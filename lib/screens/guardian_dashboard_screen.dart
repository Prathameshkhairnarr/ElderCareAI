import 'dart:async';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
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
  bool _isLoading = true;
  int _bottomNavIndex = 0;
  Timer? _refreshTimer;
  late TabController _tabController;

  final List<ChildStatsModel> _children = [
    ChildStatsModel(id: 101, childName: "Rohan", childPhone: "+91 9876543210", screenTimeMins: 145, locationStatus: "At School", unreadAlerts: 0),
    ChildStatsModel(id: 102, childName: "Priya", childPhone: "+91 9123456780", screenTimeMins: 82, locationStatus: "At Home", unreadAlerts: 1),
  ];

  // ── Theme ─────────────────────────────────────────────────────────────────
  static const _bg = Color(0xFF0D0F1F);
  static const _surface = Color(0xFF1A1D2E);
  static const _cardBg = Color(0xFF151829);
  static const _blue = Color(0xFF3B82F6);
  static const _textPri = Colors.white;
  static const _textSec = Color(0xFFB0B3C1);
  static const _green = Color(0xFF22C55E);
  static const _amber = Color(0xFFF59E0B);
  static const _red = Color(0xFFEF4444);
  static const _purple = Color(0xFF8B5CF6);

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
    if (!mounted) return;
    setState(() { _elders = decayed; _allAlerts = alerts; _elderVitals = vitals; _isLoading = false; });
  }

  Future<void> _silentRefresh() async {
    final elders = await _api.getGuardianDashboard();
    if (!mounted) return;
    final decayed = await _applyDecay(elders);
    final alerts = <AlertModel>[];
    for (final e in decayed) alerts.addAll(e.recentAlerts);
    alerts.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    setState(() { _elders = decayed; _allAlerts = alerts; });
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
      body: IndexedStack(index: _bottomNavIndex, children: [_buildDashboardBody(), _buildAlertsPage(), const GuardianSettingsScreen()]),
      bottomNavigationBar: _buildBottomNav(),
    );
  }

  Widget _buildBottomNav() {
    return Container(
      decoration: BoxDecoration(color: _surface, border: Border(top: BorderSide(color: Colors.white.withOpacity(0.07)))),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
          child: Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
            _navItem(0, Icons.dashboard_rounded, 'Dashboard'),
            _navItem(1, Icons.notifications_rounded, 'Alerts'),
            _navItem(2, Icons.settings_rounded, 'Settings'),
          ]),
        ),
      ),
    );
  }

  Widget _navItem(int i, IconData icon, String label) {
    final active = _bottomNavIndex == i;
    return GestureDetector(
      onTap: () => setState(() => _bottomNavIndex = i),
      behavior: HitTestBehavior.opaque,
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 22, color: active ? _blue : _textSec),
        const SizedBox(height: 4),
        Text(label, style: TextStyle(color: active ? _blue : _textSec, fontSize: 10, fontWeight: FontWeight.w700)),
      ]),
    );
  }

  // ── Dashboard body ────────────────────────────────────────────────────────
  Widget _buildDashboardBody() {
    return SafeArea(child: Column(children: [
      _buildHeader(),
      TabBar(controller: _tabController, indicatorColor: _blue, indicatorWeight: 3, labelColor: _blue, unselectedLabelColor: _textSec, labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15), tabs: const [Tab(text: "Elders"), Tab(text: "Children"), Tab(text: "Alerts")]),
      Expanded(child: _isLoading ? const Center(child: CircularProgressIndicator(color: _blue)) : TabBarView(controller: _tabController, children: [_buildEldersTab(), _buildChildrenTab(), _buildAlertsTab()])),
    ]));
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 16, 8),
      child: Row(children: [
        const Expanded(child: Text('Guardian Dashboard', style: TextStyle(color: _textPri, fontSize: 22, fontWeight: FontWeight.w800, letterSpacing: -0.5))),
        IconButton(
          icon: Stack(children: [
            const Icon(Icons.notifications_outlined, color: _textSec, size: 24),
            if (_allAlerts.any((a) => !a.isRead)) Positioned(right: 0, top: 0, child: Container(width: 8, height: 8, decoration: const BoxDecoration(color: _red, shape: BoxShape.circle))),
          ]),
          onPressed: () => setState(() => _bottomNavIndex = 1),
        ),
        const SizedBox(width: 4),
        GestureDetector(
          onTap: _loadDashboard,
          child: Container(width: 36, height: 36, decoration: BoxDecoration(shape: BoxShape.circle, gradient: LinearGradient(colors: [_blue, _blue.withOpacity(0.6)]), border: Border.all(color: _blue.withOpacity(0.4), width: 2)), child: const Center(child: Icon(Icons.person, color: Colors.white, size: 18))),
        ),
      ]),
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
        Text('Your Elders (${_elders!.length})', style: const TextStyle(color: _textPri, fontSize: 18, fontWeight: FontWeight.w800)),
        const SizedBox(height: 14),
        ..._elders!.map(_buildElderCard),
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
        decoration: BoxDecoration(color: _cardBg, borderRadius: BorderRadius.circular(22), border: Border.all(color: Colors.white.withOpacity(0.05))),
        child: Padding(padding: const EdgeInsets.all(16), child: Column(children: [
          // Avatar + Name + Badge
          Row(children: [
            Container(width: 50, height: 50, decoration: BoxDecoration(shape: BoxShape.circle, color: rc.withOpacity(0.10), border: Border.all(color: rc.withOpacity(0.6), width: 2.5)),
              child: Center(child: Text(elder.elderName.isNotEmpty ? elder.elderName[0].toUpperCase() : 'E', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: rc)))),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(elder.elderName, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: _textPri)),
              const SizedBox(height: 5),
              Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3), decoration: BoxDecoration(color: rc.withOpacity(0.15), borderRadius: BorderRadius.circular(6)),
                child: Text('$rl · ${elder.riskScore}', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: rc))),
            ])),
            if (elder.unreadAlertsCount > 0)
              Container(padding: const EdgeInsets.all(6), decoration: BoxDecoration(color: _red.withOpacity(0.15), shape: BoxShape.circle),
                child: Text('${elder.unreadAlertsCount}', style: const TextStyle(color: _red, fontSize: 11, fontWeight: FontWeight.bold))),
          ]),
          const SizedBox(height: 16),
          // Vitals
          Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
            _stat(Icons.favorite_rounded, 'HEART', hr == '—' ? '—' : '$hr bpm', _red),
            _vDiv(), _stat(Icons.directions_walk_rounded, 'STEPS', steps, _blue),
            _vDiv(), _stat(Icons.access_time_rounded, 'STATUS', status, _green),
          ]),
          const SizedBox(height: 14), const Divider(color: Colors.white10), const SizedBox(height: 10),
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
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(color: c.withOpacity(0.08), borderRadius: BorderRadius.circular(10), border: Border.all(color: c.withOpacity(0.2))),
      child: Column(children: [Icon(icon, color: c, size: 18), const SizedBox(height: 3), Text(label, style: TextStyle(color: c, fontSize: 10, fontWeight: FontWeight.w700))]),
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
      decoration: BoxDecoration(color: _cardBg, borderRadius: BorderRadius.circular(22), border: Border.all(color: Colors.white.withOpacity(0.05))),
      child: Padding(padding: const EdgeInsets.all(16), child: Column(children: [
        Row(children: [
          Container(width: 48, height: 48, decoration: BoxDecoration(shape: BoxShape.circle, color: _blue.withOpacity(0.10), border: Border.all(color: _blue.withOpacity(0.50), width: 2.5)),
            child: Center(child: Text(child.childName[0].toUpperCase(), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: _blue)))),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(child.childName, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: _textPri)),
            const SizedBox(height: 4),
            Text(child.childPhone, style: TextStyle(fontSize: 12, color: _textSec.withOpacity(0.6))),
          ])),
          Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4), decoration: BoxDecoration(color: _green.withOpacity(0.1), borderRadius: BorderRadius.circular(20)),
            child: Text(child.locationStatus, style: const TextStyle(color: _green, fontWeight: FontWeight.bold, fontSize: 11))),
        ]),
        const SizedBox(height: 16),
        Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
          _stat(Icons.timer_rounded, 'SCREEN', '${h}h ${m}m', _amber),
          _vDiv(), _stat(Icons.location_on_rounded, 'SEEN', '10 min ago', _purple),
          _vDiv(), _stat(Icons.shield_rounded, 'ALERTS', '${child.unreadAlerts}', _green),
        ]),
        const SizedBox(height: 14), const Divider(color: Colors.white10), const SizedBox(height: 8),
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
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, size: 16, color: c.withOpacity(0.7)), const SizedBox(width: 6),
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(value, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: _textPri)),
        Text(label, style: TextStyle(fontSize: 9, color: _textSec.withOpacity(0.6), fontWeight: FontWeight.w600, letterSpacing: 0.5)),
      ]),
    ]);
  }

  Widget _vDiv() => Container(height: 28, width: 0.5, color: Colors.white.withOpacity(0.08));

  Widget _emptyState(String type) {
    return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      Icon(type == "Elders" ? Icons.elderly_rounded : Icons.child_care_rounded, size: 56, color: _blue.withOpacity(0.5)),
      const SizedBox(height: 24), Text('No $type Added', style: const TextStyle(color: _textPri, fontSize: 20, fontWeight: FontWeight.w700)),
      const SizedBox(height: 12), Text('You are not tracking any $type yet.', style: const TextStyle(color: _textSec)),
    ]));
  }
}
