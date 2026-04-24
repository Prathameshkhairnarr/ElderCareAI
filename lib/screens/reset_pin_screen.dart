import 'package:flutter/material.dart';
import '../services/auth_service.dart';

class ResetPinScreen extends StatefulWidget {
  const ResetPinScreen({super.key});

  @override
  State<ResetPinScreen> createState() => _ResetPinScreenState();
}

class _ResetPinScreenState extends State<ResetPinScreen> {
  final _phoneController = TextEditingController();
  final _otpController = TextEditingController();
  final _pinController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  bool _isLoading = false;
  bool _obscurePin = true;
  String? _error;

  // ── 2-Step State ──
  bool _otpSent = false;       // true = Step 2 (OTP + new PIN)
  bool _isFallback = false;    // true = Fast2SMS not available
  String _otpMessage = '';     // server message to show user

  // ── Step 1: Send OTP ──
  Future<void> _sendOtp() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final result = await AuthService().sendOtp(
        _phoneController.text.trim(),
      );

      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _otpSent = true;
        _isFallback = result.fallback;
        _otpMessage = result.message;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _error = e.toString().replaceAll('Exception: ', '');
      });
    }
  }

  // ── Step 2: Verify OTP + Reset PIN ──
  Future<void> _verifyAndReset() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      await AuthService().verifyOtpAndResetPin(
        phone: _phoneController.text.trim(),
        otp: _otpController.text.trim(),
        newPin: _pinController.text.trim(),
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(
            children: [
              Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
              SizedBox(width: 10),
              Text('PIN reset successfully! You can now login.'),
            ],
          ),
          behavior: SnackBarBehavior.floating,
          backgroundColor: const Color(0xFF26A69A),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );

      Navigator.of(context).pop(); // Go back to login
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _error = e.toString().replaceAll('Exception: ', '');
      });
    }
  }

  // ── Go back to Step 1 ──
  void _goBackToStep1() {
    setState(() {
      _otpSent = false;
      _isFallback = false;
      _otpMessage = '';
      _otpController.clear();
      _pinController.clear();
      _error = null;
    });
  }

  @override
  void dispose() {
    _phoneController.dispose();
    _otpController.dispose();
    _pinController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A1A2E),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white),
          onPressed: () {
            if (_otpSent) {
              _goBackToStep1();
            } else {
              Navigator.pop(context);
            }
          },
        ),
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0.0, end: 1.0),
              duration: const Duration(milliseconds: 600),
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
                    // ── Icon ──
                    Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        color: const Color(0xFF4FC3F7).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(
                          color: const Color(0xFF4FC3F7).withValues(alpha: 0.3),
                        ),
                      ),
                      child: Icon(
                        _otpSent ? Icons.sms_rounded : Icons.lock_reset_rounded,
                        size: 40,
                        color: const Color(0xFF4FC3F7),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // ── Title ──
                    Text(
                      _otpSent ? 'Enter OTP' : 'Reset PIN',
                      style: const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 8),

                    // ── Subtitle ──
                    Text(
                      _otpSent
                          ? 'Enter the OTP and your new PIN.'
                          : 'Enter your registered phone number\nto receive an OTP.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.white.withValues(alpha: 0.6),
                        height: 1.5,
                      ),
                    ),

                    // ── Fallback Hint (dev mode) ──
                    if (_otpSent && _isFallback) ...[
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          color: Colors.amber.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.amber.withValues(alpha: 0.3)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.info_outline_rounded, color: Colors.amber, size: 18),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _otpMessage.isNotEmpty
                                    ? _otpMessage
                                    : 'Dev mode: Check server console for OTP.',
                                style: const TextStyle(
                                  color: Colors.amber,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],

                    const SizedBox(height: 48),

                    // ── Form Card ──
                    Container(
                      padding: const EdgeInsets.all(28),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.07),
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.1),
                        ),
                      ),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            if (!_otpSent) ...[
                              // ══════════════ STEP 1: Phone Number ══════════════
                              TextFormField(
                                controller: _phoneController,
                                keyboardType: TextInputType.phone,
                                style: const TextStyle(color: Colors.white),
                                decoration: _inputDecoration(
                                  label: 'Phone Number',
                                  icon: Icons.phone_android_rounded,
                                ),
                                validator: (v) {
                                  if (v == null || v.isEmpty) return 'Required';
                                  if (v.length < 10) return 'Enter valid phone';
                                  return null;
                                },
                              ),
                            ] else ...[
                              // ══════════════ STEP 2: OTP + New PIN ══════════════

                              // Show phone (read-only)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.05),
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(Icons.phone_android_rounded, color: Color(0xFF4FC3F7), size: 18),
                                    const SizedBox(width: 10),
                                    Text(
                                      _phoneController.text.trim(),
                                      style: TextStyle(
                                        color: Colors.white.withValues(alpha: 0.7),
                                        fontSize: 14,
                                      ),
                                    ),
                                    const Spacer(),
                                    GestureDetector(
                                      onTap: _goBackToStep1,
                                      child: Text(
                                        'Change',
                                        style: TextStyle(
                                          color: const Color(0xFF4FC3F7).withValues(alpha: 0.8),
                                          fontSize: 13,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 16),

                              // OTP Field
                              TextFormField(
                                controller: _otpController,
                                keyboardType: TextInputType.number,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 22,
                                  letterSpacing: 8,
                                  fontWeight: FontWeight.w700,
                                ),
                                textAlign: TextAlign.center,
                                maxLength: 6,
                                decoration: _inputDecoration(
                                  label: 'Enter OTP',
                                  icon: Icons.lock_clock_rounded,
                                ).copyWith(counterText: ''),
                                validator: (v) {
                                  if (v == null || v.isEmpty) return 'Enter OTP';
                                  if (v.length < 4) return 'OTP too short';
                                  return null;
                                },
                              ),
                              const SizedBox(height: 16),

                              // New PIN Field
                              TextFormField(
                                controller: _pinController,
                                obscureText: _obscurePin,
                                style: const TextStyle(color: Colors.white),
                                decoration: _inputDecoration(
                                  label: 'New PIN',
                                  icon: Icons.lock_rounded,
                                  suffix: IconButton(
                                    icon: Icon(
                                      _obscurePin
                                          ? Icons.visibility_off_rounded
                                          : Icons.visibility_rounded,
                                      color: Colors.white38,
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
                            ],

                            // ── Error Display ──
                            if (_error != null) ...[
                              const SizedBox(height: 16),
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

                            // ── Action Button ──
                            SizedBox(
                              height: 52,
                              child: ElevatedButton(
                                onPressed: _isLoading
                                    ? null
                                    : (_otpSent ? _verifyAndReset : _sendOtp),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF4FC3F7),
                                  foregroundColor: const Color(0xFF1A1A2E),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  elevation: 0,
                                ),
                                child: _isLoading
                                    ? const SizedBox(
                                        width: 22,
                                        height: 22,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2.5,
                                          color: Color(0xFF1A1A2E),
                                        ),
                                      )
                                    : Text(
                                        _otpSent ? 'Verify & Reset PIN' : 'Send OTP',
                                        style: const TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                              ),
                            ),

                            // ── Resend OTP ──
                            if (_otpSent) ...[
                              const SizedBox(height: 16),
                              Center(
                                child: TextButton(
                                  onPressed: _isLoading ? null : _sendOtp,
                                  child: Text(
                                    'Resend OTP',
                                    style: TextStyle(
                                      color: const Color(0xFF4FC3F7).withValues(alpha: 0.8),
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ),
                            ],
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
    );
  }

  InputDecoration _inputDecoration({
    required String label,
    required IconData icon,
    Widget? suffix,
  }) {
    return InputDecoration(
      labelText: label,
      labelStyle: TextStyle(color: Colors.white.withValues(alpha: 0.5)),
      prefixIcon: Icon(icon, color: const Color(0xFF4FC3F7), size: 20),
      suffixIcon: suffix,
      filled: true,
      fillColor: Colors.white.withValues(alpha: 0.06),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
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
