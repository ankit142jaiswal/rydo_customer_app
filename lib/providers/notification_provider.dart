import 'package:flutter/foundation.dart';
import '../services/api_service.dart';

/// Reactive provider for customer notifications.
///
/// Mirrors captain's NotificationService. Exposes [unreadCount] so the
/// AppBar badge can rebuild whenever it changes without fetching the full
/// list again.
class NotificationProvider extends ChangeNotifier {
  List<dynamic> _notifications = [];
  int _unreadCount = 0;
  bool _isLoading = false;
  Map<String, bool> _settings = {
    'rideUpdates': true,
    'promotions': true,
    'systemUpdates': true,
    'security': true,
  };

  List<dynamic> get notifications => _notifications;
  int get unreadCount => _unreadCount;
  bool get isLoading => _isLoading;
  Map<String, bool> get settings => _settings;

  Future<void> fetchNotifications() async {
    _isLoading = true;
    notifyListeners();
    try {
      final result = await ApiService.getNotifications();
      if (result['success'] == true) {
        _notifications = result['notifications'] ?? [];
        _unreadCount = result['unreadCount'] ??
            (_notifications.where((n) => n['isRead'] != true).length);
      }
    } catch (e) {
      debugPrint('NotificationProvider.fetchNotifications error: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> markAsRead(String id) async {
    try {
      await ApiService.markNotificationRead(id);
      await fetchNotifications();
    } catch (e) {
      debugPrint('NotificationProvider.markAsRead error: $e');
    }
  }

  Future<void> markAllRead() async {
    try {
      await ApiService.markAllNotificationsRead();
      await fetchNotifications();
    } catch (e) {
      debugPrint('NotificationProvider.markAllRead error: $e');
    }
  }

  Future<void> deleteNotification(String id) async {
    try {
      await ApiService.deleteNotification(id);
      await fetchNotifications();
    } catch (e) {
      debugPrint('NotificationProvider.deleteNotification error: $e');
    }
  }

  Future<void> getSettings() async {
    try {
      final result = await ApiService.getNotificationSettings();
      if (result['success'] == true && result['settings'] != null) {
        final s = result['settings'];
        _settings = {
          'rideUpdates': s['rideUpdates'] ?? true,
          'promotions': s['promotions'] ?? true,
          'systemUpdates': s['systemUpdates'] ?? true,
          'security': s['security'] ?? true,
        };
        notifyListeners();
      }
    } catch (e) {
      debugPrint('NotificationProvider.getSettings error: $e');
    }
  }

  Future<bool> updateSettings(Map<String, bool> newSettings) async {
    try {
      final result = await ApiService.updateNotificationSettings(newSettings);
      if (result['success'] == true) {
        _settings = {..._settings, ...newSettings};
        notifyListeners();
        return true;
      }
      return false;
    } catch (e) {
      debugPrint('NotificationProvider.updateSettings error: $e');
      return false;
    }
  }

  /// Increment locally when a push notification arrives (via socket).
  void incrementUnread() {
    _unreadCount++;
    notifyListeners();
  }
}
