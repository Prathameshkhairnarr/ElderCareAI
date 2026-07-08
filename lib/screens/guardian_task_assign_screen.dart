import 'package:flutter/material.dart';
import '../models/task_model.dart';
import '../services/api_service.dart';
import '../models/guardian_model.dart';

class GuardianTaskAssignScreen extends StatefulWidget {
  const GuardianTaskAssignScreen({Key? key}) : super(key: key);

  @override
  _GuardianTaskAssignScreenState createState() => _GuardianTaskAssignScreenState();
}

class _GuardianTaskAssignScreenState extends State<GuardianTaskAssignScreen> {
  final _apiService = ApiService();
  bool _isLoading = false;
  List<Map<String, dynamic>> _templates = [];
  List<TaskModel> _assignedTasks = [];
  
  // Form State
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  String _taskType = 'custom';
  String _iconKey = 'task_default';
  String _recurrence = 'once';
  String _priority = 'normal';
  bool _voiceReminderEnabled = true;
  int _selectedElderId = 1; // Default stub. Ideally, select from guardian's elders

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final templates = await _apiService.getTaskTemplates();
      // Stub guardian ID 1 for now. Retrieve actual from current user.
      final tasksRes = await _apiService.getGuardianAssignedTasks(1);
      
      setState(() {
        _templates = templates;
        if (tasksRes != null && tasksRes['tasks'] != null) {
          _assignedTasks = (tasksRes['tasks'] as List)
              .map((e) => TaskModel.fromJson(e))
              .toList();
        }
      });
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _applyTemplate(Map<String, dynamic> template) {
    setState(() {
      _titleController.text = template['title'];
      _taskType = template['task_type'];
      _iconKey = template['icon_key'];
      _priority = template['priority'];
      if (_priority == 'critical') {
        _voiceReminderEnabled = true;
      }
    });
  }

  Future<void> _submitTask() async {
    if (_titleController.text.trim().isEmpty) return;

    setState(() => _isLoading = true);
    final taskData = {
      'elder_id': _selectedElderId,
      'title': _titleController.text.trim(),
      'task_type': _taskType,
      'description': _descriptionController.text.trim(),
      'icon_key': _iconKey,
      'recurrence': _recurrence,
      'priority': _priority,
      'voice_reminder_enabled': _voiceReminderEnabled,
    };

    final result = await _apiService.createTask(taskData);
    setState(() => _isLoading = false);

    if (result != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Task bhej diya gaya! Elder ko voice reminder milega.')),
      );
      _titleController.clear();
      _descriptionController.clear();
      _loadData();
    }
  }

  Future<void> _deleteTask(int taskId) async {
    // API deletion implementation
    await _loadData();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Assign Tasks')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Quick Add', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  SizedBox(
                    height: 50,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: _templates.length,
                      itemBuilder: (context, index) {
                        final t = _templates[index];
                        return Padding(
                          padding: const EdgeInsets.only(right: 8.0),
                          child: ActionChip(
                            label: Text(t['title']),
                            onPressed: () => _applyTemplate(t),
                            backgroundColor: t['priority'] == 'critical' ? Colors.red.shade100 : null,
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 24),
                  const Text('Create Custom Task', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _titleController,
                    decoration: const InputDecoration(labelText: 'Task Title (e.g. Dawai lo)'),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _descriptionController,
                    decoration: const InputDecoration(labelText: 'Description (optional)'),
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    value: _priority,
                    decoration: const InputDecoration(labelText: 'Priority'),
                    items: const [
                      DropdownMenuItem(value: 'normal', child: Text('Normal')),
                      DropdownMenuItem(value: 'important', child: Text('Important')),
                      DropdownMenuItem(value: 'critical', child: Text('Critical 🔴')),
                    ],
                    onChanged: (v) {
                      setState(() {
                        _priority = v!;
                        if (_priority == 'critical') _voiceReminderEnabled = true;
                      });
                    },
                  ),
                  const SizedBox(height: 16),
                  SwitchListTile(
                    title: const Text('Voice Reminder Enabled'),
                    value: _voiceReminderEnabled,
                    onChanged: (v) => setState(() => _voiceReminderEnabled = v),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _submitTask,
                      child: const Text('Assign Task'),
                    ),
                  ),
                  const SizedBox(height: 32),
                  const Text('Today\'s Assigned Tasks', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  ..._assignedTasks.map((t) => ListTile(
                    title: Text(t.title),
                    subtitle: Text('Status: ${t.status.toUpperCase()} | Priority: ${t.priority}'),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete, color: Colors.red),
                      onPressed: () => _deleteTask(t.id),
                    ),
                  )).toList()
                ],
              ),
            ),
    );
  }
}
