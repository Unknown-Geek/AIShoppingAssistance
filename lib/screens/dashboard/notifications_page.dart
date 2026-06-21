import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../services/notification_storage_service.dart';
import '../../services/chat_agent_service.dart';
import '../../services/payment_notification_service.dart';

class NotificationsPage extends StatefulWidget {
  const NotificationsPage({super.key});

  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage> {
  List<Map<String, dynamic>> notifications = [];
  bool loading = true;
  bool _isSimulating = false;
  GlobalKey<AnimatedListState> _listKey = GlobalKey<AnimatedListState>();

  Future<void> _simulateNotification() async {
    if (_isSimulating) return;
    setState(() => _isSimulating = true);

    try {
      final chatService = ChatAgentService();
      final response = await http.post(
        Uri.parse('${chatService.backendUrl}/chat/test-notification'),
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final success = data['success'] as bool? ?? false;
        final message = data['message'] as String? ?? '';
        final txId = data['transactionId'] as String?;

        await NotificationStorageService.saveNotification(
          success: success,
          message: message,
          transactionId: txId,
        );

        if (mounted) {
          PaymentNotificationService.show(
            context,
            success: success,
            message: message,
            transactionId: txId,
          );
          _loadNotifications();
        }
      }
    } catch (e) {
      debugPrint('[NotificationsPage] Simulation failed: $e');
    } finally {
      if (mounted) {
        setState(() => _isSimulating = false);
      }
    }
  }

  @override
  void initState() {
    super.initState();
    _loadNotifications();
  }

  Future<void> _loadNotifications() async {
    final list = await NotificationStorageService.getNotifications();
    if (mounted) {
      setState(() {
        _listKey = GlobalKey<AnimatedListState>();
        notifications = list;
        loading = false;
      });
      await NotificationStorageService.markAllAsRead();
    }
  }

  Future<void> _clearAllNotifications() async {
    if (notifications.isEmpty) return;

    final backup = List<Map<String, dynamic>>.from(notifications);
    await NotificationStorageService.clearNotifications();

    final theme = Theme.of(context);
    if (mounted) {
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('All notifications cleared'),
          action: SnackBarAction(
            label: 'Undo',
            textColor: theme.colorScheme.inversePrimary,
            onPressed: () async {
              await NotificationStorageService.saveNotificationsList(backup);
              _loadNotifications();
            },
          ),
          behavior: SnackBarBehavior.fixed,
        ),
      );
    }

    final count = notifications.length;
    for (int i = 0; i < count; i++) {
      final item = notifications[0];
      _listKey.currentState?.removeItem(
        0,
        (context, animation) => _buildAnimatedItem(item, animation, 0, isRemoving: true),
        duration: const Duration(milliseconds: 250),
      );
      notifications.removeAt(0);
      await Future.delayed(const Duration(milliseconds: 60));
    }

    if (mounted) {
      setState(() {});
    }
  }

  Widget _buildAnimatedItem(
    Map<String, dynamic> item,
    Animation<double> animation,
    int index, {
    bool isRemoving = false,
  }) {
    final theme = Theme.of(context);
    final timestampStr = item['timestamp'] as String?;

    String timeLabel = '';
    if (timestampStr != null) {
      try {
        final time = DateTime.parse(timestampStr);
        final diff = DateTime.now().difference(time);
        if (diff.inMinutes < 1) {
          timeLabel = 'Just now';
        } else if (diff.inMinutes < 60) {
          timeLabel = '1m ago';
        } else if (diff.inHours < 24) {
          timeLabel = '1h ago';
        } else {
          timeLabel = '1d ago';
        }
      } catch (_) {}
    }

    final card = NotificationCard(
      notification: item,
      timeLabel: timeLabel,
    );

    Widget itemWidget;
    if (isRemoving) {
      itemWidget = card;
    } else {
      itemWidget = Dismissible(
        key: ValueKey(item['timestamp'] ?? index.toString()),
        direction: DismissDirection.endToStart,
        background: Container(
          alignment: Alignment.centerRight,
          padding: const EdgeInsets.only(right: 24),
          margin: const EdgeInsets.only(bottom: 12, left: 16, right: 16),
          decoration: BoxDecoration(
            color: theme.colorScheme.error.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(24),
          ),
          child: Icon(
            Icons.delete_outline_rounded,
            color: theme.colorScheme.error,
          ),
        ),
        onDismissed: (direction) async {
          if (index >= notifications.length) return;
          final removedItem = notifications[index];
          setState(() {
            notifications.removeAt(index);
          });
          _listKey.currentState?.removeItem(
            index,
            (context, animation) => const SizedBox.shrink(),
            duration: Duration.zero,
          );
          await NotificationStorageService.saveNotificationsList(notifications);

          if (mounted) {
            ScaffoldMessenger.of(context).hideCurrentSnackBar();
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: const Text('Notification cleared'),
                action: SnackBarAction(
                  label: 'Undo',
                  textColor: theme.colorScheme.inversePrimary,
                  onPressed: () async {
                    if (index <= notifications.length) {
                      setState(() {
                        notifications.insert(index, removedItem);
                        _listKey.currentState?.insertItem(index);
                      });
                      await NotificationStorageService.saveNotificationsList(notifications);
                    }
                  },
                ),
                behavior: SnackBarBehavior.fixed,
              ),
            );
          }
        },
        child: card,
      );
    }

    return FadeTransition(
      opacity: animation,
      child: SizeTransition(
        sizeFactor: animation,
        axisAlignment: 0.0,
        child: Padding(
          padding: const EdgeInsets.only(top: 0),
          child: itemWidget,
        ),
      ),
    );
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
                    await _clearAllNotifications();
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
                          : AnimatedList(
                              key: _listKey,
                              physics: const BouncingScrollPhysics(),
                              padding: const EdgeInsets.only(top: 12, bottom: 24),
                              initialItemCount: notifications.length,
                              itemBuilder: (context, index, animation) {
                                return _buildAnimatedItem(
                                  notifications[index],
                                  animation,
                                  index,
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
            const SizedBox(height: 24),
            _isSimulating
                ? SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(
                      strokeWidth: 1.5,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        theme.colorScheme.primary.withValues(alpha: 0.4),
                      ),
                    ),
                  )
                : GestureDetector(
                    onTap: _simulateNotification,
                    child: Text(
                      'Simulate Notification',
                      style: TextStyle(
                        fontFamily: theme.textTheme.bodyMedium?.fontFamily,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: theme.colorScheme.primary.withValues(alpha: 0.4),
                        decoration: TextDecoration.underline,
                      ),
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
                    color: const Color(0xFFD2E4E6),
                    width: 1.2,
                  ),
                ),
                child: Center(
                  child: Icon(
                    Icons.delete_sweep_rounded,
                    color: theme.colorScheme.error,
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

    String? amountStr;
    final match = RegExp(r'INR\s*([\d,]+\.\d{2})').firstMatch(message);
    if (match != null) {
      amountStr = '₹${match.group(1)}';
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12, left: 16, right: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFD2E4E6), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: theme.colorScheme.primary.withValues(alpha: 0.04),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Qless Payment',
                      style: TextStyle(
                        fontFamily: theme.textTheme.titleMedium?.fontFamily,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                    const SizedBox(height: 0),
                    if (timeLabel.isNotEmpty)
                      Text(
                        timeLabel,
                        style: TextStyle(
                          fontFamily: theme.textTheme.bodyMedium?.fontFamily,
                          fontSize: 10,
                          fontWeight: FontWeight.normal,
                          letterSpacing: 0.6,
                          color: theme.colorScheme.primary.withValues(alpha: 0.5),
                        ),
                      ),
                  ],
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      success ? 'Success' : 'Failure',
                      style: TextStyle(
                        fontFamily: theme.textTheme.bodyMedium?.fontFamily,
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: success ? const Color(0xFF10B981) : const Color(0xFFEF4444),
                      ),
                    ),
                    const SizedBox(width: 4),
                    Icon(
                      success ? Icons.check_circle_rounded : Icons.cancel_rounded,
                      color: success ? const Color(0xFF10B981) : const Color(0xFFEF4444),
                      size: 16,
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Body text description
            Text(
              message,
              style: TextStyle(
                fontFamily: theme.textTheme.bodyMedium?.fontFamily,
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: theme.colorScheme.primary.withValues(alpha: 0.8),
                height: 1.4,
              ),
            ),

            const SizedBox(height: 12),
            Divider(height: 1, color: Colors.grey.shade200),
            const SizedBox(height: 12),

            // Footer
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () {
                      if (txId != null && txId.isNotEmpty) {
                        Clipboard.setData(ClipboardData(text: txId));
                        ScaffoldMessenger.of(context).hideCurrentSnackBar();
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: const Text('Ref ID copied to clipboard!'),
                            backgroundColor: theme.colorScheme.primary,
                            behavior: SnackBarBehavior.fixed,
                            duration: const Duration(seconds: 2),
                          ),
                        );
                      }
                    },
                    child: Text(
                      txId != null && txId.isNotEmpty ? 'Ref ID: $txId' : 'Ref ID: N/A',
                      style: TextStyle(
                        fontFamily: theme.textTheme.bodyMedium?.fontFamily,
                        fontSize: 10,
                        fontWeight: FontWeight.w400,
                        color: Colors.grey.shade500,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
                if (amountStr != null) ...[
                  const SizedBox(width: 16),
                  Text(
                    amountStr,
                    style: TextStyle(
                      fontFamily: theme.textTheme.titleMedium?.fontFamily,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}
