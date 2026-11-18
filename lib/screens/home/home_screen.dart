import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../services/api_service.dart';
import '../../utils/app_colors.dart';
import '../book_ride_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  Map<String, dynamic>? _dashboard;
  bool _loading = true;

  final List<Map<String, dynamic>> _services = [
    {
      'title': 'Bike Taxi',
      'subtitle': 'Quick rides for short distances',
      'icon': Icons.motorcycle,
      'color': AppColors.bikeTaxi,
      'price': 'Starting ₹25',
      'serviceType': 'bike-taxi',
    },
    {
      'title': 'Courier',
      'subtitle': 'Send packages anywhere',
      'icon': Icons.local_shipping,
      'color': AppColors.courier,
      'price': 'Starting ₹20',
      'serviceType': 'courier',
    },
    {
      'title': 'Auto',
      'subtitle': 'Comfortable rides',
      'icon': Icons.directions_car,
      'color': AppColors.auto,
      'price': 'Starting ₹40',
      'serviceType': 'auto',
    },
    {
      'title': 'Mini Truck',
      'subtitle': 'Goods transport',
      'icon': Icons.local_shipping_outlined,
      'color': AppColors.miniTruck,
      'price': 'Starting ₹100',
      'serviceType': 'mini-truck',
    },
  ];

  @override
  void initState() {
    super.initState();
    _loadDashboard();
  }

  Future<void> _loadDashboard() async {
    final result = await ApiService.getDashboard();
    setState(() {
      _loading = false;
      if (result['success'] == true) _dashboard = result['dashboard'];
    });
  }

  void _openBookRide([String? serviceType]) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => BookRideScreen(initialServiceType: serviceType)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      drawer: _buildDrawer(context),
      appBar: AppBar(
        title: const Text('RYDO'),
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications),
            onPressed: () => Navigator.pushNamed(context, '/notifications'),
          ),
          IconButton(
            icon: const Icon(Icons.account_circle),
            onPressed: () => Navigator.pushNamed(context, '/profile'),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadDashboard,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _buildWelcome(),
                  const SizedBox(height: 16),
                  _buildStatsRow(),
                  const SizedBox(height: 20),
                  const Text('Our Services',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  GridView.count(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisCount: 2,
                    childAspectRatio: 0.9,
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
                    children: _services.map(_buildServiceCard).toList(),
                  ),
                ],
              ),
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openBookRide(),
        backgroundColor: AppColors.primary,
        icon: const Icon(Icons.add),
        label: const Text('Book Ride'),
      ),
    );
  }

  Widget _buildWelcome() {
    return Consumer<AuthProvider>(
      builder: (context, auth, child) {
        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: AppColors.primaryGradient,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Hello, ${auth.user?['name']?.toString().split(' ')[0] ?? 'User'}!',
                style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              const Text('Where would you like to go?',
                  style: TextStyle(color: Colors.white70, fontSize: 14)),
            ],
          ),
        );
      },
    );
  }

  Widget _buildStatsRow() {
    final total = _dashboard?['total'] ?? {};
    final month = _dashboard?['month'] ?? {};
    final wallet = _dashboard?['wallet'] ?? 0;
    return Row(
      children: [
        _statCard('Total Rides', '${total['rides'] ?? 0}', Icons.directions_car, AppColors.primary),
        const SizedBox(width: 12),
        _statCard('This Month', '₹${month['spending'] ?? 0}', Icons.calendar_today, AppColors.auto),
        const SizedBox(width: 12),
        _statCard('Wallet', '₹$wallet', Icons.account_balance_wallet, AppColors.success),
      ],
    );
  }

  Widget _statCard(String label, String value, IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8, offset: const Offset(0, 2)),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(height: 8),
            Text(value, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            Text(label, style: const TextStyle(fontSize: 11, color: AppColors.onSurfaceVariant)),
          ],
        ),
      ),
    );
  }

  Widget _buildServiceCard(Map<String, dynamic> service) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 5)),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () => _openBookRide(service['serviceType']),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: service['color'].withOpacity(0.1),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(service['icon'], color: service['color'], size: 26),
                ),
                const SizedBox(height: 12),
                Text(service['title'],
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.onSurface)),
                const SizedBox(height: 4),
                Text(service['subtitle'],
                    style: const TextStyle(fontSize: 11, color: AppColors.onSurfaceVariant)),
                const Spacer(),
                Text(service['price'],
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: service['color'])),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDrawer(BuildContext context) {
    Widget item(IconData icon, String label, String route) {
      return ListTile(
        leading: Icon(icon, color: AppColors.primary),
        title: Text(label),
        onTap: () {
          Navigator.pop(context);
          if (route != '/home') Navigator.pushNamed(context, route);
        },
      );
    }

    return Drawer(
      child: Consumer<AuthProvider>(
        builder: (context, auth, child) {
          final user = auth.user ?? {};
          return ListView(
            padding: EdgeInsets.zero,
            children: [
              DrawerHeader(
                decoration: const BoxDecoration(gradient: AppColors.primaryGradient),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    CircleAvatar(
                      radius: 26,
                      backgroundColor: Colors.white,
                      child: Text(
                        (user['name']?.toString() ?? 'U').substring(0, 1).toUpperCase(),
                        style: const TextStyle(color: AppColors.primary, fontSize: 24, fontWeight: FontWeight.bold),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(user['name']?.toString() ?? 'RYDO Customer',
                        style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                    Text(user['email']?.toString() ?? '',
                        style: const TextStyle(color: Colors.white70, fontSize: 12)),
                  ],
                ),
              ),
              item(Icons.home, 'Home', '/home'),
              item(Icons.directions_car, 'Book Ride', '/book'),
              item(Icons.history, 'My Rides', '/rides'),
              item(Icons.account_balance_wallet, 'Wallet', '/wallet'),
              item(Icons.notifications, 'Notifications', '/notifications'),
              item(Icons.person, 'Profile', '/profile'),
              item(Icons.settings, 'Settings', '/settings'),
              const Divider(),
              ListTile(
                leading: const Icon(Icons.logout, color: AppColors.error),
                title: const Text('Logout', style: TextStyle(color: AppColors.error)),
                onTap: () async {
                  await auth.logout();
                  if (context.mounted) {
                    Navigator.pushNamedAndRemoveUntil(context, '/login', (r) => false);
                  }
                },
              ),
            ],
          );
        },
      ),
    );
  }
}
