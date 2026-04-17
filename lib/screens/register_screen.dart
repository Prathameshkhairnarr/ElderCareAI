import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../services/health_profile_service.dart';
import '../widgets/page_transition.dart';
import 'dashboard_screen.dart';
import 'guardian_dashboard_screen.dart';
import 'child_dashboard_screen.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController(); // e.g. +919876543210
  final _pinController = TextEditingController();

  final _formKey = GlobalKey<FormState>();

  String _selectedRole = 'elder';
  String? _selectedGender;
  DateTime? _selectedDob;
  bool _isLoading = false;
  bool _obscurePin = true;
  String? _error;

  // Simple role list
  final List<String> _roles = ['elder', 'guardian', 'child'];
  final List<String> _genders = ['male', 'female', 'other'];

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _pinController.dispose();
    super.dispose();
  }

  Future<void> _handleRegister() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      String phone = _phoneController.text.trim();
      // Ensure +91 for consistency if needed, or just normalize in backend
      // But user asked for simple login/pass, so we accept what they type

      final success = await AuthService().register(
        name: _nameController.text.trim(),
        phone: phone,
        pin: _pinController.text.trim(),
        role: _selectedRole,
      );

      if (!mounted) return;

      if (success) {
        // Save DOB & gender to local health profile
        if (_selectedDob != null || _selectedGender != null) {
          try {
            final hpService = HealthProfileService();
            final current = await hpService.load();
            await hpService.save(current.copyWith(
              dateOfBirth: _selectedDob,
              gender: _selectedGender,
            ));
          } catch (_) {}
        }
        if (_selectedRole == 'guardian') {
          Navigator.of(context).pushAndRemoveUntil(
            PageTransition(page: const GuardianDashboardScreen()),
            (route) => false,
          );
        } else if (_selectedRole == 'child') {
          Navigator.of(context).pushAndRemoveUntil(
            PageTransition(page: const ChildDashboardScreen()),
            (route) => false,
          );
        } else {
          Navigator.of(context).pushAndRemoveUntil(
            PageTransition(page: const DashboardScreen()),
            (route) => false,
          );
        }
      } else {
        setState(() {
          _isLoading = false;
          _error = 'Registration failed. Try again.';
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _error = e.toString().replaceAll('Exception: ', '');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = MediaQuery.platformBrightnessOf(context) == Brightness.dark;
    final primaryColor = isDark ? const Color(0xFF4FC3F7) : const Color(0xFF2E7D32);

    final bgGradient = isDark
        ? const [Color(0xFF1A1A2E), Color(0xFF16213E), Color(0xFF0F3460)]
        : const [Color(0xFFF0FAF4), Color(0xFFE1F5E8), Color(0xFFC8EBD5)];
    final textPrimary = isDark ? Colors.white : const Color(0xFF11291A);
    final textSecondary = isDark ? Colors.white.withValues(alpha: 0.6) : const Color(0xFF1A3825).withValues(alpha: 0.7);
    final cardBg = isDark
        ? Colors.white.withValues(alpha: 0.05)
        : Colors.white;
    final cardBorder = isDark
        ? Colors.white.withValues(alpha: 0.1)
        : const Color(0xFFB9DEC8);
    final inputFill = isDark
        ? Colors.white.withValues(alpha: 0.06)
        : const Color(0xFFF5FCF8);
    final inputBorder = isDark
        ? Colors.white.withValues(alpha: 0.1)
        : const Color(0xFFC8E6D3);
    final inputLabelColor = isDark ? Colors.white.withValues(alpha: 0.5) : const Color(0xFF456D55);
    final iconSuffixColor = isDark ? Colors.white.withValues(alpha: 0.38) : const Color(0xFF679078);
    final dropdownColor = isDark ? const Color(0xFF16213E) : Colors.white;

    return Scaffold(
      appBar: AppBar(
        title: const Text('New Account'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: textPrimary),
        titleTextStyle: TextStyle(
          color: textPrimary,
          fontSize: 20,
          fontWeight: FontWeight.bold,
        ),
      ),
      backgroundColor: isDark ? const Color(0xFF1A1A2E) : const Color(0xFFF0FAF4),
      extendBodyBehindAppBar: true,
      body: Container(
        height: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: bgGradient,
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 600),
              child: Column(
                children: [
                  // Header
                  Icon(
                    Icons.person_add_outlined,
                    size: 64,
                    color: primaryColor,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Create Profile',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: textPrimary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Join ElderSaathi today',
                    style: TextStyle(
                      color: textSecondary,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 32),

                  // Form
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: cardBg,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: cardBorder),
                      boxShadow: isDark
                          ? null
                          : [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.06),
                                blurRadius: 20,
                                offset: const Offset(0, 8),
                              ),
                            ],
                    ),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _buildTextField(
                            controller: _nameController,
                            label: 'Full Name',
                            icon: Icons.person_rounded,
                            textColor: textPrimary,
                            inputFill: inputFill,
                            inputBorder: inputBorder,
                            inputLabelColor: inputLabelColor,
                            primaryColor: primaryColor,
                            validator: (v) =>
                                v?.isEmpty == true ? 'Required' : null,
                          ),
                          const SizedBox(height: 16),
                          _buildTextField(
                            controller: _phoneController,
                            label: 'Phone Number',
                            icon: Icons.phone_android_rounded,
                            keyboardType: TextInputType.phone,
                            hint: '9876543210',
                            textColor: textPrimary,
                            inputFill: inputFill,
                            inputBorder: inputBorder,
                            inputLabelColor: inputLabelColor,
                            primaryColor: primaryColor,
                            validator: (v) {
                              if (v == null || v.isEmpty) return 'Required';
                              if (v.length < 10) return 'Invalid phone';
                              return null;
                            },
                          ),
                          const SizedBox(height: 16),
                          _buildTextField(
                            controller: _pinController,
                            label: 'Create PIN (4-6 digits)',
                            icon: Icons.lock_rounded,
                            keyboardType: TextInputType.number,
                            obscureText: _obscurePin,
                            textColor: textPrimary,
                            inputFill: inputFill,
                            inputBorder: inputBorder,
                            inputLabelColor: inputLabelColor,
                            primaryColor: primaryColor,
                            suffix: IconButton(
                              icon: Icon(
                                _obscurePin
                                    ? Icons.visibility_off_rounded
                                    : Icons.visibility_rounded,
                                color: iconSuffixColor,
                              ),
                              onPressed: () =>
                                  setState(() => _obscurePin = !_obscurePin),
                            ),
                            validator: (v) {
                              if (v == null || v.length < 4)
                                return 'Min 4 digits';
                              return null;
                            },
                          ),
                          const SizedBox(height: 16),

                          // Date of Birth picker
                          GestureDetector(
                            onTap: () async {
                              final picked = await showDatePicker(
                                context: context,
                                initialDate: _selectedDob ?? DateTime(1960, 1, 1),
                                firstDate: DateTime(1900),
                                lastDate: DateTime.now(),
                                helpText: 'Select Date of Birth',
                              );
                              if (picked != null) {
                                setState(() => _selectedDob = picked);
                              }
                            },
                            child: Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 16,
                              ),
                              decoration: BoxDecoration(
                                color: inputFill,
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(color: inputBorder),
                              ),
                              child: Row(
                                children: [
                                    Icon(
                                      Icons.cake_rounded,
                                      color: primaryColor,
                                      size: 20,
                                    ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      _selectedDob != null
                                          ? 'DOB: ${_selectedDob!.day.toString().padLeft(2, '0')}/${_selectedDob!.month.toString().padLeft(2, '0')}/${_selectedDob!.year}  (${DateTime.now().year - _selectedDob!.year} yrs)'
                                          : 'Date of Birth',
                                      style: TextStyle(
                                        color: _selectedDob != null
                                            ? textPrimary
                                            : inputLabelColor,
                                        fontSize: 14,
                                      ),
                                    ),
                                  ),
                                  Icon(
                                    Icons.calendar_today_rounded,
                                    color: cs.onSurface.withValues(alpha: 0.4),
                                    size: 18,
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),

                          // Gender selector
                          DropdownButtonFormField<String>(
                            value: _selectedGender,
                            dropdownColor: dropdownColor,
                            style: TextStyle(color: textPrimary),
                            decoration: _inputDecoration(
                              label: 'Gender',
                              icon: Icons.person_rounded,
                              inputFill: inputFill,
                              inputBorder: inputBorder,
                              inputLabelColor: inputLabelColor,
                              primaryColor: primaryColor,
                            ),
                            items: _genders.map((g) {
                              return DropdownMenuItem(
                                value: g,
                                child: Text(
                                  g[0].toUpperCase() + g.substring(1),
                                  style: TextStyle(color: textPrimary),
                                ),
                              );
                            }).toList(),
                            onChanged: (val) {
                              if (val != null)
                                setState(() => _selectedGender = val);
                            },
                          ),
                          const SizedBox(height: 16),

                          // Role Selector
                          DropdownButtonFormField<String>(
                            value: _selectedRole,
                            dropdownColor: dropdownColor,
                            style: TextStyle(color: textPrimary),
                            decoration: _inputDecoration(
                              label: 'I am a...',
                              icon: Icons.groups_rounded,
                              inputFill: inputFill,
                              inputBorder: inputBorder,
                              inputLabelColor: inputLabelColor,
                              primaryColor: primaryColor,
                            ),
                            items: _roles.map((role) {
                              return DropdownMenuItem(
                                value: role,
                                child: Text(
                                  role[0].toUpperCase() + role.substring(1),
                                  style: TextStyle(color: textPrimary),
                                ),
                              );
                            }).toList(),
                            onChanged: (val) {
                              if (val != null)
                                setState(() => _selectedRole = val);
                            },
                          ),

                          if (_error != null) ...[
                            const SizedBox(height: 16),
                            Text(
                              _error!,
                              style: const TextStyle(
                                color: Colors.redAccent,
                                fontSize: 13,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],

                          const SizedBox(height: 32),
                          SizedBox(
                            height: 52,
                            child: ElevatedButton(
                              onPressed: _isLoading ? null : _handleRegister,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: primaryColor,
                                foregroundColor: isDark ? const Color(0xFF1A1A2E) : Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                              ),
                              child: _isLoading
                                  ? SizedBox(
                                      width: 24,
                                      height: 24,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2.5,
                                        color: isDark ? const Color(0xFF1A1A2E) : Colors.white,
                                      ),
                                    )
                                  : const Text(
                                      'Sign Up',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    required Color textColor,
    required Color inputFill,
    required Color inputBorder,
    required Color inputLabelColor,
    required Color primaryColor,
    TextInputType? keyboardType,
    bool obscureText = false,
    Widget? suffix,
    String? hint,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      obscureText: obscureText,
      style: TextStyle(color: textColor),
      validator: validator,
      decoration: _inputDecoration(
        label: label,
        icon: icon,
        suffix: suffix,
        hint: hint,
        inputFill: inputFill,
        inputBorder: inputBorder,
        inputLabelColor: inputLabelColor,
        primaryColor: primaryColor,
      ),
    );
  }

  InputDecoration _inputDecoration({
    required String label,
    required IconData icon,
    required Color inputFill,
    required Color inputBorder,
    required Color inputLabelColor,
    required Color primaryColor,
    Widget? suffix,
    String? hint,
  }) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      hintStyle: TextStyle(color: inputLabelColor.withValues(alpha: 0.6)),
      labelStyle: TextStyle(color: inputLabelColor),
      prefixIcon: Icon(icon, color: primaryColor, size: 20),
      suffixIcon: suffix,
      filled: true,
      fillColor: inputFill,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: inputBorder),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: primaryColor, width: 1.5),
      ),
    );
  }
}
