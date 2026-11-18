import 'package:flutter/foundation.dart' show kIsWeb;

/// Central API configuration for the RYDO customer app.
///
/// Base URL by platform:
/// - Web (Chrome/Edge): localhost
/// - Android emulator:  10.0.2.2  (special alias to host machine)
/// - Physical device:   10.144.164.211 (host machine LAN IP)
class ApiConfig {
  /// Change this to your machine's LAN IP when running on a physical device.
  static const String _lanIp = '10.144.164.211';

  static String get baseUrl {
    if (kIsWeb) {
      return 'http://localhost:5000/api';
    }
    return 'http://$_lanIp:5000/api';
  }

  /// Socket.io server URL (without the /api suffix).
  static String get socketUrl {
    if (kIsWeb) {
      return 'http://localhost:5000';
    }
    return 'http://$_lanIp:5000';
  }
}
