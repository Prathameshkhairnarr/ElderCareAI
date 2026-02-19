import 'package:flutter/material.dart';

import 'services/auth_service.dart';
import 'services/emergency_service.dart';
import 'services/settings_service.dart';
import 'services/background_service.dart';
import 'package:permission_handler/permission_handler.dart';
import 'app_theme.dart';
import 'app_routes.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await AuthService().init();
  } catch (e) {
    print("AuthService Init Failed: $e");
  }

  try {
    await EmergencyService().init();
  } catch (e) {
    print("EmergencyService Init Failed (Non-critical): $e");
  }

  try {
    await SettingsService().init();
  } catch (e) {
    print("SettingsService Init Failed (Non-critical): $e");
  }

  // ── Request SMS permissions (CRITICAL for real-device SMS listener) ──
  try {
    final smsStatus = await Permission.sms.request();
    print('📱 SMS permission: $smsStatus');
    if (smsStatus.isPermanentlyDenied) {
      print('⚠️ SMS permission permanently denied — SMS monitoring disabled');
    }
    // Android 13+ needs notification permission
    final notifStatus = await Permission.notification.request();
    print('🔔 Notification permission: $notifStatus');
  } catch (e) {
    print('Permission request error (non-critical): $e');
  }

  try {
    await initializeBackgroundService();
  } catch (e) {
    print("Background Service Init Failed: $e");
  }

  // Determine start route based on persisted session
  final auth = AuthService();
  String startRoute;
  if (auth.isLoggedIn && auth.currentUser != null) {
    startRoute = auth.currentUser!.role == UserRole.guardian
        ? AppRoutes.guardianDashboard
        : AppRoutes.dashboard;
    print('🟢 Auto-login: ${auth.currentUser!.name} → $startRoute');
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
