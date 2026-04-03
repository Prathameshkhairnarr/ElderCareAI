import 'package:flutter/material.dart';
import '../services/settings_service.dart';
import '../services/auth_service.dart';
import 'login_screen.dart';

class GuardianSettingsScreen extends StatefulWidget {
  const GuardianSettingsScreen({super.key});

  @override
  State<GuardianSettingsScreen> createState() => _GuardianSettingsScreenState();
}

class _GuardianSettingsScreenState extends State<GuardianSettingsScreen> {
  final _settings = SettingsService();
  final _auth     = AuthService();

  // Profile (loaded from auth/storage)
  String? _guardianName;
  String? _guardianPhone;

  // Notification preferences
  bool _smsAlerts      = true;
  bool _sosAlerts      = true;
  bool _highRiskAlerts = true;
  bool _dailySummary   = false;

  // ── Accent colors (constant across themes) ────────────────────────────────
  static const _blue   = Color(0xFF3B82F6);
  static const _green  = Color(0xFF22C55E);
  static const _amber  = Color(0xFFF59E0B);
  static const _red    = Color(0xFFEF4444);
  static const _purple = Color(0xFF8B5CF6);

  @override
  void initState() {
    super.initState();
    _settings.addListener(_onSettingsChanged);
    _loadProfile();
  }

  @override
  void dispose() {
    _settings.removeListener(_onSettingsChanged);
    super.dispose();
  }

  void _onSettingsChanged() {
    if (mounted) setState(() {});
  }

  void _loadProfile() {
    final user = _auth.currentUser;
    if (user != null) {
      setState(() {
        _guardianName  = user.name;
        _guardianPhone = user.phone;
      });
    }
  }

  // ── Adaptive theme helpers ────────────────────────────────────────────────
  bool _isDark(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark;

  Color _bg(BuildContext context) =>
      Theme.of(context).scaffoldBackgroundColor;

  Color _surface(BuildContext context) =>
      _isDark(context) ? const Color(0xFF1A1D2E) : Colors.white;

  Color _textPri(BuildContext context) =>
      Theme.of(context).colorScheme.onSurface;

  Color _textSec(BuildContext context) =>
      _isDark(context) ? const Color(0xFFB0B3C1) : const Color(0xFF6B7280);

  Color _borderColor(BuildContext context) =>
      _isDark(context)
          ? Colors.white.withOpacity(0.07)
          : Colors.black.withOpacity(0.06);

  Color _dividerColor(BuildContext context) =>
      _isDark(context)
          ? Colors.white.withOpacity(0.06)
          : Colors.black.withOpacity(0.06);

  Color _switchTrackInactive(BuildContext context) =>
      _isDark(context)
          ? Colors.white.withOpacity(0.1)
          : Colors.black.withOpacity(0.08);

  Color _switchThumbInactive(BuildContext context) =>
      _isDark(context) ? const Color(0xFFB0B3C1) : const Color(0xFF9CA3AF);

  void _logout() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _surface(context),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Logout',
          style: TextStyle(
            color: _textPri(context),
            fontWeight: FontWeight.w700,
          ),
        ),
        content: Text(
          'Are you sure you want to logout?',
          style: TextStyle(color: _textSec(context)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel', style: TextStyle(color: _textSec(context))),
          ),
          TextButton(
            onPressed: () {
              _auth.logout();
              Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(builder: (_) => const LoginScreen()),
                (route) => false,
              );
            },
            child: const Text('Logout', style: TextStyle(color: _red)),
          ),
        ],
      ),
    );
  }

  // ── Build ─────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg(context),
      appBar: AppBar(
        backgroundColor: _bg(context),
        elevation: 0,
        centerTitle: true,
        title: Text(
          'Settings',
          style: TextStyle(
            color: _textPri(context),
            fontSize: 20,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
        children: [
          _buildProfileCard(context),
          const SizedBox(height: 28),
          _buildNotificationsSection(context),
          const SizedBox(height: 28),
          _buildAppearanceSection(context),
          const SizedBox(height: 28),
          _buildAccountSection(context),
        ],
      ),
    );
  }

  // ── Profile card ──────────────────────────────────────────────────────────
  Widget _buildProfileCard(BuildContext context) {
    final initial = (_guardianName?.isNotEmpty == true)
        ? _guardianName![0].toUpperCase()
        : 'G';

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _surface(context),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: _blue.withOpacity(0.28)),
      ),
      child: Row(
        children: [
          // Avatar
          Container(
            width: 58,
            height: 58,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _blue.withOpacity(0.14),
              border: Border.all(color: _blue.withOpacity(0.4), width: 2.5),
            ),
            child: Center(
              child: Text(
                initial,
                style: const TextStyle(
                  color: _blue,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),

          // Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _guardianName ?? 'Guardian',
                  style: TextStyle(
                    color: _textPri(context),
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                if (_guardianPhone != null && _guardianPhone!.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(Icons.phone_rounded, size: 12, color: _textSec(context)),
                      const SizedBox(width: 4),
                      Text(
                        _guardianPhone!,
                        style: TextStyle(color: _textSec(context), fontSize: 13),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                  decoration: BoxDecoration(
                    color: _blue.withOpacity(0.14),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text(
                    'Guardian Account',
                    style: TextStyle(
                      color: _blue,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Notifications ─────────────────────────────────────────────────────────
  Widget _buildNotificationsSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionLabel(context, 'Notifications'),
        const SizedBox(height: 12),
        Container(
          decoration: BoxDecoration(
            color: _surface(context),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: _borderColor(context)),
          ),
          child: Column(
            children: [
              _toggleTile(
                context: context,
                icon: Icons.sms_rounded,
                iconColor: _purple,
                title: 'SMS Scam Alerts',
                subtitle: 'Notify when a scam SMS is detected',
                value: _smsAlerts,
                onChanged: (v) => setState(() => _smsAlerts = v),
              ),
              _dividerWidget(context),
              _toggleTile(
                context: context,
                icon: Icons.emergency_share_rounded,
                iconColor: _red,
                title: 'SOS Alerts',
                subtitle: 'Immediate ping on Shake-to-SOS',
                value: _sosAlerts,
                onChanged: (v) => setState(() => _sosAlerts = v),
              ),
              _dividerWidget(context),
              _toggleTile(
                context: context,
                icon: Icons.shield_rounded,
                iconColor: _amber,
                title: 'High Risk Score Alert',
                subtitle: 'Alert when risk score exceeds 75',
                value: _highRiskAlerts,
                onChanged: (v) => setState(() => _highRiskAlerts = v),
              ),
              _dividerWidget(context),
              _toggleTile(
                context: context,
                icon: Icons.summarize_rounded,
                iconColor: _green,
                title: 'Daily Health Summary',
                subtitle: 'Evening report on elder\'s activity',
                value: _dailySummary,
                onChanged: (v) => setState(() => _dailySummary = v),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ── Appearance ────────────────────────────────────────────────────────────
  Widget _buildAppearanceSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionLabel(context, 'Appearance'),
        const SizedBox(height: 12),
        Container(
          decoration: BoxDecoration(
            color: _surface(context),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: _borderColor(context)),
          ),
          child: Column(
            children: [
              _themeTile(context, ThemeMode.light, 'Light Mode',
                  Icons.wb_sunny_rounded),
              _dividerWidget(context),
              _themeTile(context, ThemeMode.dark, 'Dark Mode',
                  Icons.dark_mode_rounded),
              _dividerWidget(context),
              _themeTile(context, ThemeMode.system, 'System Default',
                  Icons.settings_brightness_rounded),
            ],
          ),
        ),
      ],
    );
  }

  // ── Account ───────────────────────────────────────────────────────────────
  Widget _buildAccountSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionLabel(context, 'Account'),
        const SizedBox(height: 12),
        Container(
          decoration: BoxDecoration(
            color: _surface(context),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: _red.withOpacity(0.2)),
          ),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 6,
            ),
            leading: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: _red.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.logout_rounded, color: _red, size: 18),
            ),
            title: const Text(
              'Logout',
              style: TextStyle(
                color: _red,
                fontSize: 14,
                fontWeight: FontWeight.w700,
              ),
            ),
            subtitle: Text(
              'Sign out of your guardian account',
              style: TextStyle(color: _textSec(context), fontSize: 12),
            ),
            trailing: const Icon(
              Icons.arrow_forward_ios_rounded,
              size: 14,
              color: _red,
            ),
            onTap: _logout,
          ),
        ),
      ],
    );
  }

  // ── Helpers ───────────────────────────────────────────────────────────────
  Widget _sectionLabel(BuildContext context, String text) {
    return Text(
      text.toUpperCase(),
      style: TextStyle(
        color: _textSec(context),
        fontSize: 11,
        fontWeight: FontWeight.w600,
        letterSpacing: 1.2,
      ),
    );
  }

  Widget _dividerWidget(BuildContext context) => Divider(
        height: 0.5,
        indent: 56,
        color: _dividerColor(context),
      );

  Widget _toggleTile({
    required BuildContext context,
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: iconColor.withOpacity(0.12),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: iconColor, size: 18),
      ),
      title: Text(
        title,
        style: TextStyle(
          color: _textPri(context),
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(color: _textSec(context), fontSize: 12),
      ),
      trailing: Switch(
        value: value,
        onChanged: onChanged,
        activeColor: _blue,
        activeTrackColor: _blue.withOpacity(0.3),
        inactiveTrackColor: _switchTrackInactive(context),
        inactiveThumbColor: _switchThumbInactive(context),
        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
    );
  }

  Widget _themeTile(
    BuildContext context,
    ThemeMode mode,
    String title,
    IconData icon,
  ) {
    final selected = _settings.themeMode == mode;
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: selected
              ? _blue.withOpacity(0.14)
              : _isDark(context)
                  ? Colors.white.withOpacity(0.06)
                  : Colors.black.withOpacity(0.04),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(
          icon,
          color: selected ? _blue : _textSec(context),
          size: 18,
        ),
      ),
      title: Text(
        title,
        style: TextStyle(
          color: selected ? _textPri(context) : _textSec(context),
          fontSize: 14,
          fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
        ),
      ),
      trailing: selected
          ? Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: _blue.withOpacity(0.15),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.check_rounded,
                color: _blue,
                size: 14,
              ),
            )
          : null,
      onTap: () => _settings.updateThemeMode(mode),
    );
  }
}
