import 'package:flutter/material.dart';
import '../child_main_screen.dart';

class TimelineTab extends StatelessWidget {
  const TimelineTab({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("Timeline", style: TextStyle(fontSize: 32, fontWeight: FontWeight.w800, color: MonitorTheme.textPrimary)),
          const SizedBox(height: 4),
          Text("Recent activity and events", style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: MonitorTheme.textTert)),
          const SizedBox(height: 24),
          
          _buildTimelineItem("Arrived Home", "2 mins ago", Icons.location_on, MonitorTheme.green),
          _buildTimelineItem("Focus session ended", "2h ago", Icons.psychology, MonitorTheme.blue),
          _buildTimelineItem("Checked in", "3h ago", Icons.check_circle_outline, MonitorTheme.green),
          _buildTimelineItem("Left School", "4h ago", Icons.school, MonitorTheme.purple),
        ],
      ),
    );
  }

  Widget _buildTimelineItem(String title, String time, IconData icon, Color color) {
     return Padding(
        padding: const EdgeInsets.only(bottom: 24),
        child: Row(
           crossAxisAlignment: CrossAxisAlignment.start,
           children: [
              Column(
                 children: [
                    Container(
                       padding: const EdgeInsets.all(10),
                       decoration: BoxDecoration(color: color.withOpacity(0.15), shape: BoxShape.circle),
                       child: Icon(icon, color: color, size: 20),
                    ),
                    const SizedBox(height: 8),
                    Container(width: 2, height: 40, color: MonitorTheme.border)
                 ],
              ),
              const SizedBox(width: 16),
              Expanded(
                 child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                       Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: MonitorTheme.textPrimary)),
                       const SizedBox(height: 4),
                       Text(time, style: TextStyle(fontSize: 14, color: MonitorTheme.textTert)),
                    ]
                 )
              )
           ]
        )
     );
  }
}
