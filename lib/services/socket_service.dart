import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;
import '../config/api_config.dart';

/// Real-time socket connection for the customer app.
///
/// On connect it joins the `customer_<id>` room so the backend can push
/// ride lifecycle events directly to this customer:
///   • ride_accepted  — a captain accepted the ride
///   • ride_started   — captain has started the trip
///   • ride_completed — trip is finished
///   • ride_cancelled — ride was cancelled
class SocketService extends ChangeNotifier {
  io.Socket? _socket;
  bool _connected = false;
  String? _customerId;

  bool get connected => _connected;

  // Stream for any ride-status update (payload contains the full ride object)
  final StreamController<Map<String, dynamic>> _rideUpdateController =
      StreamController<Map<String, dynamic>>.broadcast();
  Stream<Map<String, dynamic>> get rideUpdates => _rideUpdateController.stream;

  void connect(String customerId) {
    if (_socket != null && _connected && _customerId == customerId) return;
    _customerId = customerId;

    _socket = io.io(
      ApiConfig.socketUrl,
      io.OptionBuilder()
          .setTransports(['websocket'])
          .enableForceNew()
          .enableAutoConnect()
          .build(),
    );

    _socket!.onConnect((_) {
      _connected = true;
      // Join the customer's room so targeted events reach this device
      _socket!.emit('join_customer', customerId);
      notifyListeners();
      debugPrint('Customer socket connected, joined customer_$customerId');
    });

    _socket!.onDisconnect((_) {
      _connected = false;
      notifyListeners();
      debugPrint('Customer socket disconnected');
    });

    // Listen for all ride lifecycle events and forward them on the stream
    for (final event in [
      'ride_accepted',
      'ride_started',
      'ride_completed',
      'ride_cancelled',
      'driver_location_update',
    ]) {
      _socket!.on(event, (data) {
        if (data is Map) {
          final payload = Map<String, dynamic>.from(data);
          payload['_event'] = event; // tag with the event name for consumers
          _rideUpdateController.add(payload);
        }
      });
    }

    _socket!.connect();
  }

  void disconnect() {
    _socket?.disconnect();
    _socket?.dispose();
    _socket = null;
    _connected = false;
    _customerId = null;
  }

  @override
  void dispose() {
    _rideUpdateController.close();
    disconnect();
    super.dispose();
  }
}
