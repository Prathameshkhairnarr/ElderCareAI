import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'app_logger.dart';

class ChildLocationPoint {
  final double latitude;
  final double longitude;
  final DateTime timestamp;

  ChildLocationPoint({
    required this.latitude,
    required this.longitude,
    required this.timestamp,
  });

  Map<String, dynamic> toJson() => {
    'lat': latitude,
    'lng': longitude,
    'ts': timestamp.toIso8601String(),
  };

  factory ChildLocationPoint.fromJson(Map<String, dynamic> json) {
    return ChildLocationPoint(
      latitude: (json['lat'] as num).toDouble(),
      longitude: (json['lng'] as num).toDouble(),
      timestamp: DateTime.tryParse(json['ts'] as String? ?? '') ?? DateTime.now(),
    );
  }
}

class ChildActivityReport {
  final DateTime date;
  final int usedMinutes;
  final int dailyLimitMinutes;
  final int locationPoints;
  final int blockedWebsiteHits;
  final int blockedAppHits;
  final int blockedNumberEvents;
  final int sosCount;

  ChildActivityReport({
    required this.date,
    required this.usedMinutes,
    required this.dailyLimitMinutes,
    required this.locationPoints,
    required this.blockedWebsiteHits,
    required this.blockedAppHits,
    required this.blockedNumberEvents,
    required this.sosCount,
  });
}

class ChildControlsService {
  static final ChildControlsService _instance = ChildControlsService._internal();
  factory ChildControlsService() => _instance;
  ChildControlsService._internal();

  static const String _dateKey = 'child_controls_date';
  static const String _usedSecondsKey = 'child_controls_used_seconds';
  static const String _dailyLimitKey = 'child_controls_daily_limit';
  static const String _blockedSitesKey = 'child_controls_blocked_sites';
  static const String _allowedAppsKey = 'child_controls_allowed_apps';
  static const String _blockedAppsKey = 'child_controls_blocked_apps';
  static const String _blockedNumbersKey = 'child_controls_blocked_numbers';
  static const String _locationHistoryKey = 'child_controls_location_history';
  static const String _youtubeHistoryKey = 'child_controls_youtube_history';
  static const String _eventsKey = 'child_controls_events';
  static const String _blockedSiteHitsKey = 'child_controls_blocked_site_hits';
  static const String _blockedAppHitsKey = 'child_controls_blocked_app_hits';
  static const String _blockedNumberHitsKey = 'child_controls_blocked_number_hits';
  static const String _sosCountKey = 'child_controls_sos_count';

  int _usedSecondsToday = 0;
  int _dailyLimitMinutes = 120;
  final List<String> _blockedSites = <String>[];
  final List<String> _allowedApps = <String>[];
  final List<String> _blockedApps = <String>[];
  final List<String> _blockedNumbers = <String>[];
  final List<ChildLocationPoint> _locationHistory = <ChildLocationPoint>[];
  final List<String> _youtubeHistory = <String>[];
  final List<String> _recentEvents = <String>[];
  int _blockedWebsiteHits = 0;
  int _blockedAppHits = 0;
  int _blockedNumberHits = 0;
  int _sosCount = 0;

  bool _initialized = false;

  int get usedSecondsToday => _usedSecondsToday;
  int get dailyLimitMinutes => _dailyLimitMinutes;
  int get remainingSecondsToday => (_dailyLimitMinutes * 60 - _usedSecondsToday).clamp(0, _dailyLimitMinutes * 60);
  bool get isScreenTimeExceeded => _usedSecondsToday >= _dailyLimitMinutes * 60;

  List<String> get blockedSites => List.unmodifiable(_blockedSites);
  List<String> get allowedApps => List.unmodifiable(_allowedApps);
  List<String> get blockedApps => List.unmodifiable(_blockedApps);
  List<String> get blockedNumbers => List.unmodifiable(_blockedNumbers);
  List<ChildLocationPoint> get locationHistory => List.unmodifiable(_locationHistory);
  List<String> get youtubeHistory => List.unmodifiable(_youtubeHistory);
  List<String> get recentEvents => List.unmodifiable(_recentEvents);

  Future<void> init() async {
    if (_initialized) return;

    final prefs = await SharedPreferences.getInstance();
    final today = _todayStamp();
    final savedDate = prefs.getString(_dateKey);

    if (savedDate != today) {
      _usedSecondsToday = 0;
      await prefs.setInt(_usedSecondsKey, 0);
      await prefs.setString(_dateKey, today);
    } else {
      _usedSecondsToday = prefs.getInt(_usedSecondsKey) ?? 0;
    }

    _dailyLimitMinutes = prefs.getInt(_dailyLimitKey) ?? 120;

    _blockedSites
      ..clear()
      ..addAll(prefs.getStringList(_blockedSitesKey) ?? <String>[]);

    _allowedApps
      ..clear()
      ..addAll(prefs.getStringList(_allowedAppsKey) ?? <String>[]);

    _blockedApps
      ..clear()
      ..addAll(prefs.getStringList(_blockedAppsKey) ?? <String>[]);

    _blockedNumbers
      ..clear()
      ..addAll(prefs.getStringList(_blockedNumbersKey) ?? <String>[]);

    _youtubeHistory
      ..clear()
      ..addAll(prefs.getStringList(_youtubeHistoryKey) ?? <String>[]);

    _recentEvents
      ..clear()
      ..addAll(prefs.getStringList(_eventsKey) ?? <String>[]);

    _blockedWebsiteHits = prefs.getInt(_blockedSiteHitsKey) ?? 0;
    _blockedAppHits = prefs.getInt(_blockedAppHitsKey) ?? 0;
    _blockedNumberHits = prefs.getInt(_blockedNumberHitsKey) ?? 0;
    _sosCount = prefs.getInt(_sosCountKey) ?? 0;

    _locationHistory
      ..clear()
      ..addAll(_decodeLocations(prefs.getString(_locationHistoryKey)));

    _initialized = true;
    AppLogger.info(LogCategory.lifecycle, 'ChildControlsService initialized');
  }

  Future<void> addUsageSeconds(int seconds) async {
    if (seconds <= 0) return;
    await _ensureDateRollOver();
    _usedSecondsToday += seconds;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_usedSecondsKey, _usedSecondsToday);
  }

  Future<void> setDailyLimitMinutes(int minutes) async {
    _dailyLimitMinutes = minutes.clamp(15, 600);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_dailyLimitKey, _dailyLimitMinutes);
    await addEvent('Screen time limit set to $_dailyLimitMinutes minutes');
  }

  Future<void> addBlockedWebsite(String domain) async {
    final normalized = _normalizeDomain(domain);
    if (normalized.isEmpty || _blockedSites.contains(normalized)) return;
    _blockedSites.add(normalized);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_blockedSitesKey, _blockedSites);
    await addEvent('Blocked website added: $normalized');
  }

  Future<void> removeBlockedWebsite(String domain) async {
    _blockedSites.remove(domain);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_blockedSitesKey, _blockedSites);
  }

  Future<void> addAllowedApp(String app) async {
    final value = app.trim();
    if (value.isEmpty || _allowedApps.contains(value)) return;
    _allowedApps.add(value);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_allowedAppsKey, _allowedApps);
    await addEvent('Allowed app added: $value');
  }

  Future<void> removeAllowedApp(String app) async {
    _allowedApps.remove(app);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_allowedAppsKey, _allowedApps);
  }

  Future<void> addBlockedApp(String app) async {
    final value = app.trim();
    if (value.isEmpty || _blockedApps.contains(value)) return;
    _blockedApps.add(value);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_blockedAppsKey, _blockedApps);
    await addEvent('Blocked app added: $value');
  }

  Future<void> removeBlockedApp(String app) async {
    _blockedApps.remove(app);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_blockedAppsKey, _blockedApps);
  }

  Future<void> addBlockedNumber(String number) async {
    final normalized = number.replaceAll(RegExp(r'[^\d+]'), '');
    if (normalized.isEmpty || _blockedNumbers.contains(normalized)) return;
    _blockedNumbers.add(normalized);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_blockedNumbersKey, _blockedNumbers);
    await addEvent('Blocked number added: $normalized');
  }

  Future<void> removeBlockedNumber(String number) async {
    _blockedNumbers.remove(number);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_blockedNumbersKey, _blockedNumbers);
  }

  Future<bool> isWebsiteBlocked(String urlOrDomain) async {
    final normalized = _normalizeDomain(urlOrDomain);
    final blocked = _blockedSites.any((d) => normalized == d || normalized.endsWith('.$d'));
    if (blocked) {
      _blockedWebsiteHits += 1;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_blockedSiteHitsKey, _blockedWebsiteHits);
      await addEvent('Blocked website access attempt: $normalized');
    }
    return blocked;
  }

  Future<bool> isAppBlocked(String appName) async {
    final blocked = _blockedApps.any((a) => a.toLowerCase() == appName.toLowerCase());
    if (blocked) {
      _blockedAppHits += 1;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_blockedAppHitsKey, _blockedAppHits);
      await addEvent('Blocked app launch attempt: $appName');
    }
    return blocked;
  }

  Future<bool> isNumberBlocked(String number) async {
    final normalized = number.replaceAll(RegExp(r'[^\d+]'), '');
    final blocked = _blockedNumbers.contains(normalized);
    if (blocked) {
      _blockedNumberHits += 1;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_blockedNumberHitsKey, _blockedNumberHits);
      await addEvent('Blocked call/SMS attempt: $normalized');
    }
    return blocked;
  }

  Future<void> addLocationPoint({required double lat, required double lng}) async {
    _locationHistory.insert(
      0,
      ChildLocationPoint(latitude: lat, longitude: lng, timestamp: DateTime.now()),
    );
    if (_locationHistory.length > 100) {
      _locationHistory.removeRange(100, _locationHistory.length);
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_locationHistoryKey, _encodeLocations(_locationHistory));
  }

  Future<void> addYoutubeEntry(String queryOrUrl) async {
    final value = queryOrUrl.trim();
    if (value.isEmpty) return;
    _youtubeHistory.insert(0, '${DateTime.now().toIso8601String()}|$value');
    if (_youtubeHistory.length > 100) {
      _youtubeHistory.removeRange(100, _youtubeHistory.length);
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_youtubeHistoryKey, _youtubeHistory);
    await addEvent('YouTube activity logged');
  }

  Future<void> markSosTriggered() async {
    _sosCount += 1;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_sosCountKey, _sosCount);
    await addEvent('Panic button triggered');
  }

  Future<void> addEvent(String event) async {
    _recentEvents.insert(0, '${DateTime.now().toIso8601String()}|$event');
    if (_recentEvents.length > 150) {
      _recentEvents.removeRange(150, _recentEvents.length);
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_eventsKey, _recentEvents);
  }

  ChildActivityReport buildTodayReport() {
    final today = DateTime.now();
    final todayLocations = _locationHistory.where((p) => _isSameDay(p.timestamp, today)).length;

    return ChildActivityReport(
      date: DateTime(today.year, today.month, today.day),
      usedMinutes: (_usedSecondsToday / 60).round(),
      dailyLimitMinutes: _dailyLimitMinutes,
      locationPoints: todayLocations,
      blockedWebsiteHits: _blockedWebsiteHits,
      blockedAppHits: _blockedAppHits,
      blockedNumberEvents: _blockedNumberHits,
      sosCount: _sosCount,
    );
  }

  Future<void> _ensureDateRollOver() async {
    final today = _todayStamp();
    final prefs = await SharedPreferences.getInstance();
    final savedDate = prefs.getString(_dateKey);
    if (savedDate == today) return;

    _usedSecondsToday = 0;
    _blockedWebsiteHits = 0;
    _blockedAppHits = 0;
    _blockedNumberHits = 0;
    _sosCount = 0;

    await prefs.setString(_dateKey, today);
    await prefs.setInt(_usedSecondsKey, 0);
    await prefs.setInt(_blockedSiteHitsKey, 0);
    await prefs.setInt(_blockedAppHitsKey, 0);
    await prefs.setInt(_blockedNumberHitsKey, 0);
    await prefs.setInt(_sosCountKey, 0);
  }

  String _todayStamp() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }

  static bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  String _normalizeDomain(String value) {
    var input = value.trim().toLowerCase();
    input = input.replaceAll(RegExp(r'^https?://'), '');
    final slash = input.indexOf('/');
    if (slash > 0) {
      input = input.substring(0, slash);
    }
    input = input.replaceAll(RegExp(r'^www\.'), '');
    return input;
  }

  String _encodeLocations(List<ChildLocationPoint> points) {
    return jsonEncode(points.map((p) => p.toJson()).toList());
  }

  List<ChildLocationPoint> _decodeLocations(String? payload) {
    if (payload == null || payload.isEmpty) return <ChildLocationPoint>[];
    try {
      final decoded = jsonDecode(payload) as List<dynamic>;
      return decoded
          .whereType<Map<String, dynamic>>()
          .map(ChildLocationPoint.fromJson)
          .toList();
    } catch (_) {
      return <ChildLocationPoint>[];
    }
  }
}
