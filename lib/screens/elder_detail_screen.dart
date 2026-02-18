import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/alert_model.dart';
import '../services/api_service.dart';

class ElderDetailScreen extends StatefulWidget {
  final ElderStatsModel elder;

  const ElderDetailScreen({Key? key, required this.elder}) : super(key: key);

  @override
  State<ElderDetailScreen> createState() => _ElderDetailScreenState();
}

class _ElderDetailScreenState extends State<ElderDetailScreen> {
  final ApiService _apiService = ApiService();
  bool _isLoading = true;
  List<AlertModel> _allAlerts = [];

  @override
  void initState() {
    super.initState();
    _loadAlerts();
  }

  Future<void> _loadAlerts() async {
    // Start with recent alerts from the dashboard to show something immediately
    setState(() {
      _allAlerts = widget.elder.recentAlerts;
    });

    try {
      final fullAlerts = await _apiService.getElderAlerts(widget.elder.id);
      if (mounted) {
        setState(() {
          _allAlerts = fullAlerts;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("Error loading full alerts: $e");
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 4,
      child: Scaffold(
        backgroundColor: const Color(0xFFF8F9FA),
        appBar: AppBar(
          backgroundColor: Colors.white,
          foregroundColor: Colors.black,
          elevation: 0,
          title: Text(
            widget.elder.elderName,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          bottom: const TabBar(
            isScrollable: true,
            labelColor: Colors.blue,
            unselectedLabelColor: Colors.grey,
            indicatorColor: Colors.blue,
            tabs: [
              Tab(text: "All Activity"),
              Tab(text: "SOS"),
              Tab(text: "Medical"),
              Tab(text: "Safety"),
            ],
          ),
        ),
        body: _isLoading && _allAlerts.isEmpty
            ? const Center(child: CircularProgressIndicator())
            : TabBarView(
                children: [
                  _buildAlertList(_allAlerts),
                  _buildAlertList(_filterAlerts(_allAlerts, ['sos', 'SOS'])),
                  _buildAlertList(
                    _filterAlerts(_allAlerts, [
                      'vulnerable_user',
                      'health_warning',
                      'med_missed',
                      'medication_reminder',
                    ]),
                  ),
                  _buildAlertList(
                    _filterAlerts(_allAlerts, [
                      'call_fraud',
                      'sms_scam',
                      'sms_fraud',
                      'high_risk',
                      'phishing',
                      'financial_impersonation',
                    ]),
                  ),
                ],
              ),
      ),
    );
  }

  List<AlertModel> _filterAlerts(List<AlertModel> alerts, List<String> types) {
    return alerts.where((alert) {
      final alertType = alert.type.toLowerCase();
      final targetTypes = types.map((t) => t.toLowerCase()).toList();
      return targetTypes.contains(alertType);
    }).toList();
  }

  Widget _buildAlertList(List<AlertModel> alerts) {
    if (alerts.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.check_circle_outline, size: 64, color: Colors.grey[300]),
            const SizedBox(height: 16),
            Text(
              "No alerts in this category",
              style: TextStyle(color: Colors.grey[500], fontSize: 16),
            ),
          ],
        ),
      );
    }

    final dateFormat = DateFormat('MMM d, h:mm a');

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: alerts.length,
      itemBuilder: (context, index) {
        final alert = alerts[index];
        return _buildAlertCard(alert, dateFormat);
      },
    );
  }

  Widget _buildAlertCard(AlertModel alert, DateFormat dateFormat) {
    final type = alert.type.toLowerCase();
    Color severityColor;
    IconData icon;
    String displayTitle;

    switch (type) {
      case 'sos':
        severityColor = Colors.red;
        icon = Icons.warning_amber_rounded;
        displayTitle = "SOS Triggered";
        break;
      case 'vulnerable_user':
      case 'health_warning':
        severityColor = Colors.purple;
        icon = Icons.medical_services_outlined;
        displayTitle = "Health Warning";
        break;
      case 'med_missed':
        severityColor = Colors.purple;
        icon = Icons.medical_services_outlined;
        displayTitle = "Medication Missed";
        break;
      case 'medication_reminder':
        severityColor = Colors.purple;
        icon = Icons.medical_services_outlined;
        displayTitle = "Medication Reminder";
        break;
      case 'call_fraud':
        severityColor = Colors.orange;
        icon = Icons.phone_disabled_rounded;
        displayTitle = "Scam Call Avoided";
        break;
      case 'sms_scam':
      case 'sms_fraud':
      case 'phishing':
        severityColor = Colors.orange;
        icon = Icons.sms_failed_rounded;
        displayTitle = "Scam Alert";
        break;
      case 'financial_impersonation':
        severityColor = Colors.orange;
        icon = Icons.phonelink_lock;
        displayTitle = "Financial Threat";
        break;
      case 'high_risk':
        severityColor = Colors.deepOrange;
        icon = Icons.security;
        displayTitle = "High Risk Detected";
        break;
      default:
        severityColor = Colors.blue;
        icon = Icons.info_outline;
        displayTitle = alert.title.isEmpty ? "Alert" : alert.title;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Theme.of(context).colorScheme.outline.withAlpha(20),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(10),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: severityColor.withAlpha(25),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: severityColor, size: 24),
        ),
        title: Text(
          displayTitle,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (alert.details.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                alert.details,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurface.withAlpha(180),
                ),
              ),
            ],
            const SizedBox(height: 6),
            Text(
              dateFormat.format(alert.createdAt),
              style: TextStyle(
                fontSize: 12,
                color: Theme.of(context).colorScheme.onSurface.withAlpha(100),
              ),
            ),
          ],
        ),
        isThreeLine: alert.details.isNotEmpty,
      ),
    );
  }
}
