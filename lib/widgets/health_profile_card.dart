import 'package:flutter/material.dart';
import '../models/health_profile.dart';
import '../services/health_profile_service.dart';

// ═══════════════════════════════════════════════════════════════
//  HEALTH PROFILE CARD — Modern dashboard card for AI Doctor
// ═══════════════════════════════════════════════════════════════

class HealthProfileCard extends StatefulWidget {
  const HealthProfileCard({super.key});

  @override
  State<HealthProfileCard> createState() => _HealthProfileCardState();
}

class _HealthProfileCardState extends State<HealthProfileCard> {
  final _service = HealthProfileService();

  @override
  void initState() {
    super.initState();
    _service.addListener(_onUpdate);
    _service.load();
  }

  @override
  void dispose() {
    _service.removeListener(_onUpdate);
    super.dispose();
  }

  void _onUpdate() {
    if (mounted) setState(() {});
  }

  // ── BMI color helper ─────────────────────────────
  Color _bmiColor(double bmi) {
    if (bmi < 18.5) return const Color(0xFFFF9800); // orange — underweight
    if (bmi < 25) return const Color(0xFF4CAF50); // green  — normal
    return const Color(0xFFEF5350); // red    — overweight/obese
  }

  String _formatTime(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${dt.day}/${dt.month}/${dt.year}';
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final profile = _service.profile;
    const accent = Color(0xFF7C4DFF); // purple accent

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: const Duration(milliseconds: 700),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) => Opacity(
        opacity: value,
        child: Transform.translate(
          offset: Offset(0, 30 * (1 - value)),
          child: child,
        ),
      ),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          gradient: LinearGradient(
            colors: [
              accent.withValues(alpha: 0.10),
              cs.surfaceContainerHighest,
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          border: Border.all(color: accent.withValues(alpha: 0.20), width: 1.5),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header ──────────────────────────────
            Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(
                    Icons.person_rounded,
                    color: accent,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    'Health Profile',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: cs.onSurface,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF26A69A).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Text(
                    'Active',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF26A69A),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // ── Body ────────────────────────────────
            if (profile.isEmpty)
              _buildEmptyState(cs)
            else
              _buildProfileGrid(cs, profile),
          ],
        ),
      ),
    );
  }

  // ── Empty state ─────────────────────────────────
  Widget _buildEmptyState(ColorScheme cs) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Column(
        children: [
          Icon(
            Icons.person_outline_rounded,
            size: 48,
            color: cs.onSurface.withValues(alpha: 0.2),
          ),
          const SizedBox(height: 10),
          Text(
            'No health data saved yet',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: cs.onSurface.withValues(alpha: 0.4),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Go to the Health tab to add your profile',
            style: TextStyle(
              fontSize: 13,
              color: cs.onSurface.withValues(alpha: 0.3),
            ),
          ),
        ],
      ),
    );
  }

  // ── Filled profile grid ─────────────────────────
  Widget _buildProfileGrid(ColorScheme cs, HealthProfile profile) {
    return Column(
      children: [
        // Row 1 — Age & Gender
        Row(
          children: [
            Expanded(
              child: _infoTile(
                icon: Icons.cake_rounded,
                label: 'Age',
                value: profile.age?.toString() ?? '—',
                color: const Color(0xFFFF7043),
                cs: cs,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _infoTile(
                icon: Icons.person_rounded,
                label: 'Gender',
                value: profile.gender != null
                    ? profile.gender![0].toUpperCase() +
                          profile.gender!.substring(1)
                    : '—',
                color: const Color(0xFF42A5F5),
                cs: cs,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        // Row 2 — Height & Weight
        Row(
          children: [
            Expanded(
              child: _infoTile(
                icon: Icons.height_rounded,
                label: 'Height',
                value: profile.heightCm != null
                    ? '${profile.heightCm} cm'
                    : '—',
                color: const Color(0xFF26A69A),
                cs: cs,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _infoTile(
                icon: Icons.monitor_weight_rounded,
                label: 'Weight',
                value: profile.weightKg != null
                    ? '${profile.weightKg} kg'
                    : '—',
                color: const Color(0xFF5C6BC0),
                cs: cs,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        // Row 3 — Blood Group
        _infoTile(
          icon: Icons.bloodtype_rounded,
          label: 'Blood Group',
          value: profile.bloodGroup ?? '—',
          color: const Color(0xFFEF5350),
          cs: cs,
          fullWidth: true,
        ),
        const SizedBox(height: 12),

        // Row 4 — BMI
        if (profile.bmi != null) ...[
          _buildBmiTile(cs, profile),
          const SizedBox(height: 12),
        ],

        // Row 5 — Medical Conditions
        _infoTile(
          icon: Icons.medical_services_rounded,
          label: 'Conditions',
          value: profile.medicalConditions?.isNotEmpty == true
              ? profile.medicalConditions!
              : '—',
          color: const Color(0xFFAB47BC),
          cs: cs,
          fullWidth: true,
        ),
        const SizedBox(height: 12),

        // Row 6 — Emergency Contact
        _infoTile(
          icon: Icons.phone_rounded,
          label: 'Emergency',
          value: profile.emergencyPhone ?? '—',
          color: const Color(0xFFEC407A),
          cs: cs,
          fullWidth: true,
        ),

        // Last updated
        if (profile.lastUpdated != null) ...[
          const SizedBox(height: 16),
          Row(
            children: [
              Icon(
                Icons.access_time_rounded,
                size: 14,
                color: cs.onSurface.withValues(alpha: 0.3),
              ),
              const SizedBox(width: 6),
              Text(
                'Updated ${_formatTime(profile.lastUpdated!)}',
                style: TextStyle(
                  fontSize: 12,
                  color: cs.onSurface.withValues(alpha: 0.35),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }

  // ── Single info tile ────────────────────────────
  Widget _infoTile({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
    required ColorScheme cs,
    bool fullWidth = false,
  }) {
    return Container(
      width: fullWidth ? double.infinity : null,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.12)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 20, color: color),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: cs.onSurface.withValues(alpha: 0.5),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: cs.onSurface,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── BMI tile with status color ──────────────────
  Widget _buildBmiTile(ColorScheme cs, HealthProfile profile) {
    final bmi = profile.bmi!;
    final color = _bmiColor(bmi);
    final category = profile.bmiCategory;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.15)),
      ),
      child: Row(
        children: [
          Icon(Icons.health_and_safety_rounded, size: 20, color: color),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'BMI',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: cs.onSurface.withValues(alpha: 0.5),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  bmi.toStringAsFixed(1),
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: cs.onSurface,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              category,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
