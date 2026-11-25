import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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
import '../channel/channel_detail_screen.dart';

class BrowseScreen extends ConsumerStatefulWidget {
  const BrowseScreen({super.key});

  @override
  ConsumerState<BrowseScreen> createState() => _BrowseScreenState();
}

class _BrowseScreenState extends ConsumerState<BrowseScreen> {
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() => _ready = true);
    });
  }

  void _openChannel(BuildContext context, Channel channel) {
    Navigator.of(context).push(
      smoothScreenRoute(ChannelDetailScreen(channel: channel)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(catalogProvider);
    final catalog = async.value;
    final filter = ref.watch(browseFilterProvider);

    if (!_ready || catalog == null) {
      return CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(
          parent: ClampingScrollPhysics(),
        ),
        slivers: [
          SliverToBoxAdapter(
            child: _BrowseHeader(
              total: catalog?.channels.length ?? 0,
              activeFilters: filter.activeCount,
              onFilter: () => showBrowseFilterSheet(context),
              sort: filter.sort,
              onSort: (sort) =>
                  ref.read(browseFilterProvider.notifier).setSort(sort),
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
          else
            const SliverFillRemaining(
              hasScrollBody: false,
              child: NightsunLoadingView(
                title: 'Exploring Worldwide Channels',
                subtitle: 'Categorizing countries, genres & languages…',
                compact: true,
              ),
            ),
        ],
      );
    }

    final channels = ref.watch(filteredChannelsProvider);
    final library = ref.watch(libraryProvider);

    return CustomScrollView(
      physics: const AlwaysScrollableScrollPhysics(
        parent: ClampingScrollPhysics(),
      ),
      slivers: [
        SliverToBoxAdapter(
          child: _BrowseHeader(
            total: channels.length,
            activeFilters: filter.activeCount,
            onFilter: () => showBrowseFilterSheet(context),
            sort: filter.sort,
            onSort: (sort) =>
                ref.read(browseFilterProvider.notifier).setSort(sort),
          ),
        ),
          if (filter.isActive)
            SliverToBoxAdapter(
              child: _ActiveFilters(
                filter: filter,
                catalog: catalog,
                onChanged: (next) => ref
                    .read(browseFilterProvider.notifier)
                    .setSort(next),
              ),
            ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 10),
              child: Text(
                channels.isEmpty
                    ? 'No channels match these filters'
                    : '${formatCount(channels.length)} channel${channels.length == 1 ? '' : 's'}',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: context.colors.faint,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      letterSpacing: .2,
                    ),
              ),
            ),
          ),
          if (channels.isEmpty)
            SliverFillRemaining(
              hasScrollBody: false,
              child: EmptyState(
                icon: Icons.filter_alt_off_rounded,
                title: 'Nothing on this dial',
                message:
                    'Try removing a filter or choosing a different country, '
                    'category or language.',
                actionLabel: 'Clear filters',
                onAction: () =>
                    ref.read(browseFilterProvider.notifier).reset(),
                compact: true,
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              sliver: SliverList.builder(
                itemCount: channels.length,
                itemBuilder: (context, index) {
                  final channel = channels[index];
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: ChannelRowTile(
                      channel: channel,
                      catalog: catalog,
                      isFavorite: library.isFavorite(channel.id),
                      onFavorite: () => ref
                          .read(libraryProvider.notifier)
                          .toggleFavorite(channel.id),
                      onTap: () => _openChannel(context, channel),
                      showChevron: true,
                    ),
                  );
                },
              ),
            ),
        const SliverToBoxAdapter(child: DockSpacer()),
      ],
    );
  }
}

Future<void> showBrowseFilterSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => const _BrowseFilterSheet(),
  );
}

class _BrowseHeader extends StatelessWidget {
  const _BrowseHeader({
    required this.total,
    required this.activeFilters,
    required this.onFilter,
    required this.sort,
    required this.onSort,
  });

  final int total;
  final int activeFilters;
  final VoidCallback onFilter;
  final ChannelSort sort;
  final ValueChanged<ChannelSort> onSort;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final palette = context.palette;
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Browse',
                      style: theme.textTheme.displaySmall?.copyWith(
                        fontSize: 30,
                        letterSpacing: -1,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'Every free channel, one place',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colors.muted,
                        fontSize: 11.5,
                      ),
                    ),
                  ],
                ),
              ),
              _FilterButton(count: activeFilters, onTap: onFilter),
            ],
          ),
          const SizedBox(height: 17),
          SizedBox(
            height: 36,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                for (final option in ChannelSort.values) ...[
                  AppChip(
                    label: option.label,
                    dense: true,
                    selected: sort == option,
                    icon: option == ChannelSort.nameAsc
                        ? Icons.sort_by_alpha_rounded
                        : option == ChannelSort.country
                            ? Icons.public_rounded
                            : option == ChannelSort.newest
                                ? Icons.auto_awesome_rounded
                                : Icons.layers_rounded,
                    onTap: () => onSort(option),
                  ),
                  const SizedBox(width: 7),
                ],
              ],
            ),
          ),
          const SizedBox(height: 2),
          Row(
            children: [
              Container(
                width: 5,
                height: 5,
                decoration: BoxDecoration(
                  color: palette.primary,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                '$total on air',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: .3,
                  color: colors.faint,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _FilterButton extends StatelessWidget {
  const _FilterButton({required this.count, required this.onTap});

  final int count;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final colors = context.colors;
    return Pressable(
      onTap: onTap,
      child: Container(
        height: 42,
        padding: const EdgeInsets.symmetric(horizontal: 13),
        decoration: BoxDecoration(
          color: count > 0
              ? palette.primary.withValues(alpha: .12)
              : colors.surfaceAlt.withValues(alpha: .8),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: count > 0
                ? palette.primary.withValues(alpha: .45)
                : colors.border,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.tune_rounded,
              size: 18,
              color: count > 0 ? palette.primary : colors.text,
            ),
            const SizedBox(width: 7),
            Text(
              count > 0 ? 'Filters · $count' : 'Filters',
              style: TextStyle(
                fontFamily: 'Manrope',
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: count > 0 ? palette.primary : colors.text,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ActiveFilters extends ConsumerWidget {
  const _ActiveFilters({
    required this.filter,
    required this.catalog,
    required this.onChanged,
  });

  final BrowseFilter filter;
  final Catalog catalog;
  final ValueChanged<ChannelSort> onChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(browseFilterProvider.notifier);
    final chips = <Widget>[];
    if (filter.country != null) {
      final country = catalog.countriesByCode[filter.country];
      chips.add(AppChip(
        label: '${country?.flag ?? ''}  ${country?.name ?? filter.country}',
        dense: true,
        selected: true,
        trailing: const Icon(Icons.close_rounded, size: 13),
        onTap: () => notifier.setCountry(null),
      ));
    }
    if (filter.category != null) {
      chips.add(AppChip(
        label: catalog.categoryName(filter.category!),
        dense: true,
        selected: true,
        trailing: const Icon(Icons.close_rounded, size: 13),
        onTap: () => notifier.setCategory(null),
      ));
    }
    if (filter.language != null) {
      chips.add(AppChip(
        label: catalog.languageName(filter.language!) ?? filter.language!,
        dense: true,
        selected: true,
        trailing: const Icon(Icons.close_rounded, size: 13),
        onTap: () => notifier.setLanguage(null),
      ));
    }
    if (chips.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 2, 20, 4),
      child: Wrap(
        spacing: 7,
        runSpacing: 7,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          ...chips,
          TextButton(
            onPressed: () => notifier.reset(),
            style: TextButton.styleFrom(
              minimumSize: const Size(0, 28),
              padding: const EdgeInsets.symmetric(horizontal: 7),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              foregroundColor: context.colors.faint,
            ),
            child: Text(
              'Clear all',
              style: TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.w700,
                color: context.colors.faint,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BrowseFilterSheet extends ConsumerStatefulWidget {
  const _BrowseFilterSheet();

  @override
  ConsumerState<_BrowseFilterSheet> createState() => _BrowseFilterSheetState();
}

class _BrowseFilterSheetState extends ConsumerState<_BrowseFilterSheet>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs = TabController(length: 3, vsync: this);
  final TextEditingController _search = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _tabs.dispose();
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final catalog = ref.watch(catalogProvider).value;
    final filter = ref.watch(browseFilterProvider);
    final colors = context.colors;
    final palette = context.palette;
    final height = MediaQuery.sizeOf(context).height;

    return Container(
      height: height * .84,
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        border: Border.all(color: colors.border),
      ),
      child: Column(
        children: [
          const SizedBox(height: 9),
          Container(
            width: 36,
            height: 4,
            decoration: BoxDecoration(
              color: colors.borderStrong,
              borderRadius: BorderRadius.circular(99),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 14, 12, 10),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Refine the lineup',
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      const SizedBox(height: 3),
                      Text(
                        'Narrow 10,000+ channels down to yours.',
                        style: TextStyle(
                          fontSize: 11.5,
                          color: colors.muted,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                TextButton(
                  onPressed: () {
                    ref.read(browseFilterProvider.notifier).clear();
                    _search.clear();
                    setState(() => _query = '');
                  },
                  style: TextButton.styleFrom(
                    foregroundColor: colors.muted,
                    textStyle: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  child: const Text('Reset'),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: TextField(
              controller: _search,
              onChanged: (value) => setState(() => _query = value),
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                hintText: 'Search countries, categories, languages…',
                prefixIcon: const Icon(Icons.search_rounded, size: 19),
                suffixIcon: _query.isEmpty
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.close_rounded, size: 18),
                        onPressed: () {
                          _search.clear();
                          setState(() => _query = '');
                        },
                      ),
                isDense: true,
              ),
            ),
          ),
          const SizedBox(height: 12),
          TabBar(
            controller: _tabs,
            labelColor: palette.primary,
            unselectedLabelColor: colors.muted,
            indicatorColor: palette.primary,
            indicatorSize: TabBarIndicatorSize.label,
            dividerColor: colors.border,
            labelStyle: const TextStyle(
              fontFamily: 'Manrope',
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
            tabs: const [
              Tab(text: 'Country'),
              Tab(text: 'Category'),
              Tab(text: 'Language'),
            ],
          ),
          Expanded(
            child: catalog == null
                ? const NightsunLoadingView(
                    title: 'Loading filters',
                    subtitle: 'Preparing country & category options…',
                    compact: true,
                  )
                : TabBarView(
                    controller: _tabs,
                    children: [
                      _OptionList(
                        query: _query,
                        options: _countryOptions(catalog, _query),
                        selected: filter.country,
                        onSelect: (value) => ref
                            .read(browseFilterProvider.notifier)
                            .setCountry(value),
                      ),
                      _OptionList(
                        query: _query,
                        options: _categoryOptions(catalog, _query),
                        selected: filter.category,
                        onSelect: (value) => ref
                            .read(browseFilterProvider.notifier)
                            .setCategory(value),
                      ),
                      _OptionList(
                        query: _query,
                        options: _languageOptions(catalog, _query),
                        selected: filter.language,
                        onSelect: (value) => ref
                            .read(browseFilterProvider.notifier)
                            .setLanguage(value),
                      ),
                    ],
                  ),
          ),
          Container(
            padding: EdgeInsets.fromLTRB(
              20,
              12,
              20,
              14 + MediaQuery.paddingOf(context).bottom,
            ),
            decoration: BoxDecoration(
              color: colors.surface,
              border: Border(top: BorderSide(color: colors.border)),
            ),
            child: PrimaryButton(
              label: 'Show results',
              icon: Icons.check_rounded,
              height: 50,
              onTap: () => Navigator.of(context).pop(),
            ),
          ),
        ],
      ),
    );
  }
}

class _Option {
  const _Option(this.value, this.label, this.trailing);
  final String value;
  final String label;
  final String trailing;
}

List<_Option> _countryOptions(Catalog catalog, String query) {
  final normalized = normalizeForSearch(query);
  final countries = [...catalog.countries]
    ..sort((a, b) {
      final byCount =
          (catalog.countryCounts[b.code] ?? 0).compareTo(catalog.countryCounts[a.code] ?? 0);
      return byCount != 0 ? byCount : a.name.compareTo(b.name);
    });
  return [
    for (final country in countries)
      if (normalized.isEmpty ||
          normalizeForSearch('${country.name} ${country.code}')
              .contains(normalized))
        _Option(
          country.code,
          '${country.flag}  ${country.name}',
          formatCount(catalog.countryCounts[country.code] ?? 0),
        ),
  ];
}

List<_Option> _categoryOptions(Catalog catalog, String query) {
  final normalized = normalizeForSearch(query);
  final categories = [...catalog.categories]
    ..sort((a, b) {
      final byCount =
          (catalog.categoryCounts[b.id] ?? 0).compareTo(catalog.categoryCounts[a.id] ?? 0);
      return byCount != 0 ? byCount : a.name.compareTo(b.name);
    });
  return [
    for (final category in categories)
      if ((catalog.categoryCounts[category.id] ?? 0) > 0 &&
          (normalized.isEmpty ||
              normalizeForSearch(category.name).contains(normalized)))
        _Option(
          category.id,
          category.name,
          formatCount(catalog.categoryCounts[category.id] ?? 0),
        ),
  ];
}

List<_Option> _languageOptions(Catalog catalog, String query) {
  final normalized = normalizeForSearch(query);
  final counts = <String, int>{};
  for (final channel in catalog.channels) {
    for (final code in channel.languages) {
      counts[code] = (counts[code] ?? 0) + 1;
    }
  }
  final languages = [...catalog.languages]
    ..sort((a, b) {
      final byCount = (counts[b.code] ?? 0).compareTo(counts[a.code] ?? 0);
      return byCount != 0 ? byCount : a.name.compareTo(b.name);
    });
  return [
    for (final language in languages)
      if ((counts[language.code] ?? 0) > 0 &&
          (normalized.isEmpty ||
              normalizeForSearch(language.name).contains(normalized)))
        _Option(
          language.code,
          language.name,
          formatCount(counts[language.code] ?? 0),
        ),
  ];
}

class _OptionList extends StatelessWidget {
  const _OptionList({
    required this.options,
    required this.selected,
    required this.onSelect,
    required this.query,
  });

  final List<_Option> options;
  final String? selected;
  final ValueChanged<String?> onSelect;
  final String query;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    if (options.isEmpty) {
      return EmptyState(
        icon: Icons.search_off_rounded,
        title: 'No matches',
        message: query.isEmpty
            ? 'There is nothing to filter here.'
            : 'Try a shorter search term.',
        compact: true,
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 18),
      itemCount: options.length + 1,
      itemBuilder: (context, index) {
        if (index == 0) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 7),
            child: _OptionTile(
              label: 'All options',
              trailing: '',
              selected: selected == null,
              accent: palette.primary,
              onTap: () => onSelect(null),
            ),
          );
        }
        final option = options[index - 1];
        return Padding(
          padding: const EdgeInsets.only(bottom: 5),
          child: _OptionTile(
            label: option.label,
            trailing: option.trailing,
            selected: selected == option.value,
            accent: palette.primary,
            onTap: () => onSelect(option.value),
          ),
        );
      },
    );
  }
}

class _OptionTile extends StatelessWidget {
  const _OptionTile({
    required this.label,
    required this.trailing,
    required this.selected,
    required this.accent,
    required this.onTap,
  });

  final String label;
  final String trailing;
  final bool selected;
  final Color accent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Material(
      color: selected ? accent.withValues(alpha: .09) : Colors.transparent,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: 'Manrope',
                    fontSize: 13,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                    color: selected ? accent : colors.text,
                  ),
                ),
              ),
              if (trailing.isNotEmpty)
                Text(
                  trailing,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: colors.faint,
                  ),
                ),
              const SizedBox(width: 8),
              Icon(
                selected
                    ? Icons.radio_button_checked_rounded
                    : Icons.radio_button_off_rounded,
                size: 18,
                color: selected ? accent : colors.faint,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
