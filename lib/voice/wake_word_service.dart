import 'dart:async';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import '../services/app_logger.dart';

/// Wake word detection service using speech_to_text for offline keyword spotting.
///
/// Listens for "Hey Veda" or similar phrases to activate
/// the voice assistant without touching the phone.
///
/// Uses a periodic watchdog timer to guarantee STT restarts
/// even if callbacks fail silently.
class WakeWordService {
  WakeWordService._();
  static final WakeWordService instance = WakeWordService._();

  final stt.SpeechToText _speech = stt.SpeechToText();
  bool _isAvailable = false;
  bool _isListening = false;
  bool _isActive = false;

  /// Callback when wake word is detected. Passes the full text recognized.
  void Function(String recognizedText)? onWakeWordDetected;

  /// Wake phrases to listen for (case-insensitive).
  static const _wakePhrases = [
    'hey veda',
    'veda sahab',
    'hello veda',
    'ok veda',
    'hi veda',
    'veda ji',
    'hey wada',   // common STT mishearing
    'hey vada',   // common STT mishearing
    'a veda',     // partial match
  ];

  /// Cooldown to prevent rapid re-triggers.
  DateTime _lastTrigger = DateTime(2000);
  static const _triggerCooldown = Duration(seconds: 5);

  /// Watchdog timer — restarts STT if it dies silently.
  Timer? _watchdogTimer;
  static const _watchdogInterval = Duration(seconds: 35);

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
    _startWatchdog();
    AppLogger.info(LogCategory.lifecycle, '[WAKE] Wake word detection STARTED');
  }

  /// Stop wake word detection completely.
  void stop() {
    _isActive = false;
    _stopListening();
    _stopWatchdog();
    AppLogger.info(LogCategory.lifecycle, '[WAKE] Wake word detection STOPPED');
  }

  /// Start the watchdog timer that ensures STT keeps restarting.
  void _startWatchdog() {
    _stopWatchdog();
    _watchdogTimer = Timer.periodic(_watchdogInterval, (_) {
      if (_isActive && !_isListening) {
        AppLogger.info(
          LogCategory.lifecycle,
          '[WAKE] Watchdog: STT died silently — restarting',
        );
        _startListening();
      }
    });
  }

  void _stopWatchdog() {
    _watchdogTimer?.cancel();
    _watchdogTimer = null;
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
                _stopWatchdog();
                onWakeWordDetected?.call(text);
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
          listenMode: stt.ListenMode.dictation, // Allows longer sentences
        ),
        localeId: 'en_IN', // English for better "hey veda" detection
      );
    } catch (e) {
      _isListening = false;
      AppLogger.error(LogCategory.lifecycle, '[WAKE] Listen failed: $e');
      // Retry after delay
      if (_isActive) {
        Future.delayed(const Duration(seconds: 3), () => _startListening());
      }
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
      _startWatchdog();
      AppLogger.info(LogCategory.lifecycle, '[WAKE] Wake word detection RESUMED');
    }
  }

  /// Clean up.
  void dispose() {
    stop();
  }
}
