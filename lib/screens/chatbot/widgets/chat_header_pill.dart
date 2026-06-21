import 'package:flutter/material.dart';

class ChatHeaderPill extends StatelessWidget {
  final VoidCallback onBackTap;
  final VoidCallback onHistoryTap;

  const ChatHeaderPill({
    super.key,
    required this.onBackTap,
    required this.onHistoryTap,
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
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Left action: Back
          Align(
            alignment: Alignment.centerLeft,
            child: GestureDetector(
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
          ),
          // Center Title
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 56),
            child: Text(
              'Qless Assistant',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontFamily: theme.textTheme.titleLarge?.fontFamily,
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: theme.colorScheme.primary,
              ),
            ),
          ),
          // Right action: History
          Align(
            alignment: Alignment.centerRight,
            child: GestureDetector(
              onTap: onHistoryTap,
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
                    Icons.history_rounded,
                    color: theme.colorScheme.primary,
                    size: 20,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
