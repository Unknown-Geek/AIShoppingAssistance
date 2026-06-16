import 'package:flutter/material.dart';

class ReticlePainter extends CustomPainter {
  final Color color;
  final double strokeWidth;
  final double borderRadius;
  final double arcLength;

  ReticlePainter({
    required this.color,
    required this.strokeWidth,
    required this.borderRadius,
    required this.arcLength,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final double w = size.width;
    final double h = size.height;
    final double r = borderRadius;
    final double len = arcLength;

    final pathTL = Path()
      ..moveTo(0, r + len)
      ..lineTo(0, r)
      ..arcToPoint(Offset(r, 0), radius: Radius.circular(r))
      ..lineTo(r + len, 0);
    canvas.drawPath(pathTL, paint);

    final pathTR = Path()
      ..moveTo(w - (r + len), 0)
      ..lineTo(w - r, 0)
      ..arcToPoint(Offset(w, r), radius: Radius.circular(r))
      ..lineTo(w, r + len);
    canvas.drawPath(pathTR, paint);

    final pathBR = Path()
      ..moveTo(w, h - (r + len))
      ..lineTo(w, h - r)
      ..arcToPoint(Offset(w - r, h), radius: Radius.circular(r))
      ..lineTo(w - (r + len), h);
    canvas.drawPath(pathBR, paint);

    final pathBL = Path()
      ..moveTo(r + len, h)
      ..lineTo(r, h)
      ..arcToPoint(Offset(0, h - r), radius: Radius.circular(r))
      ..lineTo(0, h - (r + len));
    canvas.drawPath(pathBL, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
