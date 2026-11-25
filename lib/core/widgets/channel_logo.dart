import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../data/models/channel.dart';
import '../theme/app_theme.dart';
import '../utils/text.dart';

/// Channel artwork with a graceful monogram fallback.
///
/// The light "logo well" keeps colourful broadcaster marks readable on the
/// dark interface, while missing or broken images fall back to a tinted
/// monogram that stays sharp at any size.
class ChannelLogo extends StatelessWidget {
  const ChannelLogo({
    super.key,
    required this.channel,
    this.width = 52,
    this.height = 52,
    this.radius = 14,
    this.padding = 7,
    this.background,
    this.fit = BoxFit.contain,
  });

  final Channel channel;
  final double width;
  final double height;
  final double radius;
  final double padding;
  final Color? background;
  final BoxFit fit;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final palette = context.palette;
    final tile = background ?? colors.logoTile;
    final fallback = _Monogram(
      channel: channel,
      width: width,
      height: height,
      radius: radius,
      padding: padding,
      colors: colors,
      palette: palette,
    );

    Widget artwork;
    final logo = channel.logo;
    if (logo == null || logo.isEmpty) {
      artwork = fallback;
    } else if (channel.logoFormat?.toUpperCase() == 'SVG') {
      artwork = ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: ColoredBox(
          color: tile,
          child: Padding(
            padding: EdgeInsets.all(padding),
            child: SvgPicture.network(
              logo,
              fit: fit,
              placeholderBuilder: (_) => fallback,
              errorBuilder: (_, _, _) => fallback,
              semanticsLabel: channel.name,
            ),
          ),
        ),
      );
    } else {
      artwork = ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: CachedNetworkImage(
          imageUrl: logo,
          width: width,
          height: height,
          fit: fit,
          memCacheWidth: 360,
          fadeInDuration: const Duration(milliseconds: 220),
          fadeOutDuration: const Duration(milliseconds: 80),
          placeholder: (_, _) => ColoredBox(color: tile, child: fallback),
          errorWidget: (_, _, _) => fallback,
        ),
      );
    }

    return Semantics(
      image: true,
      label: '${channel.name} logo',
      child: RepaintBoundary(
        child: Container(
          width: width,
          height: height,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(radius),
            color: tile,
            border: Border.all(
              color: Colors.white.withValues(alpha: .10),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: .22),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: artwork,
        ),
      ),
    );
  }
}

class _Monogram extends StatelessWidget {
  const _Monogram({
    required this.channel,
    required this.width,
    required this.height,
    required this.radius,
    required this.padding,
    required this.colors,
    required this.palette,
  });

  final Channel channel;
  final double width;
  final double height;
  final double radius;
  final double padding;
  final AppColors colors;
  final AppPalette palette;

  @override
  Widget build(BuildContext context) {
    final shortest = width.isFinite && height.isFinite
        ? (width < height ? width : height)
        : 80.0;
    final hue = stableHue(channel.id);
    final tint = HSLColor.fromAHSL(1, hue.toDouble(), .42, .20).toColor();
    final base = Color.lerp(colors.surfaceAlt, tint, .55)!;
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [base, colors.surface],
        ),
        borderRadius: BorderRadius.circular(radius),
      ),
      alignment: Alignment.center,
      padding: EdgeInsets.all(padding),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Text(
          channelInitials(channel.name),
          style: TextStyle(
            fontFamily: 'Sora',
            fontWeight: FontWeight.w700,
            fontSize: shortest * .36,
            color: Colors.white.withValues(alpha: .9),
            letterSpacing: -.5,
          ),
        ),
      ),
    );
  }
}

String channelQuality(Channel channel) {
  for (final source in channel.sources) {
    if (source.quality != null) return source.displayQuality;
  }
  return 'LIVE';
}
