import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';

import 'app_logger.dart';

class LocationService {
  static bool _initialized = false;

  static Future<void> initialize() async {
    if (_initialized) return;

    _initialized = true;

    try {
      var status = await Permission.location.status;
      if (!status.isGranted) {
        status = await Permission.location.request();
        if (!status.isGranted) {
          return;
        }
      }

      var geoPermission = await Geolocator.checkPermission();
      if (geoPermission == LocationPermission.denied || geoPermission == LocationPermission.deniedForever) {
        geoPermission = await Geolocator.requestPermission();
        if (geoPermission != LocationPermission.always && geoPermission != LocationPermission.whileInUse) {
           return;
        }
      }
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
