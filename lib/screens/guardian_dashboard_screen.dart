import 'dart:async';
import 'package:flutter/material.dart';
import '../models/alert_model.dart';
import '../services/api_service.dart';
import 'guardian_settings_screen.dart';
import 'elder_detail_screen.dart';

class GuardianDashboardScreen extends StatefulWidget {
  const GuardianDashboardScreen({Key? key}) : super(key: key);

  @override
  State<GuardianDashboardScreen> createState() =>
      _GuardianDashboardScreenState();
}

class _GuardianDashboardScreenState extends State<GuardianDashboardScreen> {
  final ApiService _apiService = ApiService();
  List<ElderStatsModel>? _elders;
  bool _isLoading = true;
  int _selectedIndex = 0;
  Timer? _refreshTimer;

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

  @override
  void initState() {
    super.initState();
    _loadDashboard();
    // Auto-refresh every 30s to sync with elder's decaying risk score
    _refreshTimer = Timer.periodic(
      const Duration(seconds: 30),
      (_) => _silentRefresh(),
    );
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadDashboard() async {
    setState(() => _isLoading = true);
    final elders = await _apiService.getGuardianDashboard();
    if (!mounted) return;
    // Apply client-side decay to each elder's score
    final decayed = await _applyDecayToElders(elders);
    setState(() {
      _elders = decayed;
      _isLoading = false;
    });
  }

  /// Silent refresh (no loading spinner) to update elder scores live.
  Future<void> _silentRefresh() async {
    final elders = await _apiService.getGuardianDashboard();
    if (!mounted) return;
    final decayed = await _applyDecayToElders(elders);
    setState(() => _elders = decayed);
  }

  /// Fetches each elder's RiskModel (which has lastScamAt) and applies
  /// the same exponential decay formula used on the elder's device.
  /// This keeps the guardian's view in sync without a new backend endpoint.
  Future<List<ElderStatsModel>> _applyDecayToElders(
      List<ElderStatsModel> elders) async {
    final List<ElderStatsModel> result = [];

    for (final elder in elders) {
      try {
        final risk = await _apiService.getElderRiskScore(elder.id);
        if (risk != null && risk.lastScamAt != null) {
          final decayedScore = _computeDecayedScore(
            risk.score,
            risk.lastScamAt!,
          );
          // Rebuild with decayed score
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

  /// Same exponential decay formula as RiskScoreEngine:
  /// score * 0.8^N where N = (seconds since last scam) / 30
  int _computeDecayedScore(double rawScore, DateTime lastScamAt) {
    final elapsed = DateTime.now().difference(lastScamAt).inSeconds;
    if (elapsed <= 0) return rawScore.round().clamp(0, 100);

    const decayWindow = 30; // seconds per decay window
    const decayMultiplier = 0.8;

    final loops = elapsed ~/ decayWindow;
    double current = rawScore;

    for (int i = 0; i < loops; i++) {
      current = current * decayMultiplier;
      if (current < 1) return 0;
    }

    return current.round().clamp(0, 100);
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
              _navItem(0, Icons.family_restroom_rounded, 'ELDERS'),
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

  // ── Home content ──────────────────────────────────────────────────────────
  Widget _buildHomeContent() {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            Expanded(
              child: _isLoading
                  ? const Center(
                      child: CircularProgressIndicator(
                        color: _blue,
                        strokeWidth: 2.5,
                      ),
                    )
                  : (_elders == null || _elders!.isEmpty)
                      ? _buildEmptyState()
                      : RefreshIndicator(
                          onRefresh: _loadDashboard,
                          color: _blue,
                          backgroundColor: _surface,
                          child: ListView(
                            padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
                            children: [
                              _buildStatCard(
                                'ELDERS',
                                '${_elders!.length.toString().padLeft(2, '0')}',
                                Icons.people_rounded,
                                _blue,
                              ),
                              const SizedBox(height: 10),
                              _buildStatCard(
                                'ALERTS',
                                '${_elders!.fold<int>(0, (s, e) => s + e.unreadAlertsCount).toString().padLeft(2, '0')}',
                                Icons.notifications_rounded,
                                _amber,
                              ),
                              const SizedBox(height: 10),
                              _buildStatCard(
                                'CRITICAL SOS',
                                '${_elders!.where((e) => e.lastSosAt != null).length.toString().padLeft(2, '0')}',
                                Icons.emergency_share_rounded,
                                _red,
                              ),
                              const SizedBox(height: 28),
                              _sectionHeader(
                                'Your Elders',
                                '${_elders!.length.toString().padLeft(2, '0')} ACTIVE',
                              ),
                              const SizedBox(height: 14),
                              ..._elders!.map(_buildElderCard),
                            ],
                          ),
                        ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Header ────────────────────────────────────────────────────────────────
  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 16, 8),
      child: Row(
        children: [
          // Refresh icon
          GestureDetector(
            onTap: _loadDashboard,
            child: const Icon(
              Icons.refresh_rounded,
              color: _textSec,
              size: 20,
            ),
          ),
          const SizedBox(width: 10),
          // Title
          const Expanded(
            child: Text(
              'CareWatch',
              style: TextStyle(
                color: _textPri,
                fontSize: 22,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.5,
              ),
            ),
          ),
          // Profile avatar
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [_blue, _blue.withOpacity(0.6)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              border: Border.all(
                color: _blue.withOpacity(0.4),
                width: 2,
              ),
            ),
            child: const Center(
              child: Icon(Icons.person, color: Colors.white, size: 18),
            ),
          ),
        ],
      ),
    );
  }

  // ── Stat card (vertical / full-width) ─────────────────────────────────────
  Widget _buildStatCard(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: color.withOpacity(0.12)),
      ),
      child: Row(
        children: [
          // Left: label / value
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    color: _textSec.withOpacity(0.7),
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: const TextStyle(
                    color: _textPri,
                    fontSize: 32,
                    fontWeight: FontWeight.w900,
                    height: 1,
                  ),
                ),
              ],
            ),
          ),
          // Right: icon
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: color, size: 22),
          ),
        ],
      ),
    );
  }

  // ── Section header ────────────────────────────────────────────────────────
  Widget _sectionHeader(String title, String countLabel) {
    return Row(
      children: [
        Text(
          title,
          style: const TextStyle(
            color: _textPri,
            fontSize: 18,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(width: 10),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
          decoration: BoxDecoration(
            color: _blue.withOpacity(0.15),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            countLabel,
            style: const TextStyle(
              color: _blue,
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.5,
            ),
          ),
        ),
        const Spacer(),
        GestureDetector(
          onTap: () {}, // Could navigate to a full list
          child: const Text(
            'View All',
            style: TextStyle(
              color: _textSec,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }

  // ── Elder card ────────────────────────────────────────────────────────────
  Widget _buildElderCard(ElderStatsModel elder) {
    final rColor = _riskColor(elder.riskScore);
    final rLabel = _riskLabel(elder.riskScore);
    final hasSos = elder.lastSosAt != null;

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(22),
        child: InkWell(
          borderRadius: BorderRadius.circular(22),
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => ElderDetailScreen(elder: elder)),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                // ── Top row: avatar, name/risk, menu ──
                Row(
                  children: [
                    // Avatar with risk-colored ring
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: rColor.withOpacity(0.10),
                        border: Border.all(
                          color: rColor.withOpacity(0.50),
                          width: 2.5,
                        ),
                      ),
                      child: Center(
                        child: Text(
                          elder.elderName.isNotEmpty
                              ? elder.elderName[0].toUpperCase()
                              : 'E',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: rColor,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Name + badges
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            elder.elderName,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: _textPri,
                            ),
                          ),
                          const SizedBox(height: 5),
                          Row(
                            children: [
                              _riskBadge(rLabel, elder.riskScore, rColor),
                              const SizedBox(width: 8),
                              Text(
                                'ID: #${elder.id.toString().padLeft(5, '0')}',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: _textSec.withOpacity(0.6),
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    // Three-dot menu
                    GestureDetector(
                      onTap: () => _showElderMenu(elder),
                      child: const Icon(
                        Icons.more_vert_rounded,
                        color: _textSec,
                        size: 20,
                      ),
                    ),
                  ],
                ),

                // ── Health quick-stats row ──
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: _surface,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _miniStat(
                        Icons.directions_walk_rounded,
                        'STEPS',
                        '—',
                        _blue,
                      ),
                      _vertDivider(),
                      _miniStat(
                        Icons.favorite_rounded,
                        'HEART',
                        '—',
                        _red,
                      ),
                      _vertDivider(),
                      _miniStat(
                        Icons.access_time_rounded,
                        'ACTIVE',
                        hasSos ? 'SOS sent' : 'Just now',
                        _green,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── Risk badge (e.g. SAFE 28, WARNING 64) ─────────────────────────────────
  Widget _riskBadge(String label, int score, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        '$label $score',
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w800,
          color: color,
          letterSpacing: 0.3,
        ),
      ),
    );
  }

  Widget _miniStat(IconData icon, String label, String value, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: color.withOpacity(0.7)),
        const SizedBox(width: 6),
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
                color: _textSec.withOpacity(0.6),
                fontWeight: FontWeight.w600,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _vertDivider() => Container(
        height: 28,
        width: 0.5,
        color: Colors.white.withOpacity(0.08),
      );

  // ── Elder menu ────────────────────────────────────────────────────────────
  void _showElderMenu(ElderStatsModel elder) {
    showModalBottomSheet(
      context: context,
      backgroundColor: _surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),
              ListTile(
                leading: const Icon(Icons.person_rounded, color: _blue),
                title: const Text('View Details',
                    style: TextStyle(color: _textPri, fontSize: 14)),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ElderDetailScreen(elder: elder),
                    ),
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.history_rounded, color: _amber),
                title: const Text('Alert History',
                    style: TextStyle(color: _textPri, fontSize: 14)),
                onTap: () => Navigator.pop(context),
              ),
              ListTile(
                leading: const Icon(Icons.emergency_rounded, color: _red),
                title: const Text('Send SOS Check',
                    style: TextStyle(color: _textPri, fontSize: 14)),
                onTap: () => Navigator.pop(context),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Empty state ───────────────────────────────────────────────────────────
  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(28),
              decoration: BoxDecoration(
                color: _blue.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.family_restroom,
                size: 56,
                color: _blue,
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'No elders linked yet',
              style: TextStyle(
                color: _textPri,
                fontSize: 20,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Ask your elder to add your phone number in their Guardian Setup to begin monitoring.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: _textSec,
                fontSize: 14,
                height: 1.6,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
