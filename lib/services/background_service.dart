import 'dart:async';
import 'dart:ui';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:another_telephony/telephony.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:permission_handler/permission_handler.dart';
import '../config/api_config.dart';
import 'sms_classifier.dart';
import 'risk_score_engine.dart';
import 'risk_score_provider.dart';
import 'alert_policy.dart';
import 'app_logger.dart';
import 'voice_alert_service.dart';
import 'task_reminder_service.dart';

// NOTE: initializeBackgroundService() stub removed.
// The actual background init is initECAIBackground() at the bottom of this file.

// ── Constants ──
const String notificationChannelId = 'elder_care_alerts';
const String _serviceChannelId = 'elder_care_service';
const int notificationId = 888;
const String _baseUrl = ApiConfig.baseUrl;

// ── Dedup & Debounce State (persistent) ──
const String _dedupKey = 'processed_sms_hashes';
DateTime _lastProcessedAt = DateTime(2000);
const Duration _debounceInterval = Duration(seconds: 3);

// ── Throttle for backend risk-score sync ──
DateTime _lastBackendSyncAt = DateTime(2000);
const Duration _backendSyncThrottle = Duration(minutes: 2);

// ── Max message length to prevent OOM ──
const int _maxMessageLength = 2000;

// ── Helpers ──

String _quickHash(String text) {
  final normalized = text.toLowerCase().trim().replaceAll(RegExp(r'\s+'), ' ');
  return normalized.hashCode.toString();
}

/// Skip OTPs and very short messages — null-safe
bool _isOtpOrCode(String? body) {
  if (body == null || body.trim().isEmpty) return true;
  final trimmed = body.trim().toLowerCase();
  if (trimmed.length < 6) return true;
  final digitCount = trimmed.replaceAll(RegExp(r'[^0-9]'), '').length;
  if (trimmed.length <= 20 && digitCount / trimmed.length > 0.6) return true;

  // Enhanced OTP filter based on common keywords
  if (RegExp(r'\b(otp|code|verification|pin|password)\b').hasMatch(trimmed) &&
      digitCount >= 4) {
    return true;
  }
  return false;
}

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
//  CORE SMS INTELLIGENCE PIPELINE
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

/// Process an SMS through the full intelligence pipeline.
/// Called from both foreground and background handlers.
/// NEVER crashes — all exceptions swallowed defensively.
Future<void> processSms(String body, String sender) async {
  try {
    // Truncate oversized messages to prevent OOM
    final safeBody = body.length > _maxMessageLength
        ? body.substring(0, _maxMessageLength)
        : body;

    // --- TRUECALLER-STYLE CONTACT BYPASS ---
    bool isContact = false;
    try {
      if (await Permission.contacts.isGranted) {
        String normalizedSender = sender.replaceAll(RegExp(r'[^\d+]'), '');
        // Only verify against contacts if sender appears to be a normal phone number
        if (normalizedSender.length >= 10) { 
          List<Contact> contacts = await FlutterContacts.getContacts(withProperties: true);
          String matchTarget = normalizedSender.length > 10 
              ? normalizedSender.substring(normalizedSender.length - 10) 
              : normalizedSender;
              
          for (var c in contacts) {
             for (var phone in c.phones) {
                String normalizedPhone = phone.number.replaceAll(RegExp(r'[^\d]'), '');
                if (normalizedPhone.endsWith(matchTarget)) {
                   isContact = true;
                   break;
                }
             }
             if (isContact) break;
          }
        }
      }
    } catch (e) {
      AppLogger.warn(LogCategory.sms, 'Contact check bypassed due to error: $e');
    }

    // ── STEP 1: On-device heuristic classification (instant, 0 network) ──
    final classification = SmsClassifier.classify(
      safeBody,
      sender: sender,
      isContact: isContact,
    );
    AppLogger.info(
      LogCategory.sms,
      'SMS classified: ${classification.label} risk=${classification.riskScore}',
    );

    // ── STEP 1.5: Save classified result locally for Recent Messages ──
    try {
      final prefs = await SharedPreferences.getInstance();
      final localResults = prefs.getStringList('local_sms_results') ?? [];
      final entry = jsonEncode({
        'sender': sender,
        'body': safeBody,
        'riskScore': classification.riskScore,
        'category': classification.scamType,
        'isFraud': classification.isScam,
        'explanation': classification.explanation,
        'isResolved': false,
        'timestamp': DateTime.now().toIso8601String(),
      });
      localResults.insert(0, entry); // newest first
      // Keep max 50 local entries
      if (localResults.length > 50) {
        localResults.removeRange(50, localResults.length);
      }
      await prefs.setStringList('local_sms_results', localResults);
    } catch (e) {
      AppLogger.error(LogCategory.sms, 'Local SMS save failed: $e');
    }

    // ── STEP 2: Update dynamic risk score ──
    final updatedScore = await RiskScoreEngine.recordEvent(
      isScam: classification.isScam,
      riskScore: classification.riskScore,
    );
    AppLogger.info(LogCategory.risk, 'Risk score updated: $updatedScore');

    // ── STEP 3: Backend sync (only for high-risk messages) ──
    if (classification.isScam) {
      await _syncWithBackend(safeBody, sender, classification);
      // Trigger reactive UI refresh — catch any error silently
      try {
        RiskScoreProvider().onThreatEvent();
      } catch (_) {
        // Background isolate may not have access to UI provider — safe to ignore
      }
    } else {
      // Safe SMS: throttled score-only sync (max once per 2 min)
      final now = DateTime.now();
      if (now.difference(_lastBackendSyncAt) > _backendSyncThrottle) {
        _lastBackendSyncAt = now;
      }
    }

    // ── STEP 4: Smart alert policy ──
    if (classification.isScam) {
      final shouldNotify = AlertPolicy.shouldAlert(
        currentRiskScore: updatedScore,
        smsRiskScore: classification.riskScore,
        scamType: classification.scamType,
      );

      // Save scam alert locally for Safety Alerts screen
      try {
        final prefs = await SharedPreferences.getInstance();
        final localAlerts = prefs.getStringList('local_safety_alerts') ?? [];

        // Determine severity based on risk score
        String severity = 'medium';
        if (classification.riskScore >= 80) {
          severity = 'critical';
        } else if (classification.riskScore >= 50) {
          severity = 'high';
        }

        final alertEntry = jsonEncode({
          'title': classification.label == 'PHISHING_LINK'
              ? 'Dangerous Link Detected'
              : 'Scam SMS Detected',
          'details': '${classification.explanation}\n\nFrom: $sender\nMessage: ${safeBody.length > 100 ? '${safeBody.substring(0, 100)}...' : safeBody}',
          'alert_type': 'sms_fraud',
          'severity': severity,
          'created_at': DateTime.now().toIso8601String(),
        });

        localAlerts.insert(0, alertEntry);
        // Keep max 100 alerts
        if (localAlerts.length > 100) {
          localAlerts.removeRange(100, localAlerts.length);
        }
        await prefs.setStringList('local_safety_alerts', localAlerts);
      } catch (e) {
        AppLogger.error(LogCategory.sms, 'Local alert save failed: $e');
      }

      if (shouldNotify) {
        String titlePrefix = classification.label == 'PHISHING_LINK'
            ? '🛑 Dangerous Link'
            : '⚠️ Potential Scam';
        _showNotification(
          '$titlePrefix from $sender',
          classification.explanation,
          true,
        );

        // ── Voice Alert for scam ──
        try {
          VoiceAlertService().speakAlert(
            'Warning! Yeh message scam ho sakta hai. $sender se aaya hai. '
            'Kripya is message ka jawab na de.',
            priority: AlertPriority.high,
            category: AlertCategory.scam,
          );
        } catch (_) {}

        AppLogger.info(
          LogCategory.sms,
          'Alert fired for ${classification.scamType}',
        );
      } else {
        AppLogger.info(LogCategory.sms, 'Alert suppressed by policy');
      }
    }
  } catch (e, stackTrace) {
    AppLogger.error(LogCategory.sms, 'CRITICAL ERROR in processSms: $e');
    // Log stack trace only in debug
    assert(() {
      // ignore: avoid_print
      print(stackTrace);
      return true;
    }());
    // Suppress crash to prevent ANR or background service death
  }
}

/// Sync a high-risk SMS with the backend (stores + creates alert + updates server risk).
Future<void> _syncWithBackend(
  String body,
  String sender,
  SmsClassification classification,
) async {
  try {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('jwt_token');
    if (token == null) {
      AppLogger.warn(LogCategory.sms, 'No token, skipping backend sync');
      return;
    }

    final response = await http
        .post(
          Uri.parse('$_baseUrl/risk/sms-event'),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $token',
          },
          body: jsonEncode({
            'message_hash': _quickHash(body),
            'sender': sender,
            'content': body,
            'label': classification.label,
          }),
        )
        .timeout(const Duration(seconds: 10));

    if (response.statusCode == 200) {
      _lastBackendSyncAt = DateTime.now();
      AppLogger.info(LogCategory.sms, 'Backend sync OK');
    } else {
      AppLogger.warn(
        LogCategory.sms,
        'Backend sync failed: ${response.statusCode}',
      );
    }
  } on TimeoutException catch (_) {
    AppLogger.warn(LogCategory.sms, 'Backend sync timed out');
  } catch (e) {
    AppLogger.error(LogCategory.sms, 'Backend sync error: $e');
    // Fail silently — on-device classification already handled it
  }
}

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
//  BACKGROUND SERVICE ENTRY POINTS
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

/// Top-level handler for SMS received when app is in background isolate
@pragma('vm:entry-point')
Future<void> backgroundMessageHandler(SmsMessage message) async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    final body = message.body ?? '';
    final sender = message.address ?? 'Unknown';

    AppLogger.info(LogCategory.sms, 'BG SMS received from $sender');

    if (body.trim().isEmpty || _isOtpOrCode(body)) {
      AppLogger.info(LogCategory.sms, 'BG SMS ignored: empty/OTP');
      return;
    }

    final hash = _quickHash(body);
    final prefs = await SharedPreferences.getInstance();
    List<String> recentHashes = prefs.getStringList(_dedupKey) ?? [];

    if (recentHashes.contains(hash)) {
      AppLogger.info(LogCategory.sms, 'BG SMS duplicate suppressed');
      return;
    }

    recentHashes.add(hash);
    if (recentHashes.length > 200) {
      recentHashes.removeAt(0); // Keep max 200 items
    }
    await prefs.setStringList(_dedupKey, recentHashes);

    await processSms(body, sender);
  } catch (e) {
    AppLogger.error(LogCategory.sms, 'Error in backgroundMessageHandler: $e');
  }
}

/// Foreground service entry point
@pragma('vm:entry-point')
void onStart(ServiceInstance service) async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    AppLogger.info(LogCategory.lifecycle, 'Background service starting');
    DartPluginRegistrant.ensureInitialized();

    // Init notifications
    try {
      final notifPlugin = FlutterLocalNotificationsPlugin();
      const channel = AndroidNotificationChannel(
        notificationChannelId,
        'ElderCare Alerts',
        description: 'Alerts for detected scams and threats',
        importance: Importance.high,
      );
      await notifPlugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >()
          ?.createNotificationChannel(channel);
    } catch (e) {
      AppLogger.error(
        LogCategory.lifecycle,
        'Notification channel init failed: $e',
      );
    }

    if (service is AndroidServiceInstance) {
      try {
        // CRITICAL: Set as foreground immediately to prevent kill
        await service.setAsForegroundService();

        service.on('setAsForeground').listen((_) {
          service.setAsForegroundService();
        });
        service.on('setAsBackground').listen((_) {
          service.setAsBackgroundService();
        });
      } catch (e) {
        AppLogger.error(
          LogCategory.lifecycle,
          'Service mode listener failed: $e',
        );
      }
    }

    service.on('stopService').listen((_) {
      service.stopSelf();
    });

    // ── Watchdog Timer: keeps service alive ──
    // Updates the notification periodically so Android knows the service is active
    Timer.periodic(const Duration(minutes: 5), (timer) async {
      if (service is AndroidServiceInstance) {
        if (await service.isForegroundService()) {
          service.setForegroundNotificationInfo(
            title: 'ElderCare AI Active',
            content: 'SMS intelligence monitoring active...',
          );
        }
      }
    });

    // ── Task Reminder Poller ──
    try {
      TaskReminderService().startPolling();
    } catch (e) {
      AppLogger.error(LogCategory.lifecycle, 'TaskReminderService init failed: $e');
    }


    // ── SMS Listener ──
    try {
      final Telephony telephony = Telephony.instance;

      // We rely on the Main isolate (sms_listener_service) to request permissions.
      // Requesting them here in the background isolate concurrently causes Android crashes.

      telephony.listenIncomingSms(
        onNewMessage: (SmsMessage message) async {
          final body = message.body ?? '';
          final sender = message.address ?? 'Unknown';

          AppLogger.info(LogCategory.sms, 'FG SMS received from $sender');

          if (body.trim().isEmpty || _isOtpOrCode(body)) {
            AppLogger.info(LogCategory.sms, 'FG SMS ignored: empty/OTP');
            return;
          }

          // Debounce
          final now = DateTime.now();
          if (now.difference(_lastProcessedAt) < _debounceInterval) {
            AppLogger.info(LogCategory.sms, 'FG SMS debounced');
            return;
          }
          _lastProcessedAt = now;

          try {
            // Dedup with SharedPreferences
            final prefs = await SharedPreferences.getInstance();
            List<String> recentHashes = prefs.getStringList(_dedupKey) ?? [];
            final hash = _quickHash(body);

            if (recentHashes.contains(hash)) {
              AppLogger.info(LogCategory.sms, 'FG SMS duplicate suppressed');
              return;
            }

            recentHashes.add(hash);
            if (recentHashes.length > 200) recentHashes.removeAt(0);
            await prefs.setStringList(_dedupKey, recentHashes);

            AppLogger.info(LogCategory.sms, 'FG SMS → pipeline');
            await processSms(body, sender);
          } catch (e) {
            AppLogger.error(LogCategory.sms, 'Error in onNewMessage: $e');
          }
        },
        onBackgroundMessage: backgroundMessageHandler,
        listenInBackground: true,
      );
    } catch (e) {
      AppLogger.error(
        LogCategory.sms,
        'SMS listener init in BG service failed: $e',
      );
    }

    AppLogger.info(LogCategory.lifecycle, 'ElderCare SMS Intelligence active');
  } catch (e) {
    AppLogger.error(
      LogCategory.lifecycle,
      'Background service onStart FATAL: $e',
    );
    // Service degrades gracefully — does not crash
  }
}

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
//  NOTIFICATIONS
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

void _showNotification(String title, String body, bool isScam) async {
  try {
    final plugin = FlutterLocalNotificationsPlugin();
    await plugin.show(
      DateTime.now().millisecond,
      title,
      body,
      NotificationDetails(
        android: AndroidNotificationDetails(
          notificationChannelId,
          'ElderCare Alerts',
          channelDescription: 'Alerts for detected scams and threats',
          importance: Importance.max,
          priority: Priority.high,
          color: isScam ? Colors.red : Colors.green,
          icon: 'ic_bg_service_small',
        ),
      ),
    );
  } catch (e) {
    AppLogger.error(LogCategory.sms, 'Notification error: $e');
  }
}

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
//  SERVICE INITIALIZATION
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Future<void> _createNotificationChannel() async {
  final plugin = FlutterLocalNotificationsPlugin();
  final androidPlugin = plugin
      .resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin
      >();

  // 1. Scam alert channel — HIGH importance (popup + sound)
  const alertChannel = AndroidNotificationChannel(
    notificationChannelId,
    'ElderCare Alerts',
    description: 'Alerts for detected scams and threats',
    importance: Importance.high,
  );
  await androidPlugin?.createNotificationChannel(alertChannel);

  // 2. Service channel — LOW importance (silent, no popup, persistent)
  const serviceChannel = AndroidNotificationChannel(
    _serviceChannelId,
    'ElderCare Background Service',
    description: 'Keeps SMS protection running in the background',
    importance: Importance.low,
    showBadge: false,
    enableVibration: false,
    playSound: false,
  );
  await androidPlugin?.createNotificationChannel(serviceChannel);
}

Future<void> initECAIBackground() async {
  final service = FlutterBackgroundService();

  // Create channel BEFORE starting service (Android 13+ crash prevention)
  await _createNotificationChannel();

  // Request battery optimization exemption (critical for OEM devices)
  // Without this, Xiaomi/Samsung/Huawei will kill the service aggressively
  try {
    await service.configure(
      androidConfiguration: AndroidConfiguration(
        onStart: onStart,
        autoStart: true,
        autoStartOnBoot: true,
        isForegroundMode: true,
        notificationChannelId: _serviceChannelId,
        initialNotificationTitle: 'ElderCare AI Active',
        initialNotificationContent: 'SMS intelligence monitoring active...',
        foregroundServiceNotificationId: notificationId,
      ),
      iosConfiguration: IosConfiguration(
        autoStart: true,
        onForeground: onStart,
        onBackground: (ServiceInstance service) {
          return true;
        },
      ),
    );
  } catch (e) {
    AppLogger.error(
      LogCategory.lifecycle,
      'Background service configure failed: $e',
    );
  }

  service.startService();
}

