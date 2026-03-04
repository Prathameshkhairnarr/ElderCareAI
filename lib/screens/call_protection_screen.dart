import 'package:flutter/material.dart';
import '../models/call_models.dart';
import '../services/reputation_service.dart';
import '../services/phone_lookup_service.dart';

class CallProtectionScreen extends StatefulWidget {
  const CallProtectionScreen({super.key});

  @override
  State<CallProtectionScreen> createState() => _CallProtectionScreenState();
}

class _CallProtectionScreenState extends State<CallProtectionScreen> {
  final _phoneController = TextEditingController();
  final _reputationService = ReputationService();
  bool _isLoading = false;
  bool _isLookupLoading = false;
  CallReputation? _reputation;
  Map<String, dynamic>? _stats;
  Map<String, dynamic>? _phoneInfo;

  @override
  void initState() {
    super.initState();
    _fetchStats();
  }

  Future<void> _fetchStats() async {
    final stats = await _reputationService.getReportStats();
    if (mounted) {
      setState(() {
        _stats = stats;
      });
    }
  }

  Future<void> _checkNumber() async {
    final number = _phoneController.text.trim();
    if (number.isEmpty) return;

    setState(() {
      _isLoading = true;
      _reputation = null;
    });

    try {
      final rep = await _reputationService.checkNumber(number);
      if (mounted) {
        setState(() {
          _reputation = rep;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  Future<void> _lookupPhoneInfo() async {
    final number = _phoneController.text.trim();
    if (number.isEmpty) return;

    setState(() {
      _isLookupLoading = true;
      _phoneInfo = null;
    });

    try {
      final info = await PhoneLookupService.lookupNumber(number);
      if (mounted) {
        setState(() {
          _phoneInfo = info;
          _isLookupLoading = false;
        });
        if (info == null) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Unable to check this number right now.')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLookupLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Unable to check this number right now.')),
        );
      }
    }
  }

  Future<void> _reportScam() async {
    final number = _phoneController.text.trim();
    if (number.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a phone number first')),
      );
      return;
    }

    // Show category picker
    final category = await showModalBottomSheet<ScamCategory>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => _ScamCategoryPicker(),
    );

    if (category != null) {
      final success = await _reputationService.reportNumber(number, category);
      if (mounted) {
        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Report submitted. Thank you!')),
          );
          _phoneController.clear();
          setState(() => _reputation = null);
          _fetchStats();
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Failed to submit report')),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Call Protection'),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildStatsHeader(),
            const SizedBox(height: 24),
            Text(
              'Check a Number',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 12),
            _buildCheckCard(),
            if (_isLoading || _isLookupLoading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 20),
                child: Center(child: CircularProgressIndicator()),
              ),
            if (_reputation != null) ...[
              const SizedBox(height: 24),
              _buildReputationResult(),
            ],
            if (_phoneInfo != null) ...[
              const SizedBox(height: 24),
              _buildPhoneInfoCard(),
            ],
            const SizedBox(height: 32),
            _buildSafetyTips(),
          ],
        ),
      ),
    );
  }

  Widget _buildStatsHeader() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF5C6BC0), Color(0xFF3949AB)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          const Icon(Icons.security_rounded, color: Colors.white, size: 40),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Community Shield',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _stats != null 
                    ? 'You have helped identify ${_stats!['total_reports']} scam numbers'
                    : 'Help protect the community by reporting scam calls',
                  style: const TextStyle(color: Colors.white70, fontSize: 13),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCheckCard() {
    return Card(
      elevation: 0,
      color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              controller: _phoneController,
              keyboardType: TextInputType.phone,
              decoration: InputDecoration(
                hintText: 'Enter phone number (e.g. 9876543210)',
                prefixIcon: const Icon(Icons.phone_rounded),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor: Theme.of(context).colorScheme.surface,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: _checkNumber,
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('Check Reputation'),
                  ),
                ),
                const SizedBox(width: 12),
                ElevatedButton(
                  onPressed: _reportScam,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red.withValues(alpha: 0.1),
                    foregroundColor: Colors.red,
                    padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Icon(Icons.report_problem_rounded),
                ),
              ],
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _lookupPhoneInfo,
                icon: const Icon(Icons.manage_search_rounded),
                label: const Text('Lookup Info'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  side: BorderSide(color: Colors.indigo.withValues(alpha: 0.4)),
                  foregroundColor: Colors.indigo,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReputationResult() {
    final rep = _reputation!;
    final color = _getRiskColor(rep.riskLevel);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: color, size: 32),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    rep.riskLevel,
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: color,
                    ),
                  ),
                  Text(
                    'Risk Score: ${rep.riskScore}/100',
                    style: TextStyle(
                      fontSize: 14,
                      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            rep.warningMessage,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 15, height: 1.4),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              'Recommended: ${rep.recommendedAction.toUpperCase().replaceAll('_', ' ')}',
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPhoneInfoCard() {
    final info = _phoneInfo!;
    final isValid = info['valid'] == true;
    final rawCarrier = info['carrier']?.toString().isNotEmpty == true 
        ? info['carrier'] 
        : 'Unknown';
    final carrier = _normalizeCarrier(rawCarrier);
    final lineType = info['line_type']?.toString().isNotEmpty == true 
        ? info['line_type'] 
        : 'Unknown';
    final formattedNumber = info['international_format'] ?? info['number'] ?? '';
    
    // Parse location fields
    final loc = info['location']?.toString() ?? '';
    final country = info['country_name']?.toString() ?? '';

    // Build location: try state+country for Indian numbers
    String location = _buildLocation(loc, '', country, info['number'] ?? '');

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.indigo.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.indigo.withValues(alpha: 0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.info_outline_rounded, color: Colors.indigo, size: 24),
              const SizedBox(width: 10),
              Text(
                'Phone Info',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: Colors.indigo[300],
                ),
              ),
            ],
          ),
          const Divider(height: 24),
          _infoRow(Icons.phone_rounded, 'Number', formattedNumber),
          _infoRow(Icons.cell_tower_rounded, 'Carrier', carrier),
          _infoRow(Icons.location_on_rounded, 'Location', location.isNotEmpty ? location : country),
          _infoRow(Icons.cable_rounded, 'Line Type', _capitalize(lineType)),
          _infoRow(
            isValid ? Icons.check_circle_rounded : Icons.cancel_rounded,
            'Valid',
            isValid ? 'Yes' : 'No',
            valueColor: isValid ? Colors.green : Colors.red,
          ),
        ],
      ),
    );
  }

  Widget _infoRow(IconData icon, String label, String value, {Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Icon(icon, size: 18, color: Colors.grey[500]),
          const SizedBox(width: 10),
          Text(
            '$label: ',
            style: TextStyle(fontSize: 14, color: Colors.grey[500]),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: valueColor ?? Theme.of(context).colorScheme.onSurface,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _capitalize(String s) {
    if (s.isEmpty) return s;
    return s[0].toUpperCase() + s.substring(1).toLowerCase();
  }

  /// Normalize carrier names (handle mergers and rebrandings)
  String _normalizeCarrier(String carrier) {
    final lower = carrier.toLowerCase().trim();
    // Indian carrier mergers/rebrandings
    if (lower == 'idea' || lower == 'vodafone' || lower == 'vodafone idea') {
      return 'Vi (Vodafone Idea)';
    }
    if (lower == 'aircel') return 'Aircel (Closed)';
    if (lower.contains('reliance jio') || lower == 'jio') return 'Jio';
    if (lower.contains('bharti') || lower.contains('airtel')) return 'Airtel';
    if (lower.contains('bsnl')) return 'BSNL';
    if (lower.contains('mtnl')) return 'MTNL';
    return carrier;
  }

  /// Build location string; for Indian numbers, resolve state from prefix
  String _buildLocation(String city, String region, String country, String phoneNumber) {
    // If API provides distinct city/region, use them
    final parts = <String>[];
    if (city.isNotEmpty && city != country && city != region) parts.add(city);
    if (region.isNotEmpty && region != country && !parts.contains(region)) parts.add(region);

    // If we only got "India" everywhere, try to resolve state from number prefix
    if (parts.isEmpty && country.toLowerCase() == 'india') {
      final state = _getIndianState(phoneNumber);
      if (state != null) parts.add(state);
    }

    if (country.isNotEmpty) parts.add(country);
    return parts.isEmpty ? 'Unknown' : parts.join(', ');
  }

  /// Resolve Indian telecom circle (state) from mobile number prefix
  String? _getIndianState(String phone) {
    // Strip country code
    String num = phone.replaceAll(RegExp(r'[^0-9]'), '');
    if (num.startsWith('91') && num.length > 10) num = num.substring(2);
    if (num.startsWith('0')) num = num.substring(1);
    if (num.length < 4) return null;

    final p2 = num.substring(0, 2);

    // Major Indian mobile series to circle mapping
    const circleMap = {
      // 2-digit prefix based
      '70': 'UP',
      '62': 'Assam',
      '63': 'Kerala',
      '64': 'Andhra Pradesh',
      '66': 'Andhra Pradesh',
      '72': 'Maharashtra',
      '73': 'Rajasthan',
      '74': 'Himachal Pradesh',
      '75': 'Madhya Pradesh',
      '76': 'Gujarat',
      '77': 'Uttar Pradesh',
      '78': 'Haryana',
      '79': 'Karnataka',
      '80': 'Karnataka',
      '81': 'Rajasthan',
      '82': 'Delhi',
      '83': 'Gujarat',
      '84': 'West Bengal',
      '85': 'Bihar',
      '86': 'Tamil Nadu',
      '87': 'Maharashtra',
      '88': 'Tamil Nadu',
      '89': 'Madhya Pradesh',
      '90': 'Punjab',
      '91': 'Punjab',
      '92': 'Delhi',
      '93': 'Uttar Pradesh',
      '94': 'Kerala',
      '95': 'Andhra Pradesh',
      '96': 'Tamil Nadu',
      '97': 'Karnataka',
      '98': 'Delhi',
      '99': 'Maharashtra',
    };

    return circleMap[p2];
  }

  Color _getRiskColor(String level) {
    switch (level) {
      case 'HIGH': return Colors.red;
      case 'SUSPICIOUS': return Colors.orange;
      case 'SAFE': return Colors.green;
      default: return Colors.blue;
    }
  }

  Widget _buildSafetyTips() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Safety Tips',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: 12),
        _TipItem(
          icon: Icons.lock_person_rounded,
          text: 'Never share OTP or PIN over a phone call.',
        ),
        _TipItem(
          icon: Icons.timer_rounded,
          text: 'Scammers usually create fake urgency. Stay calm.',
        ),
        _TipItem(
          icon: Icons.support_agent_rounded,
          text: 'Banks will never ask for your password via call.',
        ),
      ],
    );
  }
}

class _ScamCategoryPicker extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Padding(
          padding: EdgeInsets.all(20),
          child: Text(
            'Why are you reporting this number?',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
        ),
        Flexible(
          child: ListView(
            shrinkWrap: true,
            children: ScamCategory.values.map((cat) {
              return ListTile(
                leading: const Icon(Icons.report_rounded),
                title: Text(cat.label),
                onTap: () => Navigator.pop(context, cat),
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: 20),
      ],
    );
  }
}

class _TipItem extends StatelessWidget {
  final IconData icon;
  final String text;

  const _TipItem({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Icon(icon, color: Colors.blue, size: 20),
          const SizedBox(width: 12),
          Expanded(child: Text(text, style: const TextStyle(fontSize: 14))),
        ],
      ),
    );
  }
}
