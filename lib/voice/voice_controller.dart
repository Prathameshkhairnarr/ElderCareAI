import 'package:flutter/foundation.dart';
import 'speech_service.dart';
import 'voice_engine.dart';
import 'ai_brain_service.dart';
import 'action_handler.dart';
import 'language_detector.dart';
import 'conversation_memory.dart';
import '../services/app_logger.dart';

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

  // ══════════════════════════════════════════════
  //  PRIMARY ACTION — Tap to listen/stop
  // ══════════════════════════════════════════════

  /// Called when user taps the mic button.
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

  void _processTranscript(String text) async {
    if (text.trim().isEmpty) {
      // Speak friendly retry instead of showing error
      _response = "Mujhe awaaz clear nahi mili, dobara boliyega.";
      _speakResponse(_response, 'hi-IN');
      return;
    }

    _setState(VoiceState.processing);

    // ── Detect language ──
    final detected = LanguageDetector.detect(text);
    _lastLanguage = detected;
    final ttsLocale = LanguageDetector.ttsLocale(detected);

    AppLogger.info(
      LogCategory.lifecycle,
      '[VOICE] Detected language: ${detected.name}, TTS locale: $ttsLocale',
    );

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
      _speakResponse(_response, ttsLocale);
    }
  }

  // ── Speak with emotion ──
  Future<void> _speakWithEmotion(
    String text,
    String locale,
    dynamic emotion,
  ) async {
    _setState(VoiceState.speaking);
    try {
      // VoiceEngine handles text cleaning, ElevenLabs → flutter_tts fallback
      await _voiceEngine.speakWithEmotion(text, locale, emotion);
    } catch (e) {
      AppLogger.error(LogCategory.lifecycle, '[VOICE] Speak error: $e');
    }
    // Return to idle after speaking (unless disposed)
    if (_state == VoiceState.speaking) {
      _setState(VoiceState.idle);
    }
  }

  // ── Speak (plain, for fallback/retry) ──
  Future<void> _speakResponse(String text, String locale) async {
    _setState(VoiceState.speaking);
    try {
      // VoiceEngine handles text cleaning, ElevenLabs → flutter_tts fallback
      await _voiceEngine.speak(text, locale);
    } catch (e) {
      AppLogger.error(LogCategory.lifecycle, '[VOICE] Speak error: $e');
    }
    // Return to idle after speaking (unless disposed)
    if (_state == VoiceState.speaking) {
      _setState(VoiceState.idle);
    }
  }

  Future<void> _stopSpeaking() async {
    await _voiceEngine.stop();
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
