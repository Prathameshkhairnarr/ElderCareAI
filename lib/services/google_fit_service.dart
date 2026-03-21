import 'package:health/health.dart';
import 'package:pedometer/pedometer.dart';
import 'app_logger.dart';

class GoogleFitService {
  // Singleton
  GoogleFitService._privateConstructor();
  static final GoogleFitService _instance = GoogleFitService._privateConstructor();
  factory GoogleFitService() => _instance;

  bool _healthConnectAvailable = false;
  bool _authRequested = false;
  int? _sensorSteps;

  // ── Cached values (single source of truth for all screens) ──
  int cachedSteps = 0;
  double cachedHeartRate = 0.0;
  double cachedSleep = 0.0;
  double? cachedBloodPressure;
  double? cachedSpO2;
  double? cachedTemperature;
  int cachedHealthScore = 0;

  bool get isConnected => _healthConnectAvailable;

  Future<bool> init() async {
    AppLogger.info(LogCategory.lifecycle, '[GOOGLE FIT] Initializing real data connection...');
    if (_authRequested && _healthConnectAvailable) {
       // Already checked permissions this session, safe to proceed
       return true;
    }
    return await _initFallback();
  }

  Future<bool> _initFallback() async {
    AppLogger.info(LogCategory.lifecycle, '[GOOGLE FIT] Connecting to Health Connect / Sensors...');
    try {
      try {
        _authRequested = true;
        _healthConnectAvailable = await Health().requestAuthorization([
          HealthDataType.STEPS,
          HealthDataType.HEART_RATE,
        ]);
        if (_healthConnectAvailable) {
          AppLogger.info(LogCategory.lifecycle, '[GOOGLE FIT] Health Connect active');
          return true;
        }
      } catch (e) {
        AppLogger.warn(LogCategory.lifecycle, '[GOOGLE FIT] Health Connect failed: $e');
      }

      // Fallback 2: Phone Sensors
      Pedometer.stepCountStream.listen((StepCount event) {
        _sensorSteps = event.steps;
      });
      AppLogger.info(LogCategory.lifecycle, '[GOOGLE FIT] Phone Sensors fallback active');
      return true;

    } catch (e) {
      AppLogger.error(LogCategory.lifecycle, '[GOOGLE FIT] All connections failed: $e');
      return false;
    }
  }

  Future<int> getStepsToday() async {
    try {
      if (_healthConnectAvailable) {
        final now = DateTime.now();
        final midnight = DateTime(now.year, now.month, now.day);
        int? steps = await Health().getTotalStepsInInterval(
          midnight,
          now,
        );
        int finalSteps = steps ?? 0;
        AppLogger.info(LogCategory.lifecycle, '[GOOGLE FIT] Real steps fetched: $finalSteps');
        return finalSteps;
      } else if (_sensorSteps != null) {
        AppLogger.info(LogCategory.lifecycle, '[GOOGLE FIT] (Sensor) Steps fetched: $_sensorSteps');
        return _sensorSteps!;
      }
    } catch (e) {
      AppLogger.error(LogCategory.lifecycle, '[GOOGLE FIT] Error: no data ($e)');
    }
    return 0;
  }

  Future<double?> getHeartRate() async {
    try {
      if (_healthConnectAvailable) {
        List<HealthDataPoint> data = await Health().getHealthDataFromTypes(
          startTime: DateTime.now().subtract(const Duration(days: 7)), // Look back a week if watch sync is delayed
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
           AppLogger.info(LogCategory.lifecycle, '[GOOGLE FIT] Real heart rate fetched: $hr');
           return hr;
        }
      }
    } catch (e) {
       AppLogger.error(LogCategory.lifecycle, '[GOOGLE FIT] Error: no data ($e)');
    }
    return null;
  }

  Future<double?> getSpO2() async {
    return _fetchLatestSingleType(HealthDataType.BLOOD_OXYGEN, daysBack: 30);
  }

  Future<double?> getBloodPressure() async {
    return _fetchLatestSingleType(HealthDataType.BLOOD_PRESSURE_SYSTOLIC, daysBack: 30);
  }

  Future<double?> getTemperature() async {
    return _fetchLatestSingleType(HealthDataType.BODY_TEMPERATURE, daysBack: 30);
  }

  Future<double?> getSleep() async {
    final val = await _fetchLatestSingleType(HealthDataType.SLEEP_ASLEEP, daysBack: 7);
    // Sleep from Health Connect is sometimes in minutes, convert to hours if large
    if (val != null && val > 24) {
      return double.parse((val / 60).toStringAsFixed(1));
    }
    return val;
  }

  Future<double?> _fetchLatestSingleType(HealthDataType type, {int daysBack = 7}) async {
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
       AppLogger.warn(LogCategory.lifecycle, '[GOOGLE FIT] Error fetching $type: $e');
    }
    return null;
  }
}

