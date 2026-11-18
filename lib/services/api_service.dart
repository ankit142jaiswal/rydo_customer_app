import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../config/api_config.dart';

class ApiService {
  // Platform-aware base URL (localhost on web, 10.0.2.2 on Android emulator).
  // This ensures all platforms connect to the SAME backend that rydo_web uses.
  static String get baseUrl => ApiConfig.baseUrl;
  
  static Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('token');
  }
  
  static Future<Map<String, String>> getHeaders() async {
    final token = await getToken();
    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }
  
  // Authentication
  static Future<Map<String, dynamic>> login(String email, String password) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/auth/login'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'email': email, 'password': password}),
      );
      
      return jsonDecode(response.body);
    } catch (e) {
      return {'success': false, 'message': 'Network error: $e'};
    }
  }
  
  static Future<Map<String, dynamic>> register(Map<String, dynamic> userData) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/auth/register'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(userData),
      );
      
      return jsonDecode(response.body);
    } catch (e) {
      return {'success': false, 'message': 'Network error: $e'};
    }
  }
  
  static Future<Map<String, dynamic>> getProfile() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/auth/profile'),
        headers: await getHeaders(),
      );
      
      return jsonDecode(response.body);
    } catch (e) {
      return {'success': false, 'message': 'Network error: $e'};
    }
  }
  
  // Rides
  static Future<Map<String, dynamic>> bookRide(Map<String, dynamic> rideData) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/rides/book'),
        headers: await getHeaders(),
        body: jsonEncode(rideData),
      );
      
      return jsonDecode(response.body);
    } catch (e) {
      return {'success': false, 'message': 'Network error: $e'};
    }
  }
  
  static Future<Map<String, dynamic>> getRideHistory() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/rides/my-rides'),
        headers: await getHeaders(),
      );
      
      return jsonDecode(response.body);
    } catch (e) {
      return {'success': false, 'message': 'Network error: $e'};
    }
  }
  
  static Future<Map<String, dynamic>> getRideDetails(String rideId) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/rides/$rideId'),
        headers: await getHeaders(),
      );
      
      return jsonDecode(response.body);
    } catch (e) {
      return {'success': false, 'message': 'Network error: $e'};
    }
  }
  
  static Future<Map<String, dynamic>> cancelRide(String rideId, String reason) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/customers/cancel-ride/$rideId'),
        headers: await getHeaders(),
        body: jsonEncode({'reason': reason}),
      );
      
      return jsonDecode(response.body);
    } catch (e) {
      return {'success': false, 'message': 'Network error: $e'};
    }
  }
  
  static Future<Map<String, dynamic>> rateRide(String rideId, int rating, String feedback) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/rides/$rideId/rate'),
        headers: await getHeaders(),
        body: jsonEncode({'rating': rating, 'feedback': feedback}),
      );
      
      return jsonDecode(response.body);
    } catch (e) {
      return {'success': false, 'message': 'Network error: $e'};
    }
  }
  
  // Payments
  static Future<Map<String, dynamic>> createPaymentOrder(String rideId, double amount) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/payments/create-order'),
        headers: await getHeaders(),
        body: jsonEncode({'rideId': rideId, 'amount': amount}),
      );
      
      return jsonDecode(response.body);
    } catch (e) {
      return {'success': false, 'message': 'Network error: $e'};
    }
  }
  
  static Future<Map<String, dynamic>> verifyPayment(Map<String, dynamic> paymentData) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/payments/verify-payment'),
        headers: await getHeaders(),
        body: jsonEncode(paymentData),
      );
      
      return jsonDecode(response.body);
    } catch (e) {
      return {'success': false, 'message': 'Network error: $e'};
    }
  }
  
  static Future<Map<String, dynamic>> addToWallet(double amount) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/payments/add-to-wallet'),
        headers: await getHeaders(),
        body: jsonEncode({'amount': amount}),
      );
      
      return jsonDecode(response.body);
    } catch (e) {
      return {'success': false, 'message': 'Network error: $e'};
    }
  }
  
  static Future<Map<String, dynamic>> payFromWallet(String rideId, double amount) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/payments/pay-from-wallet'),
        headers: await getHeaders(),
        body: jsonEncode({'rideId': rideId, 'amount': amount}),
      );
      
      return jsonDecode(response.body);
    } catch (e) {
      return {'success': false, 'message': 'Network error: $e'};
    }
  }
  
  // Customer
  static Future<Map<String, dynamic>> getDashboard() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/customers/dashboard'),
        headers: await getHeaders(),
      );
      
      return jsonDecode(response.body);
    } catch (e) {
      return {'success': false, 'message': 'Network error: $e'};
    }
  }
  
  static Future<Map<String, dynamic>> getRideEstimate(Map<String, dynamic> estimateData) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/customers/estimate'),
        headers: await getHeaders(),
        body: jsonEncode(estimateData),
      );
      
      return jsonDecode(response.body);
    } catch (e) {
      return {'success': false, 'message': 'Network error: $e'};
    }
  }

  // Customer rides (paginated, with status filter)
  static Future<Map<String, dynamic>> getCustomerRides({int page = 1, int limit = 20, String? status}) async {
    try {
      var url = '$baseUrl/customers/rides?page=$page&limit=$limit';
      if (status != null) url += '&status=$status';
      final response = await http.get(Uri.parse(url), headers: await getHeaders());
      return jsonDecode(response.body);
    } catch (e) {
      return {'success': false, 'message': 'Network error: $e'};
    }
  }

  // Wallet transactions
  static Future<Map<String, dynamic>> getWalletTransactions({int page = 1, int limit = 20}) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/customers/wallet/transactions?page=$page&limit=$limit'),
        headers: await getHeaders(),
      );
      return jsonDecode(response.body);
    } catch (e) {
      return {'success': false, 'message': 'Network error: $e'};
    }
  }

  // Add money to wallet (customer route with Transaction record)
  static Future<Map<String, dynamic>> addMoneyToWallet(double amount) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/customers/wallet/add'),
        headers: await getHeaders(),
        body: jsonEncode({'amount': amount}),
      );
      return jsonDecode(response.body);
    } catch (e) {
      return {'success': false, 'message': 'Network error: $e'};
    }
  }

  // Update customer profile
  static Future<Map<String, dynamic>> updateCustomerProfile(Map<String, dynamic> updates) async {
    try {
      final response = await http.put(
        Uri.parse('$baseUrl/customers/profile'),
        headers: await getHeaders(),
        body: jsonEncode(updates),
      );
      return jsonDecode(response.body);
    } catch (e) {
      return {'success': false, 'message': 'Network error: $e'};
    }
  }

  // Notifications
  static Future<Map<String, dynamic>> getNotifications({bool? unreadOnly}) async {
    try {
      var url = '$baseUrl/notifications';
      if (unreadOnly == true) url += '?isRead=false';
      final response = await http.get(Uri.parse(url), headers: await getHeaders());
      return jsonDecode(response.body);
    } catch (e) {
      return {'success': false, 'message': 'Network error: $e'};
    }
  }

  static Future<Map<String, dynamic>> markNotificationRead(String id) async {
    try {
      final response = await http.put(
        Uri.parse('$baseUrl/notifications/$id/read'),
        headers: await getHeaders(),
      );
      return jsonDecode(response.body);
    } catch (e) {
      return {'success': false, 'message': 'Network error: $e'};
    }
  }

  static Future<Map<String, dynamic>> markAllNotificationsRead() async {
    try {
      final response = await http.put(
        Uri.parse('$baseUrl/notifications/mark-all-read'),
        headers: await getHeaders(),
      );
      return jsonDecode(response.body);
    } catch (e) {
      return {'success': false, 'message': 'Network error: $e'};
    }
  }

  static Future<Map<String, dynamic>> deleteNotification(String id) async {
    try {
      final response = await http.delete(
        Uri.parse('$baseUrl/notifications/$id'),
        headers: await getHeaders(),
      );
      return jsonDecode(response.body);
    } catch (e) {
      return {'success': false, 'message': 'Network error: $e'};
    }
  }

  static Future<Map<String, dynamic>> getNotificationSettings() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/notifications/settings'),
        headers: await getHeaders(),
      );
      return jsonDecode(response.body);
    } catch (e) {
      return {'success': false, 'message': 'Network error: $e'};
    }
  }

  static Future<Map<String, dynamic>> updateNotificationSettings(Map<String, dynamic> settings) async {
    try {
      final response = await http.put(
        Uri.parse('$baseUrl/notifications/settings'),
        headers: await getHeaders(),
        body: jsonEncode(settings),
      );
      return jsonDecode(response.body);
    } catch (e) {
      return {'success': false, 'message': 'Network error: $e'};
    }
  }

  // Saved addresses
  static Future<Map<String, dynamic>> getAddresses() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/customers/addresses'),
        headers: await getHeaders(),
      );
      return jsonDecode(response.body);
    } catch (e) {
      return {'success': false, 'message': 'Network error: $e'};
    }
  }

  static Future<Map<String, dynamic>> addAddress(String type, String address, List<double> coordinates) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/customers/addresses'),
        headers: await getHeaders(),
        body: jsonEncode({'type': type, 'address': address, 'coordinates': coordinates}),
      );
      return jsonDecode(response.body);
    } catch (e) {
      return {'success': false, 'message': 'Network error: $e'};
    }
  }

  static Future<Map<String, dynamic>> deleteAddress(String type) async {
    try {
      final response = await http.delete(
        Uri.parse('$baseUrl/customers/addresses/$type'),
        headers: await getHeaders(),
      );
      return jsonDecode(response.body);
    } catch (e) {
      return {'success': false, 'message': 'Network error: $e'};
    }
  }

  // Full customer profile (with customerDetails)
  static Future<Map<String, dynamic>> getCustomerProfile() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/customers/profile'),
        headers: await getHeaders(),
      );
      return jsonDecode(response.body);
    } catch (e) {
      return {'success': false, 'message': 'Network error: $e'};
    }
  }
}