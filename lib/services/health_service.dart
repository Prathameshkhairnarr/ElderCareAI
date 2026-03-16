import 'dart:async';
import 'dart:io';
import 'package:health/health.dart';
import 'package:pedometer/pedometer.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app_logger.dart';

class HealthService {
  static final HealthService _instance = HealthService._internal();
  factory HealthService() => _instance;
  HealthService._internal();

  final _health = Health();
  bool _healthConnectAvailable = false;
  bool _healthPermissionsRequested = false;
  int? _baselineSteps;

  Future<void> initialize() async {
    // Check Health Connect
    try {
      _health.configure();
      if (Platform.isAndroid) {
        _healthConnectAvailable = await Health().isHealthConnectAvailable().timeout(const Duration(seconds: 2), onTimeout: () => false);
      }
    } catch (e) {
      _healthConnectAvailable = false;
      AppLogger.warn(LogCategory.lifecycle, 'Health Connect check failed: $e');
    }

    // We no longer eagerly request permissions here on startup to avoid
    // colliding with the SMS/Telephony foreground service initialization.
    // Permissions are requested lazily right before the streams/functions need them.
  }

  Future<bool> _ensureHealthPermissions() async {
    if (!_healthConnectAvailable) return false;
    if (_healthPermissionsRequested) return true;

    final types = [
      HealthDataType.STEPS,
      HealthDataType.SLEEP_ASLEEP,
      HealthDataType.BLOOD_OXYGEN,
      HealthDataType.BLOOD_PRESSURE_SYSTOLIC,
      HealthDataType.BODY_TEMPERATURE,
    ];

    try {
      bool? hasPermissions = await _health.hasPermissions(types);
      if (hasPermissions == true) {
        _healthPermissionsRequested = true;
        return true;
      }

      bool granted = await _health.requestAuthorization(types);
      _healthPermissionsRequested = true;
      return granted;
    } catch (e) {
      AppLogger.warn(LogCategory.lifecycle, 'Health authorization error: $e');
      return false;
    }
  }

  // ── LEVEL 1: PHONE SENSORS (Always available fallback) ──

  /// Stream of total steps taken today
  Stream<int> stepStream() async* {
    if (Platform.isAndroid) {
      bool granted = await Permission.activityRecognition.isGranted;
      if (!granted) {
        granted = await Permission.activityRecognition.request().isGranted;
        if (!granted) {
          AppLogger.warn(LogCategory.lifecycle, 'Activity recognition permission denied. Stream will send 0.');
          yield* Stream.periodic(const Duration(seconds: 10), (_) => 0);
          return;
        }
      }
    }

    final prefs = await SharedPreferences.getInstance();
    final String today = DateTime.now().toIso8601String().split('T')[0];
    final savedDate = prefs.getString('pedometer_baseline_date');

    if (savedDate == today) {
      _baselineSteps = prefs.getInt('pedometer_baseline_steps');
    } else {
      _baselineSteps = null;
    }

    try {
      yield* Pedometer.stepCountStream.map((StepCount event) {
        if (_baselineSteps == null || event.steps < _baselineSteps!) {
          _baselineSteps = event.steps;
          prefs.setInt('pedometer_baseline_steps', event.steps);
          prefs.setString('pedometer_baseline_date', today);
        }
        return (event.steps - _baselineSteps!).clamp(0, event.steps);
      }).handleError((error) {
        AppLogger.error(LogCategory.lifecycle, 'Pedometer error: $error');
      });
    } catch (e) {
       AppLogger.error(LogCategory.lifecycle, 'Pedometer initialization error: $e');
       yield* Stream.periodic(const Duration(seconds: 10), (_) => 0);
    }
  }

  Future<int> getStepsToday() async {
    // If HC exists, try that first
    if (await _ensureHealthPermissions()) {
      try {
        final now = DateTime.now();
        final midnight = DateTime(now.year, now.month, now.day);
        final hcSteps = await _health.getTotalStepsInInterval(midnight, now);
        if (hcSteps != null && hcSteps > 0) return hcSteps.toInt();
      } catch (_) {}
    }
    // Cannot easily await the stream synchronously without listening, rely on UI stream mostly
    // But as a fallback we return 0 here. UI should use stepStream()
    return 0; // Handled by stream live
  }

  // ── LEVEL 2: SLEEP ESTIMATION (Motion + Health Connect) ──

  Future<double?> estimateSleep() async {
    // 1. Try Health Connect
    if (await _ensureHealthPermissions()) {
      try {
        final now = DateTime.now();
        final yesterday = DateTime(now.year, now.month, now.day).subtract(const Duration(hours: 24));
        final sleepData = await _health.getHealthDataFromTypes(
          types: [HealthDataType.SLEEP_ASLEEP],
          startTime: yesterday,
          endTime: now,
        );
        if (sleepData.isNotEmpty) {
          int totalMinutes = 0;
          for (final point in sleepData) {
            totalMinutes += point.dateTo.difference(point.dateFrom).inMinutes;
          }
          if (totalMinutes > 0) return totalMinutes / 60.0;
        }
      } catch (e) {
        AppLogger.warn(LogCategory.lifecycle, 'HC sleep fetch error: $e');
      }
    }

    // 2. Motion-based heuristic fallback (Simple mock implementation for demo)
    // In a real app we would run a background isolate to measure accelerometer over 8 hours.
    // For this demonstration, we estimate a typical 7.0 - 8.0 hr if not tracked
    // since we can't instantly retrieve past 8 hours of accelerometer data synchronously.
    final hour = DateTime.now().hour;
    if (hour >= 6 && hour <= 12) {
      // It's morning, user woke up. Return a reasonable estimate
      return 7.5;
    }
    return null; // Don't know yet
  }

  // ── LEVEL 3: OTHER VITALS (Health Connect Fallback) ──

  Future<double?> getSpO2() async {
    return _fetchFromHealthConnect(HealthDataType.BLOOD_OXYGEN);
  }

  Future<double?> getBloodPressure() async {
    // For simplicity returning Systolic
    return _fetchFromHealthConnect(HealthDataType.BLOOD_PRESSURE_SYSTOLIC);
  }

  Future<double?> getTemperature() async {
    return _fetchFromHealthConnect(HealthDataType.BODY_TEMPERATURE);
  }

  Future<double?> _fetchFromHealthConnect(HealthDataType type) async {
    if (!(await _ensureHealthPermissions())) return null;
    try {
      final now = DateTime.now();
      final yesterday = now.subtract(const Duration(days: 2)); // Look back 48 hrs

      final data = await _health.getHealthDataFromTypes(
        types: [type],
        startTime: yesterday,
        endTime: now,
      );

      if (data.isNotEmpty) {
        data.sort((a, b) => b.dateFrom.compareTo(a.dateFrom)); // Latest first
        if (data.first.value is NumericHealthValue) {
            return (data.first.value as NumericHealthValue).numericValue.toDouble();
        }
      }
    } catch (e) {
      AppLogger.warn(LogCategory.lifecycle, 'HC fetch error for $type: $e');
    }
    return null;
  }

  // Calculate Health Score dynamically
  int calculateHealthScore(int steps, double sleepHours, double heartRate) {
    if (steps == 0 && sleepHours == 0.0 && heartRate == 0.0) return 0; // Empty
    
    // activityScore: goal is 8000
    double activityScore = (steps / 8000.0).clamp(0.0, 1.0) * 100;
    
    // sleepScore: optimal is 7-9 hours
    double sleepScore = 0.0;
    if (sleepHours >= 7 && sleepHours <= 9) sleepScore = 100.0;
    else if (sleepHours > 0) sleepScore = (sleepHours / 7.0).clamp(0.0, 1.0) * 80;

    // heartScore: 60-100 is normal resting
    double heartScore = 0.0;
    if (heartRate >= 60 && heartRate <= 100) heartScore = 100.0;
    else if (heartRate > 0) heartScore = 70.0; // outside normal range

    final score = (activityScore * 0.4) + (sleepScore * 0.3) + (heartScore * 0.3);
    return score.round();
  }
}
