import 'dart:async';
import 'package:flutter_tts/flutter_tts.dart';
import '../services/app_logger.dart';
import 'voice_selector.dart';
import 'speech_naturalizer.dart';
import 'emotion_tagger.dart';

/// Text-to-Speech wrapper — Hindi female voice, elder-friendly tuning.
///
/// Features:
///   - Default locale: hi-IN with en-IN fallback
///   - Auto-selects best female voice via [VoiceSelector]
///   - Pre-TTS naturalization via [SpeechNaturalizer]
///   - Sentence-by-sentence chunked playback
///   - Debounce guard to prevent double-speak
///   - Stop-before-new speech management
///   - Elder-friendly rate/pitch clamping
class TtsService {
  final FlutterTts _tts = FlutterTts();
  bool _isSpeaking = false;
  Completer<void>? _speakCompleter;

  /// Cancel flag — set true when stop() is called during chunked playback.
  bool _cancelRequested = false;

  /// Debounce guard — minimum gap between speak() calls.
  DateTime _lastSpeakTime = DateTime(2000);
  static const _debounceMs = 300;

  /// Current active locale.
  String _currentLocale = 'hi-IN';

  bool get isSpeaking => _isSpeaking;

  // ══════════════════════════════════════════════════════
  //  ELDER-FRIENDLY PARAMETER BOUNDS
  // ══════════════════════════════════════════════════════

  /// Speech rate bounds: slow and clear for elders.
  static const double _minRate = 0.42;
  static const double _maxRate = 0.48;
  static const double _defaultRate = 0.45;

  /// Pitch bounds: warm and natural.
  static const double _minPitch = 1.0;
  static const double _maxPitch = 1.08;
  static const double _defaultPitch = 1.05;

  /// Volume: always maximum clarity.
  static const double _volume = 1.0;

  /// Delay between sentence chunks (ms).
  static const int _interSentenceDelayMs = 250;

  /// Clamp rate to elder-friendly bounds.
  double _clampRate(double rate) => rate.clamp(_minRate, _maxRate);

  /// Clamp pitch to elder-friendly bounds.
  double _clampPitch(double pitch) => pitch.clamp(_minPitch, _maxPitch);

  // ══════════════════════════════════════════════════════
  //  INITIALIZATION
  // ══════════════════════════════════════════════════════

  /// Initialize with Hindi female voice and elder-friendly tuning.
  Future<void> initialize() async {
    try {
      // ── Language availability check ──
      final hindiAvailable = await _isLanguageAvailable('hi-IN');
      if (hindiAvailable) {
        _currentLocale = 'hi-IN';
        await _tts.setLanguage('hi-IN');
        AppLogger.info(LogCategory.lifecycle, '[VOICE] TTS locale set: hi-IN');
      } else {
        _currentLocale = 'en-IN';
        await _tts.setLanguage('en-IN');
        AppLogger.warn(
          LogCategory.lifecycle,
          '[VOICE] Hindi TTS unavailable, fallback: en-IN',
        );
      }

      // ── Female voice selection (cached) ──
      await VoiceSelector.instance.selectBestVoice(_tts);
      if (VoiceSelector.instance.hasVoice) {
        final voice = VoiceSelector.instance.cachedVoice!;
        await _tts.setVoice({
          'name': voice['name'] ?? '',
          'locale': voice['locale'] ?? '',
        });
      }

      // ── Elder-friendly tuning ──
      await _tts.setSpeechRate(_defaultRate);
      await _tts.setPitch(_defaultPitch);
      await _tts.setVolume(_volume);

      // ── Handlers ──
      _tts.setStartHandler(() {
        _isSpeaking = true;
      });

      _tts.setCompletionHandler(() {
        _isSpeaking = false;
        _speakCompleter?.complete();
        _speakCompleter = null;
      });

      _tts.setCancelHandler(() {
        _isSpeaking = false;
        _speakCompleter?.complete();
        _speakCompleter = null;
      });

      _tts.setErrorHandler((msg) {
        _isSpeaking = false;
        _speakCompleter?.complete();
        _speakCompleter = null;
        AppLogger.error(LogCategory.lifecycle, '[VOICE] TTS error: $msg');
      });

      AppLogger.info(
        LogCategory.lifecycle,
        '[VOICE] TTS initialized — locale=$_currentLocale, '
        'rate=$_defaultRate, pitch=$_defaultPitch, volume=$_volume',
      );
    } catch (e) {
      AppLogger.error(LogCategory.lifecycle, '[VOICE] TTS init failed: $e');
    }
  }

  // ══════════════════════════════════════════════════════
  //  PUBLIC SPEAK METHODS
  // ══════════════════════════════════════════════════════

  /// Speak text in the current default locale.
  /// Stops any previous speech first. Applies naturalization.
  /// Returns a Future that completes when speech finishes.
  Future<void> speak(String text) async {
    await speakInLanguage(text, _currentLocale);
  }

  /// Speak with emotion-aware voice modulation.
  ///
  /// Adjusts pitch and rate based on [emotion]:
  /// - reassurance → softer, warmer (rate 0.42, pitch 1.08)
  /// - warning → slightly serious (rate 0.48, pitch 0.98 → clamped to 1.0)
  /// - urgent → clear, firm (rate 0.48, pitch 0.95 → clamped to 1.0)
  /// - neutral → default (rate 0.45, pitch 1.05)
  Future<void> speakWithEmotion(
    String text,
    String locale,
    EmotionTag emotion,
  ) async {
    // Apply emotion-specific tuning (clamped to elder-friendly bounds)
    switch (emotion) {
      case EmotionTag.reassurance:
        await _tts.setSpeechRate(_clampRate(0.42));
        await _tts.setPitch(_clampPitch(1.08));
        break;
      case EmotionTag.warning:
        await _tts.setSpeechRate(_clampRate(0.48));
        await _tts.setPitch(_clampPitch(0.98));
        break;
      case EmotionTag.urgent:
        await _tts.setSpeechRate(_clampRate(0.50));
        await _tts.setPitch(_clampPitch(0.95));
        break;
      case EmotionTag.neutral:
        await _tts.setSpeechRate(_defaultRate);
        await _tts.setPitch(_defaultPitch);
        break;
    }

    AppLogger.info(
      LogCategory.lifecycle,
      '[VOICE] TTS emotion: ${emotion.name}',
    );

    // Speak with the adjusted parameters
    await speakInLanguage(text, locale);

    // Restore defaults after speaking
    await _tts.setSpeechRate(_defaultRate);
    await _tts.setPitch(_defaultPitch);
  }

  /// Speak text in a specific locale (e.g. 'hi-IN' or 'en-IN').
  /// Handles: debounce, stop-before-new, naturalization, language switch,
  /// and sentence-by-sentence chunked playback.
  Future<void> speakInLanguage(String text, String locale) async {
    if (text.isEmpty) return;

    // ── Debounce guard ──
    final now = DateTime.now();
    if (now.difference(_lastSpeakTime).inMilliseconds < _debounceMs) {
      AppLogger.info(
        LogCategory.lifecycle,
        '[VOICE] TTS debounced — too rapid',
      );
      return;
    }
    _lastSpeakTime = now;

    // ── Stop previous speech ──
    if (_isSpeaking) {
      await stop();
    }
    _cancelRequested = false;

    // ── Switch locale if needed ──
    if (locale != _currentLocale) {
      try {
        final available = await _isLanguageAvailable(locale);
        if (available) {
          await _tts.setLanguage(locale);
          _currentLocale = locale;

          // Re-apply female voice for the new locale
          if (VoiceSelector.instance.hasVoice) {
            final voice = VoiceSelector.instance.cachedVoice!;
            await _tts.setVoice({
              'name': voice['name'] ?? '',
              'locale': voice['locale'] ?? '',
            });
          }
        } else {
          AppLogger.warn(
            LogCategory.lifecycle,
            '[VOICE] Locale $locale unavailable, using $_currentLocale',
          );
        }
      } catch (e) {
        AppLogger.error(
          LogCategory.lifecycle,
          '[VOICE] Locale switch failed: $e',
        );
      }
    }

    // ── Naturalize text ──
    final naturalText = SpeechNaturalizer.naturalize(text);

    // ── Split into sentences and speak sequentially ──
    final sentences = _splitIntoSentences(naturalText);

    if (sentences.length <= 1) {
      // Single sentence — speak directly
      await _speakChunk(naturalText);
    } else {
      // Multiple sentences — speak one by one with pauses
      AppLogger.info(
        LogCategory.lifecycle,
        '[VOICE] Chunked playback: ${sentences.length} sentences',
      );

      for (int i = 0; i < sentences.length; i++) {
        if (_cancelRequested) {
          AppLogger.info(
            LogCategory.lifecycle,
            '[VOICE] Chunked playback cancelled at sentence ${i + 1}',
          );
          break;
        }

        await _speakChunk(sentences[i]);

        // Small pause between sentences for natural breathing rhythm
        if (i < sentences.length - 1 && !_cancelRequested) {
          await Future.delayed(
            const Duration(milliseconds: _interSentenceDelayMs),
          );
        }
      }
    }
  }

  // ══════════════════════════════════════════════════════
  //  SENTENCE CHUNKING
  // ══════════════════════════════════════════════════════

  /// Split text into sentences at natural boundaries.
  /// Handles: periods, Hindi purna viram (।), question marks,
  /// exclamation marks.
  static List<String> _splitIntoSentences(String text) {
    // Split on sentence-ending punctuation followed by whitespace or end
    final raw = text.split(RegExp(r'(?<=[.।!?])\s+'));

    // Filter empty chunks and trim
    return raw.map((s) => s.trim()).where((s) => s.isNotEmpty).toList();
  }

  // ══════════════════════════════════════════════════════
  //  INTERNAL SPEAK
  // ══════════════════════════════════════════════════════

  /// Speak a single chunk and wait for completion.
  Future<void> _speakChunk(String chunk) async {
    if (chunk.trim().isEmpty || _cancelRequested) return;

    _speakCompleter = Completer<void>();
    _isSpeaking = true;

    try {
      await _tts.speak(chunk);
      // Wait for completion or cancellation
      await _speakCompleter?.future.timeout(
        const Duration(seconds: 30),
        onTimeout: () {
          _isSpeaking = false;
          AppLogger.warn(LogCategory.lifecycle, '[VOICE] TTS chunk timeout');
        },
      );
    } catch (e) {
      _isSpeaking = false;
      AppLogger.error(LogCategory.lifecycle, '[VOICE] TTS speak failed: $e');
    }
  }

  // ══════════════════════════════════════════════════════
  //  UTILITIES
  // ══════════════════════════════════════════════════════

  /// Check if a TTS language is available on this device.
  Future<bool> _isLanguageAvailable(String locale) async {
    try {
      final result = await _tts.isLanguageAvailable(locale);
      return result == true || result == 1;
    } catch (_) {
      return false;
    }
  }

  /// Stop current speech.
  Future<void> stop() async {
    _cancelRequested = true;
    try {
      await _tts.stop();
    } catch (_) {}
    _isSpeaking = false;
    _speakCompleter?.complete();
    _speakCompleter = null;
  }

  /// Clean up resources.
  void dispose() {
    stop();
    _tts.stop();
  }
}
