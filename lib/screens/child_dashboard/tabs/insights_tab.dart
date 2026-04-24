import 'package:flutter/material.dart';
import '../../../services/child_controls_service.dart';
import '../../../services/digital_wellbeing_service.dart';
import '../child_main_screen.dart';

class InsightsTab extends StatefulWidget {
  const InsightsTab({Key? key}) : super(key: key);

  @override
  State<InsightsTab> createState() => _InsightsTabState();
}

class _InsightsTabState extends State<InsightsTab> {
  bool _isDaily = true;

  Widget _glass({required Widget child, EdgeInsetsGeometry padding = const EdgeInsets.all(16)}) {
    return Container(padding: padding, decoration: MonitorTheme.glassCard(), child: child);
  }

  @override
  Widget build(BuildContext context) {
    final usedSecs = ChildControlsService().usedSecondsToday;
    final hours = usedSecs ~/ 3600;
    final mins = (usedSecs % 3600) ~/ 60;

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("Insights", style: TextStyle(fontSize: 32, fontWeight: FontWeight.w800, color: MonitorTheme.textPrimary)),
          const SizedBox(height: 4),
          Text("Your activity and behavior patterns", style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: MonitorTheme.textTert)),
          const SizedBox(height: 24),

          // Daily/Weekly Toggle
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(color: Colors.white.withOpacity(0.05), borderRadius: BorderRadius.circular(16), border: Border.all(color: MonitorTheme.border)),
            child: Row(children: [
              Expanded(child: GestureDetector(
                onTap: () => setState(() => _isDaily = true),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(color: _isDaily ? MonitorTheme.accent : Colors.transparent, borderRadius: BorderRadius.circular(12)),
                  child: Center(child: Text("Daily", style: TextStyle(color: _isDaily ? Colors.white : MonitorTheme.textTert, fontWeight: FontWeight.bold))),
                ),
              )),
              Expanded(child: GestureDetector(
                onTap: () => setState(() => _isDaily = false),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(color: !_isDaily ? MonitorTheme.accent : Colors.transparent, borderRadius: BorderRadius.circular(12)),
                  child: Center(child: Text("Weekly", style: TextStyle(color: !_isDaily ? Colors.white : MonitorTheme.textTert, fontWeight: FontWeight.bold))),
                ),
              )),
            ]),
          ),
          const SizedBox(height: 24),

          Row(children: [
            Expanded(child: _glass(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: MonitorTheme.blue.withOpacity(0.15), borderRadius: BorderRadius.circular(10)), child: const Icon(Icons.smartphone, color: MonitorTheme.blue, size: 20)),
                const SizedBox(height: 12),
                Text("Screen Time", style: TextStyle(fontSize: 13, color: MonitorTheme.textTert)),
                const SizedBox(height: 4),
                Text("${hours}h ${mins}m", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 22, color: MonitorTheme.textPrimary)),
                const SizedBox(height: 6),
                const Row(children: [Icon(Icons.trending_down_rounded, color: MonitorTheme.green, size: 16), SizedBox(width: 4), Text("-12%", style: TextStyle(color: MonitorTheme.green, fontSize: 12, fontWeight: FontWeight.bold))]),
              ]),
            )),
            const SizedBox(width: 16),
            Expanded(child: _glass(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: MonitorTheme.purple.withOpacity(0.15), borderRadius: BorderRadius.circular(10)), child: const Icon(Icons.adjust_rounded, color: MonitorTheme.purple, size: 20)),
                const SizedBox(height: 12),
                Text("Focus Time", style: TextStyle(fontSize: 13, color: MonitorTheme.textTert)),
                const SizedBox(height: 4),
                const Text("2h 45m", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 22, color: MonitorTheme.textPrimary)),
                const SizedBox(height: 6),
                const Row(children: [Icon(Icons.trending_up_rounded, color: MonitorTheme.green, size: 16), SizedBox(width: 4), Text("+18%", style: TextStyle(color: MonitorTheme.green, fontSize: 12, fontWeight: FontWeight.bold))]),
              ]),
            )),
          ]),
          const SizedBox(height: 32),

          const Text("App Usage (Digital Wellbeing)", style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: MonitorTheme.textPrimary)),
          const SizedBox(height: 16),
          FutureBuilder<List<EnrichedAppUsage>>(
            future: DigitalWellbeingService().getTodayUsage(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator(color: MonitorTheme.accent));
              if (snapshot.hasError) {
                return _glass(child: Column(children: [
                  const Icon(Icons.privacy_tip_outlined, color: MonitorTheme.red, size: 48),
                  const SizedBox(height: 12),
                  const Text("Usage Access Required", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: MonitorTheme.textPrimary)),
                  const SizedBox(height: 8),
                  Text("Please go to Android Settings -> Security or Privacy -> Usage Access, and allow ElderCare AI to view app usage.", textAlign: TextAlign.center, style: TextStyle(color: MonitorTheme.textTert, fontSize: 13)),
                ]));
              }
              final apps = snapshot.data ?? [];
              if (apps.isEmpty) return _glass(child: Center(child: Text("No app usage recorded today.", style: TextStyle(color: MonitorTheme.textTert))));
              return Column(children: apps.take(5).map((app) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _glass(child: Row(children: [
                  if (app.icon != null) ClipRRect(borderRadius: BorderRadius.circular(8), child: Image.memory(app.icon!, width: 40, height: 40))
                  else Container(width: 40, height: 40, decoration: BoxDecoration(color: MonitorTheme.accent.withOpacity(0.15), borderRadius: BorderRadius.circular(8)), child: const Icon(Icons.android, color: MonitorTheme.accent)),
                  const SizedBox(width: 16),
                  Expanded(child: Text(app.appName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: MonitorTheme.textPrimary), maxLines: 1, overflow: TextOverflow.ellipsis)),
                  Text("${app.duration.inHours}h ${app.duration.inMinutes % 60}m", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: MonitorTheme.accent)),
                ])),
              )).toList());
            },
          ),
          const SizedBox(height: 32),

          const Text("Behavior Summary", style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: MonitorTheme.textPrimary)),
          const SizedBox(height: 16),
          _buildSummaryItem("Screen Time Status", "${ChildControlsService().usedSecondsToday ~/ 60} / ${ChildControlsService().dailyLimitMinutes} mins", "Used vs Allowed Limit"),
          const SizedBox(height: 12),
          _buildSummaryItem("Safety & Triggers", "${ChildControlsService().buildTodayReport().sosCount} SOS Triggers", "Total panic alerts recorded today"),
          const SizedBox(height: 12),
          _buildSummaryItem("Blocked Attempts", "${ChildControlsService().buildTodayReport().blockedWebsiteHits + ChildControlsService().buildTodayReport().blockedAppHits + ChildControlsService().buildTodayReport().blockedNumberEvents} Total blocks", "Sites, apps and contacts blocked"),
        ],
      ),
    );
  }

  Widget _buildSummaryItem(String title, String mainValue, String subtext) {
    return _glass(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(title, style: TextStyle(fontSize: 14, color: MonitorTheme.textTert)),
      const SizedBox(height: 4),
      Text(mainValue, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: MonitorTheme.textPrimary)),
      const SizedBox(height: 6),
      Text(subtext, style: TextStyle(fontSize: 12, color: MonitorTheme.textTert)),
    ]));
  }
}
