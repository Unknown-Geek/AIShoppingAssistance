import 'dart:async';
import 'package:flutter/material.dart';

class AnimatedContent extends StatefulWidget {
  final Widget child;
  final double distance;
  final String direction;
  final bool reverse;
  final Duration duration;
  final Curve curve;
  final double initialOpacity;
  final bool animateOpacity;
  final double scale;
  final Duration delay;
  final Duration disappearAfter;
  final Duration disappearDuration;
  final Curve disappearCurve;
  final VoidCallback? onComplete;
  final VoidCallback? onDisappearanceComplete;

  const AnimatedContent({
    super.key,
    required this.child,
    this.distance = 100.0,
    this.direction = 'vertical',
    this.reverse = false,
    this.duration = const Duration(milliseconds: 800),
    this.curve = Curves.easeOutCubic, // power3.out equivalent
    this.initialOpacity = 0.0,
    this.animateOpacity = true,
    this.scale = 1.0,
    this.delay = Duration.zero,
    this.disappearAfter = Duration.zero,
    this.disappearDuration = const Duration(milliseconds: 500),
    this.disappearCurve = Curves.easeInCubic, // power3.in equivalent
    this.onComplete,
    this.onDisappearanceComplete,
  });

  @override
  State<AnimatedContent> createState() => _AnimatedContentState();
}

class _AnimatedContentState extends State<AnimatedContent>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _opacityAnimation;
  late Animation<double> _scaleAnimation;
  late Animation<Offset> _slideAnimation;
  Timer? _delayTimer;
  Timer? _disappearTimer;

  bool _isDisappearing = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: widget.duration,
    );

    _setupAnimations();

    if (widget.delay == Duration.zero) {
      _startEntryAnimation();
    } else {
      _delayTimer = Timer(widget.delay, () {
        if (mounted) {
          _startEntryAnimation();
        }
      });
    }
  }

  void _setupAnimations() {
    // Opacity
    _opacityAnimation = Tween<double>(
      begin: widget.animateOpacity ? widget.initialOpacity : 1.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: widget.curve,
    ));

    // Scale
    _scaleAnimation = Tween<double>(
      begin: widget.scale,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: widget.curve,
    ));

    // Slide/Translate
    // Positive offset moves positive direction:
    // Vertical: distance > 0 moves down, so start at distance means it slides UP to 0
    // Horizontal: distance > 0 moves right, so start at distance means it slides LEFT to 0
    final double offsetVal = widget.reverse ? -widget.distance : widget.distance;
    final Offset beginOffset = widget.direction == 'horizontal'
        ? Offset(offsetVal, 0.0)
        : Offset(0.0, offsetVal);

    _slideAnimation = Tween<Offset>(
      begin: beginOffset,
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: widget.curve,
    ));
  }

  void _startEntryAnimation() {
    _controller.forward().then((_) {
      if (mounted) {
        widget.onComplete?.call();
        if (widget.disappearAfter > Duration.zero) {
          _disappearTimer = Timer(widget.disappearAfter, () {
            if (mounted) {
              _startDisappearanceAnimation();
            }
          });
        }
      }
    });
  }

  void _startDisappearanceAnimation() {
    setState(() {
      _isDisappearing = true;
    });

    _controller.duration = widget.disappearDuration;
    
    _opacityAnimation = Tween<double>(
      begin: 1.0,
      end: widget.animateOpacity ? widget.initialOpacity : 0.0,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: widget.disappearCurve,
    ));

    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: 0.8,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: widget.disappearCurve,
    ));

    final double offsetVal = widget.reverse ? widget.distance : -widget.distance;
    final Offset endOffset = widget.direction == 'horizontal'
        ? Offset(offsetVal, 0.0)
        : Offset(0.0, offsetVal);

    _slideAnimation = Tween<Offset>(
      begin: Offset.zero,
      end: endOffset,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: widget.disappearCurve,
    ));

    _controller.reset();
    _controller.forward().then((_) {
      if (mounted) {
        widget.onDisappearanceComplete?.call();
      }
    });
  }

  @override
  void dispose() {
    _delayTimer?.cancel();
    _disappearTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        Widget current = child!;

        // Apply scale transition
        if (_scaleAnimation.value != 1.0 || _isDisappearing) {
          current = Transform.scale(
            scale: _scaleAnimation.value,
            child: current,
          );
        }

        // Apply slide translation
        if (_slideAnimation.value != Offset.zero) {
          current = Transform.translate(
            offset: _slideAnimation.value,
            child: current,
          );
        }

        // Apply opacity
        current = Opacity(
          opacity: _opacityAnimation.value,
          child: current,
        );

        return current;
      },
      child: widget.child,
    );
  }
}
