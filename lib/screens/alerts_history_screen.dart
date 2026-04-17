import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/api_service.dart';
import 'package:intl/intl.dart';

class AlertsHistoryScreen extends StatefulWidget {
  const AlertsHistoryScreen({super.key});

  @override
  State<AlertsHistoryScreen> createState() => _AlertsHistoryScreenState();
}

class _AlertsHistoryScreenState extends State<AlertsHistoryScreen> {
  final _api = ApiService();
  bool _isLoading = true;
  List<dynamic> _alerts = [];

  @override
  void initState() {
    super.initState();
    _fetchAlerts();
  }

  Future<void> _fetchAlerts() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      // 1. Load backend alerts
      final backendAlerts = await _api.getAlerts() ?? [];

      // 2. Load locally saved scam alerts
      List<Map<String, dynamic>> localAlerts = [];
      try {
        final prefs = await SharedPreferences.getInstance();
        final localEntries = prefs.getStringList('local_safety_alerts') ?? [];
        for (final entry in localEntries) {
          try {
            final json = jsonDecode(entry) as Map<String, dynamic>;
            // Add a flag to distinguish local alerts (no backend ID)
            json['id'] = null;
            localAlerts.add(json);
          } catch (_) {}
        }
      } catch (_) {}

      // 3. Merge: local + backend, dedup by title similarity
      final seen = <String>{};
      final merged = <dynamic>[];

      // Backend alerts first (they have IDs for delete operations)
      for (final alert in backendAlerts) {
        final key = '${alert['title']}_${alert['alert_type']}';
        seen.add(key);
        merged.add(alert);
      }

      // Then local alerts (only if not already from backend)
      for (final alert in localAlerts) {
        final key = '${alert['title']}_${alert['alert_type']}';
        if (!seen.contains(key)) {
          merged.add(alert);
        }
      }

      // Sort by created_at descending (newest first)
      merged.sort((a, b) {
        final dateA = DateTime.tryParse(a['created_at'] ?? '') ?? DateTime(2000);
        final dateB = DateTime.tryParse(b['created_at'] ?? '') ?? DateTime(2000);
        return dateB.compareTo(dateA);
      });

      if (mounted) {
        setState(() {
          _alerts = merged;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _deleteAlert(dynamic alertId, int index) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Alert'),
        content: const Text('Kya aap sure hain ki aap is alert ko delete karna chahte hain?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    if (alertId == null) {
      // Local-only alert — remove from SharedPreferences
      try {
        final prefs = await SharedPreferences.getInstance();
        final localEntries = prefs.getStringList('local_safety_alerts') ?? [];
        // Find and remove the matching entry by index in merged list
        final alertData = _alerts[index];
        localEntries.removeWhere((entry) {
          try {
            final json = jsonDecode(entry);
            return json['title'] == alertData['title'] &&
                json['created_at'] == alertData['created_at'];
          } catch (_) {
            return false;
          }
        });
        await prefs.setStringList('local_safety_alerts', localEntries);
      } catch (_) {}

      if (mounted) {
        setState(() => _alerts.removeAt(index));
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Alert deleted successfully')),
        );
      }
    } else {
      // Backend alert — use API
      final success = await _api.deleteAlert(alertId);
      if (mounted) {
        if (success) {
          setState(() => _alerts.removeAt(index));
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Alert deleted successfully')),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Failed to delete alert')),
          );
        }
      }
    }
  }

  Color _getSeverityColor(String severity) {
    switch (severity.toLowerCase()) {
      case 'critical':
        return Colors.red;
      case 'high':
        return Colors.orange;
      case 'medium':
        return Colors.amber;
      default:
        return Colors.blue;
    }
  }

  IconData _getAlertIcon(String type) {
    switch (type.toLowerCase()) {
      case 'sos':
      case 'emergency':
        return Icons.emergency_rounded;
      case 'sms_fraud':
      case 'scam':
        return Icons.sms_failed_rounded;
      case 'call_fraud':
      case 'voice_fraud':
        return Icons.phone_disabled_rounded;
      case 'health_warning':
        return Icons.monitor_heart_rounded;
      default:
        return Icons.info_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Safety Alerts'), centerTitle: true),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _alerts.isEmpty
          ? _buildEmptyState()
          : RefreshIndicator(
              onRefresh: _fetchAlerts,
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: _alerts.length,
                itemBuilder: (context, index) {
                  final alert = _alerts[index];
                  final color = _getSeverityColor(alert['severity']);
                  final icon = _getAlertIcon(alert['alert_type']);
                  final date = DateTime.parse(alert['created_at']);

                  return Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                      side: BorderSide(color: color.withOpacity(0.2)),
                    ),
                    elevation: 0,
                    color: color.withOpacity(0.05),
                    child: ExpansionTile(
                      shape: const RoundedRectangleBorder(
                        side: BorderSide.none,
                      ),
                      leading: CircleAvatar(
                        backgroundColor: color.withOpacity(0.1),
                        child: Icon(icon, color: color),
                      ),
                      title: Text(
                        alert['title'],
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: Text(
                        DateFormat('MMM d, h:mm a').format(date),
                        style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                      ),
                      children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Divider(),
                              const SizedBox(height: 8),
                              Text(
                                alert['details'],
                                style: const TextStyle(height: 1.5),
                              ),
                              const SizedBox(height: 12),
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: color.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      'Severity: ${alert['severity'].toUpperCase()}',
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                        color: color,
                                      ),
                                    ),
                                  ),
                                  const Spacer(),
                                  IconButton(
                                    onPressed: () => _deleteAlert(alert['id'], index),
                                    icon: const Icon(Icons.delete_outline_rounded),
                                    color: Colors.red[400],
                                    tooltip: 'Delete Alert',
                                    style: IconButton.styleFrom(
                                      backgroundColor: Colors.red.withOpacity(0.1),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.verified_user_rounded, size: 80, color: Colors.green[200]),
          const SizedBox(height: 16),
          const Text(
            'No Alerts Detected',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text(
            'You\'re secure and protected.',
            style: TextStyle(color: Colors.grey),
          ),
        ],
      ),
    );
  }
}
