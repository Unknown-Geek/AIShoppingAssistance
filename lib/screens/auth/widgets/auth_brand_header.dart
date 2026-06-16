import 'package:flutter/material.dart';
import '../../../config/config.dart';

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
                color: theme.colorScheme.primary.withValues(alpha: 0.06),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Center(
            child: BrandConfig.active.identity.logoAssetPath != null
                ? Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: Image.asset(
                      BrandConfig.active.identity.logoAssetPath!,
                      fit: BoxFit.contain,
                    ),
                  )
                : Icon(
                    Icons.shopping_bag_rounded,
                    color: theme.colorScheme.primary,
                    size: 38,
                  ),
          ),
        ),
        const SizedBox(height: 16),
        Text(
          BrandConfig.active.identity.appName,
          style: theme.textTheme.headlineMedium?.copyWith(
            fontFamily: 'ClashDisplay',
            fontWeight: FontWeight.bold,
            color: theme.colorScheme.primary,
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          BrandConfig.active.identity.tagline ?? 'Your Intelligent Shopping Assistant',
          style: const TextStyle(
            fontSize: 14,
            color: Color(0xFF4A5568),
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}
