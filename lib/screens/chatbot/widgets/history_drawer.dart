import 'package:flutter/material.dart';
import 'dart:ui';
import '../../../models/chatbot_models.dart';

class HistoryDrawer extends StatefulWidget {
  final List<ChatSession> chatHistory;
  final String? activeSessionId;
  final VoidCallback onStartNewChat;
  final ValueChanged<ChatSession> onOpenChatSession;
  final ValueChanged<ChatSession> onDeleteChatSession;
  final Function(ChatSession, String) onRenameChatSession;

  const HistoryDrawer({
    super.key,
    required this.chatHistory,
    required this.activeSessionId,
    required this.onStartNewChat,
    required this.onOpenChatSession,
    required this.onDeleteChatSession,
    required this.onRenameChatSession,
  });

  @override
  State<HistoryDrawer> createState() => _HistoryDrawerState();
}

class _HistoryDrawerState extends State<HistoryDrawer> {
  bool _isNewChatHovered = false;

  String _getTimelineGroup(DateTime lastActive) {
    final now = DateTime.now();
    final difference = now.difference(lastActive);

    if (difference.inMinutes < 60 && difference.inMinutes >= 0) {
      return 'Last Hour';
    }

    final todayMidnight = DateTime(now.year, now.month, now.day);
    final yesterdayMidnight = todayMidnight.subtract(const Duration(days: 1));
    final sevenDaysAgo = todayMidnight.subtract(const Duration(days: 7));

    if (lastActive.isAfter(todayMidnight)) {
      return 'Today';
    } else if (lastActive.isAfter(yesterdayMidnight)) {
      return 'Yesterday';
    } else if (lastActive.isAfter(sevenDaysAgo)) {
      return 'This Week';
    } else {
      return 'Long Time Ago';
    }
  }

  Future<T?> _showBlurredDialog<T>({
    required BuildContext context,
    required WidgetBuilder builder,
    bool barrierDismissible = true,
  }) {
    return showGeneralDialog<T>(
      context: context,
      barrierDismissible: barrierDismissible,
      barrierLabel: 'Dismiss Dialog',
      barrierColor: Colors.black.withValues(alpha: 0.25),
      transitionDuration: const Duration(milliseconds: 350),
      pageBuilder: (ctx, anim1, anim2) => builder(ctx),
      transitionBuilder: (ctx, anim1, anim2, child) {
        final curve = CurvedAnimation(
          parent: anim1,
          curve: Curves.easeOutCubic,
        );
        return AnimatedBuilder(
          animation: curve,
          builder: (context, childWidget) {
            final sigma = curve.value * 6.0;
            return BackdropFilter(
              filter: ImageFilter.blur(sigmaX: sigma, sigmaY: sigma),
              child: FadeTransition(
                opacity: curve,
                child: ScaleTransition(
                  scale: Tween<double>(begin: 0.92, end: 1.0).animate(curve),
                  child: childWidget,
                ),
              ),
            );
          },
          child: child,
        );
      },
    );
  }

  void _showRenameDialog(BuildContext context, ChatSession session) {
    final theme = Theme.of(context);
    final controller = TextEditingController(text: session.title);

    _showBlurredDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          backgroundColor: Colors.white,
          title: Text(
            'Rename Chat',
            style: TextStyle(
              fontFamily: theme.textTheme.titleLarge?.fontFamily,
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: theme.colorScheme.primary,
            ),
          ),
          content: TextField(
            controller: controller,
            autofocus: true,
            style: TextStyle(
              fontFamily: theme.textTheme.bodyMedium?.fontFamily,
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: theme.colorScheme.primary,
            ),
            decoration: InputDecoration(
              hintText: 'Enter new title...',
              hintStyle: TextStyle(
                fontFamily: theme.textTheme.bodyMedium?.fontFamily,
                fontSize: 15,
                color: theme.colorScheme.onSurfaceVariant.withValues(
                  alpha: 0.5,
                ),
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 14,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(
                  color: Color(0xFFD2E4E6),
                  width: 1.2,
                ),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(
                  color: Color(0xFFD2E4E6),
                  width: 1.2,
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(
                  color: theme.colorScheme.primary,
                  width: 1.5,
                ),
              ),
            ),
          ),
          actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                'Cancel',
                style: TextStyle(
                  fontFamily: theme.textTheme.bodyMedium?.fontFamily,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: theme.colorScheme.primary.withValues(alpha: 0.7),
                ),
              ),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: theme.colorScheme.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
              ),
              onPressed: () {
                final newTitle = controller.text.trim();
                if (newTitle.isNotEmpty) {
                  widget.onRenameChatSession(session, newTitle);
                }
                Navigator.pop(context);
              },
              child: const Text(
                'Rename',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        );
      },
    );
  }

  void _showDeleteDialog(BuildContext context, ChatSession session) {
    final theme = Theme.of(context);
    _showBlurredDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          backgroundColor: Colors.white,
          title: Text(
            'Delete Chat',
            style: TextStyle(
              fontFamily: theme.textTheme.titleLarge?.fontFamily,
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: theme.colorScheme.primary,
            ),
          ),
          content: Text(
            'Are you sure you want to delete this chat session? This action cannot be undone.',
            style: TextStyle(
              fontFamily: theme.textTheme.bodyMedium?.fontFamily,
              fontSize: 15,
              fontWeight: FontWeight.w500,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                'Cancel',
                style: TextStyle(
                  fontFamily: theme.textTheme.bodyMedium?.fontFamily,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: theme.colorScheme.primary.withValues(alpha: 0.7),
                ),
              ),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFEF4444),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
              ),
              onPressed: () {
                widget.onDeleteChatSession(session);
                Navigator.pop(context);
              },
              child: const Text(
                'Delete',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // Grouping logic
    final categories = [
      'Last Hour',
      'Today',
      'Yesterday',
      'This Week',
      'Long Time Ago',
    ];
    final Map<String, List<ChatSession>> grouped = {};
    for (final session in widget.chatHistory) {
      final grp = _getTimelineGroup(session.lastActive);
      grouped.putIfAbsent(grp, () => []).add(session);
    }

    final List<dynamic> listItems = [];
    for (final category in categories) {
      if (grouped.containsKey(category) && grouped[category]!.isNotEmpty) {
        listItems.add(category);
        listItems.addAll(grouped[category]!);
      }
    }

    return Drawer(
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.only(
          topRight: Radius.circular(32),
          bottomRight: Radius.circular(32),
        ),
      ),
      backgroundColor: Colors.white,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Styled header
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 24, 16, 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Chat History',
                    style: TextStyle(
                      fontFamily: theme.textTheme.titleLarge?.fontFamily,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                  IconButton(
                    icon: Icon(
                      Icons.close_rounded,
                      color: theme.colorScheme.primary,
                    ),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),

            // Premium "New Chat" Pill Button
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
              child: InkWell(
                onTap: widget.onStartNewChat,
                borderRadius: BorderRadius.circular(24),
                onHover: (hovered) {
                  setState(() {
                    _isNewChatHovered = hovered;
                  });
                },
                child: Container(
                  height: 48,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: theme.colorScheme.primary.withValues(
                          alpha: 0.15,
                        ),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        curve: Curves.easeOutCubic,
                        padding: EdgeInsets.only(
                          right: _isNewChatHovered ? 12.0 : 8.0,
                        ),
                        child: Icon(
                          Icons.add_rounded,
                          color: theme
                              .colorScheme
                              .onPrimary, // White (the "New Chat" text color itself)
                          size: 20,
                        ),
                      ),
                      Text(
                        'New Chat',
                        style: TextStyle(
                          fontFamily: theme.textTheme.bodyMedium?.fontFamily,
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: theme.colorScheme.onPrimary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Scrollable list
            Expanded(
              child: widget.chatHistory.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.chat_bubble_outline_rounded,
                            size: 48,
                            color: theme.colorScheme.primary.withValues(
                              alpha: 0.25,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'No saved chats yet.',
                            style: TextStyle(
                              fontFamily:
                                  theme.textTheme.bodyMedium?.fontFamily,
                              fontSize: 15,
                              fontWeight: FontWeight.w500,
                              color: theme.colorScheme.primary.withValues(
                                alpha: 0.5,
                              ),
                            ),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.only(bottom: 24),
                      itemCount: listItems.length,
                      itemBuilder: (context, index) {
                        final item = listItems[index];

                        if (item is String) {
                          // Render timeline header
                          return Padding(
                            padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
                            child: Text(
                              item.toUpperCase(),
                              style: TextStyle(
                                fontFamily:
                                    theme.textTheme.bodyMedium?.fontFamily,
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                                color: theme.colorScheme.primary.withValues(
                                  alpha: 0.45,
                                ),
                                letterSpacing: 1.1,
                              ),
                            ),
                          );
                        }

                        // Render chat session tile
                        final session = item as ChatSession;
                        final isActive = session.id == widget.activeSessionId;

                        return Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 4,
                          ),
                          child: InkWell(
                            onTap: () => widget.onOpenChatSession(session),
                            borderRadius: BorderRadius.circular(16),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              padding: const EdgeInsets.fromLTRB(14, 12, 4, 12),
                              decoration: BoxDecoration(
                                color: isActive
                                    ? theme.colorScheme.secondary.withValues(
                                        alpha: 0.12,
                                      )
                                    : Colors.white,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: isActive
                                      ? theme.colorScheme.secondary.withValues(
                                          alpha: 0.5,
                                        )
                                      : const Color(
                                          0xFFD2E4E6,
                                        ).withValues(alpha: 0.3),
                                  width: 1.2,
                                ),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.chat_bubble_outline_rounded,
                                    size: 18,
                                    color: isActive
                                        ? theme.colorScheme.primary
                                        : theme.colorScheme.primary.withValues(
                                            alpha: 0.55,
                                          ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      session.title,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontFamily: theme
                                            .textTheme
                                            .bodyMedium
                                            ?.fontFamily,
                                        fontSize: 14,
                                        fontWeight: isActive
                                            ? FontWeight.w600
                                            : FontWeight.w500,
                                        color: theme.colorScheme.primary,
                                      ),
                                    ),
                                  ),
                                  PopupMenuButton<String>(
                                    icon: Icon(
                                      Icons.more_vert_rounded,
                                      size: 18,
                                      color: theme.colorScheme.primary
                                          .withValues(alpha: 0.45),
                                    ),
                                    padding: EdgeInsets.zero,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                    color: Colors.white,
                                    elevation: 8,
                                    onSelected: (value) {
                                      if (value == 'rename') {
                                        _showRenameDialog(context, session);
                                      } else if (value == 'delete') {
                                        _showDeleteDialog(context, session);
                                      }
                                    },
                                    itemBuilder: (BuildContext context) => [
                                      PopupMenuItem<String>(
                                        value: 'rename',
                                        child: Row(
                                          children: [
                                            Icon(
                                              Icons.edit_outlined,
                                              size: 16,
                                              color: theme.colorScheme.primary,
                                            ),
                                            const SizedBox(width: 8),
                                            Text(
                                              'Rename',
                                              style: TextStyle(
                                                fontFamily: theme
                                                    .textTheme
                                                    .bodyMedium
                                                    ?.fontFamily,
                                                fontSize: 14,
                                                fontWeight: FontWeight.w500,
                                                color:
                                                    theme.colorScheme.primary,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      const PopupMenuItem<String>(
                                        value: 'delete',
                                        child: Row(
                                          children: [
                                            Icon(
                                              Icons.delete_outline_rounded,
                                              size: 16,
                                              color: Color(0xFFEF4444),
                                            ),
                                            SizedBox(width: 8),
                                            Text(
                                              'Delete',
                                              style: TextStyle(
                                                fontSize: 14,
                                                fontWeight: FontWeight.w500,
                                                color: Color(0xFFEF4444),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
