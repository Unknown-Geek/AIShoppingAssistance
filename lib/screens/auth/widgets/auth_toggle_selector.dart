import 'package:flutter/material.dart';

class AuthToggleSelector extends StatelessWidget {
  final bool isSignIn;
  final ValueChanged<bool> onToggle;

  const AuthToggleSelector({
    super.key,
    required this.isSignIn,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 50,
      decoration: BoxDecoration(
        color: const Color(0xFFB3EFB2).withValues(alpha: 0.25),
        borderRadius: BorderRadius.circular(25),
        border: Border.all(
          color: const Color(0xFFB3EFB2).withValues(alpha: 0.25),
        ),
      ),
      child: Stack(
        children: [
          AnimatedAlign(
            alignment: isSignIn ? Alignment.centerLeft : Alignment.centerRight,
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeInOut,
            child: FractionallySizedBox(
              widthFactor: 0.5,
              child: Container(
                margin: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: const Color(0xFF001A23),
                  borderRadius: BorderRadius.circular(21),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF001A23).withValues(alpha: 0.25),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: () => onToggle(true),
                  behavior: HitTestBehavior.opaque,
                  child: Center(
                    child: Text(
                      'Sign In',
                      style: TextStyle(
                        color: isSignIn
                            ? Colors.white
                            : const Color(0xFF001A23),
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ),
              ),
              Expanded(
                child: GestureDetector(
                  onTap: () => onToggle(false),
                  behavior: HitTestBehavior.opaque,
                  child: Center(
                    child: Text(
                      'Sign Up',
                      style: TextStyle(
                        color: !isSignIn
                            ? Colors.white
                            : const Color(0xFF001A23),
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
