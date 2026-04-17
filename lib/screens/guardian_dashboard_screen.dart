import 'dart:async';
import 'package:flutter/material.dart';
import '../models/alert_model.dart';
import '../services/api_service.dart';
import 'guardian_settings_screen.dart';
import 'elder_detail_screen.dart';

class ChildStatsModel {
  final int id;
  final String childName;
  final String childPhone;
  final int screenTimeMins;
  final String locationStatus;
  final int unreadAlerts;

  ChildStatsModel({
    required this.id,
    required this.childName,
    required this.childPhone,
    required this.screenTimeMins,
    required this.locationStatus,
    required this.unreadAlerts,
  });
}

class GuardianDashboardScreen extends StatefulWidget {
  const GuardianDashboardScreen({Key? key}) : super(key: key);

  @override
  State<GuardianDashboardScreen> createState() =>
      _GuardianDashboardScreenState();
}

class _GuardianDashboardScreenState extends State<GuardianDashboardScreen>
    with SingleTickerProviderStateMixin {
  final ApiService _apiService = ApiService();
  
  List<ElderStatsModel>? _elders;
  final List<ChildStatsModel> _children = [
    // Mock child data
    ChildStatsModel(
      id: 101, 
      childName: "Rohan", 
      childPhone: "+91 9876543210", 
      screenTimeMins: 145, 
      locationStatus: "At School", 
      unreadAlerts: 0
    ),
  ];

  bool _isLoading = true;
  int _selectedIndex = 0;
  Timer? _refreshTimer;
  late TabController _tabController;

  // ── Theme tokens ──────────────────────────────────────────────────────────
  static const _bg       = Color(0xFF0D0F1F);
  static const _surface  = Color(0xFF1A1D2E);
  static const _cardBg   = Color(0xFF151829);
  static const _blue     = Color(0xFF3B82F6);
  static const _textPri  = Colors.white;
  static const _textSec  = Color(0xFFB0B3C1);
  static const _green    = Color(0xFF22C55E);
  static const _amber    = Color(0xFFF59E0B);
  static const _red      = Color(0xFFEF4444);
  static const _purple   = Color(0xFF8B5CF6);

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadDashboard();
    _refreshTimer = Timer.periodic(
      const Duration(seconds: 30),
      (_) => _silentRefresh(),
    );
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadDashboard() async {
    setState(() => _isLoading = true);
    final elders = await _apiService.getGuardianDashboard();
    if (!mounted) return;
    final decayed = await _applyDecayToElders(elders);
    setState(() {
      _elders = decayed;
      _isLoading = false;
    });
  }

  Future<void> _silentRefresh() async {
    final elders = await _apiService.getGuardianDashboard();
    if (!mounted) return;
    final decayed = await _applyDecayToElders(elders);
    setState(() => _elders = decayed);
  }

  Future<List<ElderStatsModel>> _applyDecayToElders(List<ElderStatsModel> elders) async {
    final List<ElderStatsModel> result = [];
    for (final elder in elders) {
      try {
        final risk = await _apiService.getElderRiskScore(elder.id);
        if (risk != null && risk.lastScamAt != null) {
          final elapsed = DateTime.now().difference(risk.lastScamAt!).inSeconds;
          double current = risk.score;
          if (elapsed > 0) {
            final loops = elapsed ~/ 30;
            for (int i = 0; i < loops; i++) {
              current = current * 0.8;
              if (current < 1) break;
            }
          }
          final decayedScore = current.round().clamp(0, 100);
          
          result.add(ElderStatsModel(
            id: elder.id,
            elderName: elder.elderName,
            elderPhone: elder.elderPhone,
            riskScore: decayedScore,
            lastSosAt: elder.lastSosAt,
            unreadAlertsCount: elder.unreadAlertsCount,
            recentAlerts: elder.recentAlerts,
          ));
        } else {
          result.add(elder);
        }
      } catch (_) {
        result.add(elder);
      }
    }
    return result;
  }

  Color _riskColor(int score) {
    if (score < 40) return _green;
    if (score < 75) return _amber;
    return _red;
  }

  String _riskLabel(int score) {
    if (score < 40) return 'SAFE';
    if (score < 75) return 'WARNING';
    return 'CRITICAL';
  }

  // ── Build ─────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      body: IndexedStack(
        index: _selectedIndex,
        children: [
          _buildHomeContent(),
          const GuardianSettingsScreen(),
        ],
      ),
      bottomNavigationBar: _buildBottomNav(),
    );
  }

  // ── Bottom nav ────────────────────────────────────────────────────────────
  Widget _buildBottomNav() {
    return Container(
      decoration: BoxDecoration(
        color: _surface,
        border: Border(top: BorderSide(color: Colors.white.withOpacity(0.07))),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _navItem(0, Icons.dashboard_rounded, 'DASHBOARD'),
              _navItem(1, Icons.settings_rounded, 'SETTINGS'),
            ],
          ),
        ),
      ),
    );
  }

  Widget _navItem(int index, IconData icon, String label) {
    final active = _selectedIndex == index;
    return GestureDetector(
      onTap: () => setState(() => _selectedIndex = index),
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 22, color: active ? _blue : _textSec),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              color: active ? _blue : _textSec,
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }

  // ── Home content & Tabs ───────────────────────────────────────────────────
  Widget _buildHomeContent() {
    return SafeArea(
      child: Column(
        children: [
          _buildHeader(),
          TabBar(
            controller: _tabController,
            indicatorColor: _blue,
            indicatorWeight: 3,
            labelColor: _blue,
            unselectedLabelColor: _textSec,
            labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            tabs: const [
              Tab(text: "Elders"),
              Tab(text: "Children"),
            ],
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: _blue))
                : TabBarView(
                    controller: _tabController,
                    children: [
                      _buildEldersTab(),
                      _buildChildrenTab(),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 16, 8),
      child: Row(
        children: [
          GestureDetector(onTap: _loadDashboard, child: const Icon(Icons.refresh_rounded, color: _textSec, size: 20)),
          const SizedBox(width: 10),
          const Expanded(child: Text('CareWatch', style: TextStyle(color: _textPri, fontSize: 24, fontWeight: FontWeight.w800, letterSpacing: -0.5))),
          Container(
            width: 36, height: 36,
            decoration: BoxDecoration(shape: BoxShape.circle, gradient: LinearGradient(colors: [_blue, _blue.withOpacity(0.6)]), border: Border.all(color: _blue.withOpacity(0.4), width: 2)),
            child: const Center(child: Icon(Icons.person, color: Colors.white, size: 18)),
          ),
        ],
      ),
    );
  }

  // ── ELDERS TAB ────────────────────────────────────────────────────────────
  Widget _buildEldersTab() {
    if (_elders == null || _elders!.isEmpty) return _buildEmptyState("Elders");

    return RefreshIndicator(
      onRefresh: _loadDashboard,
      color: _blue, backgroundColor: _surface,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        children: [
          _buildAISynopsisCard(
            title: "AI Weekly Synopsis",
            body: "Dad's vitals are stable, but he missed his afternoon walk yesterday. 2 Spam calls were intercepted and blocked this week.",
            icon: Icons.auto_awesome,
            color: _purple,
          ),
          const SizedBox(height: 24),
          const Text('Your Elders', style: TextStyle(color: _textPri, fontSize: 18, fontWeight: FontWeight.w800)),
          const SizedBox(height: 14),
          ..._elders!.map(_buildElderCard),
        ],
      ),
    );
  }

  Widget _buildAISynopsisCard({required String title, required String body, required IconData icon, required Color color}) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: color.withOpacity(0.05),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(width: 8),
              Text(title, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 16)),
            ],
          ),
          const SizedBox(height: 12),
          Text(body, style: const TextStyle(color: _textSec, height: 1.5, fontSize: 14)),
        ],
      ),
    );
  }

  Widget _buildElderCard(ElderStatsModel elder) {
    final rColor = _riskColor(elder.riskScore);
    final rLabel = _riskLabel(elder.riskScore);
    final hasSos = elder.lastSosAt != null;

    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(color: _cardBg, borderRadius: BorderRadius.circular(22), border: Border.all(color: Colors.white.withOpacity(0.05))),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  width: 48, height: 48,
                  decoration: BoxDecoration(shape: BoxShape.circle, color: rColor.withOpacity(0.10), border: Border.all(color: rColor.withOpacity(0.50), width: 2.5)),
                  child: Center(child: Text(elder.elderName.isNotEmpty ? elder.elderName[0].toUpperCase() : 'E', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: rColor))),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(elder.elderName, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: _textPri)),
                      const SizedBox(height: 5),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(color: rColor.withOpacity(0.15), borderRadius: BorderRadius.circular(6)),
                            child: Text('$rLabel ${elder.riskScore}', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: rColor, letterSpacing: 0.3)),
                          ),
                          const SizedBox(width: 8),
                          Text('ID: #${elder.id.toString().padLeft(5, '0')}', style: TextStyle(fontSize: 11, color: _textSec.withOpacity(0.6), fontWeight: FontWeight.w500)),
                        ],
                      ),
                    ],
                  ),
                ),
                IconButton(icon: const Icon(Icons.open_in_new_rounded, color: _textSec, size: 20), onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ElderDetailScreen(elder: elder)))),
              ],
            ),
            const SizedBox(height: 20),
            
            // Stats Row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _miniStat(Icons.directions_walk_rounded, 'STEPS', '4,200', _blue),
                _vertDivider(),
                _miniStat(Icons.favorite_rounded, 'HEART', '72 bpm', _red),
                _vertDivider(),
                _miniStat(Icons.access_time_rounded, 'ACTIVE', hasSos ? 'SOS sent' : 'Just now', _green),
              ],
            ),
            const SizedBox(height: 16),
            const Divider(color: Colors.white10),
            const SizedBox(height: 8),

            // Action Center
            Row(
              children: [
                Expanded(child: _buildActionButton(icon: Icons.chat_bubble_rounded, label: "Reminder", color: _blue, onTap: () => _showReminderModal(elder.elderName))),
                const SizedBox(width: 10),
                Expanded(child: _buildActionButton(icon: Icons.security_rounded, label: "Threat Block", color: _amber, filled: true, onTap: () => _showScamBlockModal(elder.elderName))),
                const SizedBox(width: 10),
                Expanded(child: _buildActionButton(icon: Icons.medication_rounded, label: "Meds", color: _green, onTap: () {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Opening Remote Vitals & Medication Updater...')));
                })),
              ],
            )
          ],
        ),
      ),
    );
  }

  Widget _buildActionButton({required IconData icon, required String label, required Color color, bool filled = false, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: filled ? color.withOpacity(0.15) : Colors.transparent,
          border: Border.all(color: filled ? Colors.transparent : color.withOpacity(0.3)),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 18),
            const SizedBox(height: 4),
            Text(label, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }

  // ── CHILDREN TAB ──────────────────────────────────────────────────────────
  Widget _buildChildrenTab() {
    if (_children.isEmpty) return _buildEmptyState("Children");

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      children: [
        _buildAISynopsisCard(
            title: "Digital Safety Report",
            body: "Rohan reached school safely at 7:50 AM. Screen time is within the healthy limit so far today.",
            icon: Icons.family_restroom,
            color: _blue,
          ),
        const SizedBox(height: 24),
        const Text('Your Kids', style: TextStyle(color: _textPri, fontSize: 18, fontWeight: FontWeight.w800)),
        const SizedBox(height: 14),
        ..._children.map(_buildChildCard),
      ],
    );
  }

  Widget _buildChildCard(ChildStatsModel child) {
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(color: _cardBg, borderRadius: BorderRadius.circular(22), border: Border.all(color: Colors.white.withOpacity(0.05))),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  width: 48, height: 48,
                  decoration: BoxDecoration(shape: BoxShape.circle, color: _blue.withOpacity(0.10), border: Border.all(color: _blue.withOpacity(0.50), width: 2.5)),
                  child: Center(child: Text(child.childName[0].toUpperCase(), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: _blue))),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(child.childName, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: _textPri)),
                      const SizedBox(height: 5),
                      Text(child.childPhone, style: TextStyle(fontSize: 12, color: _textSec.withOpacity(0.6))),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(color: _green.withOpacity(0.1), borderRadius: BorderRadius.circular(20)),
                  child: Text(child.locationStatus, style: const TextStyle(color: _green, fontWeight: FontWeight.bold, fontSize: 11)),
                )
              ],
            ),
            const SizedBox(height: 20),
            
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _miniStat(Icons.timer_rounded, 'SCREEN TIME', '${child.screenTimeMins ~/ 60}h ${child.screenTimeMins % 60}m', _amber),
                _vertDivider(),
                _miniStat(Icons.location_on_rounded, 'LAST SEEN', '10 mins ago', _purple),
              ],
            ),
            const SizedBox(height: 16),
            const Divider(color: Colors.white10),
            const SizedBox(height: 8),

            Row(
              children: [
                Expanded(child: _buildActionButton(icon: Icons.phonelink_lock_rounded, label: "Screen Lock", color: _amber, onTap: () {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Screen Lock Request Sent')));
                })),
                const SizedBox(width: 10),
                Expanded(child: _buildActionButton(icon: Icons.chat_bubble_rounded, label: "Ping", color: _blue, onTap: () {
                  _showReminderModal(child.childName, isChild: true);
                })),
              ],
            )
          ],
        ),
      ),
    );
  }

  // ── MODALS ────────────────────────────────────────────────────────────────
  void _showReminderModal(String name, {bool isChild = false}) {
    final TextEditingController con = TextEditingController();
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: _surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom + 20, left: 24, right: 24, top: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Send Ping to $name', style: const TextStyle(color: _textPri, fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            Text('This will appear as a loud popup on their phone.', style: TextStyle(color: _textSec, fontSize: 12)),
            const SizedBox(height: 20),
            
            Wrap(
              spacing: 8, runSpacing: 8,
              children: isChild 
                ? [
                    _quickPingChip("Come home", con),
                    _quickPingChip("Call me", con),
                    _quickPingChip("Homework done?", con),
                  ]
                : [
                    _quickPingChip("Paani pee lo", con),
                    _quickPingChip("Dawai kha lo", con),
                    _quickPingChip("Khana kha liya?", con),
                    _quickPingChip("Call me", con),
                  ],
            ),
            const SizedBox(height: 16),
            TextField(
              controller: con,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: "Or type a custom message...",
                hintStyle: TextStyle(color: _textSec),
                filled: true, fillColor: _bg,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Ping Sent: "${con.text}"'), backgroundColor: _green));
              },
              style: ElevatedButton.styleFrom(backgroundColor: _blue, padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
              child: const Text("Send Ping Now", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
            )
          ],
        ),
      )
    );
  }

  Widget _quickPingChip(String label, TextEditingController controller) {
    return ActionChip(
      label: Text(label, style: const TextStyle(color: Colors.white, fontSize: 12)),
      backgroundColor: _blue.withOpacity(0.2),
      side: BorderSide(color: _blue.withOpacity(0.5)),
      onPressed: () => controller.text = label,
    );
  }

  void _showScamBlockModal(String name) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: _amber.withOpacity(0.2), shape: BoxShape.circle), child: const Icon(Icons.security_rounded, color: _amber, size: 20)),
            const SizedBox(width: 12),
            const Text('Threat Console', style: TextStyle(color: _textPri, fontSize: 18)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Recent suspicious activity for $name", style: TextStyle(color: _textSec, fontSize: 13)),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: _red.withOpacity(0.1), borderRadius: BorderRadius.circular(12), border: Border.all(color: _red.withOpacity(0.3))),
              child: const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text("Detected SMS Link", style: TextStyle(color: _red, fontWeight: FontWeight.bold, fontSize: 12)),
                SizedBox(height: 4),
                Text("URL: http://lottery-winner-shady.com", style: TextStyle(color: Colors.white, fontSize: 13)),
                SizedBox(height: 2),
                Text("Risk Level: HIGH", style: TextStyle(color: _red, fontSize: 11)),
              ]),
            )
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Ignore", style: TextStyle(color: _textSec))),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Threat Blocked Successfully on Remote Device'), backgroundColor: _amber));
            },
            style: ElevatedButton.styleFrom(backgroundColor: _amber),
            child: const Text("Scan & Block Server", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
          )
        ],
      )
    );
  }

  // ── HELPERS ───────────────────────────────────────────────────────────────
  Widget _miniStat(IconData icon, String label, String value, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: color.withOpacity(0.7)),
        const SizedBox(width: 6),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(value, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: _textPri)),
            Text(label, style: TextStyle(fontSize: 9, color: _textSec.withOpacity(0.6), fontWeight: FontWeight.w600, letterSpacing: 0.5)),
          ],
        ),
      ],
    );
  }

  Widget _vertDivider() => Container(height: 28, width: 0.5, color: Colors.white.withOpacity(0.08));

  Widget _buildEmptyState(String type) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(type == "Elders" ? Icons.elderly_rounded : Icons.child_care_rounded, size: 56, color: _blue.withOpacity(0.5)),
          const SizedBox(height: 24),
          Text('No $type Added', style: const TextStyle(color: _textPri, fontSize: 20, fontWeight: FontWeight.w700)),
          const SizedBox(height: 12),
          Text('You are currently not tracking any $type profile.', style: const TextStyle(color: _textSec)),
        ],
      ),
    );
  }
}
