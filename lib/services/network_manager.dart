import 'package:connectivity_plus/connectivity_plus.dart';

class NetworkException implements Exception {
  final String message;
  NetworkException(this.message);

  @override
  String toString() => message;
}

class NetworkManager {
  static final NetworkManager _instance = NetworkManager._internal();
  factory NetworkManager() => _instance;
  NetworkManager._internal();

  /// Check if the device currently has an internet connection.
  static Future<bool> isOnline() async {
    final List<ConnectivityResult> result = await Connectivity()
        .checkConnectivity();
    return !result.contains(ConnectivityResult.none) && result.isNotEmpty;
  }

  /// Throws a [NetworkException] if the device is offline.
  static Future<void> ensureOnline() async {
    final online = await isOnline();
    if (!online) {
      throw NetworkException("No internet connection");
    }
  }
}
