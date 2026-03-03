import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/health_profile.dart';
import '../services/api_service.dart';
import '../services/health_profile_service.dart';
import '../services/app_logger.dart';

/// Unified Health tab — merges Health Monitor vitals + My Health profile
/// into a single scrollable screen with real-time ChangeNotifier sync.
class HealthProfileViewScreen extends StatefulWidget {
  const HealthProfileViewScreen({super.key});

  @override
  State<HealthProfileViewScreen> createState() =>
      _HealthProfileViewScreenState();
}

class _HealthProfileViewScreenState extends State<HealthProfileViewScreen> {
  final _api = ApiService();
  final _profileService = HealthProfileService();
  final _formKey = GlobalKey<FormState>();

  bool _isLoading = true;
  bool _isSaving = false;

  // ── Form controllers ──
  final _ageController = TextEditingController();
  final _heightController = TextEditingController();
  final _weightController = TextEditingController();
  final _conditionsController = TextEditingController();
  final _emergencyContactController = TextEditingController();
  String? _selectedGender;
  String? _selectedBloodGroup;

  final _genders = ['male', 'female', 'other'];
  final _bloodGroups = ['A+', 'A-', 'B+', 'B-', 'O+', 'O-', 'AB+', 'AB-'];

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
    _ageController.dispose();
    _heightController.dispose();
    _weightController.dispose();
    _conditionsController.dispose();
    _emergencyContactController.dispose();
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

      // 2. API — vitals + profile in parallel
      try {
        final results = await Future.wait([
          _api.getHealthSummary(),
          _api.getHealthProfile(),
        ]).timeout(const Duration(seconds: 5));

        final summary = results[0];
        final apiProfile = results[1];

        if (mounted) {
          _vitalsSummary = summary;
          if (summary != null) {
            _updateVital('heart_rate', summary['heart_rate']);
            _updateVital('steps', summary['steps']);
            _updateVital('spo2', summary['spo2']);
            _updateVital('bp', summary['bp']);
            _updateVital('sleep', summary['sleep']);
            _updateVital('temperature', summary['temperature']);
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
    _ageController.text = profile.age?.toString() ?? '';
    _heightController.text = profile.heightCm?.toString() ?? '';
    _weightController.text = profile.weightKg?.toString() ?? '';
    _conditionsController.text = profile.medicalConditions ?? '';
    _emergencyContactController.text = profile.emergencyPhone ?? '';
    _selectedGender = profile.gender;
    _selectedBloodGroup = profile.bloodGroup;
  }

  HealthProfile _buildProfileFromForm() {
    return HealthProfile(
      age: int.tryParse(_ageController.text),
      gender: _selectedGender,
      bloodGroup: _selectedBloodGroup,
      heightCm: double.tryParse(_heightController.text),
      weightKg: double.tryParse(_weightController.text),
      medicalConditions: _conditionsController.text.isNotEmpty
          ? _conditionsController.text
          : null,
      emergencyPhone: _emergencyContactController.text.isNotEmpty
          ? _emergencyContactController.text
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

  Future<void> _makeCall(String phone) async {
    try {
      final uri = Uri(scheme: 'tel', path: phone);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
      }
    } catch (e) {
      AppLogger.error(LogCategory.lifecycle, '[HEALTH] Call launch error: $e');
    }
  }

  // ═══════════════════════════════════════════════
  //  BUILD
  // ═══════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
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
                        const SizedBox(height: 24),

                        // ── Section C: My Health Profile ──
                        _buildProfileStatusCard(cs),
                        const SizedBox(height: 20),

                        _sectionTitle('Basic Information', cs),
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

                        _sectionTitle('Emergency Contact', cs),
                        const SizedBox(height: 12),
                        _buildEmergencyContactSection(cs),
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
                    ),
                  ),
                ),
              ),
      ),
    );
  }

  // ── Health Score Card ──────────────────────────
  Widget _buildHealthScoreCard(ColorScheme cs) {
    int healthScore = 85;
    if (_vitalsSummary != null) {
      if (_vitalsSummary!['heart_rate'] == null) healthScore -= 5;
      if (_vitalsSummary!['spo2'] != null &&
          _vitalsSummary!['spo2']['value'] < 95) {
        healthScore -= 10;
      }
    }
    if (_ageController.text.isNotEmpty) {
      final age = int.tryParse(_ageController.text);
      if (age != null && age > 65) healthScore -= 5;
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
                    healthScore > 80 ? '✨ Good' : '⚠️ Fair',
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
          TextFormField(
            controller: _ageController,
            keyboardType: TextInputType.number,
            style: TextStyle(color: cs.onSurface),
            decoration: _inputDecoration(
              label: 'Age',
              icon: Icons.cake_rounded,
              cs: cs,
            ),
            validator: (v) {
              if (v != null && v.isNotEmpty) {
                final age = int.tryParse(v);
                if (age == null || age < 1 || age > 150) {
                  return 'Invalid age (1-150)';
                }
              }
              return null;
            },
          ),
          const SizedBox(height: 14),
          DropdownButtonFormField<String>(
            value: _selectedGender,
            dropdownColor: cs.surfaceContainerHighest,
            style: TextStyle(color: cs.onSurface),
            decoration: _inputDecoration(
              label: 'Gender',
              icon: Icons.person_rounded,
              cs: cs,
            ),
            items: _genders
                .map(
                  (g) => DropdownMenuItem(
                    value: g,
                    child: Text(g[0].toUpperCase() + g.substring(1)),
                  ),
                )
                .toList(),
            onChanged: (val) => setState(() => _selectedGender = val),
          ),
          const SizedBox(height: 14),
          DropdownButtonFormField<String>(
            value: _selectedBloodGroup,
            dropdownColor: cs.surfaceContainerHighest,
            style: TextStyle(color: cs.onSurface),
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
      child: TextFormField(
        controller: _conditionsController,
        maxLines: null,
        minLines: 3,
        style: TextStyle(color: cs.onSurface),
        decoration:
            _inputDecoration(
              label: 'Medical Conditions',
              icon: Icons.medical_information_rounded,
              cs: cs,
            ).copyWith(
              hintText: 'e.g. diabetes, hypertension, arthritis...',
              hintStyle: TextStyle(
                color: cs.onSurface.withValues(alpha: 0.3),
                fontSize: 13,
              ),
              alignLabelWithHint: true,
            ),
      ),
    );
  }

  // ── Emergency Contact Section ─────────────────
  Widget _buildEmergencyContactSection(ColorScheme cs) {
    return _cardWrapper(
      cs,
      child: Row(
        children: [
          Expanded(
            child: TextFormField(
              controller: _emergencyContactController,
              keyboardType: TextInputType.phone,
              style: TextStyle(color: cs.onSurface),
              decoration: _inputDecoration(
                label: 'Emergency Contact Phone',
                icon: Icons.emergency_rounded,
                cs: cs,
              ),
              validator: (v) {
                if (v != null && v.isNotEmpty && v.length < 10) {
                  return 'Enter valid phone';
                }
                return null;
              },
            ),
          ),
          if (_emergencyContactController.text.length >= 10) ...[
            const SizedBox(width: 10),
            Container(
              decoration: BoxDecoration(
                color: const Color(0xFF26A69A).withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: IconButton(
                onPressed: () => _makeCall(_emergencyContactController.text),
                icon: const Icon(Icons.call_rounded, color: Color(0xFF26A69A)),
                tooltip: 'Call Emergency',
              ),
            ),
          ],
        ],
      ),
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
