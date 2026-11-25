import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/theme/app_theme.dart';
import '../../core/utils/navigation.dart';
import '../../core/widgets/app_background.dart';
import '../../core/widgets/channel_logo.dart';
import '../../core/widgets/channel_tiles.dart';
import '../../core/widgets/common.dart';
import '../../core/widgets/loading_view.dart';
import '../../core/widgets/pressable.dart';
import '../../data/models/catalog.dart';
import '../../data/models/channel.dart';
import '../../data/models/stream_source.dart';
import '../../state/library_controller.dart';
import '../../state/providers.dart';
import '../epg/epg_guide_sheet.dart';
import '../player/player_screen.dart';

class ChannelDetailScreen extends ConsumerStatefulWidget {
  const ChannelDetailScreen({super.key, required this.channel});

  final Channel channel;

  @override
  ConsumerState<ChannelDetailScreen> createState() =>
      _ChannelDetailScreenState();
}

class _ChannelDetailScreenState extends ConsumerState<ChannelDetailScreen> {
  Channel get channel => widget.channel;
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() => _ready = true);
    });
  }

  void _play(
    BuildContext context,
    Catalog catalog, {
    StreamSource? source,
  }) {
    final related = catalog.relatedTo(channel, limit: 24);
    final queue = <Channel>[channel, ...related];
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        fullscreenDialog: true,
        builder: (_) => PlayerScreen(
          queue: queue,
          initialIndex: 0,
          preferredSourceUrl: source?.url,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final catalog = ref.watch(catalogProvider).value;
    final library = ref.watch(libraryProvider);
    final colors = context.colors;
    final palette = context.palette;
    final isFavorite = library.isFavorite(channel.id);
    final currentProgram = ref.watch(currentProgramProvider(channel));
    final hasRealGuide = currentProgram != null && !currentProgram.isEstimated;

    if (!_ready || catalog == null) {
      return NightsunLoadingView(
        channel: channel,
        title: 'Tuning in to ${channel.name}',
        subtitle: 'Retrieving channel lineup & stream mirrors…',
        showBackButton: true,
      );
    }

    final country = catalog.countryOf(channel);
    final category = catalog.categoryName(channel.primaryCategory);
    final languages = catalog.languageNames(channel);
    final related = catalog.relatedTo(channel, limit: 12);

    return Scaffold(
      backgroundColor: colors.background,
      body: AppBackground(
        stars: true,
        starCount: 36,
        child: SafeArea(
          bottom: false,
          child: CustomScrollView(
            physics: const ClampingScrollPhysics(),
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(10, 6, 14, 0),
                  child: Row(
                    children: [
                      IconCircleButton(
                        icon: Icons.arrow_back_rounded,
                        tooltip: 'Back',
                        onTap: () => Navigator.of(context).pop(),
                        filled: false,
                        size: 40,
                      ),
                      const Spacer(),
                      IconCircleButton(
                        icon: isFavorite
                            ? Icons.favorite_rounded
                            : Icons.favorite_border_rounded,
                        tooltip: isFavorite
                            ? 'Remove from favourites'
                            : 'Add to favourites',
                        color: isFavorite ? palette.primary : colors.text,
                        onTap: () => ref
                            .read(libraryProvider.notifier)
                            .toggleFavorite(channel.id),
                        size: 40,
                      ),
                      const SizedBox(width: 6),
                      IconCircleButton(
                        icon: Icons.ios_share_rounded,
                        tooltip: 'Share channel',
                        onTap: () => _share(context, country.name),
                        size: 40,
                      ),
                    ],
                  ),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
                sliver: SliverToBoxAdapter(
                  child: _HeroCard(
                    channel: channel,
                    country: country,
                    category: category,
                    languages: languages,
                    isFavorite: isFavorite,
                    onFavorite: () => ref
                        .read(libraryProvider.notifier)
                        .toggleFavorite(channel.id),
                    onPlay: () => _play(context, catalog),
                  ),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                sliver: SliverToBoxAdapter(
                  child: _FactsRow(
                    country: country,
                    category: category,
                    languages: languages,
                    channel: channel,
                  ),
                ),
              ),
              if (hasRealGuide) ...[
                SliverToBoxAdapter(
                  child: SectionHeader(
                    title: 'On Air & Guide',
                    eyebrow: 'LIVE BROADCAST SCHEDULE',
                    padding: const EdgeInsets.fromLTRB(20, 22, 20, 10),
                  ),
                ),
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  sliver: SliverToBoxAdapter(
                    child: EpgNowPlayingCard(
                      channel: channel,
                      onViewGuide: () =>
                          showEpgGuideSheet(context, channel: channel),
                    ),
                  ),
                ),
              ],
              SliverToBoxAdapter(
                child: SectionHeader(
                  title: 'Streams',
                  eyebrow:
                      '${channel.sources.length} SOURCE${channel.sources.length == 1 ? '' : 'S'} · TRY ANOTHER IF ONE FAILS',
                  padding: const EdgeInsets.fromLTRB(20, 26, 20, 12),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                sliver: SliverList.builder(
                  itemCount: channel.sources.length,
                  itemBuilder: (context, index) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: _SourceCard(
                      source: channel.sources[index],
                      index: index,
                      count: channel.sources.length,
                      isLastGood:
                          library.lastGoodSources[channel.id] ==
                              channel.sources[index].url,
                      onPlay: () => _play(
                        context,
                        catalog,
                        source: channel.sources[index],
                      ),
                    ),
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: _InfoSection(
                  channel: channel,
                  country: country,
                  category: category,
                  languages: languages,
                  onOpenWebsite: () => _openWebsite(context),
                ),
              ),
              if (related.isNotEmpty) ...[
                const SliverToBoxAdapter(
                  child: SectionHeader(
                    title: 'More like this',
                    eyebrow: 'KEEP THE NIGHT GOING',
                  ),
                ),
                SliverToBoxAdapter(
                  child: SizedBox(
                    height: 210,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      itemCount: related.length,
                      separatorBuilder: (_, _) => const SizedBox(width: 11),
                      itemBuilder: (context, index) {
                        final item = related[index];
                        return ChannelCard(
                          channel: item,
                          catalog: catalog,
                          isFavorite: library.isFavorite(item.id),
                          onTap: () => Navigator.of(context).pushReplacement(
                            smoothScreenRoute(
                              ChannelDetailScreen(channel: item),
                            ),
                          ),
                          onFavorite: () => ref
                              .read(libraryProvider.notifier)
                              .toggleFavorite(item.id),
                        );
                      },
                    ),
                  ),
                ),
              ],
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
                  child: Text(
                    'NightsunTV does not host this stream. If every source is '
                    'offline, the broadcaster may have moved it or restricted '
                    'it to another region. Try again later or pick a related '
                    'channel.',
                    style: TextStyle(
                      fontSize: 9.5,
                      height: 1.55,
                      color: colors.faint,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: SizedBox(
                  height: 26 + MediaQuery.paddingOf(context).bottom,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _share(BuildContext context, String countryName) async {
    final country = countryName.isEmpty ? '' : ' · $countryName';
    await SharePlus.instance.share(
      ShareParams(
        subject: channel.name,
        text: '${channel.name}$country — free live TV on NightsunTV. '
            'No account, no ads, no limits.',
      ),
    );
  }

  Future<void> _openWebsite(BuildContext context) async {
    final website = channel.website;
    if (website == null) return;
    final uri = Uri.tryParse(website);
    if (uri == null) return;
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok && context.mounted) {
      AppNotices.show(context, 'Could not open this channel’s website.');
    }
  }
}

class _HeroCard extends StatelessWidget {
  const _HeroCard({
    required this.channel,
    required this.country,
    required this.category,
    required this.languages,
    required this.isFavorite,
    required this.onFavorite,
    required this.onPlay,
  });

  final Channel channel;
  final CatalogCountry country;
  final String category;
  final List<String> languages;
  final bool isFavorite;
  final VoidCallback onFavorite;
  final VoidCallback onPlay;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final palette = context.palette;
    final theme = Theme.of(context);
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(26),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color.lerp(colors.surface, palette.primary, .16)!,
            colors.surface,
            Color.lerp(colors.surface, palette.secondary, .06)!,
          ],
          stops: const [0, .55, 1],
        ),
        border: Border.all(color: palette.primary.withValues(alpha: .22)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: .3),
            blurRadius: 26,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            right: -38,
            top: -46,
            child: Icon(
              Icons.live_tv_rounded,
              size: 180,
              color: Colors.white.withValues(alpha: .045),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 17),
            child: Column(
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ChannelLogo(
                      channel: channel,
                      width: 84,
                      height: 84,
                      radius: 20,
                      padding: 12,
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              _LiveBadge(
                                label: channel.sources.length > 1
                                    ? 'LIVE · ${channel.sources.length} MIRRORS'
                                    : 'LIVE',
                              ),
                              if (channel.bestQuality != 'Auto') ...[
                                const SizedBox(width: 6),
                                _MiniBadge(label: channel.bestQuality),
                              ],
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            channel.name,
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.headlineMedium?.copyWith(
                              fontSize: 23,
                              height: 1.12,
                              letterSpacing: -.5,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            '${country.flag}  ${country.name}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w600,
                              color: colors.muted,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Wrap(
                  spacing: 7,
                  runSpacing: 7,
                  children: [
                    AppChip(
                      label: category,
                      dense: true,
                      icon: Icons.category_rounded,
                    ),
                    if (languages.isNotEmpty)
                      AppChip(
                        label: languages.take(2).join(' · '),
                        dense: true,
                        icon: Icons.translate_rounded,
                      ),
                    if (channel.network != null)
                      AppChip(
                        label: channel.network!,
                        dense: true,
                        icon: Icons.apartment_rounded,
                      ),
                  ],
                ),
                const SizedBox(height: 17),
                Row(
                  children: [
                    Expanded(
                      child: PrimaryButton(
                        label: 'Watch live',
                        icon: Icons.play_arrow_rounded,
                        height: 52,
                        onTap: onPlay,
                      ),
                    ),
                    const SizedBox(width: 9),
                    SizedBox(
                      width: 52,
                      height: 52,
                      child: Material(
                        color: colors.elevated.withValues(alpha: .8),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                          side: BorderSide(color: colors.borderStrong),
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: InkWell(
                          onTap: onFavorite,
                          child: Icon(
                            isFavorite
                                ? Icons.favorite_rounded
                                : Icons.favorite_border_rounded,
                            size: 23,
                            color: isFavorite ? palette.primary : colors.muted,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _LiveBadge extends StatelessWidget {
  const _LiveBadge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: .3),
        borderRadius: BorderRadius.circular(7),
        border: Border.all(color: Colors.white.withValues(alpha: .13)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 5,
            height: 5,
            decoration: BoxDecoration(
              color: context.colors.success,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: context.colors.success.withValues(alpha: .6),
                  blurRadius: 6,
                ),
              ],
            ),
          ),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              fontSize: 7.8,
              fontWeight: FontWeight.w800,
              letterSpacing: .7,
              color: Colors.white.withValues(alpha: .9),
            ),
          ),
        ],
      ),
    );
  }
}

class _MiniBadge extends StatelessWidget {
  const _MiniBadge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
      decoration: BoxDecoration(
        color: context.palette.primary.withValues(alpha: .12),
        borderRadius: BorderRadius.circular(7),
        border: Border.all(
          color: context.palette.primary.withValues(alpha: .3),
        ),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 7.8,
          fontWeight: FontWeight.w800,
          letterSpacing: .4,
          color: context.palette.primary,
        ),
      ),
    );
  }
}

class _FactsRow extends StatelessWidget {
  const _FactsRow({
    required this.country,
    required this.category,
    required this.languages,
    required this.channel,
  });

  final CatalogCountry country;
  final String category;
  final List<String> languages;
  final Channel channel;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    Widget fact(String value, String label) => Expanded(
          child: Column(
            children: [
              Text(
                value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: 'Sora',
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: colors.text,
                  letterSpacing: -.1,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                label,
                style: TextStyle(
                  fontSize: 8.5,
                  fontWeight: FontWeight.w700,
                  letterSpacing: .7,
                  color: colors.faint,
                ),
              ),
            ],
          ),
        );
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 13),
      decoration: BoxDecoration(
        color: colors.surface.withValues(alpha: .55),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: colors.border),
      ),
      child: Row(
        children: [
          fact(country.code == 'ZZ' ? 'Global' : country.name, 'COUNTRY'),
          Container(width: 1, height: 26, color: colors.border),
          fact(category, 'GENRE'),
          Container(width: 1, height: 26, color: colors.border),
          fact(
            languages.isEmpty ? 'Unlisted' : languages.first,
            'LANGUAGE',
          ),
          Container(width: 1, height: 26, color: colors.border),
          fact(
            channel.launched == null ? '—' : '${channel.launched}',
            'LAUNCHED',
          ),
        ],
      ),
    );
  }
}

class _SourceCard extends StatelessWidget {
  const _SourceCard({
    required this.source,
    required this.index,
    required this.count,
    required this.isLastGood,
    required this.onPlay,
  });

  final StreamSource source;
  final int index;
  final int count;
  final bool isLastGood;
  final VoidCallback onPlay;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final palette = context.palette;
    final headers = source.requestHeaders;
    return Material(
      color: colors.surface.withValues(alpha: .62),
      borderRadius: BorderRadius.circular(17),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onPlay,
        child: Container(
          padding: const EdgeInsets.fromLTRB(12, 11, 9, 11),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(17),
            border: Border.all(
              color: isLastGood
                  ? palette.primary.withValues(alpha: .35)
                  : colors.border,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(11),
                  color: index == 0
                      ? palette.primary.withValues(alpha: .12)
                      : colors.surfaceAlt,
                  border: Border.all(
                    color: index == 0
                        ? palette.primary.withValues(alpha: .28)
                        : colors.border,
                  ),
                ),
                alignment: Alignment.center,
                child: Icon(
                  index == 0
                      ? Icons.star_rounded
                      : Icons.swap_horiz_rounded,
                  size: 17,
                  color: index == 0 ? palette.primary : colors.muted,
                ),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            index == 0
                                ? 'Primary source'
                                : 'Backup source ${index + 1} of $count',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: colors.text,
                            ),
                          ),
                        ),
                        if (isLastGood) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 5,
                              vertical: 1.5,
                            ),
                            decoration: BoxDecoration(
                              color: palette.primary.withValues(alpha: .13),
                              borderRadius: BorderRadius.circular(5),
                            ),
                            child: Text(
                              'WORKED LAST',
                              style: TextStyle(
                                fontSize: 6.8,
                                fontWeight: FontWeight.w800,
                                letterSpacing: .4,
                                color: palette.primary,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${source.displayQuality} · ${source.formatLabel} · ${source.hostLabel}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 9.5,
                        fontWeight: FontWeight.w500,
                        color: colors.faint,
                      ),
                    ),
                    if (headers.isNotEmpty) ...[
                      const SizedBox(height: 5),
                      Row(
                        children: [
                          Icon(
                            Icons.vpn_key_outlined,
                            size: 10,
                            color: colors.faint,
                          ),
                          const SizedBox(width: 4),
                          Flexible(
                            child: Text(
                              'Requires ${headers.keys.join(' + ')}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 8.5,
                                fontWeight: FontWeight.w600,
                                color: colors.faint,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 5),
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: palette.primary.withValues(alpha: .12),
                  border: Border.all(
                    color: palette.primary.withValues(alpha: .25),
                  ),
                ),
                child: Icon(
                  Icons.play_arrow_rounded,
                  size: 21,
                  color: palette.primary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _InfoSection extends StatelessWidget {
  const _InfoSection({
    required this.channel,
    required this.country,
    required this.category,
    required this.languages,
    required this.onOpenWebsite,
  });

  final Channel channel;
  final CatalogCountry country;
  final String category;
  final List<String> languages;
  final VoidCallback onOpenWebsite;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final palette = context.palette;
    Widget row(String label, String value) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 5),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 82,
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: colors.faint,
                  ),
                ),
              ),
              Expanded(
                child: Text(
                  value,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    height: 1.4,
                    color: colors.text,
                  ),
                ),
              ),
            ],
          ),
        );

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 22, 16, 0),
      child: Container(
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(
          color: colors.surface.withValues(alpha: .5),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: colors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.info_outline_rounded,
                    size: 14, color: palette.primary),
                const SizedBox(width: 7),
                Text(
                  'CHANNEL DETAILS',
                  style: TextStyle(
                    fontSize: 8.5,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.1,
                    color: colors.muted,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 9),
            row('Country', '${country.flag} ${country.name}'),
            row('Genre', category),
            if (languages.isNotEmpty) row('Languages', languages.join(', ')),
            if (channel.network != null) row('Network', channel.network!),
            if (channel.launched != null)
              row('Launched', '${channel.launched}'),
            if (channel.altNames.isNotEmpty)
              row('Also known as', channel.altNames.join(', ')),
            if (channel.website != null)
              Pressable(
                onTap: onOpenWebsite,
                child: Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Row(
                    children: [
                      Icon(Icons.link_rounded,
                          size: 14, color: palette.primary),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          channel.website!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w700,
                            color: palette.primary,
                          ),
                        ),
                      ),
                      const SizedBox(width: 3),
                      Icon(Icons.open_in_new_rounded,
                          size: 10, color: palette.primary),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
