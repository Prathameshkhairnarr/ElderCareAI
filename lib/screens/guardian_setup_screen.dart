import 'package:flutter/material.dart';
import '../models/guardian_model.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';

class GuardianSetupScreen extends StatefulWidget {
  const GuardianSetupScreen({Key? key}) : super(key: key);

  @override
  State<GuardianSetupScreen> createState() => _GuardianSetupScreenState();
}

class _GuardianSetupScreenState extends State<GuardianSetupScreen> {
  final _formKey   = GlobalKey<FormState>();
  final _nameCon   = TextEditingController();
  final _phoneCon  = TextEditingController();
  final _emailCon  = TextEditingController();
  bool _isLoading  = false;
  bool _isPrimary  = false;
  List<GuardianModel> _guardians = [];
  final ApiService _apiService   = ApiService();

  // ── Theme tokens ──────────────────────────────────────────────────────────
  static const _bg      = Color(0xFF0D0F1F);
  static const _surface = Color(0xFF1A1D2E);
  static const _blue    = Color(0xFF3B82F6);
  static const _textPri = Colors.white;
  static const _textSec = Color(0xFFB0B3C1);
  static const _green   = Color(0xFF22C55E);
  static const _amber   = Color(0xFFF59E0B);
  static const _red     = Color(0xFFEF4444);

  // Avatar color cycle for guardian list
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
    _loadGuardians();
  }

  @override
  void dispose() {
    _nameCon.dispose();
    _phoneCon.dispose();
    _emailCon.dispose();
    super.dispose();
  }

  Future<void> _loadGuardians() async {
    setState(() => _isLoading = true);
    final guardians = await _apiService.getGuardians();
    setState(() {
      _guardians = guardians;
      _isLoading = false;
    });
  }

  Future<void> _addGuardian() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    final normalizedPhone = AuthService.normalizePhone(_phoneCon.text);
    final newGuardian = await _apiService.addGuardian(
      _nameCon.text,
      normalizedPhone,
      email: _emailCon.text.isNotEmpty ? _emailCon.text : null,
    );

    if (!mounted) return;
    setState(() => _isLoading = false);

    if (newGuardian != null) {
      _nameCon.clear();
      _phoneCon.clear();
      _emailCon.clear();
      setState(() => _isPrimary = false);
      _loadGuardians();
      _snack('Guardian added successfully', _green);
    } else {
      _snack('Failed to add guardian', _red);
    }
  }

  Future<void> _deleteGuardian(int id, String name) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'Remove Guardian',
          style: TextStyle(color: _textPri, fontWeight: FontWeight.w700),
        ),
        content: Text(
          'Remove $name? They won\'t receive alerts anymore.',
          style: const TextStyle(color: _textSec),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel', style: TextStyle(color: _textSec)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Remove', style: TextStyle(color: _red)),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    setState(() => _isLoading = true);
    final success = await _apiService.deleteGuardian(id);
    if (!mounted) return;
    if (success) {
      _loadGuardians();
    } else {
      setState(() => _isLoading = false);
      _snack('Failed to remove guardian', _red);
    }
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

  // ── Build ─────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _bg,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20, color: _textSec),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Manage Guardians',
          style: TextStyle(
            color: _textPri,
            fontSize: 20,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      body: _isLoading && _guardians.isEmpty
          ? const Center(child: CircularProgressIndicator(color: _blue, strokeWidth: 2.5))
          : SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildInfoBanner(),
                  const SizedBox(height: 24),
                  _buildFormCard(),
                  const SizedBox(height: 28),
                  _buildGuardianList(),
                ],
              ),
            ),
    );
  }

  // ── Info banner ───────────────────────────────────────────────────────────
  Widget _buildInfoBanner() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: _blue.withOpacity(0.1),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _blue.withOpacity(0.25)),
      ),
      child: Row(
        children: [
          Icon(Icons.info_outline_rounded, color: _blue.withOpacity(0.9), size: 18),
          const SizedBox(width: 10),
          const Expanded(
            child: Text(
              'Guardians get instant SOS pings and scam threat alerts.',
              style: TextStyle(color: Color(0xFF93C5FD), fontSize: 13, height: 1.4),
            ),
          ),
        ],
      ),
    );
  }

  // ── Add guardian form ─────────────────────────────────────────────────────
  Widget _buildFormCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.white.withOpacity(0.07)),
      ),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Add New Guardian',
              style: TextStyle(
                color: _textPri,
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 20),

            // Name
            _formField(
              controller: _nameCon,
              label: 'Full Name',
              icon: Icons.person_rounded,
              validator: (v) => v!.trim().isEmpty ? 'Enter a name' : null,
            ),
            const SizedBox(height: 14),

            // Phone
            _formField(
              controller: _phoneCon,
              label: 'Phone Number',
              icon: Icons.phone_rounded,
              keyboard: TextInputType.phone,
              validator: (v) => (v ?? '').length < 10 ? 'Enter valid phone' : null,
            ),
            const SizedBox(height: 14),

            // Email
            _formField(
              controller: _emailCon,
              label: 'Email (Optional)',
              icon: Icons.email_rounded,
              keyboard: TextInputType.emailAddress,
            ),
            const SizedBox(height: 16),

            // Primary guardian toggle
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: _bg,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.white.withOpacity(0.07)),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(7),
                    decoration: BoxDecoration(
                      color: _amber.withOpacity(0.14),
                      borderRadius: BorderRadius.circular(9),
                    ),
                    child: const Icon(Icons.star_rounded, size: 16, color: _amber),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Primary Guardian',
                          style: TextStyle(
                            color: _textPri,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Notified first in emergencies',
                          style: TextStyle(color: _textSec, fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                  Switch(
                    value: _isPrimary,
                    onChanged: (v) => setState(() => _isPrimary = v),
                    activeColor: _blue,
                    activeTrackColor: _blue.withOpacity(0.3),
                    inactiveTrackColor: Colors.white.withOpacity(0.1),
                    inactiveThumbColor: _textSec,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Submit button
            SizedBox(
              height: 50,
              child: ElevatedButton.icon(
                onPressed: _isLoading ? null : _addGuardian,
                icon: _isLoading
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.person_add_rounded, size: 18),
                label: Text(
                  _isLoading ? 'Adding...' : 'Add Guardian',
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _blue,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: _blue.withOpacity(0.4),
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Guardian list ─────────────────────────────────────────────────────────
  Widget _buildGuardianList() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header
        Row(
          children: [
            const Text(
              'Your Guardians',
              style: TextStyle(
                color: _textPri,
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: _blue.withOpacity(0.18),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '${_guardians.length}',
                style: const TextStyle(
                  color: _blue,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),

        // Empty state
        if (_guardians.isEmpty)
          Container(
            padding: const EdgeInsets.symmetric(vertical: 32),
            decoration: BoxDecoration(
              color: _surface,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white.withOpacity(0.06)),
            ),
            child: Column(
              children: [
                Icon(
                  Icons.group_add_rounded,
                  size: 40,
                  color: _textSec.withOpacity(0.4),
                ),
                const SizedBox(height: 10),
                const Text(
                  'No guardians added yet',
                  style: TextStyle(color: _textSec, fontSize: 14),
                ),
              ],
            ),
          )
        else
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _guardians.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (_, i) => _buildGuardianTile(_guardians[i], i),
          ),
      ],
    );
  }

  Widget _buildGuardianTile(GuardianModel g, int index) {
    final color = _avatarColors[index % _avatarColors.length];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: g.isPrimary
              ? _amber.withOpacity(0.4)
              : Colors.white.withOpacity(0.07),
        ),
      ),
      child: Row(
        children: [
          // Colored avatar
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: color.withOpacity(0.14),
            ),
            child: Center(
              child: Text(
                g.name.isNotEmpty ? g.name[0].toUpperCase() : 'G',
                style: TextStyle(
                  color: color,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          const SizedBox(width: 14),

          // Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        g.name,
                        style: const TextStyle(
                          color: _textPri,
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (g.isPrimary) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: _amber.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text(
                          'Primary',
                          style: TextStyle(
                            color: _amber,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 3),
                Row(
                  children: [
                    const Icon(Icons.phone_rounded, size: 11, color: _textSec),
                    const SizedBox(width: 4),
                    Text(
                      g.phone,
                      style: const TextStyle(color: _textSec, fontSize: 12),
                    ),
                  ],
                ),
                if (g.email != null && g.email!.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      const Icon(Icons.email_rounded, size: 11, color: _textSec),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          g.email!,
                          style: const TextStyle(color: _textSec, fontSize: 11),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),

          // Delete
          IconButton(
            icon: const Icon(Icons.delete_outline_rounded, color: _red, size: 20),
            onPressed: () => _deleteGuardian(g.id, g.name),
            splashRadius: 20,
          ),
        ],
      ),
    );
  }

  // ── Reusable form field ───────────────────────────────────────────────────
  Widget _formField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType? keyboard,
    String? Function(String?)? validator,
  }) {
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
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: Colors.white.withOpacity(0.1)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: Colors.white.withOpacity(0.1)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: _blue, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: _red),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: _red, width: 1.5),
        ),
        errorStyle: const TextStyle(color: _red, fontSize: 12),
      ),
    );
  }
}
