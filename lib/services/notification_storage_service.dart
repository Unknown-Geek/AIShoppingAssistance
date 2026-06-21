import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class NotificationStorageService {
  static const String _storageKey = 'payment_notifications_history';

  static Future<void> saveNotification({
    required bool success,
    required String message,
    String? transactionId,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final List<String> list = prefs.getStringList(_storageKey) ?? [];
      
      final Map<String, dynamic> newNotification = {
        'success': success,
        'message': message,
        'transactionId': transactionId,
        'timestamp': DateTime.now().toIso8601String(),
      };
      
      list.insert(0, jsonEncode(newNotification));
      await prefs.setStringList(_storageKey, list);
    } catch (e) {
      // silent fallback
    }
  }

  static Future<List<Map<String, dynamic>>> getNotifications() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final List<String> list = prefs.getStringList(_storageKey) ?? [];
      return list.map((item) => jsonDecode(item) as Map<String, dynamic>).toList();
    } catch (e) {
      return [];
    }
  }

  static Future<void> clearNotifications() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_storageKey);
    } catch (e) {
      // silent fallback
    }
  }
}
