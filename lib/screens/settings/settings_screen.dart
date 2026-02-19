import 'package:flutter/material.dart';
import '../../services/auth_service.dart';
import '../../services/settings_service.dart';
import '../../widgets/page_transition.dart';
import '../login_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _auth = AuthService();
  final _settings = SettingsService();

  @override
  void initState() {
    super.initState();
    _settings.addListener(_onSettingsChanged);
  }

  @override
  void dispose() {
    _settings.removeListener(_onSettingsChanged);
    super.dispose();
  }

  void _onSettingsChanged() {
    if (mounted) setState(() {});
  }

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

  String _themeName(ThemeMode mode) {
    switch (mode) {
      case ThemeMode.light:
        return 'Light';
      case ThemeMode.dark:
        return 'Dark';
      case ThemeMode.system:
        return 'System Default';
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

  String _formatLastLogin(String isoDateTime) {
    try {
      final date = DateTime.parse(isoDateTime);
      final now = DateTime.now();
      final diff = now.difference(date);
      if (diff.inMinutes < 2) return 'Just now';
      if (diff.inHours < 1) return '${diff.inMinutes}m ago';
      if (diff.inHours < 24) return '${diff.inHours}h ago';
      if (diff.inDays == 1) return 'Yesterday';
      return '${date.day}/${date.month}/${date.year}';
    } catch (_) {
      return isoDateTime;
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = _auth.currentUser;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        centerTitle: true,
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Profile section
            _buildProfileSection(user),
            const SizedBox(height: 24),

            // ── Appearance ──────────────────────────
            _buildSectionTitle('Appearance'),
            const SizedBox(height: 8),

            // Theme Selector
            Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Theme.of(
                  context,
                ).colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
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
                            child: _buildThemeOption(mode),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),

            // Font Size Slider
            Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Theme.of(
                  context,
                ).colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
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
                          color: const Color(
                            0xFF42A5F5,
                          ).withValues(alpha: 0.15),
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
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Expanded(
                        child: SliderTheme(
                          data: SliderTheme.of(context).copyWith(
                            activeTrackColor: const Color(0xFF42A5F5),
                            inactiveTrackColor: const Color(
                              0xFF42A5F5,
                            ).withValues(alpha: 0.2),
                            thumbColor: const Color(0xFF42A5F5),
                            overlayColor: const Color(
                              0xFF42A5F5,
                            ).withValues(alpha: 0.1),
                            trackHeight: 4,
                          ),
                          child: Slider(
                            value: _settings.fontScale,
                            min: 0.8,
                            max: 1.4,
                            divisions: 6,
                            onChanged: (value) =>
                                _settings.updateFontScale(value),
                          ),
                        ),
                      ),
                      const Text(
                        'A',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  // Preview
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surface,
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
            ),
            const SizedBox(height: 24),

            // ── Safety Settings ──────────────────────
            _buildSectionTitle('Safety'),
            const SizedBox(height: 8),
            _buildToggleTile(
              icon: Icons.notifications_rounded,
              title: 'Push Notifications',
              subtitle: 'Receive scam alerts and updates',
              value: _settings.notifications,
              color: const Color(0xFF42A5F5),
              onChanged: (v) => _settings.toggleNotifications(v),
            ),
            _buildToggleTile(
              icon: Icons.record_voice_over_rounded,
              title: 'Voice Alerts',
              subtitle: 'Read scam warnings aloud',
              value: _settings.voiceFeedback,
              color: const Color(0xFFEF5350),
              onChanged: (v) => _settings.toggleVoiceFeedback(v),
            ),
            _buildToggleTile(
              icon: Icons.vibration_rounded,
              title: 'Shake to SOS',
              subtitle: 'Shake phone vigorously to trigger SOS',
              value: _settings.shakeSosEnabled,
              color: const Color(0xFFFF7043),
              onChanged: (v) => _settings.toggleShakeSos(v),
            ),
            const SizedBox(height: 24),

            // ── About ──────────────────────────────
            _buildSectionTitle('About'),
            const SizedBox(height: 8),
            _buildActionTile(
              icon: Icons.info_outline_rounded,
              title: 'App Version',
              subtitle: '1.0.0 (Beta)',
              color: const Color(0xFF78909C),
              onTap: () {},
            ),
            _buildActionTile(
              icon: Icons.description_rounded,
              title: 'Terms of Service',
              subtitle: 'View legal terms',
              color: const Color(0xFF78909C),
              onTap: () => _showTermsDialog(),
            ),
            _buildActionTile(
              icon: Icons.privacy_tip_rounded,
              title: 'Privacy Policy',
              subtitle: 'How we handle your data',
              color: const Color(0xFF78909C),
              onTap: () => _showPrivacyDialog(),
            ),
            const SizedBox(height: 24),

            // Logout button
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
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  // ── Theme Option Chip ──────────────────────────
  Widget _buildThemeOption(ThemeMode mode) {
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
                : Theme.of(context).colorScheme.outline.withValues(alpha: 0.15),
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
                  : Theme.of(
                      context,
                    ).colorScheme.onSurface.withValues(alpha: 0.5),
            ),
            const SizedBox(height: 4),
            Text(
              _themeName(mode),
              style: TextStyle(
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color: isSelected
                    ? const Color(0xFF7C4DFF)
                    : Theme.of(
                        context,
                      ).colorScheme.onSurface.withValues(alpha: 0.6),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileSection(UserProfile? user) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: const Duration(milliseconds: 600),
      builder: (context, value, child) => Opacity(opacity: value, child: child),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Theme.of(
            context,
          ).colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: Theme.of(
              context,
            ).colorScheme.outline.withValues(alpha: 0.08),
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF4FC3F7), Color(0xFF0288D1)],
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Center(
                child: Text(
                  (user?.name ?? 'U')[0].toUpperCase(),
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    user?.name ?? 'User',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${user?.phone ?? 'N/A'} · ${user?.role.name.toUpperCase() ?? 'USER'}',
                    style: TextStyle(
                      fontSize: 13,
                      color: Theme.of(
                        context,
                      ).colorScheme.onSurface.withValues(alpha: 0.5),
                    ),
                  ),
                  if (user?.lastLoginAt != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      'Last login: ${_formatLastLogin(user!.lastLoginAt!)}',
                      style: TextStyle(
                        fontSize: 11,
                        color: Theme.of(
                          context,
                        ).colorScheme.onSurface.withValues(alpha: 0.35),
                      ),
                    ),
                  ] else ...[
                    const SizedBox(height: 4),
                    Text(
                      'First time login',
                      style: TextStyle(
                        fontSize: 11,
                        color: Theme.of(
                          context,
                        ).colorScheme.onSurface.withValues(alpha: 0.35),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w700,
        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
        letterSpacing: 0.5,
      ),
    );
  }

  Widget _buildToggleTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool value,
    required Color color,
    required ValueChanged<bool> onChanged,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Theme.of(
          context,
        ).colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
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
                    color: Theme.of(
                      context,
                    ).colorScheme.onSurface.withValues(alpha: 0.5),
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
    required VoidCallback onTap,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: Theme.of(
              context,
            ).colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
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
                        color: Theme.of(
                          context,
                        ).colorScheme.onSurface.withValues(alpha: 0.5),
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                color: Theme.of(
                  context,
                ).colorScheme.onSurface.withValues(alpha: 0.3),
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
