import 'dart:async';
import 'dart:ui';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:another_telephony/telephony.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../config/api_config.dart';
import 'sms_classifier.dart';
import 'risk_score_engine.dart';
import 'risk_score_provider.dart';
import 'alert_policy.dart';
import 'app_logger.dart';

// ── Constants ──
const String notificationChannelId = 'elder_care_alerts';
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
Future<void> _processSms(String body, String sender) async {
  try {
    // Truncate oversized messages to prevent OOM
    final safeBody = body.length > _maxMessageLength
        ? body.substring(0, _maxMessageLength)
        : body;

    // ── STEP 1: On-device heuristic classification (instant, 0 network) ──
    final classification = SmsClassifier.classify(safeBody);
    AppLogger.info(
      LogCategory.sms,
      'SMS classified: ${classification.label} risk=${classification.riskScore}',
    );

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

      if (shouldNotify) {
        String titlePrefix = classification.label == 'PHISHING_LINK'
            ? '🛑 Dangerous Link'
            : '⚠️ Potential Scam';
        _showNotification(
          '$titlePrefix from $sender',
          classification.explanation,
          true,
        );
        AppLogger.info(
          LogCategory.sms,
          'Alert fired for ${classification.scamType}',
        );
      } else {
        AppLogger.info(LogCategory.sms, 'Alert suppressed by policy');
      }
    }
  } catch (e, stackTrace) {
    AppLogger.error(LogCategory.sms, 'CRITICAL ERROR in _processSms: $e');
    // Log stack trace only in debug
    assert(() {
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

    await _processSms(body, sender);
  } catch (e) {
    AppLogger.error(LogCategory.sms, 'Error in backgroundMessageHandler: $e');
  }
}

/// Foreground service entry point
@pragma('vm:entry-point')
void onStart(ServiceInstance service) async {
  DartPluginRegistrant.ensureInitialized();

  // Init notifications
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

  if (service is AndroidServiceInstance) {
    service.on('setAsForeground').listen((_) {
      service.setAsForegroundService();
    });
    service.on('setAsBackground').listen((_) {
      service.setAsBackgroundService();
    });
  }

  service.on('stopService').listen((_) {
    service.stopSelf();
  });

  // ── SMS Listener ──
  final Telephony telephony = Telephony.instance;

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
        await _processSms(body, sender);
      } catch (e) {
        AppLogger.error(LogCategory.sms, 'Error in onNewMessage: $e');
      }
    },
    onBackgroundMessage: backgroundMessageHandler,
    listenInBackground: true,
  );

  AppLogger.info(LogCategory.lifecycle, 'ElderCare SMS Intelligence active');
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
  const channel = AndroidNotificationChannel(
    notificationChannelId,
    'ElderCare Alerts',
    description: 'Alerts for detected scams and threats',
    importance: Importance.high,
  );
  await plugin
      .resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin
      >()
      ?.createNotificationChannel(channel);
}

Future<void> initializeBackgroundService() async {
  final service = FlutterBackgroundService();

  // Create channel BEFORE starting service (Android 13+ crash prevention)
  await _createNotificationChannel();

  await service.configure(
    androidConfiguration: AndroidConfiguration(
      onStart: onStart,
      autoStart: true,
      isForegroundMode: true,
      notificationChannelId: notificationChannelId,
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

  service.startService();
}
