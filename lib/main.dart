import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'services/auth_service.dart';
import 'app_theme.dart';
import 'app_routes.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    // Check if we are on a supported platform (Android/iOS)
    // or if we have options for Web/Windows (not yet implemented in this task)
    await Firebase.initializeApp();
  } catch (e) {
    if (e.toString().contains("FirebaseOptions cannot be null")) {
      print("""
      ========================================================================
      ERROR: FIREBASE NOT CONFIGURED FOR WEB/WINDOWS
      
      You are trying to run on Web or Windows, but we only set up Android/iOS.
      
      PLEASE RUN ON ANDROID:
      1. Start Android Emulator (Device Manager -> Start)
      2. Run: flutter run -d android
      
      If you MUST run on Windows/Web, you need to run 'flutterfire configure'.
      ========================================================================
      """);
    } else {
      print("Firebase Init Error: $e");
    }
  }

  await AuthService().init();
  runApp(const ElderCareApp());
}

class ElderCareApp extends StatelessWidget {
  const ElderCareApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ElderCare AI',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.dark,
      initialRoute: AppRoutes.login,
      onGenerateRoute: AppRoutes.generateRoute,
    );
  }
}