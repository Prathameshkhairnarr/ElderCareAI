import 'package:flutter/material.dart';

import '../models/health_profile.dart';
import '../models/medication.dart';
import '../services/api_service.dart';
import '../services/health_profile_service.dart';
import '../services/app_logger.dart';
import '../services/health_service.dart';

/// Unified Health tab — merges Health Monitor vitals + My Health profile
/// into a single scrollable screen with real-time ChangeNotifier sync.
class HealthProfileViewScreen extends StatefulWidget {
  /// When true, shows only the editable health profile form (for Profile screen).
  /// When false (default), shows only vitals dashboard (for Health tab).
  final bool showEditableOnly;

  const HealthProfileViewScreen({super.key, this.showEditableOnly = false});

  @override
  State<HealthProfileViewScreen> createState() =>
      _HealthProfileViewScreenState();
}

class _HealthProfileViewScreenState extends State<HealthProfileViewScreen> {
  final _api = ApiService();
  final _profileService = HealthProfileService();
  final _healthService = HealthService();
  final _formKey = GlobalKey<FormState>();

  bool _isLoading = true;
  bool _isSaving = false;

  List<UserMedication> _medications = [];

  // ── Form controllers ──
  final _heightController = TextEditingController();
  final _weightController = TextEditingController();
  final _conditionsController = TextEditingController();
  String? _selectedBloodGroup;

  final _genders = ['male', 'female', 'other'];
  final _bloodGroups = ['A+', 'A-', 'B+', 'B-', 'O+', 'O-', 'AB+', 'AB-'];

  final _predefinedConditions = [
    'Diabetes',
    'Hypertension',
    'Asthma',
    'Arthritis',
    'Heart Disease',
    'COPD',
    'Osteoporosis',
    'Alzheimer\'s',
    'Kidney Disease',
    'High Cholesterol',
    'Thyroid Disorder',
    'Stroke',
    'Cancer',
    'Other'
  ];

  // ── Vitals data ──
  Map<String, dynamic>? _vitalsSummary;

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
    _profileService.addListener(_onProfileUpdate);
    _loadAllData();
  }

  @override
  void dispose() {
    _profileService.removeListener(_onProfileUpdate);
    _heightController.dispose();
    _weightController.dispose();
    _conditionsController.dispose();
    super.dispose();
  }

  void _onProfileUpdate() {
    if (mounted) setState(() {});
  }

  // ── Data loading ───────────────────────────────
  Future<void> _loadAllData() async {
    if (!mounted) return;
    setState(() => _isLoading = true);

    try {
      // 1. Local profile (instant)
      final localProfile = await _profileService.load();
      if (mounted && !localProfile.isEmpty) {
        _populateFromProfile(localProfile);
      }

      // 2. API — vitals + profile + medications in parallel
      try {
        final results = await Future.wait([
          _api.getHealthSummary(),
          _api.getHealthProfile(),
          _api.getUserMedications(),
          _api.getHealthScore(),
        ]).timeout(const Duration(seconds: 8));

        final summary = results[0] as Map<String, dynamic>?;
        final apiProfile = results[1] as Map<String, dynamic>?;
        final meds = results[2] as List<UserMedication>;
        final scoreData = results[3] as Map<String, dynamic>?;

        if (mounted) {
          _vitalsSummary = summary;
          _medications = meds;
          if (summary != null) {
            _updateVital('heart_rate', summary['heart_rate']);
            _updateVital('steps', summary['steps']);
            _updateVital('spo2', summary['spo2']);
            _updateVital('bp', summary['bp']);
            _updateVital('sleep', summary['sleep']);
            _updateVital('temperature', summary['temperature']);
          }
          if (scoreData != null && summary == null) {
            _healthScore = scoreData['score'] ?? 80;
            _healthStatus = scoreData['status'] ?? 'Fair';
          }
          if (summary != null) {
            final stps = _vitals['steps']!.value.toInt();
            final slp = _vitals['sleep']!.value;
            final hr = _vitals['heart_rate']!.value;
            _healthScore = _healthService.calculateHealthScore(stps, slp, hr);
            
            if (_healthScore > 80) _healthStatus = 'Excellent';
            else if (_healthScore > 60) _healthStatus = 'Good';
            else if (_healthScore > 40) _healthStatus = 'Fair';
            else _healthStatus = 'Low Data';
          }

          // Merge API profile if local was empty
          if (localProfile.isEmpty &&
              apiProfile != null &&
              apiProfile['id'] != 0) {
            final profile = HealthProfile.fromJson(apiProfile);
            _populateFromProfile(profile);
            await _profileService.save(profile);
          }
        }
      } catch (e) {
        AppLogger.error(
          LogCategory.network,
          '[HEALTH] API load failed (using local): $e',
        );
      }
    } catch (e) {
      AppLogger.error(LogCategory.lifecycle, '[HEALTH] Data load failed: $e');
    }

    if (mounted) setState(() => _isLoading = false);
  }

  void _updateVital(String key, dynamic data) {
    if (data != null && _vitals.containsKey(key)) {
      _vitals[key]!.value = (data['value'] as num).toDouble();
    }
  }

  void _populateFromProfile(HealthProfile profile) {
    _heightController.text = profile.heightCm?.toString() ?? '';
    _weightController.text = profile.weightKg?.toString() ?? '';
    _conditionsController.text = profile.medicalConditions ?? '';
    _selectedBloodGroup = profile.bloodGroup;
  }

   HealthProfile _buildProfileFromForm() {
    // Keep existing immutable fields like name, dateOfBirth, gender
    final current = _profileService.profile;
    return current.copyWith(
      bloodGroup: _selectedBloodGroup,
      heightCm: double.tryParse(_heightController.text),
      weightKg: double.tryParse(_weightController.text),
      medicalConditions: _conditionsController.text.isNotEmpty
          ? _conditionsController.text
          : null,
    );
  }



  // ── Save ───────────────────────────────────────
  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    try {
      final profile = _buildProfileFromForm();

      // 1. Local save (always succeeds)
      final localSaved = await _profileService.save(profile);

      if (!mounted) return;

      if (localSaved) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Row(
              children: [
                Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
                SizedBox(width: 10),
                Text('Health profile saved!'),
              ],
            ),
            behavior: SnackBarBehavior.floating,
            backgroundColor: const Color(0xFF26A69A),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            duration: const Duration(seconds: 2),
          ),
        );
      }

      // 2. API fire-and-forget
      try {
        await _api
            .saveHealthProfile(profile.toJson())
            .timeout(const Duration(seconds: 5));
      } catch (e) {
        AppLogger.error(
          LogCategory.network,
          '[HEALTH] API save failed (local saved): $e',
        );
      }
    } catch (e) {
      AppLogger.error(LogCategory.lifecycle, '[HEALTH] Save failed: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Row(
              children: [
                Icon(Icons.error_outline, color: Colors.white, size: 20),
                SizedBox(width: 10),
                Text('Failed to save. Please try again.'),
              ],
            ),
            behavior: SnackBarBehavior.floating,
            backgroundColor: Colors.redAccent,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
      }
    }

    if (mounted) setState(() => _isSaving = false);
  }



  // ═══════════════════════════════════════════════
  //  BUILD
  // ═══════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Scaffold(
      // No floating action button since manual entry is removed
      body: SafeArea(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : RefreshIndicator(
                onRefresh: _loadAllData,
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Screen title
                        if (!widget.showEditableOnly) ...[
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  'Health',
                                  style: TextStyle(
                                    fontSize: 24,
                                    fontWeight: FontWeight.w800,
                                    color: cs.onSurface,
                                  ),
                                ),
                              ),
                              Container(
                                decoration: BoxDecoration(
                                  color: cs.surfaceContainerHighest,
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                child: IconButton(
                                  onPressed: _isLoading ? null : _loadAllData,
                                  icon: const Icon(
                                    Icons.refresh_rounded,
                                    size: 20,
                                  ),
                                  tooltip: 'Refresh',
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 20),

                          // ── Section A: Health Score Card ──
                          _buildHealthScoreCard(cs),
                          const SizedBox(height: 20),

                          // ── Section B: Vitals Summary ──
                          _sectionTitle('Vitals', cs),
                          const SizedBox(height: 12),
                          _buildVitalsGrid(cs),
                          const SizedBox(height: 20),
                        ],

                        // ── Editable Health Profile sections (only from Profile) ──
                        if (widget.showEditableOnly) ...[
                          _buildProfileStatusCard(cs),
                          const SizedBox(height: 20),

                          _sectionTitle('Blood Group', cs),
                          const SizedBox(height: 12),
                          _buildBasicInfoSection(cs),
                          const SizedBox(height: 20),

                          _sectionTitle('Body Metrics', cs),
                          const SizedBox(height: 12),
                          _buildBodyMetricsSection(cs),
                          const SizedBox(height: 20),

                          _sectionTitle('Medical Conditions', cs),
                          const SizedBox(height: 12),
                          _buildMedicalConditionsSection(cs),
                          const SizedBox(height: 20),

                          _sectionTitle('Active Medications', cs),
                          const SizedBox(height: 12),
                          _buildMedicationsSection(cs),
                          const SizedBox(height: 28),

                          // Save button
                          SizedBox(
                            width: double.infinity,
                            height: 52,
                            child: ElevatedButton.icon(
                              onPressed: _isSaving ? null : _saveProfile,
                              icon: _isSaving
                                  ? const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2.5,
                                      ),
                                    )
                                  : const Icon(Icons.save_rounded),
                              label: Text(
                                _isSaving ? 'Saving...' : 'Save Health Profile',
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF26A69A),
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                elevation: 0,
                              ),
                            ),
                          ),
                          const SizedBox(height: 20),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
      ),
    );
  }

  // ── Health Score Card ──────────────────────────
  // Backend health score
  int _healthScore = 80;
  String _healthStatus = 'Fair';

  Widget _buildHealthScoreCard(ColorScheme cs) {
    final healthScore = _healthScore;
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
                  '$healthScore',
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
                value: healthScore / 100,
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

  // ── Profile Status Card ───────────────────────
  Widget _buildProfileStatusCard(ColorScheme cs) {
    final profile = _profileService.profile;
    final completeness = profile.completeness;
    final lastUpdated = profile.lastUpdated;

    String timeAgo = 'Not saved yet';
    if (lastUpdated != null) {
      final diff = DateTime.now().difference(lastUpdated);
      if (diff.inMinutes < 1) {
        timeAgo = 'Just now';
      } else if (diff.inMinutes < 60) {
        timeAgo = '${diff.inMinutes}m ago';
      } else if (diff.inHours < 24) {
        timeAgo = '${diff.inHours}h ago';
      } else {
        timeAgo = '${diff.inDays}d ago';
      }
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cs.outline.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.person_rounded, color: cs.primary, size: 20),
              const SizedBox(width: 8),
              const Text(
                'My Health Profile',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: completeness == 100
                      ? const Color(0xFF26A69A).withValues(alpha: 0.15)
                      : const Color(0xFFFFB300).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '$completeness% complete',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: completeness == 100
                        ? const Color(0xFF26A69A)
                        : const Color(0xFFFFB300),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: completeness / 100,
              backgroundColor: cs.outline.withValues(alpha: 0.1),
              valueColor: AlwaysStoppedAnimation(
                completeness == 100
                    ? const Color(0xFF26A69A)
                    : const Color(0xFF4FC3F7),
              ),
              minHeight: 5,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(
                Icons.access_time_rounded,
                size: 14,
                color: cs.onSurface.withValues(alpha: 0.4),
              ),
              const SizedBox(width: 4),
              Text(
                'Last saved: $timeAgo',
                style: TextStyle(
                  fontSize: 12,
                  color: cs.onSurface.withValues(alpha: 0.4),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── Vitals Grid ────────────────────────────────
  Widget _buildVitalsGrid(ColorScheme cs) {
    final entries = _vitals.entries.toList();
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 1.3,
      ),
      itemCount: entries.length,
      itemBuilder: (context, index) {
        return _buildVitalCard(entries[index].value, index, cs);
      },
    );
  }

  Widget _buildVitalCard(_VitalData data, int index, ColorScheme cs) {
    double progress = 0.5;
    if (data.max > data.min) {
      progress = ((data.value - data.min) / (data.max - data.min)).clamp(
        0.0,
        1.0,
      );
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
                      color: cs.onSurface.withValues(alpha: 0.7),
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Flexible(
                  child: Text(
                    data.value % 1 == 0
                        ? '${data.value.toInt()}'
                        : '${data.value}',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: data.color,
                      height: 1,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 4),
                Padding(
                  padding: const EdgeInsets.only(bottom: 2),
                  child: Text(
                    data.unit,
                    style: TextStyle(
                      fontSize: 11,
                      color: cs.onSurface.withValues(alpha: 0.5),
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

  // ── Section Title ─────────────────────────────
  Widget _sectionTitle(String title, ColorScheme cs) {
    return Text(
      title,
      style: TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.w700,
        color: cs.onSurface,
      ),
    );
  }

  // ── Basic Info Section ────────────────────────
  Widget _buildBasicInfoSection(ColorScheme cs) {
    return _cardWrapper(
      cs,
      child: Column(
        children: [
          DropdownButtonFormField<String>(
            value: _selectedBloodGroup,
            dropdownColor: cs.surfaceContainerHighest,
            style: TextStyle(color: cs.onSurface, fontSize: 16),
            icon: Icon(Icons.arrow_drop_down_rounded, color: cs.onSurface.withValues(alpha: 0.5)),
            decoration: _inputDecoration(
              label: 'Blood Group',
              icon: Icons.bloodtype_rounded,
              cs: cs,
            ),
            items: _bloodGroups
                .map((bg) => DropdownMenuItem(value: bg, child: Text(bg)))
                .toList(),
            onChanged: (val) => setState(() => _selectedBloodGroup = val),
          ),
        ],
      ),
    );
  }

  // ── Body Metrics Section ──────────────────────
  Widget _buildBodyMetricsSection(ColorScheme cs) {
    // Live BMI calculation from form
    final h = double.tryParse(_heightController.text);
    final w = double.tryParse(_weightController.text);
    double? bmiValue;
    String bmiLabel = 'N/A';
    if (h != null && w != null && h > 0) {
      final hm = h / 100;
      bmiValue = w / (hm * hm);
      if (bmiValue < 18.5) {
        bmiLabel = 'Underweight';
      } else if (bmiValue < 25) {
        bmiLabel = 'Normal';
      } else if (bmiValue < 30) {
        bmiLabel = 'Overweight';
      } else {
        bmiLabel = 'Obese';
      }
    }

    Color bmiColor;
    if (bmiValue == null) {
      bmiColor = cs.onSurface.withValues(alpha: 0.4);
    } else if (bmiValue < 18.5 || bmiValue >= 30) {
      bmiColor = const Color(0xFFEF5350);
    } else if (bmiValue >= 25) {
      bmiColor = const Color(0xFFFFB300);
    } else {
      bmiColor = const Color(0xFF26A69A);
    }

    return _cardWrapper(
      cs,
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: _heightController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  style: TextStyle(color: cs.onSurface),
                  decoration: _inputDecoration(
                    label: 'Height (cm)',
                    icon: Icons.height_rounded,
                    cs: cs,
                  ),
                  validator: (v) {
                    if (v != null && v.isNotEmpty) {
                      final val = double.tryParse(v);
                      if (val == null || val < 30 || val > 300) return '30-300';
                    }
                    return null;
                  },
                  onChanged: (_) => setState(() {}),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextFormField(
                  controller: _weightController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  style: TextStyle(color: cs.onSurface),
                  decoration: _inputDecoration(
                    label: 'Weight (kg)',
                    icon: Icons.monitor_weight_rounded,
                    cs: cs,
                  ),
                  validator: (v) {
                    if (v != null && v.isNotEmpty) {
                      final val = double.tryParse(v);
                      if (val == null || val < 5 || val > 500) return '5-500';
                    }
                    return null;
                  },
                  onChanged: (_) => setState(() {}),
                ),
              ),
            ],
          ),
          if (bmiValue != null) ...[
            const SizedBox(height: 14),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
              decoration: BoxDecoration(
                color: bmiColor.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: bmiColor.withValues(alpha: 0.15)),
              ),
              child: Row(
                children: [
                  Icon(Icons.speed_rounded, color: bmiColor, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'BMI: ${bmiValue.toStringAsFixed(1)} — $bmiLabel',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: bmiColor,
                      ),
                      softWrap: true,
                      maxLines: null,
                      overflow: TextOverflow.visible,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ── Medical Conditions Section ────────────────
  Widget _buildMedicalConditionsSection(ColorScheme cs) {
    return _cardWrapper(
      cs,
      child: InkWell(
        onTap: () => _showMedicalConditionsBottomSheet(cs),
        borderRadius: BorderRadius.circular(14),
        child: IgnorePointer(
          child: TextFormField(
            controller: _conditionsController,
            maxLines: null,
            minLines: 1,
            style: TextStyle(color: cs.onSurface),
            decoration:
                _inputDecoration(
                  label: 'Medical Conditions',
                  icon: Icons.medical_information_rounded,
                  cs: cs,
                ).copyWith(
                  hintText: 'Tap to select conditions...',
                  hintStyle: TextStyle(
                    color: cs.onSurface.withValues(alpha: 0.3),
                    fontSize: 13,
                  ),
                  suffixIcon: Icon(
                    Icons.arrow_drop_down_rounded,
                    color: cs.onSurface.withValues(alpha: 0.5),
                  ),
                  alignLabelWithHint: true,
                ),
          ),
        ),
      ),
    );
  }

  void _showMedicalConditionsBottomSheet(ColorScheme cs) {
    List<String> selected = _conditionsController.text
        .split(',')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Container(
              height: MediaQuery.of(context).size.height * 0.7,
              decoration: BoxDecoration(
                color: cs.surface,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: Column(
                children: [
                  // Handle
                  Center(
                    child: Container(
                      margin: const EdgeInsets.only(top: 12, bottom: 8),
                      height: 4,
                      width: 40,
                      decoration: BoxDecoration(
                        color: cs.onSurface.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  // Header
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Select Conditions',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                            color: cs.onSurface,
                          ),
                        ),
                        TextButton(
                          onPressed: () {
                            setState(() {
                              _conditionsController.text = selected.join(', ');
                            });
                            Navigator.pop(context);
                          },
                          child: const Text('Done', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1),
                  // List
                  Expanded(
                    child: ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                      itemCount: _predefinedConditions.length,
                      itemBuilder: (context, index) {
                        final condition = _predefinedConditions[index];
                        final isSelected = selected.contains(condition);
                        return CheckboxListTile(
                          title: Text(
                            condition,
                            style: TextStyle(
                              color: cs.onSurface,
                              fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                            ),
                          ),
                          value: isSelected,
                          activeColor: const Color(0xFF26A69A),
                          checkColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          onChanged: (bool? val) {
                            setSheetState(() {
                              if (val == true) {
                                selected.add(condition);
                              } else {
                                selected.remove(condition);
                              }
                            });
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }



  // ── Shared Helpers ────────────────────────────
  Widget _cardWrapper(ColorScheme cs, {required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cs.outline.withValues(alpha: 0.08)),
      ),
      child: child,
    );
  }

  InputDecoration _inputDecoration({
    required String label,
    required IconData icon,
    required ColorScheme cs,
  }) {
    return InputDecoration(
      labelText: label,
      labelStyle: TextStyle(color: cs.onSurface.withValues(alpha: 0.5)),
      prefixIcon: Icon(icon, color: const Color(0xFF4FC3F7), size: 20),
      filled: true,
      fillColor: cs.surface.withValues(alpha: 0.5),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: cs.outline.withValues(alpha: 0.1)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0xFF4FC3F7), width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Colors.redAccent),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
    );
  }

  // ── Medications Section ───────────────────────
  Widget _buildMedicationsSection(ColorScheme cs) {
    return _cardWrapper(
      cs,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_medications.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 20),
              child: Center(
                child: Text(
                  'No active medications recorded.',
                  style: TextStyle(color: cs.onSurface.withValues(alpha: 0.5)),
                ),
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _medications.length,
              separatorBuilder: (_, __) => Divider(color: cs.outline.withValues(alpha: 0.1)),
              itemBuilder: (context, index) {
                final med = _medications[index];
                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: CircleAvatar(
                    backgroundColor: const Color(0xFF4FC3F7).withValues(alpha: 0.15),
                    child: const Icon(Icons.medication_rounded, color: Color(0xFF4FC3F7), size: 18),
                  ),
                  title: Text(
                    med.medicine.name,
                    style: TextStyle(fontWeight: FontWeight.w700, color: cs.onSurface),
                  ),
                  subtitle: Text(
                    '${med.dosageValue != null ? med.dosageValue.toString() : ""} ${med.dosageUnit ?? ""} • ${med.frequencyPerDay}x / day',
                    style: TextStyle(fontSize: 13, color: cs.onSurface.withValues(alpha: 0.6)),
                  ),
                  trailing: IconButton(
                    icon: Icon(Icons.close_rounded, color: Colors.red.withValues(alpha: 0.6), size: 20),
                    onPressed: () => _deleteMedication(med.id),
                    tooltip: 'Remove',
                  ),
                );
              },
            ),
          const SizedBox(height: 12),
          ElevatedButton.icon(
            onPressed: () => _showAddMedicationSheet(cs),
            icon: const Icon(Icons.add_rounded),
            label: const Text('Add Medication', style: TextStyle(fontWeight: FontWeight.w600)),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF26A69A).withValues(alpha: 0.1),
              foregroundColor: const Color(0xFF26A69A),
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              minimumSize: const Size(double.infinity, 48),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteMedication(int medId) async {
    final success = await _api.deleteUserMedication(medId);
    if (success) {
      if (mounted) {
        setState(() {
          _medications.removeWhere((m) => m.id == medId);
        });
      }
    }
  }

  void _showAddMedicationSheet(ColorScheme cs) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return _AddMedicationSheet(api: _api, colorScheme: cs, onAdded: (newMed) {
          setState(() => _medications.insert(0, newMed));
        });
      },
    );
  }
}

class _AddMedicationSheet extends StatefulWidget {
  final ApiService api;
  final ColorScheme colorScheme;
  final Function(UserMedication) onAdded;

  const _AddMedicationSheet({
    required this.api,
    required this.colorScheme,
    required this.onAdded,
  });

  @override
  State<_AddMedicationSheet> createState() => _AddMedicationSheetState();
}

class _AddMedicationSheetState extends State<_AddMedicationSheet> {
  final _searchController = TextEditingController();
  List<Medicine> _searchResults = [];
  bool _isSearching = false;
  
  Medicine? _selectedMedicine;
  
  final _dosageController = TextEditingController();
  final _unitController = TextEditingController(text: 'mg');
  int _frequency = 1;
  bool _isSaving = false;

  void _performSearch(String query) async {
    if (query.trim().length < 2) {
      if (mounted) setState(() => _searchResults = []);
      return;
    }
    setState(() => _isSearching = true);
    final results = await widget.api.searchMedicines(query.trim());
    if (mounted) {
      setState(() {
        _searchResults = results;
        _isSearching = false;
      });
    }
  }

  void _save() async {
    if (_selectedMedicine == null) return;
    setState(() => _isSaving = true);
    
    final med = await widget.api.addUserMedication(
      medicineId: _selectedMedicine!.id,
      dosageValue: double.tryParse(_dosageController.text),
      dosageUnit: _unitController.text,
      frequencyPerDay: _frequency,
    );
    
    if (mounted) {
      setState(() => _isSaving = false);
      if (med != null) {
        widget.onAdded(med);
        Navigator.pop(context);
      }
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _dosageController.dispose();
    _unitController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = widget.colorScheme;
    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 12, bottom: 8),
              height: 4,
              width: 40,
              decoration: BoxDecoration(
                color: cs.onSurface.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  _selectedMedicine == null ? 'Find Medication' : 'Set Dosage',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: cs.onSurface),
                ),
                CloseButton(color: cs.onSurface),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: _selectedMedicine == null ? _buildSearchScreen(cs) : _buildDosageScreen(cs),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchScreen(ColorScheme cs) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: TextField(
            controller: _searchController,
            autofocus: true,
            style: TextStyle(color: cs.onSurface),
            decoration: InputDecoration(
              hintText: 'Search for Dolo, Augmentin...',
              hintStyle: TextStyle(color: cs.onSurface.withValues(alpha: 0.4)),
              prefixIcon: Icon(Icons.search_rounded, color: cs.onSurface.withValues(alpha: 0.6)),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              filled: true,
              fillColor: cs.surfaceContainerHighest.withValues(alpha: 0.5),
            ),
            onChanged: _performSearch,
          ),
        ),
        if (_isSearching)
          const Padding(padding: EdgeInsets.all(20), child: CircularProgressIndicator())
        else
          Expanded(
            child: ListView.builder(
              itemCount: _searchResults.length,
              itemBuilder: (context, index) {
                final m = _searchResults[index];
                return ListTile(
                  leading: CircleAvatar(
                    backgroundColor: const Color(0xFF4FC3F7).withValues(alpha: 0.15),
                    child: const Icon(Icons.medication_rounded, color: Color(0xFF4FC3F7)),
                  ),
                  title: Text(m.name, style: TextStyle(fontWeight: FontWeight.w600, color: cs.onSurface)),
                  subtitle: Text(
                    '${m.composition ?? 'Unknown composition'} • ${m.manufacturer ?? 'Unknown manufacturer'}',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 12, color: cs.onSurface.withValues(alpha: 0.6)),
                  ),
                  onTap: () {
                    setState(() => _selectedMedicine = m);
                  },
                );
              },
            ),
          ),
      ],
    );
  }

  Widget _buildDosageScreen(ColorScheme cs) {
    final m = _selectedMedicine!;
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: cs.primaryContainer.withValues(alpha: 0.3),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(m.name, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: cs.onSurface)),
              const SizedBox(height: 4),
              Text(m.composition ?? 'N/A', style: TextStyle(fontSize: 13, color: cs.onSurface.withValues(alpha: 0.7))),
            ],
          ),
        ),
        const SizedBox(height: 24),
        Row(
          children: [
            Expanded(
              flex: 2,
              child: TextFormField(
                controller: _dosageController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                style: TextStyle(color: cs.onSurface),
                decoration: InputDecoration(
                  labelText: 'Dosage',
                  labelStyle: TextStyle(color: cs.onSurface.withValues(alpha: 0.6)),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: cs.outline.withValues(alpha: 0.2))),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 1,
              child: TextFormField(
                controller: _unitController,
                style: TextStyle(color: cs.onSurface),
                decoration: InputDecoration(
                  labelText: 'Unit',
                  labelStyle: TextStyle(color: cs.onSurface.withValues(alpha: 0.6)),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: cs.outline.withValues(alpha: 0.2))),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        Text('Frequency: $_frequency per day', style: TextStyle(fontWeight: FontWeight.w600, color: cs.onSurface)),
        Slider(
          value: _frequency.toDouble(),
          min: 1,
          max: 6,
          divisions: 5,
          activeColor: const Color(0xFF26A69A),
          onChanged: (val) => setState(() => _frequency = val.toInt()),
        ),
        const SizedBox(height: 32),
        ElevatedButton(
          onPressed: _isSaving ? null : _save,
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF26A69A),
            foregroundColor: Colors.white,
            minimumSize: const Size(double.infinity, 52),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          child: _isSaving 
            ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5)) 
            : const Text('Add Medication', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
        ),
        const SizedBox(height: 12),
        TextButton(
          onPressed: () => setState(() => _selectedMedicine = null),
          child: Text('Back to Search', style: TextStyle(color: cs.primary)),
        )
      ],
    );
  }
}


// ── Vital data model (private) ──────────────────
class _VitalData {
  String label;
  double value;
  String unit;
  IconData icon;
  Color color;
  double min;
  double max;

  _VitalData({
    required this.label,
    required this.value,
    required this.unit,
    required this.icon,
    required this.color,
    required this.min,
    required this.max,
  });
}
