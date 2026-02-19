import 'package:flutter/material.dart';
import 'screens/login_screen.dart';
import 'screens/dashboard_screen.dart';
import 'screens/guardian_dashboard_screen.dart';
import 'screens/sms_analyzer_screen.dart';
import 'screens/sos_screen.dart';
import 'widgets/page_transition.dart';

class AppRoutes {
  static const login = '/login';
  static const dashboard = '/dashboard';
  static const guardianDashboard = '/guardian-dashboard';
  static const smsAnalyzer = '/sms-analyzer';
  static const sos = '/sos';

  static Route<dynamic> generateRoute(RouteSettings settings) {
    switch (settings.name) {
      case login:
        return PageTransition(page: const LoginScreen());
      case dashboard:
        return PageTransition(page: const DashboardScreen());
      case guardianDashboard:
        return PageTransition(page: const GuardianDashboardScreen());
      case smsAnalyzer:
        return PageTransition(page: const SmsAnalyzerScreen());
      case sos:
        return PageTransition(page: const SosScreen());
      default:
        return PageTransition(page: const LoginScreen());
    }
  }
}
