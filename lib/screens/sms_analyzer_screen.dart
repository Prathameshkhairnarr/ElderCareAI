import 'package:flutter/material.dart';
import '../models/sms_model.dart';
import '../models/risk_model.dart';
import '../services/api_service.dart';

class SmsAnalyzerScreen extends StatefulWidget {
  const SmsAnalyzerScreen({super.key});

  @override
  State<SmsAnalyzerScreen> createState() => _SmsAnalyzerScreenState();
}

class _SmsAnalyzerScreenState extends State<SmsAnalyzerScreen> {
  final _api = ApiService();
  final _inputController = TextEditingController();
  List<SmsModel> _smsList = [];
  SmsModel? _analysisResult;
  RiskModel? _riskScore;
  bool _loadingList = true;
  bool _analyzing = false;

  @override
  void initState() {
    super.initState();
    _loadSmsList();
    _loadRiskScore();
  }

  Future<void> _loadSmsList() async {
    // Try backend first, fall back to local
    final list = await _api.getSmsHistory();
    if (!mounted) return;
    setState(() {
      _smsList = list.isNotEmpty ? list : [];
      _loadingList = false;
    });
  }

  Future<void> _loadRiskScore() async {
    final risk = await _api.getRiskScore();
    if (!mounted) return;
    setState(() => _riskScore = risk);
  }

  Future<void> _analyze() async {
    final text = _inputController.text.trim();
    if (text.isEmpty) return;

    setState(() => _analyzing = true);
    final result = await _api.analyzeSms(text);

    if (!mounted) return;
    setState(() {
      _analysisResult = result;
      _analyzing = false;
    });
    // Refresh both lists
    _loadSmsList();
    _loadRiskScore();
  }

  Future<void> _resolveMessage(SmsModel sms, int index) async {
    if (sms.riskEntryId == null) return;

    // Optimistic UI update
    setState(() {
      sms.isResolved = true;
    });

    final updatedRisk = await _api.resolveSmsRisk(sms.riskEntryId!);

    if (!mounted) return;
    setState(() {
      if (updatedRisk != null) {
        _riskScore = updatedRisk;
      }
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✅ Threat resolved. Risk score updated.'),
          backgroundColor: Color(0xFF2E7D32),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _deleteMessage(SmsModel sms, int index) async {
    // Resolve on backend first if it's an active scam
    if (sms.riskEntryId != null && !sms.isResolved) {
      final updatedRisk = await _api.resolveSmsRisk(sms.riskEntryId!);
      if (!mounted) return;
      if (updatedRisk != null) {
        setState(() => _riskScore = updatedRisk);
      }
    }

    // Remove from local list
    if (!mounted) return;
    setState(() {
      _smsList.removeAt(index);
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('🗑️ Message deleted. Risk score updated.'),
        backgroundColor: Color(0xFF424242),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  void dispose() {
    _inputController.dispose();
    super.dispose();
  }

  // ── Color helpers ────────────────────────────────────
  Color _riskColor(double score) {
    if (score < 30) return const Color(0xFF2E7D32); // Deep green
    if (score < 60) return const Color(0xFFF57F17); // Amber
    if (score < 80) return const Color(0xFFE65100); // Deep orange
    return const Color(0xFFC62828); // Deep red
  }

  String _friendlyCategory(String category) {
    switch (category) {
      case 'financial_scam':
        return '💰 Bank Fraud Attempt';
      case 'financial_impersonation':
        return '🏛️ Fake Official — Money Scam';
      case 'impersonation':
        return '🎭 Someone Pretending to Be Official';
      case 'threat_scam':
        return '⚠️ Threatening Message';
      case 'phishing':
        return '🔗 Dangerous Link Detected';
      case 'suspicious_link':
        return '🔗 Suspicious Link';
      case 'social_engineering':
        return '🕵️ Pressure Tactic';
      case 'safe':
        return '✅ Normal Message';
      default:
        return category.replaceAll('_', ' ');
    }
  }

  // ── Build ────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'SMS Safety Check',
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 20),
        ),
        centerTitle: true,
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      body: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0.0, end: 1.0),
        duration: const Duration(milliseconds: 500),
        builder: (context, value, child) {
          return Opacity(
            opacity: value,
            child: Transform.translate(
              offset: Offset(0, 20 * (1 - value)),
              child: child,
            ),
          );
        },
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ── Risk Score Banner ──
              if (_riskScore != null) ...[
                _buildRiskBanner(),
                const SizedBox(height: 20),
              ],

              // ── Input Section ──
              _buildInputSection(),

              // ── Analysis Result ──
              if (_analysisResult != null) ...[
                const SizedBox(height: 20),
                _buildResultCard(_analysisResult!),
              ],

              // ── Recent Messages ──
              const SizedBox(height: 28),
              Row(
                children: [
                  Icon(
                    Icons.history_rounded,
                    color: Theme.of(context).colorScheme.primary,
                    size: 22,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Recent Messages',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              if (_loadingList)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(32),
                    child: CircularProgressIndicator(),
                  ),
                )
              else if (_smsList.isEmpty)
                _buildEmptyState()
              else
                ...List.generate(
                  _smsList.length,
                  (i) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: TweenAnimationBuilder<double>(
                      tween: Tween(begin: 0.0, end: 1.0),
                      duration: Duration(milliseconds: 400 + (i * 80)),
                      builder: (context, value, child) {
                        return Opacity(
                          opacity: value,
                          child: Transform.translate(
                            offset: Offset(0, 20 * (1 - value)),
                            child: child,
                          ),
                        );
                      },
                      child: _buildSmsCard(_smsList[i], i),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Risk Score Banner ──────────────────────────────────
  Widget _buildRiskBanner() {
    final score = _riskScore!.score;
    final level = _riskScore!.level;
    final color = _riskColor(score);
    final isHigh = score >= 40;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 600),
      curve: Curves.easeOutCubic,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isHigh
              ? [const Color(0xFFC62828), const Color(0xFFD32F2F)]
              : [const Color(0xFF1B5E20), const Color(0xFF2E7D32)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.3),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Icon(
                isHigh ? Icons.shield_rounded : Icons.verified_user_rounded,
                color: Colors.white,
                size: 32,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Overall Risk: $level',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _riskScore!.details,
                      style: const TextStyle(
                        fontSize: 13,
                        color: Colors.white70,
                      ),
                    ),
                  ],
                ),
              ),
              // Animated score
              TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: score),
                duration: const Duration(milliseconds: 800),
                curve: Curves.easeOutCubic,
                builder: (context, value, _) {
                  return Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Center(
                      child: Text(
                        '${value.toInt()}',
                        style: const TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
          const SizedBox(height: 14),
          // Animated risk bar
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: SizedBox(
              height: 8,
              child: Stack(
                children: [
                  Container(color: Colors.white.withValues(alpha: 0.2)),
                  AnimatedFractionallySizedBox(
                    duration: const Duration(milliseconds: 800),
                    curve: Curves.easeOutCubic,
                    widthFactor: (score / 100).clamp(0.0, 1.0),
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Input Section ──────────────────────────────────────
  Widget _buildInputSection() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(
          context,
        ).colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.1),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(
                Icons.shield_rounded,
                color: Theme.of(context).colorScheme.primary,
                size: 24,
              ),
              const SizedBox(width: 10),
              Text(
                'Check a Message',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Paste any SMS to check if it is safe or a scam',
            style: TextStyle(
              fontSize: 14,
              color: Theme.of(
                context,
              ).colorScheme.onSurface.withValues(alpha: 0.5),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _inputController,
            maxLines: 3,
            style: const TextStyle(fontSize: 16, height: 1.5),
            decoration: InputDecoration(
              hintText: 'Paste SMS text here...',
              hintStyle: TextStyle(
                fontSize: 16,
                color: Theme.of(
                  context,
                ).colorScheme.onSurface.withValues(alpha: 0.3),
              ),
              filled: true,
              fillColor: Theme.of(context).colorScheme.surface,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.all(16),
            ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            height: 52,
            child: ElevatedButton.icon(
              onPressed: _analyzing ? null : _analyze,
              icon: _analyzing
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2.5),
                    )
                  : const Icon(Icons.search_rounded, size: 22),
              label: Text(
                _analyzing ? 'Checking...' : 'Check for Scam',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
              style: ElevatedButton.styleFrom(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Result Card (prominent, post-analysis) ──────────────
  Widget _buildResultCard(SmsModel sms) {
    final isFraud = sms.isFraud;
    final score = sms.riskScore;
    final color = _riskColor(score);
    final bannerColor = isFraud
        ? const Color(0xFFC62828)
        : const Color(0xFF2E7D32);
    final bannerBg = isFraud
        ? const Color(0x22C62828)
        : const Color(0x222E7D32);

    return Container(
      key: ValueKey('result_${sms.body.hashCode}'),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: bannerColor.withValues(alpha: 0.4), width: 2),
        color: bannerBg,
      ),
      child: Column(
        children: [
          // ── Status Banner ──
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
            decoration: BoxDecoration(
              color: bannerColor,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(18),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  isFraud
                      ? Icons.warning_amber_rounded
                      : Icons.verified_rounded,
                  color: Colors.white,
                  size: 30,
                ),
                const SizedBox(width: 12),
                Text(
                  isFraud ? 'Scam Alert!' : 'Safe Message',
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          ),

          // ── Body ──
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Category
                UnconstrainedBox(
                  alignment: Alignment.centerLeft,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: bannerColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      _friendlyCategory(sms.category),
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: bannerColor,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Risk Meter
                _buildRiskMeter(score, color),
                const SizedBox(height: 16),

                // Message preview
                Text(
                  sms.body,
                  style: TextStyle(
                    fontSize: 15,
                    height: 1.6,
                    color: Theme.of(
                      context,
                    ).colorScheme.onSurface.withValues(alpha: 0.8),
                  ),
                  maxLines: 4,
                  overflow: TextOverflow.ellipsis,
                ),

                // Explanation
                if (sms.explanation.isNotEmpty) ...[
                  const SizedBox(height: 14),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Theme.of(context)
                          .colorScheme
                          .surfaceContainerHighest
                          .withValues(alpha: 0.6),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.info_outline_rounded,
                          size: 20,
                          color: Theme.of(
                            context,
                          ).colorScheme.onSurface.withValues(alpha: 0.5),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            sms.explanation,
                            style: TextStyle(
                              fontSize: 13,
                              height: 1.5,
                              color: Theme.of(
                                context,
                              ).colorScheme.onSurface.withValues(alpha: 0.6),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Risk Meter (horizontal bar) ─────────────────────────
  Widget _buildRiskMeter(double score, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.speed_rounded, size: 20, color: color),
            const SizedBox(width: 8),
            Text(
              'Risk Level',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Theme.of(
                  context,
                ).colorScheme.onSurface.withValues(alpha: 0.6),
              ),
            ),
            const Spacer(),
            Text(
              '${score.toInt()}%',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w900,
                color: color,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: SizedBox(
            height: 14,
            child: Stack(
              children: [
                // Background
                Container(
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surfaceContainerHighest
                        .withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                // Fill
                AnimatedFractionallySizedBox(
                  duration: const Duration(milliseconds: 800),
                  curve: Curves.easeOutCubic,
                  widthFactor: (score / 100).clamp(0.0, 1.0),
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: score < 30
                            ? [const Color(0xFF66BB6A), const Color(0xFF43A047)]
                            : score < 60
                            ? [const Color(0xFFFFA726), const Color(0xFFF57C00)]
                            : score < 80
                            ? [const Color(0xFFFF7043), const Color(0xFFE64A19)]
                            : [
                                const Color(0xFFEF5350),
                                const Color(0xFFC62828),
                              ],
                      ),
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 6),
        // Level labels
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Safe',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF43A047).withValues(alpha: 0.7),
              ),
            ),
            Text(
              'Caution',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: const Color(0xFFF57C00).withValues(alpha: 0.7),
              ),
            ),
            Text(
              'Danger',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: const Color(0xFFC62828).withValues(alpha: 0.7),
              ),
            ),
          ],
        ),
      ],
    );
  }

  // ── History SMS Card (with resolve/delete buttons) ──────────
  Widget _buildSmsCard(SmsModel sms, int index) {
    final isFraud = sms.isFraud;
    final isResolved = sms.isResolved;
    final score = sms.riskScore;
    final color = _riskColor(score);
    final statusColor = isResolved
        ? const Color(0xFF616161) // Grey for resolved
        : isFraud
            ? const Color(0xFFC62828)
            : const Color(0xFF2E7D32);

    return AnimatedOpacity(
      duration: const Duration(milliseconds: 300),
      opacity: isResolved ? 0.6 : 1.0,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: statusColor.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: statusColor.withValues(alpha: 0.2)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Status row
            Row(
              children: [
                // Status badge
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        isResolved
                            ? Icons.check_circle_rounded
                            : isFraud
                                ? Icons.warning_amber_rounded
                                : Icons.verified_rounded,
                        color: statusColor,
                        size: 16,
                      ),
                      const SizedBox(width: 5),
                      Text(
                        isResolved
                            ? 'Resolved'
                            : isFraud
                                ? 'Active Threat'
                                : 'Safe',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: statusColor,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                // Category
                Expanded(
                  child: Text(
                    _friendlyCategory(sms.category),
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Theme.of(
                        context,
                      ).colorScheme.onSurface.withValues(alpha: 0.5),
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                // Risk score
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '${score.toInt()}%',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w900,
                      color: color,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Mini risk bar
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: SizedBox(
                height: 6,
                child: Stack(
                  children: [
                    Container(
                      color: Theme.of(context).colorScheme.surfaceContainerHighest
                          .withValues(alpha: 0.4),
                    ),
                    FractionallySizedBox(
                      widthFactor: (score / 100).clamp(0.0, 1.0),
                      child: Container(
                        decoration: BoxDecoration(
                          color: color,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),

            // Message body
            Text(
              sms.body,
              style: TextStyle(
                fontSize: 14,
                height: 1.5,
                color: Theme.of(
                  context,
                ).colorScheme.onSurface.withValues(alpha: 0.75),
              ),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),

            // ── Action Buttons (for active fraud only) ──
            if (isFraud && !isResolved) ...[
              const SizedBox(height: 16),
              Row(
                children: [
                  // Resolve Button
                  Expanded(
                    child: SizedBox(
                      height: 48,
                      child: ElevatedButton.icon(
                        onPressed: () => _resolveMessage(sms, index),
                        icon: const Icon(Icons.check_circle_outline_rounded, size: 20),
                        label: const Text(
                          'Resolved',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF2E7D32),
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Delete Button
                  Expanded(
                    child: SizedBox(
                      height: 48,
                      child: OutlinedButton.icon(
                        onPressed: () => _deleteMessage(sms, index),
                        icon: const Icon(Icons.delete_outline_rounded, size: 20),
                        label: const Text(
                          'Delete',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFFC62828),
                          side: const BorderSide(
                            color: Color(0xFFC62828),
                            width: 1.5,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],

            // Resolved indicator
            if (isFraud && isResolved) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
                decoration: BoxDecoration(
                  color: const Color(0xFF2E7D32).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.check_circle_rounded, color: Color(0xFF2E7D32), size: 18),
                    SizedBox(width: 8),
                    Text(
                      'This threat has been resolved',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF2E7D32),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ── Empty State ────────────────────────────────────────
  Widget _buildEmptyState() {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: Theme.of(
          context,
        ).colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          Icon(
            Icons.shield_rounded,
            size: 48,
            color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.3),
          ),
          const SizedBox(height: 16),
          Text(
            'No messages checked yet',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Theme.of(
                context,
              ).colorScheme.onSurface.withValues(alpha: 0.5),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Paste a suspicious SMS above to check if it is safe',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              color: Theme.of(
                context,
              ).colorScheme.onSurface.withValues(alpha: 0.35),
            ),
          ),
        ],
      ),
    );
  }
}

/// Animated version of FractionallySizedBox for smooth risk meter fill.
class AnimatedFractionallySizedBox extends StatelessWidget {
  final Duration duration;
  final Curve curve;
  final double widthFactor;
  final Widget child;

  const AnimatedFractionallySizedBox({
    super.key,
    required this.duration,
    required this.curve,
    required this.widthFactor,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: widthFactor),
      duration: duration,
      curve: curve,
      builder: (context, value, _) {
        return FractionallySizedBox(
          alignment: Alignment.centerLeft,
          widthFactor: value,
          child: child,
        );
      },
    );
  }
}
