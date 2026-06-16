import 'package:flutter/material.dart';

class AuthBrandHeader extends StatelessWidget {
  const AuthBrandHeader({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Brand / Logo Section
        Container(
          width: 76,
          height: 76,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: const Color(0xFFD2E4E6),
              width: 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF001A23).withValues(alpha: 0.06),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: const Center(
            child: Icon(
              Icons.shopping_bag_rounded,
              color: Color(0xFF001A23),
              size: 38,
            ),
          ),
        ),
        const SizedBox(height: 16),
        Text(
          'Qless',
          style: theme.textTheme.headlineMedium?.copyWith(
            fontFamily: 'ClashDisplay',
            fontWeight: FontWeight.bold,
            color: const Color(0xFF001A23),
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 6),
        const Text(
          'Your Intelligent Shopping Assistant',
          style: TextStyle(
            fontSize: 14,
            color: Color(0xFF4A5568),
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}
