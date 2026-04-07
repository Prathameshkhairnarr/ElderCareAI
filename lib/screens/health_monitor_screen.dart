import 'dart:async';
import 'package:flutter/material.dart';

import '../services/api_service.dart';
import '../services/health_service.dart';
import '../services/google_fit_service.dart';
import '../services/app_logger.dart';

class HealthMonitorScreen extends StatefulWidget {
  const HealthMonitorScreen({super.key});

  @override
  State<HealthMonitorScreen> createState() => _HealthMonitorScreenState();
}

class _HealthMonitorScreenState extends State<HealthMonitorScreen> with WidgetsBindingObserver {
  final _api = ApiService();
  final _healthService = HealthService();
  final _googleFitService = GoogleFitService();
  
  bool _isLoading = true;
  bool _isGoogleFitConnecting = false;
  bool _isGoogleFitConnected = false;

  Timer? _refreshTimer;
  StreamSubscription<int>? _stepSubscription;

  // Local state for dashboard
  int _currentSteps = 0;
  double _currentHR = 0.0;
  double _currentSleep = 0.0;
  double _currentSpO2 = 0.0;
  double _currentBP = 0.0;
  double _currentTemp = 0.0;

  
  int _healthScore = 0;

  final Map<String, _VitalData> _vitalsCache = {
    'heart_rate': _VitalData(label: 'Heart Rate', unit: 'bpm', icon: Icons.favorite_rounded, color: const Color(0xFFEF5350), min: 60, max: 100),
    'steps': _VitalData(label: 'Steps Today', unit: 'steps', icon: Icons.directions_walk_rounded, color: const Color(0xFF7C4DFF), min: 0, max: 8000),
    'spo2': _VitalData(label: 'SpO2', unit: '%', icon: Icons.air_rounded, color: const Color(0xFF26A69A), min: 95, max: 100),
    'bp': _VitalData(label: 'Blood Pressure', unit: 'mmHg', icon: Icons.speed_rounded, color: const Color(0xFF42A5F5), min: 90, max: 140),
    'sleep': _VitalData(label: 'Sleep', unit: 'hrs', icon: Icons.bedtime_rounded, color: const Color(0xFF5C6BC0), min: 6, max: 9),
    'temperature': _VitalData(label: 'Temperature', unit: '°C', icon: Icons.thermostat_rounded, color: const Color(0xFFFFA726), min: 36.5, max: 37.5),
  };

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initHealthSystem();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      if (!_isLoading) {
         // Auto-sync when user comes back to the app
         _connectGoogleFit();
      }
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _refreshTimer?.cancel();
    _stepSubscription?.cancel();
    super.dispose();
  }

  Future<void> _initHealthSystem() async {
    print('DEBUG_HEALTH: _initHealthSystem started');
    if (!mounted) return;
    setState(() => _isLoading = true);

    // 0. INSTANT: Show cached steps from last session immediately
    int cached = await _googleFitService.getCachedSteps();
    if (cached > 0 && mounted) {
      setState(() {
        _currentSteps = cached;
        _recalculateScore();
        _googleFitService.cachedSteps = _currentSteps;
        _googleFitService.cachedHealthScore = _healthScore;
        _googleFitService.notifyCacheUpdated();
      });
    }

    print('DEBUG_HEALTH: Calling _healthService.initialize()');
    await _healthService.initialize();
    print('DEBUG_HEALTH: _healthService.initialize() done');

    // 1. Subscribe to Live Steps (Phone Sensors) - Fallback
    // Using phone sensor pedometer because Health Connect isn't syncing properly on this device
    print('DEBUG_HEALTH: Subscribing to stepStream()');
    _stepSubscription = _healthService.stepStream().listen((steps) {
      if (!mounted) return;
      setState(() {
          _currentSteps = steps;
          _recalculateScore();
          _googleFitService.cachedSteps = _currentSteps;
          _googleFitService.cachedHealthScore = _healthScore;
          _googleFitService.notifyCacheUpdated();
      });
    }, onError: (error) {
      print('DEBUG_HEALTH: stepStream error: $error');
    });

    // 2. Automatically sync Health Connect in the background for Heart Rate etc.
    await _connectGoogleFit();

    // 2. Start auto-refresh scheduler (1 minute for fresh vitals)
    _refreshTimer = Timer.periodic(const Duration(minutes: 1), (_) {
      _connectGoogleFit();
    });

    print('DEBUG_HEALTH: Setting _isLoading to false');
    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _fetchStaticVitals() async {
    try {
      final sleep = await _healthService.estimateSleep();
      final spo2 = await _healthService.getSpO2();
      final bp = await _healthService.getBloodPressure();
      final temp = await _healthService.getTemperature();
      final hcSteps = await _healthService.getStepsToday(); // Fallback if stream is dead

      if (mounted) {
        setState(() {
          if (sleep != null) _currentSleep = sleep;
          if (spo2 != null) _currentSpO2 = spo2;
          if (bp != null) _currentBP = bp;
          if (temp != null) _currentTemp = temp;
          
          // If pedometer stream hasn't emitted anything greater than 0, use HealthConnect
          if (hcSteps > 0 && _currentSteps == 0) {
            _currentSteps = hcSteps;
          }
          
          _recalculateScore();
        });
        
        // Push optionally to backend for sync
        try {
           await _api.syncVitalsBatch(
             steps: _currentSteps.toDouble(),
             heartRate: _currentHR > 0 ? _currentHR : null,
             sleepHours: _currentSleep > 0 ? _currentSleep : null,
             spo2: _currentSpO2 > 0 ? _currentSpO2 : null,
             bpSystolic: _currentBP > 0 ? _currentBP : null,
             temperature: _currentTemp > 0 ? _currentTemp : null,
           );
        } catch (_) {}
      }
    } catch (e) {
      AppLogger.warn(LogCategory.lifecycle, 'Static vitals fetch failed: $e');
    }
  }

  void _recalculateScore() {
    _healthScore = _healthService.calculateHealthScore(_currentSteps, _currentSleep, _currentHR);
  }

  Future<void> _connectGoogleFit({bool forceRequest = false}) async {
    if (!mounted) return;
    setState(() => _isGoogleFitConnecting = true);

    // Use silent init() for auto-refresh to avoid crash with telephony plugin.
    // Only use requestPermissions() when user clicks "Connect" button explicitly.
    bool success;
    if (forceRequest) {
      // Small delay to let other plugins finish their permission handling
      await Future.delayed(const Duration(milliseconds: 500));
      success = await _googleFitService.requestPermissions();
    } else {
      success = await _googleFitService.init();
    }

    if (success && _googleFitService.isConnected) {
      int steps = await _googleFitService.getStepsToday();
      double? hr = await _googleFitService.getHeartRate();
      double? spo2 = await _googleFitService.getSpO2();
      double? bp = await _googleFitService.getBloodPressure();
      double? temp = await _googleFitService.getTemperature();
      double? sleep = await _googleFitService.getSleep();

      if (mounted) {
        setState(() {
          _isGoogleFitConnected = true;
          // Direct assignment from Health Connect (Samsung Health priority)
          if (steps > 0) {
            _currentSteps = steps;
          }
          if (hr != null && hr > 0) _currentHR = hr;
          if (spo2 != null && spo2 > 0) _currentSpO2 = spo2;
          if (bp != null && bp > 0) _currentBP = bp;
          if (temp != null && temp > 0) _currentTemp = temp;
          if (sleep != null && sleep > 0) _currentSleep = sleep;
          _recalculateScore();

          // ── Cache in singleton so ALL screens read the same data ──
          _googleFitService.cachedSteps = _currentSteps;
          _googleFitService.cachedHeartRate = _currentHR;
          _googleFitService.cachedSleep = _currentSleep;
          _googleFitService.cachedBloodPressure = _currentBP > 0 ? _currentBP : null;
          _googleFitService.cachedSpO2 = _currentSpO2 > 0 ? _currentSpO2 : null;
          _googleFitService.cachedTemperature = _currentTemp > 0 ? _currentTemp : null;
          _googleFitService.cachedHealthScore = _healthScore;
          _googleFitService.notifyCacheUpdated();
        });
        
        // Push optionally to backend for sync
        try {
           await _api.syncVitalsBatch(
             steps: _currentSteps.toDouble(),
             heartRate: _currentHR > 0 ? _currentHR : null,
             sleepHours: _currentSleep > 0 ? _currentSleep : null,
             spo2: _currentSpO2 > 0 ? _currentSpO2 : null,
             bpSystolic: _currentBP > 0 ? _currentBP : null,
             temperature: _currentTemp > 0 ? _currentTemp : null,
           );
        } catch (_) {}
      }
    }

    if (mounted) setState(() => _isGoogleFitConnecting = false);
  }


  @override
  Widget build(BuildContext context) {
    // Sync local state map to UI definitions
    _vitalsCache['steps']!.value = _currentSteps.toDouble();
    _vitalsCache['heart_rate']!.value = _currentHR;

    _vitalsCache['sleep']!.value = _currentSleep;
    _vitalsCache['spo2']!.value = _currentSpO2;
    _vitalsCache['bp']!.value = _currentBP;
    _vitalsCache['temperature']!.value = _currentTemp;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Live Health Tracking'),
        centerTitle: true,
        elevation: 0,

      ),

      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 80),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildHealthScoreCard(),
                  const SizedBox(height: 16),
                                    // Live sensor banner — shown ONLY when Google Fit is connected
                  if (_isGoogleFitConnected && !_isLoading)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      decoration: BoxDecoration(
                        color: const Color(0xFF7C4DFF).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.sensors_rounded, color: Color(0xFF7C4DFF), size: 18),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Live sensor tracking active',
                              style: TextStyle(
                                  color: Color(0xFF7C4DFF), fontSize: 13, fontWeight: FontWeight.w600),
                            ),
                          ),
                        ],
                      ),
                    ),

                  // Warning banner — shown ONLY when NOT connected
                  if (!_isGoogleFitConnected && !_isLoading)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      decoration: BoxDecoration(
                        color: Colors.red.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.red.withValues(alpha: 0.2)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.sensors_off_rounded, color: Colors.redAccent, size: 20),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Live sensor tracking is offline', style: TextStyle(fontSize: 13, color: Colors.redAccent, fontWeight: FontWeight.bold)),
                                Text('Please connect Google Fit to sync vitals', style: TextStyle(fontSize: 11, color: Colors.redAccent.withValues(alpha: 0.8))),
                              ],
                            ),
                          ),
                          TextButton(
                            onPressed: () async {
                              setState(() => _isGoogleFitConnecting = true);
                              await _connectGoogleFit(forceRequest: true);
                            },
                            style: TextButton.styleFrom(
                              foregroundColor: Colors.redAccent,
                              visualDensity: VisualDensity.compact,
                              padding: const EdgeInsets.symmetric(horizontal: 8),
                            ),
                            child: const Text('Connect', style: TextStyle(fontWeight: FontWeight.bold)),
                          )
                        ],
                      ),
                    ),
                  const SizedBox(height: 24),

                  Text('Live Vitals', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Theme.of(context).colorScheme.onSurface)),

                  const SizedBox(height: 12),
                  
                  GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2, mainAxisSpacing: 12, crossAxisSpacing: 12, childAspectRatio: 1.3,
                    ),
                    itemCount: _vitalsCache.length,
                    itemBuilder: (context, index) {
                      final item = _vitalsCache.entries.elementAt(index).value;
                      return _buildVitalCard(item, index);
                    },
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
    );
  }

  Widget _buildHealthScoreCard() {
    String status = _healthScore > 80 ? 'Excellent' : _healthScore > 60 ? 'Good' : _healthScore > 40 ? 'Fair' : 'Low Data';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [Color(0xFFEC407A), Color(0xFFAD1457)], begin: Alignment.topLeft, end: Alignment.bottomRight),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.favorite_rounded, color: Colors.white, size: 28),
              const SizedBox(width: 10),
              const Text('Live Health Score', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Colors.white)),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), borderRadius: BorderRadius.circular(20)),
                child: Text(status, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13)),
              )
            ],
          ),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('$_healthScore', style: const TextStyle(fontSize: 48, fontWeight: FontWeight.w800, color: Colors.white, height: 1)),
              const SizedBox(width: 6),
              Padding(padding: const EdgeInsets.only(bottom: 6), child: Text('/ 100', style: TextStyle(fontSize: 16, color: Colors.white.withOpacity(0.7)))),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildVitalCard(_VitalData data, int index) {
    bool hasData = data.value > 0;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: hasData ? data.color.withOpacity(0.08) : Colors.grey.withOpacity(0.05),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: hasData ? data.color.withOpacity(0.15) : Colors.transparent),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Icon(data.icon, color: hasData ? data.color : Colors.grey, size: 20),
              const SizedBox(width: 6),
              Expanded(
                child: Text(data.label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7)), overflow: TextOverflow.ellipsis),
              ),
            ],
          ),
          hasData ? Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
               Text(data.value % 1 == 0 ? '${data.value.toInt()}' : '${data.value.toStringAsFixed(1)}', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: data.color, height: 1)),
               const SizedBox(width: 4),
               Padding(padding: const EdgeInsets.only(bottom: 2), child: Text(data.unit, style: TextStyle(fontSize: 11, color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5)))),
            ],
          ) : Text('Not available', style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
        ],
      ),
    );
  }
}

class _VitalData {
  String label;
  double value = 0;
  String unit;
  IconData icon;
  Color color;
  double min;
  double max;

  _VitalData({required this.label, required this.unit, required this.icon, required this.color, required this.min, required this.max});
}
