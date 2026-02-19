/// Shake-to-trigger SOS — detects vigorous shaking via accelerometer.
/// Requires 3 shakes within 2 seconds to trigger, preventing false positives
/// from walking, driving, or accidental drops.
library;

import 'dart:async';
import 'dart:math';
import 'package:sensors_plus/sensors_plus.dart';
import 'package:vibration/vibration.dart';
import 'emergency_service.dart';
import 'settings_service.dart';

class ShakeDetectorService {
  static final ShakeDetectorService _instance =
      ShakeDetectorService._internal();
  factory ShakeDetectorService() => _instance;
  ShakeDetectorService._internal();

  // ── Tuning ──
  static const double _shakeThreshold = 15.0; // m/s² (gravity ≈ 9.8)
  static const int _requiredShakes = 3;
  static const Duration _shakeWindow = Duration(seconds: 2);
  static const Duration _cooldown = Duration(seconds: 60);

  // ── State ──
  StreamSubscription<AccelerometerEvent>? _subscription;
  final List<DateTime> _shakeTimestamps = [];
  DateTime? _lastTriggerTime;
  bool _isRunning = false;

  bool get isRunning => _isRunning;

  /// Start listening to accelerometer events.
  void start() {
    if (_isRunning) return;

    _subscription = accelerometerEventStream(
      samplingPeriod: SensorInterval.uiInterval,
    ).listen(_onAccelerometerEvent);

    _isRunning = true;
    print('📳 Shake detector started');
  }

  /// Stop listening.
  void stop() {
    _subscription?.cancel();
    _subscription = null;
    _isRunning = false;
    _shakeTimestamps.clear();
    print('📳 Shake detector stopped');
  }

  /// Process each accelerometer reading.
  void _onAccelerometerEvent(AccelerometerEvent event) {
    // Check if feature is enabled
    if (!SettingsService().shakeSosEnabled) return;

    // Calculate total acceleration magnitude (includes gravity ≈ 9.8)
    final double magnitude =
        sqrt(event.x * event.x + event.y * event.y + event.z * event.z);

    // Only count readings above threshold
    if (magnitude < _shakeThreshold) return;

    final now = DateTime.now();

    // Prune old timestamps outside the window
    _shakeTimestamps.removeWhere(
      (t) => now.difference(t) > _shakeWindow,
    );

    _shakeTimestamps.add(now);

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
      print('📳 Shake SOS suppressed — cooldown active');
      return;
    }

    _lastTriggerTime = DateTime.now();
    print('📳 SHAKE DETECTED — triggering SOS!');

    // Haptic feedback: vibrate 500ms to confirm
    try {
      final hasVibrator = await Vibration.hasVibrator() ?? false;
      if (hasVibrator) {
        Vibration.vibrate(duration: 500);
      }
    } catch (_) {
      // Vibration not available — proceed anyway
    }

    // Trigger SOS through the existing service
    final success = await EmergencyService().triggerSOS();
    if (success) {
      print('✅ Shake SOS sent successfully');
    } else {
      print('❌ Shake SOS failed: ${EmergencyService().lastStatus}');
    }
  }
}
