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
  final _auth = AuthService();

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
        title: const Text('Logout'),
        content: const Text('Are you sure you want to logout?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              _auth.logout();
              Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(builder: (_) => const LoginScreen()),
                (route) => false,
              );
            },
            child: const Text('Logout', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        centerTitle: true,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildSectionTitle('Appearance'),
          const SizedBox(height: 12),
          _buildThemeSelector(),
          const SizedBox(height: 24),
          _buildSectionTitle('Account'),
          ListTile(
            leading: const Icon(Icons.logout_rounded, color: Colors.red),
            title: const Text('Logout', style: TextStyle(color: Colors.red)),
            onTap: _logout,
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title.toUpperCase(),
      style: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.bold,
        color: Theme.of(context).colorScheme.onSurface.withAlpha(120),
        letterSpacing: 1.2,
      ),
    );
  }

  Widget _buildThemeSelector() {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(
          context,
        ).colorScheme.surfaceContainerHighest.withAlpha(80),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          _buildThemeTile(
            ThemeMode.light,
            'Light Mode',
            Icons.wb_sunny_rounded,
          ),
          const Divider(height: 1),
          _buildThemeTile(ThemeMode.dark, 'Dark Mode', Icons.dark_mode_rounded),
          const Divider(height: 1),
          _buildThemeTile(
            ThemeMode.system,
            'System Default',
            Icons.settings_brightness_rounded,
          ),
        ],
      ),
    );
  }

  Widget _buildThemeTile(ThemeMode mode, String title, IconData icon) {
    final isSelected = _settings.themeMode == mode;
    return ListTile(
      leading: Icon(icon, color: isSelected ? Colors.blue : null),
      title: Text(title),
      trailing: isSelected ? const Icon(Icons.check, color: Colors.blue) : null,
      onTap: () => _settings.updateThemeMode(mode),
    );
  }
}
