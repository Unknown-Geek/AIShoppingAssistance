import 'package:flutter/material.dart';

class RollingPriceText extends StatefulWidget {
  final double value;
  final TextStyle style;

  const RollingPriceText({super.key, required this.value, required this.style});

  @override
  State<RollingPriceText> createState() => _RollingPriceTextState();
}

class _RollingPriceTextState extends State<RollingPriceText> {
  double _oldValue = 0.0;

  @override
  void initState() {
    super.initState();
    _oldValue = widget.value;
  }

  @override
  void didUpdateWidget(RollingPriceText oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value != widget.value) {
      _oldValue = oldWidget.value;
    }
  }

  @override
  Widget build(BuildContext context) {
    final double currentVal = widget.value;
    final bool goingUp = currentVal > _oldValue;

    final String newText = '₹${currentVal.toStringAsFixed(2)}';
    final List<String> newChars = newText.split('').reversed.toList();
    final List<Widget> charWidgets = [];

    // tabulate figures to prevent horizontal jitter
    final TextStyle displayStyle = widget.style.copyWith(
      fontFeatures: const [FontFeature.tabularFigures()],
    );

    for (int i = 0; i < newChars.length; i++) {
      final String newChar = newChars[i];

      charWidgets.add(
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          switchInCurve: Curves.easeOutBack,
          switchOutCurve: Curves.easeIn,
          transitionBuilder: (Widget child, Animation<double> animation) {
            final childKey = child.key as ValueKey<String>;
            final isCurrent = childKey.value == 'char-$i-$newChar';
            final offset = goingUp ? 1.0 : -1.0;

            return ClipRect(
              child: SlideTransition(
                position: Tween<Offset>(
                  begin: isCurrent ? Offset(0.0, offset) : Offset(0.0, -offset),
                  end: Offset.zero,
                ).animate(animation),
                child: child,
              ),
            );
          },
          child: Text(
            newChar,
            key: ValueKey<String>('char-$i-$newChar'),
            style: displayStyle,
          ),
        ),
      );
    }

    final widgets = charWidgets.reversed.toList();

    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: widgets,
    );
  }
}
