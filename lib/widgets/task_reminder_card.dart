import 'package:flutter/material.dart';
import '../models/task_model.dart';

class TaskReminderCard extends StatelessWidget {
  final TaskModel task;
  final VoidCallback onDone;
  final VoidCallback onSnooze;

  const TaskReminderCard({
    Key? key,
    required this.task,
    required this.onDone,
    required this.onSnooze,
  }) : super(key: key);

  IconData _getIcon() {
    switch (task.iconKey) {
      case 'pill':
        return Icons.medical_services;
      case 'water_glass':
        return Icons.local_drink;
      case 'walk':
        return Icons.directions_walk;
      case 'phone_call':
        return Icons.phone;
      case 'food':
        return Icons.restaurant;
      case 'heart_pulse':
        return Icons.favorite;
      default:
        return Icons.task_alt;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 4,
      color: task.priority == 'critical' ? Colors.red.shade50 : Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 30,
                  backgroundColor: Theme.of(context).primaryColor.withOpacity(0.1),
                  child: Icon(
                    _getIcon(),
                    size: 32,
                    color: Theme.of(context).primaryColor,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        task.title,
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (task.description != null && task.description!.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 8.0),
                          child: Text(
                            task.description!,
                            style: const TextStyle(fontSize: 18),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: onSnooze,
                    icon: const Icon(Icons.snooze, size: 28),
                    label: const Text('⏰ Baad mein', style: TextStyle(fontSize: 20)),
                    style: ElevatedButton.styleFrom(
                      foregroundColor: Colors.black87,
                      backgroundColor: Colors.grey.shade200,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: onDone,
                    icon: const Icon(Icons.check_circle, size: 28),
                    label: const Text('✅ Ho gaya', style: TextStyle(fontSize: 20)),
                    style: ElevatedButton.styleFrom(
                      foregroundColor: Colors.white,
                      backgroundColor: Colors.green,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
