import 'package:flutter/material.dart';
import '../../services/api_service.dart';
import '../../utils/app_colors.dart';

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
    setState(() {
      _loading = false;
      if (result['success'] == true) _rides = result['rides'] ?? [];
    });
  }

  Color _statusColor(String s) {
    switch (s) {
      case 'requested': return AppColors.requested;
      case 'accepted': return AppColors.accepted;
      case 'started': return AppColors.started;
      case 'completed': return AppColors.completed;
      case 'cancelled': return AppColors.cancelled;
      default: return AppColors.onSurfaceVariant;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('My Rides')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _rides.isEmpty
              ? const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.directions_car_outlined, size: 64, color: Colors.grey),
                      SizedBox(height: 12),
                      Text('No rides yet', style: TextStyle(color: Colors.grey)),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _fetch,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _rides.length,
                    itemBuilder: (context, i) {
                      final ride = _rides[i];
                      final status = ride['status'] ?? 'requested';
                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(ride['serviceType'] ?? 'Ride',
                                      style: const TextStyle(fontWeight: FontWeight.bold)),
                                  Chip(
                                    label: Text(status,
                                        style: const TextStyle(color: Colors.white, fontSize: 12)),
                                    backgroundColor: _statusColor(status),
                                    padding: EdgeInsets.zero,
                                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Row(children: [
                                const Icon(Icons.my_location, size: 15, color: AppColors.success),
                                const SizedBox(width: 6),
                                Expanded(child: Text(ride['pickup']?['address'] ?? 'N/A')),
                              ]),
                              const SizedBox(height: 4),
                              Row(children: [
                                const Icon(Icons.location_on, size: 15, color: AppColors.error),
                                const SizedBox(width: 6),
                                Expanded(child: Text(ride['destination']?['address'] ?? 'N/A')),
                              ]),
                              const Divider(height: 18),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text('₹${ride['fare']?['total'] ?? 0}',
                                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                                  Text(
                                    ride['createdAt'] != null
                                        ? DateTime.tryParse(ride['createdAt'])?.toLocal().toString().split('.')[0] ?? ''
                                        : '',
                                    style: const TextStyle(fontSize: 12, color: AppColors.onSurfaceVariant),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
    );
  }
}
