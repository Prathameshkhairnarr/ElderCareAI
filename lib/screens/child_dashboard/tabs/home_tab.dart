import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../services/auth_service.dart';
import '../../../services/emergency_service.dart';
import '../../../services/child_controls_service.dart';
import '../child_theme.dart';
import 'package:geolocator/geolocator.dart';

class HomeTab extends StatefulWidget {
  final Function(int) onTabChange;
  
  const HomeTab({Key? key, required this.onTabChange}) : super(key: key);

  @override
  State<HomeTab> createState() => _HomeTabState();
}

class _HomeTabState extends State<HomeTab> {
  static const MethodChannel _focusChannel = MethodChannel('com.eldercare/focus');
  String _childName = "Buddy";
  String _locationText = "Home";
  String _locationSubtext = "Last updated just now";
  
  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  void _loadProfile() {
    final user = AuthService().currentUser;
    if (user != null && user.name.isNotEmpty) {
      setState(() => _childName = user.name.split(' ')[0]);
    }
  }

  Future<void> _triggerSOS() async {
    try {
      await _focusChannel.invokeMethod('playSiren');
    } catch (e) {
      debugPrint("Siren failed: $e");
    }
    
    try {
      await EmergencyService().triggerSOS();
    } catch (e) {
      debugPrint("SOS failed: $e");
    }
    
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Emergency SOS sent & Siren activated!'), backgroundColor: ChildTheme.sosRed),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("Good Morning", style: ChildTheme.subtitleStyle),
          Text(_childName, style: ChildTheme.titleStyle.copyWith(fontSize: 32)),
          const SizedBox(height: 24),
          
          // Location Card
          ChildTheme.applyGlass(
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: ChildTheme.safeGreen.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.location_on_outlined, color: ChildTheme.safeGreen),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("Current Location", style: ChildTheme.subtitleStyle.copyWith(fontSize: 13)),
                      const Text("Home", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: ChildTheme.textPrimary)),
                      const SizedBox(height: 4),
                      Text("Updated 2 mins ago", style: TextStyle(color: ChildTheme.textSecondary.withOpacity(0.8), fontSize: 12)),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: ChildTheme.safeGreen.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    children: [
                      Container(width: 6, height: 6, decoration: const BoxDecoration(color: ChildTheme.safeGreen, shape: BoxShape.circle)),
                      const SizedBox(width: 6),
                      const Text("Safe", style: TextStyle(color: ChildTheme.safeGreen, fontWeight: FontWeight.bold, fontSize: 12)),
                    ],
                  ),
                )
              ],
            ),
          ),
          const SizedBox(height: 24),
          
          // Emergency SOS
          SizedBox(
            width: double.infinity,
            height: 64,
            child: ElevatedButton.icon(
              onPressed: _triggerSOS,
              icon: const Icon(Icons.error_outline_rounded, color: Colors.white, size: 28),
              label: const Text("Emergency SOS", style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
              style: ElevatedButton.styleFrom(
                backgroundColor: ChildTheme.sosRed.withOpacity(0.8), // Semi-transparent for dark mode
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                elevation: 0,
              ),
            ),
          ),
          const SizedBox(height: 32),
          
          Text("Quick Actions", style: ChildTheme.titleStyle.copyWith(fontSize: 18)),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(child: _buildActionBtn(Icons.location_on, "Check\nLocation", ChildTheme.primaryBlue, () => widget.onTabChange(1))),
              const SizedBox(width: 12),
              Expanded(child: _buildActionBtn(Icons.psychology_outlined, "Focus\nMode", ChildTheme.purpleAcc, () => widget.onTabChange(3))),
              const SizedBox(width: 12),
              Expanded(child: _buildActionBtn(Icons.trending_up_rounded, "View\nInsights", ChildTheme.safeGreen, () => widget.onTabChange(4))),
            ],
          ),
          
          const SizedBox(height: 32),
          Text("Today's Summary", style: ChildTheme.titleStyle.copyWith(fontSize: 18)),
          const SizedBox(height: 16),
          
          _buildSummaryCard(
            icon: Icons.smartphone, 
            title: "Screen Time", 
            value: "${(ChildControlsService().usedSecondsToday ~/ 3600)}h ${((ChildControlsService().usedSecondsToday % 3600) ~/ 60)}m", 
            subtitle: "Out of ${ChildControlsService().dailyLimitMinutes ~/ 60}h limit", 
            subColor: ChildTheme.primaryBlue
          ),
          const SizedBox(height: 12),
          _buildSummaryCard(
            icon: Icons.access_time_rounded, 
            title: "Alerts triggering", 
            value: "${ChildControlsService().buildTodayReport().sosCount} alerts", 
            subtitle: "Security events today", 
            subColor: ChildTheme.textSecondary
          ),
          const SizedBox(height: 12),
          _buildSummaryCard(
            icon: Icons.security, 
            title: "Blocked Hits", 
            value: "${ChildControlsService().buildTodayReport().blockedWebsiteHits + ChildControlsService().buildTodayReport().blockedAppHits} blocks", 
            subtitle: "Unwanted content stopped", 
            subColor: ChildTheme.safeGreen
          ),
        ],
      ),
    );
  }

  Widget _buildActionBtn(IconData icon, String label, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: ChildTheme.applyGlass(
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: color.withOpacity(0.1), shape: BoxShape.circle),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(height: 12),
            Text(label, textAlign: TextAlign.center, style: const TextStyle(color: ChildTheme.textPrimary, fontSize: 12, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryCard({required IconData icon, required String title, required String value, required String subtitle, required Color subColor}) {
    return ChildTheme.applyGlass(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: ChildTheme.borderLight.withOpacity(0.5), borderRadius: BorderRadius.circular(12)),
            child: Icon(icon, color: ChildTheme.textSecondary, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: ChildTheme.subtitleStyle.copyWith(fontSize: 13)),
                const SizedBox(height: 2),
                Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: ChildTheme.textPrimary)),
                const SizedBox(height: 6),
                Text(subtitle, style: TextStyle(color: subColor, fontSize: 12, fontWeight: FontWeight.w500)),
              ],
            ),
          )
        ],
      ),
    );
  }
}
