import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';

import 'app_logger.dart';

class LocationService {
  static bool _initialized = false;

  static Future<void> initialize() async {
    if (_initialized) return;

    _initialized = true;

    try {
      final status = await Permission.location.request();
      if (!status.isGranted) {
        return;
      }

      await Geolocator.requestPermission();
      AppLogger.info(
        LogCategory.lifecycle,
        '[LOCATION] Geolocator initialized',
      );
    } catch (e) {
      AppLogger.warn(
        LogCategory.lifecycle,
        '[LOCATION] Geolocator initialization failed: $e',
      );
    }
  }
}
