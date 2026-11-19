import 'package:flutter/foundation.dart' show kIsWeb;

/// Central API configuration for the RYDO customer app.
///
/// Both web and native (Android / iOS) now point to the same
/// production backend at https://rydo-web.onrender.com.
///
/// For local development, temporarily swap the constants below:
///   _prodApi  → 'http://10.0.2.2:5000/api'   (Android emulator)
///   _prodApi  → 'http://<LAN_IP>:5000/api'    (physical device)
class ApiConfig {
  static const String _prodApi    = 'https://rydo-web.onrender.com/api';
  static const String _prodSocket = 'https://rydo-web.onrender.com';

  static String get baseUrl   => _prodApi;
  static String get socketUrl => _prodSocket;
}
