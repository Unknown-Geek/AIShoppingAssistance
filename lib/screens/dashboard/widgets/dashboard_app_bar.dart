import 'package:flutter/material.dart';

enum DbConnectionStatus { unknown, live, error }

class DashboardAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String userInitial;
  final DbConnectionStatus dbStatus;
  final VoidCallback onProfileTap;
  final VoidCallback onDbStatusTap;

  const DashboardAppBar({
    super.key,
    required this.userInitial,
    required this.dbStatus,
    required this.onProfileTap,
    required this.onDbStatusTap,
  });

  @override
  Size get preferredSize => const Size.fromHeight(72);

  @override
  Widget build(BuildContext context) {
    return PreferredSize(
      preferredSize: preferredSize,
      child: SafeArea(
        child: Container(
          height: 72,
          margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: const Color(0xFFFFFFFF),
            borderRadius: BorderRadius.circular(32),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF001A23).withValues(alpha: 0.04),
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
                  ),
                  child: Center(
                    child: Text(
                      userInitial,
                      style: const TextStyle(
                        fontFamily: 'ClashDisplay',
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF001A23),
                      ),
                    ),
                  ),
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
                      const Text(
                        'DB Status',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF001A23),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Container(
                        width: 1,
                        height: 12,
                        color: const Color(0xFF001A23).withValues(alpha: 0.12),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        switch (dbStatus) {
                          DbConnectionStatus.live => 'Live',
                          DbConnectionStatus.error => 'Error',
                          DbConnectionStatus.unknown => 'Checking…',
                        },
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: switch (dbStatus) {
                            DbConnectionStatus.live => const Color(0xFFB3EFB2),
                            DbConnectionStatus.error => const Color(0xFFEF4444),
                            DbConnectionStatus.unknown => const Color(0xFF4A5568),
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Container(
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
                    const Icon(
                      Icons.notifications_none_outlined,
                      color: Color(0xFF001A23),
                      size: 22,
                    ),
                    Positioned(
                      top: 12,
                      right: 12,
                      child: Container(
                        width: 7,
                        height: 7,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: Color(0xFFB3EFB2),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
