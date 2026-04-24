import 'package:flutter/material.dart';
import '../../../services/emergency_service.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:url_launcher/url_launcher.dart';
import '../child_main_screen.dart';

class SafetyTab extends StatefulWidget {
  const SafetyTab({Key? key}) : super(key: key);

  @override
  State<SafetyTab> createState() => _SafetyTabState();
}

class _SafetyTabState extends State<SafetyTab> {
  String _locationStatus = "Locating...";
  String _timeStatus = "Waiting for GPS";
  final EmergencyService _emergencyService = EmergencyService();

  @override
  void initState() {
    super.initState();
    _fetchRealLocation();
    _emergencyService.addListener(_onContactsChanged);
    _emergencyService.init();
  }

  @override
  void dispose() {
    _emergencyService.removeListener(_onContactsChanged);
    super.dispose();
  }

  void _onContactsChanged() => setState(() {});

  Future<void> _fetchRealLocation() async {
    try {
      Position position = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
      String placemarkName = "Lat: ${position.latitude.toStringAsFixed(4)}, Lng: ${position.longitude.toStringAsFixed(4)}";
      try {
        List<Placemark> placemarks = await placemarkFromCoordinates(position.latitude, position.longitude);
        if (placemarks.isNotEmpty) {
          Placemark p = placemarks[0];
          placemarkName = "${p.subLocality ?? p.locality ?? p.name}, ${p.administrativeArea ?? p.country}";
          if (placemarkName.startsWith(", ")) placemarkName = placemarkName.substring(2);
        }
      } catch (_) {}
      if (!mounted) return;
      setState(() { _locationStatus = placemarkName; _timeStatus = "Updated just now"; });
    } catch (_) {
      setState(() { _locationStatus = "Unable to get location"; _timeStatus = "Check GPS permissions"; });
    }
  }

  void _triggerSOS(BuildContext context) async {
    try { await const MethodChannel('com.eldercare/focus').invokeMethod('playSiren'); } catch (_) {}
    try { await _emergencyService.triggerSOS(); } catch (_) {}
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('SOS Triggered! Siren is ON.'), backgroundColor: MonitorTheme.red));
  }

  void _stopSOS(BuildContext context) async {
    try { await const MethodChannel('com.eldercare/focus').invokeMethod('stopSiren'); } catch (_) {}
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Siren stopped.'), backgroundColor: Colors.orange));
  }

  void _callContact(String phone) async {
    final Uri phoneUri = Uri(scheme: 'tel', path: phone);
    if (await canLaunchUrl(phoneUri)) await launchUrl(phoneUri);
  }

  void _addContactDialog() {
    final nameCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    showDialog(context: context, builder: (ctx) => AlertDialog(
      backgroundColor: MonitorTheme.bgCardLight,
      title: const Text("Add Contact", style: TextStyle(color: MonitorTheme.textPrimary)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(controller: nameCtrl, style: const TextStyle(color: MonitorTheme.textPrimary), decoration: const InputDecoration(labelText: "Name (e.g. Mom)", labelStyle: TextStyle(color: MonitorTheme.textSec))),
          TextField(controller: phoneCtrl, keyboardType: TextInputType.phone, style: const TextStyle(color: MonitorTheme.textPrimary), decoration: const InputDecoration(labelText: "Phone Number", labelStyle: TextStyle(color: MonitorTheme.textSec))),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancel")),
        ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: MonitorTheme.accent),
          onPressed: () {
            if (nameCtrl.text.isNotEmpty && phoneCtrl.text.isNotEmpty) {
              _emergencyService.addContact(nameCtrl.text, phoneCtrl.text, "Family", null);
              Navigator.pop(ctx);
            }
          },
          child: const Text("Add", style: TextStyle(color: Colors.white)),
        ),
      ],
    ));
  }

  void _confirmDeleteContact(String id, String name) {
    showDialog(context: context, builder: (ctx) => AlertDialog(
      backgroundColor: MonitorTheme.bgCardLight,
      title: const Text("Delete Contact", style: TextStyle(color: MonitorTheme.textPrimary)),
      content: Text("Are you sure you want to remove $name?", style: const TextStyle(color: MonitorTheme.textSec)),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancel")),
        TextButton(onPressed: () { _emergencyService.removeContact(id); Navigator.pop(ctx); }, child: const Text("Delete", style: TextStyle(color: MonitorTheme.red))),
      ],
    ));
  }

  Widget _glass({required Widget child, EdgeInsetsGeometry padding = const EdgeInsets.all(16), double radius = 18}) {
    return Container(padding: padding, decoration: MonitorTheme.glassCard(radius: radius), child: child);
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("Safety", style: TextStyle(fontSize: 32, fontWeight: FontWeight.w800, color: MonitorTheme.textPrimary)),
          const SizedBox(height: 4),
          Text("Your security and emergency tools", style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: MonitorTheme.textTert)),
          const SizedBox(height: 24),

          // Map Card
          _glass(
            padding: EdgeInsets.zero,
            radius: 20,
            child: Column(
              children: [
                Container(
                  height: 180,
                  decoration: BoxDecoration(
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                    gradient: LinearGradient(colors: [const Color(0xFF1A3A2A), const Color(0xFF0F2B3A), MonitorTheme.bgCard]),
                  ),
                  child: Stack(
                    children: [
                      Center(
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(color: MonitorTheme.accent.withOpacity(0.2), shape: BoxShape.circle),
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(color: MonitorTheme.accent, shape: BoxShape.circle, boxShadow: [BoxShadow(color: MonitorTheme.accent.withOpacity(0.4), blurRadius: 12)]),
                            child: const Icon(Icons.location_on, color: Colors.white),
                          ),
                        ),
                      ),
                      Positioned(
                        top: 12, right: 12,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(color: MonitorTheme.bgCard, borderRadius: BorderRadius.circular(20), border: Border.all(color: MonitorTheme.border)),
                          child: Row(
                            children: [
                              Container(width: 6, height: 6, decoration: const BoxDecoration(color: MonitorTheme.green, shape: BoxShape.circle)),
                              const SizedBox(width: 6),
                              const Text("Live", style: TextStyle(color: MonitorTheme.textPrimary, fontWeight: FontWeight.bold, fontSize: 12)),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(_locationStatus, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: MonitorTheme.textPrimary), overflow: TextOverflow.ellipsis),
                            const SizedBox(height: 4),
                            Text(_timeStatus, style: TextStyle(fontSize: 12, color: MonitorTheme.textTert)),
                          ],
                        ),
                      ),
                      ElevatedButton(
                        onPressed: _fetchRealLocation,
                        style: ElevatedButton.styleFrom(backgroundColor: MonitorTheme.accent, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), elevation: 0),
                        child: const Text("Refresh", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),

          const Text("Emergency Actions", style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: MonitorTheme.textPrimary)),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: () => _triggerSOS(context),
                  child: _glass(
                    padding: EdgeInsets.zero,
                    child: Container(
                      height: 120,
                      decoration: BoxDecoration(color: MonitorTheme.red.withOpacity(0.08), borderRadius: BorderRadius.circular(18)),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: MonitorTheme.red.withOpacity(0.2), shape: BoxShape.circle), child: const Icon(Icons.error_outline_rounded, color: MonitorTheme.red)),
                          const SizedBox(height: 12),
                          const Text("Send SOS", style: TextStyle(color: MonitorTheme.red, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: GestureDetector(
                  onTap: () {
                    if (_emergencyService.contacts.isNotEmpty) {
                      _callContact(_emergencyService.contacts.first.phone);
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("No contacts added!")));
                    }
                  },
                  child: _glass(
                    padding: EdgeInsets.zero,
                    child: Container(
                      height: 120,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: MonitorTheme.blue.withOpacity(0.15), shape: BoxShape.circle), child: const Icon(Icons.phone_rounded, color: MonitorTheme.blue)),
                          const SizedBox(height: 12),
                          const Text("Call Contact", style: TextStyle(color: MonitorTheme.textPrimary, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          GestureDetector(
            onTap: () => _stopSOS(context),
            child: _glass(
              padding: EdgeInsets.zero,
              child: Container(
                height: 60, width: double.infinity,
                decoration: BoxDecoration(color: MonitorTheme.orange.withOpacity(0.08), borderRadius: BorderRadius.circular(18)),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: MonitorTheme.orange.withOpacity(0.2), shape: BoxShape.circle), child: const Icon(Icons.volume_off_rounded, color: MonitorTheme.orange)),
                    const SizedBox(width: 12),
                    const Text("Stop Siren", style: TextStyle(color: MonitorTheme.orange, fontWeight: FontWeight.bold, fontSize: 16)),
                  ],
                ),
              ),
            ),
          ),

          const SizedBox(height: 32),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text("Trusted Contacts", style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: MonitorTheme.textPrimary)),
              TextButton(onPressed: _addContactDialog, child: const Text("Add", style: TextStyle(color: MonitorTheme.accent, fontWeight: FontWeight.bold))),
            ],
          ),
          const SizedBox(height: 8),

          if (_emergencyService.contacts.isEmpty)
            Center(child: Padding(padding: const EdgeInsets.all(16), child: Text("No contacts added yet.", style: TextStyle(color: MonitorTheme.textTert)))),

          ..._emergencyService.contacts.map((c) => Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _buildContactCard(c.id, c.name.isNotEmpty ? c.name[0].toUpperCase() : "?", c.name, c.phone, MonitorTheme.accent, true),
          )).toList(),
        ],
      ),
    );
  }

  Widget _buildContactCard(String id, String initial, String name, String phone, Color color, bool available) {
    return _glass(
      child: Row(
        children: [
          Container(
            width: 50, height: 50,
            decoration: BoxDecoration(color: color.withOpacity(0.15), shape: BoxShape.circle),
            child: Center(child: Text(initial, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 18))),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: MonitorTheme.textPrimary)),
                const SizedBox(height: 2),
                Text(phone, style: TextStyle(fontSize: 13, color: MonitorTheme.textTert)),
                const SizedBox(height: 6),
                Row(children: [
                  Container(width: 6, height: 6, decoration: const BoxDecoration(color: MonitorTheme.green, shape: BoxShape.circle)),
                  const SizedBox(width: 6),
                  Text(available ? "Available" : "Busy", style: TextStyle(fontSize: 11, color: MonitorTheme.textTert)),
                ]),
              ],
            ),
          ),
          Row(mainAxisSize: MainAxisSize.min, children: [
            GestureDetector(
              onTap: () => _confirmDeleteContact(id, name),
              child: Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: MonitorTheme.red.withOpacity(0.1), borderRadius: BorderRadius.circular(12)), child: const Icon(Icons.delete_outline_rounded, color: MonitorTheme.red, size: 20)),
            ),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: () => _callContact(phone),
              child: Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: MonitorTheme.accent.withOpacity(0.15), borderRadius: BorderRadius.circular(12)), child: const Icon(Icons.phone_rounded, color: MonitorTheme.accent, size: 20)),
            ),
          ]),
        ],
      ),
    );
  }
}
