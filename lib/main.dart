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
import 'services/location_service.dart';
import 'package:permission_handler/permission_handler.dart';
import 'app_theme.dart';
import 'app_routes.dart';
import 'dart:async';

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
      // 📱 START FOREGROUND SMS LISTENER (after background service)
      // ─────────────────────────────────────────
      try {
        await initializeSmsListener().timeout(const Duration(seconds: 10));
      } catch (e) {
        AppLogger.error(
          LogCategory.sms,
          'Foreground SMS Listener Init Failed: $e',
        );
      }

      // ─────────────────────────────────────────
      // SAFE PARALLEL INITIALIZATION (non-blocking)
      // ─────────────────────────────────────────
      unawaited(_initNonCriticalServices());

      runApp(const ElderCareAppBootstrap());
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
    await AuthService().init().timeout(const Duration(seconds: 5));
  } catch (e) {
    AppLogger.error(LogCategory.auth, 'AuthService Init Failed: $e');
  }

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

  try {
    await SettingsService().init().timeout(const Duration(seconds: 5));
  } catch (e) {
    AppLogger.warn(LogCategory.lifecycle, 'SettingsService Init Failed: $e');
  }

  // Permissions (non-blocking) — SMS permission is handled by initializeSmsListener()
  try {
    final notifStatus = await Permission.notification.request();
    AppLogger.info(
      LogCategory.lifecycle,
      'Notification permission: $notifStatus',
    );

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

  try {
    await LocationService.initialize().timeout(const Duration(seconds: 5));
  } catch (e) {
    AppLogger.warn(LogCategory.lifecycle, 'LocationService Init Failed: $e');
  }
}

/// Lightweight bootstrap so UI starts instantly
class ElderCareAppBootstrap extends StatefulWidget {
  const ElderCareAppBootstrap({super.key});

  @override
  State<ElderCareAppBootstrap> createState() => _ElderCareAppBootstrapState();
}

class _ElderCareAppBootstrapState extends State<ElderCareAppBootstrap> {
  String _startRoute = AppRoutes.login;

  @override
  void initState() {
    super.initState();
    _resolveRoute();
  }

  Future<void> _resolveRoute() async {
    final auth = AuthService();

    if (auth.isLoggedIn && auth.currentUser != null) {
      _startRoute = auth.currentUser!.role == UserRole.guardian
          ? AppRoutes.guardianDashboard
          : AppRoutes.dashboard;
    }

    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return ElderCareApp(initialRoute: _startRoute);
  }
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
