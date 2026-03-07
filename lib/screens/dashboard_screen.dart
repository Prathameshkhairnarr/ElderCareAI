import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../services/risk_score_provider.dart';
import '../widgets/dashboard_card.dart';
import '../widgets/risk_indicator.dart';

import 'sms_analyzer_screen.dart';
import 'sos_screen.dart';
import 'call_protection_screen.dart';
import 'alerts_history_screen.dart';
import 'health_profile_view_screen.dart';
import 'guardian_setup_screen.dart';
import 'ai_doctor_screen.dart';

import 'profile/profile_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final _api = ApiService();
  final _auth = AuthService();
  final _riskProvider = RiskScoreProvider();
  bool _loading = true;
  int _selectedNavIndex = 0;
  bool _backendReachable = true;
  String? _profileImagePath;

  @override
  void initState() {
    super.initState();
    _riskProvider.addListener(_onRiskUpdate);
    _loadData();
  }

  @override
  void dispose() {
    _riskProvider.removeListener(_onRiskUpdate);
    super.dispose();
  }

  void _onRiskUpdate() {
    if (mounted) setState(() {});
  }

  Future<void> _loadData() async {
    // 1. Check Backend Connectivity first
    try {
      final isUp = await _api.checkHealth().timeout(
        const Duration(seconds: 3),
        onTimeout: () => false,
      );
      if (mounted) setState(() => _backendReachable = isUp);
    } catch (e) {
      if (mounted) setState(() => _backendReachable = false);
    }

    // 2. Refresh risk score via provider (reactive)
    try {
      await _riskProvider.refresh();
    } catch (_) {}

    // 3. Load profile image
    try {
      final prefs = await SharedPreferences.getInstance();
      String? userPhone = _auth.currentUser?.phone;
      
      // Fallback: Read from SharedPreferences directly if currentUser isn't ready
      if (userPhone == null || userPhone.isEmpty) {
        final userDataStr = prefs.getString('user_data');
        if (userDataStr != null) {
          final userData = jsonDecode(userDataStr) as Map<String, dynamic>;
          userPhone = userData['phone'] as String?;
        }
      }

      if (userPhone != null && userPhone.isNotEmpty) {
        final path = prefs.getString('profile_image_$userPhone');
        if (path != null && File(path).existsSync()) {
          if (mounted) setState(() => _profileImagePath = path);
        } else {
          if (mounted) setState(() => _profileImagePath = null);
        }
      } else {
         if (mounted) setState(() => _profileImagePath = null);
      }
    } catch (_) {}

    if (mounted) setState(() => _loading = false);
  }



  void _onNavTap(int index) {
    if (index == _selectedNavIndex) return;
    setState(() => _selectedNavIndex = index);
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && _selectedNavIndex != 0) {
          // Not on Home tab — switch to Home instead of exiting
          setState(() => _selectedNavIndex = 0);
        }
      },
      child: Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        // Use IndexedStack to preserve state of all tabs
        body: IndexedStack(
          index: _selectedNavIndex,
          children: [
            _buildHomeTab(), // 0: Home
            const AiDoctorScreen(), // 1: AI Doctor
            const SosScreen(), // 2: SOS
            const HealthProfileViewScreen(), // 3: Health
          ],
        ),
        bottomNavigationBar: NavigationBar(
          selectedIndex: _selectedNavIndex,
          onDestinationSelected: _onNavTap,
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.dashboard_rounded),
              label: 'Home',
            ),
            NavigationDestination(
              icon: Icon(Icons.medical_services_rounded),
              label: 'AI Doctor',
            ),
            NavigationDestination(
              icon: Icon(Icons.emergency_rounded),
              label: 'SOS',
            ),
            NavigationDestination(
              icon: Icon(Icons.favorite_rounded),
              label: 'Health',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHomeTab() {
    final user = _auth.currentUser;

    return SafeArea(
      child: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadData,
              child: CustomScrollView(
                slivers: [
                  // Offline Banner
                  if (!_backendReachable)
                    SliverToBoxAdapter(
                      child: Container(
                        color: Colors.red.withValues(alpha: 0.1),
                        padding: const EdgeInsets.symmetric(
                          vertical: 8,
                          horizontal: 16,
                        ),
                        child: Row(
                          children: const [
                            Icon(
                              Icons.wifi_off_rounded,
                              color: Colors.red,
                              size: 20,
                            ),
                            SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                "Backend Offline. Check Connection/Firewall.",
                                style: TextStyle(
                                  color: Colors.red,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                  // App Bar
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Welcome back,',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurface
                                        .withValues(alpha: 0.5),
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  user?.name ?? 'User',
                                  style: const TextStyle(
                                    fontSize: 24,
                                    fontWeight: FontWeight.w800,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                          GestureDetector(
                            onTap: () async {
                              await Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => const ProfileScreen(),
                                ),
                              );
                              _loadData(); // reload image after coming back
                            },
                            child: Container(
                              width: 42,
                              height: 42,
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [
                                    Color(0xFF4FC3F7),
                                    Color(0xFF0288D1),
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(14),
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(0xFF4FC3F7)
                                        .withValues(alpha: 0.3),
                                    blurRadius: 8,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                                image: _profileImagePath != null
                                    ? DecorationImage(
                                        image: FileImage(
                                          File(_profileImagePath!),
                                        ),
                                        fit: BoxFit.cover,
                                      )
                                    : null,
                              ),
                              child: _profileImagePath == null
                                  ? Center(
                                      child: Text(
                                        (user?.name ?? 'U')[0].toUpperCase(),
                                        style: const TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.w700,
                                          color: Colors.white,
                                        ),
                                      ),
                                    )
                                  : null,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Role badge
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(24, 8, 24, 0),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(
                                0xFF4FC3F7,
                              ).withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              user?.role.name.toUpperCase() ?? 'USER',
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF4FC3F7),
                                letterSpacing: 1,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Risk indicator
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 24),
                      child: Column(
                        children: [
                          GestureDetector(
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) =>
                                    const AlertsHistoryScreen(),
                              ),
                            ),
                            child: RiskIndicator(score: _riskProvider.score),
                          ),
                          const SizedBox(height: 12),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 48),
                            child: Text(
                              _riskProvider.details,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 13,
                                color: Theme.of(
                                  context,
                                ).colorScheme.onSurface.withValues(alpha: 0.5),
                                height: 1.5,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Section title
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(24, 0, 24, 12),
                      child: Text(
                        'Quick Actions',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                      ),
                    ),
                  ),

                  // Dashboard cards grid — responsive aspect ratio
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                    sliver: SliverLayoutBuilder(
                      builder: (context, constraints) {
                        final availableWidth = constraints.crossAxisExtent;
                        final textScale = MediaQuery.textScalerOf(
                          context,
                        ).scale(1.0);

                        // Responsive crossAxisCount
                        final crossAxisCount = availableWidth > 900
                            ? 4
                            : availableWidth > 600
                            ? 3
                            : 2;

                        // Screen-height-based aspect ratio:
                        // Small devices (< 700px) → 0.80 (taller cards)
                        // Medium devices           → 0.85
                        // Large devices            → 0.90
                        final screenHeight = MediaQuery.of(context).size.height;
                        double baseRatio;
                        if (screenHeight < 700) {
                          baseRatio = 0.80;
                        } else if (screenHeight < 850) {
                          baseRatio = 0.85;
                        } else {
                          baseRatio = 0.90;
                        }
                        // Further shrink ratio when font scale > 1 (taller tiles)
                        final aspectRatio = (baseRatio / textScale).clamp(
                          0.65,
                          1.0,
                        );

                        return SliverGrid(
                          gridDelegate:
                              SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: crossAxisCount,
                                mainAxisSpacing: 12,
                                crossAxisSpacing: 12,
                                childAspectRatio: aspectRatio,
                              ),
                          delegate: SliverChildBuilderDelegate((
                            context,
                            index,
                          ) {
                            final card = _cards[index];
                            return DashboardCard(
                              icon: card.icon,
                              title: card.title,
                              subtitle: card.subtitle,
                              color: card.color,
                              onTap: card.onTap,
                              index: index,
                            );
                          }, childCount: _cards.length),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  // ── Helper to build card data ────────────────────────
  List<_DashCardData> get _cards {
    final user = _auth.currentUser;
    final base = [
      _DashCardData(
        icon: Icons.sms_rounded,
        title: 'SMS Analyzer',
        subtitle: 'Scan messages for fraud & scams',
        color: const Color(0xFF7C4DFF),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const SmsAnalyzerScreen()),
        ),
      ),
      _DashCardData(
        title: 'Call Protection',
        subtitle: 'Identify spam calls',
        icon: Icons.phone_callback_rounded,
        color: const Color(0xFF5C6BC0),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const CallProtectionScreen()),
        ),
      ),
      _DashCardData(
        icon: Icons.emergency_rounded,
        title: 'SOS Emergency',
        subtitle: 'Alert emergency contacts',
        color: const Color(0xFFEF5350),
        onTap: () => setState(() => _selectedNavIndex = 2),
      ),
      _DashCardData(
        icon: Icons.notification_important_rounded,
        title: 'Safety Alerts',
        subtitle: 'History of detected threats',
        color: const Color(0xFFFFB300),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const AlertsHistoryScreen()),
        ),
      ),

      _DashCardData(
        icon: Icons.favorite_rounded,
        title: 'My Health',
        subtitle: 'Vitals, profile & wellness',
        color: const Color(0xFFEC407A),
        onTap: () => setState(() => _selectedNavIndex = 3),
      ),
      _DashCardData(
        icon: Icons.medical_services_rounded,
        title: 'AI Doctor',
        subtitle: 'Voice assistant & health tools',
        color: const Color(0xFF26A69A),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const AiDoctorScreen()),
        ),
      ),
    ];

    if (user?.role.name == 'admin') {
      base.add(
        _DashCardData(
          icon: Icons.admin_panel_settings_rounded,
          title: 'Manage Users',
          subtitle: 'User accounts & permissions',
          color: const Color(0xFFFF7043),
          onTap: () {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: const Text('Admin panel coming soon'),
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            );
          },
        ),
      );
    }

    // Guardian Features
    base.add(
      _DashCardData(
        icon: Icons.shield_rounded,
        title: 'Guardian Setup',
        subtitle: 'Add trusted contacts',
        color: const Color(0xFF8D6E63),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const GuardianSetupScreen()),
        ),
      ),
    );

    // DEBUG: Simulate SOS Button (Windows Testing)
    // Commented out — re-enable when needed for testing
    // base.add(
    //   _DashCardData(
    //     icon: Icons.bug_report_rounded,
    //     title: 'Simulate SOS',
    //     subtitle: 'Test SOS Logic (Debug)',
    //     color: Colors.grey,
    //     onTap: () async {
    //       // Simulate the flow without native calls
    //       final service = EmergencyService();
    //       try {
    //         await service.triggerSOS();
    //       } catch (e) {
    //         ScaffoldMessenger.of(context).showSnackBar(
    //           SnackBar(
    //             content: Text(
    //               "SOS Triggered (Native failed as expected on Win): $e",
    //             ),
    //           ),
    //         );
    //       }
    //     },
    //   ),
    // );

    return base;
  }
}

class _DashCardData {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback? onTap;

  _DashCardData({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    this.onTap,
  });
}
