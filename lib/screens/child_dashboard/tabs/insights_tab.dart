import 'package:flutter/material.dart';
import '../../../services/child_controls_service.dart';
import '../../../services/digital_wellbeing_service.dart';
import '../child_theme.dart';

class InsightsTab extends StatefulWidget {
  const InsightsTab({Key? key}) : super(key: key);

  @override
  State<InsightsTab> createState() => _InsightsTabState();
}

class _InsightsTabState extends State<InsightsTab> {
  bool _isDaily = true;
  
  @override
  Widget build(BuildContext context) {
    final usedSecs = ChildControlsService().usedSecondsToday;
    final hours = usedSecs ~/ 3600;
    final mins = (usedSecs % 3600) ~/ 60;
    
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("Insights", style: ChildTheme.titleStyle.copyWith(fontSize: 32)),
          const SizedBox(height: 4),
          Text("Your activity and behavior patterns", style: ChildTheme.subtitleStyle),
          const SizedBox(height: 24),

          // Daily/Weekly Toggle
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(color: ChildTheme.primaryBlue.withOpacity(0.05), borderRadius: BorderRadius.circular(16)),
            child: Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => _isDaily = true),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(color: _isDaily ? ChildTheme.primaryBlue : Colors.transparent, borderRadius: BorderRadius.circular(12)),
                      child: Center(child: Text("Daily", style: TextStyle(color: _isDaily ? Colors.white : ChildTheme.textSecondary, fontWeight: FontWeight.bold))),
                    ),
                  ),
                ),
                Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => _isDaily = false),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(color: !_isDaily ? ChildTheme.primaryBlue : Colors.transparent, borderRadius: BorderRadius.circular(12)),
                      child: Center(child: Text("Weekly", style: TextStyle(color: !_isDaily ? Colors.white : ChildTheme.textSecondary, fontWeight: FontWeight.bold))),
                    ),
                  ),
                )
              ],
            ),
          ),
          const SizedBox(height: 24),

          Row(
            children: [
              Expanded(
                child: ChildTheme.applyGlass(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: ChildTheme.textSecondary.withOpacity(0.1), borderRadius: BorderRadius.circular(10)), child: const Icon(Icons.smartphone, color: ChildTheme.textSecondary, size: 20)),
                      const SizedBox(height: 12),
                      Text("Screen Time", style: ChildTheme.subtitleStyle.copyWith(fontSize: 13)),
                      const SizedBox(height: 4),
                      Text("${hours}h ${mins}m", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 22, color: ChildTheme.textPrimary)),
                      const SizedBox(height: 6),
                      Row(
                         children: [
                            const Icon(Icons.trending_down_rounded, color: ChildTheme.safeGreen, size: 16),
                            const SizedBox(width: 4),
                            const Text("-12%", style: TextStyle(color: ChildTheme.safeGreen, fontSize: 12, fontWeight: FontWeight.bold)),
                         ]
                      )
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: ChildTheme.applyGlass(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: ChildTheme.textSecondary.withOpacity(0.1), borderRadius: BorderRadius.circular(10)), child: const Icon(Icons.adjust_rounded, color: ChildTheme.textSecondary, size: 20)),
                      const SizedBox(height: 12),
                      Text("Focus Time", style: ChildTheme.subtitleStyle.copyWith(fontSize: 13)),
                      const SizedBox(height: 4),
                      const Text("2h 45m", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 22, color: ChildTheme.textPrimary)),
                      const SizedBox(height: 6),
                       Row(
                         children: [
                            const Icon(Icons.trending_down_rounded, color: ChildTheme.safeGreen, size: 16),
                            const SizedBox(width: 4),
                            const Text("+18%", style: TextStyle(color: ChildTheme.safeGreen, fontSize: 12, fontWeight: FontWeight.bold)),
                         ]
                      )
                    ],
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 32),
          Text("App Usage (Digital Wellbeing)", style: ChildTheme.titleStyle.copyWith(fontSize: 18)),
          const SizedBox(height: 16),

          FutureBuilder<List<EnrichedAppUsage>>(
            future: DigitalWellbeingService().getTodayUsage(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.hasError) {
                return ChildTheme.applyGlass(
                  child: Column(
                    children: [
                      const Icon(Icons.privacy_tip_outlined, color: ChildTheme.sosRed, size: 48),
                      const SizedBox(height: 12),
                      const Text("Usage Access Required", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      const SizedBox(height: 8),
                      const Text(
                        "Please go to your Android Settings -> Security or Privacy -> Usage Access, and allow ElderCare AI to view app usage.",
                        textAlign: TextAlign.center,
                        style: TextStyle(color: ChildTheme.textSecondary, fontSize: 13),
                      ),
                    ],
                  ),
                );
              }

              final apps = snapshot.data ?? [];
              if (apps.isEmpty) {
                return ChildTheme.applyGlass(
                  child: const Center(child: Text("No app usage recorded today.")),
                );
              }

              return Column(
                children: apps.take(5).map((app) {
                   return Padding(
                     padding: const EdgeInsets.only(bottom: 12),
                     child: ChildTheme.applyGlass(
                       child: Row(
                         children: [
                           if (app.icon != null)
                              ClipRRect(borderRadius: BorderRadius.circular(8), child: Image.memory(app.icon!, width: 40, height: 40))
                           else
                              Container(width: 40, height: 40, decoration: BoxDecoration(color: ChildTheme.primaryBlue.withOpacity(0.1), borderRadius: BorderRadius.circular(8)), child: const Icon(Icons.android, color: ChildTheme.primaryBlue)),
                           const SizedBox(width: 16),
                           Expanded(
                             child: Column(
                               crossAxisAlignment: CrossAxisAlignment.start,
                               children: [
                                 Text(app.appName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: ChildTheme.textPrimary), maxLines: 1, overflow: TextOverflow.ellipsis),
                               ],
                             ),
                           ),
                           Text(
                             "${app.duration.inHours}h ${app.duration.inMinutes % 60}m",
                             style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: ChildTheme.primaryBlue),
                           ),
                         ],
                       ),
                     ),
                   );
                }).toList(),
              );
            },
          ),

          const SizedBox(height: 32),
          Text("Behavior Summary", style: ChildTheme.titleStyle.copyWith(fontSize: 18)),
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
     return ChildTheme.applyGlass(
        child: Column(
           crossAxisAlignment: CrossAxisAlignment.start,
           children: [
              Text(title, style: ChildTheme.subtitleStyle),
              const SizedBox(height: 4),
              Text(mainValue, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: ChildTheme.textPrimary)),
              const SizedBox(height: 6),
              Text(subtext, style: ChildTheme.subtitleStyle.copyWith(fontSize: 12)),
           ],
        )
     );
  }
}
