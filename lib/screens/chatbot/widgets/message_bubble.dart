import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../models/chatbot_models.dart';
import 'recipe_card.dart';
import 'animated_orb.dart';
import 'animated_content.dart';

class MessageBubble extends StatelessWidget {
  final ChatMessage message;

  const MessageBubble({super.key, required this.message});

  String _formatTime(DateTime dateTime) {
    final hour = dateTime.hour == 0
        ? 12
        : (dateTime.hour > 12 ? dateTime.hour - 12 : dateTime.hour);
    final minute = dateTime.minute.toString().padLeft(2, '0');
    final period = dateTime.hour >= 12 ? 'PM' : 'AM';
    return '$hour:$minute $period';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isUser = message.isUser;
    final isRecipe = message.recipe != null;
    final isTyping = message.text == null && message.recipe == null;

    final Widget bubbleWidget;

    if (isUser) {
      // User Bubble Layout
      bubbleWidget = Align(
        alignment: Alignment.centerRight,
        child: Container(
          constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.8,
          ),
          margin: const EdgeInsets.fromLTRB(24, 6, 24, 6),
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
          decoration: BoxDecoration(
            color: theme.colorScheme.secondary.withValues(alpha: 0.20),
            border: Border.all(
              color: theme.colorScheme.secondary.withValues(alpha: 0.50),
              width: 1.0,
            ),
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(28),
              topRight: Radius.circular(28),
              bottomLeft: Radius.circular(28),
              bottomRight: Radius.circular(12),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                message.text ?? '',
                style: TextStyle(
                  fontFamily: 'ClashGrotesk',
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  height: 1.5,
                  color: theme.colorScheme.primary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                _formatTime(message.timestamp),
                style: TextStyle(
                  fontFamily: 'ClashGrotesk',
                  fontSize: 11,
                  fontWeight: FontWeight.w400,
                  color: theme.colorScheme.primary.withValues(alpha: 0.6),
                  letterSpacing: 0.6,
                ),
              ),
            ],
          ),
        ),
      );
    } else {
      // AI Bubble Layout (Left aligned, with Sparkle Avatar)
      bubbleWidget = Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Animated Orb AI Avatar
            const Padding(
              padding: EdgeInsets.only(top: 4),
              child: SizedBox(
                width: 50,
                height: 50,
                child: ClipOval(child: AnimatedOrb(size: 44)),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Align(
                alignment: Alignment.centerLeft,
                child: isRecipe
                    ? RecipeCard(recipe: message.recipe!)
                    : Container(
                        constraints: BoxConstraints(
                          maxWidth: MediaQuery.of(context).size.width * 0.7,
                        ),
                        padding: const EdgeInsets.symmetric(
                          vertical: 12,
                          horizontal: 16,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: const BorderRadius.only(
                            topLeft: Radius.circular(28),
                            topRight: Radius.circular(28),
                            bottomLeft: Radius.circular(12),
                            bottomRight: Radius.circular(28),
                          ),
                          border: Border.all(
                            color: const Color(0xFFD2E4E6),
                            width: 1.2,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: theme.colorScheme.primary.withValues(
                                alpha: 0.04,
                              ),
                              blurRadius: 16,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (isTyping)
                              const Padding(
                                padding: EdgeInsets.symmetric(vertical: 4),
                                child: TypingIndicator(),
                              )
                            else
                              Text(
                                message.text ?? 'Unknown error',
                                style: TextStyle(
                                  fontFamily: 'ClashGrotesk',
                                  fontSize: 16,
                                  fontWeight: FontWeight.w500,
                                  height: 1.5,
                                  color: theme.colorScheme.primary,
                                ),
                              ),
                            if (!isTyping) ...[
                              const SizedBox(height: 4),
                              Text(
                                _formatTime(message.timestamp),
                                style: TextStyle(
                                  fontFamily: 'ClashGrotesk',
                                  fontSize: 11,
                                  fontWeight: FontWeight.w400,
                                  color: theme.colorScheme.primary.withValues(
                                    alpha: 0.6,
                                  ),
                                  letterSpacing: 0.6,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
              ),
            ),
          ],
        ),
      );
    }

    return AnimatedContent(
      distance: 10.0,
      direction: 'horizontal',
      reverse: !isUser,
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeInOut,
      initialOpacity: 0.0,
      scale: 0.96, // Premium subtle scale-up
      child: bubbleWidget,
    );
  }
}

class TypingIndicator extends StatefulWidget {
  const TypingIndicator({super.key});

  @override
  State<TypingIndicator> createState() => _TypingIndicatorState();
}

class _TypingIndicatorState extends State<TypingIndicator>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(3, (index) {
        return AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            final double bounce = (index * 0.2);
            final double value =
                (math.sin(
                      (_controller.value * 2 * math.pi) - (bounce * math.pi),
                    ) +
                    1) /
                2;
            final theme = Theme.of(context);
            return Container(
              margin: const EdgeInsets.symmetric(horizontal: 2),
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: theme.colorScheme.primary.withValues(
                  alpha: 0.3 + (value * 0.5),
                ),
              ),
            );
          },
        );
      }),
    );
  }
}
