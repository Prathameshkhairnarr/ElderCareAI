import 'package:flutter/material.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:permission_handler/permission_handler.dart';
import '../services/api_service.dart';
import '../services/emergency_service.dart';
import '../widgets/sos_button.dart';

class SosScreen extends StatefulWidget {
  const SosScreen({super.key});

  @override
  State<SosScreen> createState() => _SosScreenState();
}

class _SosScreenState extends State<SosScreen> {
  final _api = ApiService();
  final _emergencyService = EmergencyService();
  bool _triggered = false;
  bool _loading = true;

  // Colors for contact avatars
  static const _avatarColors = [
    Color(0xFF42A5F5),
    Color(0xFF26A69A),
    Color(0xFFAB47BC),
    Color(0xFFFF7043),
    Color(0xFF66BB6A),
  ];

  @override
  void initState() {
    super.initState();
    _loadContacts();
    _emergencyService.addListener(_onServiceUpdate);
  }

  @override
  void dispose() {
    _emergencyService.removeListener(_onServiceUpdate);
    super.dispose();
  }

  void _onServiceUpdate() {
    if (mounted) setState(() {});
  }

  Future<void> _loadContacts() async {
    await _emergencyService.init();
    if (mounted) setState(() => _loading = false);
  }

  // ── SOS Trigger ──────────────────────────────────
  void _onSosPressed() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(
              Icons.warning_amber_rounded,
              color: Colors.redAccent,
              size: 28,
            ),
            SizedBox(width: 10),
            Text('Confirm SOS'),
          ],
        ),
        content: Text(
          _emergencyService.contacts.isEmpty
              ? 'No emergency contacts added yet. Add contacts first.'
              : 'This will immediately alert all your emergency contacts and share your location. Continue?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          if (_emergencyService.contacts.isNotEmpty)
            ElevatedButton(
              onPressed: () {
                Navigator.pop(ctx);
                _triggerSos();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text('Send SOS'),
            ),
        ],
      ),
    );
  }

  Future<void> _triggerSos() async {
    // Use EmergencyService for full SOS flow (SMS + backend)
    await _emergencyService.triggerSOS();

    // Also directly sync with backend
    final success = await _api.triggerSos();
    if (!mounted) return;
    setState(
      () => _triggered = success || _emergencyService.lastStatus != null,
    );

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              _triggered ? Icons.check_circle_rounded : Icons.error_rounded,
              color: Colors.white,
              size: 20,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                _triggered
                    ? 'SOS alert sent to ${_emergencyService.contacts.length} contacts!'
                    : 'Failed to send SOS. Please try again.',
              ),
            ),
          ],
        ),
        backgroundColor: _triggered ? const Color(0xFF4CAF50) : Colors.red,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 4),
      ),
    );
  }

  // ── Add Contact from Phone ──────────────────────
  Future<void> _pickContact() async {
    try {
      // 1. Check & Request permission with permission_handler for better control
      var status = await Permission.contacts.status;

      if (status.isPermanentlyDenied) {
        if (!mounted) return;
        _showPermissionSettingsDialog();
        return;
      }

      if (!status.isGranted) {
        status = await Permission.contacts.request();
      }

      if (!status.isGranted) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Contact permission is required to add emergency contacts',
            ),
            behavior: SnackBarBehavior.floating,
          ),
        );
        return;
      }

      // 2. Pick a contact via flutter_contacts
      final contact = await FlutterContacts.openExternalPick();
      if (contact == null || !mounted) return;

      // Get full contact details
      final fullContact = await FlutterContacts.getContact(
        contact.id,
        withProperties: true,
      );
      if (fullContact == null || fullContact.phones.isEmpty) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Selected contact has no phone number'),
            behavior: SnackBarBehavior.floating,
          ),
        );
        return;
      }

      final name = fullContact.displayName;
      final phone = fullContact.phones.first.number;

      // Show relationship picker
      if (!mounted) return;
      final relationship = await _showRelationshipPicker(name);
      if (relationship == null) return;

      // Add via EmergencyService (handles backend + local sync)
      await _emergencyService.addContact(name, phone, relationship, null);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('✅ $name added as emergency contact'),
          backgroundColor: const Color(0xFF2E7D32),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to pick contact: $e'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<String?> _showRelationshipPicker(String contactName) async {
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Relationship to $contactName'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final rel in [
              'Son',
              'Daughter',
              'Spouse',
              'Caregiver',
              'Doctor',
              'Friend',
              'Other',
            ])
              ListTile(
                title: Text(rel),
                leading: Icon(
                  _relationIcon(rel),
                  color: const Color(0xFF4FC3F7),
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                onTap: () => Navigator.pop(ctx, rel),
              ),
          ],
        ),
      ),
    );
  }

  IconData _relationIcon(String rel) {
    switch (rel) {
      case 'Son':
        return Icons.person_rounded;
      case 'Daughter':
        return Icons.person_rounded;
      case 'Spouse':
        return Icons.favorite_rounded;
      case 'Caregiver':
        return Icons.medical_services_rounded;
      case 'Doctor':
        return Icons.local_hospital_rounded;
      case 'Friend':
        return Icons.people_rounded;
      default:
        return Icons.person_outline_rounded;
    }
  }

  void _showPermissionSettingsDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Contacts Permission'),
        content: const Text(
          'Contact permission is permanently denied. Please enable it in app settings to add emergency contacts.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              openAppSettings();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF4FC3F7),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text('Open Settings'),
          ),
        ],
      ),
    );
  }

  // ── Delete Contact ──────────────────────────────
  Future<void> _deleteContact(EmergencyContact contact) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Remove Contact'),
        content: Text('Remove ${contact.name} from emergency contacts?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text('Remove'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    await _emergencyService.removeContact(contact.id);

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${contact.name} removed'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  // ── Build ────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final contacts = _emergencyService.contacts;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Emergency SOS'),
        centerTitle: true,
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      body: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0.0, end: 1.0),
        duration: const Duration(milliseconds: 600),
        curve: Curves.easeOutCubic,
        builder: (context, value, child) {
          return Opacity(
            opacity: value,
            child: Transform.translate(
              offset: Offset(0, 30 * (1 - value)),
              child: child,
            ),
          );
        },
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              const SizedBox(height: 24),
              // SOS button
              Center(child: SosButton(onPressed: _onSosPressed)),
              const SizedBox(height: 20),
              Text(
                'Tap to send emergency alert',
                style: TextStyle(
                  fontSize: 14,
                  color: Theme.of(
                    context,
                  ).colorScheme.onSurface.withValues(alpha: 0.5),
                ),
              ),

              if (_triggered) ...[
                const SizedBox(height: 20),
                TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0.0, end: 1.0),
                  duration: const Duration(milliseconds: 400),
                  builder: (context, value, child) {
                    return Opacity(opacity: value, child: child);
                  },
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFF4CAF50).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: const Color(0xFF4CAF50).withValues(alpha: 0.3),
                      ),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.check_circle_rounded,
                          color: Color(0xFF4CAF50),
                          size: 22,
                        ),
                        SizedBox(width: 10),
                        Text(
                          'Alert sent successfully',
                          style: TextStyle(
                            color: Color(0xFF4CAF50),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],

              const SizedBox(height: 40),

              // Emergency Contacts Header + Add Button
              Row(
                children: [
                  Text(
                    'Emergency Contacts',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                  const Spacer(),
                  if (contacts.length < 5)
                    TextButton.icon(
                      onPressed: _pickContact,
                      icon: const Icon(Icons.add_rounded, size: 20),
                      label: const Text(
                        'Add',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 16),

              // Contact list or empty state
              if (_loading)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(32),
                    child: CircularProgressIndicator(),
                  ),
                )
              else if (contacts.isEmpty)
                _buildEmptyState()
              else
                ...List.generate(
                  contacts.length,
                  (i) => _buildContactCard(contacts[i], i),
                ),

              // Big Add Button at bottom
              if (!_loading && contacts.length < 5) ...[
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: OutlinedButton.icon(
                    onPressed: _pickContact,
                    icon: const Icon(Icons.person_add_rounded, size: 22),
                    label: const Text(
                      'Add Emergency Contact',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF4FC3F7),
                      side: const BorderSide(
                        color: Color(0xFF4FC3F7),
                        width: 2,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: Theme.of(
          context,
        ).colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          Icon(
            Icons.contacts_rounded,
            size: 48,
            color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.3),
          ),
          const SizedBox(height: 16),
          Text(
            'No emergency contacts yet',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Theme.of(
                context,
              ).colorScheme.onSurface.withValues(alpha: 0.5),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Add contacts from your phone to receive SOS alerts',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              color: Theme.of(
                context,
              ).colorScheme.onSurface.withValues(alpha: 0.35),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContactCard(EmergencyContact contact, int index) {
    final color = _avatarColors[contact.colorIndex % _avatarColors.length];

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: Duration(milliseconds: 400 + (index * 120)),
      builder: (context, value, child) {
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(0, 20 * (1 - value)),
            child: child,
          ),
        );
      },
      child: Dismissible(
        key: ValueKey(contact.id),
        direction: DismissDirection.endToStart,
        background: Container(
          alignment: Alignment.centerRight,
          padding: const EdgeInsets.only(right: 24),
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: Colors.red.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(16),
          ),
          child: const Icon(Icons.delete_rounded, color: Colors.red, size: 28),
        ),
        confirmDismiss: (direction) async {
          return await showDialog<bool>(
            context: context,
            builder: (ctx) => AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              title: const Text('Remove Contact'),
              content: Text('Remove ${contact.name}?'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Remove'),
                ),
              ],
            ),
          );
        },
        onDismissed: (_) => _emergencyService.removeContact(contact.id),
        child: Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Theme.of(
              context,
            ).colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: Theme.of(
                context,
              ).colorScheme.outline.withValues(alpha: 0.08),
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Center(
                  child: Text(
                    contact.name.isNotEmpty
                        ? contact.name[0].toUpperCase()
                        : '?',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: color,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      contact.name,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${contact.relationship} · ${contact.phone}',
                      style: TextStyle(
                        fontSize: 13,
                        color: Theme.of(
                          context,
                        ).colorScheme.onSurface.withValues(alpha: 0.5),
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: () => _deleteContact(contact),
                icon: Icon(
                  Icons.close_rounded,
                  color: Theme.of(
                    context,
                  ).colorScheme.onSurface.withValues(alpha: 0.3),
                  size: 20,
                ),
                tooltip: 'Remove',
              ),
            ],
          ),
        ),
      ),
    );
  }
}
