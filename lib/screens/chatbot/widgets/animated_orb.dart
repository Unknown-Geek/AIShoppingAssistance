import 'dart:math' as math;
import 'package:flutter/material.dart';

class AnimatedOrb extends StatefulWidget {
  final double size;

  const AnimatedOrb({super.key, required this.size});

  @override
  State<AnimatedOrb> createState() => _AnimatedOrbState();
}

class _AnimatedOrbState extends State<AnimatedOrb>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    // Rotation is slower (15 seconds) for a modern, high-end SaaS feel
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 15),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return CustomPaint(
          size: Size(widget.size, widget.size),
          painter: _OrbPainter(_controller.value),
        );
      },
    );
  }
}

class _OrbPainter extends CustomPainter {
  final double progress;

  _OrbPainter(this.progress);

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    // Use saveLayer to apply composite blending
    canvas.saveLayer(Rect.fromLTWH(0, 0, size.width, size.height), Paint());

    final angle = progress * 2 * math.pi;

    // 1. Primary Base: Deep Qless Navy
    // Modulating with secondary harmonics for fluid/liquid motion
    final x1 = math.sin(angle) * 0.10 + math.cos(angle * 2.3) * 0.05;
    final y1 = math.cos(angle) * 0.10 + math.sin(angle * 1.7) * 0.05;
    final offset1 = Offset(center.dx + x1 * radius, center.dy + y1 * radius);
    final rad1 = radius * (0.88 + math.sin(angle * 2.5) * 0.10);

    final paint1 = Paint()
      ..shader = RadialGradient(
        colors: [
          const Color(0xFF001A23),
          const Color(0xFF001A23).withValues(alpha: 0.85),
          const Color(0xFF001A23).withValues(alpha: 0.0),
        ],
        stops: const [0.0, 0.55, 1.0],
      ).createShader(Rect.fromCircle(center: offset1, radius: rad1));
    canvas.drawCircle(offset1, rad1, paint1);

    // 2. SaaS Vibrant Purple (blending and breathing)
    final x2 = math.cos(angle + math.pi / 2) * 0.18 + math.sin(angle * 2.9) * 0.07;
    final y2 = math.sin(angle + math.pi / 2) * 0.18 + math.cos(angle * 2.1) * 0.07;
    final offset2 = Offset(center.dx + x2 * radius, center.dy + y2 * radius);
    final rad2 = radius * (0.78 + math.cos(angle * 3.6) * 0.15);

    final paint2 = Paint()
      ..blendMode = BlendMode.screen
      ..shader = RadialGradient(
        colors: [
          const Color(0xFF7C3AED), // Vibrant purple
          const Color(0xFF7C3AED).withValues(alpha: 0.55),
          const Color(0xFF7C3AED).withValues(alpha: 0.0),
        ],
        stops: const [0.0, 0.45, 1.0],
      ).createShader(Rect.fromCircle(center: offset2, radius: rad2));
    canvas.drawCircle(offset2, rad2, paint2);

    // 3. Secondary Mint Green Accent (wobbly overlay)
    final x3 = math.sin(angle + math.pi) * 0.20 + math.cos(angle * 3.4) * 0.08;
    final y3 = math.cos(angle + math.pi) * 0.20 + math.sin(angle * 2.6) * 0.08;
    final offset3 = Offset(center.dx + x3 * radius, center.dy + y3 * radius);
    final rad3 = radius * (0.68 + math.sin(angle * 4.8) * 0.18);

    final paint3 = Paint()
      ..blendMode = BlendMode.screen
      ..shader = RadialGradient(
        colors: [
          const Color(0xFFB3EFB2), // Mint Green
          const Color(0xFFB3EFB2).withValues(alpha: 0.75),
          const Color(0xFFB3EFB2).withValues(alpha: 0.0),
        ],
        stops: const [0.0, 0.35, 1.0],
      ).createShader(Rect.fromCircle(center: offset3, radius: rad3));
    canvas.drawCircle(offset3, rad3, paint3);

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _OrbPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}
