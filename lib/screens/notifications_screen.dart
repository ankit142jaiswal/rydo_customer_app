import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/notification_provider.dart';
import '../utils/app_colors.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<NotificationProvider>(context, listen: false)
          .fetchNotifications();
    });
  }

  IconData _typeIcon(String type) {
    switch (type) {
      case 'ride_update': return Icons.directions_car;
      case 'promotion':   return Icons.local_offer;
      case 'security':    return Icons.security;
      case 'system':      return Icons.info;
      default:            return Icons.notifications;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.dark,
        foregroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: Padding(
          padding: const EdgeInsets.all(8),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Padding(
              padding: EdgeInsets.all(10),
              child: Image(
                image: AssetImage('assets/images/rydo_logo.png'),
                fit: BoxFit.contain,
              ),
            ),
          ),
        ),
        title: const Text(
          'Notifications',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w700,
            fontSize: 20,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.done_all, color: Colors.white),
            tooltip: 'Mark all read',
            onPressed: () =>
                Provider.of<NotificationProvider>(context, listen: false)
                    .markAllRead(),
          ),
        ],
      ),
      body: Consumer<NotificationProvider>(
        builder: (context, provider, _) {
          if (provider.isLoading) {
            return const Center(
              child: CircularProgressIndicator(color: AppColors.dark),
            );
          }
          if (provider.notifications.isEmpty) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.notifications_off_outlined,
                      size: 64, color: AppColors.outlineVariant),
                  SizedBox(height: 12),
                  Text('No notifications',
                      style: TextStyle(color: AppColors.onSurfaceVariant)),
                ],
              ),
            );
          }
          return RefreshIndicator(
            onRefresh: () => provider.fetchNotifications(),
            color: AppColors.primary,
            child: ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: provider.notifications.length,
              itemBuilder: (context, i) {
                final n = provider.notifications[i];
                final isRead = n['isRead'] == true;
                return Dismissible(
                  key: Key(n['_id']?.toString() ?? '$i'),
                  direction: DismissDirection.endToStart,
                  background: Container(
                    alignment: Alignment.centerRight,
                    padding: const EdgeInsets.only(right: 20),
                    decoration: BoxDecoration(
                      color: AppColors.error,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(Icons.delete, color: Colors.white),
                  ),
                  onDismissed: (_) =>
                      provider.deleteNotification(n['_id']?.toString() ?? ''),
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    decoration: BoxDecoration(
                      color: isRead ? Colors.white : AppColors.infoLight,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AppColors.outline),
                    ),
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 6),
                      leading: Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          color: AppColors.dark.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          _typeIcon(n['type']?.toString() ?? ''),
                          color: AppColors.dark,
                          size: 20,
                        ),
                      ),
                      title: Text(
                        n['title']?.toString() ?? '',
                        style: TextStyle(
                          fontWeight:
                              isRead ? FontWeight.w500 : FontWeight.w700,
                          fontSize: 14,
                        ),
                      ),
                      subtitle:
                          Text(n['message']?.toString() ?? '',
                              style: const TextStyle(fontSize: 12)),
                      trailing: isRead
                          ? null
                          : Container(
                              width: 10,
                              height: 10,
                              decoration: const BoxDecoration(
                                color: AppColors.primary,
                                shape: BoxShape.circle,
                              ),
                            ),
                      onTap: isRead
                          ? null
                          : () => provider
                              .markAsRead(n['_id']?.toString() ?? ''),
                    ),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}