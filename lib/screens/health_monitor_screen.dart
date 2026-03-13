import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../services/health_sync_service.dart';
import '../services/app_logger.dart';

class HealthMonitorScreen extends StatefulWidget {
  const HealthMonitorScreen({super.key});

  @override
  State<HealthMonitorScreen> createState() => _HealthMonitorScreenState();
}

class _HealthMonitorScreenState extends State<HealthMonitorScreen> {
  final _api = ApiService();
  final _syncService = HealthSyncService();
  bool _isLoading = true;
  bool _isSyncing = false;
  String _lastSyncSource = 'none';

  // Default structure, values will be updated from backend
  final Map<String, _VitalData> _vitals = {
    'heart_rate': _VitalData(
      label: 'Heart Rate',
      value: 0,
      unit: 'bpm',
      icon: Icons.favorite_rounded,
      color: const Color(0xFFEF5350),
      min: 60,
      max: 100,
    ),
    'steps': _VitalData(
      label: 'Steps Today',
      value: 0,
      unit: 'steps',
      icon: Icons.directions_walk_rounded,
      color: const Color(0xFF7C4DFF),
      min: 0,
      max: 8000,
      status: 'Keep Going!',
    ),
    'spo2': _VitalData(
      label: 'SpO2',
      value: 0,
      unit: '%',
      icon: Icons.air_rounded,
      color: const Color(0xFF26A69A),
      min: 95,
      max: 100,
    ),
    'bp': _VitalData(
      label: 'Blood Pressure',
      value: 0,
      unit: 'mmHg',
      icon: Icons.speed_rounded,
      color: const Color(0xFF42A5F5),
      min: 90,
      max: 140,
    ),
    'sleep': _VitalData(
      label: 'Sleep',
      value: 0,
      unit: 'hrs',
      icon: Icons.bedtime_rounded,
      color: const Color(0xFF5C6BC0),
      min: 6,
      max: 9,
    ),
    'temperature': _VitalData(
      label: 'Temperature',
      value: 0,
      unit: '°F',
      icon: Icons.thermostat_rounded,
      color: const Color(0xFFFFA726),
      min: 97,
      max: 99.5,
    ),
  };

  // Health score from backend
  int _healthScore = 80;
  String _healthStatus = 'Fair';

  @override
  void initState() {
    super.initState();
    _initAndSync();
  }

  @override
  void dispose() {
    _syncService.stopSensorFallback();
    super.dispose();
  }

  Future<void> _initAndSync() async {
    if (!mounted) return;
    setState(() => _isLoading = true);

    try {
      // Initialize Health Connect service
      await _syncService.initialize();

      // Run the full sync chain (Health Connect → sensor → manual)
      final source = await _syncService.syncAll();
      _lastSyncSource = source;

      // Now fetch backend data (summary + score)
      await _fetchFromBackend();
    } catch (e) {
      AppLogger.error(LogCategory.lifecycle, 'Health sync init failed: $e');
    }

    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _fetchFromBackend() async {
    try {
      final results = await Future.wait([
        _api.getHealthSummary(),
        _api.getHealthScore(),
      ]).timeout(const Duration(seconds: 8));

      final summary = results[0];
      final scoreData = results[1];

      if (mounted) {
        setState(() {
          if (summary != null) {
            _updateVital('heart_rate', summary['heart_rate']);
            _updateVital('steps', summary['steps']);
            _updateVital('spo2', summary['spo2']);
            _updateVital('bp', summary['bp']);
            _updateVital('sleep', summary['sleep']);
            _updateVital('temperature', summary['temperature']);
          }
          if (scoreData != null) {
            _healthScore = scoreData['score'] ?? 80;
            _healthStatus = scoreData['status'] ?? 'Fair';
          }
        });
      }
    } catch (e) {
      AppLogger.error(LogCategory.network, 'Backend fetch failed: $e');
    }
  }

  void _updateVital(String key, dynamic backendData) {
    if (backendData != null && _vitals.containsKey(key)) {
      _vitals[key]!.value = (backendData['value'] as num).toDouble();
    }
  }

  Future<void> _refreshData() async {
    setState(() => _isSyncing = true);
    try {
      // Re-sync from devices/sensors
      final source = await _syncService.syncAll();
      _lastSyncSource = source;
      // Then refresh from backend
      await _fetchFromBackend();
    } catch (e) {
      AppLogger.error(LogCategory.lifecycle, 'Refresh failed: $e');
    }
    if (mounted) setState(() => _isSyncing = false);
  }

  // ── Manual Entry Bottom Sheet ─────────────────────────
  void _showManualEntrySheet() {
    final hrCtrl = TextEditingController();
    final stepsCtrl = TextEditingController();
    final spo2Ctrl = TextEditingController();
    final bpCtrl = TextEditingController();
    final sleepCtrl = TextEditingController();
    final tempCtrl = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom,
          ),
          child: Container(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
            decoration: BoxDecoration(
              color: Theme.of(ctx).colorScheme.surface,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(28),
              ),
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Theme.of(ctx)
                          .colorScheme
                          .onSurface
                          .withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.edit_rounded, color: Color(0xFF4FC3F7), size: 24),
                      SizedBox(width: 8),
                      Text(
                        'Enter Vitals Manually',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  _manualField(hrCtrl, 'Heart Rate', 'bpm', Icons.favorite_rounded, const Color(0xFFEF5350)),
                  const SizedBox(height: 10),
                  _manualField(stepsCtrl, 'Steps Today', 'steps', Icons.directions_walk_rounded, const Color(0xFF7C4DFF)),
                  const SizedBox(height: 10),
                  _manualField(spo2Ctrl, 'SpO2', '%', Icons.air_rounded, const Color(0xFF26A69A)),
                  const SizedBox(height: 10),
                  _manualField(bpCtrl, 'Blood Pressure (systolic)', 'mmHg', Icons.speed_rounded, const Color(0xFF42A5F5)),
                  const SizedBox(height: 10),
                  _manualField(sleepCtrl, 'Sleep Hours', 'hrs', Icons.bedtime_rounded, const Color(0xFF5C6BC0)),
                  const SizedBox(height: 10),
                  _manualField(tempCtrl, 'Temperature', '°F', Icons.thermostat_rounded, const Color(0xFFFFA726)),
                  const SizedBox(height: 24),

                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton.icon(
                      onPressed: () async {
                        // Parse values
                        _syncService.setManualVitals(
                          heartRate: double.tryParse(hrCtrl.text),
                          steps: double.tryParse(stepsCtrl.text),
                          spo2: double.tryParse(spo2Ctrl.text),
                          bp: double.tryParse(bpCtrl.text),
                          sleepHours: double.tryParse(sleepCtrl.text),
                          temperature: double.tryParse(tempCtrl.text),
                        );
                        // Sync to backend
                        await _syncService.syncToBackend();
                        if (context.mounted) Navigator.pop(ctx);
                        // Refresh data
                        await _fetchFromBackend();

                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: const Row(
                                children: [
                                  Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
                                  SizedBox(width: 10),
                                  Text('Vitals saved successfully!'),
                                ],
                              ),
                              behavior: SnackBarBehavior.floating,
                              backgroundColor: const Color(0xFF26A69A),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                          );
                        }
                      },
                      icon: const Icon(Icons.save_rounded),
                      label: const Text(
                        'Save Vitals',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF26A69A),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        elevation: 0,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _manualField(
    TextEditingController ctrl,
    String label,
    String unit,
    IconData icon,
    Color color,
  ) {
    return TextField(
      controller: ctrl,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
      decoration: InputDecoration(
        labelText: '$label ($unit)',
        prefixIcon: Icon(icon, color: color, size: 20),
        filled: true,
        fillColor: Theme.of(context)
            .colorScheme
            .surfaceContainerHighest
            .withValues(alpha: 0.3),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Health Monitor'),
        centerTitle: true,
        elevation: 0,
        scrolledUnderElevation: 0,
        actions: [
          IconButton(
            onPressed: _isSyncing ? null : _refreshData,
            icon: _isSyncing
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.refresh_rounded),
            tooltip: 'Sync & Refresh',
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showManualEntrySheet,
        backgroundColor: const Color(0xFF4FC3F7),
        icon: const Icon(Icons.edit_rounded, color: Colors.white),
        label: const Text(
          'Manual Entry',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
        ),
      ),
      body: _isLoading && _vitals.values.every((v) => v.value == 0)
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 80),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Health Score card (from backend)
                  _buildHealthScoreCard(),
                  const SizedBox(height: 16),

                  // Data source badge
                  _buildDataSourceBadge(),
                  const SizedBox(height: 24),

                  Text(
                    'Vitals',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Vitals grid
                  GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      mainAxisSpacing: 12,
                      crossAxisSpacing: 12,
                      childAspectRatio: 1.3,
                    ),
                    itemCount: _vitals.length,
                    itemBuilder: (context, index) {
                      final entry = _vitals.entries.elementAt(index);
                      return _buildVitalCard(entry.value, index);
                    },
                  ),
                  const SizedBox(height: 24),

                  // Tips section
                  _buildTipsSection(),
                ],
              ),
            ),
    );
  }

  Widget _buildHealthScoreCard() {
    String emoji;
    if (_healthStatus == 'Excellent') {
      emoji = '✨';
    } else if (_healthStatus == 'Good') {
      emoji = '👍';
    } else if (_healthStatus == 'Fair') {
      emoji = '⚠️';
    } else {
      emoji = '🚨';
    }

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: const Duration(milliseconds: 600),
      builder: (context, value, child) => Opacity(opacity: value, child: child),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFFEC407A), Color(0xFFAD1457)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFEC407A).withValues(alpha: 0.3),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.favorite_rounded, color: Colors.white, size: 28),
                SizedBox(width: 10),
                Text(
                  'Health Score',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '$_healthScore',
                  style: const TextStyle(
                    fontSize: 48,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    height: 1,
                  ),
                ),
                const SizedBox(width: 6),
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Text(
                    '/ 100',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.white.withValues(alpha: 0.7),
                    ),
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '$emoji $_healthStatus',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: _healthScore / 100,
                backgroundColor: Colors.white.withValues(alpha: 0.2),
                valueColor: const AlwaysStoppedAnimation(Colors.white),
                minHeight: 6,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDataSourceBadge() {
    IconData icon;
    String label;
    Color color;

    switch (_lastSyncSource) {
      case 'health_connect':
        icon = Icons.watch_rounded;
        label = 'Synced via Health Connect';
        color = const Color(0xFF26A69A);
        break;
      case 'sensor':
        icon = Icons.sensors_rounded;
        label = 'Using phone sensors';
        color = const Color(0xFF7C4DFF);
        break;
      case 'manual':
        icon = Icons.edit_rounded;
        label = 'Manual entry mode';
        color = const Color(0xFFFFB300);
        break;
      default:
        icon = Icons.info_outline_rounded;
        label = 'No data source connected';
        color = const Color(0xFF78909C);
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ),
          Text(
            'Last: ${DateTime.now().hour}:${DateTime.now().minute.toString().padLeft(2, '0')}',
            style: TextStyle(
              fontSize: 11,
              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVitalCard(_VitalData data, int index) {
    // Simple progress normalization
    double progress = 0.5;
    if (data.max > data.min) {
      progress = ((data.value - data.min) / (data.max - data.min)).clamp(0.0, 1.0);
    }

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: Duration(milliseconds: 500 + (index * 100)),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) {
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(0, 20 * (1 - value)),
            child: child,
          ),
        );
      },
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: data.color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: data.color.withValues(alpha: 0.15)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Icon(data.icon, color: data.color, size: 20),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    data.label,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withValues(alpha: 0.7),
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  data.value % 1 == 0
                      ? '${data.value.toInt()}'
                      : '${data.value}',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: data.color,
                    height: 1,
                  ),
                ),
                const SizedBox(width: 4),
                Padding(
                  padding: const EdgeInsets.only(bottom: 2),
                  child: Text(
                    data.unit,
                    style: TextStyle(
                      fontSize: 11,
                      color: Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withValues(alpha: 0.5),
                    ),
                  ),
                ),
              ],
            ),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: progress,
                backgroundColor: data.color.withValues(alpha: 0.1),
                valueColor: AlwaysStoppedAnimation(data.color),
                minHeight: 4,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTipsSection() {
    final tips = [
      {
        'icon': Icons.water_drop_rounded,
        'tip': 'Drink at least 8 glasses of water today',
      },
      {
        'icon': Icons.directions_walk_rounded,
        'tip': 'Try a 15-minute walk after lunch',
      },
      {
        'icon': Icons.bedtime_rounded,
        'tip': 'Aim for 7-8 hours of sleep tonight',
      },
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Daily Tips',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: 12),
        ...tips.map(
          (t) => Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Theme.of(context)
                  .colorScheme
                  .surfaceContainerHighest
                  .withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              children: [
                Icon(
                  t['icon'] as IconData,
                  color: const Color(0xFF4FC3F7),
                  size: 22,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    t['tip'] as String,
                    style: TextStyle(
                      fontSize: 13,
                      color: Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withValues(alpha: 0.8),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _VitalData {
  String label;
  double value;
  String unit;
  IconData icon;
  Color color;
  double min;
  double max;
  String? status;

  _VitalData({
    required this.label,
    required this.value,
    required this.unit,
    required this.icon,
    required this.color,
    required this.min,
    required this.max,
    this.status,
  });
}
