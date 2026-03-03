import 'package:flutter/material.dart';
import 'voice_controller.dart';

/// Elder-friendly floating voice assistant widget.
/// Shows a large mic FAB with state-aware animations and a response sheet.
class AssistantWidget extends StatefulWidget {
  const AssistantWidget({super.key});

  @override
  State<AssistantWidget> createState() => _AssistantWidgetState();
}

class _AssistantWidgetState extends State<AssistantWidget>
    with SingleTickerProviderStateMixin {
  final VoiceController _controller = VoiceController();
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _controller.addListener(_onStateChange);
  }

  @override
  void dispose() {
    _controller.removeListener(_onStateChange);
    _controller.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  void _onStateChange() {
    if (!mounted) return;
    setState(() {});

    // Manage pulse animation based on state
    if (_controller.isListening) {
      _pulseController.repeat(reverse: true);
    } else {
      _pulseController.stop();
      _pulseController.reset();
    }
  }

  void _onMicTap() async {
    await _controller.onMicTap();

    // Show response sheet when we have a response
    if (_controller.response.isNotEmpty && mounted) {
      _showResponseSheet();
    }
  }

  void _showResponseSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _ResponseSheet(
        transcript: _controller.transcript,
        response: _controller.response,
        state: _controller.state,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Status label above mic
        if (!_controller.isIdle) ...[
          _buildStatusChip(),
          const SizedBox(height: 8),
        ],
        // Mic FAB
        _buildMicButton(),
      ],
    );
  }

  Widget _buildStatusChip() {
    String label;
    Color color;
    IconData icon;

    switch (_controller.state) {
      case VoiceState.listening:
        label = 'Listening...';
        color = const Color(0xFFEF5350);
        icon = Icons.mic_rounded;
        break;
      case VoiceState.processing:
        label = 'Thinking...';
        color = const Color(0xFF7C4DFF);
        icon = Icons.psychology_rounded;
        break;
      case VoiceState.speaking:
        label = 'Speaking...';
        color = const Color(0xFF26A69A);
        icon = Icons.volume_up_rounded;
        break;
      case VoiceState.error:
        label = 'Error';
        color = Colors.redAccent;
        icon = Icons.error_outline_rounded;
        break;
      default:
        return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMicButton() {
    Color bgColor;
    IconData icon;

    switch (_controller.state) {
      case VoiceState.listening:
        bgColor = const Color(0xFFEF5350);
        icon = Icons.stop_rounded;
        break;
      case VoiceState.processing:
        bgColor = const Color(0xFF7C4DFF);
        icon = Icons.psychology_rounded;
        break;
      case VoiceState.speaking:
        bgColor = const Color(0xFF26A69A);
        icon = Icons.volume_up_rounded;
        break;
      case VoiceState.error:
        bgColor = Colors.redAccent;
        icon = Icons.refresh_rounded;
        break;
      default:
        bgColor = const Color(0xFF4FC3F7);
        icon = Icons.mic_rounded;
    }

    return AnimatedBuilder(
      animation: _pulseController,
      builder: (context, child) {
        final scale = _controller.isListening
            ? 1.0 + (_pulseController.value * 0.12)
            : 1.0;

        return Transform.scale(
          scale: scale,
          child: Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: bgColor.withValues(alpha: 0.35),
                  blurRadius: _controller.isListening ? 20 : 10,
                  spreadRadius: _controller.isListening ? 4 : 0,
                ),
              ],
            ),
            child: FloatingActionButton.large(
              heroTag: 'voice_assistant_fab',
              backgroundColor: bgColor,
              elevation: 4,
              onPressed: _controller.isProcessing ? null : _onMicTap,
              child: _controller.isProcessing
                  ? const SizedBox(
                      width: 28,
                      height: 28,
                      child: CircularProgressIndicator(
                        strokeWidth: 3,
                        color: Colors.white,
                      ),
                    )
                  : Icon(icon, size: 32, color: Colors.white),
            ),
          ),
        );
      },
    );
  }
}

// ── Response Bottom Sheet ──
class _ResponseSheet extends StatelessWidget {
  final String transcript;
  final String response;
  final VoiceState state;

  const _ResponseSheet({
    required this.transcript,
    required this.response,
    required this.state,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Container(
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
          // Handle bar
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

          // "You said" section
          if (transcript.isNotEmpty) ...[
            Row(
              children: [
                Icon(
                  Icons.person_rounded,
                  size: 18,
                  color: cs.onSurface.withValues(alpha: 0.5),
                ),
                const SizedBox(width: 8),
                Text(
                  'You said',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: cs.onSurface.withValues(alpha: 0.5),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: cs.surface,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                transcript,
                style: TextStyle(
                  fontSize: 15,
                  color: cs.onSurface,
                  height: 1.4,
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],

          // Assistant response
          if (response.isNotEmpty) ...[
            Row(
              children: [
                const Icon(
                  Icons.smart_toy_rounded,
                  size: 18,
                  color: Color(0xFF4FC3F7),
                ),
                const SizedBox(width: 8),
                Text(
                  'Assistant',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF4FC3F7).withValues(alpha: 0.8),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF4FC3F7).withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: const Color(0xFF4FC3F7).withValues(alpha: 0.15),
                ),
              ),
              child: Text(
                response,
                style: TextStyle(
                  fontSize: 15,
                  color: cs.onSurface,
                  height: 1.5,
                ),
              ),
            ),
          ],

          const SizedBox(height: 12),
        ],
      ),
    );
  }
}
