import 'dart:async';
import 'dart:ui';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_background_service_android/flutter_background_service_android.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import 'package:shared_preferences/shared_preferences.dart';
import '../config/api_config.dart';

// Notification Channel ID
const String notificationChannelId = 'elder_care_alerts';
const int notificationId = 888;

const String _baseUrl = ApiConfig.baseUrl;

/// Entry point for the background service
@pragma('vm:entry-point')
void onStart(ServiceInstance service) async {
  DartPluginRegistrant.ensureInitialized();

  // Init local notifications
  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  const AndroidNotificationChannel channel = AndroidNotificationChannel(
    notificationChannelId,
    'ElderCare Alerts',
    description: 'Alerts for detected scams and threats',
    importance: Importance.high,
  );

  await flutterLocalNotificationsPlugin
      .resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin
      >()
      ?.createNotificationChannel(channel);

  if (service is AndroidServiceInstance) {
    service.on('setAsForeground').listen((event) {
      service.setAsForegroundService();
    });

    service.on('setAsBackground').listen((event) {
      service.setAsBackgroundService();
    });
  }

  service.on('stopService').listen((event) {
    service.stopSelf();
  });

  // ── REMOVED TELEPHONY LISTENER ──
  // Listen for SMS
  /*
  Telephony.instance.listenIncomingSms(
    onNewMessage: (SmsMessage message) {
      // Foreground handler (optional)
      print("FG SMS: ${message.body}");
      _analyzeSms(message.body ?? "");
    },
    onBackgroundMessage: backgroundMessageHandler,
  );
  */

  print("ElderCare Background Service Started");
}

/// Headless SMS Handler (Placeholder/Removed Telephony)
@pragma('vm:entry-point')
Future<void> backgroundMessageHandler(dynamic message) async {
  // Logic removed with telephony removal
}

Future<void> _analyzeSms(String body) async {
  try {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString(
      'jwt_token',
    ); // Make sure key matches AuthService

    if (token == null) {
      print("BG SMS: No token found, skipping analysis.");
      return;
    }

    final response = await http.post(
      Uri.parse('$_baseUrl/sms/analyze-sms'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({'message': body}),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final isScam = data['is_scam'] == true;
      final category = data['category'] ?? 'check';

      _showNotification(
        isScam ? '⚠️ Scam Alert Detected!' : '✅ Message Verified Safe',
        isScam
            ? 'Blocked dangerous "$category" message. Tap to resolve.'
            : 'New message processed. No threats found.',
        isScam,
      );
    } else {
      print("BG Analysis Failed: ${response.statusCode}");
    }
  } catch (e) {
    print("BG Analysis Error: $e");
  }
}

void _showNotification(String title, String body, bool isScam) async {
  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  // Big text style
  final BigTextStyleInformation bigTextStyleInformation =
      BigTextStyleInformation(body, contentTitle: title);

  await flutterLocalNotificationsPlugin.show(
    DateTime.now().millisecond, // unique id
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
        icon: 'ic_bg_service_small', // Now valid and exists in drawable
      ),
    ),
  );
}

Future<void> _createNotificationChannel() async {
  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  const AndroidNotificationChannel channel = AndroidNotificationChannel(
    notificationChannelId,
    'ElderCare Alerts',
    description: 'Alerts for detected scams and threats',
    importance: Importance.high,
  );

  await flutterLocalNotificationsPlugin
      .resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin
      >()
      ?.createNotificationChannel(channel);
}

Future<void> initializeBackgroundService() async {
  final service = FlutterBackgroundService();

  // Create the notification channel BEFORE starting the service
  // to prevent "Bad notification" crash on Android 13+
  await _createNotificationChannel();

  await service.configure(
    androidConfiguration: AndroidConfiguration(
      onStart: onStart,
      autoStart: true,
      isForegroundMode: true,
      notificationChannelId: notificationChannelId,
      initialNotificationTitle: 'ElderCare AI Active',
      initialNotificationContent: 'Monitoring for scam messages...',
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
