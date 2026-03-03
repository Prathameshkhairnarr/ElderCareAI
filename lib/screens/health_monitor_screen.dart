import 'package:flutter/material.dart';
import '../services/api_service.dart';

class HealthMonitorScreen extends StatefulWidget {
  const HealthMonitorScreen({super.key});

  @override
  State<HealthMonitorScreen> createState() => _HealthMonitorScreenState();
}

class _HealthMonitorScreenState extends State<HealthMonitorScreen> {
  final _api = ApiService();
  bool _isLoading = true;
  
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

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  Future<void> _fetchData() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      final data = await _api.getHealthSummary();
      if (data != null && mounted) {
        setState(() {
          _updateVital('heart_rate', data['heart_rate']);
          _updateVital('steps', data['steps']);
          _updateVital('spo2', data['spo2']);
          _updateVital('bp', data['bp']);
          _updateVital('sleep', data['sleep']);
          _updateVital('temperature', data['temperature']);
        });
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _updateVital(String key, dynamic backendData) {
    if (backendData != null && _vitals.containsKey(key)) {
      _vitals[key]!.value = (backendData['value'] as num).toDouble();
      // Logic to determine status based on thresholds could go here
    }
  }

  Future<void> _refreshData() async {
    await _fetchData();
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
            onPressed: _refreshData,
            icon: _isLoading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.refresh_rounded),
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: _isLoading && _vitals.values.every((v) => v.value == 0)
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Summary card
                  _buildSummaryCard(),
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

  Widget _buildSummaryCard() {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: const Duration(milliseconds: 600),
      builder: (context, value, child) => Opacity(opacity: value, child: child),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF26A69A), Color(0xFF00897B)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF26A69A).withValues(alpha: 0.3),
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
                Icon(
                  Icons.monitor_heart_rounded,
                  color: Colors.white,
                  size: 28,
                ),
                SizedBox(width: 10),
                Text(
                  'Overall Health',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Text(
              'Your vitals are being monitored. Syncing with backend...',
              style: TextStyle(
                fontSize: 14,
                color: Colors.white70,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Last synced: ${DateTime.now().hour}:${DateTime.now().minute.toString().padLeft(2, '0')}',
              style: const TextStyle(fontSize: 12, color: Colors.white54),
            ),
          ],
        ),
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
                      color: Theme.of(
                        context,
                      ).colorScheme.onSurface.withValues(alpha: 0.7),
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
                      color: Theme.of(
                        context,
                      ).colorScheme.onSurface.withValues(alpha: 0.5),
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
              color: Theme.of(
                context,
              ).colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
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
                      color: Theme.of(
                        context,
                      ).colorScheme.onSurface.withValues(alpha: 0.8),
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
