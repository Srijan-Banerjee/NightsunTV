import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import '../../core/utils/navigation.dart';
import '../../core/utils/text.dart';
import '../../core/widgets/channel_tiles.dart';
import '../../core/widgets/common.dart';
import '../../core/widgets/loading_view.dart';
import '../../core/widgets/pressable.dart';
import '../../data/models/channel.dart';
import '../../state/library_controller.dart';
import '../../state/providers.dart';
import '../../state/settings_controller.dart';
import '../channel/channel_detail_screen.dart';

class LibraryScreen extends ConsumerStatefulWidget {
  const LibraryScreen({super.key});

  @override
  ConsumerState<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends ConsumerState<LibraryScreen> {
  int _tab = 0;
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() => _ready = true);
    });
  }

  void _openChannel(Channel channel) {
    Navigator.of(context).push(
      smoothScreenRoute(ChannelDetailScreen(channel: channel)),
    );
  }

  void _browse() => ref.read(shellTabProvider.notifier).select(1);

  @override
  Widget build(BuildContext context) {
    final catalog = ref.watch(catalogProvider).value;
    final library = ref.watch(libraryProvider);
    final showAdult =
        ref.watch(settingsProvider.select((settings) => settings.showAdult));
    final favorites = ref.watch(favoriteChannelsProvider);
    final recents = ref.watch(recentChannelsProvider);
    final colors = context.colors;

    final visibleFavorites =
        favorites.where((channel) => showAdult || !channel.nsfw).toList();
    final visibleRecents =
        recents.where((channel) => showAdult || !channel.nsfw).toList();

    return CustomScrollView(
      physics: const AlwaysScrollableScrollPhysics(
        parent: ClampingScrollPhysics(),
      ),
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Library',
                            style: Theme.of(context)
                                .textTheme
                                .displaySmall
                                ?.copyWith(
                                  fontSize: 30,
                                  letterSpacing: -1,
                                ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            '${formatCount(visibleFavorites.length)} saved · '
                            '${formatCount(visibleRecents.length)} watched',
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w500,
                              color: colors.muted,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (_tab == 1 && visibleRecents.isNotEmpty)
                      TextButton.icon(
                        onPressed: () async {
                          final confirmed = await AppNotices.confirm(
                            context,
                            title: 'Clear watch history?',
                            message:
                                'This removes every channel from your history. '
                                'Your favourites stay untouched.',
                            confirmLabel: 'Clear history',
                            destructive: true,
                          );
                          if (confirmed && context.mounted) {
                            ref.read(libraryProvider.notifier).clearRecents();
                          }
                        },
                        icon: const Icon(Icons.delete_sweep_outlined, size: 16),
                        label: const Text('Clear'),
                        style: TextButton.styleFrom(
                          foregroundColor: colors.muted,
                          textStyle: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 18),
                _Segmented(
                  index: _tab,
                  favorites: visibleFavorites.length,
                  history: visibleRecents.length,
                  onChanged: (index) => setState(() => _tab = index),
                ),
                const SizedBox(height: 14),
              ],
            ),
          ),
        ),
        if (!_ready || catalog == null)
          const SliverFillRemaining(
            hasScrollBody: false,
            child: NightsunLoadingView(
              title: 'Accessing Library',
              subtitle: 'Loading your saved bookmarks & recents…',
              compact: true,
            ),
          )
        else if (_tab == 0)
          if (visibleFavorites.isEmpty)
            SliverFillRemaining(
              hasScrollBody: false,
              child: EmptyState(
                icon: Icons.favorite_border_rounded,
                title: 'Your shelf is empty',
                message:
                    'Tap the heart on any channel to keep it here. '
                    'Favourites are stored on this device — no account needed.',
                actionLabel: 'Find channels',
                onAction: _browse,
                compact: true,
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              sliver: SliverList.builder(
                itemCount: visibleFavorites.length,
                itemBuilder: (context, index) {
                  final channel = visibleFavorites[index];
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: ChannelRowTile(
                      channel: channel,
                      catalog: catalog,
                      isFavorite: true,
                      onFavorite: () =>
                          ref.read(libraryProvider.notifier).toggleFavorite(channel.id),
                      onTap: () => _openChannel(channel),
                      showChevron: true,
                    ),
                  );
                },
              ),
            )
        else if (visibleRecents.isEmpty)
          SliverFillRemaining(
            hasScrollBody: false,
            child: EmptyState(
              icon: Icons.history_rounded,
              title: 'No late nights yet',
              message:
                  'Channels you watch will appear here so you can jump straight '
                  'back in. History never leaves this device.',
              actionLabel: 'Start watching',
              onAction: _browse,
              compact: true,
            ),
          )
        else
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            sliver: SliverList.builder(
              itemCount: visibleRecents.length,
              itemBuilder: (context, index) {
                final channel = visibleRecents[index];
                RecentEntry? entry;
                for (final recent in library.recents) {
                  if (recent.channelId == channel.id) {
                    entry = recent;
                    break;
                  }
                }
                final country = catalog.countryOf(channel);
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: ChannelRowTile(
                    channel: channel,
                    catalog: catalog,
                    subtitle: entry == null
                        ? channelMetaLine(catalog, channel)
                        : '${country.flag} ${country.name} · '
                            '${relativeTime(entry.watchedAt)}',
                    isFavorite: library.isFavorite(channel.id),
                    onFavorite: () =>
                        ref.read(libraryProvider.notifier).toggleFavorite(channel.id),
                    onTap: () => _openChannel(channel),
                    trailing: Tooltip(
                      message: 'Remove from history',
                      child: SizedBox(
                        width: 34,
                        height: 40,
                        child: IconButton(
                          onPressed: () => ref
                              .read(libraryProvider.notifier)
                              .removeRecent(channel.id),
                          padding: EdgeInsets.zero,
                          iconSize: 17,
                          icon: Icon(
                            Icons.close_rounded,
                            color: colors.faint,
                          ),
                        ),
                      ),
                    ),
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

class _Segmented extends StatelessWidget {
  const _Segmented({
    required this.index,
    required this.favorites,
    required this.history,
    required this.onChanged,
  });

  final int index;
  final int favorites;
  final int history;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final palette = context.palette;
    Widget segment(String label, int value, IconData icon) {
      final selected = index == value;
      return Expanded(
        child: Pressable(
          onTap: () => onChanged(value),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOutCubic,
            padding: const EdgeInsets.symmetric(vertical: 10),
            decoration: BoxDecoration(
              color: selected
                  ? palette.primary.withValues(alpha: .13)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(13),
              border: Border.all(
                color: selected
                    ? palette.primary.withValues(alpha: .35)
                    : Colors.transparent,
              ),
            ),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    icon,
                    size: 16,
                    color: selected ? palette.primary : colors.muted,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    label,
                    style: TextStyle(
                      fontFamily: 'Manrope',
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: selected ? palette.primary : colors.muted,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                    decoration: BoxDecoration(
                      color: selected
                          ? palette.primary.withValues(alpha: .17)
                          : colors.surfaceAlt,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      formatCount(value == 0 ? favorites : history),
                      style: TextStyle(
                        fontSize: 8.5,
                        fontWeight: FontWeight.w800,
                        color: selected ? palette.primary : colors.faint,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: colors.surface.withValues(alpha: .7),
        borderRadius: BorderRadius.circular(17),
        border: Border.all(color: colors.border),
      ),
      child: Row(
        children: [
          segment('Favourites', 0, Icons.favorite_rounded),
          const SizedBox(width: 4),
          segment('History', 1, Icons.history_rounded),
        ],
      ),
    );
  }
}
