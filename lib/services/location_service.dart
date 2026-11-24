import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';
import '../utils/storage_helper.dart';

/// Handles device location for the customer app.
///
/// • Requests permission and fetches the current GPS position.
/// • Reverse-geocodes it to a human-readable address.
/// • Can push the customer's location to the backend (used while tracking
///   a live ride so the driver app knows the pickup point).
class LocationService extends ChangeNotifier {
  Position? _currentPosition;
  String? _currentAddress;
  bool _isLoading = false;
  String? _error;

  Position? get currentPosition => _currentPosition;
  String? get currentAddress => _currentAddress;
  bool get isLoading => _isLoading;
  String? get error => _error;

  /// Request permission, fetch GPS fix, and reverse-geocode to an address.
  Future<void> getCurrentLocation() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        _error = 'Location services are disabled.';
        _isLoading = false;
        notifyListeners();
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          _error = 'Location permission denied.';
          _isLoading = false;
          notifyListeners();
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        _error = 'Location permission permanently denied. Enable it in Settings.';
        _isLoading = false;
        notifyListeners();
        return;
      }

      _currentPosition = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      await _reverseGeocode();
    } catch (e) {
      _error = 'Failed to get location: $e';
      debugPrint('LocationService.getCurrentLocation error: $e');
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<void> _reverseGeocode() async {
    if (_currentPosition == null) return;
    try {
      final placemarks = await placemarkFromCoordinates(
        _currentPosition!.latitude,
        _currentPosition!.longitude,
      );
      if (placemarks.isNotEmpty) {
        final p = placemarks.first;
        _currentAddress = [p.street, p.locality]
            .where((s) => s != null && s.isNotEmpty)
            .join(', ');
      }
    } catch (e) {
      debugPrint('LocationService._reverseGeocode error: $e');
      _currentAddress = 'Unknown location';
    }
  }

  /// Push the customer's current location to the server.
  /// Called while a ride is active so the backend can track the pickup point.
  Future<void> updateLocationOnServer() async {
    if (_currentPosition == null) return;
    try {
      final token = await StorageHelper.getToken();
      await http.post(
        Uri.parse('${ApiConfig.baseUrl}/customers/update-location'),
        headers: {
          'Content-Type': 'application/json',
          if (token != null) 'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'latitude': _currentPosition!.latitude,
          'longitude': _currentPosition!.longitude,
        }),
      );
    } catch (e) {
      debugPrint('LocationService.updateLocationOnServer error: $e');
    }
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }
}
