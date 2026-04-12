import 'package:flutter/material.dart';
import '../../services/emergency_service.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'dart:convert';

class ContactsScreen extends StatefulWidget {
  const ContactsScreen({super.key});

  @override
  State<ContactsScreen> createState() => _ContactsScreenState();
}

class _ContactsScreenState extends State<ContactsScreen> {
  final _emergencyService = EmergencyService();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = MediaQuery.platformBrightnessOf(context) == Brightness.dark;
    
    final bgGradient = isDark
        ? const [Color(0xFF1A1A2E), Color(0xFF16213E), Color(0xFF0F3460)]
        : [cs.surface, cs.surfaceContainerHighest.withValues(alpha: 0.3), cs.surface];

    return Scaffold(
      appBar: AppBar(
        title: Text('Emergency Contacts', style: TextStyle(color: cs.onSurface)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: cs.onSurface),
        actions: [
          IconButton(
            icon: const Icon(Icons.person_add_rounded),
            onPressed: () => _showAddContactDialog(context),
          ),
        ],
      ),
      backgroundColor: isDark ? const Color(0xFF1A1A2E) : cs.surface,
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: bgGradient,
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: AnimatedBuilder(
          animation: _emergencyService,
          builder: (context, _) {
            final contacts = _emergencyService.contacts;

            if (contacts.isEmpty) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.people_outline_rounded,
                      size: 80,
                      color: cs.onSurface.withValues(alpha: 0.2),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'No Emergency Contacts',
                      style: TextStyle(
                        color: cs.onSurface.withValues(alpha: 0.5),
                        fontSize: 18,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Add people to notify during SOS',
                      style: TextStyle(
                        color: cs.onSurface.withValues(alpha: 0.3),
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton.icon(
                      onPressed: () => _showAddContactDialog(context),
                      icon: const Icon(Icons.add),
                      label: const Text('Add Contact'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: cs.primary,
                        foregroundColor: isDark ? const Color(0xFF1A1A2E) : Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }

            return ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: contacts.length,
              itemBuilder: (context, index) {
                final contact = contacts[index];
                return Dismissible(
                  key: Key(contact.id),
                  background: _buildDeleteBackground(),
                  direction: DismissDirection.endToStart,
                  confirmDismiss: (direction) =>
                      _confirmDelete(context, contact),
                  onDismissed: (direction) {
                    _emergencyService.removeContact(contact.id);
                  },
                  child: Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    color: isDark ? Colors.white.withValues(alpha: 0.08) : cs.surface,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                      side: BorderSide(
                        color: isDark ? Colors.white.withValues(alpha: 0.1) : cs.outline.withValues(alpha: 0.1),
                      ),
                    ),
                    elevation: isDark ? 0 : 2,
                    shadowColor: Colors.black.withValues(alpha: 0.05),
                    child: ListTile(
                      contentPadding: const EdgeInsets.all(16),
                      leading: CircleAvatar(
                        radius: 24,
                        backgroundColor: _getColor(contact.colorIndex).withValues(alpha: 0.2),
                        child: Text(
                          contact.name.isNotEmpty
                              ? contact.name[0].toUpperCase()
                              : '?',
                          style: TextStyle(
                            color: _getColor(contact.colorIndex),
                            fontWeight: FontWeight.bold,
                            fontSize: 20,
                          ),
                        ),
                      ),
                      title: Text(
                        contact.name,
                        style: TextStyle(
                          color: cs.onSurface,
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                        ),
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Icon(
                                Icons.phone_rounded,
                                size: 14,
                                color: cs.onSurface.withValues(alpha: 0.6),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                contact.phone,
                                style: TextStyle(
                                  color: cs.onSurface.withValues(alpha: 0.8),
                                  fontSize: 15,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: _getColor(
                                contact.colorIndex,
                              ).withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              contact.relationship,
                              style: TextStyle(
                                color: _getColor(contact.colorIndex),
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                      trailing: IconButton(
                        icon: const Icon(
                          Icons.delete_outline,
                          color: Colors.redAccent,
                        ),
                        onPressed: () => _confirmAndRemove(context, contact),
                      ),
                    ),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }

  Widget _buildDeleteBackground() {
    return Container(
      alignment: Alignment.centerRight,
      padding: const EdgeInsets.only(right: 20),
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.redAccent.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(16),
      ),
      child: const Icon(
        Icons.delete_forever,
        color: Colors.redAccent,
        size: 32,
      ),
    );
  }

  Color _getColor(int index) {
    final colors = [
      Colors.blueAccent,
      Colors.purpleAccent,
      Colors.orangeAccent,
      Colors.greenAccent,
      Colors.pinkAccent,
    ];
    return colors[index % colors.length];
  }

  Future<bool?> _confirmDelete(
    BuildContext context,
    EmergencyContact contact,
  ) async {
    final cs = Theme.of(context).colorScheme;
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: cs.surface,
        title: Text(
          'Remove Contact?',
          style: TextStyle(color: cs.onSurface),
        ),
        content: Text(
          'Remove ${contact.name} from emergency contacts?',
          style: TextStyle(color: cs.onSurface.withValues(alpha: 0.7)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text(
              'Remove',
              style: TextStyle(color: Colors.redAccent),
            ),
          ),
        ],
      ),
    );
  }

  void _confirmAndRemove(BuildContext context, EmergencyContact contact) async {
    final confirm = await _confirmDelete(context, contact);
    if (confirm == true) {
      _emergencyService.removeContact(contact.id);
    }
  }

  void _showAddContactDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => const AddContactDialog(),
    );
  }
}

class AddContactDialog extends StatefulWidget {
  const AddContactDialog({super.key});

  @override
  State<AddContactDialog> createState() => _AddContactDialogState();
}

class _AddContactDialogState extends State<AddContactDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  String _relationship = 'Son';
  File? _imageFile;

  final _relationships = [
    'Son',
    'Daughter',
    'Doctor',
    'Caregiver',
    'Friend',
    'Other',
  ];

  Future<void> _pickContact() async {
    bool loadingOpen = false;
    try {
      if (await FlutterContacts.requestPermission(readonly: true)) {
        loadingOpen = true;
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (_) => const Center(child: CircularProgressIndicator()),
        );
        
        // Fetch contacts internally to avoid exiting the app and getting killed by OS memory manager
        final contacts = await FlutterContacts.getContacts(withProperties: true);
        
        if (loadingOpen && mounted) {
          Navigator.pop(context);
          loadingOpen = false;
        }

        if (contacts.isNotEmpty && mounted) {
          _showContactPickerSheet(contacts);
        } else if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No contacts found on device')),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Contacts permission is required')),
          );
        }
      }
    } catch (e) {
      if (loadingOpen && mounted) {
        Navigator.pop(context);
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not load contacts: $e')),
        );
      }
    }
  }

  void _showContactPickerSheet(List<Contact> contacts) {
    String searchQuery = '';
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        final cs = Theme.of(context).colorScheme;
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setModalState) {
            final filteredContacts = contacts.where((c) {
              if (c.phones.isEmpty) return false;
              final q = searchQuery.toLowerCase();
              return c.displayName.toLowerCase().contains(q) || 
                     c.phones.any((p) => p.number.replaceAll(RegExp(r'[^0-9+]'), '').contains(q));
            }).toList();

            return DraggableScrollableSheet(
              initialChildSize: 0.8,
              maxChildSize: 0.95,
              minChildSize: 0.5,
              expand: false,
              builder: (context, scrollController) {
                return Container(
                  decoration: BoxDecoration(
                    color: cs.surface,
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                  ),
                  child: Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16.0, 16.0, 16.0, 8.0),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Select Contact',
                              style: TextStyle(
                                color: cs.onSurface,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            CloseButton(color: cs.onSurface, onPressed: () => Navigator.pop(context)),
                          ],
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                        child: TextField(
                          style: TextStyle(color: cs.onSurface),
                          decoration: InputDecoration(
                            hintText: 'Search by name or number...',
                            hintStyle: TextStyle(color: cs.onSurface.withValues(alpha: 0.54)),
                            prefixIcon: Icon(Icons.search, color: cs.primary),
                            filled: true,
                            fillColor: cs.onSurface.withValues(alpha: 0.05),
                            contentPadding: const EdgeInsets.symmetric(vertical: 0),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide.none,
                            ),
                          ),
                          onChanged: (value) {
                            setModalState(() {
                              searchQuery = value;
                            });
                          },
                        ),
                      ),
                      Expanded(
                        child: filteredContacts.isEmpty
                            ? Center(
                                child: Text(
                                  'No contacts found.',
                                  style: TextStyle(color: cs.onSurface.withValues(alpha: 0.54)),
                                ),
                              )
                            : ListView.builder(
                                controller: scrollController,
                                itemCount: filteredContacts.length,
                                itemBuilder: (context, index) {
                                  final c = filteredContacts[index];
                                  
                                  return ListTile(
                                    leading: CircleAvatar(
                                      backgroundColor: cs.primary,
                                      child: Text(
                                        c.displayName.isNotEmpty ? c.displayName[0].toUpperCase() : '?',
                                        style: TextStyle(color: cs.surface, fontWeight: FontWeight.bold),
                                      ),
                                    ),
                                    title: Text(c.displayName, style: TextStyle(color: cs.onSurface)),
                                    subtitle: Text(c.phones.first.number, style: TextStyle(color: cs.onSurface.withValues(alpha: 0.54))),
                                    onTap: () {
                                      Navigator.pop(context);
                                      setState(() {
                                        _nameCtrl.text = c.displayName;
                                        _phoneCtrl.text = c.phones.first.number;
                                      });
                                    },
                                  );
                                },
                              ),
                      ),
                    ],
                  ),
                );
              },
            );
          }
        );
      },
    );
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 200, // Optimize size
      maxHeight: 200,
      imageQuality: 70,
    );
    if (pickedFile != null) {
      setState(() {
        _imageFile = File(pickedFile.path);
      });
    }
  }

  Future<void> _save() async {
    if (_formKey.currentState!.validate()) {
      String? photoBase64;
      if (_imageFile != null) {
        final bytes = await _imageFile!.readAsBytes();
        photoBase64 = base64Encode(bytes);
      }

      await EmergencyService().addContact(
        _nameCtrl.text.trim(),
        _phoneCtrl.text.trim(),
        _relationship,
        photoBase64,
      );
      if (mounted) Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = MediaQuery.platformBrightnessOf(context) == Brightness.dark;

    return AlertDialog(
      backgroundColor: cs.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text('New Contact', style: TextStyle(color: cs.onSurface)),
          IconButton(
            icon: Icon(Icons.contacts_rounded, color: cs.primary),
            onPressed: _pickContact,
            tooltip: 'Pick from Phonebook',
          ),
        ],
      ),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Photo Picker
              GestureDetector(
                onTap: _pickImage,
                child: CircleAvatar(
                  radius: 40,
                  backgroundColor: cs.onSurface.withValues(alpha: 0.1),
                  backgroundImage: _imageFile != null
                      ? FileImage(_imageFile!)
                      : null,
                  child: _imageFile == null
                      ? Icon(
                          Icons.add_a_photo,
                          color: cs.onSurface.withValues(alpha: 0.5),
                          size: 30,
                        )
                      : null,
                ),
              ),
              const SizedBox(height: 16),

              TextFormField(
                controller: _nameCtrl,
                style: TextStyle(color: cs.onSurface),
                decoration: _inputDeco('Full Name', Icons.person, cs),
                validator: (v) => v?.isEmpty == true ? 'Required' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _phoneCtrl,
                style: TextStyle(color: cs.onSurface),
                decoration: _inputDeco('Phone Number', Icons.phone, cs),
                keyboardType: TextInputType.phone,
                validator: (v) => v?.isEmpty == true ? 'Required' : null,
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: _relationship,
                dropdownColor: cs.surface,
                style: TextStyle(color: cs.onSurface),
                decoration: _inputDeco('Relationship', Icons.people, cs),
                items: _relationships
                    .map((r) => DropdownMenuItem(value: r, child: Text(r)))
                    .toList(),
                onChanged: (v) => setState(() => _relationship = v!),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text('Cancel', style: TextStyle(color: cs.onSurface.withValues(alpha: 0.5))),
        ),
        ElevatedButton(
          onPressed: _save,
          style: ElevatedButton.styleFrom(
            backgroundColor: cs.primary,
          ),
          child: Text('Save', style: TextStyle(color: isDark ? const Color(0xFF1A1A2E) : Colors.white)),
        ),
      ],
    );
  }

  InputDecoration _inputDeco(String label, IconData icon, ColorScheme cs) {
    return InputDecoration(
      labelText: label,
      labelStyle: TextStyle(color: cs.onSurface.withValues(alpha: 0.5)),
      prefixIcon: Icon(icon, color: cs.primary, size: 20),
      filled: true,
      fillColor: cs.onSurface.withValues(alpha: 0.05),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
    );
  }
}
