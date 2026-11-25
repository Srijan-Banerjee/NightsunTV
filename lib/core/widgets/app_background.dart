import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'star_field.dart';

/// The app's fixed night-sky backdrop. It is intentionally cheap to paint:
/// one linear gradient and a pair of soft radial glows, no backdrop blur.
class AppBackground extends StatelessWidget {
  const AppBackground({
    super.key,
    this.child,
    this.stars = false,
    this.starCount = 60,
    this.glow = true,
  });

  final Widget? child;
  final bool stars;
  final int starCount;
  final bool glow;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final palette = context.palette;
    final pureBlack = colors.isPureBlack;
    return Stack(
      fit: StackFit.expand,
      children: [
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: pureBlack
                  ? const [Color(0xFF000000), Color(0xFF030304)]
                  : const [Color(0xFF080D18), Color(0xFF050810), Color(0xFF070B14)],
              stops: pureBlack ? const [0, 1] : const [0, .55, 1],
            ),
          ),
        ),
        if (glow) ...[
          Positioned(
            top: -180,
            right: -150,
            child: _Glow(
              color: palette.primary,
              size: 420,
              opacity: pureBlack ? .05 : .10,
            ),
          ),
          Positioned(
            top: 280,
            left: -220,
            child: _Glow(
              color: palette.secondary,
              size: 440,
              opacity: pureBlack ? .035 : .07,
            ),
          ),
        ],
        if (stars)
          StarField(
            count: starCount,
            color: palette.primary,
            opacity: .9,
          ),
        ?child,
      ],
    );
  }
}

class _Glow extends StatelessWidget {
  const _Glow({required this.color, required this.size, required this.opacity});

  final Color color;
  final double size;
  final double opacity;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: [
              color.withValues(alpha: opacity),
              color.withValues(alpha: 0),
            ],
          ),
        ),
      ),
    );
  }
}
