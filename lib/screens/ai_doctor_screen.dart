import 'package:flutter/material.dart';
import '../voice/voice_controller.dart';
import '../services/emergency_service.dart';
import '../services/api_service.dart';
import '../services/health_profile_service.dart';
import '../widgets/health_profile_card.dart';

// ═══════════════════════════════════════════════════════════════
//  AI DOCTOR SCREEN
//  Elderly-friendly dashboard: Voice · Medication · Health · SOS
// ═══════════════════════════════════════════════════════════════

class AiDoctorScreen extends StatefulWidget {
  const AiDoctorScreen({super.key});

  @override
  State<AiDoctorScreen> createState() => _AiDoctorScreenState();
}

class _AiDoctorScreenState extends State<AiDoctorScreen> {
  final VoiceController _voice = VoiceController();

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    _voice.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.medical_services_rounded,
              color: Theme.of(context).colorScheme.primary,
              size: 24,
            ),
            const SizedBox(width: 10),
            const Text('AI Doctor'),
          ],
        ),
        centerTitle: true,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _VoiceAssistantCard(controller: _voice),
            const SizedBox(height: 20),
            const HealthProfileCard(),
            const SizedBox(height: 20),
            const _MedicationReminderCard(),
            const SizedBox(height: 20),
            const _HealthCheckCard(),
            const SizedBox(height: 28),
            _SosEmergencyButton(
              onPressed: () => EmergencyService().triggerSOS(),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
//  1. VOICE ASSISTANT CARD
// ═══════════════════════════════════════════════════════════════

class _VoiceAssistantCard extends StatefulWidget {
  final VoiceController controller;
  const _VoiceAssistantCard({required this.controller});

  @override
  State<_VoiceAssistantCard> createState() => _VoiceAssistantCardState();
}

class _VoiceAssistantCardState extends State<_VoiceAssistantCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseCtrl;

  VoiceController get _vc => widget.controller;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _vc.addListener(_onVoiceChange);
  }

  @override
  void dispose() {
    _vc.removeListener(_onVoiceChange);
    _pulseCtrl.dispose();
    super.dispose();
  }

  void _onVoiceChange() {
    if (!mounted) return;
    setState(() {});
    if (_vc.isListening || _vc.isConversationActive) {
      _pulseCtrl.repeat(reverse: true);
    } else {
      _pulseCtrl.stop();
      _pulseCtrl.reset();
    }
  }

  Future<void> _onMicTap() async {
    await _vc.onMicTap();
    if (_vc.response.isNotEmpty && mounted) {
      _showResponseSheet();
    }
  }

  void _onMicLongPress() {
    if (_vc.isConversationActive) {
      _vc.stopConversation();
    } else {
      _vc.startConversation();
    }
  }

  void _showResponseSheet() {
    final cs = Theme.of(context).colorScheme;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        margin: const EdgeInsets.all(16),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: cs.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: cs.outline.withValues(alpha: 0.1)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.2),
              blurRadius: 20,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: cs.outline.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            if (_vc.transcript.isNotEmpty) ...[
              _sheetLabel(Icons.person_rounded, 'You said', cs),
              const SizedBox(height: 6),
              _sheetBubble(_vc.transcript, cs.surface, cs.onSurface, null),
              const SizedBox(height: 16),
            ],
            if (_vc.response.isNotEmpty) ...[
              _sheetLabel(
                Icons.smart_toy_rounded,
                'AI Doctor',
                cs,
                iconColor: const Color(0xFF4FC3F7),
              ),
              const SizedBox(height: 6),
              _sheetBubble(
                _vc.response,
                const Color(0xFF4FC3F7).withValues(alpha: 0.08),
                cs.onSurface,
                const Color(0xFF4FC3F7).withValues(alpha: 0.15),
              ),
            ],
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  Widget _sheetLabel(
    IconData icon,
    String text,
    ColorScheme cs, {
    Color? iconColor,
  }) {
    return Row(
      children: [
        Icon(
          icon,
          size: 18,
          color: iconColor ?? cs.onSurface.withValues(alpha: 0.5),
        ),
        const SizedBox(width: 8),
        Text(
          text,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: iconColor ?? cs.onSurface.withValues(alpha: 0.5),
          ),
        ),
      ],
    );
  }

  Widget _sheetBubble(
    String text,
    Color bg,
    Color textColor,
    Color? borderColor,
  ) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(14),
        border: borderColor != null ? Border.all(color: borderColor) : null,
      ),
      child: Text(
        text,
        style: TextStyle(fontSize: 16, color: textColor, height: 1.5),
      ),
    );
  }

  // ── Status label & color logic ──

  (String, Color, IconData) get _statusInfo {
    switch (_vc.state) {
      case VoiceState.listening:
        return ('Listening…', const Color(0xFFEF5350), Icons.mic_rounded);
      case VoiceState.processing:
        return ('Thinking…', const Color(0xFF7C4DFF), Icons.psychology_rounded);
      case VoiceState.speaking:
        return ('Speaking…', const Color(0xFF26A69A), Icons.volume_up_rounded);
      case VoiceState.error:
        return ('Error', Colors.redAccent, Icons.error_outline_rounded);
      case VoiceState.idle:
        return ('Tap to speak', const Color(0xFF4FC3F7), Icons.mic_rounded);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final (statusText, statusColor, _) = _statusInfo;

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: const Duration(milliseconds: 600),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) => Opacity(
        opacity: value,
        child: Transform.translate(
          offset: Offset(0, 30 * (1 - value)),
          child: child,
        ),
      ),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 24),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          gradient: LinearGradient(
            colors: [
              statusColor.withValues(alpha: 0.12),
              cs.surfaceContainerHighest,
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          border: Border.all(
            color: statusColor.withValues(alpha: 0.25),
            width: 1.5,
          ),
        ),
        child: Column(
          children: [
            // Title
            Text(
              'Talk to AI Doctor',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: cs.onSurface,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Ask about health, medications, or symptoms',
              style: TextStyle(
                fontSize: 14,
                color: cs.onSurface.withValues(alpha: 0.6),
              ),
            ),
            const SizedBox(height: 28),

            // Mic button with pulse — supports long-press for conversation
            AnimatedBuilder(
              animation: _pulseCtrl,
              builder: (context, child) {
                final scale = _vc.isListening || _vc.isConversationActive
                    ? 1.0 + (_pulseCtrl.value * 0.10)
                    : 1.0;
                return Transform.scale(
                  scale: scale,
                  child: Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color:
                              (_vc.isConversationActive
                                      ? Colors.green
                                      : statusColor)
                                  .withValues(alpha: 0.35),
                          blurRadius:
                              _vc.isListening || _vc.isConversationActive
                              ? 24
                              : 12,
                          spreadRadius:
                              _vc.isListening || _vc.isConversationActive
                              ? 6
                              : 0,
                        ),
                      ],
                    ),
                    child: Material(
                      shape: const CircleBorder(),
                      color: _vc.isConversationActive
                          ? Colors.green
                          : statusColor,
                      elevation: 4,
                      child: InkWell(
                        onTap: _vc.isProcessing ? null : _onMicTap,
                        onLongPress: _vc.isProcessing ? null : _onMicLongPress,
                        customBorder: const CircleBorder(),
                        splashColor: Colors.white24,
                        child: SizedBox(
                          width: 88,
                          height: 88,
                          child: Center(
                            child: _vc.isProcessing
                                ? const SizedBox(
                                    width: 30,
                                    height: 30,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 3,
                                      color: Colors.white,
                                    ),
                                  )
                                : Icon(
                                    _vc.isListening
                                        ? Icons.stop_rounded
                                        : (_vc.isConversationActive
                                              ? Icons.chat_rounded
                                              : Icons.mic_rounded),
                                    size: 38,
                                    color: Colors.white,
                                  ),
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 18),

            // Status chip
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              child: Container(
                key: ValueKey('$statusText-${_vc.isConversationActive}'),
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: (_vc.isConversationActive ? Colors.green : statusColor)
                      .withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color:
                        (_vc.isConversationActive ? Colors.green : statusColor)
                            .withValues(alpha: 0.25),
                  ),
                ),
                child: Text(
                  _vc.isConversationActive && _vc.state == VoiceState.idle
                      ? '🟢 Conversation Active'
                      : statusText,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: _vc.isConversationActive
                        ? Colors.green
                        : statusColor,
                  ),
                ),
              ),
            ),

            // Hint text
            if (!_vc.isConversationActive && _vc.state == VoiceState.idle)
              Padding(
                padding: const EdgeInsets.only(top: 10),
                child: Text(
                  'Long-press mic for conversation mode',
                  style: TextStyle(
                    fontSize: 12,
                    color: cs.onSurface.withValues(alpha: 0.4),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
//  2. MEDICATION REMINDER CARD
// ═══════════════════════════════════════════════════════════════

class _MedicationReminderCard extends StatelessWidget {
  const _MedicationReminderCard();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    const accentColor = Color(0xFF66BB6A); // calm green

    // Demo data — replace with dynamic data later
    final medications = [
      {'name': 'Paracetamol', 'time': '08:00 PM', 'dosage': '500 mg'},
      {'name': 'Metformin', 'time': '09:00 PM', 'dosage': '250 mg'},
    ];

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
              accentColor.withValues(alpha: 0.10),
              cs.surfaceContainerHighest,
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          border: Border.all(
            color: accentColor.withValues(alpha: 0.20),
            width: 1.5,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: accentColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(
                    Icons.medication_rounded,
                    color: accentColor,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    'Medication Reminder',
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
                    color: accentColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    'Today',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: accentColor,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),

            // Medication list
            ...medications.map(
              (med) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                  decoration: BoxDecoration(
                    color: cs.surface.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: accentColor.withValues(alpha: 0.12),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.circle, size: 10, color: accentColor),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              med['name']!,
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: cs.onSurface,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              med['dosage']!,
                              style: TextStyle(
                                fontSize: 13,
                                color: cs.onSurface.withValues(alpha: 0.5),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: accentColor.withValues(alpha: 0.10),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.access_time_rounded,
                              size: 14,
                              color: accentColor,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              med['time']!,
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: accentColor,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
//  3. HEALTH CHECK CARD — synced with My Health data
// ═══════════════════════════════════════════════════════════════

class _HealthCheckCard extends StatefulWidget {
  const _HealthCheckCard();

  @override
  State<_HealthCheckCard> createState() => _HealthCheckCardState();
}

class _HealthCheckCardState extends State<_HealthCheckCard> {
  final _api = ApiService();
  final _profileService = HealthProfileService();

  bool _loading = true;

  // Vitals — default to null (unknown)
  String _heartRate = '--';
  String _bloodPressure = '--';
  int _healthScore = 85;

  @override
  void initState() {
    super.initState();
    _loadHealthData();
  }

  Future<void> _loadHealthData() async {
    try {
      // Load profile (for health score age-adjustment)
      final profile = await _profileService.load();

      // Load vitals from API (same call as HealthProfileViewScreen)
      Map<String, dynamic>? summary;
      try {
        summary = await _api.getHealthSummary().timeout(
          const Duration(seconds: 5),
        );
      } catch (_) {
        // API unavailable — keep defaults
      }

      if (!mounted) return;

      // Parse heart rate
      if (summary != null && summary['heart_rate'] != null) {
        final hrVal = summary['heart_rate']['value'];
        if (hrVal != null) _heartRate = '${(hrVal as num).toInt()}';
      }

      // Parse blood pressure
      if (summary != null && summary['bp'] != null) {
        final bpVal = summary['bp']['value'];
        if (bpVal != null) _bloodPressure = '${(bpVal as num).toInt()}';
      }

      // Compute health score (same logic as HealthProfileViewScreen)
      int score = 85;
      if (summary != null) {
        if (summary['heart_rate'] == null) score -= 5;
        if (summary['spo2'] != null && summary['spo2']['value'] < 95) {
          score -= 10;
        }
      }
      if (!profile.isEmpty && profile.age != null && profile.age! > 65) {
        score -= 5;
      }
      _healthScore = score.clamp(0, 100);

      setState(() => _loading = false);
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    final metrics = [
      _HealthMetric(
        icon: Icons.favorite_rounded,
        label: 'Heart Rate',
        value: _heartRate,
        unit: 'BPM',
        color: const Color(0xFFEF5350),
      ),
      _HealthMetric(
        icon: Icons.monitor_heart_rounded,
        label: 'Blood Pressure',
        value: _bloodPressure,
        unit: 'mmHg',
        color: const Color(0xFF42A5F5),
      ),
      _HealthMetric(
        icon: Icons.health_and_safety_rounded,
        label: 'Health Score',
        value: '$_healthScore',
        unit: '%',
        color: const Color(0xFF66BB6A),
      ),
    ];

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: const Duration(milliseconds: 800),
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
              const Color(0xFF42A5F5).withValues(alpha: 0.08),
              cs.surfaceContainerHighest,
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          border: Border.all(
            color: const Color(0xFF42A5F5).withValues(alpha: 0.18),
            width: 1.5,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: const Color(0xFF42A5F5).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(
                    Icons.monitor_heart_rounded,
                    color: Color(0xFF42A5F5),
                    size: 24,
                  ),
                ),
                const SizedBox(width: 14),
                Text(
                  'Health Status',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: cs.onSurface,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Metric tiles
            _loading
                ? const Center(
                    child: Padding(
                      padding: EdgeInsets.symmetric(vertical: 20),
                      child: SizedBox(
                        width: 28,
                        height: 28,
                        child: CircularProgressIndicator(strokeWidth: 2.5),
                      ),
                    ),
                  )
                : Row(
                    children: metrics
                        .map((m) => Expanded(child: _buildMetricTile(m, cs)))
                        .toList(),
                  ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetricTile(_HealthMetric m, ColorScheme cs) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 4),
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
      decoration: BoxDecoration(
        color: m.color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: m.color.withValues(alpha: 0.15)),
      ),
      child: Column(
        children: [
          Icon(m.icon, color: m.color, size: 26),
          const SizedBox(height: 10),
          Text(
            m.value,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: cs.onSurface,
            ),
          ),
          Text(
            m.unit,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: cs.onSurface.withValues(alpha: 0.5),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            m.label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: cs.onSurface.withValues(alpha: 0.65),
            ),
          ),
        ],
      ),
    );
  }
}

class _HealthMetric {
  final IconData icon;
  final String label;
  final String value;
  final String unit;
  final Color color;

  const _HealthMetric({
    required this.icon,
    required this.label,
    required this.value,
    required this.unit,
    required this.color,
  });
}

// ═══════════════════════════════════════════════════════════════
//  4. SOS EMERGENCY BUTTON
// ═══════════════════════════════════════════════════════════════

class _SosEmergencyButton extends StatelessWidget {
  final VoidCallback onPressed;
  const _SosEmergencyButton({required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: const Duration(milliseconds: 900),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) => Opacity(
        opacity: value,
        child: Transform.translate(
          offset: Offset(0, 20 * (1 - value)),
          child: child,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(22),
          splashColor: Colors.white24,
          child: Ink(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(22),
              gradient: const LinearGradient(
                colors: [Color(0xFFEF5350), Color(0xFFC62828)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFEF5350).withValues(alpha: 0.35),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 20),
              alignment: Alignment.center,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: const [
                  Icon(Icons.sos_rounded, color: Colors.white, size: 28),
                  SizedBox(width: 12),
                  Text(
                    'EMERGENCY SOS',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                      letterSpacing: 2,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
