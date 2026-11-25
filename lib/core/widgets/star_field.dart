import 'dart:math' as math;

import 'package:flutter/material.dart';

/// A deterministic, very subtle star field. Used sparingly — onboarding and
/// the About screen — so it reads as atmosphere rather than decoration.
class StarField extends StatelessWidget {
  const StarField({
    super.key,
    this.color = Colors.white,
    this.count = 70,
    this.seed = 41,
    this.opacity = 1,
  });

  final Color color;
  final int count;
  final int seed;
  final double opacity;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: CustomPaint(
        painter: _StarPainter(
          color: color,
          count: count,
          seed: seed,
          opacity: opacity,
        ),
        child: const SizedBox.expand(),
      ),
    );
  }
}

class _StarPainter extends CustomPainter {
  const _StarPainter({
    required this.color,
    required this.count,
    required this.seed,
    required this.opacity,
  });

  final Color color;
  final int count;
  final int seed;
  final double opacity;

  @override
  void paint(Canvas canvas, Size size) {
    final random = math.Random(seed);
    final paint = Paint();
    for (var i = 0; i < count; i++) {
      final x = random.nextDouble() * size.width;
      final y = random.nextDouble() * size.height;
      final radius = random.nextDouble() * 1.25 + .35;
      final alpha = (random.nextDouble() * .5 + .18) * opacity;
      paint.color = color.withValues(alpha: alpha);
      canvas.drawCircle(Offset(x, y), radius, paint);
      if (i % 13 == 0) {
        paint.color = color.withValues(alpha: alpha * .18);
        canvas.drawCircle(Offset(x, y), radius * 3.2, paint);
      }
    }
  }

  @override
  bool shouldRepaint(_StarPainter oldDelegate) =>
      oldDelegate.count != count ||
      oldDelegate.seed != seed ||
      oldDelegate.color != color ||
      oldDelegate.opacity != opacity;
}
