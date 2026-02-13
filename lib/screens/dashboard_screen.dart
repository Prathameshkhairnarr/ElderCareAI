import 'package:flutter/material.dart';
import '../models/risk_model.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../widgets/dashboard_card.dart';
import '../widgets/risk_indicator.dart';
import '../widgets/page_transition.dart';
import 'login_screen.dart';
import 'sms_analyzer_screen.dart';
import 'sos_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final _api = ApiService();
  final _auth = AuthService();
  RiskModel? _risk;
  bool _loading = true;
  int _selectedNavIndex = 0;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final risk = await _api.getRiskScore();
    if (!mounted) return;
    setState(() {
      _risk = risk;
      _loading = false;
    });
  }

  void _logout() {
    _auth.logout();
    Navigator.of(context).pushAndRemoveUntil(
      PageTransition(page: const LoginScreen()),
      (route) => false,
    );
  }

  List<_DashCardData> get _cards {
    final user = _auth.currentUser;
    final base = [
      _DashCardData(
        icon: Icons.sms_rounded,
        title: 'SMS Analyzer',
        subtitle: 'Scan messages for fraud & scams',
        color: const Color(0xFF7C4DFF),
        onTap: () => Navigator.of(
          context,
        ).push(PageTransition(page: const SmsAnalyzerScreen())),
      ),
      _DashCardData(
        icon: Icons.emergency_rounded,
        title: 'SOS Emergency',
        subtitle: 'Quick alert to emergency contacts',
        color: const Color(0xFFEF5350),
        onTap: () =>
            Navigator.of(context).push(PageTransition(page: const SosScreen())),
      ),
      _DashCardData(
        icon: Icons.monitor_heart_rounded,
        title: 'Health Monitor',
        subtitle: 'Track daily vitals & wellness',
        color: const Color(0xFF26A69A),
      ),
    ];

    if (user?.role.name == 'admin') {
      base.add(
        _DashCardData(
          icon: Icons.admin_panel_settings_rounded,
          title: 'Manage Users',
          subtitle: 'User accounts & permissions',
          color: const Color(0xFFFF7043),
        ),
      );
    } else if (user?.role.name == 'caregiver') {
      base.add(
        _DashCardData(
          icon: Icons.people_rounded,
          title: 'My Patients',
          subtitle: 'View assigned elder profiles',
          color: const Color(0xFF42A5F5),
        ),
      );
    } else {
      base.add(
        _DashCardData(
          icon: Icons.favorite_rounded,
          title: 'My Health',
          subtitle: 'Personal health summary',
          color: const Color(0xFFEC407A),
        ),
      );
    }

    return base;
  }

  @override
  Widget build(BuildContext context) {
    final user = _auth.currentUser;
    final screenWidth = MediaQuery.of(context).size.width;
    final crossAxisCount = screenWidth > 900 ? 4 : 2;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : RefreshIndicator(
                onRefresh: _loadData,
                child: CustomScrollView(
                  slivers: [
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
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              decoration: BoxDecoration(
                                color: Theme.of(
                                  context,
                                ).colorScheme.surfaceContainerHighest,
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: IconButton(
                                onPressed: _logout,
                                icon: const Icon(
                                  Icons.logout_rounded,
                                  size: 20,
                                ),
                                tooltip: 'Logout',
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
                        padding: const EdgeInsets.symmetric(vertical: 32),
                        child: Column(
                          children: [
                            if (_risk != null)
                              RiskIndicator(score: _risk!.score),
                            const SizedBox(height: 12),
                            if (_risk != null)
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 48,
                                ),
                                child: Text(
                                  _risk!.details,
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurface
                                        .withValues(alpha: 0.5),
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

                    // Dashboard cards grid
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                      sliver: SliverGrid(
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: crossAxisCount,
                          mainAxisSpacing: 12,
                          crossAxisSpacing: 12,
                          childAspectRatio: 1.1,
                        ),
                        delegate: SliverChildBuilderDelegate((context, index) {
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
                      ),
                    ),
                  ],
                ),
              ),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedNavIndex,
        onDestinationSelected: (index) {
          setState(() => _selectedNavIndex = index);
          if (index == 1) {
            Navigator.of(
              context,
            ).push(PageTransition(page: const SmsAnalyzerScreen()));
          } else if (index == 2) {
            Navigator.of(context).push(PageTransition(page: const SosScreen()));
          }
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.dashboard_rounded),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.sms_rounded),
            label: 'SMS Scan',
          ),
          NavigationDestination(
            icon: Icon(Icons.emergency_rounded),
            label: 'SOS',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings_rounded),
            label: 'Settings',
          ),
        ],
      ),
    );
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
