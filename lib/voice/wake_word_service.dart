import 'dart:async';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import '../services/app_logger.dart';

/// Wake word detection service using speech_to_text for offline keyword spotting.
///
/// Listens for the wake phrase "Hey Doctor" or "Doctor sahab" to activate
/// the voice assistant without touching the phone.
///
/// Implementation: Uses STT in continuous low-power mode, checking for
/// wake word in partial results. When detected, triggers the callback.
///
/// Note: For production, consider dedicated wake word engines like Porcupine.
/// This implementation uses speech_to_text as a lightweight alternative.
class WakeWordService {
  WakeWordService._();
  static final WakeWordService instance = WakeWordService._();

  final stt.SpeechToText _speech = stt.SpeechToText();
  bool _isAvailable = false;
  bool _isListening = false;
  bool _isActive = false;

  /// Callback when wake word is detected.
  void Function()? onWakeWordDetected;

  /// Wake phrases to listen for (case-insensitive).
  static const _wakePhrases = [
    'hey doctor',
    'doctor sahab',
    'hello doctor',
    'ok doctor',
    'hi doctor',
    'doctor ji',
  ];

  /// Cooldown to prevent rapid re-triggers.
  DateTime _lastTrigger = DateTime(2000);
  static const _triggerCooldown = Duration(seconds: 5);

  /// Whether wake word detection is active.
  bool get isActive => _isActive;

  /// Initialize the speech engine for wake word detection.
  Future<bool> initialize() async {
    try {
      _isAvailable = await _speech.initialize(
        onError: (error) {
          AppLogger.warn(
            LogCategory.lifecycle,
            '[WAKE] STT error: ${error.errorMsg}',
          );
          _isListening = false;
          // Auto-restart after error if still active
          if (_isActive) {
            Future.delayed(const Duration(seconds: 2), () => _startListening());
          }
        },
        onStatus: (status) {
          if (status == 'notListening' || status == 'done') {
            _isListening = false;
            // Auto-restart when STT stops if still active
            if (_isActive) {
              Future.delayed(
                const Duration(seconds: 1),
                () => _startListening(),
              );
            }
          }
        },
      );
      return _isAvailable;
    } catch (e) {
      AppLogger.error(LogCategory.lifecycle, '[WAKE] Init failed: $e');
      return false;
    }
  }

  /// Start wake word detection.
  Future<void> start() async {
    if (_isActive) return;

    if (!_isAvailable) {
      final ok = await initialize();
      if (!ok) {
        AppLogger.warn(
          LogCategory.lifecycle,
          '[WAKE] Cannot start — STT not available',
        );
        return;
      }
    }

    _isActive = true;
    await _startListening();
    AppLogger.info(LogCategory.lifecycle, '[WAKE] Wake word detection STARTED');
  }

  /// Stop wake word detection.
  void stop() {
    _isActive = false;
    _stopListening();
    AppLogger.info(LogCategory.lifecycle, '[WAKE] Wake word detection STOPPED');
  }

  Future<void> _startListening() async {
    if (!_isActive || _isListening) return;

    _isListening = true;

    try {
      await _speech.listen(
        onResult: (result) {
          final text = result.recognizedWords.toLowerCase();

          // Check for wake phrase in recognized text
          for (final phrase in _wakePhrases) {
            if (text.contains(phrase)) {
              final now = DateTime.now();
              if (now.difference(_lastTrigger) > _triggerCooldown) {
                _lastTrigger = now;
                AppLogger.info(
                  LogCategory.lifecycle,
                  '[WAKE] Wake word detected: "$phrase" in "$text"',
                );

                // Stop listening and trigger callback
                _stopListening();
                _isActive = false; // pause wake word while assistant is active
                onWakeWordDetected?.call();
              }
              break;
            }
          }
        },
        listenFor: const Duration(seconds: 30),
        pauseFor: const Duration(seconds: 10),
        listenOptions: stt.SpeechListenOptions(
          partialResults: true,
          cancelOnError: false,
          listenMode: stt.ListenMode.search, // shorter utterances
        ),
        localeId: 'en_IN', // English for better "hey doctor" detection
      );
    } catch (e) {
      _isListening = false;
      AppLogger.error(LogCategory.lifecycle, '[WAKE] Listen failed: $e');
    }
  }

  void _stopListening() {
    try {
      _speech.cancel();
    } catch (_) {}
    _isListening = false;
  }

  /// Resume wake word detection after assistant finishes.
  void resume() {
    if (!_isActive) {
      _isActive = true;
      _startListening();
    }
  }

  /// Clean up.
  void dispose() {
    stop();
  }
}
