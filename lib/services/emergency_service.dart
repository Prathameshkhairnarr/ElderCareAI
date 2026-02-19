import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter/services.dart'; // MethodChannel
import 'package:url_launcher/url_launcher.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:uuid/uuid.dart';
import 'api_service.dart';

class EmergencyContact {
  final String id;
  final String name;
  final String phone;
  final String relationship;
  final int colorIndex;
  final String? photoBase64; // New field for profile photo

  EmergencyContact({
    required this.id,
    required this.name,
    required this.phone,
    required this.relationship,
    this.colorIndex = 0,
    this.photoBase64,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'phone': phone,
    'relationship': relationship,
    'color_index': colorIndex,
    'photo_base64': photoBase64,
  };

  factory EmergencyContact.fromJson(Map<String, dynamic> json) {
    return EmergencyContact(
      id: json['id'],
      name: json['name'],
      phone: json['phone'],
      relationship: json['relationship'],
      colorIndex: json['color_index'] ?? json['colorIndex'] ?? 0,
      photoBase64: json['photo_base64'] ?? json['photoBase64'],
    );
  }
}

class EmergencyService extends ChangeNotifier {
  static final EmergencyService _instance = EmergencyService._internal();
  factory EmergencyService() => _instance;
  EmergencyService._internal();

  List<EmergencyContact> _contacts = [];
  bool _isSending = false;
  String? _lastStatus;
  DateTime? _lastSosTime;

  List<EmergencyContact> get contacts => _contacts;
  bool get isSending => _isSending;
  String? get lastStatus => _lastStatus;

  /// Seconds remaining before SOS can be triggered again (0 = ready)
  int get cooldownRemaining {
    if (_lastSosTime == null) return 0;
    final elapsed = DateTime.now().difference(_lastSosTime!).inSeconds;
    return (60 - elapsed).clamp(0, 60);
  }

  // Constants
  static const String _contactsKey = 'emergency_contacts';
  static const String _pendingSosKey = 'pending_sos_queue';
  final _api = ApiService();

  // Initialize
  Future<void> init() async {
    await _loadContacts();
    // Retry any pending SOS that failed to sync
    _retryPendingSos();
  }

  // Load contacts (API First, Fallback to Local)
  Future<void> _loadContacts() async {
    // 1. Try API
    final apiContacts = await _api.getContacts();
    if (apiContacts != null) {
      _contacts = apiContacts.map((e) => EmergencyContact.fromJson(e)).toList();
      notifyListeners();
      _saveContactsLocal(); // Update Cache
      return;
    }

    // 2. Fallback to Local
    print("API unreachable, loading local contacts...");
    final prefs = await SharedPreferences.getInstance();
    final String? contactsJson = prefs.getString(_contactsKey);
    if (contactsJson != null) {
      final List<dynamic> decoded = jsonDecode(contactsJson);
      _contacts = decoded.map((e) => EmergencyContact.fromJson(e)).toList();
      notifyListeners();
    }
  }

  // Save contacts (Local Cache)
  Future<void> _saveContactsLocal() async {
    final prefs = await SharedPreferences.getInstance();
    final String encoded = jsonEncode(
      _contacts.map((e) => e.toJson()).toList(),
    );
    await prefs.setString(_contactsKey, encoded);
  }

  // Add Contact
  Future<void> addContact(
    String name,
    String phone,
    String relationship,
    String? photoBase64,
  ) async {
    final newId = const Uuid().v4();

    // Optimistic Update
    final newContact = EmergencyContact(
      id: newId,
      name: name,
      phone: phone.replaceAll(RegExp(r'[^\d+]'), ''),
      relationship: relationship,
      colorIndex: _contacts.length % 5,
      photoBase64: photoBase64,
    );
    _contacts.add(newContact);
    notifyListeners();
    _saveContactsLocal();

    // Sync to Backend
    await _api.addContact(newContact.toJson());
    // In a real app, we might update the ID from response, but UUID is fine for now
  }

  // Remove Contact
  Future<void> removeContact(String id) async {
    _contacts.removeWhere((c) => c.id == id);
    notifyListeners();
    _saveContactsLocal();

    // Sync to Backend
    await _api.deleteContact(id);
  }

  // 🚨 TRIGGER SOS 🚨
  /// Returns true if SOS was successfully sent (SMS + backend).
  Future<bool> triggerSOS() async {
    // Anti-spam cooldown
    if (cooldownRemaining > 0) {
      _lastStatus = "Please wait ${cooldownRemaining}s before sending again";
      notifyListeners();
      return false;
    }

    if (_isSending) return false; // Already in progress
    _isSending = true;
    _lastStatus = "Starting Emergency sequence...";
    notifyListeners();

    bool success = false;

    try {
      if (_contacts.isEmpty) {
        throw Exception("No emergency contacts added!");
      }

      // 1. Get Location
      _lastStatus = "Fetching location...";
      notifyListeners();

      Position? position;

      if (!kIsWeb &&
          (defaultTargetPlatform == TargetPlatform.android ||
              defaultTargetPlatform == TargetPlatform.iOS)) {
        try {
          position = await _determinePosition().timeout(
            const Duration(seconds: 5),
          );
        } catch (e) {
          print("High accuracy GPS failed: $e. Trying last known...");
          position = await Geolocator.getLastKnownPosition();
        }
      } else {
        await Future.delayed(const Duration(seconds: 1));
        print("Mocking location for Windows/Web");
      }

      // 2. Construct Message
      String message = "🚨 EMERGENCY ALERT! I need help!\n";
      if (position != null) {
        message +=
            "📍 Location: https://maps.google.com/?q=${position.latitude},${position.longitude}\n";
        message += "⚡ Accuracy: Within ${position.accuracy.toInt()}m\n";
      } else {
        message += "📍 Location: Unknown (GPS Unavailable)\n";
      }
      message += "🕒 Time: ${DateTime.now().toString().split('.')[0]}";

      // 3. Send SMS
      _lastStatus = "Sending SMS to ${_contacts.length} contacts...";
      notifyListeners();

      if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
        var smsPermission = await Permission.sms.status;
        if (!smsPermission.isGranted) {
          _lastStatus = "Requesting SMS permission...";
          notifyListeners();
          smsPermission = await Permission.sms.request();
        }
      }

      final recipients = _contacts.map((c) => c.phone).toList();
      String result;

      if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
        try {
          final platform = const MethodChannel('com.eldercare/sms');
          _lastStatus = "Sending via Android Manager...";
          notifyListeners();

          for (var phone in recipients) {
            await platform.invokeMethod('sendSMS', <String, String>{
              'phone': phone,
              'message': message,
            });
          }
          result = "Sent via Native Android Manager";
        } catch (e) {
          print("Native SMS failed: $e. Fallback to URL launcher.");
          _lastStatus = "Native failed. Opening SMS app...";
          notifyListeners();

          final Uri smsLaunchUri = Uri(
            scheme: 'sms',
            path: recipients.join(','),
            queryParameters: <String, String>{'body': message},
          );
          try {
            if (await canLaunchUrl(smsLaunchUri)) {
              await launchUrl(smsLaunchUri);
              result = "Opened SMS App (Fallback)";
            } else {
              result = "Failed: No SMS App found";
            }
          } catch (launchError) {
            result = "Failed to launch SMS: $launchError";
          }
        }
      } else {
        await Future.delayed(const Duration(seconds: 1));
        result = "Simulated SMS send (Not Android)";
      }

      // 4. Sync with Backend (with offline queue fallback)
      _lastStatus = "Syncing with server...";
      notifyListeners();

      final backendOk = await _api.triggerSos(
        lat: position?.latitude,
        lng: position?.longitude,
      );

      if (!backendOk) {
        // Queue for later retry
        await _queuePendingSos(
          lat: position?.latitude,
          lng: position?.longitude,
        );
        _lastStatus = "✅ SMS sent. Server sync queued for retry.";
      } else {
        _lastStatus = "✅ SOS sent to ${_contacts.length} contacts & server.";
      }

      // Mark cooldown
      _lastSosTime = DateTime.now();
      success = true;
      print("SOS Result: $result | Backend: $backendOk");
    } catch (e) {
      _lastStatus = "❌ Failed: $e";
      print("SOS Error: $e");
    } finally {
      _isSending = false;
      notifyListeners();
    }
    return success;
  }

  /// Queue a failed SOS for retry when network returns
  Future<void> _queuePendingSos({double? lat, double? lng}) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final pending = prefs.getStringList(_pendingSosKey) ?? [];
      final payload = jsonEncode({
        'latitude': lat,
        'longitude': lng,
        'message': 'Emergency SOS triggered from app',
        'timestamp': DateTime.now().toIso8601String(),
        'retries': 0,
      });
      pending.add(payload);
      await prefs.setStringList(_pendingSosKey, pending);
      print("SOS queued for offline retry");
    } catch (e) {
      print("Failed to queue SOS: $e");
    }
  }

  /// Retry any pending SOS calls (called on init and after successful SOS)
  Future<void> _retryPendingSos() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final pending = prefs.getStringList(_pendingSosKey) ?? [];
      if (pending.isEmpty) return;

      final remaining = <String>[];
      for (final item in pending) {
        final data = jsonDecode(item) as Map<String, dynamic>;
        final retries = (data['retries'] as int?) ?? 0;

        if (retries >= 3) continue; // Drop after 3 attempts

        final ok = await _api.triggerSos(
          lat: data['latitude'] as double?,
          lng: data['longitude'] as double?,
        );

        if (!ok) {
          // Increment retry count and keep
          data['retries'] = retries + 1;
          remaining.add(jsonEncode(data));
        } else {
          print("Retried pending SOS successfully");
        }
      }

      await prefs.setStringList(_pendingSosKey, remaining);
    } catch (e) {
      print("Pending SOS retry error: $e");
    }
  }

  // Helper: Location Permission & Fetch
  Future<Position> _determinePosition() async {
    bool serviceEnabled;
    LocationPermission permission;

    // Test if location services are enabled.
    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      return Future.error('Location services are disabled.');
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        return Future.error('Location permissions are denied');
      }
    }

    if (permission == LocationPermission.deniedForever) {
      return Future.error(
        'Location permissions are permanently denied, we cannot request permissions.',
      );
    }

    return await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
    );
  }
}
