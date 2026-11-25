import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'channel_logo.dart';
import 'star_field.dart';

/// Cosmic pulse loader matching the NightsunTV astronomical aesthetic.
/// Features a breathing solar core, dual counter-rotating orbital gyro rings,
/// and an optional centered channel logo or television emblem.
class NightsunPulseLoader extends StatefulWidget {
  const NightsunPulseLoader({
    super.key,
    this.size = 84,
    this.channel,
    this.customIcon,
    this.color,
  });

  final double size;
  final dynamic channel; // Channel?
  final IconData? customIcon;
  final Color? color;

  @override
  State<NightsunPulseLoader> createState() => _NightsunPulseLoaderState();
}

class _NightsunPulseLoaderState extends State<NightsunPulseLoader>
    with TickerProviderStateMixin {
  late final AnimationController _rotationController = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2800),
  )..repeat();

  late final AnimationController _pulseController = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1800),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _rotationController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final primary = widget.color ?? palette.primary;
    final secondary = palette.secondary;

    return AnimatedBuilder(
      animation: Listenable.merge([_rotationController, _pulseController]),
      builder: (context, child) {
        final pulse = Curves.easeInOut.transform(_pulseController.value);
        final angle = _rotationController.value * 2 * math.pi;

        return SizedBox(
          width: widget.size,
          height: widget.size,
          child: Stack(
            alignment: Alignment.center,
            children: [
              CustomPaint(
                size: Size(widget.size, widget.size),
                painter: _OrbitalGyroPainter(
                  primaryColor: primary,
                  secondaryColor: secondary,
                  angle: angle,
                  pulse: pulse,
                ),
              ),
              if (widget.channel != null)
                ChannelLogo(
                  channel: widget.channel,
                  width: widget.size * 0.52,
                  height: widget.size * 0.52,
                  radius: widget.size * 0.14,
                  padding: 6,
                )
              else
                Container(
                  width: widget.size * 0.44,
                  height: widget.size * 0.44,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [primary, secondary],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: primary.withValues(alpha: .45 + pulse * .25),
                        blurRadius: 14 + pulse * 6,
                        spreadRadius: 1 + pulse * 2,
                      ),
                    ],
                  ),
                  child: Center(
                    child: Icon(
                      widget.customIcon ?? Icons.live_tv_rounded,
                      size: widget.size * 0.22,
                      color: const Color(0xFF070B14),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _OrbitalGyroPainter extends CustomPainter {
  const _OrbitalGyroPainter({
    required this.primaryColor,
    required this.secondaryColor,
    required this.angle,
    required this.pulse,
  });

  final Color primaryColor;
  final Color secondaryColor;
  final double angle;
  final double pulse;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final maxRadius = size.width / 2;

    // Atmospheric breathing outer glow
    final glowPaint = Paint()
      ..shader = RadialGradient(
        colors: [
          primaryColor.withValues(alpha: .28 + pulse * .16),
          secondaryColor.withValues(alpha: .08),
          Colors.transparent,
        ],
        stops: const [0.0, 0.65, 1.0],
      ).createShader(Rect.fromCircle(center: center, radius: maxRadius));
    canvas.drawCircle(center, maxRadius, glowPaint);

    // Expanding beacon pulse wave
    final waveRadius = maxRadius * (0.65 + pulse * 0.3);
    final wavePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..color = primaryColor.withValues(alpha: (1.0 - pulse) * 0.45);
    canvas.drawCircle(center, waveRadius, wavePaint);

    // Gyroscopic Orbit Ring 1 (Clockwise)
    final ring1Radius = maxRadius * 0.88;
    final ring1Paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6
      ..color = primaryColor.withValues(alpha: .32);
    canvas.drawCircle(center, ring1Radius, ring1Paint);

    // Orbital satellite pip 1
    final sat1 = Offset(
      center.dx + ring1Radius * math.cos(angle),
      center.dy + ring1Radius * math.sin(angle),
    );
    final pip1Paint = Paint()
      ..color = primaryColor
      ..style = PaintingStyle.fill;
    canvas.drawCircle(sat1, 3.2, pip1Paint);
    canvas.drawCircle(
      sat1,
      6.0,
      Paint()..color = primaryColor.withValues(alpha: .35),
    );

    // Gyroscopic Orbit Ring 2 (Counter-Clockwise dashed arc)
    final ring2Radius = maxRadius * 0.72;
    final sweepRect = Rect.fromCircle(center: center, radius: ring2Radius);
    final arcPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4
      ..shader = SweepGradient(
        startAngle: -angle,
        endAngle: -angle + math.pi * 1.5,
        colors: [
          secondaryColor.withValues(alpha: .7),
          primaryColor.withValues(alpha: .1),
        ],
      ).createShader(sweepRect);
    canvas.drawArc(sweepRect, -angle, math.pi * 1.2, false, arcPaint);

    // Orbital satellite pip 2
    final sat2 = Offset(
      center.dx + ring2Radius * math.cos(-angle + math.pi * 0.8),
      center.dy + ring2Radius * math.sin(-angle + math.pi * 0.8),
    );
    canvas.drawCircle(sat2, 2.4, Paint()..color = secondaryColor);
  }

  @override
  bool shouldRepaint(covariant _OrbitalGyroPainter oldDelegate) {
    return oldDelegate.angle != angle ||
        oldDelegate.pulse != pulse ||
        oldDelegate.primaryColor != primaryColor;
  }
}

/// A full-screen or card loading view with animated status cycling,
/// starry background atmosphere, glowing shimmer beam, and orbital loader.
class NightsunLoadingView extends StatefulWidget {
  const NightsunLoadingView({
    super.key,
    required this.title,
    this.subtitle,
    this.message,
    this.channel,
    this.statusMessages,
    this.showBackButton = false,
    this.onBack,
    this.compact = false,
  });

  final String title;
  final String? subtitle;
  final String? message;
  final dynamic channel;
  final List<String>? statusMessages;
  final bool showBackButton;
  final VoidCallback? onBack;
  final bool compact;

  @override
  State<NightsunLoadingView> createState() => _NightsunLoadingViewState();
}

class _NightsunLoadingViewState extends State<NightsunLoadingView>
    with SingleTickerProviderStateMixin {
  late final List<String> _statuses = widget.statusMessages ??
      const [
        'Connecting to live broadcast mirrors…',
        'Synchronizing 10,000+ worldwide stations…',
        'Testing highest quality stream feeds…',
        'Preparing seamless playback…',
      ];

  int _statusIndex = 0;
  Timer? _statusTimer;
  late final AnimationController _beamController = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1600),
  )..repeat();

  @override
  void initState() {
    super.initState();
    if (_statuses.length > 1) {
      _statusTimer = Timer.periodic(const Duration(milliseconds: 2200), (timer) {
        if (!mounted) return;
        setState(() {
          _statusIndex = (_statusIndex + 1) % _statuses.length;
        });
      });
    }
  }

  @override
  void dispose() {
    _statusTimer?.cancel();
    _beamController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final palette = context.palette;

    final content = Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            NightsunPulseLoader(
              size: widget.compact ? 72 : 92,
              channel: widget.channel,
              color: palette.primary,
            ),
            const SizedBox(height: 24),
            Text(
              widget.title,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'Sora',
                fontSize: widget.compact ? 16 : 19,
                fontWeight: FontWeight.w700,
                color: Colors.white,
                letterSpacing: -.3,
              ),
            ),
            if (widget.subtitle != null) ...[
              const SizedBox(height: 7),
              Text(
                widget.subtitle!,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: 'Manrope',
                  fontSize: widget.compact ? 11 : 12.5,
                  fontWeight: FontWeight.w500,
                  color: Colors.white.withValues(alpha: .68),
                ),
              ),
            ],
            const SizedBox(height: 20),
            // Indeterminate glowing beam indicator
            Container(
              width: 140,
              height: 3.5,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: .08),
                borderRadius: BorderRadius.circular(99),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(99),
                child: AnimatedBuilder(
                  animation: _beamController,
                  builder: (context, _) {
                    final t = _beamController.value;
                    return FractionalTranslation(
                      translation: Offset(-1.0 + t * 2.0, 0),
                      child: Container(
                        width: 70,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              palette.primary.withValues(alpha: .1),
                              palette.primary,
                              palette.secondary,
                              palette.secondary.withValues(alpha: .1),
                            ],
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: palette.primary.withValues(alpha: .7),
                              blurRadius: 6,
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
            const SizedBox(height: 18),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 380),
              transitionBuilder: (child, animation) {
                return FadeTransition(
                  opacity: animation,
                  child: SlideTransition(
                    position: Tween<Offset>(
                      begin: const Offset(0, 0.3),
                      end: Offset.zero,
                    ).animate(animation),
                    child: child,
                  ),
                );
              },
              child: Text(
                widget.message ?? _statuses[_statusIndex],
                key: ValueKey<int>(_statusIndex),
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: 'Manrope',
                  fontSize: widget.compact ? 10.5 : 11.5,
                  fontWeight: FontWeight.w600,
                  color: palette.primary.withValues(alpha: .92),
                  letterSpacing: .2,
                ),
              ),
            ),
          ],
        ),
      ),
    );

    if (widget.compact) {
      return content;
    }

    return Scaffold(
      backgroundColor: colors.background,
      body: Stack(
        children: [
          const StarField(count: 36, opacity: 0.8),
          SafeArea(child: content),
          if (widget.showBackButton)
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.only(left: 14, top: 10),
                child: Material(
                  color: Colors.black.withValues(alpha: .38),
                  shape: const CircleBorder(),
                  clipBehavior: Clip.antiAlias,
                  child: InkWell(
                    onTap: widget.onBack ?? () => Navigator.of(context).maybePop(),
                    child: const SizedBox(
                      width: 42,
                      height: 42,
                      child: Icon(
                        Icons.arrow_back_rounded,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Cinematic stream loading view for PlayerScreen with animated signal status.
class StreamLoadingView extends StatelessWidget {
  const StreamLoadingView({
    super.key,
    required this.channel,
    required this.status,
    this.flag,
    this.countryName,
    this.hasMultipleSources = false,
    this.onSkipSource,
  });

  final dynamic channel;
  final String status;
  final String? flag;
  final String? countryName;
  final bool hasMultipleSources;
  final VoidCallback? onSkipSource;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return Center(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 380),
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 16),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: .72),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: Colors.white.withValues(alpha: .12)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: .5),
              blurRadius: 24,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: SingleChildScrollView(
          physics: const ClampingScrollPhysics(),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              NightsunPulseLoader(
                size: 72,
                channel: channel,
                color: palette.primary,
              ),
              const SizedBox(height: 12),
              Text(
                channel.name,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontFamily: 'Sora',
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                  letterSpacing: -.2,
                ),
              ),
              if (flag != null && countryName != null) ...[
                const SizedBox(height: 3),
                Text(
                  '$flag $countryName',
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w500,
                    color: Colors.white.withValues(alpha: .6),
                  ),
                ),
              ],
              const SizedBox(height: 12),
            // Status chip with animated pulsing indicator
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
              decoration: BoxDecoration(
                color: palette.primary.withValues(alpha: .12),
                borderRadius: BorderRadius.circular(99),
                border: Border.all(
                  color: palette.primary.withValues(alpha: .32),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: 13,
                    height: 13,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: palette.primary,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      status,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontFamily: 'Manrope',
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: palette.primary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            if (hasMultipleSources) ...[
              const SizedBox(height: 14),
              Material(
                color: Colors.white.withValues(alpha: .08),
                borderRadius: BorderRadius.circular(10),
                child: InkWell(
                  onTap: onSkipSource,
                  borderRadius: BorderRadius.circular(10),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.skip_next_rounded,
                          size: 15,
                          color: Colors.white.withValues(alpha: .9),
                        ),
                        const SizedBox(width: 5),
                        Text(
                          'Skip to next mirror',
                          style: TextStyle(
                            fontFamily: 'Manrope',
                            fontSize: 10.5,
                            fontWeight: FontWeight.w600,
                            color: Colors.white.withValues(alpha: .9),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    ),
  );
  }
}
