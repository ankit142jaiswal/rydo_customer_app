import 'package:flutter/material.dart';
import '../services/api_service.dart';

class RideProvider with ChangeNotifier {
  Map<String, dynamic>? _currentRide;
  List<Map<String, dynamic>> _rideHistory = [];
  bool _isLoading = false;

  Map<String, dynamic>? get currentRide => _currentRide;
  List<Map<String, dynamic>> get rideHistory => _rideHistory;
  bool get isLoading => _isLoading;

  Future<Map<String, dynamic>> bookRide(Map<String, dynamic> rideData) async {
    _isLoading = true;
    notifyListeners();

    try {
      final result = await ApiService.bookRide(rideData);
      
      if (result['success']) {
        _currentRide = result['ride'];
      }
      
      _isLoading = false;
      notifyListeners();
      return result;
    } catch (e) {
      _isLoading = false;
      notifyListeners();
      return {'success': false, 'message': 'Network error: $e'};
    }
  }

  Future<void> fetchRideHistory() async {
    _isLoading = true;
    notifyListeners();

    try {
      final result = await ApiService.getRideHistory();
      
      if (result['success']) {
        _rideHistory = List<Map<String, dynamic>>.from(result['rides']);
      }
    } catch (e) {
      print('Error fetching ride history: $e');
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<Map<String, dynamic>> cancelRide(String rideId, String reason) async {
    try {
      final result = await ApiService.cancelRide(rideId, reason);
      
      if (result['success']) {
        _currentRide = null;
        notifyListeners();
      }
      
      return result;
    } catch (e) {
      return {'success': false, 'message': 'Network error: $e'};
    }
  }

  void updateCurrentRide(Map<String, dynamic> rideData) {
    _currentRide = rideData;
    notifyListeners();
  }

  void clearCurrentRide() {
    _currentRide = null;
    notifyListeners();
  }
}