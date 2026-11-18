import 'package:flutter/material.dart';
import '../../services/api_service.dart';
import '../../utils/app_colors.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  Map<String, bool> _settings = {
    'rideUpdates': true,
    'promotions': true,
    'systemUpdates': true,
    'security': true,
  };
  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  Future<void> _fetch() async {
    setState(() => _loading = true);
    final result = await ApiService.getNotificationSettings();
    setState(() {
      _loading = false;
      if (result['success'] == true && result['settings'] != null) {
        final s = result['settings'];
        _settings = {
          'rideUpdates': s['rideUpdates'] ?? true,
          'promotions': s['promotions'] ?? true,
          'systemUpdates': s['systemUpdates'] ?? true,
          'security': s['security'] ?? true,
        };
      }
    });
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    final result = await ApiService.updateNotificationSettings(_settings);
    setState(() => _saving = false);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(result['success'] == true ? 'Settings saved' : (result['message'] ?? 'Failed')),
      backgroundColor: result['success'] == true ? AppColors.success : AppColors.error,
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Settings')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                const Text('Notification Preferences',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                _toggle('Ride Updates', 'rideUpdates', Icons.directions_car),
                _toggle('Promotions & Offers', 'promotions', Icons.local_offer),
                _toggle('System Updates', 'systemUpdates', Icons.info),
                _toggle('Security Alerts', 'security', Icons.security),
                const SizedBox(height: 24),
                SizedBox(
                  height: 52,
                  child: ElevatedButton(
                    onPressed: _saving ? null : _save,
                    child: _saving
                        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                        : const Text('Save Settings'),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _toggle(String label, String key, IconData icon) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: SwitchListTile(
        secondary: Icon(icon, color: AppColors.primary),
        title: Text(label),
        value: _settings[key] ?? true,
        onChanged: (v) => setState(() => _settings[key] = v),
      ),
    );
  }
}
