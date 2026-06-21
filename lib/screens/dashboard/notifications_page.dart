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
      backgroundColor: theme.scaffoldBackgroundColor,
      body: Stack(
        children: [
          // Background soft visual decoration (radial gradients) matching profile/orders
          Positioned(
            top: -120,
            right: -120,
            child: Container(
              width: 320,
              height: 320,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    theme.colorScheme.primary.withValues(alpha: 0.08),
                    theme.colorScheme.primary.withValues(alpha: 0.0),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            bottom: 100,
            left: -60,
            child: Container(
              width: 280,
              height: 280,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    theme.colorScheme.secondary.withValues(alpha: 0.12),
                    theme.colorScheme.secondary.withValues(alpha: 0.0),
                  ],
                ),
              ),
            ),
          ),
          // Main Body
          SafeArea(
            child: Column(
              children: [
                // Custom Floating Header Pill
                NotificationsHeaderPill(
                  onBackTap: () {
                    Navigator.of(context).pop();
                  },
                  showClearAll: notifications.isNotEmpty,
                  onClearAllTap: () async {
                    await NotificationStorageService.clearNotifications();
                    if (mounted) {
                      setState(() {
                        notifications.clear();
                      });
                    }
                  },
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: loading
                      ? const Center(child: CircularProgressIndicator())
                      : notifications.isEmpty
                          ? SingleChildScrollView(
                              physics: const BouncingScrollPhysics(),
                              child: _buildEmptyState(theme),
                            )
                          : ListView.builder(
                              physics: const BouncingScrollPhysics(),
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              itemCount: notifications.length,
                              itemBuilder: (context, index) {
                                final item = notifications[index];
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

                                return NotificationCard(
                                  notification: item,
                                  timeLabel: timeLabel,
                                );
                              },
                            ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 120),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.notifications_off_rounded,
              size: 64,
              color: theme.colorScheme.primary.withValues(alpha: 0.2),
            ),
            const SizedBox(height: 16),
            Text(
              'No notifications found',
              style: TextStyle(
                fontFamily: 'ClashGrotesk',
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: theme.colorScheme.primary.withValues(alpha: 0.5),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class NotificationsHeaderPill extends StatelessWidget {
  final VoidCallback onBackTap;
  final VoidCallback? onClearAllTap;
  final bool showClearAll;

  const NotificationsHeaderPill({
    super.key,
    required this.onBackTap,
    this.onClearAllTap,
    required this.showClearAll,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      height: 64,
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(32),
        border: Border.all(color: const Color(0xFFD2E4E6), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: theme.colorScheme.primary.withValues(alpha: 0.04),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Left: Back button
          GestureDetector(
            onTap: onBackTap,
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white,
                border: Border.all(
                  color: const Color(0xFFD2E4E6),
                  width: 1.2,
                ),
              ),
              child: Center(
                child: Icon(
                  Icons.arrow_back_rounded,
                  color: theme.colorScheme.primary,
                  size: 20,
                ),
              ),
            ),
          ),
          // Center: Title
          Text(
            'Notifications',
            style: TextStyle(
              fontFamily: theme.textTheme.titleLarge?.fontFamily,
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: theme.colorScheme.primary,
            ),
          ),
          // Right: Clear All button (or placeholder to balance the back button)
          if (showClearAll)
            GestureDetector(
              onTap: onClearAllTap,
              child: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white,
                  border: Border.all(
                    color: Colors.red.withValues(alpha: 0.2),
                    width: 1.2,
                  ),
                ),
                child: const Center(
                  child: Icon(
                    Icons.delete_sweep_rounded,
                    color: Colors.red,
                    size: 20,
                  ),
                ),
              ),
            )
          else
            const SizedBox(width: 44),
        ],
      ),
    );
  }
}

class NotificationCard extends StatelessWidget {
  final Map<String, dynamic> notification;
  final String timeLabel;

  const NotificationCard({
    super.key,
    required this.notification,
    required this.timeLabel,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final success = notification['success'] as bool? ?? false;
    final message = notification['message'] as String? ?? '';
    final txId = notification['transactionId'] as String?;

    final Color iconColor = success
        ? theme.colorScheme.secondary
        : const Color(0xFFEF4444);

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 16),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFD2E4E6), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: theme.colorScheme.primary.withValues(alpha: 0.03),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Icon Avatar
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Center(
              child: Icon(
                success
                    ? Icons.check_circle_outline_rounded
                    : Icons.error_outline_rounded,
                color: success ? theme.colorScheme.primary : iconColor,
                size: 22,
              ),
            ),
          ),
          const SizedBox(width: 14),
          // Text Content
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        success ? 'Payment Success' : 'Payment Failed',
                        style: TextStyle(
                          fontFamily: theme.textTheme.titleLarge?.fontFamily,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                    ),
                    if (timeLabel.isNotEmpty)
                      Text(
                        timeLabel,
                        style: TextStyle(
                          fontFamily: theme.textTheme.bodyMedium?.fontFamily,
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          color: theme.colorScheme.primary.withValues(alpha: 0.4),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  message,
                  style: TextStyle(
                    fontFamily: theme.textTheme.bodyMedium?.fontFamily,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: theme.colorScheme.primary.withValues(alpha: 0.7),
                    height: 1.4,
                  ),
                ),
                if (txId != null && txId.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary.withValues(alpha: 0.04),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: theme.colorScheme.primary.withValues(alpha: 0.08),
                        width: 0.8,
                      ),
                    ),
                    child: Text(
                      'Ref ID: $txId',
                      style: TextStyle(
                        fontFamily: 'ClashGrotesk',
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.primary.withValues(alpha: 0.5),
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
