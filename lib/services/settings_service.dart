import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsService extends ChangeNotifier {
  static final SettingsService _instance = SettingsService._internal();
  factory SettingsService() => _instance;
  SettingsService._internal();

  // State
  ThemeMode _themeMode = ThemeMode.system;
  bool _voiceFeedback = true;
  bool _notifications = true;
  double _fontScale = 1.0;
  bool _shakeSosEnabled = true;

  ThemeMode get themeMode => _themeMode;
  bool get voiceFeedback => _voiceFeedback;
  bool get notifications => _notifications;
  double get fontScale => _fontScale;
  bool get shakeSosEnabled => _shakeSosEnabled;

  // Keys
  static const String _themeKey = 'theme_mode';
  static const String _voiceKey = 'voice_feedback';
  static const String _notifKey = 'notifications_enabled';
  static const String _fontKey = 'font_scale';
  static const String _shakeKey = 'shake_sos_enabled';

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();

    // Load Theme
    final themeIndex = prefs.getInt(_themeKey);
    if (themeIndex != null) {
      _themeMode = ThemeMode.values[themeIndex];
    }

    // Load Toggles
    _voiceFeedback = prefs.getBool(_voiceKey) ?? true;
    _notifications = prefs.getBool(_notifKey) ?? true;
    _fontScale = prefs.getDouble(_fontKey) ?? 1.0;
    _shakeSosEnabled = prefs.getBool(_shakeKey) ?? true;

    notifyListeners();
  }

  Future<void> updateThemeMode(ThemeMode mode) async {
    _themeMode = mode;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_themeKey, mode.index);
  }

  Future<void> toggleVoiceFeedback(bool value) async {
    _voiceFeedback = value;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_voiceKey, value);
  }

  Future<void> toggleNotifications(bool value) async {
    _notifications = value;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_notifKey, value);
  }

  Future<void> updateFontScale(double scale) async {
    _fontScale = scale.clamp(0.8, 1.4);
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_fontKey, _fontScale);
  }

  Future<void> toggleShakeSos(bool value) async {
    _shakeSosEnabled = value;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_shakeKey, value);
  }
}
