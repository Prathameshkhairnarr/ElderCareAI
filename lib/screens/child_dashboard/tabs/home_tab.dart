import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:ui';
import '../../../services/auth_service.dart';
import '../../../services/emergency_service.dart';
import '../../../services/child_controls_service.dart';
import 'package:geolocator/geolocator.dart';
import '../child_profile_screen.dart';
import '../child_main_screen.dart';

class HomeTab extends StatefulWidget {
  final Function(int) onTabChange;
  
  const HomeTab({Key? key, required this.onTabChange}) : super(key: key);

  @override
  State<HomeTab> createState() => _HomeTabState();
}

class _HomeTabState extends State<HomeTab> {
  static const MethodChannel _focusChannel = MethodChannel('com.eldercare/focus');
  String _childName = "Buddy";
  
  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  void _loadProfile() {
    final user = AuthService().currentUser;
    if (user != null && user.name.isNotEmpty) {
      if (mounted) {
        setState(() => _childName = user.name.split(' ')[0]);
      }
    }
  }

  Future<void> _triggerSOS() async {
    try {
      await _focusChannel.invokeMethod('playSiren');
    } catch (e) {
      debugPrint("Siren failed: $e");
    }
    
    try {
      await EmergencyService().triggerSOS();
    } catch (e) {
      debugPrint("SOS failed: $e");
    }
    
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Emergency SOS sent & Siren activated!'), backgroundColor: MonitorTheme.red),
    );
  }

  Future<void> _stopSOS() async {
    try {
      await _focusChannel.invokeMethod('stopSiren');
    } catch (e) {
      debugPrint("Stop siren failed: $e");
    }
    
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Siren stopped.'), backgroundColor: Colors.orange),
    );
  }

  // ── Glass card builder ──
  Widget _glass({required Widget child, EdgeInsetsGeometry padding = const EdgeInsets.all(16), double radius = 18}) {
    return Container(
      padding: padding,
      decoration: MonitorTheme.glassCard(radius: radius),
      child: child,
    );
  }

  @override
  Widget build(BuildContext context) {
    final usedSecs = ChildControlsService().usedSecondsToday;
    final hours = usedSecs ~/ 3600;
    final mins = (usedSecs % 3600) ~/ 60;
    final report = ChildControlsService().buildTodayReport();

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [

          // ═══════════════════════════════════════════
          //  HEADER — "MONITORING" + Name + Avatar
          // ═══════════════════════════════════════════
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "MONITORING",
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 2,
                        color: MonitorTheme.textTert,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _childName,
                      style: const TextStyle(
                        fontSize: 34,
                        fontWeight: FontWeight.w800,
                        color: MonitorTheme.textPrimary,
                        height: 1.1,
                      ),
                    ),
                  ],
                ),
              ),
              GestureDetector(
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ChildProfileScreen())),
                child: Hero(
                  tag: 'profile_avatar',
                  child: Container(
                    width: 50, height: 50,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        colors: [MonitorTheme.accent.withOpacity(0.6), MonitorTheme.purple.withOpacity(0.4)],
                      ),
                      border: Border.all(color: MonitorTheme.accent.withOpacity(0.4), width: 2),
                    ),
                    child: const Icon(Icons.person_rounded, color: Colors.white, size: 26),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // ═══════════════════════════════════════════
          //  LOCATION / MAP CARD
          // ═══════════════════════════════════════════
          _glass(
            padding: EdgeInsets.zero,
            radius: 20,
            child: Column(
              children: [
                // Map area / visual placeholder
                Container(
                  height: 130,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        const Color(0xFF1A3A2A),
                        const Color(0xFF0F2B3A),
                        MonitorTheme.bgCard,
                      ],
                    ),
                  ),
                  child: Stack(
                    children: [
                      // Grid dots for map effect
                      ...List.generate(12, (i) {
                        final row = i ~/ 4;
                        final col = i % 4;
                        return Positioned(
                          left: 30.0 + col * 80,
                          top: 20.0 + row * 35,
                          child: Container(
                            width: 3, height: 3,
                            decoration: BoxDecoration(
                              color: MonitorTheme.green.withOpacity(0.15),
                              shape: BoxShape.circle,
                            ),
                          ),
                        );
                      }),
                      // Pulsing center dot
                      Center(
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: MonitorTheme.green.withOpacity(0.15),
                            shape: BoxShape.circle,
                          ),
                          child: Container(
                            width: 14, height: 14,
                            decoration: BoxDecoration(
                              color: MonitorTheme.green,
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(color: MonitorTheme.green.withOpacity(0.5), blurRadius: 12, spreadRadius: 2),
                              ],
                            ),
                          ),
                        ),
                      ),
                      // SAFE ZONE badge
                      Positioned(
                        top: 12, left: 12,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: MonitorTheme.green.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: MonitorTheme.green.withOpacity(0.3)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(width: 6, height: 6, decoration: BoxDecoration(color: MonitorTheme.green, shape: BoxShape.circle)),
                              const SizedBox(width: 6),
                              const Text("SAFE ZONE", style: TextStyle(color: MonitorTheme.green, fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 1)),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                // Location info row
                Padding(
                  padding: const EdgeInsets.all(14),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: MonitorTheme.blue.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.home_rounded, color: MonitorTheme.blue, size: 20),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text("Home", style: TextStyle(color: MonitorTheme.textPrimary, fontWeight: FontWeight.w700, fontSize: 16)),
                            const SizedBox(height: 2),
                            Text("Arrived 2 hours ago", style: TextStyle(color: MonitorTheme.textTert, fontSize: 12)),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.05),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.chevron_right_rounded, color: MonitorTheme.textSec, size: 20),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // ═══════════════════════════════════════════
          //  QUICK ACTION BUTTONS
          // ═══════════════════════════════════════════
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildQuickAction(Icons.my_location_rounded, "LOCATE", MonitorTheme.blue, () => widget.onTabChange(1)),
              _buildQuickAction(Icons.do_not_disturb_on_rounded, "FOCUS", MonitorTheme.purple, () => widget.onTabChange(3)),
              _buildQuickAction(Icons.bar_chart_rounded, "INSIGHTS", MonitorTheme.green, () => widget.onTabChange(4)),
            ],
          ),
          const SizedBox(height: 28),

          // ═══════════════════════════════════════════
          //  DAILY SUMMARY
          // ═══════════════════════════════════════════
          Text(
            "DAILY SUMMARY",
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 2,
              color: MonitorTheme.textTert,
            ),
          ),
          const SizedBox(height: 14),
          _glass(
            child: Row(
              children: [
                // Screen Time column
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 10, height: 10,
                            decoration: BoxDecoration(
                              color: MonitorTheme.blue,
                              borderRadius: BorderRadius.circular(3),
                            ),
                          ),
                          const SizedBox(width: 8),
                          // ON TRACK badge
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: MonitorTheme.green.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Text("ON TRACK", style: TextStyle(color: MonitorTheme.green, fontSize: 9, fontWeight: FontWeight.w800, letterSpacing: 1)),
                          ),
                          const Spacer(),
                          // Critical counter
                          Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.05),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(Icons.warning_amber_rounded, color: MonitorTheme.textTert, size: 16),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          // Screen time value
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  "${hours}h ${mins}m",
                                  style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w800, color: MonitorTheme.textPrimary, height: 1),
                                ),
                                const SizedBox(height: 4),
                                Text("Screen Time Today", style: TextStyle(fontSize: 12, color: MonitorTheme.textTert)),
                              ],
                            ),
                          ),
                          // Critical count
                          Column(
                            children: [
                              Text(
                                "${report.sosCount}",
                                style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w800, color: MonitorTheme.textPrimary, height: 1),
                              ),
                              const SizedBox(height: 4),
                              Text("Critical", style: TextStyle(fontSize: 12, color: MonitorTheme.textTert)),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // ═══════════════════════════════════════════
          //  SOS EMERGENCY BUTTON
          // ═══════════════════════════════════════════
          GestureDetector(
            onTap: _triggerSOS,
            child: Container(
              width: double.infinity,
              height: 58,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(30),
                gradient: const LinearGradient(
                  colors: [Color(0xFFFF4444), Color(0xFFCC0000)],
                ),
                boxShadow: [
                  BoxShadow(color: MonitorTheme.red.withOpacity(0.35), blurRadius: 18, offset: const Offset(0, 6)),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text("SOS", style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w900, letterSpacing: 2)),
                  const SizedBox(width: 10),
                  const Text("EMERGENCY SOS", style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildQuickAction(IconData icon, String label, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              shape: BoxShape.circle,
              border: Border.all(color: color.withOpacity(0.25)),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: TextStyle(
              color: MonitorTheme.textTert,
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.2,
            ),
          ),
        ],
      ),
    );
  }
}
