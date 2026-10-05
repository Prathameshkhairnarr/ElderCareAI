import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/alert_model.dart';
import '../services/api_service.dart';
import 'guardian_settings_screen.dart';
import 'elder_detail_screen.dart';
import 'guardian_task_assign_screen.dart';

class ChildStatsModel {
  final int id;
  final String childName;
  final String childPhone;
  final int screenTimeMins;
  final String locationStatus;
  final int unreadAlerts;
  ChildStatsModel({required this.id, required this.childName, required this.childPhone, required this.screenTimeMins, required this.locationStatus, required this.unreadAlerts});
}

class GuardianDashboardScreen extends StatefulWidget {
  const GuardianDashboardScreen({Key? key}) : super(key: key);
  @override
  State<GuardianDashboardScreen> createState() => _GuardianDashboardScreenState();
}

class _GuardianDashboardScreenState extends State<GuardianDashboardScreen> with SingleTickerProviderStateMixin {
  final ApiService _api = ApiService();
  List<ElderStatsModel>? _elders;
  List<AlertModel> _allAlerts = [];
  Map<int, Map<String, dynamic>> _elderVitals = {};
  Map<String, dynamic>? _taskSummary;
  bool _isLoading = true;
  int _bottomNavIndex = 0;
  Timer? _refreshTimer;
  late TabController _tabController;

  final List<ChildStatsModel> _children = [
    ChildStatsModel(id: 101, childName: "Rohan", childPhone: "+91 9876543210", screenTimeMins: 145, locationStatus: "At School", unreadAlerts: 0),
    ChildStatsModel(id: 102, childName: "Priya", childPhone: "+91 9123456780", screenTimeMins: 82, locationStatus: "At Home", unreadAlerts: 1),
  ];

  // ── Theme (Matched with ElderCare App Theme) ──────────────────────────────
  static const _bg = Color(0xFF12122A);
  static const _surface = Color(0xFF1A1A2E);
  static const _cardBg = Color(0xFF222244);
  static const _blue = Color(0xFF4FC3F7); // Elder primary cyan
  static const _textPri = Colors.white;
  static const _textSec = Color(0xFFB0B3C1);
  static const _green = Color(0xFF00E676);
  static const _amber = Color(0xFFFFB74D);
  static const _red = Color(0xFFFF5252);
  static const _purple = Color(0xFF7C4DFF); // Elder secondary purple

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadDashboard();
    _refreshTimer = Timer.periodic(const Duration(seconds: 30), (_) => _silentRefresh());
  }

  @override
  void dispose() { _refreshTimer?.cancel(); _tabController.dispose(); super.dispose(); }

  Future<void> _loadDashboard() async {
    setState(() => _isLoading = true);
    final elders = await _api.getGuardianDashboard();
    if (!mounted) return;
    final decayed = await _applyDecay(elders);
    final alerts = <AlertModel>[];
    for (final e in decayed) alerts.addAll(e.recentAlerts);
    alerts.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    final vitals = <int, Map<String, dynamic>>{};
    for (final e in decayed) {
      try { final h = await _api.getHealthSummary(); if (h != null) vitals[e.id] = h; } catch (_) {}
    }
    
    // Stub guardian ID 1 for now
    final taskData = await _api.getGuardianAssignedTasks(1);

    if (!mounted) return;
    setState(() { _elders = decayed; _allAlerts = alerts; _elderVitals = vitals; _taskSummary = taskData; _isLoading = false; });
  }

  Future<void> _silentRefresh() async {
    final elders = await _api.getGuardianDashboard();
    if (!mounted) return;
    final decayed = await _applyDecay(elders);
    final alerts = <AlertModel>[];
    for (final e in decayed) alerts.addAll(e.recentAlerts);
    alerts.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    
    final taskData = await _api.getGuardianAssignedTasks(1);
    
    setState(() { _elders = decayed; _allAlerts = alerts; _taskSummary = taskData; });
  }

  Future<List<ElderStatsModel>> _applyDecay(List<ElderStatsModel> elders) async {
    final result = <ElderStatsModel>[];
    for (final elder in elders) {
      try {
        final risk = await _api.getElderRiskScore(elder.id);
        if (risk != null && risk.lastScamAt != null) {
          final elapsed = DateTime.now().difference(risk.lastScamAt!).inSeconds;
          double current = risk.score;
          if (elapsed > 0) { for (int i = 0; i < elapsed ~/ 30; i++) { current *= 0.8; if (current < 1) break; } }
          result.add(ElderStatsModel(id: elder.id, elderName: elder.elderName, elderPhone: elder.elderPhone, riskScore: current.round().clamp(0, 100), lastSosAt: elder.lastSosAt, unreadAlertsCount: elder.unreadAlertsCount, recentAlerts: elder.recentAlerts));
        } else { result.add(elder); }
      } catch (_) { result.add(elder); }
    }
    return result;
  }

  Color _riskColor(int s) => s < 40 ? _green : (s < 75 ? _amber : _red);
  String _riskLabel(int s) => s < 40 ? 'SAFE' : (s < 75 ? 'WARNING' : 'CRITICAL');

  String _generateAISynopsis() {
    if (_elders == null || _elders!.isEmpty) return 'No elder data available. Add elders to start monitoring.';
    final scamAlerts = _allAlerts.where((a) => a.type.toLowerCase().contains('scam')).length;
    final critical = _elders!.where((e) => e.riskScore >= 75).length;
    final safe = _elders!.where((e) => e.riskScore < 40).length;
    final parts = <String>[];
    if (safe == _elders!.length) parts.add('All elders are in safe status.');
    else if (critical > 0) parts.add('$critical elder(s) need immediate attention.');
    if (scamAlerts > 0) parts.add('$scamAlerts scam threat(s) detected recently.');
    if (_allAlerts.isNotEmpty) parts.add('${_allAlerts.length} alert(s) in the last period.');
    else parts.add('No recent alerts — everything looks calm.');
    return parts.join(' ');
  }

  Future<void> _callElder(String phone) async {
    final uri = Uri(scheme: 'tel', path: phone.replaceAll(' ', ''));
    if (await canLaunchUrl(uri)) await launchUrl(uri);
  }

  String _timeAgo(DateTime dt) {
    final d = DateTime.now().difference(dt);
    if (d.inMinutes < 1) return 'now';
    if (d.inMinutes < 60) return '${d.inMinutes}m';
    if (d.inHours < 24) return '${d.inHours}h';
    return '${d.inDays}d';
  }

  void _snack(String msg) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: _blue));

  // ── Build ─────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      body: IndexedStack(
        index: _bottomNavIndex,
        children: [
          _buildDashboardBody(),
          _buildAlertsPage(),
          const GuardianSettingsScreen(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _bottomNavIndex,
        onDestinationSelected: (i) => setState(() => _bottomNavIndex = i),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.dashboard_rounded),
            label: 'Dashboard',
          ),
          NavigationDestination(
            icon: Icon(Icons.notifications_rounded),
            label: 'Alerts',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings_rounded),
            label: 'Settings',
          ),
        ],
      ),
    );
  }

  // ── Dashboard body ────────────────────────────────────────────────────────
  Widget _buildDashboardBody() {
    return SafeArea(
      child: Column(
        children: [
          _buildHeader(),
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: _surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
            ),
            child: TabBar(
              controller: _tabController,
              indicator: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                color: _blue.withValues(alpha: 0.20),
                border: Border.all(color: _blue.withValues(alpha: 0.40)),
              ),
              dividerColor: Colors.transparent,
              labelColor: _blue,
              unselectedLabelColor: Colors.white.withValues(alpha: 0.6),
              labelStyle: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 14),
              unselectedLabelStyle: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 14),
              tabs: const [
                Tab(text: "Elders"),
                Tab(text: "Children"),
                Tab(text: "Alerts"),
              ],
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: _blue))
                : TabBarView(
                    controller: _tabController,
                    children: [
                      _buildEldersTab(),
                      _buildChildrenTab(),
                      _buildAlertsTab(),
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
          Expanded(
            child: Text(
              'Guardian Dashboard',
              style: GoogleFonts.inter(
                color: _textPri,
                fontSize: 22,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.5,
              ),
            ),
          ),
          IconButton(
            icon: Stack(
              children: [
                const Icon(Icons.notifications_outlined, color: _textSec, size: 24),
                if (_allAlerts.any((a) => !a.isRead))
                  Positioned(
                    right: 0,
                    top: 0,
                    child: Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: _red,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
              ],
            ),
            onPressed: () => setState(() => _bottomNavIndex = 1),
          ),
          const SizedBox(width: 4),
          GestureDetector(
            onTap: _loadDashboard,
            child: Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [_blue, _purple],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                border: Border.all(
                  color: _blue.withValues(alpha: 0.5),
                  width: 2,
                ),
              ),
              child: const Center(
                child: Icon(Icons.person, color: Colors.white, size: 20),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Elders Tab ────────────────────────────────────────────────────────────
  Widget _buildEldersTab() {
    if (_elders == null || _elders!.isEmpty) return _emptyState("Elders");
    return RefreshIndicator(
      onRefresh: _loadDashboard, color: _blue, backgroundColor: _surface,
      child: ListView(padding: const EdgeInsets.fromLTRB(20, 16, 20, 24), children: [
        _synopsisCard(title: "AI Synopsis", body: _generateAISynopsis(), icon: Icons.auto_awesome, color: _purple),
        const SizedBox(height: 20),
        if (_taskSummary != null) _buildTaskOverviewCard(),
        const SizedBox(height: 20),
        Text('Your Elders (${_elders!.length})', style: const TextStyle(color: _textPri, fontSize: 18, fontWeight: FontWeight.w800)),
        const SizedBox(height: 14),
        ..._elders!.map(_buildElderCard),
      ]),
    );
  }

  Widget _buildTaskOverviewCard() {
    final summary = _taskSummary!['completion_summary'] ?? {'total': 0, 'done': 0, 'pending': 0, 'missed': 0};
    final tasks = _taskSummary!['tasks'] as List? ?? [];
    final total = summary['total'] as int;
    final done = summary['done'] as int;
    final percent = total > 0 ? (done / total) : 0.0;
    
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(color: _cardBg, borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.white.withOpacity(0.05))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          const Text('Task Completion', style: TextStyle(color: _textPri, fontWeight: FontWeight.bold, fontSize: 16)),
          ElevatedButton(
            onPressed: () {
              Navigator.push(context, MaterialPageRoute(builder: (_) => const GuardianTaskAssignScreen()));
            },
            style: ElevatedButton.styleFrom(backgroundColor: _blue, minimumSize: const Size(80, 30), padding: const EdgeInsets.symmetric(horizontal: 12)),
            child: const Text('Assign New Task', style: TextStyle(fontSize: 12, color: Colors.white)),
          )
        ]),
        const SizedBox(height: 16),
        Row(children: [
          SizedBox(
            width: 60, height: 60,
            child: Stack(fit: StackFit.expand, children: [
              CircularProgressIndicator(value: percent, color: _green, backgroundColor: _surface, strokeWidth: 6),
              Center(child: Text('${(percent * 100).toInt()}%', style: const TextStyle(color: _textPri, fontWeight: FontWeight.bold, fontSize: 14))),
            ]),
          ),
          const SizedBox(width: 16),
          Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: tasks.take(3).map((t) {
              final status = t['status'] as String;
              final icon = status == 'done' ? '✅' : (status == 'pending' ? '🟡' : '🔴');
              return Padding(
                padding: const EdgeInsets.only(bottom: 4.0),
                child: Text('$icon ${t['title']} — ${status.toUpperCase()}', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: _textSec, fontSize: 12)),
              );
            }).toList(),
          )),
        ]),
      ]),
    );
  }

  Widget _synopsisCard({required String title, required String body, required IconData icon, required Color color}) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(color: color.withOpacity(0.05), borderRadius: BorderRadius.circular(20), border: Border.all(color: color.withOpacity(0.2))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [Icon(icon, color: color, size: 20), const SizedBox(width: 8), Text(title, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 15))]),
        const SizedBox(height: 12),
        Text(body, style: const TextStyle(color: _textSec, height: 1.5, fontSize: 14)),
      ]),
    );
  }

  Widget _buildElderCard(ElderStatsModel elder) {
    final rc = _riskColor(elder.riskScore);
    final rl = _riskLabel(elder.riskScore);
    final v = _elderVitals[elder.id];
    final hr = v?['heart_rate']?.toString() ?? '—';
    final steps = v?['steps']?.toString() ?? '—';
    final status = elder.lastSosAt != null ? 'SOS sent' : 'Active';

    return GestureDetector(
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ElderDetailScreen(elder: elder))),
      child: Container(
        margin: const EdgeInsets.only(bottom: 18),
        decoration: BoxDecoration(
          color: _cardBg,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.20),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Padding(padding: const EdgeInsets.all(18), child: Column(children: [
          // Avatar + Name + Badge
          Row(children: [
            Container(width: 52, height: 52, decoration: BoxDecoration(shape: BoxShape.circle, color: rc.withValues(alpha: 0.12), border: Border.all(color: rc.withValues(alpha: 0.5), width: 2)),
              child: Center(child: Text(elder.elderName.isNotEmpty ? elder.elderName[0].toUpperCase() : 'E', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: rc)))),
            const SizedBox(width: 14),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(elder.elderName, style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w700, color: _textPri)),
              const SizedBox(height: 5),
              Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3), decoration: BoxDecoration(color: rc.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(20), border: Border.all(color: rc.withValues(alpha: 0.3))),
                child: Text('$rl · Risk ${elder.riskScore}', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: rc))),
            ])),
            if (elder.unreadAlertsCount > 0)
              Container(padding: const EdgeInsets.all(7), decoration: BoxDecoration(color: _red.withValues(alpha: 0.2), shape: BoxShape.circle),
                child: Text('${elder.unreadAlertsCount}', style: const TextStyle(color: _red, fontSize: 12, fontWeight: FontWeight.bold))),
          ]),
          const SizedBox(height: 18),
          // Vitals
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _stat(Icons.favorite_rounded, 'HEART', hr == '—' ? '—' : '$hr bpm', _red),
              _stat(Icons.directions_walk_rounded, 'STEPS', steps, _blue),
              _stat(Icons.access_time_rounded, 'STATUS', status, _green),
            ],
          ),
          const SizedBox(height: 16), const Divider(color: Colors.white12), const SizedBox(height: 8),
          // Actions
          Row(children: [
            _actBtn(Icons.phone_rounded, "Call", _green, () => _callElder(elder.elderPhone)),
            const SizedBox(width: 8), _actBtn(Icons.medication_rounded, "Meds", _blue, () => _showMedsModal(elder)),
            const SizedBox(width: 8), _actBtn(Icons.notifications_active_rounded, "Remind", _amber, () => _showReminderModal(elder.elderName)),
            const SizedBox(width: 8), _actBtn(Icons.shield_rounded, "Threats", _red, () => _showThreatsModal(elder)),
          ]),
        ])),
      ),
    );
  }

  Widget _actBtn(IconData icon, String label, Color c, VoidCallback onTap) {
    return Expanded(child: GestureDetector(onTap: onTap, child: Container(
      padding: const EdgeInsets.symmetric(vertical: 11),
      decoration: BoxDecoration(color: c.withValues(alpha: 0.10), borderRadius: BorderRadius.circular(14), border: Border.all(color: c.withValues(alpha: 0.25))),
      child: Column(children: [Icon(icon, color: c, size: 18), const SizedBox(height: 4), Text(label, style: TextStyle(color: c, fontSize: 11, fontWeight: FontWeight.w700))]),
    )));
  }

  // ── Children Tab ──────────────────────────────────────────────────────────
  Widget _buildChildrenTab() {
    if (_children.isEmpty) return _emptyState("Children");
    return ListView(padding: const EdgeInsets.fromLTRB(20, 16, 20, 24), children: [
      _synopsisCard(title: "Digital Safety Report", body: "Rohan reached school safely at 7:50 AM. Screen time is within healthy limits today.", icon: Icons.family_restroom, color: _blue),
      const SizedBox(height: 20),
      const Text('Your Kids', style: TextStyle(color: _textPri, fontSize: 18, fontWeight: FontWeight.w800)),
      const SizedBox(height: 14),
      ..._children.map(_buildChildCard),
    ]);
  }

  Widget _buildChildCard(ChildStatsModel child) {
    final h = child.screenTimeMins ~/ 60, m = child.screenTimeMins % 60;
    return Container(
      margin: const EdgeInsets.only(bottom: 18),
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.20),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Padding(padding: const EdgeInsets.all(18), child: Column(children: [
        Row(children: [
          Container(width: 50, height: 50, decoration: BoxDecoration(shape: BoxShape.circle, color: _blue.withValues(alpha: 0.12), border: Border.all(color: _blue.withValues(alpha: 0.50), width: 2)),
            child: Center(child: Text(child.childName[0].toUpperCase(), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: _blue)))),
          const SizedBox(width: 14),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(child.childName, style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w700, color: _textPri)),
            const SizedBox(height: 4),
            Text(child.childPhone, style: TextStyle(fontSize: 12, color: _textSec.withValues(alpha: 0.7))),
          ])),
          Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4), decoration: BoxDecoration(color: _green.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(20), border: Border.all(color: _green.withValues(alpha: 0.3))),
            child: Text(child.locationStatus, style: const TextStyle(color: _green, fontWeight: FontWeight.bold, fontSize: 11))),
        ]),
        const SizedBox(height: 18),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _stat(Icons.timer_rounded, 'SCREEN', '${h}h ${m}m', _amber),
            _stat(Icons.location_on_rounded, 'SEEN', '10 min ago', _purple),
            _stat(Icons.shield_rounded, 'ALERTS', '${child.unreadAlerts}', _green),
          ],
        ),
        const SizedBox(height: 16), const Divider(color: Colors.white12), const SizedBox(height: 8),
        Row(children: [
          _actBtn(Icons.phonelink_lock_rounded, "Lock", _amber, () => _snack('Screen Lock Request Sent')),
          const SizedBox(width: 8), _actBtn(Icons.phone_rounded, "Call", _green, () => _callElder(child.childPhone)),
          const SizedBox(width: 8), _actBtn(Icons.chat_bubble_rounded, "Ping", _blue, () => _showReminderModal(child.childName, isChild: true)),
        ]),
      ])),
    );
  }

  // ── Alerts Tab ────────────────────────────────────────────────────────────
  Widget _buildAlertsTab() {
    if (_allAlerts.isEmpty) return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      Icon(Icons.check_circle_outline_rounded, size: 56, color: _green.withOpacity(0.5)),
      const SizedBox(height: 16), const Text('All Clear', style: TextStyle(color: _textPri, fontSize: 20, fontWeight: FontWeight.w700)),
      const SizedBox(height: 8), const Text('No alerts at this time.', style: TextStyle(color: _textSec)),
    ]));
    return ListView.builder(padding: const EdgeInsets.fromLTRB(20, 16, 20, 24), itemCount: _allAlerts.length, itemBuilder: (_, i) => _alertTile(_allAlerts[i]));
  }

  // ── Alerts Page (bottom nav) ──────────────────────────────────────────────
  Widget _buildAlertsPage() {
    return SafeArea(child: Column(children: [
      Padding(padding: const EdgeInsets.fromLTRB(20, 16, 16, 12), child: Row(children: [
        const Expanded(child: Text('All Alerts', style: TextStyle(color: _textPri, fontSize: 22, fontWeight: FontWeight.w800))),
        Text('${_allAlerts.length} total', style: const TextStyle(color: _textSec, fontSize: 13)),
      ])),
      Expanded(child: _allAlerts.isEmpty
        ? const Center(child: Text('No alerts', style: TextStyle(color: _textSec)))
        : ListView.builder(padding: const EdgeInsets.fromLTRB(20, 0, 20, 24), itemCount: _allAlerts.length, itemBuilder: (_, i) => _alertTile(_allAlerts[i]))),
    ]));
  }

  Widget _alertTile(AlertModel alert) {
    final isScam = alert.type.toLowerCase().contains('scam');
    final isSos = alert.type.toLowerCase().contains('sos');
    final color = isSos ? _red : (isScam ? _amber : _blue);
    final icon = isSos ? Icons.emergency_rounded : (isScam ? Icons.shield_rounded : Icons.info_outline_rounded);
    return Container(
      margin: const EdgeInsets.only(bottom: 12), padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: alert.isRead ? _cardBg : color.withOpacity(0.05), borderRadius: BorderRadius.circular(16), border: Border.all(color: alert.isRead ? Colors.white.withOpacity(0.04) : color.withOpacity(0.2))),
      child: Row(children: [
        Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(10)), child: Icon(icon, color: color, size: 18)),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(alert.title, style: const TextStyle(color: _textPri, fontSize: 13, fontWeight: FontWeight.w600)),
          const SizedBox(height: 3),
          Text(alert.details, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: _textSec, fontSize: 12)),
        ])),
        const SizedBox(width: 8),
        Text(_timeAgo(alert.createdAt), style: const TextStyle(color: _textSec, fontSize: 10)),
      ]),
    );
  }

  // ── Modals ────────────────────────────────────────────────────────────────
  void _showReminderModal(String name, {bool isChild = false}) {
    final con = TextEditingController();
    showModalBottomSheet(
      context: context, isScrollControlled: true, backgroundColor: _surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom + 20, left: 24, right: 24, top: 24),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text('Send Reminder to $name', style: const TextStyle(color: _textPri, fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 6),
          const Text('This will appear as a loud popup on their phone.', style: TextStyle(color: _textSec, fontSize: 12)),
          const SizedBox(height: 20),
          Wrap(spacing: 8, runSpacing: 8, children: (isChild
            ? ["Come home", "Call me", "Homework done?"]
            : ["Paani pee lo", "Dawai kha lo", "Khana kha liya?", "Call me"]
          ).map((l) => ActionChip(label: Text(l, style: const TextStyle(color: Colors.white, fontSize: 12)), backgroundColor: _blue.withOpacity(0.2), side: BorderSide(color: _blue.withOpacity(0.5)), onPressed: () => con.text = l)).toList()),
          const SizedBox(height: 16),
          TextField(controller: con, style: const TextStyle(color: Colors.white), decoration: InputDecoration(hintText: "Or type a custom message...", hintStyle: const TextStyle(color: _textSec), filled: true, fillColor: _bg, border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none))),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: () { Navigator.pop(ctx); _snack('Reminder sent: "${con.text}"'); },
            style: ElevatedButton.styleFrom(backgroundColor: _blue, padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
            child: const Text("Send Now", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
          ),
        ]),
      ),
    );
  }

  void _showMedsModal(ElderStatsModel elder) {
    showModalBottomSheet(
      context: context, backgroundColor: _surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => FutureBuilder(
        future: _api.getUserMedications(),
        builder: (_, snap) {
          if (snap.connectionState == ConnectionState.waiting) return const SizedBox(height: 200, child: Center(child: CircularProgressIndicator(color: _blue)));
          final meds = snap.data ?? [];
          return Padding(padding: const EdgeInsets.all(24), child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('${elder.elderName}\'s Medications', style: const TextStyle(color: _textPri, fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            if (meds.isEmpty) const Padding(padding: EdgeInsets.symmetric(vertical: 24), child: Center(child: Text('No medications on record.', style: TextStyle(color: _textSec))))
            else ...meds.take(5).map((m) => Container(
              margin: const EdgeInsets.only(bottom: 10), padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: _cardBg, borderRadius: BorderRadius.circular(12)),
              child: Row(children: [
                const Icon(Icons.medication_rounded, color: _blue, size: 20), const SizedBox(width: 12),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(m.medicine.name, style: const TextStyle(color: _textPri, fontWeight: FontWeight.w600, fontSize: 14)),
                  Text('${m.frequencyPerDay}x/day${m.timeOfDay != null ? ' · ${m.timeOfDay}' : ''}', style: const TextStyle(color: _textSec, fontSize: 12)),
                ])),
              ]),
            )),
          ]));
        },
      ),
    );
  }

  void _showThreatsModal(ElderStatsModel elder) {
    final threats = elder.recentAlerts.where((a) => a.type.toLowerCase().contains('scam') || a.type.toLowerCase().contains('threat')).toList();
    showDialog(context: context, builder: (ctx) => AlertDialog(
      backgroundColor: _surface, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Row(children: [
        Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: _red.withOpacity(0.2), shape: BoxShape.circle), child: const Icon(Icons.shield_rounded, color: _red, size: 20)),
        const SizedBox(width: 12), const Text('Threat Console', style: TextStyle(color: _textPri, fontSize: 18)),
      ]),
      content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text("Threats for ${elder.elderName}", style: const TextStyle(color: _textSec, fontSize: 13)),
        const SizedBox(height: 16),
        if (threats.isEmpty) Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: _green.withOpacity(0.1), borderRadius: BorderRadius.circular(12)), child: const Text('No active threats detected.', style: TextStyle(color: _green, fontSize: 13)))
        else ...threats.take(3).map((a) => Container(
          margin: const EdgeInsets.only(bottom: 8), padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: _red.withOpacity(0.08), borderRadius: BorderRadius.circular(12), border: Border.all(color: _red.withOpacity(0.2))),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(a.title, style: const TextStyle(color: _red, fontWeight: FontWeight.bold, fontSize: 12)),
            const SizedBox(height: 4), Text(a.details, style: const TextStyle(color: _textPri, fontSize: 12)),
            const SizedBox(height: 2), Text('Severity: ${a.severity.toUpperCase()}', style: const TextStyle(color: _amber, fontSize: 11)),
          ]),
        )),
      ]),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Close", style: TextStyle(color: _textSec))),
        if (threats.isNotEmpty) ElevatedButton(
          onPressed: () { Navigator.pop(ctx); _snack('Threats blocked on remote device'); },
          style: ElevatedButton.styleFrom(backgroundColor: _red),
          child: const Text("Block All", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        ),
      ],
    ));
  }

  // ── Shared widgets ────────────────────────────────────────────────────────
  Widget _stat(IconData icon, String label, String value, Color c) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: c.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 15, color: c),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: _textPri,
                ),
              ),
              Text(
                label,
                style: TextStyle(
                  fontSize: 9,
                  color: _textSec.withValues(alpha: 0.7),
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _emptyState(String type) {
    final isElder = type == "Elders";
    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 32),
      child: Center(
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 36),
          decoration: BoxDecoration(
            color: _cardBg,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.25),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _blue.withValues(alpha: 0.12),
                  border: Border.all(
                    color: _blue.withValues(alpha: 0.35),
                    width: 2,
                  ),
                ),
                child: Center(
                  child: Icon(
                    isElder ? Icons.elderly_rounded : Icons.child_care_rounded,
                    size: 40,
                    color: _blue,
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'No $type Connected',
                style: GoogleFonts.inter(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                isElder
                    ? 'Connect an elder to monitor real-time safety, fraud threats, health vitals, and emergency SOS alerts.'
                    : 'Connect a child to monitor screen time, safe locations, and send instant check-in reminders.',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  fontSize: 14,
                  height: 1.5,
                  color: Colors.white.withValues(alpha: 0.65),
                ),
              ),
              const SizedBox(height: 26),
              ElevatedButton.icon(
                onPressed: isElder ? _showAddElderDialog : null,
                icon: const Icon(Icons.add_rounded, size: 20),
                label: Text(isElder ? 'Add / Link Elder' : 'Add Child'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _blue,
                  foregroundColor: const Color(0xFF12122A),
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  elevation: 0,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showAddElderDialog() {
    final phoneController = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: _blue.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.person_add_rounded, color: _blue, size: 22),
            ),
            const SizedBox(width: 12),
            Text(
              'Link Elder',
              style: GoogleFonts.inter(
                color: _textPri,
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Enter the registered phone number of the elder (e.g. 9876500003).',
              style: GoogleFonts.inter(
                color: _textSec,
                fontSize: 13,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: phoneController,
              keyboardType: TextInputType.phone,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: "Phone number (10 digits)",
                hintStyle: TextStyle(color: _textSec.withValues(alpha: 0.6)),
                filled: true,
                fillColor: _bg,
                prefixIcon: const Icon(Icons.phone_rounded, color: _blue, size: 20),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: _blue, width: 1.5),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel', style: TextStyle(color: _textSec)),
          ),
          ElevatedButton(
            onPressed: () async {
              final phone = phoneController.text.trim();
              if (phone.length < 10) {
                _snack('Please enter a valid 10-digit phone number');
                return;
              }
              Navigator.pop(ctx);
              _snack('Linking elder account...');
              await _loadDashboard();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: _blue,
              foregroundColor: const Color(0xFF12122A),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Connect', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}
