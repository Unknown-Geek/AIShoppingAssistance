import 'dart:ui';
import 'package:flutter/material.dart';

class BottomNavBar extends StatefulWidget {
  final VoidCallback onChatTap;
  final VoidCallback onStoreTap;
  final bool isSearchingImage;
  final VoidCallback onShutterTap;

  const BottomNavBar({
    super.key,
    required this.onChatTap,
    required this.onStoreTap,
    required this.isSearchingImage,
    required this.onShutterTap,
  });

  @override
  State<BottomNavBar> createState() => _BottomNavBarState();
}

class _BottomNavBarState extends State<BottomNavBar> {
  double _shutterScale = 1.0;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Stack(
      clipBehavior: Clip.none,
      alignment: Alignment.center,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(40),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
            child: Container(
              height: 82,
              decoration: BoxDecoration(
                color: const Color(0xFFFFFFFF),
                borderRadius: BorderRadius.circular(40),
                border: Border.all(color: const Color(0xFFD2E4E6)),
                boxShadow: [
                  BoxShadow(
                    color: theme.colorScheme.primary.withValues(alpha: 0.06),
                    blurRadius: 24,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: InkWell(
                      onTap: widget.onChatTap,
                      child: const Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.chat_bubble_outline,
                            color: Color(0xFF4A5568),
                            size: 20,
                          ),
                          SizedBox(height: 5),
                          Text(
                            'Chat',
                            style: TextStyle(
                              fontSize: 11,
                              color: Color(0xFF4A5568),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 74),
                  Expanded(
                    child: InkWell(
                      onTap: widget.onStoreTap,
                      child: const Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.storefront_outlined,
                            color: Color(0xFF4A5568),
                            size: 22,
                          ),
                          SizedBox(height: 4),
                          Text(
                            'Store',
                            style: TextStyle(
                              fontSize: 11,
                              color: Color(0xFF4A5568),
                              fontWeight: FontWeight.w500,
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
        ),
        _buildShutterButton(theme),
      ],
    );
  }

  Widget _buildShutterButton(ThemeData theme) {
    return GestureDetector(
      onTapDown: (_) {
        setState(() {
          _shutterScale = 0.92;
        });
      },
      onTapUp: (_) {
        setState(() {
          _shutterScale = 1.0;
        });
        widget.onShutterTap();
      },
      onTapCancel: () {
        setState(() {
          _shutterScale = 1.0;
        });
      },
      child: AnimatedScale(
        scale: _shutterScale,
        duration: const Duration(milliseconds: 100),
        child: Container(
          width: 74,
          height: 74,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: theme.colorScheme.secondary,
            border: Border.all(color: Colors.white, width: 4),
            boxShadow: [
              BoxShadow(
                color: theme.colorScheme.secondary.withValues(alpha: 0.3),
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Center(
            child: widget.isSearchingImage
                ? SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: theme.colorScheme.primary,
                    ),
                  )
                : Icon(
                    Icons.camera_alt_outlined,
                    color: theme.colorScheme.primary,
                    size: 28,
                  ),
          ),
        ),
      ),
    );
  }
}
