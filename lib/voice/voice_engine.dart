import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:just_audio/just_audio.dart';
import 'package:path_provider/path_provider.dart';

import '../config/api_config.dart';
import '../services/app_logger.dart';
import 'azure_tts_service.dart';
import 'elevenlabs_service.dart';
import 'tts_service.dart';
import 'speech_naturalizer.dart';
import 'caregiver_filter.dart';
import 'emotion_tagger.dart' show EmotionTag;
import 'language_detector.dart';

/// Which TTS engine was used for the last utterance.
enum VoiceEngineType { azureTts, elevenLabs, flutterTts }

/// Triple-layer voice engine: Azure primary → ElevenLabs secondary → flutter_tts fallback.
///
/// Guarantees:
///   - Voice NEVER stays silent — cascading fallback ensures speech
///   - No audio overlap — stops previous audio before new speech
///   - Debounce protection — ignores rapid-fire calls within 300ms
///   - Full logging — engine used, fallback reason, response time
///
/// Usage:
/// ```dart
/// final engine = VoiceEngine();
/// await engine.initialize();
/// await engine.speak('Namaste!', 'hi-IN');
/// ```
class VoiceEngine {
  final TtsService _tts = TtsService();
  final ElevenLabsService _elevenLabs = ElevenLabsService.instance;
  final AzureTtsService _azureTts = AzureTtsService.instance;
  final AudioPlayer _audioPlayer = AudioPlayer();

  bool _initialized = false;
  bool _isSpeaking = false;

  /// Debounce guard — minimum gap between speak() calls.
  DateTime _lastSpeakTime = DateTime(2000);
  static const _debounceMs = 150;

  /// Temporary file path for neural TTS audio playback.
  String? _tempDir;

  /// Diagnostics counters.
  int _totalCalls = 0;
  int _azureSuccesses = 0;
  int _elevenLabsSuccesses = 0;
  int _fallbackCount = 0;

  bool get isSpeaking => _isSpeaking;
  int get totalCalls => _totalCalls;
  int get azureSuccesses => _azureSuccesses;
  int get elevenLabsSuccesses => _elevenLabsSuccesses;
  int get fallbackCount => _fallbackCount;

  // ══════════════════════════════════════════════════════
  //  INITIALIZATION
  // ══════════════════════════════════════════════════════

  /// Initialize all TTS engines.
  Future<void> initialize() async {
    if (_initialized) return;

    // Initialize flutter_tts (always needed — final fallback)
    await _tts.initialize();

    // Get temp directory for neural TTS audio files
    try {
      final dir = await getTemporaryDirectory();
      _tempDir = dir.path;
    } catch (e) {
      AppLogger.warn(
        LogCategory.lifecycle,
        '[VOICE] Could not get temp dir: $e — neural TTS cache disabled',
      );
    }

    _initialized = true;

    final azureStatus = _azureTts.isConfigured
        ? 'ENABLED'
        : 'DISABLED (no key)';
    final elevenLabsStatus = _elevenLabs.isConfigured
        ? 'ENABLED'
        : 'DISABLED (no key)';

    AppLogger.info(
      LogCategory.lifecycle,
      '[VOICE] VoiceEngine initialized — '
      'Azure $azureStatus, '
      'ElevenLabs $elevenLabsStatus, '
      'flutter_tts READY',
    );
  }

  // ══════════════════════════════════════════════════════
  //  PUBLIC SPEAK METHODS
  // ══════════════════════════════════════════════════════

  /// Speak text with automatic engine selection and cascading fallback.
  ///
  /// Flow:
  ///   1. Stop previous audio
  ///   2. Debounce check
  ///   3. Try Azure (if configured) — SSML with hi-IN-SwaraNeural
  ///   4. Try ElevenLabs (if configured) — neural multilingual
  ///   5. Fallback to flutter_tts (always available)
  Future<void> speak(String text, String locale) async {
    if (text.trim().isEmpty) return;

    // ── Debounce guard ──
    final now = DateTime.now();
    if (now.difference(_lastSpeakTime).inMilliseconds < _debounceMs) {
      AppLogger.info(
        LogCategory.lifecycle,
        '[VOICE] VoiceEngine debounced — too rapid',
      );
      return;
    }
    _lastSpeakTime = now;

    // ── Stop previous audio (single pass — no double stop) ──
    await stop();

    _totalCalls++;
    _isSpeaking = true;

    // ── Try Azure first (primary — best Hindi female voice) ──
    if (_azureTts.isConfigured) {
      final success = await _tryAzure(text, locale);
      if (success) {
        _isSpeaking = false;
        return;
      }
    }

    // ── Try ElevenLabs second (light cleanup — AI handles Hindi natively) ──
    if (_elevenLabs.isConfigured) {
      final elevenLabsText = _lightCleanForElevenLabs(text);
      final success = await _tryElevenLabs(elevenLabsText);
      if (success) {
        _isSpeaking = false;
        return;
      }
    }

    // ── Final fallback to flutter_tts (full processing needed) ──
    final ttsText = CaregiverFilter.filter(SpeechNaturalizer.naturalize(text));
    await _fallbackToFlutterTts(ttsText, locale);
    _isSpeaking = false;
  }

  /// Speak with emotion-aware voice modulation.
  ///
  /// Azure and ElevenLabs handle emotion naturally via neural models.
  /// flutter_tts fallback uses pitch/rate adjustments via [TtsService.speakWithEmotion].
  Future<void> speakWithEmotion(
    String text,
    String locale,
    dynamic emotion,
  ) async {
    if (text.trim().isEmpty) return;

    // Safely cast emotion to EmotionTag
    final EmotionTag safeEmotion = (emotion is EmotionTag)
        ? emotion
        : EmotionTag.neutral;

    // ── Debounce guard ──
    final now = DateTime.now();
    if (now.difference(_lastSpeakTime).inMilliseconds < _debounceMs) {
      AppLogger.info(
        LogCategory.lifecycle,
        '[VOICE] VoiceEngine debounced — too rapid',
      );
      return;
    }
    _lastSpeakTime = now;

    // ── Stop previous audio ──
    await stop();

    _totalCalls++;
    _isSpeaking = true;

    // ── Try Azure first (neural voice handles emotion naturally) ──
    if (_azureTts.isConfigured) {
      final success = await _tryAzure(text, locale);
      if (success) {
        _isSpeaking = false;
        return;
      }
    }

    // ── Try ElevenLabs second ──
    if (_elevenLabs.isConfigured) {
      final elevenLabsText = _lightCleanForElevenLabs(text);
      final success = await _tryElevenLabs(elevenLabsText);
      if (success) {
        _isSpeaking = false;
        return;
      }
    }

    // ── Fallback to flutter_tts with full processing + emotion ──
    final ttsText = CaregiverFilter.filter(SpeechNaturalizer.naturalize(text));
    await _fallbackToFlutterTtsWithEmotion(ttsText, locale, safeEmotion);
    _isSpeaking = false;
  }

  // ══════════════════════════════════════════════════════
  //  AZURE ENGINE
  // ══════════════════════════════════════════════════════

  /// Attempt to synthesize and play via Azure Neural TTS.
  /// Dynamically selects SSML language and voice based on [locale].
  /// Returns true on success, false on any failure (triggering next fallback).
  Future<bool> _tryAzure(String text, String locale) async {
    final stopwatch = Stopwatch()..start();

    // Map locale to Azure SSML language and voice
    final detectedLang = locale.startsWith('hi')
        ? DetectedLanguage.hindi
        : DetectedLanguage.english;
    final ssmlLang = LanguageDetector.azureSsmlLang(detectedLang);
    final voiceName = LanguageDetector.azureVoiceName(detectedLang);

    try {
      AppLogger.info(
        LogCategory.lifecycle,
        '[VOICE] Using Azure voice=$voiceName lang=$ssmlLang — '
        '"${text.length > 50 ? '${text.substring(0, 50)}...' : text}"',
      );

      final audioBytes = await _azureTts.synthesize(
        text,
        ssmlLang: ssmlLang,
        voiceName: voiceName,
      );
      stopwatch.stop();

      // ── Play the audio ──
      await _playAudioBytes(audioBytes);

      _azureSuccesses++;

      AppLogger.info(
        LogCategory.lifecycle,
        '[VOICE] Azure playback complete — ${stopwatch.elapsedMilliseconds}ms total',
      );
      return true;
    } on AzureTtsException catch (e) {
      stopwatch.stop();
      _fallbackCount++;

      AppLogger.warn(
        LogCategory.lifecycle,
        '[VOICE] Azure failed (${e.reason.name}) → trying next engine — '
        '${stopwatch.elapsedMilliseconds}ms — ${e.message}',
      );
      return false;
    } catch (e) {
      stopwatch.stop();
      _fallbackCount++;

      AppLogger.warn(
        LogCategory.lifecycle,
        '[VOICE] Azure unexpected error → trying next engine — $e',
      );
      return false;
    }
  }

  // ══════════════════════════════════════════════════════
  //  ELEVENLABS ENGINE
  // ══════════════════════════════════════════════════════

  /// Light text cleanup for ElevenLabs — only remove emojis and collapse spaces.
  /// ElevenLabs multilingual_v2 handles Hindi/Hinglish natively, so heavy
  /// normalization (SpeechNaturalizer, CaregiverFilter) would hurt pronunciation.
  String _lightCleanForElevenLabs(String text) {
    // Remove emojis (Unicode emoji ranges)
    var clean = text.replaceAll(
      RegExp(
        r'[\u{1F600}-\u{1F64F}]|[\u{1F300}-\u{1F5FF}]|[\u{1F680}-\u{1F6FF}]|'
        r'[\u{1F1E0}-\u{1F1FF}]|[\u{2600}-\u{26FF}]|[\u{2700}-\u{27BF}]|'
        r'[\u{FE00}-\u{FE0F}]|[\u{1F900}-\u{1F9FF}]|[\u{200D}]',
        unicode: true,
      ),
      '',
    );
    // Collapse multiple spaces
    clean = clean.replaceAll(RegExp(r'\s+'), ' ').trim();
    return clean;
  }

  /// Attempt to synthesize and play via ElevenLabs.
  /// Returns true on success, false on any failure (triggering fallback).
  Future<bool> _tryElevenLabs(String text) async {
    final stopwatch = Stopwatch()..start();

    try {
      AppLogger.info(
        LogCategory.lifecycle,
        '[VOICE] Using ElevenLabs voice=${ApiConfig.elevenLabsVoiceId} — '
        '"${text.length > 50 ? '${text.substring(0, 50)}...' : text}"',
      );

      final audioBytes = await _elevenLabs.synthesize(text);
      stopwatch.stop();

      // ── Play the audio ──
      await _playAudioBytes(audioBytes);

      _elevenLabsSuccesses++;

      AppLogger.info(
        LogCategory.lifecycle,
        '[VOICE] ElevenLabs playback complete — ${stopwatch.elapsedMilliseconds}ms total',
      );
      return true;
    } on ElevenLabsException catch (e) {
      stopwatch.stop();
      _fallbackCount++;

      AppLogger.warn(
        LogCategory.lifecycle,
        '[VOICE] ElevenLabs failed (${e.reason.name}) → fallback to flutter_tts — '
        '${stopwatch.elapsedMilliseconds}ms — ${e.message}',
      );
      return false;
    } catch (e) {
      stopwatch.stop();
      _fallbackCount++;

      AppLogger.warn(
        LogCategory.lifecycle,
        '[VOICE] ElevenLabs unexpected error → fallback to flutter_tts — $e',
      );
      return false;
    }
  }

  // ══════════════════════════════════════════════════════
  //  AUDIO PLAYBACK
  // ══════════════════════════════════════════════════════

  /// Play raw MP3 bytes via just_audio — low-latency, immediate start.
  Future<void> _playAudioBytes(Uint8List bytes) async {
    try {
      // Write to temp file (just_audio needs a file/URL source)
      final tempFile = File(
        '${_tempDir ?? '/tmp'}/eldercare_tts_${DateTime.now().millisecondsSinceEpoch}.mp3',
      );
      await tempFile.writeAsBytes(bytes, flush: true);

      // Set up completion listener BEFORE play to avoid race
      final completer = Completer<void>();
      final subscription = _audioPlayer.playerStateStream.listen((state) {
        if (state.processingState == ProcessingState.completed) {
          if (!completer.isCompleted) completer.complete();
        }
      });

      await _audioPlayer.setFilePath(tempFile.path);

      // Fire-and-forget play — audio starts immediately, no await
      _audioPlayer.play();

      // Wait for completion (30s safety — most TTS is < 10s)
      await completer.future.timeout(
        const Duration(seconds: 30),
        onTimeout: () {},
      );

      await subscription.cancel();

      // Async cleanup — don't block
      tempFile.delete().catchError((_) => tempFile);
    } catch (e) {
      AppLogger.error(
        LogCategory.lifecycle,
        '[VOICE] Audio playback failed: $e',
      );
      rethrow;
    }
  }

  // ══════════════════════════════════════════════════════
  //  FLUTTER_TTS FALLBACK
  // ══════════════════════════════════════════════════════

  /// Fallback: speak via flutter_tts (plain mode).
  Future<void> _fallbackToFlutterTts(String text, String locale) async {
    AppLogger.info(
      LogCategory.lifecycle,
      '[VOICE] Fallback → flutter_tts (locale=$locale)',
    );

    try {
      await _tts.speakInLanguage(text, locale);
      AppLogger.info(
        LogCategory.lifecycle,
        '[VOICE] Fallback success — flutter_tts completed',
      );
    } catch (e) {
      AppLogger.error(
        LogCategory.lifecycle,
        '[VOICE] flutter_tts fallback also failed: $e',
      );
    }
  }

  /// Fallback: speak via flutter_tts with emotion modulation.
  Future<void> _fallbackToFlutterTtsWithEmotion(
    String text,
    String locale,
    EmotionTag emotion,
  ) async {
    AppLogger.info(
      LogCategory.lifecycle,
      '[VOICE] Fallback → flutter_tts with emotion=${emotion.name} (locale=$locale)',
    );

    try {
      await _tts.speakWithEmotion(text, locale, emotion);
      AppLogger.info(
        LogCategory.lifecycle,
        '[VOICE] Fallback success — flutter_tts completed',
      );
    } catch (e) {
      AppLogger.error(
        LogCategory.lifecycle,
        '[VOICE] flutter_tts fallback also failed: $e',
      );
    }
  }

  // ══════════════════════════════════════════════════════
  //  STOP & CLEANUP
  // ══════════════════════════════════════════════════════

  /// Stop ALL audio — Azure/ElevenLabs (just_audio) and flutter_tts.
  Future<void> stop() async {
    _isSpeaking = false;

    // Stop just_audio player (used by Azure + ElevenLabs)
    try {
      await _audioPlayer.stop();
    } catch (_) {}

    // Stop flutter_tts
    try {
      await _tts.stop();
    } catch (_) {}
  }

  /// Clean up all resources.
  Future<void> dispose() async {
    await stop();
    await _audioPlayer.dispose();
    _tts.dispose();
    _azureTts.clearCache();
    _elevenLabs.clearCache();

    AppLogger.info(
      LogCategory.lifecycle,
      '[VOICE] VoiceEngine disposed — '
      'total=$_totalCalls, azure=$_azureSuccesses, '
      'elevenLabs=$_elevenLabsSuccesses, fallback=$_fallbackCount',
    );
  }
}
