import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import 'services/auth_service.dart';
import 'services/emergency_service.dart';
import 'services/settings_service.dart';
import 'services/background_service.dart';
import 'services/sms_listener_service.dart';
import 'services/shake_detector_service.dart';
import 'services/risk_score_provider.dart';
import 'services/app_logger.dart';
import 'package:permission_handler/permission_handler.dart';
import 'app_theme.dart';
import 'app_routes.dart';
import 'dart:async';

import 'screens/login_screen.dart';
import 'screens/dashboard_screen.dart';
import 'screens/guardian_dashboard_screen.dart';

void main() {
  runZonedGuarded(
    () async {
      WidgetsFlutterBinding.ensureInitialized();

      // ─────────────────────────────────────────
      // LOAD ENVIRONMENT VARIABLES
      // ─────────────────────────────────────────
      try {
        await dotenv.load(fileName: ".env");
        AppLogger.info(LogCategory.lifecycle, 'Environment variables loaded');
      } catch (e) {
        AppLogger.warn(
          LogCategory.lifecycle,
          'Failed to load .env file: $e — keys will be empty',
        );
      }

      // ─────────────────────────────────────────
      // GLOBAL ERROR HANDLERS
      // ─────────────────────────────────────────
      FlutterError.onError = (FlutterErrorDetails details) {
        AppLogger.error(
          LogCategory.lifecycle,
          'FlutterError: ${details.exceptionAsString()}',
        );
      };

      PlatformDispatcher.instance.onError = (error, stack) {
        AppLogger.error(LogCategory.lifecycle, 'PlatformError: $error');
        return true;
      };

      // ─────────────────────────────────────────
      // 🚨 START BACKGROUND SERVICE EARLY (CRITICAL FIX)
      // ─────────────────────────────────────────
      try {
        await initECAIBackground().timeout(const Duration(seconds: 10));
        AppLogger.info(LogCategory.lifecycle, 'Background service started');
      } catch (e) {
        AppLogger.error(
          LogCategory.lifecycle,
          'Background Service Init Failed: $e',
        );
      }

      // ─────────────────────────────────────────
      // SAFE ASYNC INITIALIZATION (Sequential logic)
      // ─────────────────────────────────────────
      Future<void> _runAsyncInitializations() async {
        try {
          // 🚀 BATCH ALL STARTUP PERMISSIONS HERE TO PREVENT ANDROID 14+ CRASHES 🚀
          // Requesting them via a list allows the plugin to queue the prompts naturally
          // without triggering multiple simultaneous intents.
          await [
            Permission.sms,
            Permission.phone,
            Permission.notification,
            Permission.activityRecognition,
            Permission.location,
          ].request();
        } catch (e) {
          AppLogger.warn(LogCategory.lifecycle, 'Master permission request error: $e');
        }

        try {
          await initializeSmsListener();
        } catch (e) {
          AppLogger.error(
            LogCategory.sms,
            'Foreground SMS Listener Init Failed: $e',
          );
        }

        try {
          await _initNonCriticalServices();
        } catch (e) {
          AppLogger.error(LogCategory.lifecycle, 'Non-critical init failed: $e');
        }
      }

      // Ensure Auth Service is initialized before checking route
      try {
        await AuthService().init().timeout(const Duration(seconds: 5));
      } catch (e) {
        AppLogger.error(LogCategory.auth, 'AuthService Init Failed: $e');
      }

      // Load settings (theme) BEFORE running the app to avoid wrong theme flash
      try {
        await SettingsService().init().timeout(const Duration(seconds: 3));
      } catch (e) {
        AppLogger.warn(LogCategory.lifecycle, 'Early SettingsService Init Failed: $e');
      }

      unawaited(_runAsyncInitializations());

      final auth = AuthService();
      Widget homeWidget = const LoginScreen();
      if (auth.isLoggedIn && auth.currentUser != null) {
        homeWidget = auth.currentUser!.role == UserRole.guardian
            ? const GuardianDashboardScreen()
            : const DashboardScreen();
      }

      runApp(ElderCareApp(homeWidget: homeWidget));
    },
    (error, stack) {
      // Last-resort handler: catches errors that escape all other handlers
      AppLogger.error(LogCategory.lifecycle, 'Uncaught zone error: $error');
    },
  );
}

/// Runs heavy inits without blocking app start
Future<void> _initNonCriticalServices() async {
  try {
    await EmergencyService().init().timeout(const Duration(seconds: 5));
  } catch (e) {
    AppLogger.warn(LogCategory.sos, 'EmergencyService Init Failed: $e');
  }

  try {
    ShakeDetectorService().start();
  } catch (e) {
    AppLogger.warn(LogCategory.shake, 'ShakeDetector Init Failed: $e');
  }



  // Permissions (non-blocking)
  // Notifications and location are now handled in the master batch.
  try {
    // Battery optimization is a special intent, keep it isolated at the end.
    final batteryStatus = await Permission.ignoreBatteryOptimizations.request();
    AppLogger.info(
      LogCategory.lifecycle,
      'Battery optimization ignore: $batteryStatus',
    );
  } catch (e) {
    AppLogger.warn(LogCategory.lifecycle, 'Permission request error: $e');
  }

  try {
    await RiskScoreProvider().init().timeout(const Duration(seconds: 5));
  } catch (e) {
    AppLogger.warn(LogCategory.risk, 'RiskScoreProvider Init Failed: $e');
  }

}



class ElderCareApp extends StatelessWidget {
  final Widget homeWidget;
  const ElderCareApp({super.key, required this.homeWidget});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: SettingsService(),
      builder: (context, child) {
        return MaterialApp(
          title: 'ElderSaathi',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.lightTheme,
          darkTheme: AppTheme.darkTheme,
          themeMode: SettingsService().themeMode,
          home: homeWidget,
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
