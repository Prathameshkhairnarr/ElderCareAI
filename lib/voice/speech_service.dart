import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:speech_to_text/speech_recognition_result.dart';
import '../services/app_logger.dart';

/// Speech-to-Text wrapper — elder-friendly, tolerant timings.
/// Never throws; all errors surfaced via callbacks.
class SpeechService {
  final stt.SpeechToText _speech = stt.SpeechToText();
  bool _isAvailable = false;
  bool _isListening = false;

  bool get isListening => _isListening;
  bool get isAvailable => _isAvailable;

  /// Initialize speech engine. Returns true if mic is available & permitted.
  Future<bool> initialize() async {
    try {
      _isAvailable = await _speech.initialize(
        onError: (error) {
          AppLogger.warn(
            LogCategory.lifecycle,
            '[VOICE] STT error: ${error.errorMsg}',
          );
          _isListening = false;
        },
        onStatus: (status) {
          AppLogger.info(LogCategory.lifecycle, '[VOICE] STT status: $status');
          if (status == 'notListening' || status == 'done') {
            _isListening = false;
          }
        },
      );
      AppLogger.info(
        LogCategory.lifecycle,
        '[VOICE] STT init: available=$_isAvailable',
      );
      return _isAvailable;
    } catch (e) {
      AppLogger.error(LogCategory.lifecycle, '[VOICE] STT init failed: $e');
      _isAvailable = false;
      return false;
    }
  }

  /// Start listening with elder-friendly timings.
  /// Calls [onResult] with final recognized text,
  /// [onPartial] with interim results, and [onTimeout] on speech timeout.
  /// [localeId] defaults to 'hi_IN' for Hindi-first listening.
  Future<void> startListening({
    required void Function(String text) onResult,
    void Function(String partial)? onPartial,
    void Function()? onTimeout,
    String localeId = 'hi_IN',
    Duration listenFor = const Duration(seconds: 30),
    Duration pauseFor = const Duration(seconds: 5),
  }) async {
    if (_isListening) return; // prevent double-listen

    // ── Permission recheck ──
    if (!_isAvailable) {
      final ok = await initialize();
      if (!ok) {
        AppLogger.warn(
          LogCategory.lifecycle,
          '[VOICE] Mic unavailable or permission denied',
        );
        return;
      }
    }

    // ── Pre-listening warm-up buffer (500ms) ──
    // Lets the mic hardware stabilize before STT starts counting timeout
    await Future.delayed(const Duration(milliseconds: 500));

    _isListening = true;

    AppLogger.info(
      LogCategory.lifecycle,
      '[VOICE] STT listening with locale: $localeId',
    );

    try {
      await _speech.listen(
        onResult: (SpeechRecognitionResult result) {
          if (result.finalResult) {
            _isListening = false;
            final text = result.recognizedWords.trim();
            if (text.isNotEmpty) {
              onResult(text);
            } else {
              // Empty final result = timeout equivalent
              onTimeout?.call();
            }
          } else {
            onPartial?.call(result.recognizedWords);
          }
        },
        listenFor: listenFor,
        pauseFor: pauseFor,
        listenOptions: stt.SpeechListenOptions(
          partialResults: true,
          cancelOnError: false, // don't cancel on timeout, handle gracefully
          listenMode: stt.ListenMode.dictation,
          autoPunctuation: true,
        ),
        localeId: localeId,
      );
    } catch (e) {
      _isListening = false;
      AppLogger.error(LogCategory.lifecycle, '[VOICE] Listen failed: $e');
    }
  }

  /// Stop listening immediately.
  Future<void> stopListening() async {
    if (!_isListening) return;
    try {
      await _speech.stop();
    } catch (e) {
      AppLogger.error(LogCategory.lifecycle, '[VOICE] Stop failed: $e');
    }
    _isListening = false;
  }

  /// Cancel without processing.
  Future<void> cancel() async {
    try {
      await _speech.cancel();
    } catch (_) {}
    _isListening = false;
  }

  /// Clean up resources.
  void dispose() {
    cancel();
  }
}
