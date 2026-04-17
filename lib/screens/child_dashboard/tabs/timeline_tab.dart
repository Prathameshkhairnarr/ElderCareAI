import 'package:flutter/material.dart';
import '../child_theme.dart';

class TimelineTab extends StatelessWidget {
  const TimelineTab({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("Timeline", style: ChildTheme.titleStyle.copyWith(fontSize: 32)),
          const SizedBox(height: 4),
          Text("Recent activity and events", style: ChildTheme.subtitleStyle),
          const SizedBox(height: 24),
          
          _buildTimelineItem("Arrived Home", "2 mins ago", Icons.location_on, ChildTheme.safeGreen),
          _buildTimelineItem("Focus session ended", "2h ago", Icons.psychology, ChildTheme.primaryBlue),
          _buildTimelineItem("Checked in", "3h ago", Icons.check_circle_outline, ChildTheme.safeGreen),
          _buildTimelineItem("Left School", "4h ago", Icons.school, ChildTheme.purpleAcc),
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
                       decoration: BoxDecoration(color: color.withOpacity(0.1), shape: BoxShape.circle),
                       child: Icon(icon, color: color, size: 20),
                    ),
                    const SizedBox(height: 8),
                    Container(width: 2, height: 40, color: ChildTheme.borderLight)
                 ],
              ),
              const SizedBox(width: 16),
              Expanded(
                 child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                       Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: ChildTheme.textPrimary)),
                       const SizedBox(height: 4),
                       Text(time, style: ChildTheme.subtitleStyle),
                    ]
                 )
              )
           ]
        )
     );
  }
}
