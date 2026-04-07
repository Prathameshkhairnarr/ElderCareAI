import 'package:flutter/foundation.dart';
import 'package:health/health.dart';

import 'package:shared_preferences/shared_preferences.dart';
import 'app_logger.dart';

class GoogleFitService extends ChangeNotifier {
  // Singleton
  GoogleFitService._privateConstructor();
  static final GoogleFitService _instance =
      GoogleFitService._privateConstructor();
  factory GoogleFitService() => _instance;

  bool _healthConnectAvailable = false;
  bool _authRequested = false;
  int cachedSteps = 0;
  double cachedHeartRate = 0.0;
  double cachedSleep = 0.0;
  double? cachedBloodPressure;
  double? cachedSpO2;
  double? cachedTemperature;
  int cachedHealthScore = 0;

  /// Call this after updating cached values to notify all listening screens
  void notifyCacheUpdated() {
    notifyListeners();
  }

  bool get isConnected => _healthConnectAvailable;

  bool _isAuthenticating = false;

  /// Silently initializes.
  /// Ideal for background or app-start initialization.
  Future<bool> init() async {
    final prefs = await SharedPreferences.getInstance();
    final isExplicitlyConnected = prefs.getBool('health_is_connected') ?? false;

    if (!isExplicitlyConnected) {
      // Return quietly without touching any sensors or showing logs
      return false;
    }

    AppLogger.info(
      LogCategory.lifecycle,
      '[GOOGLE FIT] Silently verifying existing connection...',
    );

    if (_authRequested && _healthConnectAvailable) {
      return true;
    }
    return await _initFallback(requestAuth: false);
  }

  /// Explicitly requests authorization. Will show the permission popup.
  /// Ideal for "Connect" buttons in the UI.
  Future<bool> requestPermissions() async {
    if (_isAuthenticating) {
      AppLogger.warn(
        LogCategory.lifecycle,
        '[GOOGLE FIT] Already authenticating. Ignoring extra click.',
      );
      return false;
    }
    AppLogger.info(
      LogCategory.lifecycle,
      '[GOOGLE FIT] Explicitly requesting permissions...',
    );
    final success = await _initFallback(requestAuth: true);
    if (success) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('health_is_connected', true);
    }
    return success;
  }

  Future<bool> _initFallback({required bool requestAuth}) async {
    if (_isAuthenticating) return false;
    _isAuthenticating = true;

    AppLogger.info(
      LogCategory.lifecycle,
      '[GOOGLE FIT] Connecting to Health Connect / Sensors...',
    );
    try {
      try {
        final types = [
          HealthDataType.STEPS,
          HealthDataType.HEART_RATE,
          HealthDataType.SLEEP_ASLEEP,
          HealthDataType.BLOOD_OXYGEN,
          HealthDataType.BLOOD_PRESSURE_SYSTOLIC,
          HealthDataType.BODY_TEMPERATURE,
        ];

        bool? hasPermissions;
        try {
          hasPermissions = await Health().hasPermissions(types);
        } catch (_) {}

        if (hasPermissions == true || requestAuth) {
          _authRequested = true;
          _healthConnectAvailable = await Health().requestAuthorization(types);
          if (_healthConnectAvailable) {
            AppLogger.info(
              LogCategory.lifecycle,
              '[GOOGLE FIT] Health Connect active',
            );
            return true;
          }
        } else {
          AppLogger.info(
            LogCategory.lifecycle,
            '[GOOGLE FIT] Health Connect permissions not granted yet. Skipping silent request.',
          );
        }
      } catch (e) {
        AppLogger.warn(
          LogCategory.lifecycle,
          '[GOOGLE FIT] Health Connect failed: $e',
        );
      }

      // Health Connect not available or permissions denied
      AppLogger.info(
        LogCategory.lifecycle,
        '[GOOGLE FIT] Health Connect not available',
      );

      return false;
    } catch (e) {
      AppLogger.error(
        LogCategory.lifecycle,
        '[GOOGLE FIT] All connections failed: $e',
      );
      return false;
    } finally {
      _isAuthenticating = false;
    }
  }



  Future<int> getStepsToday() async {
    try {
      if (_healthConnectAvailable) {
        final now = DateTime.now();
        final midnight = DateTime(now.year, now.month, now.day);
        
        // DEBUG: Querying the last 3 days to see if ANY step data exists in Health Connect
        List<HealthDataPoint> stepData = await Health().getHealthDataFromTypes(
          startTime: now.subtract(const Duration(days: 3)),
          endTime: now,
          types: [HealthDataType.STEPS],
        );

        if (stepData.isNotEmpty) {
          int maxSteps = 0;
          Map<String, int> stepsBySource = {};
          
          for (var point in stepData) {
            // ONLY SUM IF THE DATE IS TODAY to simulate getStepsToday properly
            if (point.dateTo.isAfter(midnight)) {
              final source = point.sourceName;
              final val = point.value is NumericHealthValue
                  ? (point.value as NumericHealthValue).numericValue.toInt()
                  : int.tryParse(point.value.toString()) ?? 0;
              stepsBySource[source] = (stepsBySource[source] ?? 0) + val;
            }
          }

          AppLogger.info(LogCategory.lifecycle, '[GOOGLE FIT] Raw Step Sources today: $stepsBySource');
          AppLogger.info(LogCategory.lifecycle, '[GOOGLE FIT] Total data points over 3 days: ${stepData.length}');

          // Find the maximum count among all sources (Samsung Health is usually one of them)
          stepsBySource.forEach((source, count) {
            if (count > maxSteps) maxSteps = count;
          });

          if (maxSteps > 0) {
            final prefs = await SharedPreferences.getInstance();
            await prefs.setInt('cached_steps_today', maxSteps);
            await prefs.setString(
              'cached_steps_date',
              now.toIso8601String().split('T')[0],
            );
            AppLogger.info(LogCategory.lifecycle, '[GOOGLE FIT] Calculated Steps: $maxSteps');
            return maxSteps;
          }
        }

        AppLogger.info(
          LogCategory.lifecycle,
          '[GOOGLE FIT] Health Connect returned 0 steps. Using device sensor fallback.',
        );
      }
      


    } catch (e) {
      AppLogger.error(
        LogCategory.lifecycle,
        '[GOOGLE FIT] Steps fetch error: $e',
      );
    }
    return 0;
  }

  /// Get cached steps for instant display on app launch
  Future<int> getCachedSteps() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final today = DateTime.now().toIso8601String().split('T')[0];
      final cachedDate = prefs.getString('cached_steps_date');
      if (cachedDate == today) {
        return prefs.getInt('cached_steps_today') ?? 0;
      }
    } catch (_) {}
    return 0;
  }

  Future<double?> getHeartRate() async {
    try {
      if (_healthConnectAvailable) {
        List<HealthDataPoint> data = await Health().getHealthDataFromTypes(
          startTime: DateTime.now().subtract(
            const Duration(days: 7),
          ), // Look back a week if watch sync is delayed
          endTime: DateTime.now(),
          types: [HealthDataType.HEART_RATE],
        );
        if (data.isNotEmpty) {
          // Sort by date to get the most recent
          data.sort((a, b) => a.dateFrom.compareTo(b.dateFrom));
          var last = data.last.value;
          double? hr;
          if (last is NumericHealthValue) {
            hr = last.numericValue.toDouble();
          } else {
            hr = double.tryParse(last.toString());
          }
          AppLogger.info(
            LogCategory.lifecycle,
            '[GOOGLE FIT] Real heart rate fetched: $hr',
          );
          return hr;
        }
      }
    } catch (e) {
      AppLogger.error(
        LogCategory.lifecycle,
        '[GOOGLE FIT] Error: no data ($e)',
      );
    }
    return null;
  }

  Future<double?> getSpO2() async {
    return _fetchLatestSingleType(HealthDataType.BLOOD_OXYGEN, daysBack: 30);
  }

  Future<double?> getBloodPressure() async {
    return _fetchLatestSingleType(
      HealthDataType.BLOOD_PRESSURE_SYSTOLIC,
      daysBack: 30,
    );
  }

  Future<double?> getTemperature() async {
    return _fetchLatestSingleType(
      HealthDataType.BODY_TEMPERATURE,
      daysBack: 30,
    );
  }

  Future<double?> getSleep() async {
    final val = await _fetchLatestSingleType(
      HealthDataType.SLEEP_ASLEEP,
      daysBack: 7,
    );
    // Sleep from Health Connect is sometimes in minutes, convert to hours if large
    if (val != null && val > 24) {
      return double.parse((val / 60).toStringAsFixed(1));
    }
    return val;
  }

  Future<double?> _fetchLatestSingleType(
    HealthDataType type, {
    int daysBack = 7,
  }) async {
    try {
      if (_healthConnectAvailable) {
        List<HealthDataPoint> data = await Health().getHealthDataFromTypes(
          startTime: DateTime.now().subtract(Duration(days: daysBack)),
          endTime: DateTime.now(),
          types: [type],
        );
        if (data.isNotEmpty) {
          data.sort((a, b) => a.dateFrom.compareTo(b.dateFrom));
          var last = data.last.value;
          if (last is NumericHealthValue) return last.numericValue.toDouble();
          return double.tryParse(last.toString());
        }
      }
    } catch (e) {
      AppLogger.warn(
        LogCategory.lifecycle,
        '[GOOGLE FIT] Error fetching $type: $e',
      );
    }
    return null;
  }
}
