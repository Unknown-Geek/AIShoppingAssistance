import 'dart:ui';
import 'package:flutter/material.dart';

class FadeContent extends StatefulWidget {
  final Widget child;
  final bool blur;
  final Duration duration;
  final Duration delay;
  final Curve curve;

  const FadeContent({
    super.key,
    required this.child,
    this.blur = true,
    this.duration = const Duration(milliseconds: 1000),
    this.delay = Duration.zero,
    this.curve = Curves.easeOut,
  });

  @override
  State<FadeContent> createState() => _FadeContentState();
}

class _FadeContentState extends State<FadeContent>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: widget.duration);
    _animation = CurvedAnimation(parent: _controller, curve: widget.curve);

    if (widget.delay == Duration.zero) {
      _controller.forward();
    } else {
      Future.delayed(widget.delay, () {
        if (mounted) {
          _controller.forward();
        }
      });
    }
  }

  // didUpdateWidget is removed to ensure the fade/blur animation only plays once on mounting (switching chats or creating a new chat) and not when sending messages.

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, childWidget) {
        final double opacity = _animation.value;
        final double sigma = widget.blur
            ? (1.0 - _animation.value) * 10.0
            : 0.0;

        Widget current = Opacity(opacity: opacity, child: childWidget);

        if (sigma > 0.1) {
          current = ImageFiltered(
            imageFilter: ImageFilter.blur(
              sigmaX: sigma,
              sigmaY: sigma,
              tileMode: TileMode.decal,
            ),
            child: current,
          );
        }

        return current;
      },
      child: widget.child,
    );
  }
}
