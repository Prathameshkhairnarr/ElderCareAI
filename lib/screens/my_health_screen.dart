import 'package:flutter/material.dart';
import '../services/api_service.dart';

class MyHealthScreen extends StatefulWidget {
  const MyHealthScreen({super.key});

  @override
  State<MyHealthScreen> createState() => _MyHealthScreenState();
}

class _MyHealthScreenState extends State<MyHealthScreen> {
  final _api = ApiService();
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

  Future<void> _loadData() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      final results = await Future.wait([
        _api.getHealthProfile(),
        _api.getHealthSummary(),
      ]);

      final profile = results[0];
      final summary = results[1];

      if (mounted) {
        if (profile != null && profile['id'] != 0) {
          _ageController.text = profile['age']?.toString() ?? '';
          _heightController.text = profile['height_cm']?.toString() ?? '';
          _weightController.text = profile['weight_kg']?.toString() ?? '';
          _conditionsController.text = profile['medical_conditions'] ?? '';
          _emergencyContactController.text = profile['emergency_contact'] ?? '';
          _selectedGender = profile['gender'];
          _selectedBloodGroup = profile['blood_group'];
        }
        setState(() {
          _vitalsSummary = summary;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    final data = <String, dynamic>{};
    if (_ageController.text.isNotEmpty)
      data['age'] = int.tryParse(_ageController.text);
    if (_selectedGender != null) data['gender'] = _selectedGender;
    if (_selectedBloodGroup != null) data['blood_group'] = _selectedBloodGroup;
    if (_heightController.text.isNotEmpty)
      data['height_cm'] = double.tryParse(_heightController.text);
    if (_weightController.text.isNotEmpty)
      data['weight_kg'] = double.tryParse(_weightController.text);
    data['medical_conditions'] = _conditionsController.text;
    if (_emergencyContactController.text.isNotEmpty)
      data['emergency_contact'] = _emergencyContactController.text;

    final result = await _api.saveHealthProfile(data);

    if (!mounted) return;
    setState(() => _isSaving = false);

    if (result != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(
            children: [
              Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
              SizedBox(width: 10),
              Text('Health profile saved successfully!'),
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
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(
            children: [
              Icon(Icons.error_outline, color: Colors.white, size: 20),
              SizedBox(width: 10),
              Text('Failed to save profile. Please try again.'),
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
            value: _selectedGender,
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
            value: _selectedBloodGroup,
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
