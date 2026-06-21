import 'package:flutter/material.dart';
import '../../services/notification_storage_service.dart';

class NotificationsPage extends StatefulWidget {
  const NotificationsPage({super.key});

  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage> {
  List<Map<String, dynamic>> notifications = [];
  bool loading = true;

  @override
  void initState() {
    super.initState();
    _loadNotifications();
  }

  Future<void> _loadNotifications() async {
    final list = await NotificationStorageService.getNotifications();
    if (mounted) {
      setState(() {
        notifications = list;
        loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'Notifications',
          style: TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.bold,
            fontFamily: 'ClashDisplay',
          ),
        ),
        iconTheme: const IconThemeData(color: Colors.black),
        actions: [
          if (notifications.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(right: 8.0),
              child: TextButton.icon(
                onPressed: () async {
                  await NotificationStorageService.clearNotifications();
                  if (mounted) {
                    setState(() {
                      notifications.clear();
                    });
                  }
                },
                icon: const Icon(Icons.clear_all_rounded, size: 18, color: Colors.red),
                label: const Text(
                  'Clear All',
                  style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
                ),
              ),
            ),
        ],
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : notifications.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.notifications_off_outlined,
                        size: 48,
                        color: theme.colorScheme.primary.withValues(alpha: 0.2),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'No notifications yet',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: theme.colorScheme.primary.withValues(alpha: 0.5),
                        ),
                      ),
                    ],
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  itemCount: notifications.length,
                  separatorBuilder: (_, __) => const Divider(height: 1, color: Color(0xFFE2E8F0)),
                  itemBuilder: (context, index) {
                    final item = notifications[index];
                    final success = item['success'] as bool? ?? false;
                    final message = item['message'] as String? ?? '';
                    final txId = item['transactionId'] as String?;
                    final timestampStr = item['timestamp'] as String?;
                    
                    String timeLabel = '';
                    if (timestampStr != null) {
                      try {
                        final time = DateTime.parse(timestampStr);
                        final diff = DateTime.now().difference(time);
                        if (diff.inMinutes < 1) {
                          timeLabel = 'Just now';
                        } else if (diff.inMinutes < 60) {
                          timeLabel = '${diff.inMinutes}m ago';
                        } else if (diff.inHours < 24) {
                          timeLabel = '${diff.inHours}h ago';
                        } else {
                          timeLabel = '${diff.inDays}d ago';
                        }
                      } catch (_) {}
                    }

                    final Color iconColor = success
                        ? theme.colorScheme.secondary
                        : const Color(0xFFEF4444);

                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12.0),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          CircleAvatar(
                            radius: 18,
                            backgroundColor: iconColor.withValues(alpha: 0.1),
                            child: Icon(
                              success
                                  ? Icons.check_circle_outline_rounded
                                  : Icons.error_outline_rounded,
                              color: iconColor,
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      success ? 'Payment Success' : 'Payment Failed',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14,
                                        color: theme.colorScheme.primary,
                                      ),
                                    ),
                                    if (timeLabel.isNotEmpty)
                                      Text(
                                        timeLabel,
                                        style: const TextStyle(
                                          fontSize: 11,
                                          color: Colors.grey,
                                        ),
                                      ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  message,
                                  style: const TextStyle(
                                    fontSize: 13,
                                    color: Color(0xFF4A5568),
                                    height: 1.3,
                                  ),
                                ),
                                if (txId != null && txId.isNotEmpty) ...[
                                  const SizedBox(height: 4),
                                  Text(
                                    'Ref ID: $txId',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      color: theme.colorScheme.primary.withValues(alpha: 0.4),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
    );
  }
}
