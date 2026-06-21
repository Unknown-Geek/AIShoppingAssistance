import 'package:flutter/material.dart';

class ShimmerPlaceholder extends StatefulWidget {
  final double width;
  final double height;
  final double borderRadius;

  const ShimmerPlaceholder({
    super.key,
    required this.width,
    required this.height,
    this.borderRadius = 8,
  });

  @override
  State<ShimmerPlaceholder> createState() => _ShimmerPlaceholderState();
}

class _ShimmerPlaceholderState extends State<ShimmerPlaceholder>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat(reverse: true);
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
        return Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            color: Color.lerp(
              const Color(0xFFE5E7EB), // Light grey
              const Color(0xFFF3F4F6), // Even lighter grey
              _controller.value,
            ),
            borderRadius: BorderRadius.circular(widget.borderRadius),
          ),
        );
      },
    );
  }
}

class ProfileSkeletonList extends StatelessWidget {
  const ProfileSkeletonList({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      itemCount: 3,
      itemBuilder: (context, index) {
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: const Color(0xFFD2E4E6), width: 1.2),
          ),
          child: const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header row
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ShimmerPlaceholder(width: 80, height: 18, borderRadius: 6),
                      SizedBox(height: 6),
                      ShimmerPlaceholder(width: 100, height: 12, borderRadius: 4),
                    ],
                  ),
                  ShimmerPlaceholder(width: 70, height: 22, borderRadius: 12),
                ],
              ),
              SizedBox(height: 20),
              
              // Body items
              Row(
                children: [
                  ShimmerPlaceholder(width: 24, height: 16, borderRadius: 4),
                  SizedBox(width: 10),
                  ShimmerPlaceholder(width: 160, height: 14, borderRadius: 4),
                ],
              ),
              SizedBox(height: 10),
              Row(
                children: [
                  ShimmerPlaceholder(width: 24, height: 16, borderRadius: 4),
                  SizedBox(width: 10),
                  ShimmerPlaceholder(width: 120, height: 14, borderRadius: 4),
                ],
              ),
              
              SizedBox(height: 16),
              Divider(height: 1, color: Color(0xFFEEEEEE)),
              SizedBox(height: 12),
              
              // Footer
              ShimmerPlaceholder(width: 220, height: 10, borderRadius: 4),
            ],
          ),
        );
      },
    );
  }
}
