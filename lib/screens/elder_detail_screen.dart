import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/alert_model.dart';
import '../models/medication.dart';
import '../services/api_service.dart';
import '../services/prescription_history_service.dart';

class ElderDetailScreen extends StatefulWidget {
  final ElderStatsModel elder;
  const ElderDetailScreen({Key? key, required this.elder}) : super(key: key);
  @override
  State<ElderDetailScreen> createState() => _ElderDetailScreenState();
}

class _ElderDetailScreenState extends State<ElderDetailScreen> {
  // ── Theme ─────────────────────────────────────────────
  static const _bg = Color(0xFF0D0F1F);
  static const _surface = Color(0xFF1A1D2E);
  static const _cardBg = Color(0xFF151829);
  static const _blue = Color(0xFF3B82F6);
  static const _textPri = Colors.white;
  static const _textSec = Color(0xFFB0B3C1);
  static const _green = Color(0xFF22C55E);
  static const _amber = Color(0xFFF59E0B);
  static const _red = Color(0xFFEF4444);
  static const _purple = Color(0xFF8B5CF6);

  final ApiService _api = ApiService();
  bool _isLoading = true;

  // Data
  List<UserMedication> _medications = [];
  Map<String, dynamic>? _healthProfile;
  Map<String, dynamic>? _healthSummary;
  List<PrescriptionRecord> _prescriptions = [];
  List<AlertModel> _allAlerts = [];

  @override
  void initState() {
    super.initState();
    _loadAllData();
  }

  Future<void> _loadAllData() async {
    setState(() => _isLoading = true);
    await Future.wait([
      _loadMedications(),
      _loadHealthProfile(),
      _loadHealthSummary(),
      _loadPrescriptions(),
      _loadAlerts(),
    ]);
    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _loadMedications() async {
    try {
      _medications = await _api.getUserMedications();
    } catch (_) {}
  }

  Future<void> _loadHealthProfile() async {
    try {
      _healthProfile = await _api.getHealthProfile();
    } catch (_) {}
  }

  Future<void> _loadHealthSummary() async {
    try {
      _healthSummary = await _api.getHealthSummary();
    } catch (_) {}
  }

  Future<void> _loadPrescriptions() async {
    try {
      _prescriptions = await PrescriptionHistoryService.getAll();
    } catch (_) {}
  }

  Future<void> _loadAlerts() async {
    try {
      final alerts = await _api.getElderAlerts(widget.elder.id);
      _allAlerts = alerts.isNotEmpty ? alerts : widget.elder.recentAlerts;
    } catch (_) {
      _allAlerts = widget.elder.recentAlerts;
    }
  }

  Color _riskColor(int s) => s < 40 ? _green : (s < 75 ? _amber : _red);
  String _riskLabel(int s) => s < 40 ? 'SAFE' : (s < 75 ? 'WARNING' : 'CRITICAL');

  String _timeAgo(DateTime dt) {
    final d = DateTime.now().difference(dt);
    if (d.inMinutes < 1) return 'just now';
    if (d.inMinutes < 60) return '${d.inMinutes}m ago';
    if (d.inHours < 24) return '${d.inHours}h ago';
    return '${d.inDays}d ago';
  }

  Future<void> _callElder() async {
    final uri = Uri(scheme: 'tel', path: widget.elder.elderPhone.replaceAll(' ', ''));
    if (await canLaunchUrl(uri)) await launchUrl(uri);
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: _blue, behavior: SnackBarBehavior.floating),
    );
  }

  // ── Build ─────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      body: SafeArea(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator(color: _blue))
            : RefreshIndicator(
                onRefresh: _loadAllData,
                color: _blue,
                backgroundColor: _surface,
                child: CustomScrollView(
                  slivers: [
                    SliverToBoxAdapter(child: _buildBackButton()),
                    SliverToBoxAdapter(child: _buildHeader()),
                    SliverToBoxAdapter(child: _buildQuickStats()),
                    SliverToBoxAdapter(child: _buildLocationCard()),
                    SliverToBoxAdapter(child: _buildMedicationsSection()),
                    SliverToBoxAdapter(child: _buildHealthProfileSection()),
                    SliverToBoxAdapter(child: _buildPrescriptionHistory()),
                    SliverToBoxAdapter(child: _buildSosHistory()),
                    SliverToBoxAdapter(child: _buildActivityTimeline()),
                    SliverToBoxAdapter(child: _buildHealthTrends()),
                    const SliverToBoxAdapter(child: SizedBox(height: 32)),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _buildBackButton() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 16, 0),
      child: Row(children: [
        IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: _textSec, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        const Spacer(),
        IconButton(
          icon: const Icon(Icons.refresh_rounded, color: _textSec, size: 22),
          onPressed: _loadAllData,
        ),
      ]),
    );
  }

  // ── 1. Header ─────────────────────────────────────────
  Widget _buildHeader() {
    final rc = _riskColor(widget.elder.riskScore);
    final rl = _riskLabel(widget.elder.riskScore);
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
      child: Row(children: [
        Container(
          width: 64, height: 64,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: rc.withOpacity(0.10),
            border: Border.all(color: rc.withOpacity(0.7), width: 3),
          ),
          child: Center(
            child: Text(
              widget.elder.elderName.isNotEmpty ? widget.elder.elderName[0].toUpperCase() : 'E',
              style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: rc),
            ),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(widget.elder.elderName, style: const TextStyle(color: _textPri, fontSize: 22, fontWeight: FontWeight.w800)),
            const SizedBox(height: 4),
            Text(widget.elder.elderPhone, style: const TextStyle(color: _textSec, fontSize: 13)),
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(color: rc.withOpacity(0.15), borderRadius: BorderRadius.circular(8)),
              child: Text('$rl · ${widget.elder.riskScore}', style: TextStyle(color: rc, fontSize: 11, fontWeight: FontWeight.w800)),
            ),
          ]),
        ),
        GestureDetector(
          onTap: _callElder,
          child: Container(
            width: 44, height: 44,
            decoration: BoxDecoration(color: _green.withOpacity(0.15), shape: BoxShape.circle, border: Border.all(color: _green.withOpacity(0.4))),
            child: const Icon(Icons.phone_rounded, color: _green, size: 22),
          ),
        ),
      ]),
    );
  }

  // ── 2. Quick Stats ────────────────────────────────────
  Widget _buildQuickStats() {
    final lastActive = widget.elder.lastSosAt != null ? _timeAgo(widget.elder.lastSosAt!) : 'No SOS';
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
        decoration: BoxDecoration(color: _cardBg, borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.white.withOpacity(0.05))),
        child: Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
          _quickStat(Icons.shield_rounded, 'Risk Score', '${widget.elder.riskScore}', _riskColor(widget.elder.riskScore)),
          _vertDivider(),
          _quickStat(Icons.notifications_active_rounded, 'Alerts', '${widget.elder.unreadAlertsCount}', _amber),
          _vertDivider(),
          _quickStat(Icons.access_time_rounded, 'Last SOS', lastActive, _red),
        ]),
      ),
    );
  }

  Widget _quickStat(IconData icon, String label, String value, Color c) {
    return Column(children: [
      Icon(icon, color: c, size: 20),
      const SizedBox(height: 6),
      Text(value, style: TextStyle(color: c, fontSize: 16, fontWeight: FontWeight.w800)),
      const SizedBox(height: 2),
      Text(label, style: const TextStyle(color: _textSec, fontSize: 10, fontWeight: FontWeight.w600)),
    ]);
  }

  Widget _vertDivider() => Container(height: 36, width: 0.5, color: Colors.white.withOpacity(0.08));

  // ── 3. Location Card ──────────────────────────────────
  Widget _buildLocationCard() {
    return _sectionCard(
      title: 'Location',
      icon: Icons.location_on_rounded,
      iconColor: _purple,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: _purple.withOpacity(0.05), borderRadius: BorderRadius.circular(12), border: Border.all(color: _purple.withOpacity(0.15))),
          child: Column(children: [
            Icon(Icons.map_rounded, color: _purple.withOpacity(0.4), size: 36),
            const SizedBox(height: 10),
            const Text('Location tracking will be available soon', style: TextStyle(color: _textSec, fontSize: 13)),
            const SizedBox(height: 6),
            Text("Elder's phone syncs location periodically", style: TextStyle(color: _textSec.withOpacity(0.6), fontSize: 11)),
          ]),
        ),
      ]),
    );
  }

  // ── 4. Medications Section ────────────────────────────
  Widget _buildMedicationsSection() {
    return _sectionCard(
      title: 'Medications',
      icon: Icons.medication_rounded,
      iconColor: _blue,
      trailing: GestureDetector(
        onTap: _showAddMedicineModal,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(color: _blue.withOpacity(0.15), borderRadius: BorderRadius.circular(8)),
          child: const Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.add_rounded, color: _blue, size: 16),
            SizedBox(width: 4),
            Text('Add', style: TextStyle(color: _blue, fontSize: 12, fontWeight: FontWeight.w700)),
          ]),
        ),
      ),
      child: _medications.isEmpty
          ? const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Text('No medications on record.', style: TextStyle(color: _textSec, fontSize: 13)),
            )
          : Column(children: _medications.map(_buildMedTile).toList()),
    );
  }

  Widget _buildMedTile(UserMedication med) {
    final dosage = med.dosageValue != null ? '${med.dosageValue}${med.dosageUnit ?? 'mg'}' : '—';
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: _bg, borderRadius: BorderRadius.circular(12)),
      child: Row(children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(color: _blue.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
          child: const Icon(Icons.medication_rounded, color: _blue, size: 18),
        ),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(med.medicine.name, style: const TextStyle(color: _textPri, fontSize: 13, fontWeight: FontWeight.w600)),
          const SizedBox(height: 3),
          Text('$dosage · ${med.frequencyPerDay}x/day${med.timeOfDay != null ? ' · ${med.timeOfDay}' : ''}',
            style: const TextStyle(color: _textSec, fontSize: 11)),
        ])),
        GestureDetector(
          onTap: () => _deleteMedication(med),
          child: Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(color: _red.withOpacity(0.1), shape: BoxShape.circle),
            child: const Icon(Icons.close_rounded, color: _red, size: 14),
          ),
        ),
      ]),
    );
  }

  Future<void> _deleteMedication(UserMedication med) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Remove Medication', style: TextStyle(color: _textPri, fontSize: 16)),
        content: Text('Remove ${med.medicine.name}?', style: const TextStyle(color: _textSec)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel', style: TextStyle(color: _textSec))),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Remove', style: TextStyle(color: _red))),
        ],
      ),
    );
    if (confirm == true) {
      final ok = await _api.deleteUserMedication(med.id);
      if (ok) {
        setState(() => _medications.removeWhere((m) => m.id == med.id));
        _snack('Medication removed');
      } else {
        _snack('Failed to remove medication');
      }
    }
  }

  void _showAddMedicineModal() {
    final searchCtrl = TextEditingController();
    List<Medicine> results = [];
    bool searching = false;
    Timer? debounce;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: _surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) {
          return Padding(
            padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom + 16, left: 20, right: 20, top: 20),
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Add Medicine', style: TextStyle(color: _textPri, fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 14),
              TextField(
                controller: searchCtrl,
                style: const TextStyle(color: _textPri),
                decoration: InputDecoration(
                  hintText: 'Search medicines...',
                  hintStyle: const TextStyle(color: _textSec),
                  prefixIcon: const Icon(Icons.search_rounded, color: _textSec),
                  filled: true, fillColor: _bg,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                ),
                onChanged: (q) {
                  debounce?.cancel();
                  debounce = Timer(const Duration(milliseconds: 400), () async {
                    if (q.length < 2) { setModalState(() => results = []); return; }
                    setModalState(() => searching = true);
                    final r = await _api.searchMedicines(q);
                    setModalState(() { results = r; searching = false; });
                  });
                },
              ),
              const SizedBox(height: 12),
              if (searching) const Center(child: Padding(padding: EdgeInsets.all(16), child: CircularProgressIndicator(color: _blue, strokeWidth: 2))),
              if (!searching && results.isNotEmpty)
                SizedBox(
                  height: 220,
                  child: ListView.builder(
                    itemCount: results.length,
                    itemBuilder: (_, i) {
                      final med = results[i];
                      return ListTile(
                        dense: true,
                        title: Text(med.name, style: const TextStyle(color: _textPri, fontSize: 13)),
                        subtitle: Text(med.manufacturer ?? '', style: const TextStyle(color: _textSec, fontSize: 11)),
                        trailing: const Icon(Icons.add_circle_outline_rounded, color: _blue, size: 20),
                        onTap: () async {
                          Navigator.pop(ctx);
                          await _addMedicine(med);
                        },
                      );
                    },
                  ),
                ),
              if (!searching && results.isEmpty && searchCtrl.text.length >= 2)
                const Padding(padding: EdgeInsets.all(16), child: Text('No medicines found.', style: TextStyle(color: _textSec, fontSize: 13))),
            ]),
          );
        },
      ),
    );
  }

  Future<void> _addMedicine(Medicine med) async {
    final result = await _api.addUserMedication(medicineId: med.id, frequencyPerDay: 1, timeOfDay: 'morning');
    if (result != null) {
      setState(() => _medications.add(result));
      _snack('${med.name} added');
    } else {
      _snack('Failed to add medicine');
    }
  }

  // ── 5. Health Profile Section ─────────────────────────
  Widget _buildHealthProfileSection() {
    final age = _healthProfile?['age']?.toString() ?? '—';
    final weight = _healthProfile?['weight']?.toString() ?? '—';
    final height = _healthProfile?['height']?.toString() ?? '—';
    final blood = _healthProfile?['blood_group']?.toString() ?? '—';
    final conditions = _healthProfile?['conditions']?.toString() ?? 'None';

    return _sectionCard(
      title: 'Health Profile',
      icon: Icons.favorite_rounded,
      iconColor: _red,
      trailing: GestureDetector(
        onTap: _showEditHealthModal,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(color: _green.withOpacity(0.15), borderRadius: BorderRadius.circular(8)),
          child: const Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.edit_rounded, color: _green, size: 14),
            SizedBox(width: 4),
            Text('Edit', style: TextStyle(color: _green, fontSize: 12, fontWeight: FontWeight.w700)),
          ]),
        ),
      ),
      child: Column(children: [
        _profileRow('Age', age, Icons.cake_rounded),
        _profileRow('Weight', weight != '—' ? '$weight kg' : '—', Icons.monitor_weight_rounded),
        _profileRow('Height', height != '—' ? '$height cm' : '—', Icons.height_rounded),
        _profileRow('Blood Group', blood, Icons.bloodtype_rounded),
        _profileRow('Conditions', conditions, Icons.medical_information_rounded),
      ]),
    );
  }

  Widget _profileRow(String label, String value, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(children: [
        Icon(icon, color: _textSec.withOpacity(0.5), size: 16),
        const SizedBox(width: 10),
        Text(label, style: const TextStyle(color: _textSec, fontSize: 12)),
        const Spacer(),
        Text(value, style: const TextStyle(color: _textPri, fontSize: 13, fontWeight: FontWeight.w600)),
      ]),
    );
  }

  void _showEditHealthModal() {
    final weightCtrl = TextEditingController(text: _healthProfile?['weight']?.toString() ?? '');
    final bpCtrl = TextEditingController(text: _healthProfile?['bp']?.toString() ?? '');
    final sugarCtrl = TextEditingController(text: _healthProfile?['sugar']?.toString() ?? '');
    final hrCtrl = TextEditingController(text: _healthProfile?['heart_rate']?.toString() ?? '');

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: _surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom + 20, left: 20, right: 20, top: 20),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          const Text('Update Health Data', style: TextStyle(color: _textPri, fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          _inputField('Weight (kg)', weightCtrl, TextInputType.number),
          const SizedBox(height: 12),
          _inputField('Blood Pressure (e.g. 120/80)', bpCtrl, TextInputType.text),
          const SizedBox(height: 12),
          _inputField('Blood Sugar (mg/dL)', sugarCtrl, TextInputType.number),
          const SizedBox(height: 12),
          _inputField('Heart Rate (bpm)', hrCtrl, TextInputType.number),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: () async {
              final data = <String, dynamic>{};
              if (weightCtrl.text.isNotEmpty) data['weight'] = double.tryParse(weightCtrl.text);
              if (bpCtrl.text.isNotEmpty) data['bp'] = bpCtrl.text;
              if (sugarCtrl.text.isNotEmpty) data['sugar'] = double.tryParse(sugarCtrl.text);
              if (hrCtrl.text.isNotEmpty) data['heart_rate'] = double.tryParse(hrCtrl.text);
              Navigator.pop(ctx);
              if (data.isNotEmpty) {
                final result = await _api.saveHealthProfile(data);
                if (result != null) {
                  _snack('Health profile updated');
                  await _loadHealthProfile();
                  if (mounted) setState(() {});
                } else {
                  _snack('Failed to update profile');
                }
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: _blue, padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
            child: const Text('Save', style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold)),
          ),
        ]),
      ),
    );
  }

  Widget _inputField(String label, TextEditingController ctrl, TextInputType type) {
    return TextField(
      controller: ctrl,
      keyboardType: type,
      style: const TextStyle(color: _textPri, fontSize: 14),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: _textSec, fontSize: 13),
        filled: true, fillColor: _bg,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      ),
    );
  }

  // ── 6. Prescription History ───────────────────────────
  Widget _buildPrescriptionHistory() {
    final recent = _prescriptions.take(5).toList();
    return _sectionCard(
      title: 'Prescription History',
      icon: Icons.description_rounded,
      iconColor: _amber,
      child: recent.isEmpty
          ? const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Text('No prescriptions scanned yet.', style: TextStyle(color: _textSec, fontSize: 13)),
            )
          : Column(children: recent.map((p) => _prescriptionTile(p)).toList()),
    );
  }

  Widget _prescriptionTile(PrescriptionRecord p) {
    final date = DateFormat('MMM d, yyyy').format(p.scannedAt);
    final preview = p.result.length > 60 ? '${p.result.substring(0, 60)}...' : p.result;
    return GestureDetector(
      onTap: () => _showPrescriptionDetail(p),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: _bg, borderRadius: BorderRadius.circular(12)),
        child: Row(children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: _amber.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
            child: const Icon(Icons.receipt_long_rounded, color: _amber, size: 16),
          ),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(date, style: const TextStyle(color: _textPri, fontSize: 12, fontWeight: FontWeight.w600)),
            const SizedBox(height: 3),
            Text(preview, style: const TextStyle(color: _textSec, fontSize: 11), maxLines: 1, overflow: TextOverflow.ellipsis),
          ])),
          const Icon(Icons.chevron_right_rounded, color: _textSec, size: 18),
        ]),
      ),
    );
  }

  void _showPrescriptionDetail(PrescriptionRecord p) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(children: [
          const Icon(Icons.receipt_long_rounded, color: _amber, size: 20),
          const SizedBox(width: 8),
          Text(DateFormat('MMM d, yyyy').format(p.scannedAt), style: const TextStyle(color: _textPri, fontSize: 16)),
        ]),
        content: SingleChildScrollView(
          child: Text(p.result, style: const TextStyle(color: _textSec, fontSize: 13, height: 1.5)),
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close', style: TextStyle(color: _blue)))],
      ),
    );
  }

  // ── 7. SOS History ────────────────────────────────────
  Widget _buildSosHistory() {
    final sosAlerts = _allAlerts.where((a) => a.type.toLowerCase().contains('sos')).toList();
    return _sectionCard(
      title: 'SOS History',
      icon: Icons.emergency_rounded,
      iconColor: _red,
      child: sosAlerts.isEmpty
          ? Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(color: _green.withOpacity(0.05), borderRadius: BorderRadius.circular(12)),
              child: const Row(children: [
                Icon(Icons.check_circle_rounded, color: _green, size: 18),
                SizedBox(width: 10),
                Text('No SOS events recorded', style: TextStyle(color: _green, fontSize: 13)),
              ]),
            )
          : Column(children: sosAlerts.take(5).map((a) {
              final date = DateFormat('MMM d, h:mm a').format(a.createdAt);
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: _red.withOpacity(0.05), borderRadius: BorderRadius.circular(12), border: Border.all(color: _red.withOpacity(0.15))),
                child: Row(children: [
                  const Icon(Icons.warning_amber_rounded, color: _red, size: 18),
                  const SizedBox(width: 10),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(a.title.isNotEmpty ? a.title : 'SOS Triggered', style: const TextStyle(color: _textPri, fontSize: 12, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 2),
                    Text(date, style: const TextStyle(color: _textSec, fontSize: 11)),
                  ])),
                ]),
              );
            }).toList()),
    );
  }

  // ── 8. Activity Timeline ──────────────────────────────
  Widget _buildActivityTimeline() {
    final sorted = List<AlertModel>.from(_allAlerts)..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    final display = sorted.take(10).toList();
    return _sectionCard(
      title: 'Activity Timeline',
      icon: Icons.timeline_rounded,
      iconColor: _blue,
      child: display.isEmpty
          ? const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Text('No recent activity.', style: TextStyle(color: _textSec, fontSize: 13)),
            )
          : Column(children: display.asMap().entries.map((entry) {
              final a = entry.value;
              final isLast = entry.key == display.length - 1;
              return _timelineTile(a, isLast);
            }).toList()),
    );
  }

  Widget _timelineTile(AlertModel a, bool isLast) {
    final isScam = a.type.toLowerCase().contains('scam');
    final isSos = a.type.toLowerCase().contains('sos');
    final isHealth = a.type.toLowerCase().contains('health') || a.type.toLowerCase().contains('med');
    final Color c = isSos ? _red : (isScam ? _amber : (isHealth ? _blue : _purple));
    final IconData icon = isSos ? Icons.emergency_rounded : (isScam ? Icons.shield_rounded : (isHealth ? Icons.favorite_rounded : Icons.info_rounded));

    return IntrinsicHeight(
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        SizedBox(
          width: 28,
          child: Column(children: [
            Container(
              width: 10, height: 10,
              decoration: BoxDecoration(color: c, shape: BoxShape.circle),
            ),
            if (!isLast) Expanded(child: Container(width: 1.5, color: c.withOpacity(0.2))),
          ]),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: c.withOpacity(0.04), borderRadius: BorderRadius.circular(10)),
            child: Row(children: [
              Icon(icon, color: c, size: 16),
              const SizedBox(width: 10),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(a.title.isNotEmpty ? a.title : a.type, style: TextStyle(color: c, fontSize: 12, fontWeight: FontWeight.w600)),
                const SizedBox(height: 2),
                Text(_timeAgo(a.createdAt), style: const TextStyle(color: _textSec, fontSize: 10)),
              ])),
            ]),
          ),
        ),
      ]),
    );
  }

  // ── 9. Health Trends ──────────────────────────────────
  Widget _buildHealthTrends() {
    final score = _healthSummary?['health_score']?.toString() ?? _healthSummary?['score']?.toString();
    final steps = _healthSummary?['steps']?.toString();
    final hr = _healthSummary?['heart_rate']?.toString();
    final spo2 = _healthSummary?['spo2']?.toString();

    return _sectionCard(
      title: 'Health Trends',
      icon: Icons.trending_up_rounded,
      iconColor: _green,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        if (score != null)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [_green.withOpacity(0.08), _blue.withOpacity(0.05)]),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(children: [
              Text(score, style: const TextStyle(color: _green, fontSize: 32, fontWeight: FontWeight.w800)),
              const SizedBox(height: 4),
              const Text('Health Score', style: TextStyle(color: _textSec, fontSize: 12)),
            ]),
          ),
        if (steps != null || hr != null || spo2 != null)
          Row(children: [
            if (steps != null) Expanded(child: _vitalChip('Steps', steps, Icons.directions_walk_rounded, _blue)),
            if (hr != null) ...[const SizedBox(width: 8), Expanded(child: _vitalChip('HR', '$hr bpm', Icons.favorite_rounded, _red))],
            if (spo2 != null) ...[const SizedBox(width: 8), Expanded(child: _vitalChip('SpO₂', '$spo2%', Icons.air_rounded, _purple))],
          ]),
        if (score == null && steps == null && hr == null && spo2 == null)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Text('No health data available yet.', style: TextStyle(color: _textSec, fontSize: 13)),
          ),
        const SizedBox(height: 10),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(color: _blue.withOpacity(0.05), borderRadius: BorderRadius.circular(8)),
          child: const Row(children: [
            Icon(Icons.auto_graph_rounded, color: _blue, size: 16),
            SizedBox(width: 8),
            Text('Detailed graphs coming soon', style: TextStyle(color: _textSec, fontSize: 11)),
          ]),
        ),
      ]),
    );
  }

  Widget _vitalChip(String label, String value, IconData icon, Color c) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: c.withOpacity(0.06), borderRadius: BorderRadius.circular(10)),
      child: Column(children: [
        Icon(icon, color: c, size: 18),
        const SizedBox(height: 6),
        Text(value, style: TextStyle(color: c, fontSize: 12, fontWeight: FontWeight.w700)),
        const SizedBox(height: 2),
        Text(label, style: const TextStyle(color: _textSec, fontSize: 10)),
      ]),
    );
  }

  // ── Shared Section Card ───────────────────────────────
  Widget _sectionCard({required String title, required IconData icon, required Color iconColor, required Widget child, Widget? trailing}) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: _cardBg, borderRadius: BorderRadius.circular(18), border: Border.all(color: Colors.white.withOpacity(0.05))),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(color: iconColor.withOpacity(0.12), borderRadius: BorderRadius.circular(8)),
              child: Icon(icon, color: iconColor, size: 16),
            ),
            const SizedBox(width: 10),
            Text(title, style: const TextStyle(color: _textPri, fontSize: 15, fontWeight: FontWeight.w700)),
            const Spacer(),
            if (trailing != null) trailing,
          ]),
          const SizedBox(height: 14),
          child,
        ]),
      ),
    );
  }
}
