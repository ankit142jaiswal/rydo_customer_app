import '../widgets/rydo_back_button.dart';
import '../utils/currency.dart';
import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../utils/app_colors.dart';

class RidesScreen extends StatefulWidget {
  const RidesScreen({super.key});

  @override
  State<RidesScreen> createState() => _RidesScreenState();
}

class _RidesScreenState extends State<RidesScreen> {
  List<dynamic> _rides = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  Future<void> _fetch() async {
    setState(() => _loading = true);
    final result = await ApiService.getCustomerRides();
    if (mounted) {
      setState(() {
        _loading = false;
        if (result['success'] == true) _rides = result['rides'] ?? [];
      });
    }
  }

  Color _statusColor(String s) {
    switch (s) {
      case 'requested':
        return AppColors.requested;
      case 'accepted':
        return AppColors.accepted;
      case 'started':
        return AppColors.started;
      case 'completed':
        return AppColors.completed;
      case 'cancelled':
        return AppColors.cancelled;
      default:
        return AppColors.onSurfaceVariant;
    }
  }

  // Build a standalone AppBar with logo — used when this screen is opened
  // directly via route (not via HomeScreen's IndexedStack).
  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: AppColors.dark,
      foregroundColor: Colors.white,
      elevation: 0,
      scrolledUnderElevation: 0,
      automaticallyImplyLeading: false,
      leading: const RydoBackButton(),
      title: const Text('My Rides'),
    );
  }

  @override
  Widget build(BuildContext context) {
    // When embedded in HomeScreen's IndexedStack the AppBar comes from
    // HomeScreen; when opened as a standalone route we show our own.
    final bool isStandalone =
        ModalRoute.of(context)?.settings.name == '/rides';

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: isStandalone ? _buildAppBar() : null,
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.dark),
            )
          : _rides.isEmpty
              ? const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.directions_car_outlined,
                        size: 64,
                        color: AppColors.outlineVariant,
                      ),
                      SizedBox(height: 12),
                      Text(
                        'No rides yet',
                        style: TextStyle(color: AppColors.onSurfaceVariant),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _fetch,
                  color: AppColors.primary,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _rides.length,
                    itemBuilder: (context, i) {
                      final ride = _rides[i];
                      final status =
                          ride['status']?.toString() ?? 'requested';
                      return _RideCard(
                        ride: ride,
                        status: status,
                        statusColor: _statusColor(status),
                      );
                    },
                  ),
                ),
    );
  }
}

class _RideCard extends StatelessWidget {
  const _RideCard({
    required this.ride,
    required this.status,
    required this.statusColor,
  });

  final dynamic ride;
  final String status;
  final Color statusColor;

  @override
  Widget build(BuildContext context) {
    final dateStr = ride['createdAt'] != null
        ? (DateTime.tryParse(ride['createdAt'])
                ?.toLocal()
                .toString()
                .split('.')
                .first ??
            '')
        : '';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.outline),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  ride['serviceType']?.toString() ?? 'Ride',
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                    color: AppColors.onSurface,
                  ),
                ),
                _StatusChip(label: status, color: statusColor),
              ],
            ),

            const SizedBox(height: 12),

            _AddressRow(
              icon: Icons.my_location,
              iconColor: AppColors.success,
              text: ride['pickup']?['address']?.toString() ?? 'N/A',
            ),

            const SizedBox(height: 6),

            _AddressRow(
              icon: Icons.location_on,
              iconColor: AppColors.error,
              text: ride['destination']?['address']?.toString() ?? 'N/A',
            ),

            const Padding(
              padding: EdgeInsets.symmetric(vertical: 10),
              child: Divider(height: 1, color: AppColors.outline),
            ),

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  formatRupees(ride['fare']?['total']),
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: AppColors.onSurface,
                  ),
                ),
                Text(
                  dateStr,
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }
}

class _AddressRow extends StatelessWidget {
  const _AddressRow({
    required this.icon,
    required this.iconColor,
    required this.text,
  });

  final IconData icon;
  final Color iconColor;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 15, color: iconColor),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              fontSize: 13,
              color: AppColors.onSurface,
            ),
          ),
        ),
      ],
    );
  }
}
