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

  List<EmergencyContact> get contacts => _contacts;
  bool get isSending => _isSending;
  String? get lastStatus => _lastStatus;

  // Constants
  static const String _contactsKey = 'emergency_contacts';
  final _api = ApiService();

  // Initialize
  Future<void> init() async {
    await _loadContacts();
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
  Future<void> triggerSOS() async {
    if (_isSending) return; // Debounce
    _isSending = true;
    _lastStatus = "Starting Emergency sequence...";
    notifyListeners();

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
          // Try high accuracy with short timeout to avoid hanging
          position = await _determinePosition().timeout(
            const Duration(seconds: 5),
          );
        } catch (e) {
          print("High accuracy GPS failed: $e. Trying last known...");
          // Fallback
          position = await Geolocator.getLastKnownPosition();
        }
      } else {
        // Mock location for Windows/Web
        await Future.delayed(const Duration(seconds: 1)); // Sim delay
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

      // Request SMS Permission for native send
      if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
        var status = await Permission.sms.status;
        if (!status.isGranted) {
          _lastStatus = "Requesting SMS permission...";
          notifyListeners();
          status = await Permission.sms.request();
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

          // Fallback to interactive SMS
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

      _lastStatus = "Done: $result";
      print("SOS Result: $result");

      // 4. Sync with Backend (Fire & Forget)
      try {
        if (kIsWeb ||
            (defaultTargetPlatform != TargetPlatform.android &&
                defaultTargetPlatform != TargetPlatform.iOS)) {
          // On Windows/Web, we can definitely sync since we have internet usually
          await ApiService().triggerSos(
            lat: position?.latitude,
            lng: position?.longitude,
          );
        } else {
          // On mobile, try to sync but don't await if we want to be fast?
          // actually awaiting is fine as it's fire & forget in UI terms (provider notifies listener)
          ApiService().triggerSos(
            lat: position?.latitude,
            lng: position?.longitude,
          );
        }
      } catch (e) {
        print("Backend sync failed (harmless): $e");
      }
    } catch (e) {
      _lastStatus = "Failed: $e";
      print("SOS Error: $e");
    } finally {
      _isSending = false;
      notifyListeners();
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
