import 'dart:async';
import 'dart:ui';
import 'dart:convert';
import 'dart:collection';
import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_background_service_android/flutter_background_service_android.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:another_telephony/telephony.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../config/api_config.dart';
import 'sms_classifier.dart';
import 'risk_score_engine.dart';
import 'alert_policy.dart';

// ── Constants ──
const String notificationChannelId = 'elder_care_alerts';
const int notificationId = 888;
const String _baseUrl = ApiConfig.baseUrl;

// ── Dedup & Debounce State (in-memory, per session) ──
final Set<String> _recentHashes = HashSet<String>();
DateTime _lastProcessedAt = DateTime(2000);
const Duration _debounceInterval = Duration(seconds: 3);

// ── Throttle for backend risk-score sync ──
DateTime _lastBackendSyncAt = DateTime(2000);
const Duration _backendSyncThrottle = Duration(minutes: 2);

// ── Helpers ──

String _quickHash(String text) {
  final normalized = text.toLowerCase().trim().replaceAll(RegExp(r'\s+'), ' ');
  return normalized.hashCode.toString();
}

/// Skip OTPs and very short messages
bool _isOtpOrCode(String body) {
  final trimmed = body.trim();
  if (trimmed.length < 6) return true;
  final digitCount = trimmed.replaceAll(RegExp(r'[^0-9]'), '').length;
  if (trimmed.length <= 20 && digitCount / trimmed.length > 0.6) return true;
  return false;
}

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
//  CORE SMS INTELLIGENCE PIPELINE
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

/// Process an SMS through the full intelligence pipeline.
/// Called from both foreground and background handlers.
Future<void> _processSms(String body) async {
  // ── STEP 1: On-device heuristic classification (instant, 0 network) ──
  final classification = SmsClassifier.classify(body);
  print('📊 SMS classified: $classification');

  // ── STEP 2: Update dynamic risk score ──
  final updatedScore = await RiskScoreEngine.recordEvent(
    isScam: classification.isScam,
    riskScore: classification.riskScore,
  );
  print('📈 Risk score updated: $updatedScore');

  // ── STEP 3: Backend sync (only for high-risk messages) ──
  if (classification.isScam) {
    // Always send scam SMS to backend for confirmation + storage + alert
    await _syncWithBackend(body);
  } else {
    // Safe SMS: throttled score-only sync (max once per 2 min)
    final now = DateTime.now();
    if (now.difference(_lastBackendSyncAt) > _backendSyncThrottle) {
      _lastBackendSyncAt = now;
      // Fire-and-forget lightweight sync — just updating the score
      // The backend already handles this via the analyze endpoint
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
      _showNotification(
        '⚠️ Scam Detected — ${_friendlyType(classification.scamType)}',
        classification.explanation,
        true,
      );
      print('🔔 Alert fired for ${classification.scamType}');
    } else {
      print('🔕 Alert suppressed by policy');
    }
  }
}

/// Sync a high-risk SMS with the backend (stores + creates alert + updates server risk).
Future<void> _syncWithBackend(String body) async {
  try {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('jwt_token');
    if (token == null) {
      print('BG SMS: No token, skipping backend sync');
      return;
    }

    final response = await http
        .post(
          Uri.parse('$_baseUrl/sms/analyze-sms'),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $token',
          },
          body: jsonEncode({'message': body}),
        )
        .timeout(const Duration(seconds: 10));

    if (response.statusCode == 200) {
      _lastBackendSyncAt = DateTime.now();
      print('✅ Backend sync OK');
    } else {
      print('❌ Backend sync failed: ${response.statusCode}');
    }
  } catch (e) {
    print('❌ Backend sync error: $e');
    // Fail silently — on-device classification already handled it
  }
}

/// Human-friendly scam type label
String _friendlyType(String type) {
  switch (type) {
    case 'financial_impersonation':
      return 'Bank Impersonation';
    case 'financial_scam':
      return 'Financial Scam';
    case 'impersonation':
      return 'Authority Impersonation';
    case 'threat_scam':
      return 'Threatening Message';
    case 'phishing':
      return 'Phishing Link';
    case 'suspicious_link':
      return 'Suspicious Link';
    case 'social_engineering':
      return 'Social Engineering';
    default:
      return 'Suspicious Message';
  }
}

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
//  BACKGROUND SERVICE ENTRY POINTS
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

/// Top-level handler for SMS received when app is in background isolate
@pragma('vm:entry-point')
Future<void> backgroundMessageHandler(SmsMessage message) async {
  final body = message.body ?? '';
  if (body.trim().isEmpty || _isOtpOrCode(body)) return;

  final hash = _quickHash(body);
  if (_recentHashes.contains(hash)) return;
  _recentHashes.add(hash);
  if (_recentHashes.length > 200) _recentHashes.clear();

  await _processSms(body);
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

  // Request SMS permission via Telephony's own API (ensures plugin-internal state is set)
  final bool? permGranted = await telephony.requestSmsPermissions;
  print('📱 Telephony SMS permission granted: $permGranted');

  telephony.listenIncomingSms(
    onNewMessage: (SmsMessage message) {
      final body = message.body ?? '';
      print('📩 SMS RECEIVED: $body');

      if (body.trim().isEmpty || _isOtpOrCode(body)) return;

      // Debounce
      final now = DateTime.now();
      if (now.difference(_lastProcessedAt) < _debounceInterval) return;
      _lastProcessedAt = now;

      // Dedup
      final hash = _quickHash(body);
      if (_recentHashes.contains(hash)) return;
      _recentHashes.add(hash);
      if (_recentHashes.length > 200) _recentHashes.clear();

      print('� SMS → pipeline');
      _processSms(body);
    },
    onBackgroundMessage: backgroundMessageHandler,
    listenInBackground: true,
  );

  print('ElderCare SMS Intelligence active');
}

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
//  NOTIFICATIONS
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

void _showNotification(String title, String body, bool isScam) async {
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
