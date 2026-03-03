/// Shake-to-trigger SOS — detects vigorous shaking via accelerometer.
///
/// HARDENED for production:
/// - Requires 4 shakes within 2 seconds (was 3)
/// - Higher threshold (18 m/s²) to filter vehicle bumps
/// - Direction reversal check — vehicle bumps are uni-directional
/// - Ignores sensor noise (>50 m/s²)
/// - Uses normalInterval (~10Hz) instead of uiInterval (~60Hz) — battery efficient
/// - 60-second cooldown after trigger
library;

import 'dart:async';
import 'dart:math';
import 'package:sensors_plus/sensors_plus.dart';
import 'package:vibration/vibration.dart';
import 'emergency_service.dart';
import 'settings_service.dart';
import 'app_logger.dart';

class ShakeDetectorService {
  static final ShakeDetectorService _instance =
      ShakeDetectorService._internal();
  factory ShakeDetectorService() => _instance;
  ShakeDetectorService._internal();

  // ── Tuning (hardened) ──
  static const double _shakeThreshold =
      18.0; // m/s² (was 15.0 — stricter for vehicle filter)
  static const double _maxAcceleration =
      50.0; // Above this = sensor noise / drop
  static const int _requiredShakes =
      4; // (was 3 — extra shake reduces false positives)
  static const Duration _shakeWindow = Duration(seconds: 2);
  static const Duration _cooldown = Duration(seconds: 60);

  // ── State ──
  StreamSubscription<AccelerometerEvent>? _subscription;
  final List<_ShakeEvent> _shakeTimestamps = [];
  DateTime? _lastTriggerTime;
  bool _isRunning = false;
  double _lastMagnitude = 0.0; // Track direction reversal

  bool get isRunning => _isRunning;

  /// Start listening to accelerometer events.
  void start() {
    if (_isRunning) return;

    _subscription = accelerometerEventStream(
      samplingPeriod:
          SensorInterval.normalInterval, // ~10Hz, not ~60Hz — battery safe
    ).listen(_onAccelerometerEvent);

    _isRunning = true;
    AppLogger.info(LogCategory.shake, 'Shake detector started');
  }

  /// Stop listening.
  void stop() {
    _subscription?.cancel();
    _subscription = null;
    _isRunning = false;
    _shakeTimestamps.clear();
    AppLogger.info(LogCategory.shake, 'Shake detector stopped');
  }

  /// Process each accelerometer reading.
  void _onAccelerometerEvent(AccelerometerEvent event) {
    // Check if feature is enabled
    if (!SettingsService().shakeSosEnabled) return;

    // Calculate total acceleration magnitude (includes gravity ≈ 9.8)
    final double magnitude = sqrt(
      event.x * event.x + event.y * event.y + event.z * event.z,
    );

    // Filter out sensor noise / drops (unrealistically high readings)
    if (magnitude > _maxAcceleration) return;

    // Only count readings above threshold
    if (magnitude < _shakeThreshold) {
      _lastMagnitude = magnitude;
      return;
    }

    final now = DateTime.now();

    // Direction reversal check: require the acceleration to have dropped
    // significantly between shakes. Vehicle bumps maintain constant high
    // acceleration, while shaking has peaks and valleys.
    final bool hasDirectionReversal =
        (_lastMagnitude <
        _shakeThreshold * 0.7); // Must drop below 70% of threshold

    _lastMagnitude = magnitude;

    if (!hasDirectionReversal && _shakeTimestamps.isNotEmpty) {
      // Continuous high acceleration (like rough road) — don't count
      return;
    }

    // Prune old timestamps outside the window
    _shakeTimestamps.removeWhere((s) => now.difference(s.time) > _shakeWindow);

    _shakeTimestamps.add(_ShakeEvent(time: now, magnitude: magnitude));

    // Check if enough shakes accumulated
    if (_shakeTimestamps.length >= _requiredShakes) {
      _shakeTimestamps.clear();
      _onShakeDetected();
    }
  }

  /// Called when a valid shake pattern is confirmed.
  Future<void> _onShakeDetected() async {
    // Cooldown check
    if (_lastTriggerTime != null &&
        DateTime.now().difference(_lastTriggerTime!) < _cooldown) {
      AppLogger.info(
        LogCategory.shake,
        'Shake SOS suppressed — cooldown active',
      );
      return;
    }

    _lastTriggerTime = DateTime.now();
    AppLogger.info(LogCategory.shake, 'SHAKE DETECTED — triggering SOS!');

    // Haptic feedback: vibrate 500ms to confirm
    try {
      final hasVibrator = await Vibration.hasVibrator();
      if (hasVibrator) {
        Vibration.vibrate(duration: 500);
      }
    } catch (_) {
      // Vibration not available — proceed anyway
    }

    // Trigger SOS through the existing service
    try {
      final success = await EmergencyService().triggerSOS();
      if (success) {
        AppLogger.info(LogCategory.shake, 'Shake SOS sent successfully');
      } else {
        AppLogger.warn(
          LogCategory.shake,
          'Shake SOS failed: ${EmergencyService().lastStatus}',
        );
      }
    } catch (e) {
      AppLogger.error(LogCategory.shake, 'Shake SOS trigger error: $e');
    }
  }
}

/// Internal shake event with timestamp and magnitude
class _ShakeEvent {
  final DateTime time;
  final double magnitude;
  const _ShakeEvent({required this.time, required this.magnitude});
}
