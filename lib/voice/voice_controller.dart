import 'dart:async';
import 'package:flutter/foundation.dart';
import 'speech_service.dart';
import 'voice_engine.dart';
import 'ai_brain_service.dart';
import 'action_handler.dart';
import 'language_detector.dart';
import 'conversation_memory.dart';
import 'offline_command_handler.dart';
import 'emergency_detector.dart';
import '../services/app_logger.dart';
import '../services/user_memory_service.dart';
import '../services/emergency_service.dart';

/// Voice assistant states.
enum VoiceState { idle, listening, processing, speaking, error }

/// Central voice assistant orchestrator.
/// Manages full lifecycle: tap → permission → listen → STT → AI Brain → Action/Emotion TTS → idle.
/// Supports Voice OS JSON actions: theme, SOS, health profile, module toggle, user name.
///
/// Pipeline:
///   Mic → STT → AI Brain → JSON action? → Execute & Speak confirmation
///                         → Plain text? → EmotionTagger → Emotion TTS → Speaker
class VoiceController extends ChangeNotifier {
  final SpeechService _stt = SpeechService();
  final VoiceEngine _voiceEngine = VoiceEngine();
  final AiBrainService _ai = AiBrainService.instance;

  VoiceState _state = VoiceState.idle;
  String _transcript = '';
  String _response = '';
  String _errorMessage = '';
  bool _initialized = false;
  bool _busy = false; // guard against rapid taps
  bool _processingInProgress =
      false; // guard against duplicate transcript processing

  // ── Continuous conversation mode ──
  bool _isConversationActive = false;
  static const _relistenDelay = Duration(milliseconds: 600);

  // ── Emergency detection state ──
  bool _awaitingEmergencyConfirmation = false;

  /// Navigation callback — set by the widget/screen that hosts the assistant.
  /// Used for voice-driven screen navigation (Phase 6).
  void Function(String routeName)? onNavigate;

  /// Last detected language — used for next STT locale hint.
  DetectedLanguage _lastLanguage = DetectedLanguage.hindi;

  // ── Getters ──
  VoiceState get state => _state;
  String get transcript => _transcript;
  String get response => _response;
  String get errorMessage => _errorMessage;
  bool get isIdle => _state == VoiceState.idle;
  bool get isListening => _state == VoiceState.listening;
  bool get isProcessing => _state == VoiceState.processing;
  bool get isSpeaking => _state == VoiceState.speaking;
  bool get hasError => _state == VoiceState.error;

  /// Whether continuous conversation mode is active.
  bool get isConversationActive => _isConversationActive;

  /// Whether AI mode is active (Gemini configured).
  bool get isAiEnabled => _ai.isAiEnabled;

  /// Conversation turn count.
  int get conversationLength => ConversationMemory.instance.length;

  // ── Initialize ──
  Future<bool> _ensureInit() async {
    if (_initialized) return true;
    try {
      final sttReady = await _stt.initialize();
      await _voiceEngine.initialize();
      await ActionHandler.instance.loadUserName();
      await UserMemoryService.instance.load();
      _initialized = sttReady;
      if (!sttReady) {
        _setError(
          'Microphone not available. Please grant microphone permission in Settings.',
        );
      }
      return sttReady;
    } catch (e) {
      AppLogger.error(LogCategory.lifecycle, '[VOICE] Init failed: $e');
      _setError('Voice assistant could not start.');
      return false;
    }
  }

  // ══════════════════════════════════════════════════════
  //  GREETING — spoken when AI Doctor screen opens
  // ══════════════════════════════════════════════════════

  bool _greetingSpoken = false;

  /// Speak a warm doctor greeting when the screen opens.
  /// Only speaks once per controller lifecycle.
  Future<void> speakGreeting() async {
    if (_greetingSpoken) return;
    _greetingSpoken = true;

    final ready = await _ensureInit();
    if (!ready) return;

    const greeting =
        'Namaste, main aapki AI Doctor hoon. Aap apni samasya bata sakte hain.';
    _response = greeting;
    _setState(VoiceState.speaking);

    try {
      await _voiceEngine.speak(greeting, 'hi-IN');
    } catch (e) {
      AppLogger.error(LogCategory.lifecycle, '[VOICE] Greeting error: $e');
    }

    if (_state == VoiceState.speaking) {
      _setState(VoiceState.idle);
    }
  }

  // ══════════════════════════════════════════════
  //  PRIMARY ACTION — Tap to listen/stop
  // ══════════════════════════════════════════════

  /// Called when user taps the mic button (short tap = single query).
  Future<void> onMicTap() async {
    if (_busy) return; // prevent rapid tap race conditions
    _busy = true;

    try {
      switch (_state) {
        case VoiceState.idle:
        case VoiceState.error:
          await _startListening();
          break;
        case VoiceState.listening:
          await _stopListening();
          break;
        case VoiceState.speaking:
          // Tapping during speech stops TTS AND ends conversation mode
          _isConversationActive = false;
          await _stopSpeaking();
          break;
        case VoiceState.processing:
          // ignore taps during processing
          break;
      }
    } finally {
      _busy = false;
    }
  }

  /// Start continuous conversation mode.
  /// After each AI response, the assistant automatically re-listens.
  Future<void> startConversation() async {
    _isConversationActive = true;
    notifyListeners();
    AppLogger.info(
      LogCategory.lifecycle,
      '[VOICE] Continuous conversation mode STARTED',
    );
    await _startListening();
  }

  /// Stop continuous conversation mode.
  void stopConversation() {
    _isConversationActive = false;
    _stt.cancel();
    _voiceEngine.stop();
    _setState(VoiceState.idle);
    AppLogger.info(
      LogCategory.lifecycle,
      '[VOICE] Continuous conversation mode STOPPED',
    );
  }

  // ── Listen ──
  Future<void> _startListening() async {
    final ready = await _ensureInit();
    if (!ready) return;

    _transcript = '';
    _response = '';
    _errorMessage = '';
    _setState(VoiceState.listening);

    // Use the last detected language to hint STT locale
    final sttLocale = LanguageDetector.sttLocale(_lastLanguage);

    await _stt.startListening(
      onResult: (text) {
        _transcript = text;
        notifyListeners();
        _processTranscript(text);
      },
      onPartial: (partial) {
        _transcript = partial;
        notifyListeners();
      },
      onTimeout: () {
        // ── Graceful timeout: speak friendly retry message ──
        AppLogger.info(
          LogCategory.lifecycle,
          '[VOICE] Timeout — speaking retry prompt',
        );
        _transcript = '';
        _response = "Mujhe awaaz clear nahi mili, dobara boliyega.";
        _speakResponse(_response, 'hi-IN');
      },
      localeId: sttLocale,
    );
  }

  Future<void> _stopListening() async {
    await _stt.stopListening();
    if (_transcript.trim().isNotEmpty) {
      _processTranscript(_transcript);
    } else {
      _setState(VoiceState.idle);
    }
  }

  // ══════════════════════════════════════════════
  //  AI-POWERED PROCESSING PIPELINE
  // ══════════════════════════════════════════════

  /// Overall pipeline timeout — prevents infinite hangs.
  static const _pipelineTimeout = Duration(seconds: 15);

  void _processTranscript(String text) async {
    // ── Debounce: prevent duplicate processing from rapid STT callbacks ──
    if (_processingInProgress) {
      AppLogger.warn(
        LogCategory.lifecycle,
        '[VOICE] Ignoring duplicate _processTranscript call',
      );
      return;
    }

    if (text.trim().isEmpty) {
      // Speak friendly retry instead of showing error
      _response = "Mujhe awaaz clear nahi mili, dobara boliyega.";
      _speakResponse(_response, 'hi-IN');
      return;
    }

    _processingInProgress = true;
    _setState(VoiceState.processing);

    // ── Stop STT immediately — mic must be off during processing/speaking ──
    await _stt.cancel();

    try {
      await _processTranscriptInner(text).timeout(_pipelineTimeout);
    } on TimeoutException {
      AppLogger.error(
        LogCategory.lifecycle,
        '[VOICE] Pipeline timeout after ${_pipelineTimeout.inSeconds}s',
      );
      _response = "Thoda time lag raha hai. Dobara try karein.";
      try {
        await _speakResponse(_response, 'hi-IN');
      } catch (_) {}
    } catch (e) {
      AppLogger.error(LogCategory.lifecycle, '[VOICE] Pipeline error: $e');
      _response = "Kuch gadbad ho gayi. Dobara try karein.";
      try {
        await _speakResponse(_response, 'hi-IN');
      } catch (_) {}
    } finally {
      _processingInProgress = false;
      // Safety net: ensure we always return to idle if state got stuck
      if (_state == VoiceState.processing) {
        _setState(VoiceState.idle);
      }
    }
  }

  /// Inner processing logic — separated so the outer method can add
  /// timeout + error safety net around it.
  Future<void> _processTranscriptInner(String text) async {
    // ── Detect language ──
    final detected = LanguageDetector.detect(text);
    _lastLanguage = detected;
    final ttsLocale = LanguageDetector.ttsLocale(detected);

    AppLogger.info(
      LogCategory.lifecycle,
      '[VOICE] Detected language: ${detected.name}, TTS locale: $ttsLocale',
    );

    // ── Step 0: Emergency detection (highest priority) ──
    final emergency = EmergencyDetector.detect(text);
    if (emergency.isEmergency) {
      final isHindi = detected != DetectedLanguage.english;

      if (_awaitingEmergencyConfirmation) {
        // User confirmed emergency — check for "haan", "yes", "ha"
        final lowerText = text.toLowerCase();
        if (lowerText.contains('haan') ||
            lowerText.contains('yes') ||
            lowerText.contains('ha ') ||
            lowerText.contains('haa') ||
            lowerText.contains('ok') ||
            lowerText.contains('bhejo')) {
          _awaitingEmergencyConfirmation = false;
          EmergencyService().triggerSOS();
          _response = isHindi
              ? 'SOS bhej diya gaya hai. Aapke emergency contacts ko alert hoga.'
              : 'SOS has been sent. Your emergency contacts will be alerted.';
          await _speakResponse(_response, ttsLocale);
          return;
        } else {
          _awaitingEmergencyConfirmation = false;
          _response = isHindi
              ? 'Theek hai, SOS nahi bheja. Agar madad chahiye to mujhe bataiye.'
              : 'OK, SOS not sent. Let me know if you need help.';
          await _speakResponse(_response, ttsLocale);
          return;
        }
      }

      // First detection — ask for confirmation
      _awaitingEmergencyConfirmation = true;
      _response = EmergencyDetector.getConfirmationPrompt(emergency, isHindi);
      await _speakResponse(_response, ttsLocale);
      return;
    } else {
      // Reset if user says something normal
      _awaitingEmergencyConfirmation = false;
    }

    // ── Step 1: Offline commands (instant, no network) ──
    try {
      final offlineResult = await OfflineCommandHandler.instance.tryHandle(
        text,
        detected,
      );
      if (offlineResult != null) {
        _response = offlineResult.spokenResponse;
        AppLogger.info(
          LogCategory.lifecycle,
          '[VOICE] Offline command: "$_response"',
        );
        // Handle navigation if offline command requests it
        if (offlineResult.navigateTo != null && onNavigate != null) {
          onNavigate!(offlineResult.navigateTo!);
        }
        await _speakResponse(_response, ttsLocale);
        return;
      }
    } catch (e) {
      AppLogger.warn(
        LogCategory.lifecycle,
        '[VOICE] Offline handler error: $e',
      );
    }

    // ── AI Brain (with automatic fallback) ──
    try {
      final aiResponse = await _ai.generateResponse(text, language: detected);

      _response = aiResponse.text;

      AppLogger.info(
        LogCategory.lifecycle,
        '[VOICE] Response (${aiResponse.source}): '
        '"${_response.length > 60 ? '${_response.substring(0, 60)}...' : _response}"',
      );

      // ── Check if response is a JSON action ──
      if (ActionHandler.isActionResponse(_response)) {
        final action = ActionHandler.parseAction(_response);
        if (action != null) {
          final isHindi = detected != DetectedLanguage.english;
          final result = await ActionHandler.instance.execute(
            action,
            hindi: isHindi,
          );
          _response = result.spokenResponse;
          await _speakResponse(_response, ttsLocale);
          return;
        }
      }

      // ── Normal text response → speak with emotion ──
      await _speakWithEmotion(_response, ttsLocale, aiResponse.emotion);
    } catch (e) {
      AppLogger.error(LogCategory.lifecycle, '[VOICE] Process error: $e');
      _response = detected == DetectedLanguage.english
          ? "Something went wrong. Please try again."
          : "Kuch gadbad ho gayi. Dobara try karein.";
      await _speakResponse(_response, ttsLocale);
    }
  }

  // ── Speak with emotion ──
  Future<void> _speakWithEmotion(
    String text,
    String locale,
    dynamic emotion,
  ) async {
    // ── Ensure STT is stopped before speaking ──
    await _stt.cancel();
    _setState(VoiceState.speaking);
    try {
      // VoiceEngine handles text cleaning, ElevenLabs → flutter_tts fallback
      await _voiceEngine.speakWithEmotion(text, locale, emotion);
    } catch (e) {
      AppLogger.error(LogCategory.lifecycle, '[VOICE] Speak error: $e');
    }
    // After speaking: auto-relisten or idle
    await _afterSpeaking();
  }

  // ── Speak (plain, for fallback/retry) ──
  Future<void> _speakResponse(String text, String locale) async {
    // ── Ensure STT is stopped before speaking ──
    await _stt.cancel();
    _setState(VoiceState.speaking);
    try {
      // VoiceEngine handles text cleaning, ElevenLabs → flutter_tts fallback
      await _voiceEngine.speak(text, locale);
    } catch (e) {
      AppLogger.error(LogCategory.lifecycle, '[VOICE] Speak error: $e');
    }
    // After speaking: auto-relisten or idle
    await _afterSpeaking();
  }

  /// Post-speaking handler: auto-relisten in conversation mode, else idle.
  Future<void> _afterSpeaking() async {
    if (_state != VoiceState.speaking) return;

    if (_isConversationActive) {
      // Brief delay to prevent mic from picking up TTS audio tail
      await Future.delayed(_relistenDelay);
      if (_isConversationActive && _state == VoiceState.speaking) {
        AppLogger.info(
          LogCategory.lifecycle,
          '[VOICE] Auto-relisten (conversation mode)',
        );
        await _startListening();
      }
    } else {
      _setState(VoiceState.idle);
    }
  }

  Future<void> _stopSpeaking() async {
    await _voiceEngine.stop();
    _isConversationActive = false;
    _setState(VoiceState.idle);
  }

  // ── State helpers ──
  void _setState(VoiceState newState) {
    _state = newState;
    notifyListeners();
  }

  void _setError(String msg) {
    _errorMessage = msg;
    _setState(VoiceState.error);

    // Auto-clear error after 5 seconds
    Future.delayed(const Duration(seconds: 5), () {
      if (_state == VoiceState.error) {
        _setState(VoiceState.idle);
      }
    });
  }

  /// Reset to idle state.
  void reset() {
    _stt.cancel();
    _voiceEngine.stop();
    _transcript = '';
    _response = '';
    _errorMessage = '';
    _busy = false;
    _processingInProgress = false;
    _isConversationActive = false;
    _ai.clearMemory();
    _setState(VoiceState.idle);
  }

  @override
  void dispose() {
    _stt.dispose();
    _voiceEngine.dispose();
    super.dispose();
  }
}
