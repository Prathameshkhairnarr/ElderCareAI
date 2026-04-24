import 'dart:async';
import 'package:flutter/foundation.dart';
import 'speech_service.dart';
import 'voice_engine.dart';
import 'child_brain_service.dart';
import 'language_detector.dart';
import '../services/app_logger.dart';

import 'voice_controller.dart' show VoiceState;

class ChildVoiceController extends ChangeNotifier {
  final SpeechService _stt = SpeechService();
  final VoiceEngine _voiceEngine = VoiceEngine(isMaleVoice: true);
  final ChildBrainService _ai = ChildBrainService.instance;

  VoiceState _state = VoiceState.idle;
  String _transcript = '';
  String _response = '';
  String _errorMessage = '';
  bool _initialized = false;
  bool _busy = false;

  bool _isConversationActive = false;
  static const _relistenDelay = Duration(milliseconds: 600);

  static const _stopKeywords = ['stop', 'ruk', 'ruko', 'chup', 'shut up', 'ok stop'];
  DetectedLanguage _lastLanguage = DetectedLanguage.hindi;

  VoiceState get state => _state;
  String get transcript => _transcript;
  String get response => _response;
  String get errorMessage => _errorMessage;
  bool get isIdle => _state == VoiceState.idle;
  bool get isListening => _state == VoiceState.listening;
  bool get isProcessing => _state == VoiceState.processing;
  bool get isSpeaking => _state == VoiceState.speaking;
  bool get hasError => _state == VoiceState.error;

  Future<bool> _ensureInit() async {
    if (_initialized) return true;
    try {
      final sttReady = await _stt.initialize();
      await _voiceEngine.initialize();
      _initialized = sttReady;
      if (!sttReady) _setError('Microphone not available.');
      return sttReady;
    } catch (e) {
      _setError('Buddy assistant could not start.');
      return false;
    }
  }

  bool _greetingSpoken = false;

  Future<void> speakGreeting() async {
    if (_greetingSpoken) return;
    _greetingSpoken = true;

    final ready = await _ensureInit();
    if (!ready) return;

    const greeting = 'Aur bhai kya chal raha hai? Main tera naya AI best friend. Bata, kya scene hai aaj ka?';
    _response = greeting;
    _setState(VoiceState.speaking);

    try {
      await _voiceEngine.speak(greeting, 'hi-IN');
    } catch (e) {
      AppLogger.error(LogCategory.lifecycle, '[CHILD_VOICE] Greeting error: $e');
    }

    if (_state == VoiceState.speaking) {
      _setState(VoiceState.idle);
    }
  }

  Future<void> onMicTap() async {
    if (_busy) return;
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
        case VoiceState.processing:
          _isConversationActive = false;
          await _stt.cancel();
          await _voiceEngine.stop();
          _setState(VoiceState.idle);
          break;
      }
    } finally {
      _busy = false;
    }
  }

  Future<void> _startListening() async {
    final ready = await _ensureInit();
    if (!ready) return;

    _transcript = '';
    _response = '';
    _errorMessage = '';
    _setState(VoiceState.listening);

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
        _transcript = '';
        _response = "Awaaz thodi cut rahi hai, fir se bolna plz?";
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

  void _processTranscript(String text) async {
    if (text.trim().isEmpty) {
      _response = "Hmmm... wapas bolna, theek se sunai nahi diya.";
      _speakResponse(_response, 'hi-IN');
      return;
    }

    final lowerText = text.toLowerCase().trim();
    if (_stopKeywords.any((k) => lowerText.contains(k))) {
      _isConversationActive = false;
      await _voiceEngine.stop();
      _response = '';
      _setState(VoiceState.idle);
      return;
    }

    _setState(VoiceState.processing);
    await _stt.cancel();

    try {
      final detected = LanguageDetector.detect(text);
      _lastLanguage = detected;
      final ttsLocale = LanguageDetector.ttsLocale(detected);

      final aiResponse = await _ai.generateResponse(text, language: detected);
      _response = aiResponse.text;
      
      await _speakWithEmotion(_response, ttsLocale, aiResponse.emotion);
    } catch (e) {
      AppLogger.error(LogCategory.lifecycle, '[CHILD_VOICE] Process error: $e');
      _response = "Oops, kuch error gaya. Try again.";
      await _speakResponse(_response, 'hi-IN');
    }
  }

  Future<void> _speakWithEmotion(String text, String locale, dynamic emotion) async {
    await _stt.cancel();
    _setState(VoiceState.speaking);
    try {
      await _voiceEngine.speakWithEmotion(text, locale, emotion);
    } catch (e) {}
    await _afterSpeaking();
  }

  Future<void> _speakResponse(String text, String locale) async {
    await _stt.cancel();
    _setState(VoiceState.speaking);
    try {
      await _voiceEngine.speak(text, locale);
    } catch (e) {}
    await _afterSpeaking();
  }

  Future<void> _afterSpeaking() async {
    if (_state != VoiceState.speaking) return;
    if (_isConversationActive) {
      await Future.delayed(_relistenDelay);
      if (_isConversationActive && _state == VoiceState.speaking) {
        await _startListening();
      }
    } else {
      _setState(VoiceState.idle);
    }
  }

  void forceReset() {
    _busy = false;
    _isConversationActive = false;
    _stt.cancel();
    _voiceEngine.stop();
    _setState(VoiceState.idle);
  }

  void _setState(VoiceState newState) {
    _state = newState;
    notifyListeners();
  }

  void _setError(String msg) {
    _errorMessage = msg;
    _setState(VoiceState.error);
    Future.delayed(const Duration(seconds: 5), () {
      if (_state == VoiceState.error) _setState(VoiceState.idle);
    });
  }

  @override
  void dispose() {
    _stt.dispose();
    _voiceEngine.dispose();
    super.dispose();
  }
}
