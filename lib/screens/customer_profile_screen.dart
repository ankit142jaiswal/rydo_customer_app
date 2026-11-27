import '../widgets/rydo_back_button.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../services/api_service.dart';
import '../../utils/app_colors.dart';

class CustomerProfileScreen extends StatefulWidget {
  const CustomerProfileScreen({super.key});

  @override
  State<CustomerProfileScreen> createState() => _CustomerProfileScreenState();
}

class _CustomerProfileScreenState extends State<CustomerProfileScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  Map<String, dynamic>? _profile;
  List<dynamic> _addresses = [];
  bool _loading = true;

  // Notification/privacy settings
  Map<String, bool> _settings = {
    'rideUpdates': true,
    'promotions': true,
    'systemUpdates': true,
    'security': true,
  };

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _load();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final profile = await ApiService.getCustomerProfile();
    final addrs = await ApiService.getAddresses();
    final settings = await ApiService.getNotificationSettings();
    setState(() {
      _loading = false;
      if (profile['success'] == true) _profile = profile['customer'];
      if (addrs['success'] == true) _addresses = addrs['addresses'] ?? [];
      if (settings['success'] == true && settings['settings'] != null) {
        final s = settings['settings'];
        _settings = {
          'rideUpdates': s['rideUpdates'] ?? true,
          'promotions': s['promotions'] ?? true,
          'systemUpdates': s['systemUpdates'] ?? true,
          'security': s['security'] ?? true,
        };
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(leading: const RydoBackButton(), title: const Text('My Profile')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                _buildHeader(),
                Container(
                  color: Colors.white,
                  child: TabBar(
                    controller: _tabController,
                    isScrollable: true,
                    labelColor: AppColors.primary,
                    unselectedLabelColor: AppColors.onSurfaceVariant,
                    indicatorColor: AppColors.primary,
                    tabs: const [
                      Tab(icon: Icon(Icons.person), text: 'Personal'),
                      Tab(icon: Icon(Icons.location_on), text: 'Addresses'),
                      Tab(icon: Icon(Icons.payment), text: 'Payment'),
                      Tab(icon: Icon(Icons.settings), text: 'Settings'),
                    ],
                  ),
                ),
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      _personalTab(),
                      _addressesTab(),
                      _paymentTab(),
                      _settingsTab(),
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildHeader() {
    final user = _profile ?? Provider.of<AuthProvider>(context, listen: false).user ?? {};
    final details = user['customerDetails'] ?? {};
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      color: Colors.white,
      child: Row(
        children: [
          Stack(
            children: [
              CircleAvatar(
                radius: 44,
                backgroundColor: AppColors.primary,
                child: Text(
                  (user['name']?.toString() ?? 'U').substring(0, 1).toUpperCase(),
                  style: const TextStyle(fontSize: 34, color: Colors.white, fontWeight: FontWeight.bold),
                ),
              ),
              Positioned(
                bottom: 0,
                right: 0,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: const BoxDecoration(color: AppColors.primary, shape: BoxShape.circle),
                  child: const Icon(Icons.camera_alt, size: 16, color: Colors.white),
                ),
              ),
            ],
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(user['name']?.toString() ?? 'User',
                          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                    ),
                    if (user['isVerified'] == true) ...[
                      const SizedBox(width: 6),
                      const Icon(Icons.verified, color: AppColors.success, size: 20),
                    ],
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(Icons.star, color: Color(0xFFFFD700), size: 18),
                    Text(' ${details['rating'] ?? 5.0}',
                        style: const TextStyle(fontWeight: FontWeight.w500)),
                    const SizedBox(width: 12),
                    Text('${details['totalRides'] ?? 0} rides',
                        style: const TextStyle(color: AppColors.onSurfaceVariant, fontSize: 13)),
                  ],
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                      decoration: BoxDecoration(
                        color: AppColors.success.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Text('Active',
                          style: TextStyle(color: AppColors.success, fontSize: 12, fontWeight: FontWeight.w600)),
                    ),
                    if ((details['rideOtp'] ?? user['rideOtp']) != null)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppColors.dark,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text('Ride OTP: ${details['rideOtp'] ?? user['rideOtp']}',
                            style: const TextStyle(
                                color: AppColors.primary, fontSize: 12, fontWeight: FontWeight.w800, letterSpacing: 1)),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // TAB 1: Personal Info
  Widget _personalTab() {
    final user = _profile ?? {};
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Personal Information',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  OutlinedButton.icon(
                    onPressed: _editPersonal,
                    icon: const Icon(Icons.edit, size: 16),
                    label: const Text('Edit'),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _field('Full Name', user['name']?.toString() ?? 'N/A', Icons.person),
              _field('Email', user['email']?.toString() ?? 'N/A', Icons.email),
              _field('Phone Number', user['phone']?.toString() ?? 'N/A', Icons.phone),
              _field('Wallet Balance', '₹${user['wallet'] ?? 0}', Icons.account_balance_wallet),
            ],
          ),
        ),
      ),
    );
  }

  // TAB 2: Saved Addresses
  Widget _addressesTab() {
    final icons = {'home': '🏠', 'work': '🏢', 'other': '📍'};
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Saved Addresses',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  OutlinedButton.icon(
                    onPressed: _addAddress,
                    icon: const Icon(Icons.add_location_alt, size: 16),
                    label: const Text('Add'),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              if (_addresses.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(20),
                  child: Center(child: Text('No saved addresses', style: TextStyle(color: Colors.grey))),
                )
              else
                ..._addresses.map((a) {
                  final type = a['type']?.toString() ?? 'other';
                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Text(icons[type] ?? '📍', style: const TextStyle(fontSize: 28)),
                    title: Text(type[0].toUpperCase() + type.substring(1),
                        style: const TextStyle(fontWeight: FontWeight.w600)),
                    subtitle: Text(a['address']?.toString() ?? ''),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete_outline, color: AppColors.error),
                      onPressed: () => _deleteAddress(type),
                    ),
                  );
                }),
            ],
          ),
        ),
      ),
    );
  }

  // TAB 3: Payment Methods
  Widget _paymentTab() {
    final user = _profile ?? {};
    final methods = [
      {'type': 'Rydo Wallet', 'details': '₹${user['wallet'] ?? 0}', 'default': true, 'icon': Icons.account_balance_wallet},
      {'type': 'Cash', 'details': 'Pay after ride', 'default': false, 'icon': Icons.money},
      {'type': 'UPI / Online', 'details': 'Razorpay', 'default': false, 'icon': Icons.qr_code},
    ];
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Payment Methods',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              ...methods.map((m) => ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(m['icon'] as IconData, color: AppColors.primary),
                    title: Row(
                      children: [
                        Text(m['type'] as String, style: const TextStyle(fontWeight: FontWeight.w600)),
                        if (m['default'] == true) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Text('Default',
                                style: TextStyle(color: AppColors.primary, fontSize: 11)),
                          ),
                        ],
                      ],
                    ),
                    subtitle: Text(m['details'] as String),
                  )),
            ],
          ),
        ),
      ),
    );
  }

  // TAB 4: Settings
  Widget _settingsTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Notification Preferences',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  _switch('Ride Updates', 'rideUpdates'),
                  _switch('Promotions & Offers', 'promotions'),
                  _switch('System Updates', 'systemUpdates'),
                  _switch('Security Alerts', 'security'),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(onPressed: _saveSettings, child: const Text('Save Preferences')),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Account Actions',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  _actionButton('Change Password', Icons.lock_outline, () => _notImplemented('Change Password')),
                  _actionButton('Download My Data', Icons.download, () => _notImplemented('Download Data')),
                  _actionButton('Logout', Icons.logout, _logout, color: AppColors.error),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _field(String label, String value, IconData icon) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, color: AppColors.onSurfaceVariant, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(fontSize: 12, color: AppColors.onSurfaceVariant)),
                Text(value, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _switch(String label, String key) {
    return SwitchListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(label),
      value: _settings[key] ?? true,
      activeColor: AppColors.primary,
      onChanged: (v) => setState(() => _settings[key] = v),
    );
  }

  Widget _actionButton(String label, IconData icon, VoidCallback onTap, {Color? color}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: SizedBox(
        width: double.infinity,
        child: OutlinedButton.icon(
          onPressed: onTap,
          icon: Icon(icon, color: color),
          label: Align(alignment: Alignment.centerLeft, child: Text(label, style: TextStyle(color: color))),
          style: OutlinedButton.styleFrom(
            side: BorderSide(color: color ?? AppColors.outline),
            alignment: Alignment.centerLeft,
          ),
        ),
      ),
    );
  }

  // Actions
  Future<void> _editPersonal() async {
    final user = _profile ?? {};
    final nameC = TextEditingController(text: user['name']?.toString() ?? '');
    final phoneC = TextEditingController(text: user['phone']?.toString() ?? '');
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Edit Personal Information'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: nameC, decoration: const InputDecoration(labelText: 'Name')),
          const SizedBox(height: 12),
          TextField(controller: phoneC, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: 'Phone')),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Save')),
        ],
      ),
    );
    if (ok != true) return;
    final result = await ApiService.updateCustomerProfile({'name': nameC.text.trim(), 'phone': phoneC.text.trim()});
    if (!mounted) return;
    if (result['success'] == true) {
      Provider.of<AuthProvider>(context, listen: false).updateProfile({'name': nameC.text.trim(), 'phone': phoneC.text.trim()});
      _snack('Profile updated', AppColors.success);
      _load();
    } else {
      _snack(result['message'] ?? 'Update failed', AppColors.error);
    }
  }

  Future<void> _addAddress() async {
    String type = 'home';
    final addrC = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          title: const Text('Add Address'),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            DropdownButtonFormField<String>(
              value: type,
              decoration: const InputDecoration(labelText: 'Type'),
              items: const [
                DropdownMenuItem(value: 'home', child: Text('Home')),
                DropdownMenuItem(value: 'work', child: Text('Work')),
                DropdownMenuItem(value: 'other', child: Text('Other')),
              ],
              onChanged: (v) => setLocal(() => type = v!),
            ),
            const SizedBox(height: 12),
            TextField(controller: addrC, decoration: const InputDecoration(labelText: 'Address')),
          ]),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
            ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Save')),
          ],
        ),
      ),
    );
    if (ok != true || addrC.text.trim().isEmpty) return;
    final result = await ApiService.addAddress(type, addrC.text.trim(), [77.5946, 12.9716]);
    if (!mounted) return;
    if (result['success'] == true) {
      _snack('Address saved', AppColors.success);
      _load();
    } else {
      _snack(result['message'] ?? 'Failed', AppColors.error);
    }
  }

  Future<void> _deleteAddress(String type) async {
    final result = await ApiService.deleteAddress(type);
    if (!mounted) return;
    if (result['success'] == true) {
      _snack('Address deleted', AppColors.success);
      _load();
    } else {
      _snack(result['message'] ?? 'Failed', AppColors.error);
    }
  }

  Future<void> _saveSettings() async {
    final result = await ApiService.updateNotificationSettings(_settings);
    if (!mounted) return;
    _snack(result['success'] == true ? 'Preferences saved' : (result['message'] ?? 'Failed'),
        result['success'] == true ? AppColors.success : AppColors.error);
  }

  void _notImplemented(String feature) {
    _snack('$feature - contact support', AppColors.info);
  }

  Future<void> _logout() async {
    await Provider.of<AuthProvider>(context, listen: false).logout();
    if (mounted) Navigator.pushNamedAndRemoveUntil(context, '/login', (r) => false);
  }

  void _snack(String msg, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: color));
  }
}
