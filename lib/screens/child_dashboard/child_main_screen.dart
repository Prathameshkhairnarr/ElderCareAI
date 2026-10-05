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

// ── Dark Monitoring Theme Constants (Matched with ElderCare Theme) ──
class MonitorTheme {
  static const Color bgDeep     = Color(0xFF12122A); // Elder scaffold background
  static const Color bgCard     = Color(0xFF222244); // Elder card background
  static const Color bgCardLight= Color(0xFF2A2A54);
  static const Color accent     = Color(0xFF4FC3F7); // Elder primary cyan
  static const Color green      = Color(0xFF00E676);
  static const Color red        = Color(0xFFFF5252);
  static const Color orange     = Color(0xFFFFB74D);
  static const Color purple     = Color(0xFF7C4DFF); // Elder secondary purple
  static const Color blue       = Color(0xFF4FC3F7); // Elder primary cyan
  static const Color textPrimary= Color(0xFFFFFFFF);
  static const Color textSec    = Color(0xB3FFFFFF); // 70%
  static const Color textTert   = Color(0x73FFFFFF); // 45%
  static const Color border     = Color(0x1AFFFFFF); // 10%

  static BoxDecoration glassCard({double radius = 20}) => BoxDecoration(
    color: bgCard,
    borderRadius: BorderRadius.circular(radius),
    border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
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
        bottomNavigationBar: NavigationBar(
          selectedIndex: _currentIndex,
          onDestinationSelected: _onTabTapped,
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.home_rounded),
              label: 'Home',
            ),
            NavigationDestination(
              icon: Icon(Icons.location_on_rounded),
              label: 'Safety',
            ),
            NavigationDestination(
              icon: Icon(Icons.mic_rounded),
              label: 'Buddy',
            ),
            NavigationDestination(
              icon: Icon(Icons.center_focus_strong_rounded),
              label: 'Focus',
            ),
            NavigationDestination(
              icon: Icon(Icons.insights_rounded),
              label: 'Insights',
            ),
          ],
        ),
      ),
    );
  }
}
