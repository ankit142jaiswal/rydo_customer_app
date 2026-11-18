import 'package:flutter/material.dart';
import '../../services/api_service.dart';
import '../../utils/app_colors.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  List<dynamic> _notifications = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  Future<void> _fetch() async {
    setState(() => _loading = true);
    final result = await ApiService.getNotifications();
    setState(() {
      _loading = false;
      if (result['success'] == true) _notifications = result['notifications'] ?? [];
    });
  }

  Future<void> _markRead(String id) async {
    await ApiService.markNotificationRead(id);
    _fetch();
  }

  Future<void> _markAllRead() async {
    await ApiService.markAllNotificationsRead();
    _fetch();
  }

  Future<void> _delete(String id) async {
    await ApiService.deleteNotification(id);
    _fetch();
  }

  IconData _typeIcon(String type) {
    switch (type) {
      case 'ride_update': return Icons.directions_car;
      case 'promotion': return Icons.local_offer;
      case 'security': return Icons.security;
      case 'system': return Icons.info;
      default: return Icons.notifications;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Notifications'),
        actions: [
          IconButton(
            icon: const Icon(Icons.done_all),
            tooltip: 'Mark all read',
            onPressed: _markAllRead,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _notifications.isEmpty
              ? const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.notifications_off_outlined, size: 64, color: Colors.grey),
                      SizedBox(height: 12),
                      Text('No notifications', style: TextStyle(color: Colors.grey)),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _fetch,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(12),
                    itemCount: _notifications.length,
                    itemBuilder: (context, i) {
                      final n = _notifications[i];
                      final isRead = n['isRead'] == true;
                      return Dismissible(
                        key: Key(n['_id'] ?? '$i'),
                        direction: DismissDirection.endToStart,
                        background: Container(
                          alignment: Alignment.centerRight,
                          padding: const EdgeInsets.only(right: 20),
                          color: AppColors.error,
                          child: const Icon(Icons.delete, color: Colors.white),
                        ),
                        onDismissed: (_) => _delete(n['_id']),
                        child: Card(
                          color: isRead ? Colors.white : AppColors.infoLight,
                          margin: const EdgeInsets.only(bottom: 8),
                          child: ListTile(
                            leading: CircleAvatar(
                              backgroundColor: AppColors.primary.withOpacity(0.1),
                              child: Icon(_typeIcon(n['type'] ?? ''), color: AppColors.primary),
                            ),
                            title: Text(n['title'] ?? '',
                                style: TextStyle(fontWeight: isRead ? FontWeight.normal : FontWeight.bold)),
                            subtitle: Text(n['message'] ?? ''),
                            trailing: isRead
                                ? null
                                : const Icon(Icons.circle, size: 10, color: AppColors.primary),
                            onTap: isRead ? null : () => _markRead(n['_id']),
                          ),
                        ),
                      );
                    },
                  ),
                ),
    );
  }
}
