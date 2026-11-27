import '../utils/currency.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../providers/auth_provider.dart';
import '../services/api_service.dart';
import '../services/razorpay_checkout.dart';
import '../services/socket_service.dart';
import '../utils/app_colors.dart';

/// Live ride screen shown after booking, from search through completion:
/// requested → accepted → arrived → started → completed (or cancelled).
class RideTrackingScreen extends StatefulWidget {
  final String rideId;
  final Map<String, dynamic>? initialRide;
  final String? rideOtp;
  const RideTrackingScreen({super.key, required this.rideId, this.initialRide, this.rideOtp});

  @override
  State<RideTrackingScreen> createState() => _RideTrackingScreenState();
}

class _RideTrackingScreenState extends State<RideTrackingScreen> {
  Map<String, dynamic>? _ride;
  String? _otp;
  Map<String, dynamic>? _driverInfo; // from ride_accepted socket payload
  LatLng? _driverPos;
  GoogleMapController? _map;
  StreamSubscription<Map<String, dynamic>>? _sub;
  Timer? _poll;

  bool _cancelling = false;
  bool _paying = false;
  bool _ratingSent = false;
  bool _sendingRating = false;
  int _rating = 5;
  final _feedback = TextEditingController();

  static const _steps = ['requested', 'accepted', 'arrived', 'started', 'completed'];

  String get _status => _ride?['status']?.toString() ?? 'requested';
  bool get _isTerminal => _status == 'completed' || _status == 'cancelled';

  @override
  void initState() {
    super.initState();
    _ride = widget.initialRide;
    _otp = widget.rideOtp ??
        Provider.of<AuthProvider>(context, listen: false).user?['rideOtp']?.toString();
    _readDriverLocation();
    final socket = Provider.of<SocketService>(context, listen: false);
    _sub = socket.rideUpdates.listen(_onSocket);
    _refresh();
    _poll = Timer.periodic(const Duration(seconds: 8), (_) {
      if (!_isTerminal) _refresh();
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    _poll?.cancel();
    _map?.dispose();
    _feedback.dispose();
    super.dispose();
  }

  // ── Data ─────────────────────────────────────────────────────────────────

  Future<void> _refresh() async {
    final res = await ApiService.getRideDetails(widget.rideId);
    if (!mounted || res['success'] != true || res['ride'] == null) return;
    final prev = _status;
    setState(() {
      _ride = Map<String, dynamic>.from(res['ride']);
      if (res['rideOtp'] != null) _otp = res['rideOtp'].toString();
    });
    _readDriverLocation();
    if (prev != _status) _fitCamera();
  }

  void _readDriverLocation() {
    final d = _ride?['driver'];
    final c = d is Map ? (d['driverDetails']?['location']?['coordinates']) : null;
    if (c is List && c.length == 2 && _driverPos == null) {
      final lng = (c[0] as num).toDouble(), lat = (c[1] as num).toDouble();
      if (lat != 0 || lng != 0) _driverPos = LatLng(lat, lng);
    }
  }

  String? get _driverId {
    final d = _ride?['driver'];
    if (d is Map) return d['_id']?.toString();
    return d?.toString();
  }

  void _onSocket(Map<String, dynamic> data) {
    if (!mounted) return;
    final event = data['_event'];

    if (event == 'driver_location' || event == 'driver_location_update') {
      // Broadcast updates carry driverId; ignore other drivers.
      final id = data['driverId']?.toString();
      if (id != null && _driverId != null && id != _driverId) return;
      if (id != null && _driverId == null) return;
      final lat = (data['latitude'] as num?)?.toDouble();
      final lng = (data['longitude'] as num?)?.toDouble();
      if (lat == null || lng == null) return;
      setState(() => _driverPos = LatLng(lat, lng));
      return;
    }

    if (data['rideId']?.toString() != widget.rideId) return;
    if (event == 'ride_accepted' && data['driver'] is Map) {
      _driverInfo = Map<String, dynamic>.from(data['driver']);
    }
    final newStatus = data['status']?.toString() ??
        {
          'ride_accepted': 'accepted',
          'ride_started': 'started',
          'ride_completed': 'completed',
          'ride_cancelled': 'cancelled',
        }[event];
    if (newStatus != null) {
      setState(() => _ride = {...?_ride, 'status': newStatus});
    }
    _refresh(); // pull full ride (driver, payment) after any change
  }

  // ── Map ──────────────────────────────────────────────────────────────────

  LatLng? _point(String key) {
    final c = _ride?[key]?['coordinates'];
    if (c is List && c.length == 2) {
      return LatLng((c[1] as num).toDouble(), (c[0] as num).toDouble());
    }
    return null;
  }

  Set<Marker> get _markers {
    final p = _point('pickup'), d = _point('destination');
    return {
      if (p != null)
        Marker(
          markerId: const MarkerId('pickup'),
          position: p,
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
          infoWindow: const InfoWindow(title: 'Pickup'),
        ),
      if (d != null)
        Marker(
          markerId: const MarkerId('drop'),
          position: d,
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
          infoWindow: const InfoWindow(title: 'Destination'),
        ),
      if (_driverPos != null && !_isTerminal && _status != 'requested')
        Marker(
          markerId: const MarkerId('driver'),
          position: _driverPos!,
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
          infoWindow: InfoWindow(title: _driverName),
        ),
    };
  }

  Set<Polyline> get _polylines {
    final p = _point('pickup'), d = _point('destination');
    final lines = <Polyline>{};
    if (p != null && d != null) {
      lines.add(Polyline(polylineId: const PolylineId('trip'), points: [p, d], width: 4, color: AppColors.dark));
    }
    if (_driverPos != null && p != null && (_status == 'accepted' || _status == 'arrived')) {
      lines.add(Polyline(
        polylineId: const PolylineId('approach'),
        points: [_driverPos!, p],
        width: 3,
        color: AppColors.info,
        patterns: [PatternItem.dash(12), PatternItem.gap(8)],
      ));
    }
    return lines;
  }

  void _fitCamera() {
    final pts = [_point('pickup'), _point('destination'), if (!_isTerminal) _driverPos].whereType<LatLng>().toList();
    if (_map == null || pts.isEmpty) return;
    if (pts.length == 1) {
      _map!.animateCamera(CameraUpdate.newLatLngZoom(pts.first, 15));
      return;
    }
    double minLat = pts.first.latitude, maxLat = minLat, minLng = pts.first.longitude, maxLng = minLng;
    for (final p in pts) {
      if (p.latitude < minLat) minLat = p.latitude;
      if (p.latitude > maxLat) maxLat = p.latitude;
      if (p.longitude < minLng) minLng = p.longitude;
      if (p.longitude > maxLng) maxLng = p.longitude;
    }
    _map!.animateCamera(CameraUpdate.newLatLngBounds(
      LatLngBounds(southwest: LatLng(minLat, minLng), northeast: LatLng(maxLat, maxLng)),
      70,
    ));
  }

  // ── Actions ──────────────────────────────────────────────────────────────

  String get _driverName {
    final d = _ride?['driver'];
    return (d is Map ? d['name'] : null)?.toString() ?? _driverInfo?['name']?.toString() ?? 'Your captain';
  }

  String? get _driverPhone {
    final d = _ride?['driver'];
    return (d is Map ? d['phone'] : null)?.toString() ?? _driverInfo?['phone']?.toString();
  }

  String? get _vehicleNumber {
    final d = _ride?['driver'];
    return (d is Map ? (d['driverDetails']?['vehicleNumber']) : null)?.toString() ??
        _driverInfo?['vehicleNumber']?.toString();
  }

  String? get _driverRating {
    final d = _ride?['driver'];
    final r = (d is Map ? (d['driverDetails']?['rating']) : null) ?? _driverInfo?['rating'];
    return r == null ? null : (r as num).toStringAsFixed(1);
  }

  double get _total => ((_ride?['fare']?['total'] ?? 0) as num).toDouble();
  String get _paymentMethod => _ride?['payment']?['method']?.toString() ?? 'cash';
  bool get _paid => _ride?['payment']?['status'] == 'completed';

  Future<void> _call() async {
    final phone = _driverPhone;
    if (phone == null || phone.isEmpty) return;
    final uri = Uri(scheme: 'tel', path: phone);
    if (!await launchUrl(uri)) _snack('Could not open dialer', AppColors.error);
  }

  Future<void> _cancel() async {
    const reasons = [
      'Driver is taking too long',
      'Changed my plans',
      'Booked by mistake',
      'Found another ride',
      'Other',
    ];
    final reason = await showModalBottomSheet<String>(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text('Why do you want to cancel?', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
            ),
            for (final r in reasons)
              ListTile(title: Text(r), trailing: const Icon(Icons.chevron_right), onTap: () => Navigator.pop(ctx, r)),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (reason == null) return;
    setState(() => _cancelling = true);
    final res = await ApiService.cancelRide(widget.rideId, reason);
    if (!mounted) return;
    setState(() => _cancelling = false);
    if (res['success'] == true) {
      setState(() => _ride = {...?_ride, 'status': 'cancelled', 'cancellationReason': reason});
    } else {
      _snack(res['message']?.toString() ?? 'Could not cancel ride', AppColors.error);
    }
  }

  Future<void> _pay() async {
    setState(() => _paying = true);
    Map<String, dynamic> res;
    if (_paymentMethod == 'wallet') {
      res = await ApiService.payFromWallet(widget.rideId, _total);
    } else {
      final user = Provider.of<AuthProvider>(context, listen: false).user ?? {};
      res = await RazorpayCheckout.payForRide(
        rideId: widget.rideId,
        amount: _total,
        customerName: user['name']?.toString() ?? 'Customer',
        customerEmail: user['email']?.toString() ?? 'customer@rydo.com',
        customerPhone: user['phone']?.toString() ?? '',
      );
    }
    if (!mounted) return;
    setState(() => _paying = false);
    _snack(res['message']?.toString() ?? (res['success'] == true ? 'Payment successful' : 'Payment failed'),
        res['success'] == true ? AppColors.success : AppColors.error);
    if (res['success'] == true) {
      setState(() => _ride = {
            ...?_ride,
            'payment': {...?(_ride?['payment'] as Map?), 'status': 'completed'},
          });
      _refresh();
    }
  }

  Future<void> _submitRating() async {
    setState(() => _sendingRating = true);
    final res = await ApiService.rateRide(widget.rideId, _rating, _feedback.text.trim());
    if (!mounted) return;
    setState(() {
      _sendingRating = false;
      _ratingSent = res['success'] == true;
    });
    _snack(res['success'] == true ? 'Thanks for your feedback!' : (res['message']?.toString() ?? 'Could not submit rating'),
        res['success'] == true ? AppColors.success : AppColors.error);
  }

  void _snack(String msg, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: color, behavior: SnackBarBehavior.floating),
    );
  }

  void _goHome() => Navigator.of(context).popUntil((r) => r.isFirst);

  // ── UI ───────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final start = _point('pickup') ?? const LatLng(12.9716, 77.5946);
    return PopScope(
      canPop: true,
      child: Scaffold(
        backgroundColor: AppColors.background,
        extendBodyBehindAppBar: true,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          foregroundColor: AppColors.dark,
          elevation: 0,
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
            Positioned.fill(
              child: GoogleMap(
                initialCameraPosition: CameraPosition(target: start, zoom: 14),
                onMapCreated: (c) {
                  _map = c;
                  _fitCamera();
                },
                markers: _markers,
                polylines: _polylines,
                myLocationEnabled: true,
                myLocationButtonEnabled: false,
                zoomControlsEnabled: false,
                mapToolbarEnabled: false,
                padding: EdgeInsets.only(bottom: MediaQuery.of(context).size.height * 0.45),
              ),
            ),
            DraggableScrollableSheet(
              initialChildSize: 0.5,
              minChildSize: 0.28,
              maxChildSize: 0.92,
              builder: (context, scroll) => Container(
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
                        decoration: BoxDecoration(color: AppColors.outlineVariant, borderRadius: BorderRadius.circular(3)),
                      ),
                    ),
                    const SizedBox(height: 14),
                    _statusHeader(),
                    const SizedBox(height: 14),
                    if (_status != 'cancelled') ...[_stepper(), const SizedBox(height: 16)],
                    if (_otp != null && (_status == 'requested' || _status == 'accepted' || _status == 'arrived')) ...[
                      _otpCard(),
                      const SizedBox(height: 12),
                    ],
                    if (_status != 'requested' && _status != 'cancelled') ...[_driverCard(), const SizedBox(height: 12)],
                    _tripCard(),
                    const SizedBox(height: 12),
                    _fareCard(),
                    const SizedBox(height: 16),
                    ..._bottomActions(),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _statusHeader() {
    final (IconData icon, String title, String sub, Color color) = switch (_status) {
      'requested' => (Icons.search_rounded, 'Finding your captain', 'Notifying nearby captains…', AppColors.requested),
      'accepted' => (Icons.directions_bike_rounded, 'Captain is on the way', '$_driverName is heading to your pickup', AppColors.accepted),
      'arrived' => (Icons.place_rounded, 'Captain has arrived', 'Meet $_driverName at the pickup point', AppColors.arrived),
      'started' => (Icons.route_rounded, 'On your trip', 'Enjoy the ride to your destination', AppColors.started),
      'completed' => (Icons.check_circle_rounded, 'You have arrived', 'Trip completed successfully', AppColors.completed),
      _ => (Icons.cancel_rounded, 'Ride cancelled', _ride?['cancellationReason']?.toString() ?? 'This ride was cancelled', AppColors.cancelled),
    };
    return Row(
      children: [
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(color: color.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(14)),
          child: _status == 'requested'
              ? Padding(padding: const EdgeInsets.all(12), child: CircularProgressIndicator(strokeWidth: 2.5, color: color))
              : Icon(icon, color: color, size: 26),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.onSurface)),
              const SizedBox(height: 2),
              Text(sub, style: const TextStyle(fontSize: 13, color: AppColors.onSurfaceVariant), maxLines: 2, overflow: TextOverflow.ellipsis),
            ],
          ),
        ),
      ],
    );
  }

  Widget _stepper() {
    const labels = ['Booked', 'Assigned', 'Arrived', 'On trip', 'Done'];
    final current = _steps.indexOf(_status);
    return Row(
      children: [
        for (var i = 0; i < _steps.length; i++) ...[
          Expanded(
            child: Column(
              children: [
                Container(
                  height: 6,
                  decoration: BoxDecoration(
                    color: i <= current ? AppColors.primary : AppColors.outline,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
                const SizedBox(height: 6),
                Text(labels[i],
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: i == current ? FontWeight.w700 : FontWeight.w500,
                      color: i <= current ? AppColors.onSurface : AppColors.onSurfaceVariant,
                    )),
              ],
            ),
          ),
          if (i < _steps.length - 1) const SizedBox(width: 4),
        ],
      ],
    );
  }

  BoxDecoration get _card => BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.outline),
      );

  Widget _otpCard() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        gradient: AppColors.darkGradient,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          const Icon(Icons.lock_rounded, color: AppColors.primary),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Your ride OTP', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                SizedBox(height: 2),
                Text('Share with your captain to start the trip',
                    style: TextStyle(color: Colors.white70, fontSize: 12)),
              ],
            ),
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final d in _otp!.split(''))
                Container(
                  width: 30,
                  height: 38,
                  margin: const EdgeInsets.only(left: 4),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(color: AppColors.primary, borderRadius: BorderRadius.circular(8)),
                  child: Text(d,
                      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: AppColors.onPrimary)),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _driverCard() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: _card,
      child: Row(
        children: [
          CircleAvatar(
            radius: 24,
            backgroundColor: AppColors.primary,
            child: Text(_driverName.isNotEmpty ? _driverName[0].toUpperCase() : 'C',
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: AppColors.onPrimary)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_driverName, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700), overflow: TextOverflow.ellipsis),
                const SizedBox(height: 2),
                Wrap(
                  spacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    if (_vehicleNumber != null)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(color: AppColors.surfaceVariant, borderRadius: BorderRadius.circular(6)),
                        child: Text(_vehicleNumber!, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, letterSpacing: 0.5)),
                      ),
                    if (_driverRating != null)
                      Row(mainAxisSize: MainAxisSize.min, children: [
                        const Icon(Icons.star_rounded, size: 16, color: AppColors.primaryDark),
                        Text(_driverRating!, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                      ]),
                  ],
                ),
              ],
            ),
          ),
          if (_driverPhone != null && !_isTerminal)
            IconButton.filled(
              onPressed: _call,
              style: IconButton.styleFrom(backgroundColor: AppColors.success, foregroundColor: Colors.white),
              icon: const Icon(Icons.call_rounded),
              tooltip: 'Call captain',
            ),
        ],
      ),
    );
  }

  Widget _tripCard() {
    Widget line(IconData icon, Color color, String label, String? text) => Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 18, color: color),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: const TextStyle(fontSize: 11, color: AppColors.onSurfaceVariant)),
                  Text(text ?? '-', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600), maxLines: 2, overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
          ],
        );
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: _card,
      child: Column(
        children: [
          line(Icons.trip_origin_rounded, AppColors.success, 'PICKUP', _ride?['pickup']?['address']?.toString()),
          const Padding(padding: EdgeInsets.symmetric(vertical: 8), child: Divider(height: 1)),
          line(Icons.location_on_rounded, AppColors.error, 'DROP', _ride?['destination']?['address']?.toString()),
          if (_ride?['returnTrip']?['enabled'] == true) ...[
            const Padding(padding: EdgeInsets.symmetric(vertical: 8), child: Divider(height: 1)),
            line(Icons.u_turn_left_rounded, AppColors.dark, 'RETURN RIDE',
                'Captain waits ${_ride?['returnTrip']?['waitMinutes']} min, then back to pickup'),
          ],
        ],
      ),
    );
  }

  Widget _fareCard() {
    final method = {'cash': 'Cash', 'online': 'Online', 'wallet': 'Wallet'}[_paymentMethod] ?? _paymentMethod;
    final dist = (_ride?['distance'] as num?)?.toStringAsFixed(1);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: _card,
      child: Row(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Total fare', style: TextStyle(fontSize: 12, color: AppColors.onSurfaceVariant)),
              Text(formatRupees(_total), style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
              if (dist != null) Text('$dist km', style: const TextStyle(fontSize: 12, color: AppColors.onSurfaceVariant)),
            ],
          ),
          const Spacer(),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(method, style: const TextStyle(fontWeight: FontWeight.w700)),
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                decoration: BoxDecoration(
                  color: (_paid ? AppColors.success : AppColors.warning).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(_paid ? 'Paid' : 'Payment pending',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: _paid ? AppColors.success : AppColors.warning)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  List<Widget> _bottomActions() {
    // Before the trip starts: allow cancel.
    if (_status == 'requested' || _status == 'accepted' || _status == 'arrived') {
      return [
        SizedBox(
          height: 52,
          child: OutlinedButton.icon(
            onPressed: _cancelling ? null : _cancel,
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.error,
              side: const BorderSide(color: AppColors.error),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            ),
            icon: _cancelling
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.error))
                : const Icon(Icons.close_rounded),
            label: Text(_cancelling ? 'Cancelling...' : 'Cancel Ride'),
          ),
        ),
      ];
    }

    if (_status == 'started') {
      return [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: AppColors.infoLight, borderRadius: BorderRadius.circular(12)),
          child: const Row(children: [
            Icon(Icons.shield_rounded, color: AppColors.info),
            SizedBox(width: 10),
            Expanded(child: Text('Your trip is in progress. Stay safe and wear your seat belt or helmet.')),
          ]),
        ),
      ];
    }

    if (_status == 'cancelled') {
      return [_primaryButton('Back to Home', Icons.home_rounded, _goHome)];
    }

    // Completed: payment → rating → done.
    return [
      if (!_paid && _paymentMethod == 'cash')
        Container(
          padding: const EdgeInsets.all(14),
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(color: AppColors.primary.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(14)),
          child: Row(children: [
            const Icon(Icons.payments_rounded, color: AppColors.dark),
            const SizedBox(width: 10),
            Expanded(
              child: Text('Please pay ${formatRupees(_total)} in cash to your captain.',
                  style: const TextStyle(fontWeight: FontWeight.w600)),
            ),
          ]),
        ),
      if (!_paid && _paymentMethod != 'cash') ...[
        _primaryButton(
          _paying ? 'Processing...' : 'Pay ${formatRupees(_total)} ${_paymentMethod == 'wallet' ? 'from Wallet' : 'Online'}',
          _paymentMethod == 'wallet' ? Icons.account_balance_wallet_rounded : Icons.credit_card_rounded,
          _paying ? null : _pay,
        ),
        const SizedBox(height: 12),
      ],
      _ratingCard(),
      const SizedBox(height: 12),
      SizedBox(
        height: 52,
        child: OutlinedButton(
          onPressed: _goHome,
          style: OutlinedButton.styleFrom(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
          child: const Text('Done'),
        ),
      ),
    ];
  }

  Widget _ratingCard() {
    if (_ratingSent) {
      return Container(
        padding: const EdgeInsets.all(14),
        decoration: _card,
        child: const Row(children: [
          Icon(Icons.favorite_rounded, color: AppColors.error),
          SizedBox(width: 10),
          Text('Thanks for rating your trip!', style: TextStyle(fontWeight: FontWeight.w600)),
        ]),
      );
    }
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: _card,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Rate your trip with $_driverName', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (var i = 1; i <= 5; i++)
                IconButton(
                  onPressed: () => setState(() => _rating = i),
                  iconSize: 36,
                  icon: Icon(i <= _rating ? Icons.star_rounded : Icons.star_outline_rounded,
                      color: i <= _rating ? AppColors.primaryDark : AppColors.outlineVariant),
                ),
            ],
          ),
          TextField(
            controller: _feedback,
            maxLines: 2,
            decoration: const InputDecoration(hintText: 'Add a comment (optional)'),
          ),
          const SizedBox(height: 12),
          _primaryButton(_sendingRating ? 'Submitting...' : 'Submit Rating', Icons.send_rounded, _sendingRating ? null : _submitRating),
        ],
      ),
    );
  }

  Widget _primaryButton(String label, IconData icon, VoidCallback? onPressed) {
    return SizedBox(
      height: 52,
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: AppColors.onPrimary,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
        icon: Icon(icon),
        label: Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
      ),
    );
  }
}
