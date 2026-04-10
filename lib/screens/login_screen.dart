import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../widgets/page_transition.dart';
import 'dashboard_screen.dart';
import 'register_screen.dart';
import 'guardian_dashboard_screen.dart';
import 'reset_pin_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _phoneController = TextEditingController();
  final _pinController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  bool _obscurePin = true;
  String? _error;

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final user = await AuthService().login(
        _phoneController.text.trim(),
        _pinController.text.trim(),
      );

      if (!mounted) return;

      if (user.role == UserRole.guardian) {
        Navigator.of(context).pushAndRemoveUntil(
          PageTransition(page: const GuardianDashboardScreen()),
          (route) => false,
        );
      } else {
        Navigator.of(context).pushAndRemoveUntil(
          PageTransition(page: const DashboardScreen()),
          (route) => false,
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        // Strip "Exception: " prefix if present
        _error = e.toString().replaceAll('Exception: ', '');
      });
    }
  }

  @override
  void dispose() {
    _phoneController.dispose();
    _pinController.dispose();
    super.dispose();
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
        ? Colors.white.withValues(alpha: 0.07)
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
    final dividerColor = isDark ? Colors.white.withValues(alpha: 0.15) : const Color(0xFF11291A).withValues(alpha: 0.12);
    final iconSuffixColor = isDark ? Colors.white.withValues(alpha: 0.38) : const Color(0xFF679078);

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: bgGradient,
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: TweenAnimationBuilder<double>(
                tween: Tween(begin: 0.0, end: 1.0),
                duration: const Duration(milliseconds: 800),
                curve: Curves.easeOutCubic,
                builder: (context, value, child) {
                  return Opacity(
                    opacity: value,
                    child: Transform.translate(
                      offset: Offset(0, 40 * (1 - value)),
                      child: child,
                    ),
                  );
                },
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 420),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Logo area
                      ClipRRect(
                        borderRadius: BorderRadius.circular(24),
                        child: Image.asset(
                          'assets/images/Logo.png',
                          width: 100,
                          height: 100,
                          fit: BoxFit.cover,
                        ),
                      ),
                      const SizedBox(height: 24),
                      Text(
                        'ElderSaathi',
                        style: TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.w800,
                          color: textPrimary,
                          letterSpacing: -0.5,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Smart Protection for Your Loved Ones',
                        style: TextStyle(
                          fontSize: 14,
                          color: textSecondary,
                        ),
                      ),
                      const SizedBox(height: 48),

                      // Login form card
                      Container(
                        padding: const EdgeInsets.all(28),
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
                              Text(
                                'Sign In',
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w700,
                                  color: textPrimary.withValues(alpha: 0.9),
                                ),
                              ),
                              const SizedBox(height: 24),
                              TextFormField(
                                controller: _phoneController,
                                keyboardType: TextInputType.phone,
                                style: TextStyle(color: textPrimary),
                                decoration: _inputDecoration(
                                  label: 'Phone Number',
                                  icon: Icons.phone_android_rounded,
                                  inputFill: inputFill,
                                  inputBorder: inputBorder,
                                  inputLabelColor: inputLabelColor,
                                  primaryColor: primaryColor,
                                ),
                                validator: (v) {
                                  if (v == null || v.isEmpty) return 'Required';
                                  if (v.length < 10) return 'Enter valid phone';
                                  return null;
                                },
                              ),
                              const SizedBox(height: 16),
                              TextFormField(
                                controller: _pinController,
                                obscureText: _obscurePin,
                                style: TextStyle(color: textPrimary),
                                decoration: _inputDecoration(
                                  label: 'PIN',
                                  icon: Icons.lock_rounded,
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
                                      size: 20,
                                    ),
                                    onPressed: () => setState(
                                      () => _obscurePin = !_obscurePin,
                                    ),
                                  ),
                                ),
                                validator: (v) {
                                  if (v == null || v.isEmpty) return 'Required';
                                  if (v.length < 4) return 'Min 4 digits';
                                  return null;
                                },
                              ),
                              Align(
                                alignment: Alignment.centerRight,
                                child: TextButton(
                                  onPressed: () {
                                    Navigator.of(context).push(
                                      PageTransition(
                                        page: const ResetPinScreen(),
                                      ),
                                    );
                                  },
                                  style: TextButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    minimumSize: Size.zero,
                                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                  ),
                                  child: Text(
                                    'Forgot PIN?',
                                    style: TextStyle(
                                      color: primaryColor,
                                      fontWeight: FontWeight.w600,
                                      fontSize: 13,
                                    ),
                                  ),
                                ),
                              ),
                              if (_error != null) ...[
                                const SizedBox(height: 12),
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: Colors.red.withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Row(
                                    children: [
                                      const Icon(
                                        Icons.error_outline,
                                        color: Colors.redAccent,
                                        size: 18,
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          _error!,
                                          style: const TextStyle(
                                            color: Colors.redAccent,
                                            fontSize: 13,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                              const SizedBox(height: 24),
                              SizedBox(
                                height: 52,
                                child: ElevatedButton(
                                  onPressed: _isLoading ? null : _login,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: primaryColor,
                                    foregroundColor: isDark ? const Color(0xFF1A1A2E) : Colors.white,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                    elevation: 0,
                                  ),
                                  child: _isLoading
                                      ? SizedBox(
                                          width: 22,
                                          height: 22,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2.5,
                                            color: isDark ? const Color(0xFF1A1A2E) : Colors.white,
                                          ),
                                        )
                                      : const Text(
                                          'Sign In',
                                          style: TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                ),
                              ),
                              const SizedBox(height: 16),
                              Row(
                                children: [
                                  Expanded(
                                    child: Divider(color: dividerColor),
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                    ),
                                    child: Text(
                                      'OR',
                                      style: TextStyle(
                                        color: cs.onSurface.withValues(alpha: 0.4),
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                  Expanded(
                                    child: Divider(color: dividerColor),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),
                              SizedBox(
                                height: 52,
                                child: OutlinedButton.icon(
                                  onPressed: () {
                                    Navigator.of(context).push(
                                      PageTransition(
                                        page: const RegisterScreen(),
                                      ),
                                    );
                                  },
                                  icon: const Icon(
                                    Icons.person_add_rounded,
                                    size: 20,
                                  ),
                                  label: const Text(
                                    'Create Account',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: primaryColor,
                                    side: BorderSide(
                                      color: primaryColor.withValues(alpha: 0.5),
                                      width: 1.5,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(14),
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
        ),
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
  }) {
    return InputDecoration(
      labelText: label,
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
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Colors.redAccent),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
    );
  }
}
