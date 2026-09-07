import 'package:flutter/material.dart';

/// Marca G de Google a 4 colores (guideline Sign in with Google).
class GoogleGMark extends StatelessWidget {
  final double size;
  const GoogleGMark({super.key, this.size = 22});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(painter: _GoogleGPainter()),
    );
  }
}

class _GoogleGPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width;
    final c = Offset(s / 2, s / 2);
    final stroke = s * 0.18;
    final r = s / 2 - stroke / 2;

    void arc(Color color, double start, double sweep) {
      final p = Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..strokeCap = StrokeCap.butt;
      canvas.drawArc(
        Rect.fromCircle(center: c, radius: r),
        start,
        sweep,
        false,
        p,
      );
    }

    arc(const Color(0xFF4285F4), -0.35, 1.6);
    arc(const Color(0xFF34A853), 1.25, 1.15);
    arc(const Color(0xFFFBBC05), 2.40, 0.85);
    arc(const Color(0xFFEA4335), 3.25, 1.35);

    final bar = Paint()..color = const Color(0xFF4285F4);
    canvas.drawRect(
      Rect.fromLTWH(c.dx, c.dy - stroke / 2, r + stroke / 2, stroke),
      bar,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
