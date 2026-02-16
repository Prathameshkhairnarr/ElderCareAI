import 'package:flutter/material.dart';

import 'services/auth_service.dart';
import 'services/emergency_service.dart';
import 'services/settings_service.dart';
import 'services/background_service.dart';
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

  try {
    await initializeBackgroundService();
  } catch (e) {
    print("Background Service Init Failed: $e");
  }

  runApp(const ElderCareApp());
}

class ElderCareApp extends StatelessWidget {
  const ElderCareApp({super.key});

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
          initialRoute: AppRoutes.login,
          onGenerateRoute: AppRoutes.generateRoute,
          builder: (context, child) {
            final scale = SettingsService().fontScale;
            return MediaQuery(
              data: MediaQuery.of(context).copyWith(
                textScaler: TextScaler.linear(scale),
              ),
              child: child!,
            );
          },
        );
      },
    );
  }
}
