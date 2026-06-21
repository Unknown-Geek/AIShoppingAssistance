import 'dart:async';
import 'package:flutter/material.dart';
import 'animated_orb.dart';

class WelcomeCard extends StatefulWidget {
  const WelcomeCard({super.key});

  @override
  State<WelcomeCard> createState() => _WelcomeCardState();
}

class _WelcomeCardState extends State<WelcomeCard> {
  bool _startSecondSentence = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: Colors.white,
        gradient: LinearGradient(
          colors: [
            Colors.white,
            theme.colorScheme.secondary.withValues(alpha: 0.08),
          ],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
        borderRadius: BorderRadius.circular(36),
        border: Border.all(color: const Color(0xFFD2E4E6), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: theme.colorScheme.primary.withValues(alpha: 0.04),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const SizedBox(
                width: 56,
                height: 56,
                child: ClipOval(child: AnimatedOrb(size: 64)),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TypewriterText(
                      text: 'Hi there!',
                      style: TextStyle(
                        fontFamily: theme.textTheme.titleLarge?.fontFamily,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.primary,
                      ),
                      onComplete: () {
                        setState(() {
                          _startSecondSentence = true;
                        });
                      },
                    ),
                    TypewriterText(
                      text: "I'm your Qless Assistant.",
                      startTyping: _startSecondSentence,
                      style: TextStyle(
                        fontFamily: theme.textTheme.titleLarge?.fontFamily,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            'Ask me questions, get item suggestions, update your cart, or find recipe ideas!',
            style: TextStyle(
              fontFamily: theme.textTheme.bodyMedium?.fontFamily,
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: theme.colorScheme.primary.withValues(alpha: 0.7),
            ),
          ),
        ],
      ),
    );
  }
}

class TypewriterText extends StatefulWidget {
  final String text;
  final TextStyle style;
  final Duration typingSpeed;
  final Duration initialDelay;
  final bool showCursor;
  final String cursorCharacter;
  final VoidCallback? onComplete;
  final bool startTyping;

  const TypewriterText({
    super.key,
    required this.text,
    required this.style,
    this.typingSpeed = const Duration(milliseconds: 60),
    this.initialDelay = Duration.zero,
    this.showCursor = true,
    this.cursorCharacter = '|',
    this.onComplete,
    this.startTyping = true,
  });

  @override
  State<TypewriterText> createState() => _TypewriterTextState();
}

class _TypewriterTextState extends State<TypewriterText> {
  String _displayedText = '';
  int _currentCharIndex = 0;
  Timer? _typingTimer;
  Timer? _cursorTimer;
  bool _cursorVisible = true;
  bool _isDone = false;
  bool _hasStarted = false;

  @override
  void initState() {
    super.initState();
    if (widget.showCursor) {
      _cursorTimer = Timer.periodic(const Duration(milliseconds: 400), (timer) {
        if (mounted) {
          setState(() {
            _cursorVisible = !_cursorVisible;
          });
        }
      });
    }
    
    if (widget.startTyping) {
      _triggerStart();
    }
  }

  @override
  void didUpdateWidget(TypewriterText oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.startTyping && !oldWidget.startTyping && !_hasStarted) {
      _triggerStart();
    }
  }

  void _triggerStart() {
    _hasStarted = true;
    if (widget.initialDelay > Duration.zero) {
      Timer(widget.initialDelay, _startTyping);
    } else {
      _startTyping();
    }
  }

  void _startTyping() {
    if (!mounted) return;
    _typingTimer = Timer.periodic(widget.typingSpeed, (timer) {
      if (!mounted) return;
      if (_currentCharIndex < widget.text.length) {
        setState(() {
          _displayedText += widget.text[_currentCharIndex];
          _currentCharIndex++;
        });
      } else {
        _typingTimer?.cancel();
        setState(() {
          _isDone = true;
        });
        _cursorTimer?.cancel();
        if (widget.onComplete != null) {
          widget.onComplete!();
        }
      }
    });
  }

  @override
  void dispose() {
    _typingTimer?.cancel();
    _cursorTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_hasStarted && _displayedText.isEmpty) {
      return RichText(
        text: TextSpan(
          text: widget.text,
          style: widget.style.copyWith(color: Colors.transparent),
        ),
      );
    }

    final typedPart = widget.text.substring(0, _currentCharIndex);
    final remainingPart = widget.text.substring(_currentCharIndex);

    return RichText(
      text: TextSpan(
        children: [
          TextSpan(
            text: typedPart,
            style: widget.style,
          ),
          if (widget.showCursor && !_isDone && _cursorVisible)
            TextSpan(
              text: widget.cursorCharacter,
              style: widget.style.copyWith(
                color: widget.style.color?.withValues(alpha: 0.8) ?? Colors.black54,
              ),
            ),
          TextSpan(
            text: remainingPart,
            style: widget.style.copyWith(color: Colors.transparent),
          ),
        ],
      ),
    );
  }
}
