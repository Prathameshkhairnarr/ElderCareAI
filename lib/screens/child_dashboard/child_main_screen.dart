import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../services/child_controls_service.dart';
import '../my_buddy_screen.dart';
import 'dart:ui';
import 'tabs/home_tab.dart';
import 'tabs/safety_tab.dart';
import 'tabs/focus_tab.dart';
import 'tabs/insights_tab.dart';
import 'dart:async';

// ── Dark Monitoring Theme Constants ──
class MonitorTheme {
  static const Color bgDeep     = Color(0xFF0B0F1A);
  static const Color bgCard     = Color(0xFF141928);
  static const Color bgCardLight= Color(0xFF1C2333);
  static const Color accent     = Color(0xFF6C63FF);
  static const Color green      = Color(0xFF4ADE80);
  static const Color red        = Color(0xFFEF4444);
  static const Color orange     = Color(0xFFF59E0B);
  static const Color purple     = Color(0xFFA855F7);
  static const Color blue       = Color(0xFF3B82F6);
  static const Color textPrimary= Color(0xFFFFFFFF);
  static const Color textSec    = Color(0x99FFFFFF); // 60%
  static const Color textTert   = Color(0x66FFFFFF); // 40%
  static const Color border     = Color(0x1AFFFFFF); // 10%

  static BoxDecoration glassCard({double radius = 18}) => BoxDecoration(
    color: bgCard.withOpacity(0.75),
    borderRadius: BorderRadius.circular(radius),
    border: Border.all(color: border),
  );
}

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
    if (mounted) setState(() {}); // Rebuild UI with synced screen time
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
      SafetyTab(),
      const SizedBox(), // Placeholder for Voice Buddy
      FocusTab(),
      InsightsTab(),
    ];

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: MonitorTheme.bgDeep,
        body: SafeArea(
          child: IndexedStack(
            index: _currentIndex,
            children: tabs,
          ),
        ),
        bottomNavigationBar: Container(
          margin: const EdgeInsets.fromLTRB(40, 0, 40, 16),
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: MonitorTheme.bgCard.withOpacity(0.9),
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: MonitorTheme.border),
            boxShadow: [
              BoxShadow(color: Colors.black.withOpacity(0.3), blurRadius: 20, offset: const Offset(0, 4)),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _navItem(Icons.home_rounded, 0),
              _navItem(Icons.location_on_rounded, 1),
              _navItem(Icons.mic_rounded, 2),
              _navItem(Icons.center_focus_strong_rounded, 3),
              _navItem(Icons.settings_rounded, 4),
            ],
          ),
        ),
      ),
    );
  }

  Widget _navItem(IconData icon, int index) {
    final isActive = _currentIndex == index;
    return GestureDetector(
      onTap: () => _onTabTapped(index),
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: isActive ? MonitorTheme.accent.withOpacity(0.2) : Colors.transparent,
          shape: BoxShape.circle,
        ),
        child: Icon(
          icon,
          color: isActive ? MonitorTheme.accent : MonitorTheme.textTert,
          size: 22,
        ),
      ),
    );
  }
}
