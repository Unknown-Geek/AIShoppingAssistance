import 'dart:convert';
import 'package:flutter/material.dart';

enum DbConnectionStatus { unknown, live, error }

class DashboardAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String userInitial;
  final String? profilePicBase64;
  final DbConnectionStatus dbStatus;
  final VoidCallback onProfileTap;
  final VoidCallback onDbStatusTap;
  final VoidCallback onNotificationsTap;
  final bool hasNotifications;

  const DashboardAppBar({
    super.key,
    required this.userInitial,
    this.profilePicBase64,
    required this.dbStatus,
    required this.onProfileTap,
    required this.onDbStatusTap,
    required this.onNotificationsTap,
    required this.hasNotifications,
  });

  @override
  Size get preferredSize => const Size.fromHeight(72);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return PreferredSize(
      preferredSize: preferredSize,
      child: SafeArea(
        child: Container(
          height: 72,
          margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: const Color(0xFFFFFFFF),
            borderRadius: BorderRadius.circular(32),
            boxShadow: [
              BoxShadow(
                color: theme.colorScheme.primary.withValues(alpha: 0.04),
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
            ],
            border: Border.all(color: const Color(0xFFD2E4E6)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              GestureDetector(
                onTap: onProfileTap,
                child: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: const Color(0xFFFFFFFF),
                    border: Border.all(color: const Color(0xFFD2E4E6)),
                    image: profilePicBase64 != null
                        ? DecorationImage(
                            image:
                                (profilePicBase64!.startsWith('http')
                                        ? NetworkImage(profilePicBase64!)
                                        : MemoryImage(
                                            base64Decode(profilePicBase64!),
                                          ))
                                    as ImageProvider,
                            fit: BoxFit.cover,
                          )
                        : null,
                  ),
                  child: profilePicBase64 == null
                      ? Center(
                          child: Text(
                            userInitial,
                            style: TextStyle(
                              fontFamily:
                                  theme.textTheme.titleLarge?.fontFamily,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: theme.colorScheme.primary,
                            ),
                          ),
                        )
                      : null,
                ),
              ),
              GestureDetector(
                onTap: onDbStatusTap,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Status',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Container(
                        width: 1,
                        height: 12,
                        color: theme.colorScheme.primary.withValues(
                          alpha: 0.12,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        switch (dbStatus) {
                          DbConnectionStatus.live => 'Live',
                          DbConnectionStatus.error => 'Error',
                          DbConnectionStatus.unknown => 'Checking…',
                        },
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: switch (dbStatus) {
                            DbConnectionStatus.live =>
                              theme.colorScheme.secondary,
                            DbConnectionStatus.error => theme.colorScheme.error,
                            DbConnectionStatus.unknown =>
                              theme.colorScheme.onSurfaceVariant,
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              GestureDetector(
                onTap: onNotificationsTap,
                child: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: const Color(0xFFFFFFFF),
                    border: Border.all(color: const Color(0xFFD2E4E6)),
                  ),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Icon(
                        Icons.notifications_none_outlined,
                        color: theme.colorScheme.primary,
                        size: 22,
                      ),
                      if (hasNotifications)
                        Positioned(
                          top: 12,
                          right: 12,
                          child: Container(
                            width: 7,
                            height: 7,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: theme.colorScheme.secondary,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
