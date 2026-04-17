import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:math';
import '../models/guardian_model.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';

class GuardianSetupScreen extends StatefulWidget {
  const GuardianSetupScreen({Key? key}) : super(key: key);

  @override
  State<GuardianSetupScreen> createState() => _GuardianSetupScreenState();
}

class _GuardianSetupScreenState extends State<GuardianSetupScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isLoading = false;
  List<GuardianModel> _guardians = [];
  final ApiService _apiService = ApiService();
  late SharedPreferences _prefs;

  // Local preferences cache map for privacy toggles: guardianId -> permissions
  final Map<int, Map<String, bool>> _guardianPrefs = {};

  final List<Map<String, String>> _activityLog = [
    {"time": "Just now", "msg": "System: Guardian setup initialized."},
  ];

  // ── Theme tokens ──
  static const _bg = Color(0xFF0D0F1F);
  static const _surface = Color(0xFF1A1D2E);
  static const _blue = Color(0xFF3B82F6);
  static const _textPri = Colors.white;
  static const _textSec = Color(0xFFB0B3C1);
  static const _green = Color(0xFF22C55E);
  static const _amber = Color(0xFFF59E0B);
  static const _red = Color(0xFFEF4444);

  static const _avatarColors = [
    Color(0xFF3B82F6),
    Color(0xFF8B5CF6),
    Color(0xFF22C55E),
    Color(0xFFF59E0B),
    Color(0xFFEF4444),
    Color(0xFF06B6D4),
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _initData();
  }

  Future<void> _initData() async {
    _prefs = await SharedPreferences.getInstance();
    await _loadGuardians();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadGuardians() async {
    setState(() => _isLoading = true);
    final guardians = await _apiService.getGuardians();
    
    for (var g in guardians) {
      _guardianPrefs[g.id] = {
        'location': _prefs.getBool('g_${g.id}_loc') ?? true,
        'health': _prefs.getBool('g_${g.id}_health') ?? false,
        'sos': _prefs.getBool('g_${g.id}_sos') ?? true,
      };
    }

    // Mock an activity log
    if (guardians.isNotEmpty) {
      _activityLog.insert(0, {
        "time": "2 mins ago",
        "msg": "${guardians.first.name} was pinged for device sync."
      });
    }

    if (mounted) {
      setState(() {
        _guardians = guardians;
        // Sort primary first
        _guardians.sort((a, b) => (b.isPrimary ? 1 : 0).compareTo(a.isPrimary ? 1 : 0));
        _isLoading = false;
      });
    }
  }

  Future<void> _updatePref(int guardianId, String key, bool value) async {
    await _prefs.setBool('g_${guardianId}_$key', value);
    setState(() {
      _guardianPrefs[guardianId]![key] = value;
    });
    final gName = _guardians.firstWhere((g) => g.id == guardianId).name;
    _addLog("Privacy settings updated for $gName");
  }

  void _addLog(String msg) {
    setState(() {
      _activityLog.insert(0, {
        "time": "Just now",
        "msg": msg
      });
    });
  }

  void _snack(String msg, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  void _sendSafePing() {
    HapticFeedback.mediumImpact();
    _snack("Safe ping sent to all Guardians!", _green);
    _addLog("You sent an 'I am Safe' ping.");
  }

  void _inviteChildApp() {
    // Show mock dialog
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Invite to Guardian App', style: TextStyle(color: _textPri)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Your guardians can download the Child Profile App to monitor your safety automatically.',
              style: TextStyle(color: _textSec, fontSize: 13),
            ),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: _bg, borderRadius: BorderRadius.circular(12)),
              child: const Row(
                children: [
                  Icon(Icons.link_rounded, color: _blue, size: 20),
                  SizedBox(width: 8),
                  Expanded(child: Text("https://eldercare.app/invite/123", style: TextStyle(color: _blue, fontSize: 13, decoration: TextDecoration.underline))),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close', style: TextStyle(color: _textSec)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              _snack("Invite link copied!", _blue);
            },
            style: ElevatedButton.styleFrom(backgroundColor: _blue),
            child: const Text('Copy Link', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteGuardian(int id, String name) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Remove Guardian', style: TextStyle(color: _textPri, fontWeight: FontWeight.w700)),
        content: Text('Remove $name? They won\'t receive alerts anymore.', style: const TextStyle(color: _textSec)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel', style: TextStyle(color: _textSec))),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Remove', style: TextStyle(color: _red))),
        ],
      ),
    );
    if (confirm != true) return;

    setState(() => _isLoading = true);
    final success = await _apiService.deleteGuardian(id);
    if (success) {
      _addLog("Guardian $name removed.");
      _loadGuardians();
    } else {
      setState(() => _isLoading = false);
      _snack('Failed to remove guardian', _red);
    }
  }

  void _showAddGuardianSheet() {
    final formKey = GlobalKey<FormState>();
    final nameCon = TextEditingController();
    final phoneCon = TextEditingController();
    final emailCon = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setSheetState) {
            bool sheetLoading = false;

            Future<void> add() async {
              if (!formKey.currentState!.validate()) return;
              setSheetState(() => sheetLoading = true);
              final normalizedPhone = AuthService.normalizePhone(phoneCon.text);
              
              final newGuardian = await _apiService.addGuardian(
                nameCon.text,
                normalizedPhone,
                email: emailCon.text.isNotEmpty ? emailCon.text : null,
              );

              setSheetState(() => sheetLoading = false);
              if (newGuardian != null) {
                Navigator.pop(ctx);
                _snack('Guardian added', _green);
                _addLog("New guardian ${nameCon.text} added.");
                _loadGuardians();
              } else {
                _snack('Failed to add guardian', _red);
              }
            }

            return Container(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
                left: 20,
                right: 20,
                top: 24,
              ),
              decoration: const BoxDecoration(
                color: _surface,
                borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
              ),
              child: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text('Add New Guardian', style: TextStyle(color: _textPri, fontSize: 20, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 20),
                    _formField(controller: nameCon, label: 'Full Name', icon: Icons.person_rounded, validator: (v) => v!.trim().isEmpty ? 'Enter name' : null),
                    const SizedBox(height: 14),
                    _formField(controller: phoneCon, label: 'Phone Number', icon: Icons.phone_rounded, keyboard: TextInputType.phone, validator: (v) => (v ?? '').length < 10 ? 'Enter valid phone' : null),
                    const SizedBox(height: 14),
                    _formField(controller: emailCon, label: 'Email (Optional)', icon: Icons.email_rounded, keyboard: TextInputType.emailAddress),
                    const SizedBox(height: 16),
                    SizedBox(
                      height: 52,
                      child: ElevatedButton(
                        onPressed: sheetLoading ? null : add,
                        style: ElevatedButton.styleFrom(backgroundColor: _blue, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
                        child: sheetLoading 
                          ? const CircularProgressIndicator(color: Colors.white) 
                          : const Text('Add Guardian', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.white)),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }
        );
      }
    );
  }

  Widget _formField({required TextEditingController controller, required String label, required IconData icon, TextInputType? keyboard, String? Function(String?)? validator}) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboard,
      validator: validator,
      style: const TextStyle(color: _textPri, fontSize: 15),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: _textSec, fontSize: 14),
        prefixIcon: Icon(icon, color: _textSec, size: 20),
        filled: true,
        fillColor: _bg,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: Colors.white.withOpacity(0.1))),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: Colors.white.withOpacity(0.1))),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: _blue, width: 1.5)),
      ),
    );
  }

  // ── Tabs Building ─────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _bg,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20, color: _textPri),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Guardian Hub', style: TextStyle(color: _textPri, fontSize: 20, fontWeight: FontWeight.w700)),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: _blue,
          labelColor: _blue,
          unselectedLabelColor: _textSec,
          tabs: const [
            Tab(text: "Guardians"),
            Tab(text: "SOS Rules"),
            Tab(text: "Privacy"),
          ],
        ),
      ),
      body: _isLoading && _guardians.isEmpty
          ? const Center(child: CircularProgressIndicator(color: _blue))
          : TabBarView(
              controller: _tabController,
              children: [
                _buildGuardiansTab(),
                _buildSOSRulesTab(),
                _buildPrivacyTab(),
              ],
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddGuardianSheet,
        backgroundColor: _blue,
        icon: const Icon(Icons.person_add_rounded, color: Colors.white),
        label: const Text("Add Guardian", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
    );
  }

  Widget _buildGuardiansTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Safe Check-in Card
          InkWell(
            onTap: _sendSafePing,
            borderRadius: BorderRadius.circular(20),
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: [_green.withOpacity(0.2), _green.withOpacity(0.05)], begin: Alignment.topLeft, end: Alignment.bottomRight),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: _green.withOpacity(0.3)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.check_circle_rounded, color: _green, size: 36),
                  SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text("Send 'I am Safe' Ping", style: TextStyle(color: _textPri, fontSize: 16, fontWeight: FontWeight.bold)),
                        SizedBox(height: 4),
                        Text("Instantly reassure all guardians.", style: TextStyle(color: _green, fontSize: 13)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),

          // Child App Invite Banner
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: _surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: _blue.withOpacity(0.2)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(color: _blue.withOpacity(0.1), shape: BoxShape.circle),
                  child: const Icon(Icons.phonelink_ring_rounded, color: _blue, size: 24),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text("Guardian Companion App", style: TextStyle(color: _textPri, fontWeight: FontWeight.bold, fontSize: 14)),
                      const SizedBox(height: 2),
                      const Text("Let them monitor via the Child App.", style: TextStyle(color: _textSec, fontSize: 12)),
                    ],
                  ),
                ),
                TextButton(
                  onPressed: _inviteChildApp,
                  child: const Text("Invite", style: TextStyle(color: _blue, fontWeight: FontWeight.bold)),
                )
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Guardians List
          const Text("Active Guardians", style: TextStyle(color: _textPri, fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          
          if (_guardians.isEmpty)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(40.0),
                child: Text("No guardians added yet.", style: TextStyle(color: _textSec)),
              ),
            ),
          
          ..._guardians.asMap().entries.map((entry) {
            final idx = entry.key;
            final g = entry.value;
            final color = _avatarColors[idx % _avatarColors.length];
            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: _surface,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: g.isPrimary ? _amber.withOpacity(0.4) : Colors.white.withOpacity(0.05)),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    backgroundColor: color.withOpacity(0.15),
                    radius: 24,
                    child: Text(g.name[0].toUpperCase(), style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 18)),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(g.name, style: const TextStyle(color: _textPri, fontWeight: FontWeight.bold, fontSize: 16)),
                            if (g.isPrimary) ...[
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(color: _amber.withOpacity(0.15), borderRadius: BorderRadius.circular(6)),
                                child: const Text('Primary', style: TextStyle(color: _amber, fontSize: 10, fontWeight: FontWeight.bold)),
                              ),
                            ]
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(g.phone, style: const TextStyle(color: _textSec, fontSize: 13)),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.delete_outline, color: _red.withOpacity(0.8)),
                    onPressed: () => _deleteGuardian(g.id, g.name),
                  ),
                ],
              ),
            );
          }),
          
          const SizedBox(height: 80), // Padding for FAB
        ],
      ),
    );
  }

  Widget _buildSOSRulesTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text("Emergency Escalation Protocol", style: TextStyle(color: _textPri, fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          const Text("When you trigger an SOS, our system immediately contacts your guardians in this specific order:", style: TextStyle(color: _textSec, fontSize: 14, height: 1.5)),
          const SizedBox(height: 30),
          
          _buildFlowStep(icon: Icons.sos_rounded, color: _red, title: "1. SOS Activated", subtitle: "You tap the SOS button or a severe fall is detected."),
          _buildFlowConnector(),
          _buildFlowStep(icon: Icons.star_rounded, color: _amber, title: "2. Primary Guardian", subtitle: "Immediate Push Alert & SMS sent to Primary Guardian.", isPrimary: true),
          _buildFlowConnector(label: "If no response in 30s"),
          _buildFlowStep(icon: Icons.group_rounded, color: _blue, title: "3. Secondary Guardians", subtitle: "Alert escalated to all other secondary guardians."),
          _buildFlowConnector(label: "If no response in 1 min"),
          _buildFlowStep(icon: Icons.local_hospital_rounded, color: Colors.teal, title: "4. Emergency Services", subtitle: "If configured, 911/Local services are alerted automatically."),
        ],
      ),
    );
  }

  Widget _buildFlowStep({required IconData icon, required Color color, required String title, required String subtitle, bool isPrimary = false}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isPrimary ? _amber.withOpacity(0.3) : Colors.white.withOpacity(0.05)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: color.withOpacity(0.15), shape: BoxShape.circle),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(color: _textPri, fontWeight: FontWeight.bold, fontSize: 15)),
                const SizedBox(height: 4),
                Text(subtitle, style: const TextStyle(color: _textSec, fontSize: 13, height: 1.3)),
              ],
            ),
          )
        ],
      ),
    );
  }

  Widget _buildFlowConnector({String? label}) {
    return Column(
      children: [
        Container(width: 2, height: 15, color: _textSec.withOpacity(0.3)),
        if (label != null)
          Container(
            margin: const EdgeInsets.symmetric(vertical: 4),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(color: _bg, borderRadius: BorderRadius.circular(10), border: Border.all(color: _textSec.withOpacity(0.2))),
            child: Text(label, style: const TextStyle(color: _textSec, fontSize: 11)),
          ),
        Container(width: 2, height: 15, color: _textSec.withOpacity(0.3)),
      ],
    );
  }

  Widget _buildPrivacyTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text("Access Controls", style: TextStyle(color: _textPri, fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          const Text("Decide what information each guardian can see.", style: TextStyle(color: _textSec, fontSize: 14)),
          const SizedBox(height: 20),

          ..._guardians.map((g) {
            final prefs = _guardianPrefs[g.id] ?? {};
            return Container(
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(color: _surface, borderRadius: BorderRadius.circular(16)),
              child: Theme(
                data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                child: ExpansionTile(
                  title: Text(g.name, style: const TextStyle(color: _textPri, fontWeight: FontWeight.bold)),
                  subtitle: const Text("Manage Permissions", style: TextStyle(color: _textSec, fontSize: 12)),
                  children: [
                    _buildToggleRow("Receive SOS Alerts", Icons.sos_rounded, _red, prefs['sos'] ?? true, (val) => _updatePref(g.id, 'sos', val)),
                    _buildToggleRow("Live Location Tracking", Icons.location_on_rounded, _blue, prefs['location'] ?? true, (val) => _updatePref(g.id, 'location', val)),
                    _buildToggleRow("View Health Vitals", Icons.health_and_safety_rounded, _green, prefs['health'] ?? false, (val) => _updatePref(g.id, 'health', val)),
                    const SizedBox(height: 10),
                  ],
                ),
              ),
            );
          }),

          const SizedBox(height: 20),
          const Divider(color: Colors.white10),
          const SizedBox(height: 20),
          
          const Text("Activity Log", style: TextStyle(color: _textPri, fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),

          ..._activityLog.map((log) => Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  margin: const EdgeInsets.only(top: 4),
                  width: 8, height: 8,
                  decoration: const BoxDecoration(color: _blue, shape: BoxShape.circle),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(log["msg"]!, style: const TextStyle(color: Colors.white70, fontSize: 14)),
                      const SizedBox(height: 2),
                      Text(log["time"]!, style: const TextStyle(color: _textSec, fontSize: 11)),
                    ],
                  ),
                ),
              ],
            ),
          )),
          const SizedBox(height: 80),
        ],
      ),
    );
  }

  Widget _buildToggleRow(String title, IconData icon, Color color, bool value, Function(bool) onChanged) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Icon(icon, color: color.withOpacity(0.8), size: 18),
          const SizedBox(width: 12),
          Expanded(child: Text(title, style: const TextStyle(color: Colors.white70, fontSize: 14))),
          Switch(
            value: value,
            onChanged: onChanged,
            activeColor: color,
            activeTrackColor: color.withOpacity(0.3),
            inactiveTrackColor: Colors.white10,
            inactiveThumbColor: _textSec,
          ),
        ],
      ),
    );
  }
}
