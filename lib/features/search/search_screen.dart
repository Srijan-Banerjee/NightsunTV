import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import '../../core/utils/navigation.dart';
import '../../core/utils/text.dart';
import '../../core/widgets/channel_tiles.dart';
import '../../core/widgets/common.dart';
import '../../core/widgets/loading_view.dart';
import '../../core/widgets/pressable.dart';
import '../../data/models/catalog.dart';
import '../../data/models/channel.dart';
import '../../data/services/search_engine.dart';
import '../../state/library_controller.dart';
import '../../state/providers.dart';
import '../channel/channel_detail_screen.dart';

class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focus = FocusNode();
  Timer? _debounce;
  String _query = '';
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() => _ready = true);
    });
  }

  static const _suggestions = [
    'news',
    'movies',
    'sports',
    'music',
    'documentary',
    'kids',
    'France',
    'India',
    'Brazil',
    'Japan',
  ];

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _onChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 150), () {
      if (!mounted) return;
      setState(() => _query = value.trim());
    });
  }

  void _submit(String value) {
    _debounce?.cancel();
    _focus.unfocus();
    setState(() => _query = value.trim());
  }

  void _applySuggestion(String value) {
    _controller.text = value;
    _controller.selection =
        TextSelection.collapsed(offset: _controller.text.length);
    _submit(value);
  }

  void _clear() {
    _debounce?.cancel();
    _controller.clear();
    setState(() => _query = '');
    _focus.requestFocus();
  }

  void _openChannel(Channel channel) {
    _focus.unfocus();
    Navigator.of(context).push(
      smoothScreenRoute(ChannelDetailScreen(channel: channel)),
    );
  }

  void _openBrowse({String? country, String? category}) {
    _focus.unfocus();
    final filters = ref.read(browseFilterProvider.notifier);
    filters.reset();
    if (country != null) filters.setCountry(country);
    if (category != null) filters.setCategory(category);
    ref.read(shellTabProvider.notifier).select(1);
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<int>(searchFocusProvider, (previous, next) {
      if (previous != next) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _focus.requestFocus();
        });
      }
    });

    final catalog = ref.watch(catalogProvider).value;
    final engine = (!_ready || catalog == null)
        ? null
        : ref.watch(searchEngineProvider);
    final library = ref.watch(libraryProvider);
    final results = _query.isEmpty || engine == null
        ? SearchResults.empty
        : engine.search(_query);
    final colors = context.colors;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    'Search',
                    style: Theme.of(context).textTheme.displaySmall?.copyWith(
                          fontSize: 30,
                          letterSpacing: -1,
                        ),
                  ),
                  const SizedBox(width: 9),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
                    decoration: BoxDecoration(
                      color: context.palette.primary.withValues(alpha: .11),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: context.palette.primary.withValues(alpha: .25),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.auto_awesome_rounded,
                          size: 10,
                          color: context.palette.primary,
                        ),
                        const SizedBox(width: 3),
                        Text(
                          'SMART',
                          style: TextStyle(
                            fontSize: 7.8,
                            fontWeight: FontWeight.w800,
                            letterSpacing: .6,
                            color: context.palette.primary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                'Names, countries, languages and genres',
                style: TextStyle(
                  fontSize: 11.5,
                  color: colors.muted,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: TextField(
            controller: _controller,
            focusNode: _focus,
            onChanged: _onChanged,
            onSubmitted: _submit,
            textInputAction: TextInputAction.search,
            autocorrect: false,
            style: const TextStyle(
              fontFamily: 'Manrope',
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
            decoration: InputDecoration(
              hintText: 'Try “BBC”, “news”, “France”…',
              prefixIcon: Icon(
                Icons.search_rounded,
                size: 21,
                color: context.palette.primary,
              ),
              suffixIcon: _controller.text.isEmpty
                  ? null
                  : IconButton(
                      tooltip: 'Clear search',
                      onPressed: _clear,
                      icon: const Icon(Icons.close_rounded, size: 19),
                    ),
            ),
          ),
        ),
        const SizedBox(height: 6),
        Expanded(
          child: (!_ready || catalog == null)
              ? const NightsunLoadingView(
                  title: 'Indexing Global Channels',
                  subtitle: 'Building search index for 10,000+ stations…',
                  compact: true,
                )
              : AnimatedSwitcher(
                  duration: const Duration(milliseconds: 180),
                  child: _query.isEmpty
                      ? _DiscoveryView(
                          key: const ValueKey('discover'),
                          catalog: catalog,
                          suggestions: _suggestions,
                          onSuggestion: _applySuggestion,
                          onBrowse: _openBrowse,
                        )
                      : _ResultsView(
                          key: ValueKey('results-$_query'),
                          results: results,
                          catalog: catalog,
                          library: library,
                          onOpenChannel: _openChannel,
                          onFavorite: (channel) => ref
                              .read(libraryProvider.notifier)
                              .toggleFavorite(channel.id),
                          onBrowse: _openBrowse,
                          onClear: _clear,
                        ),
                ),
        ),
      ],
    );
  }
}

class _DiscoveryView extends StatelessWidget {
  const _DiscoveryView({
    super.key,
    required this.catalog,
    required this.suggestions,
    required this.onSuggestion,
    required this.onBrowse,
  });

  final Catalog catalog;
  final List<String> suggestions;
  final ValueChanged<String> onSuggestion;
  final void Function({String? country, String? category}) onBrowse;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final palette = context.palette;
    final countries = catalog.topCountries(limit: 8);
    final categories = [...catalog.categories]
      ..sort((a, b) => (catalog.categoryCounts[b.id] ?? 0)
          .compareTo(catalog.categoryCounts[a.id] ?? 0));
    final topCategories = categories
        .where((category) => (catalog.categoryCounts[category.id] ?? 0) > 0)
        .take(8)
        .toList(growable: false);

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      children: [
        _Panel(
          title: 'Try a search',
          icon: Icons.bolt_rounded,
          children: [
            Wrap(
              spacing: 7,
              runSpacing: 7,
              children: [
                for (final suggestion in suggestions)
                  AppChip(
                    label: suggestion,
                    dense: true,
                    icon: Icons.search_rounded,
                    onTap: () => onSuggestion(suggestion),
                  ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 16),
        _Panel(
          title: 'Browse by country',
          icon: Icons.public_rounded,
          actionLabel: 'All',
          onAction: () => onBrowse(),
          children: [
            Column(
              children: [
                for (final country in countries)
                  _SuggestionRow(
                    leading: country.flag,
                    title: country.name,
                    trailing:
                        '${formatCount(catalog.countryCounts[country.code] ?? 0)} channels',
                    onTap: () => onBrowse(country: country.code),
                  ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 16),
        _Panel(
          title: 'Browse by genre',
          icon: Icons.category_rounded,
          children: [
            Column(
              children: [
                for (final category in topCategories)
                  _SuggestionRow(
                    leading: null,
                    icon: _iconForCategory(category.id),
                    title: category.name,
                    trailing:
                        formatCount(catalog.categoryCounts[category.id] ?? 0),
                    onTap: () => onBrowse(category: category.id),
                  ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: palette.primary.withValues(alpha: .07),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: palette.primary.withValues(alpha: .18),
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.tips_and_updates_rounded,
                  size: 18, color: palette.primary),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Search understands more than names. Try a country, a '
                  'language, a network or a genre — or combine them: '
                  '“french news”, “spanish sports”.',
                  style: TextStyle(
                    fontSize: 11.5,
                    height: 1.5,
                    color: colors.muted,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),
        const DockSpacer(),
      ],
    );
  }
}

IconData _iconForCategory(String id) => switch (id) {
      'news' => Icons.newspaper_rounded,
      'movies' => Icons.movie_rounded,
      'sports' => Icons.sports_soccer_rounded,
      'music' => Icons.graphic_eq_rounded,
      'kids' => Icons.child_care_rounded,
      'documentary' => Icons.travel_explore_rounded,
      'entertainment' => Icons.theaters_rounded,
      'education' => Icons.school_rounded,
      _ => Icons.live_tv_rounded,
    };

class _Panel extends StatelessWidget {
  const _Panel({
    required this.title,
    required this.icon,
    required this.children,
    this.actionLabel,
    this.onAction,
  });

  final String title;
  final IconData icon;
  final List<Widget> children;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final palette = context.palette;
    return Container(
      decoration: BoxDecoration(
        color: colors.surface.withValues(alpha: .6),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: colors.border),
      ),
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 15, color: palette.primary),
              const SizedBox(width: 7),
              Text(
                title,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1,
                  color: colors.muted,
                ),
              ),
              const Spacer(),
              if (actionLabel != null && onAction != null)
                Pressable(
                  onTap: onAction!,
                  child: Text(
                    actionLabel!,
                    style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w700,
                      color: palette.primary,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 11),
          ...children,
        ],
      ),
    );
  }
}

class _SuggestionRow extends StatelessWidget {
  const _SuggestionRow({
    required this.title,
    required this.trailing,
    required this.onTap,
    this.leading,
    this.icon,
  });

  final String title;
  final String trailing;
  final VoidCallback onTap;
  final String? leading;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 7, horizontal: 4),
          child: Row(
            children: [
              if (leading != null)
                SizedBox(
                  width: 26,
                  child: Text(
                    leading!,
                    style: const TextStyle(fontSize: 16),
                  ),
                )
              else
                SizedBox(
                  width: 26,
                  child: Icon(icon ?? Icons.live_tv_rounded,
                      size: 16, color: colors.muted),
                ),
              const SizedBox(width: 7),
              Expanded(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: colors.text,
                  ),
                ),
              ),
              Text(
                trailing,
                style: TextStyle(
                  fontSize: 9.5,
                  fontWeight: FontWeight.w500,
                  color: colors.faint,
                ),
              ),
              Icon(Icons.chevron_right_rounded, size: 16, color: colors.faint),
            ],
          ),
        ),
      ),
    );
  }
}

class _ResultsView extends StatelessWidget {
  const _ResultsView({
    super.key,
    required this.results,
    required this.catalog,
    required this.library,
    required this.onOpenChannel,
    required this.onFavorite,
    required this.onBrowse,
    required this.onClear,
  });

  final SearchResults results;
  final Catalog catalog;
  final LibraryState library;
  final ValueChanged<Channel> onOpenChannel;
  final ValueChanged<Channel> onFavorite;
  final void Function({String? country, String? category}) onBrowse;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final palette = context.palette;

    if (results.isEmpty) {
      return ListView(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        children: [
          EmptyState(
            icon: Icons.search_off_rounded,
            title: 'No signal found',
            message:
                'Nothing matched “${results.query}”. Try a shorter name, a '
                'country, or one of the genres.',
            actionLabel: 'Clear search',
            onAction: onClear,
            compact: true,
          ),
          const DockSpacer(),
        ],
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 6, 20, 0),
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      children: [
        if (results.countries.isNotEmpty) ...[
          _ResultLabel(label: 'COUNTRIES'),
          const SizedBox(height: 7),
          Wrap(
            spacing: 7,
            runSpacing: 7,
            children: [
              for (final country in results.countries)
                AppChip(
                  label: '${country.flag}  ${country.name}',
                  dense: true,
                  selected: true,
                  icon: Icons.public_rounded,
                  onTap: () => onBrowse(country: country.code),
                ),
            ],
          ),
          const SizedBox(height: 14),
        ],
        if (results.categories.isNotEmpty) ...[
          _ResultLabel(label: 'GENRES'),
          const SizedBox(height: 7),
          Wrap(
            spacing: 7,
            runSpacing: 7,
            children: [
              for (final category in results.categories)
                AppChip(
                  label: category.name,
                  dense: true,
                  selected: true,
                  icon: _iconForCategory(category.id),
                  onTap: () => onBrowse(category: category.id),
                ),
            ],
          ),
          const SizedBox(height: 14),
        ],
        Row(
          children: [
            _ResultLabel(
              label: results.channels.isEmpty
                  ? 'NO CHANNELS'
                  : 'CHANNELS',
            ),
            const Spacer(),
            Text(
              results.truncated
                  ? 'Top ${results.channels.length} of ${formatCount(results.totalMatches)}'
                  : '${formatCount(results.totalMatches)} found',
              style: TextStyle(
                fontSize: 9.5,
                fontWeight: FontWeight.w600,
                color: colors.faint,
              ),
            ),
          ],
        ),
        const SizedBox(height: 9),
        if (results.channels.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Text(
              'Genres and countries above can still take you somewhere.',
              style: TextStyle(
                fontSize: 11.5,
                color: colors.muted,
                height: 1.5,
              ),
            ),
          )
        else
          for (final channel in results.channels)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: ChannelRowTile(
                channel: channel,
                catalog: catalog,
                dense: true,
                isFavorite: library.isFavorite(channel.id),
                onFavorite: () => onFavorite(channel),
                onTap: () => onOpenChannel(channel),
                showChevron: true,
              ),
            ),
        if (results.truncated)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.filter_alt_rounded, size: 14, color: palette.primary),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    'Top ${results.channels.length} shown. Add a country or '
                    'genre above to narrow things down.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 10,
                      height: 1.4,
                      color: colors.faint,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
        const DockSpacer(),
      ],
    );
  }
}

class _ResultLabel extends StatelessWidget {
  const _ResultLabel({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: TextStyle(
        fontSize: 9,
        fontWeight: FontWeight.w800,
        letterSpacing: 1.2,
        color: context.colors.faint,
      ),
    );
  }
}
