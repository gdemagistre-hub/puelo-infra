import 'package:flutter/material.dart';

/// Lockup PROX (casita + wordmark + slogan).
class ProxLockup extends StatelessWidget {
  final double maxWidth;
  final bool showSlogan;

  const ProxLockup({
    super.key,
    this.maxWidth = 280,
    this.showSlogan = true,
  });

  static const String assetPath = 'assets/images/prox_lockup.png';

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: maxWidth),
      child: Image.asset(
        assetPath,
        fit: BoxFit.contain,
        errorBuilder: (_, __, ___) => _Fallback(showSlogan: showSlogan),
      ),
    );
  }
}

class _Fallback extends StatelessWidget {
  final bool showSlogan;
  const _Fallback({required this.showSlogan});

  static const Color teal = Color(0xFF00A3B0);
  static const Color navy = Color(0xFF0B2A4A);

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: const [
            CustomPaint(size: Size(52, 46), painter: _HousePinPainter()),
            SizedBox(width: 10),
            Text(
              'PROX',
              style: TextStyle(
                fontSize: 34,
                fontWeight: FontWeight.w800,
                color: navy,
                letterSpacing: -0.8,
                height: 1,
              ),
            ),
          ],
        ),
        if (showSlogan) ...[
          const SizedBox(height: 14),
          const Text(
            'Trabajo de confianza,',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: navy,
              height: 1.15,
            ),
          ),
          const Text(
            'cerca tuyo.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: teal,
              height: 1.1,
            ),
          ),
        ],
      ],
    );
  }
}

class _HousePinPainter extends CustomPainter {
  const _HousePinPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = const Color(0xFF00A3B0)
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.width * 0.18
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final path = Path()
      ..moveTo(size.width * 0.12, size.height * 0.92)
      ..lineTo(size.width * 0.12, size.height * 0.42)
      ..lineTo(size.width * 0.50, size.height * 0.10)
      ..lineTo(size.width * 0.88, size.height * 0.42)
      ..lineTo(size.width * 0.88, size.height * 0.92);
    canvas.drawPath(path, p);

    final fill = Paint()..color = const Color(0xFF00A3B0);
    final cx = size.width * 0.50;
    final cy = size.height * 0.58;
    final r = size.width * 0.16;
    canvas.drawCircle(Offset(cx, cy), r, fill);
    final tip = Path()
      ..moveTo(cx - r * 0.85, cy + r * 0.2)
      ..lineTo(cx + r * 0.85, cy + r * 0.2)
      ..lineTo(cx, cy + r * 1.65)
      ..close();
    canvas.drawPath(tip, fill);
    canvas.drawCircle(
      Offset(cx, cy),
      r * 0.38,
      Paint()..color = Colors.white,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
