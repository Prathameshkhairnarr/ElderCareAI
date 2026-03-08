import 'package:flutter/material.dart';
import '../models/health_profile.dart';
import '../services/api_service.dart';
import '../services/health_profile_service.dart';
import '../services/app_logger.dart';

class MyHealthScreen extends StatefulWidget {
  const MyHealthScreen({super.key});

  @override
  State<MyHealthScreen> createState() => _MyHealthScreenState();
}

class _MyHealthScreenState extends State<MyHealthScreen> {
  final _api = ApiService();
  final _profileService = HealthProfileService();
  final _formKey = GlobalKey<FormState>();

  bool _isLoading = true;
  bool _isSaving = false;

  // Form controllers
  final _ageController = TextEditingController();
  final _heightController = TextEditingController();
  final _weightController = TextEditingController();
  final _conditionsController = TextEditingController();
  final _emergencyContactController = TextEditingController();

  String? _selectedGender;
  String? _selectedBloodGroup;

  final _genders = ['male', 'female', 'other'];
  final _bloodGroups = ['A+', 'A-', 'B+', 'B-', 'O+', 'O-', 'AB+', 'AB-'];

  // Vitals summary
  Map<String, dynamic>? _vitalsSummary;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _ageController.dispose();
    _heightController.dispose();
    _weightController.dispose();
    _conditionsController.dispose();
    _emergencyContactController.dispose();
    super.dispose();
  }

  /// Populate form controllers from a HealthProfile.
  void _populateFromProfile(HealthProfile profile) {
    _ageController.text = profile.age?.toString() ?? '';
    _heightController.text = profile.heightCm?.toString() ?? '';
    _weightController.text = profile.weightKg?.toString() ?? '';
    _conditionsController.text = profile.medicalConditions ?? '';
    _emergencyContactController.text = profile.emergencyPhone ?? '';
    _selectedGender = profile.gender;
    _selectedBloodGroup = profile.bloodGroup;
  }

  /// Load data: local first (instant), then API in background.
  Future<void> _loadData() async {
    if (!mounted) return;
    setState(() => _isLoading = true);

    try {
      // 1. Load from local storage FIRST (instant)
      final localProfile = await _profileService.load();
      if (mounted && !localProfile.isEmpty) {
        _populateFromProfile(localProfile);
      }

      // 2. Try API in background — merge if local was empty
      try {
        final results = await Future.wait([
          _api.getHealthProfile(),
          _api.getHealthSummary(),
        ]).timeout(const Duration(seconds: 5));

        final apiProfile = results[0];
        final summary = results[1];

        if (mounted) {
          // If local was empty but API has data, use API data
          if (localProfile.isEmpty &&
              apiProfile != null &&
              apiProfile['id'] != 0) {
            final profile = HealthProfile.fromJson(apiProfile);
            _populateFromProfile(profile);
            // Save API data locally for next time
            await _profileService.save(profile);
          }
          _vitalsSummary = summary;
        }
      } catch (e) {
        // API failed — local data already loaded, no problem
        AppLogger.error(
          LogCategory.network,
          'Health API load failed (using local): $e',
        );
      }
    } catch (e) {
      AppLogger.error(LogCategory.lifecycle, 'Health data load failed: $e');
    }

    if (mounted) setState(() => _isLoading = false);
  }

  /// Build HealthProfile from current form values.
  HealthProfile _buildProfileFromForm() {
    // Estimate DOB from entered age (Jan 1 of birth year)
    final enteredAge = int.tryParse(_ageController.text);
    final estimatedDob = enteredAge != null
        ? DateTime(DateTime.now().year - enteredAge, 1, 1)
        : null;
    return HealthProfile(
      dateOfBirth: estimatedDob,
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

  /// Save: local first (always succeeds), then API fire-and-forget.
  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    try {
      final profile = _buildProfileFromForm();

      // 1. Save to local storage FIRST (always succeeds)
      final localSaved = await _profileService.save(profile);

      if (!mounted) return;

      if (localSaved) {
        // Show success immediately after local save
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

      // 2. Try API in background (fire-and-forget)
      try {
        final data = profile.toJson();
        await _api.saveHealthProfile(data).timeout(const Duration(seconds: 5));
      } catch (e) {
        AppLogger.error(
          LogCategory.network,
          'API health save failed (local saved): $e',
        );
      }
    } catch (e) {
      AppLogger.error(LogCategory.lifecycle, 'Health save failed: $e');
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Health'),
        centerTitle: true,
        elevation: 0,
        scrolledUnderElevation: 0,
        actions: [
          IconButton(
            onPressed: _loadData,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Health score card
                    _buildHealthScoreCard(),
                    const SizedBox(height: 16),

                    // Profile status card (NEW)
                    _buildProfileStatusCard(),
                    const SizedBox(height: 24),

                    // Vitals summary
                    if (_vitalsSummary != null) ...[
                      _sectionTitle('Vitals Summary'),
                      const SizedBox(height: 12),
                      _buildVitalsSummary(),
                      const SizedBox(height: 24),
                    ],

                    // Basic Info section
                    _sectionTitle('Basic Information'),
                    const SizedBox(height: 12),
                    _buildBasicInfoSection(),
                    const SizedBox(height: 24),

                    // Body Metrics section
                    _sectionTitle('Body Metrics'),
                    const SizedBox(height: 12),
                    _buildBodyMetricsSection(),
                    const SizedBox(height: 24),

                    // Medical Conditions section
                    _sectionTitle('Medical Conditions'),
                    const SizedBox(height: 12),
                    _buildMedicalConditionsSection(),
                    const SizedBox(height: 24),

                    // Emergency Contact section
                    _sectionTitle('Emergency Contact'),
                    const SizedBox(height: 12),
                    _buildEmergencyContactSection(),
                    const SizedBox(height: 32),

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
    );
  }

  // ── Profile Status Card (NEW) ──────────────────
  Widget _buildProfileStatusCard() {
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
        color: Theme.of(
          context,
        ).colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.08),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.person_rounded,
                color: Theme.of(context).colorScheme.primary,
                size: 20,
              ),
              const SizedBox(width: 8),
              const Text(
                'Profile Status',
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
          // Progress bar
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: completeness / 100,
              backgroundColor: Theme.of(
                context,
              ).colorScheme.outline.withValues(alpha: 0.1),
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
                color: Theme.of(
                  context,
                ).colorScheme.onSurface.withValues(alpha: 0.4),
              ),
              const SizedBox(width: 4),
              Text(
                'Last saved: $timeAgo',
                style: TextStyle(
                  fontSize: 12,
                  color: Theme.of(
                    context,
                  ).colorScheme.onSurface.withValues(alpha: 0.4),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _sectionTitle(String title) {
    return Text(
      title,
      style: TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.w700,
        color: Theme.of(context).colorScheme.onSurface,
      ),
    );
  }

  Widget _buildHealthScoreCard() {
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

  Widget _buildVitalsSummary() {
    String getVal(String key, String unit, String fallback) {
      if (_vitalsSummary == null || _vitalsSummary![key] == null)
        return fallback;
      final val = _vitalsSummary![key]['value'];
      return val % 1 == 0 ? '${val.toInt()} $unit' : '$val $unit';
    }

    final stats = [
      {
        'label': 'Heart Rate',
        'value': getVal('heart_rate', 'bpm', '--'),
        'icon': Icons.favorite_rounded,
        'color': const Color(0xFFEF5350),
      },
      {
        'label': 'Steps',
        'value': getVal('steps', '', '0'),
        'icon': Icons.directions_walk_rounded,
        'color': const Color(0xFF7C4DFF),
      },
      {
        'label': 'Sleep',
        'value': getVal('sleep', 'hrs', '--'),
        'icon': Icons.bedtime_rounded,
        'color': const Color(0xFF5C6BC0),
      },
      {
        'label': 'SpO2',
        'value': getVal('spo2', '%', '--'),
        'icon': Icons.air_rounded,
        'color': const Color(0xFF26A69A),
      },
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
        childAspectRatio: 2.0,
      ),
      itemCount: stats.length,
      itemBuilder: (context, index) {
        final s = stats[index];
        return Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: (s['color'] as Color).withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: (s['color'] as Color).withValues(alpha: 0.15),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Row(
                children: [
                  Icon(
                    s['icon'] as IconData,
                    color: s['color'] as Color,
                    size: 16,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      s['label'] as String,
                      style: TextStyle(
                        fontSize: 11,
                        color: Theme.of(
                          context,
                        ).colorScheme.onSurface.withValues(alpha: 0.6),
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                s['value'] as String,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: s['color'] as Color,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildBasicInfoSection() {
    return _cardWrapper(
      child: Column(
        children: [
          // Age
          TextFormField(
            controller: _ageController,
            keyboardType: TextInputType.number,
            style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
            decoration: _inputDecoration(
              label: 'Age',
              icon: Icons.cake_rounded,
            ),
            validator: (v) {
              if (v != null && v.isNotEmpty) {
                final age = int.tryParse(v);
                if (age == null || age < 1 || age > 150)
                  return 'Invalid age (1-150)';
              }
              return null;
            },
          ),
          const SizedBox(height: 14),

          // Gender
          DropdownButtonFormField<String>(
            initialValue: _selectedGender,
            dropdownColor: Theme.of(
              context,
            ).colorScheme.surfaceContainerHighest,
            style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
            decoration: _inputDecoration(
              label: 'Gender',
              icon: Icons.person_rounded,
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

          // Blood Group
          DropdownButtonFormField<String>(
            initialValue: _selectedBloodGroup,
            dropdownColor: Theme.of(
              context,
            ).colorScheme.surfaceContainerHighest,
            style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
            decoration: _inputDecoration(
              label: 'Blood Group',
              icon: Icons.bloodtype_rounded,
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

  Widget _buildBodyMetricsSection() {
    return _cardWrapper(
      child: Row(
        children: [
          Expanded(
            child: TextFormField(
              controller: _heightController,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
              decoration: _inputDecoration(
                label: 'Height (cm)',
                icon: Icons.height_rounded,
              ),
              validator: (v) {
                if (v != null && v.isNotEmpty) {
                  final h = double.tryParse(v);
                  if (h == null || h < 30 || h > 300) return '30-300';
                }
                return null;
              },
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: TextFormField(
              controller: _weightController,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
              decoration: _inputDecoration(
                label: 'Weight (kg)',
                icon: Icons.monitor_weight_rounded,
              ),
              validator: (v) {
                if (v != null && v.isNotEmpty) {
                  final w = double.tryParse(v);
                  if (w == null || w < 5 || w > 500) return '5-500';
                }
                return null;
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMedicalConditionsSection() {
    return _cardWrapper(
      child: TextFormField(
        controller: _conditionsController,
        maxLines: 4,
        style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
        decoration:
            _inputDecoration(
              label: 'Medical Conditions',
              icon: Icons.medical_information_rounded,
            ).copyWith(
              hintText: 'e.g. diabetes, hypertension, arthritis...',
              hintStyle: TextStyle(
                color: Theme.of(
                  context,
                ).colorScheme.onSurface.withValues(alpha: 0.3),
                fontSize: 13,
              ),
              alignLabelWithHint: true,
            ),
      ),
    );
  }

  Widget _buildEmergencyContactSection() {
    return _cardWrapper(
      child: TextFormField(
        controller: _emergencyContactController,
        keyboardType: TextInputType.phone,
        style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
        decoration: _inputDecoration(
          label: 'Emergency Contact Phone',
          icon: Icons.emergency_rounded,
        ),
        validator: (v) {
          if (v != null && v.isNotEmpty && v.length < 10)
            return 'Enter valid phone';
          return null;
        },
      ),
    );
  }

  Widget _cardWrapper({required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(
          context,
        ).colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.08),
        ),
      ),
      child: child,
    );
  }

  InputDecoration _inputDecoration({
    required String label,
    required IconData icon,
  }) {
    return InputDecoration(
      labelText: label,
      labelStyle: TextStyle(
        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
      ),
      prefixIcon: Icon(icon, color: const Color(0xFF4FC3F7), size: 20),
      filled: true,
      fillColor: Theme.of(context).colorScheme.surface.withValues(alpha: 0.5),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(
          color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.1),
        ),
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
