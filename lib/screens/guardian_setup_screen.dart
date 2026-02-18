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
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  bool _isLoading = false;
  List<GuardianModel> _guardians = [];
  final ApiService _apiService = ApiService();

  @override
  void initState() {
    super.initState();
    _loadGuardians();
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

    // Fix: Normalize phone before sending to match AuthService logic
    final normalizedPhone = AuthService.normalizePhone(_phoneController.text);

    final newGuardian = await _apiService.addGuardian(
      _nameController.text,
      normalizedPhone,
      email: _emailController.text.isNotEmpty ? _emailController.text : null,
    );

    if (!mounted) return;
    setState(() => _isLoading = false);

    if (newGuardian != null) {
      _nameController.clear();
      _phoneController.clear();
      _emailController.clear();
      _loadGuardians();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Guardian added successfully')),
      );
    } else {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Failed to add guardian')));
    }
  }

  Future<void> _deleteGuardian(int id) async {
    setState(() => _isLoading = true);
    final success = await _apiService.deleteGuardian(id);
    if (!mounted) return;

    if (success) {
      _loadGuardians();
    } else {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to delete guardian')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Manage Guardians')),
      body: _isLoading && _guardians.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    "Add a trusted person to receive alerts.",
                    style: TextStyle(fontSize: 16, color: Colors.grey),
                  ),
                  const SizedBox(height: 20),
                  Form(
                    key: _formKey,
                    child: Card(
                      elevation: 2,
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          children: [
                            TextFormField(
                              controller: _nameController,
                              decoration: const InputDecoration(
                                labelText: 'Name',
                              ),
                              validator: (v) =>
                                  v!.isEmpty ? 'Enter name' : null,
                            ),
                            TextFormField(
                              controller: _phoneController,
                              decoration: const InputDecoration(
                                labelText:
                                    'Phone Number (linked to their account)',
                              ),
                              keyboardType: TextInputType.phone,
                              validator: (v) =>
                                  v!.length < 10 ? 'Enter valid phone' : null,
                            ),
                            TextFormField(
                              controller: _emailController,
                              decoration: const InputDecoration(
                                labelText: 'Email (Optional)',
                              ),
                              keyboardType: TextInputType.emailAddress,
                            ),
                            const SizedBox(height: 20),
                            ElevatedButton(
                              onPressed: _isLoading ? null : _addGuardian,
                              child: const Text('Add Guardian'),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    "Your Guardians",
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 10),
                  ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _guardians.length,
                    itemBuilder: (context, index) {
                      final g = _guardians[index];
                      return Card(
                        child: ListTile(
                          leading: const CircleAvatar(
                            child: Icon(Icons.person),
                          ),
                          title: Text(g.name),
                          subtitle: Text(g.phone),
                          trailing: IconButton(
                            icon: const Icon(Icons.delete, color: Colors.red),
                            onPressed: () => _deleteGuardian(g.id),
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
    );
  }
}
