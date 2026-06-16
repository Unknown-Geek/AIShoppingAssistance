import 'package:flutter/material.dart';

class ScanningOverlay extends StatefulWidget {
  const ScanningOverlay({super.key});

  @override
  State<ScanningOverlay> createState() => _ScanningOverlayState();
}

class _ScanningOverlayState extends State<ScanningOverlay>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 180.0,
      height: 180.0,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          final value = _controller.value;
          return ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Stack(
              children: [
                // Subtle background green tint
                Container(
                  color: const Color(0xFFB3EFB2).withValues(alpha: 0.04),
                ),
                // Translucent green gradient trail/glow behind the sweeping laser line
                Positioned(
                  top: (value * 180.0) - 60.0,
                  left: 0,
                  right: 0,
                  height: 60.0,
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          const Color(0xFFB3EFB2).withValues(alpha: 0.18),
                        ],
                      ),
                    ),
                  ),
                ),
                // Sweeping laser line
                Positioned(
                  top: value * 180.0,
                  left: 0,
                  right: 0,
                  child: Container(
                    height: 2.5,
                    decoration: BoxDecoration(
                      color: const Color(0xFFB3EFB2),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFFB3EFB2).withValues(alpha: 0.8),
                          blurRadius: 8,
                          spreadRadius: 1.5,
                        ),
                      ],
                    ),
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
