import 'package:flutter/material.dart';
import '../../../services/child_controls_service.dart';
import '../child_theme.dart';
import 'package:flutter/services.dart';

class FocusTab extends StatefulWidget {
  const FocusTab({Key? key}) : super(key: key);

  @override
  State<FocusTab> createState() => _FocusTabState();
}

class _FocusTabState extends State<FocusTab> {
  static const MethodChannel _focusChannel = MethodChannel('com.eldercare/focus');
  bool _isFocusMode = false;
  
  bool _mockSchedule1 = true;
  bool _mockSchedule2 = true;
  bool _mockSchedule3 = false;

  void _toggleFocusMode() async {
    if (_isFocusMode) {
      try {
        await _focusChannel.invokeMethod('stopLockTask');
        setState(() => _isFocusMode = false);
      } catch (_) {}
    } else {
      try {
        await _focusChannel.invokeMethod('startLockTask');
        setState(() => _isFocusMode = true);
        await ChildControlsService().addEvent('Manual Focus Mode Started');
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Screen Pinning not supported or disabled in settings.")));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("Focus Mode", style: ChildTheme.titleStyle.copyWith(fontSize: 32)),
          const SizedBox(height: 4),
          Text("Minimize distractions and stay productive", style: ChildTheme.subtitleStyle),
          const SizedBox(height: 24),

          // Main Focus Card
          ChildTheme.applyGlass(
            child: Column(
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(color: ChildTheme.textPrimary.withOpacity(0.05), borderRadius: BorderRadius.circular(12)),
                      child: const Icon(Icons.psychology_outlined, color: ChildTheme.textPrimary, size: 28),
                    ),
                    const SizedBox(width: 16),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text("Focus Mode", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: ChildTheme.textPrimary)),
                        const SizedBox(height: 4),
                        Text(_isFocusMode ? "Currently focusing" : "Start focusing", style: ChildTheme.subtitleStyle),
                      ],
                    )
                  ],
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  height: 54,
                  child: ElevatedButton(
                    onPressed: _toggleFocusMode,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _isFocusMode ? ChildTheme.sosRed.withOpacity(0.1) : ChildTheme.primaryBlue.withOpacity(0.05),
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: Text(
                      _isFocusMode ? "Disable Focus Mode" : "Enable Focus Mode", 
                      style: TextStyle(color: _isFocusMode ? ChildTheme.sosRed : ChildTheme.textPrimary, fontWeight: FontWeight.bold, fontSize: 16)
                    ),
                  ),
                )
              ],
            ),
          ),
          const SizedBox(height: 32),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text("Schedule", style: ChildTheme.titleStyle.copyWith(fontSize: 18)),
              TextButton(onPressed: () {}, child: const Text("Edit", style: TextStyle(color: ChildTheme.primaryBlue, fontWeight: FontWeight.bold)))
            ],
          ),
          const SizedBox(height: 8),

          _buildScheduleCard("Weekday Mornings", "9:00 AM - 12:00 PM", "Mon - Fri", _mockSchedule1, (val) => setState(() => _mockSchedule1 = val)),
          const SizedBox(height: 12),
          _buildScheduleCard("Afternoon Study", "2:00 PM - 5:00 PM", "Mon, Wed, Fri", _mockSchedule2, (val) => setState(() => _mockSchedule2 = val)),
          const SizedBox(height: 12),
          _buildScheduleCard("Evening Focus", "7:00 PM - 9:00 PM", "Daily", _mockSchedule3, (val) => setState(() => _mockSchedule3 = val)),

          const SizedBox(height: 32),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text("Allowed Apps", style: ChildTheme.titleStyle.copyWith(fontSize: 18)),
              TextButton(onPressed: () {}, child: const Text("Manage", style: TextStyle(color: ChildTheme.primaryBlue, fontWeight: FontWeight.bold)))
            ],
          ),
          const SizedBox(height: 8),

          ChildTheme.applyGlass(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(color: ChildTheme.textSecondary.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
                      child: const Icon(Icons.smartphone, color: ChildTheme.textPrimary, size: 24),
                    ),
                    const SizedBox(width: 16),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text("3 apps allowed", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: ChildTheme.textPrimary)),
                        const SizedBox(height: 4),
                        Text("During Focus Mode", style: ChildTheme.subtitleStyle.copyWith(fontSize: 13)),
                      ],
                    )
                  ],
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    _buildAppChip("Messages"),
                    const SizedBox(width: 8),
                    _buildAppChip("Calendar"),
                    const SizedBox(width: 8),
                    _buildAppChip("Notes"),
                  ],
                )
              ],
            ),
          )

        ],
      ),
    );
  }

  Widget _buildScheduleCard(String title, String time, String days, bool value, ValueChanged<bool> onChanged) {
    return ChildTheme.applyGlass(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: ChildTheme.primaryBlue.withOpacity(0.1), shape: BoxShape.circle), child: const Icon(Icons.access_time_rounded, color: ChildTheme.primaryBlue, size: 20)),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: ChildTheme.textPrimary)),
                    const SizedBox(height: 4),
                    Text(time, style: ChildTheme.subtitleStyle.copyWith(fontSize: 13)),
                  ],
                ),
              ),
              Switch(
                value: value,
                onChanged: onChanged,
                activeColor: Colors.white,
                activeTrackColor: ChildTheme.primaryBlue,
                inactiveThumbColor: Colors.white,
                inactiveTrackColor: ChildTheme.borderLight,
              )
            ],
          ),
          const SizedBox(height: 12),
          Text(days, style: ChildTheme.subtitleStyle.copyWith(fontSize: 12)),
        ],
      ),
    );
  }

  Widget _buildAppChip(String name) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(color: ChildTheme.textSecondary.withOpacity(0.05), borderRadius: BorderRadius.circular(20)),
      child: Text(name, style: const TextStyle(color: ChildTheme.textPrimary, fontSize: 13, fontWeight: FontWeight.w500)),
    );
  }
}
