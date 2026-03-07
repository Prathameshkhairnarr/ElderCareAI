import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../services/auth_service.dart';
import '../../services/settings_service.dart';
import '../../services/health_profile_service.dart';
import '../../widgets/page_transition.dart';
import '../login_screen.dart';
import '../health_profile_view_screen.dart';
import '../settings/contacts_screen.dart';

// ═══════════════════════════════════════════════════════════════
//  PROFILE SCREEN — Central hub for user profile & app settings
// ═══════════════════════════════════════════════════════════════

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _auth = AuthService();
  final _settings = SettingsService();
  final _healthProfile = HealthProfileService();
  final _imagePicker = ImagePicker();

  String? _profileImagePath;

  @override
  void initState() {
    super.initState();
    _settings.addListener(_onSettingsChanged);
    _healthProfile.addListener(_onSettingsChanged);
    _loadProfileImage();
  }

  @override
  void dispose() {
    _settings.removeListener(_onSettingsChanged);
    _healthProfile.removeListener(_onSettingsChanged);
    super.dispose();
  }

  void _onSettingsChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _loadProfileImage() async {
    final prefs = await SharedPreferences.getInstance();
    String? userPhone = _auth.currentUser?.phone;
    
    // Fallback: Read from SharedPreferences directly if currentUser isn't ready
    if (userPhone == null || userPhone.isEmpty) {
      final userDataStr = prefs.getString('user_data');
      if (userDataStr != null) {
        final userData = jsonDecode(userDataStr) as Map<String, dynamic>;
        userPhone = userData['phone'] as String?;
      }
    }

    if (userPhone != null && userPhone.isNotEmpty) {
      final path = prefs.getString('profile_image_$userPhone');
      if (path != null && File(path).existsSync() && mounted) {
        setState(() => _profileImagePath = path);
      }
    }
  }

  Future<void> _saveProfileImage(String path) async {
    final prefs = await SharedPreferences.getInstance();
    String? userPhone = _auth.currentUser?.phone;
    
    // Fallback
    if (userPhone == null || userPhone.isEmpty) {
      final userDataStr = prefs.getString('user_data');
      if (userDataStr != null) {
        final userData = jsonDecode(userDataStr) as Map<String, dynamic>;
        userPhone = userData['phone'] as String?;
      }
    }

    if (userPhone != null && userPhone.isNotEmpty) {
      await prefs.setString('profile_image_$userPhone', path);
    }
  }

  Future<String?> _pickProfileImage({bool saveImmediately = true}) async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final cs = Theme.of(ctx).colorScheme;
        return Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: cs.surface,
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(28),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: cs.onSurface.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'Choose Photo',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: InkWell(
                      onTap: () => Navigator.pop(ctx, ImageSource.camera),
                      borderRadius: BorderRadius.circular(14),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 20),
                        decoration: BoxDecoration(
                          color: cs.surfaceContainerHighest.withValues(
                            alpha: 0.3,
                          ),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Column(
                          children: [
                            Icon(
                              Icons.camera_alt_rounded,
                              color: Color(0xFF4FC3F7),
                              size: 32,
                            ),
                            SizedBox(height: 8),
                            Text(
                              'Camera',
                              style: TextStyle(fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: InkWell(
                      onTap: () => Navigator.pop(ctx, ImageSource.gallery),
                      borderRadius: BorderRadius.circular(14),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 20),
                        decoration: BoxDecoration(
                          color: cs.surfaceContainerHighest.withValues(
                            alpha: 0.3,
                          ),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Column(
                          children: [
                            Icon(
                              Icons.photo_library_rounded,
                              color: Color(0xFF7C4DFF),
                              size: 32,
                            ),
                            SizedBox(height: 8),
                            Text(
                              'Gallery',
                              style: TextStyle(fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );

    if (source == null) return null;

    final picked = await _imagePicker.pickImage(
      source: source,
      maxWidth: 512,
      maxHeight: 512,
      imageQuality: 80,
    );

    if (picked != null && mounted) {
      if (saveImmediately) {
        await _saveProfileImage(picked.path);
        setState(() => _profileImagePath = picked.path);
      }
      return picked.path;
    }
    return null;
  }

  // ── Logout with confirmation ──
  void _logout() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Logout'),
        content: const Text('Are you sure you want to logout?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              _auth.logout();
              Navigator.of(context).pushAndRemoveUntil(
                PageTransition(page: const LoginScreen()),
                (route) => false,
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text('Logout'),
          ),
        ],
      ),
    );
  }

  // ── Dialogs ──
  void _showTermsDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Terms of Service'),
        content: const SingleChildScrollView(
          child: Text(
            'ElderCare AI Terms of Service\n\n'
            '1. Acceptance of Terms\n'
            'By using this app, you agree to these terms.\n\n'
            '2. Service Description\n'
            'ElderCare AI provides scam detection and emergency alert features.\n\n'
            '3. User Responsibilities\n'
            '- Provide accurate information\n'
            '- Use the app responsibly\n'
            '- Maintain account security\n\n'
            '4. Limitations\n'
            'The app provides assistance but is not a substitute for professional advice.\n\n'
            '5. Privacy\n'
            'See our Privacy Policy for data handling practices.\n\n'
            'Last updated: February 2026',
            style: TextStyle(fontSize: 13, height: 1.5),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _showPrivacyDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Privacy Policy'),
        content: const SingleChildScrollView(
          child: Text(
            'ElderCare AI Privacy Policy\n\n'
            '1. Data Collection\n'
            'We collect:\n'
            '- Phone number for authentication\n'
            '- SMS messages you choose to analyze\n'
            '- Emergency contact information\n'
            '- Health vitals you choose to track\n\n'
            '2. Data Usage\n'
            '- Scam detection and risk analysis\n'
            '- Emergency alert services\n'
            '- App functionality improvement\n\n'
            '3. Data Storage\n'
            'Data is stored securely and encrypted.\n\n'
            '4. Data Sharing\n'
            'We do not sell your data. Data is only shared:\n'
            '- With emergency contacts during SOS\n'
            '- As required by law\n\n'
            '5. Your Rights\n'
            'You can request data deletion at any time.\n\n'
            'Last updated: February 2026',
            style: TextStyle(fontSize: 13, height: 1.5),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  // ── Theme helpers ──
  String _themeName(ThemeMode mode) {
    switch (mode) {
      case ThemeMode.light:
        return 'Light';
      case ThemeMode.dark:
        return 'Dark';
      case ThemeMode.system:
        return 'System';
    }
  }

  IconData _themeIcon(ThemeMode mode) {
    switch (mode) {
      case ThemeMode.light:
        return Icons.wb_sunny_rounded;
      case ThemeMode.dark:
        return Icons.dark_mode_rounded;
      case ThemeMode.system:
        return Icons.settings_brightness_rounded;
    }
  }

  // ── Edit Profile bottom sheet ──
  void _showEditProfileSheet({String? tempImagePath}) {
    final user = _auth.currentUser;
    final profile = _healthProfile.profile;
    
    // Use temp image if provided, otherwise fallback to existing
    String? currentImage = tempImagePath ?? _profileImagePath;
    final nameCtrl = TextEditingController(text: user?.name ?? '');
    final phoneCtrl = TextEditingController(text: user?.phone ?? '');
    DateTime? selectedDob = profile.dateOfBirth;
    String? selectedGender = profile.gender;
    final genders = ['male', 'female', 'other'];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            final cs = Theme.of(ctx).colorScheme;
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(ctx).viewInsets.bottom,
              ),
              child: Container(
                padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
                decoration: BoxDecoration(
                  color: cs.surface,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(28),
                  ),
                ),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Handle bar
                      Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: cs.onSurface.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      const SizedBox(height: 20),
                      const Text(
                        'Edit Profile',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Profile Image
                      GestureDetector(
                        onTap: () async {
                          Navigator.pop(ctx);
                          final path = await _pickProfileImage(saveImmediately: false);
                          if (mounted) {
                            _showEditProfileSheet(tempImagePath: path ?? currentImage);
                          }
                        },
                        child: Stack(
                          children: [
                            Container(
                              width: 80,
                              height: 80,
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [
                                    Color(0xFF4FC3F7),
                                    Color(0xFF0288D1),
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(24),
                                image: currentImage != null
                                    ? DecorationImage(
                                        image: FileImage(
                                          File(currentImage),
                                        ),
                                        fit: BoxFit.cover,
                                      )
                                    : null,
                              ),
                              child: currentImage == null
                                  ? Center(
                                      child: Text(
                                        (user?.name ?? 'U')[0].toUpperCase(),
                                        style: const TextStyle(
                                          fontSize: 30,
                                          fontWeight: FontWeight.w700,
                                          color: Colors.white,
                                        ),
                                      ),
                                    )
                                  : null,
                            ),
                            Positioned(
                              bottom: 0,
                              right: 0,
                              child: Container(
                                padding: const EdgeInsets.all(4),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF4FC3F7),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: cs.surface,
                                    width: 2,
                                  ),
                                ),
                                child: const Icon(
                                  Icons.camera_alt_rounded,
                                  size: 14,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Name field
                      TextField(
                        controller: nameCtrl,
                        style: TextStyle(color: cs.onSurface),
                        decoration: InputDecoration(
                          labelText: 'Full Name',
                          prefixIcon: const Icon(Icons.person_rounded),
                          filled: true,
                          fillColor: cs.surfaceContainerHighest.withValues(
                            alpha: 0.3,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: BorderSide.none,
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),

                      // Phone field
                      TextField(
                        controller: phoneCtrl,
                        keyboardType: TextInputType.phone,
                        style: TextStyle(color: cs.onSurface),
                        decoration: InputDecoration(
                          labelText: 'Phone Number',
                          prefixIcon: const Icon(Icons.phone_rounded),
                          filled: true,
                          fillColor: cs.surfaceContainerHighest.withValues(
                            alpha: 0.3,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: BorderSide.none,
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),

                      // Date of Birth picker
                      GestureDetector(
                        onTap: () async {
                          final picked = await showDatePicker(
                            context: ctx,
                            initialDate: selectedDob ?? DateTime(1960, 1, 1),
                            firstDate: DateTime(1900),
                            lastDate: DateTime.now(),
                            helpText: 'Select Date of Birth',
                          );
                          if (picked != null) {
                            setSheetState(() => selectedDob = picked);
                          }
                        },
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 16,
                          ),
                          decoration: BoxDecoration(
                            color: cs.surfaceContainerHighest.withValues(
                              alpha: 0.3,
                            ),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.cake_rounded),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Date of Birth',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: cs.onSurface.withValues(
                                          alpha: 0.6,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      selectedDob != null
                                          ? '${selectedDob!.day.toString().padLeft(2, '0')}/${selectedDob!.month.toString().padLeft(2, '0')}/${selectedDob!.year}'
                                          : 'Tap to select',
                                      style: TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w600,
                                        color: selectedDob != null
                                            ? cs.onSurface
                                            : cs.onSurface.withValues(
                                                alpha: 0.4,
                                              ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              if (selectedDob != null)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF4FC3F7).withValues(
                                      alpha: 0.15,
                                    ),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    '${DateTime.now().year - selectedDob!.year} yrs',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                      color: Color(0xFF4FC3F7),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),

                      // Gender dropdown
                      DropdownButtonFormField<String>(
                        value: selectedGender,
                        dropdownColor: cs.surfaceContainerHighest,
                        style: TextStyle(color: cs.onSurface),
                        decoration: InputDecoration(
                          labelText: 'Gender',
                          prefixIcon: Icon(
                            selectedGender == 'female'
                                ? Icons.female_rounded
                                : selectedGender == 'male'
                                    ? Icons.male_rounded
                                    : Icons.person_rounded,
                          ),
                          filled: true,
                          fillColor: cs.surfaceContainerHighest.withValues(
                            alpha: 0.3,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: BorderSide.none,
                          ),
                        ),
                        items: genders
                            .map(
                              (g) => DropdownMenuItem(
                                value: g,
                                child: Text(
                                  g[0].toUpperCase() + g.substring(1),
                                ),
                              ),
                            )
                            .toList(),
                        onChanged: (val) =>
                            setSheetState(() => selectedGender = val),
                      ),
                      const SizedBox(height: 24),

                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton(
                          onPressed: () async {
                            // Save image if changed
                            if (currentImage != null && currentImage != _profileImagePath) {
                              await _saveProfileImage(currentImage);
                              _profileImagePath = currentImage;
                            }

                            // Save DOB and gender to health profile
                            final updated = profile.copyWith(
                              dateOfBirth: selectedDob,
                              gender: selectedGender,
                            );
                            await _healthProfile.save(updated);

                            if (!ctx.mounted) return;
                            Navigator.pop(ctx);

                            if (!mounted) return;
                            setState(() {}); // Refresh profile header
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: const Row(
                                  children: [
                                    Icon(
                                      Icons.check_circle_rounded,
                                      color: Colors.white,
                                      size: 20,
                                    ),
                                    SizedBox(width: 10),
                                    Text('Profile updated!'),
                                  ],
                                ),
                                behavior: SnackBarBehavior.floating,
                                backgroundColor: const Color(0xFF26A69A),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                            );
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF4FC3F7),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                            elevation: 0,
                          ),
                          child: const Text(
                            'Save Changes',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
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
      },
    );
  }

  // ══════════════════════════════════════════════════════
  //  BUILD
  // ══════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final user = _auth.currentUser;
    final profile = _healthProfile.profile;
    final completeness = profile.completeness;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
        centerTitle: true,
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Profile Header ──
            _buildProfileHeader(user, cs),
            const SizedBox(height: 16),

            // ── Profile Completeness Banner ──
            if (completeness < 100) ...[
              _buildCompletenessBanner(completeness, cs),
              const SizedBox(height: 20),
            ] else
              const SizedBox(height: 12),

            // ── PERSONAL ──
            _buildSectionTitle('Personal', cs),
            const SizedBox(height: 10),
            _buildActionTile(
              icon: Icons.person_rounded,
              title: 'Edit Profile',
              subtitle: 'Name, age, gender & photo',
              color: const Color(0xFF4FC3F7),
              cs: cs,
              onTap: _showEditProfileSheet,
            ),
            _buildActionTile(
              icon: Icons.favorite_rounded,
              title: 'Health Profile',
              subtitle: 'Blood group, body metrics & conditions',
              color: const Color(0xFFEC407A),
              cs: cs,
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const HealthProfileViewScreen(
                    showEditableOnly: true,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),

            // ── APP PREFERENCES ──
            _buildSectionTitle('App Preferences', cs),
            const SizedBox(height: 10),
            _buildThemeSelector(cs),
            const SizedBox(height: 8),
            _buildFontSizeControl(cs),
            const SizedBox(height: 8),
            _buildToggleTile(
              icon: Icons.notifications_rounded,
              title: 'Push Notifications',
              subtitle: 'Receive scam alerts and updates',
              value: _settings.notifications,
              color: const Color(0xFF42A5F5),
              cs: cs,
              onChanged: (v) => _settings.toggleNotifications(v),
            ),
            const SizedBox(height: 24),

            // ── SAFETY ──
            _buildSectionTitle('Safety', cs),
            const SizedBox(height: 10),
            _buildActionTile(
              icon: Icons.contacts_rounded,
              title: 'Emergency Contacts',
              subtitle: 'Manage your emergency contacts',
              color: const Color(0xFFEF5350),
              cs: cs,
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ContactsScreen()),
              ),
            ),
            _buildToggleTile(
              icon: Icons.record_voice_over_rounded,
              title: 'Voice Alerts',
              subtitle: 'Read scam warnings aloud',
              value: _settings.voiceFeedback,
              color: const Color(0xFFFF7043),
              cs: cs,
              onChanged: (v) => _settings.toggleVoiceFeedback(v),
            ),
            _buildToggleTile(
              icon: Icons.vibration_rounded,
              title: 'Shake to SOS',
              subtitle: 'Shake phone vigorously to trigger SOS',
              value: _settings.shakeSosEnabled,
              color: const Color(0xFFFFB300),
              cs: cs,
              onChanged: (v) => _settings.toggleShakeSos(v),
            ),
            const SizedBox(height: 24),

            // ── ABOUT ──
            _buildSectionTitle('About', cs),
            const SizedBox(height: 10),
            _buildActionTile(
              icon: Icons.info_outline_rounded,
              title: 'App Version',
              subtitle: '1.0.0 (Beta)',
              color: const Color(0xFF78909C),
              cs: cs,
              onTap: () {},
              showChevron: false,
            ),
            _buildActionTile(
              icon: Icons.description_rounded,
              title: 'Terms of Service',
              subtitle: 'View legal terms',
              color: const Color(0xFF78909C),
              cs: cs,
              onTap: _showTermsDialog,
            ),
            _buildActionTile(
              icon: Icons.privacy_tip_rounded,
              title: 'Privacy Policy',
              subtitle: 'How we handle your data',
              color: const Color(0xFF78909C),
              cs: cs,
              onTap: _showPrivacyDialog,
            ),
            const SizedBox(height: 28),

            // ── LOGOUT ──
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton.icon(
                onPressed: _logout,
                icon: const Icon(Icons.logout_rounded),
                label: const Text(
                  'Logout',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red.withValues(alpha: 0.1),
                  foregroundColor: Colors.redAccent,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                    side: BorderSide(color: Colors.red.withValues(alpha: 0.2)),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  // ══════════════════════════════════════════════════════
  //  PROFILE COMPLETENESS BANNER
  // ══════════════════════════════════════════════════════

  Widget _buildCompletenessBanner(int completeness, ColorScheme cs) {
    return GestureDetector(
      onTap: _showEditProfileSheet,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              const Color(0xFFFFB300).withValues(alpha: 0.12),
              const Color(0xFFFFA000).withValues(alpha: 0.06),
            ],
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: const Color(0xFFFFB300).withValues(alpha: 0.3),
          ),
        ),
        child: Row(
          children: [
            // Circular progress
            SizedBox(
              width: 44,
              height: 44,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  CircularProgressIndicator(
                    value: completeness / 100,
                    strokeWidth: 4,
                    backgroundColor:
                        const Color(0xFFFFB300).withValues(alpha: 0.2),
                    valueColor: const AlwaysStoppedAnimation(Color(0xFFFFB300)),
                  ),
                  Text(
                    '$completeness%',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFFFFB300),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Complete your profile',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Add missing details for better health insights',
                    style: TextStyle(
                      fontSize: 12,
                      color: cs.onSurface.withValues(alpha: 0.5),
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              color: cs.onSurface.withValues(alpha: 0.3),
            ),
          ],
        ),
      ),
    );
  }

  // ══════════════════════════════════════════════════════
  //  PROFILE HEADER
  // ══════════════════════════════════════════════════════

  Widget _buildProfileHeader(UserProfile? user, ColorScheme cs) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: const Duration(milliseconds: 600),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) => Opacity(
        opacity: value,
        child: Transform.translate(
          offset: Offset(0, 20 * (1 - value)),
          child: child,
        ),
      ),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          gradient: LinearGradient(
            colors: [
              const Color(0xFF4FC3F7).withValues(alpha: 0.12),
              cs.surfaceContainerHighest,
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          border: Border.all(
            color: const Color(0xFF4FC3F7).withValues(alpha: 0.2),
            width: 1.5,
          ),
        ),
        child: Column(
          children: [
            // Avatar with image support
            GestureDetector(
              onTap: _pickProfileImage,
              child: Stack(
                children: [
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      gradient: _profileImagePath == null
                          ? const LinearGradient(
                              colors: [Color(0xFF4FC3F7), Color(0xFF0288D1)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            )
                          : null,
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(
                          color:
                              const Color(0xFF4FC3F7).withValues(alpha: 0.3),
                          blurRadius: 16,
                          offset: const Offset(0, 6),
                        ),
                      ],
                      image: _profileImagePath != null
                          ? DecorationImage(
                              image: FileImage(File(_profileImagePath!)),
                              fit: BoxFit.cover,
                            )
                          : null,
                    ),
                    child: _profileImagePath == null
                        ? Center(
                            child: Text(
                              (user?.name ?? 'U')[0].toUpperCase(),
                              style: const TextStyle(
                                fontSize: 34,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                            ),
                          )
                        : null,
                  ),
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: const Color(0xFF4FC3F7),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: cs.surface, width: 2),
                      ),
                      child: const Icon(
                        Icons.camera_alt_rounded,
                        size: 14,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Name
            Text(
              user?.name ?? 'User',
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 4),

            // Phone
            Text(
              user?.phone ?? 'N/A',
              style: TextStyle(
                fontSize: 14,
                color: cs.onSurface.withValues(alpha: 0.5),
              ),
            ),
            const SizedBox(height: 10),

            // Role badge
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 5,
              ),
              decoration: BoxDecoration(
                color: const Color(0xFF4FC3F7).withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                user?.role.name.toUpperCase() ?? 'USER',
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF4FC3F7),
                  letterSpacing: 1,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ══════════════════════════════════════════════════════
  //  SECTION TITLE
  // ══════════════════════════════════════════════════════

  Widget _buildSectionTitle(String title, ColorScheme cs) {
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w700,
          color: cs.onSurface.withValues(alpha: 0.5),
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  // ══════════════════════════════════════════════════════
  //  THEME SELECTOR
  // ══════════════════════════════════════════════════════

  Widget _buildThemeSelector(ColorScheme cs) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                _themeIcon(_settings.themeMode),
                color: const Color(0xFF7C4DFF),
                size: 22,
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Theme',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      'Choose your preferred look',
                      style: TextStyle(fontSize: 12),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              for (final mode in ThemeMode.values) ...[
                Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(
                      right: mode != ThemeMode.system ? 8 : 0,
                    ),
                    child: _buildThemeOption(mode, cs),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildThemeOption(ThemeMode mode, ColorScheme cs) {
    final isSelected = _settings.themeMode == mode;
    return GestureDetector(
      onTap: () => _settings.updateThemeMode(mode),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xFF7C4DFF).withValues(alpha: 0.15)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected
                ? const Color(0xFF7C4DFF)
                : cs.outline.withValues(alpha: 0.15),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Column(
          children: [
            Icon(
              _themeIcon(mode),
              size: 20,
              color: isSelected
                  ? const Color(0xFF7C4DFF)
                  : cs.onSurface.withValues(alpha: 0.5),
            ),
            const SizedBox(height: 4),
            Text(
              _themeName(mode),
              style: TextStyle(
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color: isSelected
                    ? const Color(0xFF7C4DFF)
                    : cs.onSurface.withValues(alpha: 0.6),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ══════════════════════════════════════════════════════
  //  FONT SIZE SLIDER
  // ══════════════════════════════════════════════════════

  Widget _buildFontSizeControl(ColorScheme cs) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.text_fields_rounded,
                color: Color(0xFF42A5F5),
                size: 22,
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Font Size',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      'Adjust text size across the app',
                      style: TextStyle(fontSize: 12),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFF42A5F5).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '${(_settings.fontScale * 100).toInt()}%',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF42A5F5),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              const Text(
                'A',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
              ),
              Expanded(
                child: SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    activeTrackColor: const Color(0xFF42A5F5),
                    inactiveTrackColor: const Color(0xFF42A5F5).withValues(
                      alpha: 0.2,
                    ),
                    thumbColor: const Color(0xFF42A5F5),
                    overlayColor: const Color(0xFF42A5F5).withValues(
                      alpha: 0.1,
                    ),
                    trackHeight: 4,
                  ),
                  child: Slider(
                    value: _settings.fontScale,
                    min: 0.8,
                    max: 1.4,
                    divisions: 6,
                    onChanged: (value) => _settings.updateFontScale(value),
                  ),
                ),
              ),
              const Text(
                'A',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
              ),
            ],
          ),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: cs.surface,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              'Preview: This is how your text will look',
              style: TextStyle(
                fontSize: 14 * _settings.fontScale,
                height: 1.4,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }

  // ══════════════════════════════════════════════════════
  //  REUSABLE TILES
  // ══════════════════════════════════════════════════════

  Widget _buildToggleTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool value,
    required Color color,
    required ColorScheme cs,
    required ValueChanged<bool> onChanged,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 12,
                    color: cs.onSurface.withValues(alpha: 0.5),
                  ),
                ),
              ],
            ),
          ),
          Switch.adaptive(
            value: value,
            onChanged: onChanged,
            activeTrackColor: color,
          ),
        ],
      ),
    );
  }

  Widget _buildActionTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required ColorScheme cs,
    required VoidCallback onTap,
    bool showChevron = true,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: cs.surfaceContainerHighest.withValues(alpha: 0.3),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            children: [
              Icon(icon, color: color, size: 22),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 12,
                        color: cs.onSurface.withValues(alpha: 0.5),
                      ),
                    ),
                  ],
                ),
              ),
              if (showChevron)
                Icon(
                  Icons.chevron_right_rounded,
                  color: cs.onSurface.withValues(alpha: 0.3),
                  size: 20,
                ),
            ],
          ),
        ),
      ),
    );
  }
}
