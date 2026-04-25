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
  bool _shakeSosEnabled = false;

  // Voice alert category toggles
  bool _voiceAlertScam = true;
  bool _voiceAlertMedicine = true;
  bool _voiceAlertHealth = true;
  bool _voiceAlertSos = true;
  bool _voiceAlertCallWarning = true;

  ThemeMode get themeMode => _themeMode;
  bool get voiceFeedback => _voiceFeedback;
  bool get notifications => _notifications;
  double get fontScale => _fontScale;
  bool get shakeSosEnabled => _shakeSosEnabled;

  // Voice alert category getters
  bool get voiceAlertScam => _voiceAlertScam;
  bool get voiceAlertMedicine => _voiceAlertMedicine;
  bool get voiceAlertHealth => _voiceAlertHealth;
  bool get voiceAlertSos => _voiceAlertSos;
  bool get voiceAlertCallWarning => _voiceAlertCallWarning;

  // Keys
  static const String _themeKey = 'theme_mode';
  static const String _voiceKey = 'voice_feedback';
  static const String _notifKey = 'notifications_enabled';
  static const String _fontKey = 'font_scale';
  static const String _shakeKey = 'shake_sos_enabled';
  static const String _vaScamKey = 'va_scam';
  static const String _vaMedicineKey = 'va_medicine';
  static const String _vaHealthKey = 'va_health';
  static const String _vaSosKey = 'va_sos';
  static const String _vaCallKey = 'va_call_warning';

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
    _shakeSosEnabled = prefs.getBool(_shakeKey) ?? false;

    // Load voice alert category toggles
    _voiceAlertScam = prefs.getBool(_vaScamKey) ?? true;
    _voiceAlertMedicine = prefs.getBool(_vaMedicineKey) ?? true;
    _voiceAlertHealth = prefs.getBool(_vaHealthKey) ?? true;
    _voiceAlertSos = prefs.getBool(_vaSosKey) ?? true;
    _voiceAlertCallWarning = prefs.getBool(_vaCallKey) ?? true;

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

  // Voice alert category toggles
  Future<void> toggleVoiceAlertScam(bool value) async {
    _voiceAlertScam = value;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_vaScamKey, value);
  }

  Future<void> toggleVoiceAlertMedicine(bool value) async {
    _voiceAlertMedicine = value;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_vaMedicineKey, value);
  }

  Future<void> toggleVoiceAlertHealth(bool value) async {
    _voiceAlertHealth = value;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_vaHealthKey, value);
  }

  Future<void> toggleVoiceAlertSos(bool value) async {
    _voiceAlertSos = value;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_vaSosKey, value);
  }

  Future<void> toggleVoiceAlertCallWarning(bool value) async {
    _voiceAlertCallWarning = value;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_vaCallKey, value);
  }
}
