import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import '../../core/widgets/app_background.dart';
import '../../state/providers.dart';
import '../browse/browse_screen.dart';
import '../favorites/library_screen.dart';
import '../home/home_screen.dart';
import '../search/search_screen.dart';
import '../settings/settings_screen.dart';

class AppShell extends ConsumerStatefulWidget {
  const AppShell({super.key});

  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<AppShell> {
  final Set<int> _visited = {0};

  @override
  Widget build(BuildContext context) {
    final tab = ref.watch(shellTabProvider);
    _visited.add(tab);
    final keyboardVisible = MediaQuery.viewInsetsOf(context).bottom > 0;

    return PopScope(
      canPop: tab == 0,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop && tab != 0) {
          FocusManager.instance.primaryFocus?.unfocus();
          ref.read(shellTabProvider.notifier).select(0);
        }
      },
      child: AppBackground(
        child: Scaffold(
          backgroundColor: Colors.transparent,
          body: Stack(
            children: [
              SafeArea(
                bottom: false,
                child: IndexedStack(
                  index: tab,
                  children: [
                    for (var index = 0; index < 5; index++)
                      KeyedSubtree(
                        key: ValueKey('tab-$index'),
                        child: _visited.contains(index)
                            ? switch (index) {
                                0 => const HomeScreen(),
                                1 => const BrowseScreen(),
                                2 => const SearchScreen(),
                                3 => const LibraryScreen(),
                                _ => const SettingsScreen(),
                              }
                            : const SizedBox.shrink(),
                      ),
                  ],
                ),
              ),
              if (!keyboardVisible) const AppDock(),
            ],
          ),
        ),
      ),
    );
  }
}

class AppDock extends ConsumerWidget {
  const AppDock({super.key});

  static const _items = [
    _DockSpec('Home', Icons.home_outlined, Icons.home_rounded),
    _DockSpec('Browse', Icons.grid_view_outlined, Icons.grid_view_rounded),
    _DockSpec('Search', Icons.search_outlined, Icons.search_rounded),
    _DockSpec('Library', Icons.bookmark_outline_rounded, Icons.bookmark_rounded),
    _DockSpec('Settings', Icons.tune_outlined, Icons.tune_rounded),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final palette = context.palette;
    final active = ref.watch(shellTabProvider);
    final bottom = MediaQuery.viewPaddingOf(context).bottom;

    return Positioned(
      left: 12,
      right: 12,
      bottom: 10 + bottom,
      child: Container(
        decoration: BoxDecoration(
          color: colors.surface.withValues(alpha: .96),
          borderRadius: BorderRadius.circular(25),
          border: Border.all(color: colors.border),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: .45),
              blurRadius: 28,
              offset: const Offset(0, 14),
            ),
            BoxShadow(
              color: palette.primary.withValues(alpha: .05),
              blurRadius: 18,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        padding: const EdgeInsets.all(6),
        child: Row(
          children: [
            for (var index = 0; index < _items.length; index++)
              Expanded(
                child: _DockItem(
                  spec: _items[index],
                  selected: active == index,
                  onTap: () {
                    FocusManager.instance.primaryFocus?.unfocus();
                    ref.read(shellTabProvider.notifier).select(index);
                    HapticFeedback.selectionClick();
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _DockSpec {
  const _DockSpec(this.label, this.icon, this.activeIcon);
  final String label;
  final IconData icon;
  final IconData activeIcon;
}

class _DockItem extends StatelessWidget {
  const _DockItem({
    required this.spec,
    required this.selected,
    required this.onTap,
  });

  final _DockSpec spec;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final colors = context.colors;
    return Semantics(
      button: true,
      selected: selected,
      label: spec.label,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(19),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.symmetric(vertical: 7),
          decoration: BoxDecoration(
            color: selected
                ? palette.primary.withValues(alpha: .11)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(19),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                selected ? spec.activeIcon : spec.icon,
                size: 21,
                color: selected ? palette.primary : colors.muted,
              ),
              const SizedBox(height: 3),
              Text(
                spec.label,
                maxLines: 1,
                overflow: TextOverflow.fade,
                style: TextStyle(
                  fontFamily: 'Manrope',
                  fontSize: 9.5,
                  height: 1.1,
                  fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                  color: selected ? palette.primary : colors.faint,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
