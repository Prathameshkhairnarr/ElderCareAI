import 'dart:ui';
import 'package:flutter/material.dart';

import 'services/auth_service.dart';
import 'services/emergency_service.dart';
import 'services/settings_service.dart';
import 'services/background_service.dart';
import 'services/shake_detector_service.dart';
import 'services/risk_score_provider.dart';
import 'services/app_logger.dart';
import 'package:permission_handler/permission_handler.dart';
import 'app_theme.dart';
import 'app_routes.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // ── Global error handlers ──
  FlutterError.onError = (FlutterErrorDetails details) {
    AppLogger.error(
      LogCategory.lifecycle,
      'FlutterError: ${details.exceptionAsString()}',
    );
    // Don't rethrow — prevents crash in production
  };
  PlatformDispatcher.instance.onError = (error, stack) {
    AppLogger.error(LogCategory.lifecycle, 'PlatformError: $error');
    return true; // Handled — prevent crash
  };

  // ── Service initialization with individual timeouts ──
  // Each init is wrapped to prevent one failure from blocking startup

  try {
    await AuthService().init().timeout(const Duration(seconds: 5));
  } catch (e) {
    AppLogger.error(LogCategory.auth, 'AuthService Init Failed: $e');
  }

  try {
    await EmergencyService().init().timeout(const Duration(seconds: 5));
  } catch (e) {
    AppLogger.warn(
      LogCategory.sos,
      'EmergencyService Init Failed (Non-critical): $e',
    );
  }

  // Start shake-to-SOS detector
  try {
    ShakeDetectorService().start();
  } catch (e) {
    AppLogger.warn(
      LogCategory.shake,
      'ShakeDetector Init Failed (Non-critical): $e',
    );
  }

  try {
    await SettingsService().init().timeout(const Duration(seconds: 5));
  } catch (e) {
    AppLogger.warn(
      LogCategory.lifecycle,
      'SettingsService Init Failed (Non-critical): $e',
    );
  }

  // ── Request permissions (CRITICAL for real-device SMS listener) ──
  try {
    final smsStatus = await Permission.sms.request();
    AppLogger.info(LogCategory.lifecycle, 'SMS permission: $smsStatus');
    if (smsStatus.isPermanentlyDenied) {
      AppLogger.warn(
        LogCategory.lifecycle,
        'SMS permission permanently denied — SMS monitoring disabled',
      );
    }
    // Android 13+ needs notification permission
    final notifStatus = await Permission.notification.request();
    AppLogger.info(
      LogCategory.lifecycle,
      'Notification permission: $notifStatus',
    );

    // Request battery optimization ignore for background reliability
    final batteryStatus = await Permission.ignoreBatteryOptimizations.request();
    AppLogger.info(
      LogCategory.lifecycle,
      'Battery optimization ignore: $batteryStatus',
    );
  } catch (e) {
    AppLogger.warn(
      LogCategory.lifecycle,
      'Permission request error (non-critical): $e',
    );
  }

  // ── Initialize risk score provider (starts periodic sync) ──
  try {
    await RiskScoreProvider().init().timeout(const Duration(seconds: 5));
  } catch (e) {
    AppLogger.warn(
      LogCategory.risk,
      'RiskScoreProvider Init Failed (Non-critical): $e',
    );
  }

  try {
    await initializeBackgroundService().timeout(const Duration(seconds: 10));
  } catch (e) {
    AppLogger.error(
      LogCategory.lifecycle,
      'Background Service Init Failed: $e',
    );
  }

  // Determine start route based on persisted session
  final auth = AuthService();
  String startRoute;
  if (auth.isLoggedIn && auth.currentUser != null) {
    startRoute = auth.currentUser!.role == UserRole.guardian
        ? AppRoutes.guardianDashboard
        : AppRoutes.dashboard;
    AppLogger.info(
      LogCategory.auth,
      'Auto-login: ${auth.currentUser!.name} → $startRoute',
    );
  } else {
    startRoute = AppRoutes.login;
  }

  runApp(ElderCareApp(initialRoute: startRoute));
}

class ElderCareApp extends StatelessWidget {
  final String initialRoute;
  const ElderCareApp({super.key, required this.initialRoute});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: SettingsService(),
      builder: (context, child) {
        return MaterialApp(
          title: 'ElderCare AI',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.lightTheme,
          darkTheme: AppTheme.darkTheme,
          themeMode: SettingsService().themeMode,
          initialRoute: initialRoute,
          onGenerateRoute: AppRoutes.generateRoute,

          builder: (context, child) {
            final scale = SettingsService().fontScale;
            return MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: TextScaler.linear(scale)),
              child: child!,
            );
          },
        );
      },
    );
  }
}
