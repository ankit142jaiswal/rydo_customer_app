import '../utils/currency.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:geocoding/geocoding.dart';
import '../services/places_service.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../services/api_service.dart';
import '../services/razorpay_checkout.dart';
import 'ride_tracking_screen.dart';
import '../utils/app_colors.dart';
import '../utils/service_catalog.dart';

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

  // Return ride: captain waits at the destination, then brings the customer back.
  // Waiting is 1–20 minutes at ₹1/min (fare is calculated by the server).
  static const _minWait = 1, _maxWait = 20, _waitRatePerMin = 1;
  bool _returnTrip = false;
  int _waitMinutes = 5;

  Map<String, dynamic> get _returnTripBody =>
      {'enabled': _returnTrip, if (_returnTrip) 'waitMinutes': _waitMinutes};
  Map<String, dynamic>? _estimate;
  bool _loadingEstimate = false;
  bool _booking = false;
  String? _message;

  // Services grouped by category (Ride / Parcel / Goods)
  late ServiceCategory _category = ServiceCatalog.categoryOf(_serviceType);

  // Map state. Backend coordinates are [lng, lat].
  static const _defaultCenter = LatLng(12.9716, 77.5946);
  GoogleMapController? _mapController;
  LatLng? _pickup;
  LatLng? _dest;
  bool _selectingPickup = true;

  // Address suggestions
  Timer? _debounce;
  List<PlaceSuggestion> _suggestions = [];
  bool _suggestPickup = true; // which field the suggestions belong to
  bool _loadingSuggestions = false;

  void _onTextChanged(String text, {required bool pickup}) {
    setState(() {
      _estimate = null;
      _selectingPickup = pickup;
    });
    _debounce?.cancel();
    if (text.trim().length < 2) {
      setState(() => _suggestions = []);
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 350), () async {
      setState(() {
        _suggestPickup = pickup;
        _loadingSuggestions = true;
      });
      final bias = _pickup ?? _defaultCenter;
      final res = await PlacesService.autocomplete(text, lat: bias.latitude, lng: bias.longitude);
      if (!mounted) return;
      // Ignore stale responses if the field text changed meanwhile
      final current = (pickup ? _pickupController : _destController).text;
      if (current != text) return;
      setState(() {
        _suggestions = res;
        _loadingSuggestions = false;
      });
    });
  }

  Future<void> _selectSuggestion(PlaceSuggestion s) async {
    final pickup = _suggestPickup;
    FocusScope.of(context).unfocus();
    (pickup ? _pickupController : _destController).text = s.description;
    setState(() {
      _suggestions = [];
      _loadingSuggestions = false;
    });
    final d = await PlacesService.details(s);
    if (!mounted) return;
    if (d == null) {
      setState(() => _message = 'Could not load that place. Check the Places API key.');
      return;
    }
    setState(() {
      _message = null;
      final pos = LatLng(d.lat, d.lng);
      if (pickup) {
        _pickup = pos;
      } else {
        _dest = pos;
      }
      _estimate = null;
    });
    _fitCamera();
  }

  List<double> get _pickupCoords => [_pickup?.longitude ?? _defaultCenter.longitude, _pickup?.latitude ?? _defaultCenter.latitude];
  List<double> get _destCoords => [_dest?.longitude ?? _defaultCenter.longitude, _dest?.latitude ?? _defaultCenter.latitude];

  Set<Marker> get _markers => {
        if (_pickup != null)
          Marker(
            markerId: const MarkerId('pickup'),
            position: _pickup!,
            icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
            infoWindow: const InfoWindow(title: 'Pickup'),
          ),
        if (_dest != null)
          Marker(
            markerId: const MarkerId('drop'),
            position: _dest!,
            icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
            infoWindow: const InfoWindow(title: 'Destination'),
          ),
      };

  Set<Polyline> get _polylines => {
        if (_pickup != null && _dest != null)
          Polyline(
            polylineId: const PolylineId('route'),
            points: [_pickup!, _dest!],
            width: 4,
            color: AppColors.primary,
          ),
      };

  @override
  void initState() {
    super.initState();
    if (widget.initialServiceType != null) {
      _serviceType = widget.initialServiceType!;
    }
    _useCurrentLocation();
  }

  Future<void> _useCurrentLocation() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) return;
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.denied || perm == LocationPermission.deniedForever) return;
      final p = await Geolocator.getCurrentPosition();
      if (!mounted) return;
      await _setPoint(LatLng(p.latitude, p.longitude), pickup: true);
    } catch (e) {
      debugPrint('Current location failed: $e');
    }
  }

  Future<String> _addressFor(LatLng pos) async {
    try {
      final pm = await placemarkFromCoordinates(pos.latitude, pos.longitude);
      if (pm.isNotEmpty) {
        final p = pm.first;
        final parts = [p.street, p.subLocality, p.locality].where((s) => s != null && s.isNotEmpty);
        if (parts.isNotEmpty) return parts.join(', ');
      }
    } catch (e) {
      debugPrint('Reverse geocode failed: $e');
    }
    final fallback = await PlacesService.reverse(pos.latitude, pos.longitude);
    if (fallback != null) return fallback;
    return '${pos.latitude.toStringAsFixed(5)}, ${pos.longitude.toStringAsFixed(5)}';
  }

  Future<void> _setPoint(LatLng pos, {required bool pickup}) async {
    setState(() {
      if (pickup) {
        _pickup = pos;
      } else {
        _dest = pos;
      }
      _estimate = null;
    });
    _fitCamera();
    final addr = await _addressFor(pos);
    if (!mounted) return;
    (pickup ? _pickupController : _destController).text = addr;
  }

  Future<void> _searchAddress(String query, {required bool pickup}) async {
    if (query.trim().isEmpty) return;
    try {
      final res = await locationFromAddress(query);
      if (res.isEmpty) {
        setState(() => _message = 'Address not found');
        return;
      }
      final pos = LatLng(res.first.latitude, res.first.longitude);
      setState(() {
        _message = null;
        if (pickup) {
          _pickup = pos;
        } else {
          _dest = pos;
        }
        _estimate = null;
      });
      _fitCamera();
    } catch (e) {
      setState(() => _message = 'Could not find that address');
    }
  }

  void _fitCamera() {
    final c = _mapController;
    if (c == null) return;
    if (_pickup != null && _dest != null) {
      final sw = LatLng(
        _pickup!.latitude < _dest!.latitude ? _pickup!.latitude : _dest!.latitude,
        _pickup!.longitude < _dest!.longitude ? _pickup!.longitude : _dest!.longitude,
      );
      final ne = LatLng(
        _pickup!.latitude > _dest!.latitude ? _pickup!.latitude : _dest!.latitude,
        _pickup!.longitude > _dest!.longitude ? _pickup!.longitude : _dest!.longitude,
      );
      c.animateCamera(CameraUpdate.newLatLngBounds(LatLngBounds(southwest: sw, northeast: ne), 60));
    } else {
      final t = _pickup ?? _dest;
      if (t != null) c.animateCamera(CameraUpdate.newLatLngZoom(t, 15));
    }
  }

  @override
  void dispose() {
    _pickupController.dispose();
    _destController.dispose();
    _debounce?.cancel();
    _mapController?.dispose();
    super.dispose();
  }

  Future<void> _getEstimate() async {
    if (_pickupController.text.isEmpty || _destController.text.isEmpty) {
      setState(() => _message = 'Enter both pickup and destination');
      return;
    }
    if (_pickup == null || _dest == null) {
      setState(() => _message = 'Select pickup and destination on the map or search an address (press Enter)');
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
      'returnTrip': _returnTripBody,
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
      'returnTrip': _returnTripBody,
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

      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => RideTrackingScreen(
            rideId: rideId,
            rideOtp: result['rideOtp']?.toString(),
            initialRide: ride is Map ? Map<String, dynamic>.from(ride) : null,
          ),
        ),
      );
    } else {
      setState(() => _message = result['message'] ?? 'Booking failed');
    }
  }

  BoxDecoration get _cardDecoration => BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.outline),
      );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text('Book a Ride'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: AppColors.dark,
        leading: Padding(
          padding: const EdgeInsets.all(6),
          child: CircleAvatar(
            backgroundColor: Colors.white,
            child: IconButton(
              icon: const Icon(Icons.arrow_back_rounded, color: AppColors.dark),
              onPressed: () => Navigator.maybePop(context),
            ),
          ),
        ),
      ),
      body: Stack(
        children: [
          // ── Map ──────────────────────────────────────────────────────────
          Positioned.fill(
            child: GoogleMap(
              initialCameraPosition: CameraPosition(target: _pickup ?? _defaultCenter, zoom: 14),
              onMapCreated: (c) {
                _mapController = c;
                _fitCamera();
              },
              onTap: (pos) => _setPoint(pos, pickup: _selectingPickup),
              markers: _markers,
              polylines: _polylines,
              myLocationEnabled: true,
              myLocationButtonEnabled: false,
              zoomControlsEnabled: false,
              mapToolbarEnabled: false,
              padding: EdgeInsets.only(bottom: MediaQuery.of(context).size.height * 0.4),
            ),
          ),

          // ── Tap target toggle ───────────────────────────────────────────
          Positioned(
            top: MediaQuery.of(context).padding.top + kToolbarHeight + 4,
            left: 16,
            right: 16,
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(30),
                boxShadow: const [BoxShadow(color: AppColors.shadow, blurRadius: 12, offset: Offset(0, 4))],
              ),
              child: Row(
                children: [
                  _toggleChip('Tap map: Pickup', Icons.trip_origin_rounded, true),
                  _toggleChip('Tap map: Drop', Icons.location_on_rounded, false),
                ],
              ),
            ),
          ),

          // ── Bottom sheet ────────────────────────────────────────────────
          DraggableScrollableSheet(
            initialChildSize: 0.55,
            minChildSize: 0.3,
            maxChildSize: 0.92,
            builder: (context, scroll) {
              return Container(
                decoration: const BoxDecoration(
                  color: AppColors.background,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
                  boxShadow: [BoxShadow(color: AppColors.shadow, blurRadius: 20, offset: Offset(0, -4))],
                ),
                child: ListView(
                  controller: scroll,
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 24),
                  children: [
                    Center(
                      child: Container(
                        width: 44,
                        height: 5,
                        decoration: BoxDecoration(
                          color: AppColors.outlineVariant,
                          borderRadius: BorderRadius.circular(3),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    if (_message != null)
                      Container(
                        padding: const EdgeInsets.all(12),
                        margin: const EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(
                          color: AppColors.error.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(children: [
                          const Icon(Icons.error_outline, color: AppColors.error, size: 18),
                          const SizedBox(width: 8),
                          Expanded(child: Text(_message!, style: const TextStyle(color: AppColors.error))),
                        ]),
                      ),
                    _locationCard(),
                    _suggestionList(),
                    const SizedBox(height: 18),
                    _categoryTabs(),
                    const SizedBox(height: 10),
                    SizedBox(
                      height: 88,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: _category.services.length,
                        separatorBuilder: (_, __) => const SizedBox(width: 10),
                        itemBuilder: (_, i) => _serviceTile(_category.services[i]),
                      ),
                    ),
                    const SizedBox(height: 18),
                    _returnTripCard(),
                    const SizedBox(height: 18),
                    const Text('Payment',
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.onSurface)),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        _payTile('cash', 'Cash', Icons.payments_rounded),
                        const SizedBox(width: 10),
                        _payTile('online', 'Online', Icons.credit_card_rounded),
                        const SizedBox(width: 10),
                        _payTile('wallet', 'Wallet', Icons.account_balance_wallet_rounded),
                      ],
                    ),
                    const SizedBox(height: 20),
                    if (_estimate == null)
                      SizedBox(
                        height: 54,
                        child: ElevatedButton.icon(
                          onPressed: _loadingEstimate ? null : _getEstimate,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.dark,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          ),
                          icon: _loadingEstimate
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                              : const Text('₹',
                                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: AppColors.primary)),
                          label: Text(_loadingEstimate ? 'Getting estimate...' : 'Get Fare Estimate',
                              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                        ),
                      )
                    else ...[
                      _estimateCard(),
                      const SizedBox(height: 16),
                      SizedBox(
                        height: 54,
                        child: ElevatedButton.icon(
                          onPressed: _booking ? null : _bookRide,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: AppColors.onPrimary,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          ),
                          icon: _booking
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.onPrimary))
                              : const Icon(Icons.check_circle_rounded),
                          label: Text(_booking ? 'Booking...' : 'Confirm & Book Ride',
                              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                        ),
                      ),
                    ],
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _suggestionList() {
    if (_loadingSuggestions && _suggestions.isEmpty) {
      return const Padding(
        padding: EdgeInsets.only(top: 10),
        child: LinearProgressIndicator(minHeight: 2, color: AppColors.primary),
      );
    }
    if (_suggestions.isEmpty) return const SizedBox.shrink();
    return Container(
      margin: const EdgeInsets.only(top: 8),
      decoration: _cardDecoration,
      child: Column(
        children: [
          for (var i = 0; i < _suggestions.length; i++) ...[
            if (i > 0) const Divider(height: 1),
            ListTile(
              dense: true,
              leading: const Icon(Icons.place_outlined, color: AppColors.onSurfaceVariant),
              title: Text(_suggestions[i].title,
                  maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w600)),
              subtitle: _suggestions[i].subtitle.isEmpty
                  ? null
                  : Text(_suggestions[i].subtitle, maxLines: 1, overflow: TextOverflow.ellipsis),
              onTap: () => _selectSuggestion(_suggestions[i]),
            ),
          ],
        ],
      ),
    );
  }

  Widget _toggleChip(String label, IconData icon, bool pickup) {
    final selected = _selectingPickup == pickup;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _selectingPickup = pickup),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: selected ? AppColors.primary : Colors.transparent,
            borderRadius: BorderRadius.circular(26),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 16, color: AppColors.dark),
              const SizedBox(width: 6),
              Flexible(
                child: Text(label,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                        color: AppColors.dark)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _locationCard() {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 8, 8, 8),
      decoration: _cardDecoration,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 16),
            child: Column(
              children: [
                const Icon(Icons.trip_origin_rounded, size: 16, color: AppColors.success),
                Container(width: 2, height: 36, color: AppColors.outlineVariant),
                const Icon(Icons.location_on_rounded, size: 18, color: AppColors.error),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              children: [
                TextField(
                  controller: _pickupController,
                  textInputAction: TextInputAction.search,
                  decoration: InputDecoration(
                    hintText: 'Pickup location',
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    filled: false,
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.my_location_rounded, size: 20),
                      tooltip: 'Use current location',
                      onPressed: _useCurrentLocation,
                    ),
                  ),
                  onChanged: (v) => _onTextChanged(v, pickup: true),
                  onSubmitted: (v) => _searchAddress(v, pickup: true),
                ),
                const Divider(height: 1),
                TextField(
                  controller: _destController,
                  textInputAction: TextInputAction.search,
                  decoration: const InputDecoration(
                    hintText: 'Where to?',
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    filled: false,
                  ),
                  onChanged: (v) => _onTextChanged(v, pickup: false),
                  onSubmitted: (v) => _searchAddress(v, pickup: false),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _returnTripCard() {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      padding: const EdgeInsets.fromLTRB(14, 6, 6, 6),
      decoration: BoxDecoration(
        color: _returnTrip ? AppColors.primary.withValues(alpha: 0.12) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _returnTrip ? AppColors.primary : AppColors.outline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.u_turn_left_rounded, color: AppColors.dark),
              const SizedBox(width: 10),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Return ride', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                    Text('Captain waits, then brings you back to pickup',
                        style: TextStyle(fontSize: 12, color: AppColors.onSurfaceVariant)),
                  ],
                ),
              ),
              Switch(
                value: _returnTrip,
                activeThumbColor: AppColors.dark,
                activeTrackColor: AppColors.primary,
                onChanged: (v) => setState(() {
                  _returnTrip = v;
                  _estimate = null;
                }),
              ),
            ],
          ),
          if (_returnTrip) ...[
            const SizedBox(height: 4),
            Row(
              children: [
                const Text('Wait time', style: TextStyle(fontWeight: FontWeight.w600)),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  margin: const EdgeInsets.only(right: 8),
                  decoration: BoxDecoration(color: AppColors.dark, borderRadius: BorderRadius.circular(20)),
                  child: Text(
                    '$_waitMinutes min · +${formatRupees(_waitMinutes * _waitRatePerMin)}',
                    style: const TextStyle(color: AppColors.primary, fontSize: 12, fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
            Slider(
              value: _waitMinutes.toDouble(),
              min: _minWait.toDouble(),
              max: _maxWait.toDouble(),
              divisions: _maxWait - _minWait,
              label: '$_waitMinutes min',
              activeColor: AppColors.dark,
              inactiveColor: AppColors.outlineVariant,
              onChanged: (v) => setState(() {
                _waitMinutes = v.round();
                _estimate = null;
              }),
            ),
            const Padding(
              padding: EdgeInsets.only(right: 8, bottom: 4),
              child: Text(
                'Waiting is charged at ₹1 per minute (1–20 min). The return trip is charged at the same per-km rate.',
                style: TextStyle(fontSize: 11.5, color: AppColors.onSurfaceVariant),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _categoryTabs() {
    return Row(
      children: [
        for (final c in ServiceCatalog.categories) ...[
          Expanded(
            child: GestureDetector(
              onTap: () => setState(() {
                _category = c;
                if (!c.services.any((s) => s.type == _serviceType)) {
                  _serviceType = c.services.first.type;
                  _estimate = null;
                }
              }),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: _category.id == c.id ? AppColors.dark : Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: _category.id == c.id ? AppColors.dark : AppColors.outline),
                ),
                child: Column(
                  children: [
                    Icon(c.icon, size: 20, color: _category.id == c.id ? AppColors.primary : AppColors.onSurfaceVariant),
                    const SizedBox(height: 4),
                    Text(c.id == 'goods' ? 'Goods' : c.title,
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                          color: _category.id == c.id ? Colors.white : AppColors.onSurface,
                        )),
                  ],
                ),
              ),
            ),
          ),
          if (c != ServiceCatalog.categories.last) const SizedBox(width: 8),
        ],
      ],
    );
  }

  Widget _serviceTile(RydoService s) {
    final selected = _serviceType == s.type;
    return GestureDetector(
      onTap: () => setState(() {
        _serviceType = s.type;
        _estimate = null;
      }),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 104,
        decoration: BoxDecoration(
          color: selected ? AppColors.primary.withValues(alpha: 0.18) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: selected ? AppColors.primary : AppColors.outline, width: selected ? 2 : 1),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(s.icon, size: 30, color: selected ? AppColors.dark : s.color),
            const SizedBox(height: 4),
            Text(s.title,
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                    color: AppColors.onSurface)),
            Text(s.price, style: const TextStyle(fontSize: 10.5, color: AppColors.onSurfaceVariant)),
          ],
        ),
      ),
    );
  }

  Widget _payTile(String value, String label, IconData icon) {
    final selected = _paymentMethod == value;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _paymentMethod = value),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: selected ? AppColors.dark : Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: selected ? AppColors.dark : AppColors.outline),
          ),
          child: Column(
            children: [
              Icon(icon, size: 22, color: selected ? AppColors.primary : AppColors.onSurfaceVariant),
              const SizedBox(height: 4),
              Text(label,
                  style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: selected ? Colors.white : AppColors.onSurface)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _estimateCard() {
    final fare = _estimate!['fare'];
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _cardDecoration,
      child: Column(
        children: [
          Row(
            children: [
              _infoPill(Icons.route_rounded, '${_estimate!['distance']} km'),
              const SizedBox(width: 10),
              _infoPill(Icons.schedule_rounded, '${_estimate!['estimatedTime']} min'),
            ],
          ),
          const SizedBox(height: 12),
          _row('Base Fare', formatRupees(fare['baseFare'])),
          _row('Distance Fare', formatRupees(fare['distanceFare'])),
          if ((fare['returnFare'] ?? 0) > 0) _row('Return Trip Fare', formatRupees(fare['returnFare'])),
          if ((fare['waitingCharge'] ?? 0) > 0)
            _row('Waiting (${_estimate!['returnTrip']?['waitMinutes'] ?? _waitMinutes} min × ₹1)',
                formatRupees(fare['waitingCharge'])),
          const Divider(),
          _row('Total', formatRupees(fare['total']), bold: true),
        ],
      ),
    );
  }

  Widget _infoPill(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: AppColors.onSurfaceVariant),
          const SizedBox(width: 6),
          Text(text, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Widget _row(String label, String value, {bool bold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: TextStyle(
                  color: bold ? AppColors.onSurface : AppColors.onSurfaceVariant,
                  fontWeight: bold ? FontWeight.bold : FontWeight.normal,
                  fontSize: bold ? 16 : 14)),
          Text(value,
              style: TextStyle(
                  fontWeight: bold ? FontWeight.bold : FontWeight.w500,
                  fontSize: bold ? 18 : 14,
                  color: bold ? AppColors.success : AppColors.onSurface)),
        ],
      ),
    );
  }
}
