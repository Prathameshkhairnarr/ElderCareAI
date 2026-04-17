import 'package:flutter/material.dart';
import '../../../services/emergency_service.dart';
import '../child_theme.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:url_launcher/url_launcher.dart';

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
    _emergencyService.init(); // ensure loaded
  }

  @override
  void dispose() {
    _emergencyService.removeListener(_onContactsChanged);
    super.dispose();
  }

  void _onContactsChanged() {
    setState(() {});
  }

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
      setState(() {
        _locationStatus = placemarkName;
        _timeStatus = "Updated just now";
      });
    } catch (_) {
      setState(() {
         _locationStatus = "Unable to get location";
         _timeStatus = "Check GPS permissions";
      });
    }
  }

  void _triggerSOS(BuildContext context) async {
    try {
      await const MethodChannel('com.eldercare/focus').invokeMethod('playSiren');
    } catch (_) {}
    try {
      await _emergencyService.triggerSOS();
    } catch (_) {}
    
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('SOS Triggered! Siren is ON.'), backgroundColor: ChildTheme.sosRed),
    );
  }

  void _callContact(String phone) async {
     final Uri phoneUri = Uri(scheme: 'tel', path: phone);
     if (await canLaunchUrl(phoneUri)) {
        await launchUrl(phoneUri);
     }
  }

  void _addContactDialog() {
     final nameCtrl = TextEditingController();
     final phoneCtrl = TextEditingController();
     showDialog(context: context, builder: (ctx) => AlertDialog(
        title: const Text("Add Contact"),
        content: Column(
           mainAxisSize: MainAxisSize.min,
           children: [
              TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: "Name (e.g. Mom)")),
              TextField(controller: phoneCtrl, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: "Phone Number")),
           ]
        ),
        actions: [
           TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancel")),
           ElevatedButton(onPressed: () {
              if (nameCtrl.text.isNotEmpty && phoneCtrl.text.isNotEmpty) {
                 _emergencyService.addContact(nameCtrl.text, phoneCtrl.text, "Family", null);
                 Navigator.pop(ctx);
              }
           }, child: const Text("Add")),
        ]
     ));
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("Safety", style: ChildTheme.titleStyle.copyWith(fontSize: 32)),
          const SizedBox(height: 4),
          Text("Your security and emergency tools", style: ChildTheme.subtitleStyle),
          const SizedBox(height: 24),

          // Map Card Placeholder
          ChildTheme.applyGlass(
            usePadding: false,
            child: Column(
              children: [
                Container(
                  height: 180,
                  decoration: const BoxDecoration(
                    color: Colors.transparent,
                    borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
                  ),
                  child: Stack(
                    children: [
                      Center(
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(color: ChildTheme.primaryBlue.withOpacity(0.2), shape: BoxShape.circle),
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: const BoxDecoration(color: ChildTheme.primaryBlue, shape: BoxShape.circle),
                            child: const Icon(Icons.location_on, color: Colors.white),
                          ),
                        ),
                      ),
                      Positioned(
                        top: 12, right: 12,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 4)]),
                          child: Row(
                            children: [
                              Container(width: 6, height: 6, decoration: const BoxDecoration(color: ChildTheme.safeGreen, shape: BoxShape.circle)),
                              const SizedBox(width: 6),
                              const Text("Live", style: TextStyle(color: ChildTheme.textPrimary, fontWeight: FontWeight.bold, fontSize: 12)),
                            ],
                          ),
                        )
                      )
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(_locationStatus, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: ChildTheme.textPrimary), overflow: TextOverflow.ellipsis),
                            const SizedBox(height: 4),
                            Text(_timeStatus, style: ChildTheme.subtitleStyle.copyWith(fontSize: 12)),
                          ],
                        ),
                      ),
                      ElevatedButton(
                        onPressed: _fetchRealLocation,
                        style: ElevatedButton.styleFrom(backgroundColor: ChildTheme.primaryBlue.withOpacity(0.8), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), elevation: 0),
                        child: const Text("Refresh", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                      )
                    ],
                  ),
                )
              ],
            ),
          ),
          const SizedBox(height: 32),

          Text("Emergency Actions", style: ChildTheme.titleStyle.copyWith(fontSize: 18)),
          const SizedBox(height: 16),
          Row(
             children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () => _triggerSOS(context),
                    child: ChildTheme.applyGlass(
                      usePadding: false,
                      child: Container(
                        height: 120,
                        decoration: BoxDecoration(color: ChildTheme.sosRed.withOpacity(0.1), borderRadius: BorderRadius.circular(16)),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: ChildTheme.sosRed.withOpacity(0.2), shape: BoxShape.circle), child: const Icon(Icons.error_outline_rounded, color: ChildTheme.sosRed)),
                            const SizedBox(height: 12),
                            const Text("Send SOS", style: TextStyle(color: ChildTheme.sosRed, fontWeight: FontWeight.bold)),
                          ],
                        )
                      )
                    )
                  )
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
                    child: ChildTheme.applyGlass(
                      usePadding: false,
                      child: Container(
                        height: 120,
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: ChildTheme.primaryBlue.withOpacity(0.1), shape: BoxShape.circle), child: const Icon(Icons.phone_rounded, color: ChildTheme.primaryBlue)),
                            const SizedBox(height: 12),
                            const Text("Call Contact", style: TextStyle(color: ChildTheme.textPrimary, fontWeight: FontWeight.bold)),
                          ],
                        )
                      )
                    )
                  )
                ),
             ]
          ),

          const SizedBox(height: 32),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text("Trusted Contacts", style: ChildTheme.titleStyle.copyWith(fontSize: 18)),
              TextButton(onPressed: _addContactDialog, child: const Text("Add", style: TextStyle(color: ChildTheme.primaryBlue, fontWeight: FontWeight.bold)))
            ],
          ),
          const SizedBox(height: 8),

          if (_emergencyService.contacts.isEmpty)
             const Center(child: Padding(padding: EdgeInsets.all(16), child: Text("No contacts added yet.", style: TextStyle(color: ChildTheme.textSecondary)))),
          
          ..._emergencyService.contacts.map((c) => Padding(
             padding: const EdgeInsets.only(bottom: 12),
             child: _buildContactCard(c.name.isNotEmpty ? c.name[0].toUpperCase() : "?", c.name, c.phone, ChildTheme.primaryBlue, true)
          )).toList()

        ],
      ),
    );
  }

  Widget _buildContactCard(String initial, String name, String phone, Color color, bool available, {String? subtitleRaw}) {
    return ChildTheme.applyGlass(
      child: Row(
        children: [
          Container(
            width: 50, height: 50,
            decoration: BoxDecoration(color: color.withOpacity(0.1), shape: BoxShape.circle),
            child: Center(child: Text(initial, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 18))),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: ChildTheme.textPrimary)),
                const SizedBox(height: 2),
                Text(phone, style: ChildTheme.subtitleStyle.copyWith(fontSize: 13)),
                const SizedBox(height: 6),
                Row(
                  children: [
                     Container(width: 6, height: 6, decoration: BoxDecoration(color: available ? ChildTheme.safeGreen : ChildTheme.safeGreen, shape: BoxShape.circle)),
                     const SizedBox(width: 6),
                     Text(subtitleRaw ?? (available ? "Available" : "Busy"), style: ChildTheme.subtitleStyle.copyWith(fontSize: 11)),
                  ]
                )
              ],
            ),
          ),
          GestureDetector(
             onTap: () => _callContact(phone),
             child: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: ChildTheme.primaryBlue.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
                child: const Icon(Icons.phone_rounded, color: ChildTheme.primaryBlue, size: 20),
             )
          )
        ],
      ),
    );
  }
}
