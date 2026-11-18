import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../services/api_service.dart';
import '../services/razorpay_checkout.dart';
import '../utils/app_colors.dart';

class BookRideScreen extends StatefulWidget {
  final String? initialServiceType;
  const BookRideScreen({super.key, this.initialServiceType});

  @override
  State<BookRideScreen> createState() => _BookRideScreenState();
}

class _BookRideScreenState extends State<BookRideScreen> {
  final _pickupController = TextEditingController();
  final _destController = TextEditingController();
  String _serviceType = 'bike-taxi';
  String _paymentMethod = 'cash';
  Map<String, dynamic>? _estimate;
  bool _loadingEstimate = false;
  bool _booking = false;
  String? _message;

  final List<Map<String, String>> _services = [
    {'value': 'bike-taxi', 'label': 'Bike Taxi'},
    {'value': 'courier', 'label': 'Courier'},
    {'value': 'auto', 'label': 'Auto'},
    {'value': 'mini-truck', 'label': 'Mini Truck'},
    {'value': 'truck', 'label': 'Truck'},
  ];

  // Mock coordinates (in a real app use a maps/places API)
  final _pickupCoords = [77.5946, 12.9716];
  final _destCoords = [77.6413, 12.9141];

  @override
  void initState() {
    super.initState();
    if (widget.initialServiceType != null) {
      _serviceType = widget.initialServiceType!;
    }
  }

  @override
  void dispose() {
    _pickupController.dispose();
    _destController.dispose();
    super.dispose();
  }

  Future<void> _getEstimate() async {
    if (_pickupController.text.isEmpty || _destController.text.isEmpty) {
      setState(() => _message = 'Enter both pickup and destination');
      return;
    }
    setState(() {
      _loadingEstimate = true;
      _message = null;
    });
    final result = await ApiService.getRideEstimate({
      'pickup': {'coordinates': _pickupCoords},
      'destination': {'coordinates': _destCoords},
      'serviceType': _serviceType,
    });
    setState(() {
      _loadingEstimate = false;
      if (result['success'] == true) {
        _estimate = result['estimate'];
      } else {
        _message = result['message'] ?? 'Failed to get estimate';
      }
    });
  }

  Future<void> _bookRide() async {
    if (_estimate == null) {
      setState(() => _message = 'Get an estimate first');
      return;
    }
    setState(() {
      _booking = true;
      _message = null;
    });
    final result = await ApiService.bookRide({
      'pickup': {'address': _pickupController.text, 'coordinates': _pickupCoords},
      'destination': {'address': _destController.text, 'coordinates': _destCoords},
      'serviceType': _serviceType,
      'paymentMethod': _paymentMethod,
    });
    setState(() => _booking = false);
    if (!mounted) return;
    if (result['success'] == true) {
      final ride = result['ride'];
      final rideId = ride?['rideId']?.toString() ?? '';
      final total = (_estimate!['fare']['total'] ?? 0).toDouble();

      // For online payment, launch Razorpay checkout immediately
      if (_paymentMethod == 'online') {
        final user = Provider.of<AuthProvider>(context, listen: false).user ?? {};
        final pay = await RazorpayCheckout.payForRide(
          rideId: rideId,
          amount: total,
          customerName: user['name']?.toString() ?? 'Customer',
          customerEmail: user['email']?.toString() ?? 'customer@rydo.com',
          customerPhone: user['phone']?.toString() ?? '',
        );
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(pay['success'] == true
              ? 'Ride booked & paid via Razorpay! ID: $rideId'
              : 'Ride booked (ID: $rideId). Payment: ${pay['message']}'),
          backgroundColor: pay['success'] == true ? AppColors.success : AppColors.warning,
        ));
      } else {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Ride booked! ID: $rideId (${_paymentMethod == 'wallet' ? 'Wallet' : 'Cash'})'),
          backgroundColor: AppColors.success,
        ));
      }

      setState(() {
        _pickupController.clear();
        _destController.clear();
        _estimate = null;
      });
    } else {
      setState(() => _message = result['message'] ?? 'Booking failed');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Book a Ride')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_message != null)
              Container(
                padding: const EdgeInsets.all(12),
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: AppColors.error.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(_message!, style: const TextStyle(color: AppColors.error)),
              ),
            TextField(
              controller: _pickupController,
              decoration: const InputDecoration(
                labelText: 'Pickup Location',
                prefixIcon: Icon(Icons.my_location, color: AppColors.primary),
              ),
              onChanged: (_) => setState(() => _estimate = null),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _destController,
              decoration: const InputDecoration(
                labelText: 'Destination',
                prefixIcon: Icon(Icons.location_on, color: AppColors.error),
              ),
              onChanged: (_) => setState(() => _estimate = null),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              value: _serviceType,
              decoration: const InputDecoration(labelText: 'Service Type'),
              items: _services
                  .map((s) => DropdownMenuItem(value: s['value'], child: Text(s['label']!)))
                  .toList(),
              onChanged: (v) => setState(() {
                _serviceType = v!;
                _estimate = null;
              }),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              value: _paymentMethod,
              decoration: const InputDecoration(labelText: 'Payment Method'),
              items: const [
                DropdownMenuItem(value: 'cash', child: Text('Cash')),
                DropdownMenuItem(value: 'online', child: Text('Online')),
                DropdownMenuItem(value: 'wallet', child: Text('Wallet')),
              ],
              onChanged: (v) => setState(() => _paymentMethod = v!),
            ),
            const SizedBox(height: 20),
            OutlinedButton.icon(
              onPressed: _loadingEstimate ? null : _getEstimate,
              icon: _loadingEstimate
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.attach_money),
              label: Text(_loadingEstimate ? 'Getting Estimate...' : 'Get Fare Estimate'),
            ),
            if (_estimate != null) ...[
              const SizedBox(height: 20),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      _row('Distance', '${_estimate!['distance']} km'),
                      _row('Est. Time', '${_estimate!['estimatedTime']} min'),
                      const Divider(),
                      _row('Base Fare', '₹${_estimate!['fare']['baseFare']}'),
                      _row('Distance Fare', '₹${_estimate!['fare']['distanceFare']}'),
                      const Divider(),
                      _row('Total', '₹${_estimate!['fare']['total']}', bold: true),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                height: 52,
                child: ElevatedButton.icon(
                  onPressed: _booking ? null : _bookRide,
                  icon: _booking
                      ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Icon(Icons.directions_car),
                  label: Text(_booking ? 'Booking...' : 'Book Ride'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _row(String label, String value, {bool bold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: bold ? AppColors.onSurface : AppColors.onSurfaceVariant, fontWeight: bold ? FontWeight.bold : FontWeight.normal, fontSize: bold ? 16 : 14)),
          Text(value, style: TextStyle(fontWeight: bold ? FontWeight.bold : FontWeight.w500, fontSize: bold ? 18 : 14, color: bold ? AppColors.success : AppColors.onSurface)),
        ],
      ),
    );
  }
}
