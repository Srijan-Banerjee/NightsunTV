import 'package:flutter/material.dart';

import '../../data/models/catalog.dart';
import '../../data/models/channel.dart';
import '../theme/app_theme.dart';
import '../utils/text.dart';
import 'channel_logo.dart';
import 'common.dart';
import 'pressable.dart';

String channelMetaLine(
  Catalog catalog,
  Channel channel, {
  bool includeSourceCount = true,
}) {
  final country = catalog.countryOf(channel);
  final category = catalog.categoryName(channel.primaryCategory);
  final sources = includeSourceCount && channel.sources.length > 1
      ? ' · ${channel.sources.length} sources'
      : '';
  return '${country.flag} ${country.name} · $category$sources';
}

/// A portrait tile used in horizontal shelves.
class ChannelCard extends StatelessWidget {
  const ChannelCard({
    super.key,
    required this.channel,
    required this.catalog,
    this.onTap,
    this.onFavorite,
    this.isFavorite = false,
    this.width = 168,
  });

  final Channel channel;
  final Catalog catalog;
  final VoidCallback? onTap;
  final VoidCallback? onFavorite;
  final bool isFavorite;
  final double width;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final theme = Theme.of(context);
    final country = catalog.countryOf(channel);
    final innerWidth = width - 20;
    return SizedBox(
      width: width,
      child: Pressable(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: colors.surface.withValues(alpha: .78),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: colors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Stack(
                children: [
                  ChannelLogo(
                    channel: channel,
                    width: innerWidth,
                    height: 94,
                    radius: 14,
                    padding: 12,
                  ),
                  Positioned(
                    left: 7,
                    top: 7,
                    child: QualityBadge(label: channelQuality(channel)),
                  ),
                  if (onFavorite != null)
                    Positioned(
                      right: 6,
                      top: 6,
                      child: _MiniFavorite(
                        active: isFavorite,
                        onTap: onFavorite!,
                        name: channel.name,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 10),
              SizedBox(
                height: 37,
                child: Text(
                  channel.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontSize: 14,
                    height: 1.3,
                  ),
                ),
              ),
              const SizedBox(height: 5),
              Text(
                '${country.flag}  ${country.name}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colors.muted,
                  fontSize: 11.5,
                ),
              ),
              const SizedBox(height: 7),
              Row(
                children: [
                  Expanded(
                    child: SourceCountBadge(count: channel.sources.length),
                  ),
                  Icon(
                    Icons.chevron_right_rounded,
                    size: 16,
                    color: colors.faint,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MiniFavorite extends StatelessWidget {
  const _MiniFavorite({
    required this.active,
    required this.onTap,
    required this.name,
  });

  final bool active;
  final VoidCallback onTap;
  final String name;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Tooltip(
      message: active ? 'Remove from favorites' : 'Add to favorites',
      child: Material(
        color: Colors.black.withValues(alpha: .48),
        shape: const CircleBorder(),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: SizedBox(
            width: 30,
            height: 30,
            child: Icon(
              active ? Icons.favorite_rounded : Icons.favorite_border_rounded,
              size: 16,
              color: active ? palette.primary : Colors.white,
            ),
          ),
        ),
      ),
    );
  }
}

/// The dense row used by Browse, Search and the Library.
class ChannelRowTile extends StatelessWidget {
  const ChannelRowTile({
    super.key,
    required this.channel,
    required this.catalog,
    this.onTap,
    this.onFavorite,
    this.isFavorite = false,
    this.trailing,
    this.subtitle,
    this.showChevron = false,
    this.dense = false,
    this.leading,
  });

  final Channel channel;
  final Catalog catalog;
  final VoidCallback? onTap;
  final VoidCallback? onFavorite;
  final bool isFavorite;
  final Widget? trailing;
  final String? subtitle;
  final bool showChevron;
  final bool dense;
  final Widget? leading;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final theme = Theme.of(context);
    final palette = context.palette;
    final meta = subtitle ?? channelMetaLine(catalog, channel);
    final logoSize = dense ? 46.0 : 54.0;
    return Material(
      color: colors.surface.withValues(alpha: .55),
      borderRadius: BorderRadius.circular(18),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        splashColor: palette.primary.withValues(alpha: .06),
        highlightColor: palette.primary.withValues(alpha: .04),
        child: Container(
          padding: EdgeInsets.symmetric(
            horizontal: dense ? 9 : 10,
            vertical: dense ? 8 : 9,
          ),
          decoration: BoxDecoration(
            border: Border.all(color: colors.border),
            borderRadius: BorderRadius.circular(18),
          ),
          child: Row(
            children: [
              leading ??
                  ChannelLogo(
                    channel: channel,
                    width: logoSize,
                    height: logoSize,
                    radius: 12,
                    padding: 6,
                  ),
              SizedBox(width: dense ? 10 : 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      channel.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontSize: dense ? 13.5 : 14.5,
                        height: 1.25,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      meta,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colors.muted,
                        fontSize: dense ? 10.8 : 11.5,
                        height: 1.25,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              if (onFavorite != null)
                SizedBox(
                  width: 38,
                  height: 42,
                  child: IconButton(
                    tooltip: isFavorite
                        ? 'Remove from favorites'
                        : 'Add to favorites',
                    onPressed: onFavorite,
                    padding: EdgeInsets.zero,
                    iconSize: 20,
                    icon: Icon(
                      isFavorite
                          ? Icons.favorite_rounded
                          : Icons.favorite_border_rounded,
                      color: isFavorite ? palette.primary : colors.faint,
                    ),
                  ),
                ),
              ?trailing,
              if (showChevron)
                Padding(
                  padding: const EdgeInsets.only(left: 1),
                  child: Icon(
                    Icons.chevron_right_rounded,
                    size: 19,
                    color: colors.faint,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A compact horizontal card for the "Continue watching" strip.
class RecentCard extends StatelessWidget {
  const RecentCard({
    super.key,
    required this.channel,
    required this.catalog,
    required this.watchedAt,
    this.onTap,
    this.onFavorite,
    this.isFavorite = false,
  });

  final Channel channel;
  final Catalog catalog;
  final DateTime watchedAt;
  final VoidCallback? onTap;
  final VoidCallback? onFavorite;
  final bool isFavorite;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final theme = Theme.of(context);
    return SizedBox(
      width: 240,
      child: Pressable(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(11),
          decoration: BoxDecoration(
            color: colors.surface.withValues(alpha: .8),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: colors.border),
          ),
          child: Row(
            children: [
              ChannelLogo(
                channel: channel,
                width: 62,
                height: 62,
                radius: 13,
                padding: 7,
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      channel.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleSmall?.copyWith(fontSize: 13.5),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${catalog.countryOf(channel).flag} ${relativeTime(watchedAt)}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colors.muted,
                        fontSize: 11,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Row(
                      children: [
                        Icon(
                          Icons.play_circle_fill_rounded,
                          size: 14,
                          color: context.palette.primary,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'Continue',
                          style: TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w700,
                            color: context.palette.primary,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              if (onFavorite != null)
                IconButton(
                  onPressed: onFavorite,
                  visualDensity: VisualDensity.compact,
                  iconSize: 17,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 32, minHeight: 36),
                  icon: Icon(
                    isFavorite
                        ? Icons.favorite_rounded
                        : Icons.favorite_border_rounded,
                    color: isFavorite ? context.palette.primary : colors.faint,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
