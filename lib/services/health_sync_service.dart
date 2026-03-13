import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:health/health.dart';
import 'package:pedometer/pedometer.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'api_service.dart';
import 'app_logger.dart';

/// Manages health data from Health Connect, sensors, or manual entry.
///
/// Priority chain:
///   1. Android Health Connect (wearables, Samsung Health, Fitbit, etc.)
///   2. Phone sensors (pedometer for steps)
///   3. Manual entry (user types values)
class HealthSyncService {
  // ── Singleton ──
  static final HealthSyncService _instance = HealthSyncService._internal();
  factory HealthSyncService() => _instance;
  HealthSyncService._internal();

  final _api = ApiService();
  final _health = Health();

  bool _healthConnectAvailable = false;
  bool _initialized = false;

  // Latest local vitals (used for UI before backend round-trip)
  final ValueNotifier<Map<String, double?>> vitals = ValueNotifier({
    'steps': null,
    'heart_rate': null,
    'spo2': null,
    'sleep_hours': null,
    'temperature': null,
    'bp': null,
  });

  String _dataSource = 'none'; // 'health_connect' | 'sensor' | 'manual' | 'none'
  String get dataSource => _dataSource;

  // ══════════════════════════════════════════════════════
  //  INITIALIZATION
  // ══════════════════════════════════════════════════════

  /// Call once (e.g. from main.dart or the health screen).
  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;

    try {
      // Check if Health Connect is available
      _healthConnectAvailable = await _health.hasPermissions(
        [HealthDataType.STEPS],
      ) ?? false;
    } catch (e) {
      _healthConnectAvailable = false;
      AppLogger.warn(
        LogCategory.lifecycle,
        'Health Connect check failed: $e',
      );
    }

    // Load cached vitals
    await _loadCachedVitals();

    AppLogger.info(
      LogCategory.lifecycle,
      'HealthSyncService initialized. Health Connect: $_healthConnectAvailable',
    );
  }

  // ══════════════════════════════════════════════════════
  //  HEALTH CONNECT
  // ══════════════════════════════════════════════════════

  /// Request Health Connect permissions and read data.
  Future<bool> syncFromHealthConnect() async {
    try {
      // Configure Health Connect
      _health.configure();

      final types = [
        HealthDataType.STEPS,
        HealthDataType.HEART_RATE,
        HealthDataType.BLOOD_OXYGEN,
        HealthDataType.SLEEP_ASLEEP,
        HealthDataType.BODY_TEMPERATURE,
      ];

      final permissions = types.map((t) => HealthDataAccess.READ).toList();

      // Request permissions
      final granted = await _health.requestAuthorization(types, permissions: permissions);
      if (!granted) {
        AppLogger.warn(LogCategory.lifecycle, 'Health Connect permissions denied');
        return false;
      }

      final now = DateTime.now();
      final midnight = DateTime(now.year, now.month, now.day);
      final yesterday = midnight.subtract(const Duration(hours: 24));

      // Fetch steps for today
      double? steps;
      try {
        final stepsTotal = await _health.getTotalStepsInInterval(midnight, now);
        steps = stepsTotal?.toDouble();
      } catch (_) {}

      // Fetch latest heart rate
      double? heartRate;
      try {
        final hrData = await _health.getHealthDataFromTypes(
          types: [HealthDataType.HEART_RATE],
          startTime: yesterday,
          endTime: now,
        );
        if (hrData.isNotEmpty) {
          hrData.sort((a, b) => b.dateFrom.compareTo(a.dateFrom));
          heartRate = (hrData.first.value as NumericHealthValue).numericValue.toDouble();
        }
      } catch (_) {}

      // Fetch SpO2
      double? spo2;
      try {
        final spo2Data = await _health.getHealthDataFromTypes(
          types: [HealthDataType.BLOOD_OXYGEN],
          startTime: yesterday,
          endTime: now,
        );
        if (spo2Data.isNotEmpty) {
          spo2Data.sort((a, b) => b.dateFrom.compareTo(a.dateFrom));
          spo2 = (spo2Data.first.value as NumericHealthValue).numericValue.toDouble();
        }
      } catch (_) {}

      // Fetch sleep duration
      double? sleepHours;
      try {
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
          sleepHours = totalMinutes / 60.0;
        }
      } catch (_) {}

      // Update local state
      _updateVitals(
        steps: steps,
        heartRate: heartRate,
        spo2: spo2,
        sleepHours: sleepHours,
      );
      _dataSource = 'health_connect';

      AppLogger.info(
        LogCategory.lifecycle,
        'Health Connect sync: steps=$steps, hr=$heartRate, spo2=$spo2, sleep=${sleepHours?.toStringAsFixed(1)}',
      );

      return true;
    } catch (e) {
      AppLogger.error(LogCategory.lifecycle, 'Health Connect sync failed: $e');
      return false;
    }
  }

  // ══════════════════════════════════════════════════════
  //  SENSOR FALLBACK (Pedometer)
  // ══════════════════════════════════════════════════════

  StreamSubscription<StepCount>? _stepSubscription;

  /// Start listening to the phone's step counter sensor.
  void startSensorFallback() {
    _dataSource = 'sensor';

    try {
      _stepSubscription?.cancel();
      _stepSubscription = Pedometer.stepCountStream.listen(
        (StepCount event) {
          _updateVitals(steps: event.steps.toDouble());
        },
        onError: (e) {
          AppLogger.warn(LogCategory.lifecycle, 'Pedometer error: $e');
        },
      );
      AppLogger.info(LogCategory.lifecycle, 'Sensor fallback started (pedometer)');
    } catch (e) {
      AppLogger.error(LogCategory.lifecycle, 'Sensor fallback failed: $e');
      _dataSource = 'manual';
    }
  }

  void stopSensorFallback() {
    _stepSubscription?.cancel();
    _stepSubscription = null;
  }

  // ══════════════════════════════════════════════════════
  //  MANUAL ENTRY
  // ══════════════════════════════════════════════════════

  /// Update vitals from manual user entry.
  void setManualVitals({
    double? steps,
    double? heartRate,
    double? spo2,
    double? sleepHours,
    double? temperature,
    double? bp,
  }) {
    _updateVitals(
      steps: steps,
      heartRate: heartRate,
      spo2: spo2,
      sleepHours: sleepHours,
      temperature: temperature,
      bp: bp,
    );
    _dataSource = 'manual';
  }

  // ══════════════════════════════════════════════════════
  //  FULL SYNC FLOW
  // ══════════════════════════════════════════════════════

  /// Run the full sync chain: Health Connect → Sensor → leave for manual.
  /// Returns the data source that was used.
  Future<String> syncAll() async {
    // Try Health Connect first
    final hcSuccess = await syncFromHealthConnect();
    if (hcSuccess && _hasAnyData()) {
      await _syncToBackend();
      return 'health_connect';
    }

    // Fallback to sensor
    startSensorFallback();
    // Give it a moment to get initial step count
    await Future.delayed(const Duration(seconds: 2));
    if (_hasAnyData()) {
      await _syncToBackend();
      return 'sensor';
    }

    // No auto data — manual mode
    _dataSource = 'manual';
    return 'manual';
  }

  // ══════════════════════════════════════════════════════
  //  BACKEND SYNC
  // ══════════════════════════════════════════════════════

  /// Push current vitals to backend via POST /health/vitals.
  Future<bool> _syncToBackend() async {
    try {
      final v = vitals.value;
      final success = await _api.syncVitalsBatch(
        steps: v['steps'],
        heartRate: v['heart_rate'],
        spo2: v['spo2'],
        sleepHours: v['sleep_hours'],
        temperature: v['temperature'],
        bpSystolic: v['bp'],
      );
      if (success) {
        await _cacheVitals();
        AppLogger.info(LogCategory.network, 'Vitals synced to backend');
      }
      return success;
    } catch (e) {
      AppLogger.error(LogCategory.network, 'Vitals sync to backend failed: $e');
      return false;
    }
  }

  /// Public method to force a sync to backend (after manual entry).
  Future<bool> syncToBackend() => _syncToBackend();

  // ══════════════════════════════════════════════════════
  //  INTERNAL HELPERS
  // ══════════════════════════════════════════════════════

  void _updateVitals({
    double? steps,
    double? heartRate,
    double? spo2,
    double? sleepHours,
    double? temperature,
    double? bp,
  }) {
    final current = Map<String, double?>.from(vitals.value);
    if (steps != null) current['steps'] = steps;
    if (heartRate != null) current['heart_rate'] = heartRate;
    if (spo2 != null) current['spo2'] = spo2;
    if (sleepHours != null) current['sleep_hours'] = sleepHours;
    if (temperature != null) current['temperature'] = temperature;
    if (bp != null) current['bp'] = bp;
    vitals.value = current;
  }

  bool _hasAnyData() {
    return vitals.value.values.any((v) => v != null);
  }

  Future<void> _cacheVitals() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final v = vitals.value;
      for (final entry in v.entries) {
        if (entry.value != null) {
          await prefs.setDouble('vitals_${entry.key}', entry.value!);
        }
      }
      await prefs.setString('vitals_source', _dataSource);
    } catch (_) {}
  }

  Future<void> _loadCachedVitals() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final keys = ['steps', 'heart_rate', 'spo2', 'sleep_hours', 'temperature', 'bp'];
      final cached = <String, double?>{};
      for (final key in keys) {
        cached[key] = prefs.getDouble('vitals_$key');
      }
      vitals.value = cached;
      _dataSource = prefs.getString('vitals_source') ?? 'none';
    } catch (_) {}
  }

  void dispose() {
    stopSensorFallback();
  }
}
