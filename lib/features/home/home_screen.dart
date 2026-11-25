import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/theme/app_theme.dart';
import '../../core/utils/navigation.dart';
import '../../core/utils/text.dart';
import '../../core/widgets/channel_tiles.dart';
import '../../core/widgets/common.dart';
import '../../core/widgets/loading_view.dart';
import '../../core/widgets/pressable.dart';
import '../../data/models/browse_filter.dart';
import '../../data/models/catalog.dart';
import '../../data/models/channel.dart';
import '../../state/library_controller.dart';
import '../../state/providers.dart';
import '../../state/settings_controller.dart';
import '../channel/channel_detail_screen.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(catalogProvider);
    final catalog = async.value;
    final channels = ref.watch(visibleChannelsProvider);
    final library = ref.watch(libraryProvider);
    final showAdult =
        ref.watch(settingsProvider.select((settings) => settings.showAdult));
    final strongSignals = catalog?.strongSignals(limit: 12) ?? const <Channel>[];
    final newArrivals = catalog?.newArrivals(limit: 12) ?? const <Channel>[];
    final now = DateTime.now();

    void openChannel(Channel channel) {
      Navigator.of(context).push(
        smoothScreenRoute(ChannelDetailScreen(channel: channel)),
      );
    }

    void openBrowse({String? country, String? category, ChannelSort? sort}) {
      final filters = ref.read(browseFilterProvider.notifier);
      filters.reset();
      if (country != null) filters.setCountry(country);
      if (category != null) filters.setCategory(category);
      if (sort != null) filters.setSort(sort);
      ref.read(shellTabProvider.notifier).select(1);
    }

    void openSearch() {
      ref.read(shellTabProvider.notifier).select(2);
      ref.read(searchFocusProvider.notifier).requestFocus();
    }

    void surprise() {
      final pool = channels
          .where((channel) => channel.hasLogo && channel.sources.isNotEmpty)
          .toList(growable: false);
      if (pool.isEmpty) {
        AppNotices.show(context, 'Channels are still loading.');
        return;
      }
      openChannel(pool[math.Random().nextInt(pool.length)]);
    }

    return CustomScrollView(
      physics: const AlwaysScrollableScrollPhysics(
        parent: ClampingScrollPhysics(),
      ),
      slivers: [
        SliverToBoxAdapter(
          child: _HomeHeader(
            greeting: greetingFor(now),
            channelCount: channels.isNotEmpty ? channels.length : 15239,
            countryCount: (catalog?.countries.length ?? 0) > 0
                ? catalog!.countries.length
                : 184,
            streamCount: (catalog?.sourceCount ?? 0) > 0
                ? catalog!.sourceCount
                : 26570,
            loaded: catalog != null,
            onSurprise: surprise,
            onSettings: () => ref.read(shellTabProvider.notifier).select(4),
          ),
        ),
        SliverToBoxAdapter(
          child: _SearchEntry(
            onTap: openSearch,
            channelCount: channels.isNotEmpty ? channels.length : 15239,
            countryCount: (catalog?.countries.length ?? 0) > 0
                ? catalog!.countries.length
                : 184,
          ),
        ),
        if (catalog == null && async.hasError)
          SliverFillRemaining(
            hasScrollBody: false,
            child: InlineError(
              message: async.error.toString(),
              onRetry: () => ref.invalidate(catalogProvider),
            ),
          )
        else if (catalog == null)
          const SliverFillRemaining(
            hasScrollBody: false,
            child: NightsunLoadingView(
              title: 'Tuning In to NightsunTV',
              subtitle: 'Connecting to live global broadcast catalog…',
              compact: true,
            ),
          )
        else ...[
          if (library.recents.isNotEmpty) ...[
            const SliverToBoxAdapter(
              child: SectionHeader(
                title: 'Pick up where you left off',
                eyebrow: 'RECENT',
              ),
            ),
            SliverToBoxAdapter(
              child: SizedBox(
                height: 86,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  itemCount: library.recents.length > 10
                      ? 10
                      : library.recents.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 10),
                  itemBuilder: (context, index) {
                    final entry = library.recents[index];
                    final channel = catalog.byId[entry.channelId];
                    if (channel == null ||
                        (!showAdult && channel.nsfw)) {
                      return const SizedBox.shrink();
                    }
                    return RecentCard(
                      channel: channel,
                      catalog: catalog,
                      watchedAt: entry.watchedAt,
                      isFavorite: library.isFavorite(channel.id),
                      onTap: () => openChannel(channel),
                      onFavorite: () =>
                          ref.read(libraryProvider.notifier).toggleFavorite(channel.id),
                    );
                  },
                ),
              ),
            ),
          ],
          SliverToBoxAdapter(
            child: _SpotlightCarousel(
              catalog: catalog,
              onOpenCategory: (category) => openBrowse(category: category),
            ),
          ),
          SliverToBoxAdapter(
            child: SectionHeader(
              title: 'Strong signals',
              eyebrow: '${formatCount(strongSignals.length)} MULTI-SOURCE CHANNELS',
              actionLabel: 'See all',
              onAction: () => openBrowse(sort: ChannelSort.sources),
            ),
          ),
          SliverToBoxAdapter(
            child: SizedBox(
              height: 210,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 20),
                itemCount: strongSignals.length,
                separatorBuilder: (_, _) => const SizedBox(width: 11),
                itemBuilder: (context, index) {
                  final channel = strongSignals[index];
                  return ChannelCard(
                    channel: channel,
                    catalog: catalog,
                    isFavorite: library.isFavorite(channel.id),
                    onTap: () => openChannel(channel),
                    onFavorite: () =>
                        ref.read(libraryProvider.notifier).toggleFavorite(channel.id),
                  );
                },
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: SectionHeader(
              title: 'Around the world',
              eyebrow: '${catalog.countries.length} COUNTRIES',
              actionLabel: 'All (${catalog.countries.length})',
              onAction: () => openBrowse(),
            ),
          ),
          SliverToBoxAdapter(
            child: _CountryStrip(
              catalog: catalog,
              onSelect: (code) => openBrowse(country: code),
            ),
          ),
          SliverToBoxAdapter(
            child: SectionHeader(
              title: 'Find your genre',
              eyebrow: '${catalog.categories.length} CATEGORIES',
              actionLabel: 'Browse all (${catalog.categories.length})',
              onAction: () => openBrowse(),
            ),
          ),
          _CategoryGrid(
            catalog: catalog,
            onSelect: (id) => openBrowse(category: id),
          ),
          if (newArrivals.length >= 4) ...[
            const SliverToBoxAdapter(
              child: SectionHeader(
                title: 'Recently launched',
                eyebrow: 'NEW ARRIVALS',
              ),
            ),
            SliverToBoxAdapter(
              child: SizedBox(
                height: 210,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  itemCount: newArrivals.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 11),
                  itemBuilder: (context, index) {
                    final channel = newArrivals[index];
                    return ChannelCard(
                      channel: channel,
                      catalog: catalog,
                      isFavorite: library.isFavorite(channel.id),
                      onTap: () => openChannel(channel),
                      onFavorite: () => ref
                          .read(libraryProvider.notifier)
                          .toggleFavorite(channel.id),
                    );
                  },
                ),
              ),
            ),
          ],
          SliverToBoxAdapter(
            child: _AttributionFooter(catalog: catalog),
          ),
        ],
        const SliverToBoxAdapter(child: DockSpacer()),
      ],
    );
  }
}

class _HomeHeader extends StatelessWidget {
  const _HomeHeader({
    required this.greeting,
    required this.channelCount,
    required this.countryCount,
    required this.streamCount,
    required this.loaded,
    required this.onSurprise,
    required this.onSettings,
  });

  final String greeting;
  final int channelCount;
  final int countryCount;
  final int streamCount;
  final bool loaded;
  final VoidCallback onSurprise;
  final VoidCallback onSettings;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final palette = context.palette;
    final theme = Theme.of(context);
    final actualChannels = channelCount > 0 ? channelCount : 15239;
    final actualCountries = countryCount > 0 ? countryCount : 184;
    final actualStreams = streamCount > 0 ? streamCount : 26570;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const BrandMark(size: 38, radius: 11),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'NightsunTV',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontFamily: 'Sora',
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -.3,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${formatCount(actualChannels)} FREE BROADCASTS',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 8.2,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.05,
                        color: colors.faint,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              IconCircleButton(
                icon: Icons.auto_awesome_rounded,
                tooltip: 'Surprise me',
                onTap: onSurprise,
                size: 40,
                iconSize: 19,
                color: palette.primary,
              ),
              const SizedBox(width: 6),
              IconCircleButton(
                icon: Icons.tune_rounded,
                tooltip: 'Settings',
                onTap: onSettings,
                size: 40,
                iconSize: 19,
              ),
            ],
          ),
          const SizedBox(height: 20),
          Text(
            '$greeting.',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.2,
              color: palette.primary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Find something\nworth staying up for.',
            style: theme.textTheme.displaySmall?.copyWith(
              fontSize: 30,
              height: 1.08,
              letterSpacing: -1,
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _StatMetricPill(
                  icon: Icons.live_tv_rounded,
                  count: formatCount(actualChannels),
                  label: 'CHANNELS',
                  color: palette.primary,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _StatMetricPill(
                  icon: Icons.public_rounded,
                  count: '$actualCountries',
                  label: 'COUNTRIES',
                  color: palette.secondary,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _StatMetricPill(
                  icon: Icons.sensors_rounded,
                  count: formatCount(actualStreams),
                  label: 'STREAMS',
                  color: colors.success,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatMetricPill extends StatelessWidget {
  const _StatMetricPill({
    required this.icon,
    required this.count,
    required this.label,
    required this.color,
  });

  final IconData icon;
  final String count;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: colors.surface.withValues(alpha: 0.65),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: color.withValues(alpha: 0.22),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(icon, size: 11, color: color),
              const SizedBox(width: 3),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: 'Manrope',
                    fontSize: 7.5,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.6,
                    color: colors.faint,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 3),
          Text(
            count,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontFamily: 'Sora',
              fontSize: 13,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.3,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}

class _SearchEntry extends StatelessWidget {
  const _SearchEntry({
    required this.onTap,
    this.channelCount = 15239,
    this.countryCount = 184,
  });

  final VoidCallback onTap;
  final int channelCount;
  final int countryCount;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final palette = context.palette;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 2),
      child: Pressable(
        onTap: onTap,
        scale: .985,
        child: Container(
          height: 52,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            color: colors.surface.withValues(alpha: .82),
            borderRadius: BorderRadius.circular(17),
            border: Border.all(color: colors.border),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: .18),
                blurRadius: 18,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Row(
            children: [
              Icon(Icons.search_rounded, size: 21, color: palette.primary),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Search ${formatCount(channelCount)} channels across $countryCount countries…',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: colors.faint,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
                decoration: BoxDecoration(
                  color: palette.primary.withValues(alpha: .10),
                  borderRadius: BorderRadius.circular(7),
                ),
                child: Row(
                  children: [
                    Icon(Icons.auto_awesome_rounded, size: 10, color: palette.primary),
                    const SizedBox(width: 3),
                    Text(
                      'SMART',
                      style: TextStyle(
                        fontSize: 7.8,
                        fontWeight: FontWeight.w800,
                        letterSpacing: .5,
                        color: palette.primary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Spot {
  const _Spot({
    required this.category,
    required this.title,
    required this.subtitle,
    required this.icon,
  });
  final String category;
  final String title;
  final String subtitle;
  final IconData icon;
}

const _spots = [
  _Spot(
    category: 'news',
    title: 'The world, live',
    subtitle: 'Follow the story as it happens.',
    icon: Icons.public_rounded,
  ),
  _Spot(
    category: 'movies',
    title: 'Movie night, sorted',
    subtitle: 'Big-screen stories, no ticket price.',
    icon: Icons.movie_rounded,
  ),
  _Spot(
    category: 'sports',
    title: 'Game on',
    subtitle: 'Live action from leagues worldwide.',
    icon: Icons.sports_soccer_rounded,
  ),
  _Spot(
    category: 'music',
    title: 'Press play on music',
    subtitle: 'Charts, classics and everything between.',
    icon: Icons.graphic_eq_rounded,
  ),
  _Spot(
    category: 'kids',
    title: 'For the little ones',
    subtitle: 'Cartoons and family favourites.',
    icon: Icons.child_care_rounded,
  ),
];

class _SpotlightCarousel extends StatefulWidget {
  const _SpotlightCarousel({
    required this.catalog,
    required this.onOpenCategory,
  });

  final Catalog catalog;
  final ValueChanged<String> onOpenCategory;

  @override
  State<_SpotlightCarousel> createState() => _SpotlightCarouselState();
}

class _SpotlightCarouselState extends State<_SpotlightCarousel> {
  late final PageController _controller = PageController(viewportFraction: .88);
  int _page = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final spots = _spots
        .where((spot) => (widget.catalog.categoryCounts[spot.category] ?? 0) > 0)
        .toList(growable: false);
    if (spots.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 22),
      child: Column(
        children: [
          SizedBox(
            height: 172,
            child: PageView.builder(
              controller: _controller,
              padEnds: false,
              itemCount: spots.length,
              onPageChanged: (index) => setState(() => _page = index),
              itemBuilder: (context, index) {
                final spot = spots[index];
                final count = widget.catalog.categoryCounts[spot.category] ?? 0;
                return Padding(
                  padding: EdgeInsets.only(
                    left: index == 0 ? 20 : 0,
                    right: 12,
                  ),
                  child: _SpotCard(
                    spot: spot,
                    count: count,
                    index: index,
                    onTap: () => widget.onOpenCategory(spot.category),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (var index = 0; index < spots.length; index++)
                AnimatedContainer(
                  duration: const Duration(milliseconds: 240),
                  width: index == _page ? 18 : 5,
                  height: 5,
                  margin: const EdgeInsets.symmetric(horizontal: 2.5),
                  decoration: BoxDecoration(
                    color: index == _page
                        ? context.palette.primary
                        : context.colors.borderStrong,
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SpotCard extends StatelessWidget {
  const _SpotCard({
    required this.spot,
    required this.count,
    required this.index,
    required this.onTap,
  });

  final _Spot spot;
  final int count;
  final int index;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final palette = context.palette;
    final mix = [.28, .22, .26, .2, .3][index % 5];
    final start = Color.lerp(colors.surface, palette.primary, mix)!;
    final end = Color.lerp(colors.surface, palette.secondary, mix * .5)!;
    return Pressable(
      onTap: onTap,
      scale: .985,
      child: Container(
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [start, end, colors.surface],
            stops: const [0, .55, 1],
          ),
          border: Border.all(
            color: palette.primary.withValues(alpha: .19),
          ),
        ),
        child: Stack(
          children: [
            Positioned(
              right: -22,
              top: -16,
              child: Icon(
                spot.icon,
                size: 152,
                color: Colors.white.withValues(alpha: .055),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(17, 16, 16, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        'COLLECTION',
                        style: TextStyle(
                          fontSize: 8.5,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.2,
                          color: Colors.white.withValues(alpha: .58),
                        ),
                      ),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 7,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: .24),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          '${formatCount(count)} channels',
                          style: TextStyle(
                            fontSize: 8.5,
                            fontWeight: FontWeight.w700,
                            color: Colors.white.withValues(alpha: .78),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const Spacer(),
                  Text(
                    spot.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontFamily: 'Sora',
                      fontSize: 21,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -.4,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    spot.subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w500,
                      color: Colors.white.withValues(alpha: .66),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 7,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: .94),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'Explore',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                                color: Color.lerp(
                                  colors.background,
                                  palette.primary,
                                  .1,
                                ),
                              ),
                            ),
                            const SizedBox(width: 3),
                            Icon(
                              Icons.arrow_forward_rounded,
                              size: 12,
                              color: colors.background,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CountryStrip extends StatelessWidget {
  const _CountryStrip({required this.catalog, required this.onSelect});

  final Catalog catalog;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) {
    final countries = catalog.topCountries(limit: 12);
    return SizedBox(
      height: 40,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemCount: countries.length + 1,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          if (index == countries.length) {
            return AppChip(
              label: 'All countries',
              icon: Icons.public_rounded,
              dense: true,
              trailing: Text(
                '${catalog.countries.length}',
                style: TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                  color: context.colors.faint,
                ),
              ),
              onTap: () => onSelect(''),
            );
          }
          final country = countries[index];
          final count = catalog.countryCounts[country.code] ?? 0;
          return AppChip(
            label: '${country.flag}  ${country.name}',
            dense: true,
            onTap: () => onSelect(country.code),
            trailing: Text(
              formatCount(count),
              style: TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.w700,
                color: context.colors.faint,
              ),
            ),
          );
        },
      ),
    );
  }
}

const _categoryIcons = {
  'news': Icons.newspaper_rounded,
  'movies': Icons.movie_rounded,
  'sports': Icons.sports_soccer_rounded,
  'music': Icons.graphic_eq_rounded,
  'kids': Icons.child_care_rounded,
  'documentary': Icons.travel_explore_rounded,
};

class _CategoryGrid extends StatelessWidget {
  const _CategoryGrid({required this.catalog, required this.onSelect});

  final Catalog catalog;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) {
    final categories = <CatalogCategory>[];
    for (final id in _categoryIcons.keys) {
      final category = catalog.categoryOf(id);
      if (category != null && (catalog.categoryCounts[id] ?? 0) > 0) {
        categories.add(category);
      }
    }
    if (categories.isEmpty) return const SizedBox.shrink();
    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      sliver: SliverGrid(
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: MediaQuery.sizeOf(context).width >= 600 ? 3 : 2,
          mainAxisSpacing: 9,
          crossAxisSpacing: 9,
          childAspectRatio: 2.25,
        ),
        delegate: SliverChildBuilderDelegate(
          (context, index) {
            final category = categories[index];
            return _CategoryTile(
              category: category,
              icon: _categoryIcons[category.id] ?? Icons.live_tv_rounded,
              count: catalog.categoryCounts[category.id] ?? 0,
              index: index,
              onTap: () => onSelect(category.id),
            );
          },
          childCount: categories.length,
        ),
      ),
    );
  }
}

class _CategoryTile extends StatelessWidget {
  const _CategoryTile({
    required this.category,
    required this.icon,
    required this.count,
    required this.index,
    required this.onTap,
  });

  final CatalogCategory category;
  final IconData icon;
  final int count;
  final int index;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final palette = context.palette;
    final tint = index.isEven ? palette.primary : palette.secondary;
    return Pressable(
      onTap: onTap,
      scale: .975,
      child: Container(
        padding: const EdgeInsets.fromLTRB(11, 10, 10, 10),
        decoration: BoxDecoration(
          color: Color.lerp(colors.surface, tint, .075),
          borderRadius: BorderRadius.circular(17),
          border: Border.all(color: tint.withValues(alpha: .16)),
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(11),
                color: tint.withValues(alpha: .12),
              ),
              child: Icon(icon, size: 18, color: tint),
            ),
            const SizedBox(width: 9),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    category.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: 'Sora',
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: colors.text,
                      letterSpacing: -.2,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    formatCount(count),
                    style: TextStyle(
                      fontSize: 9.5,
                      fontWeight: FontWeight.w600,
                      color: colors.faint,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AttributionFooter extends StatelessWidget {
  const _AttributionFooter({required this.catalog});

  final Catalog catalog;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final palette = context.palette;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 26, 20, 8),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: colors.surface.withValues(alpha: .5),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: colors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.public_rounded, size: 14, color: palette.primary),
                const SizedBox(width: 6),
                Text(
                  'POWERED BY IPTV-ORG',
                  style: TextStyle(
                    fontSize: 8.5,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1,
                    color: colors.muted,
                  ),
                ),
                const Spacer(),
                Text(
                  'Updated ${formatDate(catalog.generatedAt)}',
                  style: TextStyle(
                    fontSize: 8.5,
                    fontWeight: FontWeight.w500,
                    color: colors.faint,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Free, publicly listed streams. NightsunTV does not host or '
              'control any broadcast. Some channels may be offline or '
              'geo-blocked, so backup sources are tried automatically.',
              style: TextStyle(
                fontSize: 10,
                height: 1.5,
                fontWeight: FontWeight.w500,
                color: colors.faint,
              ),
            ),
            const SizedBox(height: 9),
            Pressable(
              onTap: () => launchUrl(
                Uri.parse('https://github.com/iptv-org/iptv'),
                mode: LaunchMode.externalApplication,
              ),
              child: Row(
                children: [
                  Text(
                    'Visit iptv-org on GitHub',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: palette.primary,
                    ),
                  ),
                  const SizedBox(width: 3),
                  Icon(Icons.open_in_new_rounded, size: 11, color: palette.primary),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
