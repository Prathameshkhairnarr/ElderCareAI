import 'package:flutter/material.dart';
import '../voice/voice_controller.dart';
import '../voice/medical_response_parser.dart';
import '../models/medication.dart';
import '../services/emergency_service.dart';
import '../services/api_service.dart';
import '../services/google_fit_service.dart';
import '../widgets/health_profile_card.dart';

// ═══════════════════════════════════════════════════════════════
//  AI DOCTOR SCREEN
//  Elderly-friendly dashboard: Voice · Medication · Health · SOS
// ═══════════════════════════════════════════════════════════════

class AiDoctorScreen extends StatefulWidget {
  final bool isVisible;
  const AiDoctorScreen({super.key, this.isVisible = true});

  @override
  State<AiDoctorScreen> createState() => _AiDoctorScreenState();
}

class _AiDoctorScreenState extends State<AiDoctorScreen>
    with WidgetsBindingObserver {
  final VoiceController _voice = VoiceController();

  /// Parsed medical response shown in the inline card (null = no card).
  MedicalResponse? _lastMedicalResponse;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _voice.addListener(_onVoiceUpdate);
    // Start wake word only if tab is currently visible
    if (widget.isVisible) {
      _voice.startWakeWordDetection();
    }
  }

  @override
  void didUpdateWidget(covariant AiDoctorScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isVisible != widget.isVisible) {
      if (widget.isVisible) {
        // Tab became visible — restart wake word
        _voice.startWakeWordDetection();
      } else {
        // Tab became hidden — force stop EVERYTHING
        _voice.stopWakeWordDetection();
        _voice.forceReset();
      }
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      // App going to background or screen off — stop wake word mic to save battery
      _voice.stopWakeWordDetection();
      // Only reset if completely idle, DO NOT cut off active conversations or speech
      if (_voice.isIdle) {
        _voice.forceReset();
      }
    } else if (state == AppLifecycleState.resumed && widget.isVisible) {
      // App came back — restart wake word
      _voice.startWakeWordDetection();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _voice.stopWakeWordDetection();
    _voice.forceReset();
    _voice.removeListener(_onVoiceUpdate);
    _voice.dispose();
    super.dispose();
  }

  void _onVoiceUpdate() {
    // Parse response whenever voice controller returns a new text response
    if (_voice.response.isNotEmpty && _voice.isIdle) {
      final parsed = MedicalResponseParser.parse(_voice.response);
      if (parsed != null && mounted) {
        setState(() => _lastMedicalResponse = parsed);
      }
    }
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
            const Text('AI Doctor — Veda'),
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
            // ── Voice Assistant ──
            _VoiceAssistantCard(controller: _voice),
            const SizedBox(height: 20),

            // ── Structured Medical Response Card (appears after AI reply) ──
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 400),
              transitionBuilder: (child, animation) => SlideTransition(
                position: Tween<Offset>(
                  begin: const Offset(0, -0.2),
                  end: Offset.zero,
                ).animate(CurvedAnimation(
                  parent: animation,
                  curve: Curves.easeOutCubic,
                )),
                child: FadeTransition(opacity: animation, child: child),
              ),
              child: _lastMedicalResponse != null
                  ? Padding(
                      key: ValueKey(_lastMedicalResponse.hashCode),
                      padding: const EdgeInsets.only(bottom: 20),
                      child: _MedicalResponseCard(
                        response: _lastMedicalResponse!,
                        onDismiss: () =>
                            setState(() => _lastMedicalResponse = null),
                      ),
                    )
                  : const SizedBox.shrink(key: ValueKey('empty')),
            ),

            // ── Health Profile Summary ──
            const HealthProfileCard(),
            const SizedBox(height: 20),

            // ── Active Medications ──
            const _MedicationReminderCard(),
            const SizedBox(height: 20),

            // ── Live Health Metrics ──
            const _HealthCheckCard(),
            const SizedBox(height: 28),

            // ── Emergency SOS ──
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
//  1. STRUCTURED MEDICAL RESPONSE CARD
// ═══════════════════════════════════════════════════════════════

class _MedicalResponseCard extends StatelessWidget {
  final MedicalResponse response;
  final VoidCallback onDismiss;

  const _MedicalResponseCard({
    required this.response,
    required this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    if (!response.hasContent) return const SizedBox.shrink();

    final cs = Theme.of(context).colorScheme;

    return Stack(
      children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: cs.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: response.isEmergency 
                  ? const Color(0xFFEF5350).withOpacity(0.4) 
                  : cs.primary.withOpacity(0.2),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: (response.isEmergency ? const Color(0xFFEF5350) : cs.primary)
                    .withOpacity(0.1),
                blurRadius: 20,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Header ──
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: (response.isEmergency ? const Color(0xFFEF5350) : cs.primary)
                          .withOpacity(0.15),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      response.isEmergency ? Icons.warning_rounded : Icons.health_and_safety_rounded,
                      color: response.isEmergency ? const Color(0xFFEF5350) : cs.primary,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Doctor Veda says',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: cs.onSurface.withOpacity(0.7),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // ── Body ──
              if (response.condition.isNotEmpty) ...[
                _buildSectionLabel(context, 'POSSIBLE CONDITION', Icons.search_rounded),
                const SizedBox(height: 6),
                Text(
                  response.condition,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: cs.onSurface,
                  ),
                ),
                const SizedBox(height: 16),
              ],

              if (response.explanation.isNotEmpty) ...[
                _buildSectionLabel(context, 'EXPLANATION', Icons.info_outline_rounded),
                const SizedBox(height: 6),
                Text(
                  response.explanation,
                  style: TextStyle(
                    fontSize: 15,
                    height: 1.4,
                    color: cs.onSurface.withOpacity(0.9),
                  ),
                ),
                const SizedBox(height: 16),
              ],

              if (response.symptoms.isNotEmpty) ...[
                _buildSectionLabel(context, 'MATCHING SYMPTOMS', Icons.list_alt_rounded),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: response.symptoms.map((symptom) {
                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: cs.surface,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: cs.outline.withOpacity(0.2)),
                      ),
                      child: Text(
                        symptom,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: cs.onSurface.withOpacity(0.8),
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 16),
              ],

              if (response.care.isNotEmpty) ...[
                _buildSectionLabel(context, 'SUGGESTED CARE', Icons.healing_rounded),
                const SizedBox(height: 6),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.green.withOpacity(0.3)),
                  ),
                  child: Text(
                    response.care,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      color: Colors.green.shade700,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
              ],

              if (response.doctorWarning.isNotEmpty) ...[
                _buildSectionLabel(
                  context, 
                  'DOCTOR WARNING', 
                  Icons.warning_amber_rounded,
                  color: response.isEmergency ? const Color(0xFFEF5350) : Colors.orange.shade700,
                ),
                const SizedBox(height: 6),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: (response.isEmergency ? const Color(0xFFEF5350) : Colors.orange).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: (response.isEmergency ? const Color(0xFFEF5350) : Colors.orange).withOpacity(0.3)
                    ),
                  ),
                  child: Text(
                    response.doctorWarning,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: response.isEmergency ? const Color(0xFFE53935) : Colors.orange.shade800,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),

        // ── Close Button ──
        Positioned(
          top: 8,
          right: 8,
          child: IconButton(
            icon: const Icon(Icons.close_rounded, size: 20),
            color: cs.onSurface.withOpacity(0.5),
            style: IconButton.styleFrom(
              backgroundColor: cs.surface.withOpacity(0.5),
            ),
            onPressed: onDismiss,
          ),
        ),
      ],
    );
  }

  Widget _buildSectionLabel(BuildContext context, String title, IconData icon, {Color? color}) {
    final cs = Theme.of(context).colorScheme;
    final finalColor = color ?? cs.onSurface.withOpacity(0.5);
    return Row(
      children: [
        Icon(icon, size: 14, color: finalColor),
        const SizedBox(width: 6),
        Text(
          title,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.2,
            color: finalColor,
          ),
        ),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════
//  2. VOICE ASSISTANT CARD
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
                        onTap: _onMicTap,
                        onLongPress: _onMicLongPress,
                        onDoubleTap: () => _vc.forceReset(),
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

class _MedicationReminderCard extends StatefulWidget {
  const _MedicationReminderCard();

  @override
  State<_MedicationReminderCard> createState() => _MedicationReminderCardState();
}

class _MedicationReminderCardState extends State<_MedicationReminderCard> {
  final _api = ApiService();
  bool _loading = true;
  List<UserMedication> _medications = [];

  @override
  void initState() {
    super.initState();
    _loadMeds();
  }

  Future<void> _loadMeds() async {
    try {
      final meds = await _api.getUserMedications();
      if (mounted) {
        setState(() {
          _medications = meds;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    const accentColor = Color(0xFF66BB6A); // calm green

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
                    'Active Medications',
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

            if (_loading)
              const Center(child: Padding(padding: EdgeInsets.all(20), child: CircularProgressIndicator()))
            else if (_medications.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 20),
                child: Center(
                  child: Text(
                    'No active medications tracking.',
                    style: TextStyle(color: cs.onSurface.withValues(alpha: 0.5)),
                  ),
                ),
              )
            else
              // Medication list
              ..._medications.map((med) {
                final dosage = '${med.dosageValue != null ? med.dosageValue.toString() : ""} ${med.dosageUnit ?? ""}';
                final time = med.timeOfDay ?? '${med.frequencyPerDay}x / day';
                
                return Padding(
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
                                med.medicine.name,
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: cs.onSurface,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                dosage.trim().isNotEmpty ? dosage.trim() : 'As prescribed',
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
                                time,
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
                );
              }),
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
  final _googleFit = GoogleFitService();

  @override
  void initState() {
    super.initState();
    _googleFit.addListener(_onCacheUpdated);
  }

  @override
  void dispose() {
    _googleFit.removeListener(_onCacheUpdated);
    super.dispose();
  }

  void _onCacheUpdated() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    // ONLY read from GoogleFitService cache — single source of truth
    // HealthMonitorScreen is the ONLY writer to this cache
    // This widget auto-rebuilds when cache changes via ChangeNotifier
    final heartRate = _googleFit.cachedHeartRate > 0 
        ? _googleFit.cachedHeartRate.toInt().toString() 
        : '--';
    final bloodPressure = _googleFit.cachedBloodPressure != null 
        ? _googleFit.cachedBloodPressure!.toInt().toString() 
        : '--';
    final healthScore = _googleFit.cachedHealthScore;

    final metrics = [
      _HealthMetric(
        icon: Icons.favorite_rounded,
        label: 'Heart Rate',
        value: heartRate,
        unit: 'BPM',
        color: const Color(0xFFEF5350),
      ),
      _HealthMetric(
        icon: Icons.monitor_heart_rounded,
        label: 'Blood Pressure',
        value: bloodPressure,
        unit: 'mmHg',
        color: const Color(0xFF42A5F5),
      ),
      _HealthMetric(
        icon: Icons.health_and_safety_rounded,
        label: 'Health Score',
        value: '$healthScore',
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

            // Metric tiles — read directly from cache, no loading state
            Row(
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
