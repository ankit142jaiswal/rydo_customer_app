import '../../widgets/rydo_back_button.dart';
import '../../utils/currency.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:async';
import '../../providers/auth_provider.dart';
import '../../providers/notification_provider.dart';
import '../../services/api_service.dart';
import '../../services/socket_service.dart';
import '../../utils/app_colors.dart';
import '../../utils/service_catalog.dart';
import '../book_ride_screen.dart';
import '../ride_tracking_screen.dart';
import '../rides_screen.dart';
import '../wallet_screen.dart';
import '../customer_profile_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;
  Map<String, dynamic>? _dashboard;
  bool _loading = true;
  StreamSubscription<Map<String, dynamic>>? _rideSub;

  @override
  void initState() {
    super.initState();
    _loadDashboard();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initSocket();
      Provider.of<NotificationProvider>(context, listen: false)
          .fetchNotifications();
    });
  }

  void _initSocket() {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final socket = Provider.of<SocketService>(context, listen: false);
    final customerId = auth.user?['id']?.toString() ??
        auth.user?['_id']?.toString() ??
        auth.user?['userId']?.toString();
    if (customerId != null) {
      socket.connect(customerId);
    }
    _rideSub = socket.rideUpdates.listen(_onRideUpdate);
  }

  void _onRideUpdate(Map<String, dynamic> data) {
    if (!mounted) return;
    final event = data['_event']?.toString() ?? '';
    // Location pings are handled by the tracking screen; don't touch the badge.
    if (event == 'driver_location' || event == 'driver_location_update') return;
    _loadDashboard(silent: true); // keep the active-ride banner in sync
    // Refresh notifications badge
    Provider.of<NotificationProvider>(context, listen: false)
        .incrementUnread();

    final statusMsg = {
      'arrived': '📍 Your captain has arrived at pickup.',
      'started': '🛣️ Your ride has started!',
      'completed': '✅ Your ride is complete.',
      'cancelled': '❌ Your ride was cancelled.',
    };
    final messages = {
      'ride_accepted': '🚗 A captain has accepted your ride!',
      'ride_started': '🛣️ Your ride has started!',
      'ride_completed': '✅ Your ride is complete.',
      'ride_cancelled': '❌ Your ride was cancelled.',
      if (event == 'ride_status_update' && statusMsg[data['status']] != null)
        'ride_status_update': statusMsg[data['status']]!,
    };
    final msg = messages[event];
    if (msg != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(msg),
          backgroundColor: event == 'ride_cancelled'
              ? AppColors.error
              : event == 'ride_completed'
                  ? AppColors.success
                  : AppColors.dark,
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          duration: const Duration(seconds: 4),
          action: SnackBarAction(
            label: 'View',
            textColor: AppColors.primary,
            onPressed: () => Navigator.pushNamed(context, '/rides'),
          ),
        ),
      );
    }
  }

  @override
  void dispose() {
    _rideSub?.cancel();
    super.dispose();
  }

  Future<void> _loadDashboard({bool silent = false}) async {
    if (!silent) setState(() => _loading = true);
    final result = await ApiService.getDashboard();
    if (mounted) {
      setState(() {
        _loading = false;
        if (result['success'] == true) _dashboard = result['dashboard'];
      });
    }
  }

  void _openBookRide([String? serviceType]) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => BookRideScreen(initialServiceType: serviceType),
      ),
    );
  }

  // ── Bottom navigation tab pages ──────────────────────────────────────────
  List<Widget> get _pages => [
        _HomePage(
          loading: _loading,
          dashboard: _dashboard,
          onRefresh: _loadDashboard,
          onServiceTap: _openBookRide,
          onBookTap: () => _openBookRide(),
          onTabTap: (i) => setState(() => _currentIndex = i),
        ),
        const RidesScreen(),
        const WalletScreen(),
        const CustomerProfileScreen(),
      ];

  void _goHomeTab() => setState(() => _currentIndex = 0);

  @override
  Widget build(BuildContext context) {
    final tabTitles = ['Home', 'Rides', 'Wallet', 'Profile'];

    return PopScope(
      // System back on Rides/Wallet/Profile tabs returns to the Home tab
      canPop: _currentIndex == 0,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && _currentIndex != 0) setState(() => _currentIndex = 0);
      },
      child: Scaffold(
      backgroundColor: AppColors.background,
      // ── Side navigation drawer ─────────────────────────────────────────
      drawer: _buildDrawer(context),
      appBar: AppBar(
        backgroundColor: AppColors.dark,
        elevation: 0,
        scrolledUnderElevation: 0,
        // Home tab: logo opens the drawer. Other tabs: back arrow to Home.
        automaticallyImplyLeading: false,
        leading: _currentIndex != 0
            ? IconButton(
                icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
                tooltip: 'Back',
                onPressed: () => setState(() => _currentIndex = 0),
              )
            : Builder(
          builder: (ctx) => InkWell(
            onTap: () => Scaffold.of(ctx).openDrawer(),
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Image.asset(
                  'assets/images/rydo_icon.png',
                  fit: BoxFit.cover,
                ),
              ),
            ),
          ),
        ),
        // No title — logo IS the brand identity + menu trigger
        title: null,
        actions: [
          Consumer<NotificationProvider>(
            builder: (context, notifProvider, _) {
              final count = notifProvider.unreadCount;
              return Stack(
                alignment: Alignment.center,
                children: [
                  IconButton(
                    icon: const Icon(Icons.notifications_outlined,
                        color: Colors.white),
                    tooltip: 'Notifications',
                    onPressed: () {
                      Navigator.pushNamed(context, '/notifications').then((_) {
                        Provider.of<NotificationProvider>(context,
                                listen: false)
                            .fetchNotifications();
                      });
                    },
                  ),
                  if (count > 0)
                    Positioned(
                      top: 8,
                      right: 8,
                      child: Container(
                        padding: const EdgeInsets.all(3),
                        decoration: const BoxDecoration(
                          color: AppColors.primary,
                          shape: BoxShape.circle,
                        ),
                        constraints: const BoxConstraints(
                          minWidth: 16,
                          minHeight: 16,
                        ),
                        child: Text(
                          count > 99 ? '99+' : '$count',
                          style: const TextStyle(
                            color: AppColors.onPrimary,
                            fontSize: 9,
                            fontWeight: FontWeight.w800,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.settings_outlined, color: Colors.white),
            tooltip: 'Settings',
            onPressed: () => Navigator.pushNamed(context, '/settings'),
          ),
          const SizedBox(width: 4),
        ],
      ),

      body: HomeTabScope(
        goHome: _goHomeTab,
        child: IndexedStack(
          index: _currentIndex,
          children: _pages,
        ),
      ),

      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (i) => setState(() => _currentIndex = i),
        type: BottomNavigationBarType.fixed,
        backgroundColor: Colors.white,
        selectedItemColor: AppColors.dark,
        unselectedItemColor: AppColors.onSurfaceVariant,
        selectedLabelStyle: const TextStyle(
          fontWeight: FontWeight.w700,
          fontSize: 11,
        ),
        unselectedLabelStyle: const TextStyle(fontSize: 11),
        elevation: 16,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home_outlined),
            activeIcon: Icon(Icons.home),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.directions_car_outlined),
            activeIcon: Icon(Icons.directions_car),
            label: 'Rides',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.account_balance_wallet_outlined),
            activeIcon: Icon(Icons.account_balance_wallet),
            label: 'Wallet',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person_outline),
            activeIcon: Icon(Icons.person),
            label: 'Profile',
          ),
        ],
      ),

      floatingActionButton: _currentIndex == 0
          ? FloatingActionButton.extended(
              onPressed: () => _openBookRide(),
              backgroundColor: AppColors.primary,
              foregroundColor: AppColors.onPrimary,
              elevation: 4,
              icon: const Icon(Icons.add_road),
              label: const Text(
                'Book Ride',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
            )
          : null,
      ),
    );
  }

  // ── Drawer ───────────────────────────────────────────────────────────────
  Widget _buildDrawer(BuildContext context) {
    Widget _item(IconData icon, String label, VoidCallback onTap,
        {Color? color}) {
      return ListTile(
        leading: Icon(icon, color: color ?? AppColors.dark, size: 22),
        title: Text(
          label,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: color ?? AppColors.onSurface,
          ),
        ),
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        onTap: () {
          Navigator.pop(context); // close drawer first
          onTap();
        },
      );
    }

    void _go(String route) => Navigator.pushNamed(context, route);
    void _tab(int i) => setState(() => _currentIndex = i);

    return Drawer(
      child: Consumer<AuthProvider>(
        builder: (ctx, auth, _) {
          final user = auth.user ?? {};
          final name = user['name']?.toString() ?? 'Rydo User';
          final email = user['email']?.toString() ?? '';
          final wallet = user['wallet'] ?? 0;
          final initial =
              name.isNotEmpty ? name[0].toUpperCase() : 'R';

          return Column(
            children: [
              // ── Header ─────────────────────────────────────────────────
              Container(
                width: double.infinity,
                padding: EdgeInsets.only(
                  top: MediaQuery.of(context).padding.top + 20,
                  left: 20,
                  right: 20,
                  bottom: 24,
                ),
                decoration:
                    const BoxDecoration(gradient: AppColors.darkGradient),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // User avatar
                    CircleAvatar(
                      radius: 30,
                      backgroundColor: AppColors.primary,
                      child: Text(
                        initial,
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w800,
                          color: AppColors.onPrimary,
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      name,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (email.isNotEmpty)
                      Text(
                        email,
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.72),
                          fontSize: 12,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    const SizedBox(height: 10),
                    // Wallet balance chip
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 5),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withOpacity(0.18),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                            color: AppColors.primary.withOpacity(0.4)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.account_balance_wallet,
                              color: AppColors.primary, size: 14),
                          const SizedBox(width: 6),
                          Text(
                            'Wallet: ₹$wallet',
                            style: const TextStyle(
                              color: AppColors.primary,
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // ── Nav items ───────────────────────────────────────────────
              Expanded(
                child: ListView(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                  children: [
                    _item(Icons.home_rounded, 'Home', () => _tab(0)),
                    _item(Icons.add_road_rounded, 'Book a Ride',
                        () => _openBookRide()),
                    _item(Icons.directions_car_rounded, 'My Rides',
                        () => _tab(1)),
                    _item(Icons.account_balance_wallet_rounded, 'Wallet',
                        () => _tab(2)),
                    _item(Icons.person_rounded, 'Profile', () => _tab(3)),
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 8),
                      child: Divider(height: 24),
                    ),
                    _item(Icons.notifications_rounded, 'Notifications',
                        () => _go('/notifications')),
                    _item(Icons.settings_rounded, 'Settings',
                        () => _go('/settings')),
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 8),
                      child: Divider(height: 24),
                    ),
                    _item(
                      Icons.logout_rounded,
                      'Log Out',
                      () async {
                        final confirmed = await showDialog<bool>(
                          context: context,
                          builder: (ctx) => AlertDialog(
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(20)),
                            title: const Text('Log Out'),
                            content: const Text(
                                'Are you sure you want to log out?'),
                            actions: [
                              TextButton(
                                onPressed: () =>
                                    Navigator.pop(ctx, false),
                                child: const Text('Cancel'),
                              ),
                              ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.error,
                                  foregroundColor: Colors.white,
                                ),
                                onPressed: () =>
                                    Navigator.pop(ctx, true),
                                child: const Text('Log Out'),
                              ),
                            ],
                          ),
                        );
                        if (confirmed == true && context.mounted) {
                          await Provider.of<AuthProvider>(context,
                                  listen: false)
                              .logout();
                          if (context.mounted) {
                            Navigator.pushNamedAndRemoveUntil(
                                context, '/login', (r) => false);
                          }
                        }
                      },
                      color: AppColors.error,
                    ),
                  ],
                ),
              ),

              // ── Footer version label ────────────────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                child: Text(
                  'Rydo v1.0.0',
                  style: TextStyle(
                    fontSize: 11,
                    color: AppColors.onSurfaceVariant.withOpacity(0.6),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

// ── Home tab content ─────────────────────────────────────────────────────────
class _HomePage extends StatelessWidget {
  const _HomePage({
    required this.loading,
    required this.dashboard,
    required this.onRefresh,
    required this.onServiceTap,
    required this.onBookTap,
    required this.onTabTap,
  });

  final void Function(int index) onTabTap;
  final bool loading;
  final Map<String, dynamic>? dashboard;
  final Future<void> Function() onRefresh;
  final void Function(String serviceType) onServiceTap;
  final VoidCallback onBookTap;

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.dark),
      );
    }

    return RefreshIndicator(
      onRefresh: onRefresh,
      color: AppColors.primary,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final sw = constraints.maxWidth;
          // 2 columns on phones; 3 on tablets (>= 600 px)
          final cols = sw >= 600 ? 3 : 2;
          final hPad = sw < 360 ? 12.0 : 16.0;

          return ListView(
            padding: EdgeInsets.symmetric(horizontal: hPad, vertical: 16),
            children: [
              _HeroBanner(dashboard: dashboard),
              if (dashboard?['activeRide'] is Map) ...[
                const SizedBox(height: 12),
                _ActiveRideBanner(
                  ride: Map<String, dynamic>.from(dashboard!['activeRide']),
                  onClosed: onRefresh,
                ),
              ],
              const SizedBox(height: 16),
              _StatsRow(dashboard: dashboard, onTabTap: onTabTap),
              for (final cat in ServiceCatalog.categories) ...[
                const SizedBox(height: 20),
                _SectionHeader(title: cat.title, subtitle: cat.subtitle),
                const SizedBox(height: 12),
                _ServiceGrid(
                  services: [
                    for (final s in cat.services)
                      {
                        'title': s.title,
                        'subtitle': s.subtitle,
                        'icon': s.icon,
                        'color': s.color,
                        'price': s.price,
                        'serviceType': s.type,
                      }
                  ],
                  columns: cols,
                  onTap: onServiceTap,
                ),
              ],
              // Extra space above FAB
              const SizedBox(height: 80),
            ],
          );
        },
      ),
    );
  }
}

// ── Active ride banner ───────────────────────────────────────────────────────
class _ActiveRideBanner extends StatelessWidget {
  const _ActiveRideBanner({required this.ride, required this.onClosed});

  final Map<String, dynamic> ride;
  final Future<void> Function() onClosed;

  @override
  Widget build(BuildContext context) {
    final status = ride['status']?.toString() ?? 'requested';
    final label = {
          'requested': 'Finding your captain…',
          'accepted': 'Captain is on the way',
          'arrived': 'Captain has arrived',
          'started': 'Trip in progress',
        }[status] ??
        'Ride in progress';
    final dest = ride['destination']?['address']?.toString() ?? '';
    return Material(
      color: AppColors.primary,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => RideTrackingScreen(rideId: ride['rideId'].toString(), initialRide: ride),
            ),
          );
          onClosed();
        },
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              const Icon(Icons.directions_bike_rounded, color: AppColors.onPrimary),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label, style: const TextStyle(fontWeight: FontWeight.w800, color: AppColors.onPrimary)),
                    if (dest.isNotEmpty)
                      Text('To $dest',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 12, color: AppColors.onPrimary)),
                  ],
                ),
              ),
              const Text('Track', style: TextStyle(fontWeight: FontWeight.w700, color: AppColors.onPrimary)),
              const Icon(Icons.chevron_right_rounded, color: AppColors.onPrimary),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Hero greeting banner ─────────────────────────────────────────────────────
class _HeroBanner extends StatelessWidget {
  const _HeroBanner({required this.dashboard});

  final Map<String, dynamic>? dashboard;

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthProvider>(
      builder: (context, auth, _) {
        final firstName =
            auth.user?['name']?.toString().split(' ').first ?? 'there';
        final totalRides =
            dashboard?['total']?['rides']?.toString() ?? '0';

        return Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF1A1A2E), Color(0xFF0F3460), Color(0xFFFFC107)],
              stops: [0.0, 0.6, 1.0],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: AppColors.dark.withOpacity(0.25),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Hello, $firstName! 👋',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Where would you like to go today?',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.75),
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.directions_car,
                          color: AppColors.primary,
                          size: 16,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '$totalRides rides',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

// ── Stats row ─────────────────────────────────────────────────────────────────
class _StatsRow extends StatelessWidget {
  const _StatsRow({required this.dashboard, required this.onTabTap});

  final void Function(int index) onTabTap;
  final Map<String, dynamic>? dashboard;

  @override
  Widget build(BuildContext context) {
    final total = dashboard?['total'] ?? {};
    final month = dashboard?['month'] ?? {};
    final wallet = dashboard?['wallet'] ?? 0;

    return Row(
      children: [
        _StatCard(
          label: 'Total Rides',
          value: '${total['rides'] ?? 0}',
          icon: Icons.directions_car,
          iconColor: AppColors.bikeTaxi,
          onTap: () => onTabTap(1),
        ),
        const SizedBox(width: 10),
        _StatCard(
          label: 'This Month',
          value: formatRupees(month['spending']),
          icon: Icons.calendar_today,
          iconColor: AppColors.auto,
          onTap: () => onTabTap(1),
        ),
        const SizedBox(width: 10),
        _StatCard(
          label: 'Wallet',
          value: '₹$wallet',
          icon: Icons.account_balance_wallet,
          iconColor: AppColors.success,
          onTap: () => onTabTap(2),
        ),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.iconColor,
    required this.onTap,
  });

  final VoidCallback onTap;
  final String label;
  final String value;
  final IconData icon;
  final Color iconColor;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.outline),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: iconColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: iconColor, size: 20),
            ),
            const SizedBox(height: 10),
            Text(
              value,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: AppColors.onSurface,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: const TextStyle(
                fontSize: 11,
                color: AppColors.onSurfaceVariant,
              ),
            ),
          ],
        ),
          ),
        ),
      ),
    );
  }
}

// ── Section header ────────────────────────────────────────────────────────────
class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: AppColors.onSurface,
              ),
            ),
            Text(
              subtitle,
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

// ── Service grid ──────────────────────────────────────────────────────────────
class _ServiceGrid extends StatelessWidget {
  const _ServiceGrid({
    required this.services,
    required this.columns,
    required this.onTap,
  });

  final List<Map<String, dynamic>> services;
  final int columns;
  final void Function(String) onTap;

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: services.length,
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: columns,
        childAspectRatio: 0.88,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      itemBuilder: (context, i) {
        final s = services[i];
        return _ServiceCard(service: s, onTap: () => onTap(s['serviceType']));
      },
    );
  }
}

class _ServiceCard extends StatelessWidget {
  const _ServiceCard({required this.service, required this.onTap});

  final Map<String, dynamic> service;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final Color color = service['color'] as Color;

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.outline),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Icon badge
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(
                    service['icon'] as IconData,
                    color: color,
                    size: 26,
                  ),
                ),

                const SizedBox(height: 14),

                Text(
                  service['title'] as String,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppColors.onSurface,
                  ),
                ),

                const SizedBox(height: 3),

                Text(
                  service['subtitle'] as String,
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.onSurfaceVariant,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),

                const Spacer(),

                // Price pill
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    service['price'] as String,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: color,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
