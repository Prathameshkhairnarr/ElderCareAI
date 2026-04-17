import 'package:flutter/material.dart';
import '../../services/child_controls_service.dart';
import '../my_buddy_screen.dart';
import 'child_theme.dart';
import 'animated_background.dart';
import 'dart:ui';
import 'tabs/home_tab.dart';
import 'tabs/safety_tab.dart';
import 'tabs/focus_tab.dart';
import 'tabs/insights_tab.dart';
import 'tabs/timeline_tab.dart';
import 'dart:async';

class ChildMainScreen extends StatefulWidget {
  const ChildMainScreen({Key? key}) : super(key: key);

  @override
  State<ChildMainScreen> createState() => _ChildMainScreenState();
}

class _ChildMainScreenState extends State<ChildMainScreen> {
  int _currentIndex = 0;
  Timer? _usageTimer;

  @override
  void initState() {
    super.initState();
    _initServices();
  }

  Future<void> _initServices() async {
    await ChildControlsService().init();
    _startUsageTimer();
  }

  void _startUsageTimer() {
    _usageTimer?.cancel();
    _usageTimer = Timer.periodic(const Duration(seconds: 1), (_) async {
      await ChildControlsService().addUsageSeconds(1);
    });
  }

  @override
  void dispose() {
    _usageTimer?.cancel();
    super.dispose();
  }

  void _onTabTapped(int index) {
    if (index == 2) {
      Navigator.of(context).push(MaterialPageRoute(builder: (_) => const MyBuddyScreen()));
      return;
    }
    setState(() {
      _currentIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    final List<Widget> tabs = [
      HomeTab(onTabChange: _onTabTapped),
      const SafetyTab(),
      const SizedBox(), // Placeholder for Voice Buddy
      const FocusTab(),
      const InsightsTab(),
    ];

    return Scaffold(
      backgroundColor: ChildTheme.background,
      body: SafeArea(
        child: IndexedStack(
          index: _currentIndex,
          children: tabs,
        ),
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 20, offset: const Offset(0, -5)),
          ],
        ),
        child: BottomNavigationBar(
          backgroundColor: Colors.white,
          elevation: 0,
          type: BottomNavigationBarType.fixed,
          currentIndex: _currentIndex,
          selectedItemColor: ChildTheme.primaryBlue,
          unselectedItemColor: ChildTheme.textSecondary.withOpacity(0.5),
          selectedLabelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11),
          unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w500, fontSize: 11),
          onTap: _onTabTapped,
          items: const [
            BottomNavigationBarItem(icon: Icon(Icons.home_rounded), label: "Home"),
            BottomNavigationBarItem(icon: Icon(Icons.shield_outlined), activeIcon: Icon(Icons.shield_rounded), label: "Safety"),
            BottomNavigationBarItem(icon: Icon(Icons.mic_rounded), activeIcon: Icon(Icons.mic_rounded), label: "Buddy"),
            BottomNavigationBarItem(icon: Icon(Icons.center_focus_weak_outlined), activeIcon: Icon(Icons.center_focus_strong_rounded), label: "Focus"),
            BottomNavigationBarItem(icon: Icon(Icons.bar_chart_rounded), label: "Insights"),
          ],
        ),
      ),
    );
  }
}
