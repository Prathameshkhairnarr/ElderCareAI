import 'dart:typed_data';
import 'package:app_usage/app_usage.dart';
import 'package:installed_apps/app_info.dart';
import 'package:installed_apps/installed_apps.dart';

class EnrichedAppUsage {
  final AppUsageInfo usageInfo;
  final String appName;
  final Uint8List? icon;
  final Duration duration;

  EnrichedAppUsage({
    required this.usageInfo,
    required this.appName,
    required this.icon,
    required this.duration,
  });
}

class DigitalWellbeingService {
  static final DigitalWellbeingService _instance = DigitalWellbeingService._internal();
  factory DigitalWellbeingService() => _instance;
  DigitalWellbeingService._internal();

  /// Fetches today's app usage stats enriched with app names and icons.
  Future<List<EnrichedAppUsage>> getTodayUsage() async {
    try {
      final now = DateTime.now();
      // Start from midnight of today
      final startDate = DateTime(now.year, now.month, now.day);

      // Fetch raw usage from OS
      List<AppUsageInfo> rawUsages = await AppUsage().getAppUsage(startDate, now);

      // We only care about apps used for more than 1 minute to avoid clutter.
      final filtered = rawUsages.where((u) => u.usage.inMinutes > 0).toList();

      List<EnrichedAppUsage> enrichedList = [];
      for (var usage in filtered) {
        String name = usage.appName;
        Uint8List? appIcon;

        try {
          AppInfo? info = await InstalledApps.getAppInfo(usage.packageName);
          if (info != null) {
            name = info.name ?? usage.appName;
            appIcon = info.icon;

            // Skip system-only routing packages or the launcher if possible
            if (name.contains("launcher") || name.toLowerCase().contains("system ui")) continue;
          } else {
            // System hidden components we couldn't properly fetch via InstalledApps
            continue;
          }
        } catch (_) {
          continue;
        }

        enrichedList.add(
          EnrichedAppUsage(
            usageInfo: usage,
            appName: name,
            icon: appIcon,
            duration: usage.usage,
          ),
        );
      }

      // Sort by highest duration first
      enrichedList.sort((a, b) => b.duration.compareTo(a.duration));
      return enrichedList;

    } catch (e) {
      // The most common exception is permission missing ("AppUsageException: Usage access is not granted")
      rethrow;
    }
  }
}
