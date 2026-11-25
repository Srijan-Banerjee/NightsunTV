import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/theme/app_theme.dart';
import '../../core/utils/text.dart';
import '../../core/widgets/common.dart';
import '../../core/widgets/pressable.dart';
import '../../core/widgets/star_field.dart';
import '../../data/services/lineup_refresh_service.dart';
import '../../state/providers.dart';
import '../../state/settings_controller.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final catalog = ref.watch(catalogProvider).value;
    final refreshInfo = ref.watch(refreshInfoProvider).value;
    final colors = context.colors;
    final notifier = ref.read(settingsProvider.notifier);

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Settings',
                      style: Theme.of(context).textTheme.displaySmall?.copyWith(
                            fontSize: 30,
                            letterSpacing: -1,
                          ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'Make the night yours',
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w500,
                        color: colors.muted,
                      ),
                    ),
                  ],
                ),
              ),
              const BrandMark(size: 42, radius: 12),
            ],
          ),
        ),
        const SizedBox(height: 20),
        _Section(
          title: 'Appearance',
          icon: Icons.palette_rounded,
          children: [
            Row(
              children: [
                for (final variant in ThemeVariant.values) ...[
                  Expanded(
                    child: _ThemePreview(
                      variant: variant,
                      accent: settings.accent,
                      selected: settings.themeVariant == variant,
                      onTap: () => notifier.setTheme(variant),
                    ),
                  ),
                  if (variant != ThemeVariant.values.last)
                    const SizedBox(width: 9),
                ],
              ],
            ),
            const SizedBox(height: 17),
            Text(
              'ACCENT',
              style: TextStyle(
                fontSize: 8.5,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.2,
                color: colors.faint,
              ),
            ),
            const SizedBox(height: 9),
            Row(
              children: [
                for (final accent in AccentChoice.values) ...[
                  Expanded(
                    child: _AccentSwatch(
                      accent: accent,
                      selected: settings.accent == accent,
                      onTap: () => notifier.setAccent(accent),
                    ),
                  ),
                  if (accent != AccentChoice.values.last)
                    const SizedBox(width: 8),
                ],
              ],
            ),
            const SizedBox(height: 10),
            Text(
              'Only dark themes. No bright white screens at 2 a.m.',
              style: TextStyle(
                fontSize: 10,
                height: 1.4,
                color: colors.faint,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        _Section(
          title: 'Playback',
          icon: Icons.play_circle_outline_rounded,
          children: [
            _Toggle(
              title: 'Start playing immediately',
              subtitle: 'Open a channel straight into the stream.',
              value: settings.autoplay,
              onChanged: notifier.setAutoplay,
            ),
            _Toggle(
              title: 'Automatic backup sources',
              subtitle:
                  'If a stream fails, try the next mirror without asking.',
              value: settings.autoFallback,
              onChanged: notifier.setAutoFallback,
            ),
            _Toggle(
              title: 'Prefer highest quality',
              subtitle:
                  'Start with the best resolution the channel lists. Higher '
                  'quality uses more data.',
              value: settings.preferHighestQuality,
              onChanged: notifier.setPreferHighestQuality,
            ),
            _Toggle(
              title: 'Keep the screen awake',
              subtitle: 'Stop the phone sleeping while a channel is playing.',
              value: settings.keepScreenOn,
              onChanged: notifier.setKeepScreenOn,
            ),
            _Toggle(
              title: 'Haptic feedback',
              subtitle: 'A small tap response on buttons and favourites.',
              value: settings.haptics,
              onChanged: notifier.setHaptics,
              isLast: true,
            ),
          ],
        ),
        const SizedBox(height: 12),
        _Section(
          title: 'Channel lineup',
          icon: Icons.satellite_alt_rounded,
          children: [
            Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: context.palette.primary.withValues(alpha: .1),
                    borderRadius: BorderRadius.circular(11),
                  ),
                  child: Icon(
                    Icons.dns_outlined,
                    size: 18,
                    color: context.palette.primary,
                  ),
                ),
                const SizedBox(width: 11),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        refreshInfo == null
                            ? 'Bundled snapshot'
                            : 'Lineup refreshed',
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        catalog == null
                            ? 'Reading the built-in catalog…'
                            : '${formatCount(catalog.channels.length)} channels · '
                                '${formatCount(catalog.sourceCount)} streams'
                                '${refreshInfo == null ? '' : ' · ${formatDate(refreshInfo.fetchedAt)}'}',
                        style: TextStyle(
                          fontSize: 10,
                          color: colors.faint,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 13),
            PrimaryButton(
              label: 'Refresh lineup',
              icon: Icons.sync_rounded,
              height: 46,
              onTap: catalog == null
                  ? null
                  : () => showLineupRefreshSheet(context),
            ),
            if (refreshInfo != null) ...[
              const SizedBox(height: 8),
              Pressable(
                onTap: () async {
                  final ok = await AppNotices.confirm(
                    context,
                    title: 'Restore bundled lineup?',
                    message:
                        'The refreshed stream list will be removed and the '
                        'catalog that shipped with this app version will be '
                        'used again.',
                    confirmLabel: 'Restore',
                  );
                  if (!ok || !context.mounted) return;
                  await ref
                      .read(catalogRepositoryProvider)
                      .restoreBundledLineup();
                  ref.invalidate(catalogProvider);
                  ref.invalidate(refreshInfoProvider);
                  if (context.mounted) {
                    AppNotices.show(context, 'Bundled lineup restored.',
                        icon: Icons.restore_rounded);
                  }
                },
                child: Container(
                  height: 42,
                  alignment: Alignment.center,
                  child: Text(
                    'Restore bundled lineup',
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                      color: colors.muted,
                    ),
                  ),
                ),
              ),
            ],
            const SizedBox(height: 10),
            Text(
              'A refresh downloads the current public iptv-org playlist and '
              'keeps only channels already in the catalog. Streams are '
              'third-party, so some may still be offline or geo-blocked. '
              'Your current lineup is kept if anything goes wrong.',
              style: TextStyle(
                fontSize: 9.8,
                height: 1.5,
                color: colors.faint,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        _Section(
          title: 'About',
          icon: Icons.nights_stay_rounded,
          children: [
            _LinkRow(
              icon: Icons.info_outline_rounded,
              label: 'How NightsunTV works',
              onTap: () => _showHowItWorks(context),
            ),
            _LinkRow(
              icon: Icons.code_rounded,
              label: 'iptv-org on GitHub',
              onTap: () => _openUrl(
                context,
                'https://github.com/iptv-org/iptv',
              ),
              trailingIcon: Icons.open_in_new_rounded,
            ),
            _LinkRow(
              icon: Icons.description_outlined,
              label: 'Open-source licenses',
              onTap: () => showLicensePage(
                context: context,
                applicationName: 'NightsunTV',
                applicationLegalese:
                    'Free live TV, built on the public iptv-org catalog. '
                    'NightsunTV does not host or retransmit any stream.',
              ),
            ),
            _LinkRow(
              icon: Icons.ios_share_rounded,
              label: 'Share NightsunTV',
              onTap: () => SharePlus.instance.share(
                ShareParams(
                  text: 'NightsunTV — thousands of free live TV channels, '
                      'no account, no ads, no limits. '
                      'Built on the public iptv-org catalog.',
                  subject: 'NightsunTV',
                ),
              ),
              isLast: true,
            ),
            const SizedBox(height: 12),
            FutureBuilder<PackageInfo>(
              future: PackageInfo.fromPlatform(),
              builder: (context, snapshot) {
                final info = snapshot.data;
                return Row(
                  children: [
                    const BrandMark(size: 30, radius: 9),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        info == null
                            ? 'NightsunTV'
                            : 'NightsunTV v${info.version} (${info.buildNumber})',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: colors.faint,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        'Made for late nights',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.right,
                        style: TextStyle(
                          fontSize: 9.5,
                          fontWeight: FontWeight.w500,
                          color: colors.faint,
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ],
        ),
        const SizedBox(height: 18),
        Center(
          child: Text(
            'No accounts. No ads. No watch limits.\n'
            'Free, publicly listed streams from iptv-org.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 9.5,
              height: 1.6,
              color: colors.faint,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        const DockSpacer(),
      ],
    );
  }

  void _showHowItWorks(BuildContext context) {
    final colors = context.colors;
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) => Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * .8,
        ),
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          border: Border.all(color: colors.border),
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(22, 12, 22, 26),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 18),
                  decoration: BoxDecoration(
                    color: colors.borderStrong,
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
              ),
              Row(
                children: [
                  Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        colors: context.palette.gradient,
                      ),
                    ),
                    child: Icon(
                      Icons.nights_stay_rounded,
                      size: 23,
                      color: context.palette.onPrimary,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'How NightsunTV works',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              for (final item in const [
                (
                  Icons.public_rounded,
                  'The catalog',
                  'Channel names, logos, countries, languages and stream URLs '
                      'come from the free, open iptv-org project. The app ships '
                      'with a snapshot so it works offline for browsing.',
                ),
                (
                  Icons.play_arrow_rounded,
                  'The streams',
                  'Playback goes directly from the broadcaster or host to your '
                      'phone. NightsunTV is not a video host and does not '
                      'retransmit or record any channel.',
                ),
                (
                  Icons.swap_horiz_rounded,
                  'Backup sources',
                  'Many channels list several public mirrors. If one fails, the '
                      'player tries the next — you can also pick a source '
                      'manually on the channel page.',
                ),
                (
                  Icons.lock_open_rounded,
                  'No accounts, no limits',
                  'There is no sign-up, no subscription, no advertising, no '
                      'trial and no cap on channels or watch time. Favourites '
                      'and history stay on your device.',
                ),
                (
                  Icons.cloud_off_rounded,
                  'Honest about downtime',
                  'These are third-party public streams. Some channels will be '
                      'offline, moved or blocked in your region; that is outside '
                      'NightsunTV’s control.',
                ),
              ]) ...[
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                        color: context.palette.primary.withValues(alpha: .09),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(item.$1,
                          size: 17, color: context.palette.primary),
                    ),
                    const SizedBox(width: 11),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.$2,
                            style: Theme.of(context)
                                .textTheme
                                .titleSmall
                                ?.copyWith(fontSize: 13),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            item.$3,
                            style: TextStyle(
                              fontSize: 11.5,
                              height: 1.55,
                              color: colors.muted,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
              ],
              SecondaryButton(
                label: 'Close',
                expand: true,
                onTap: () => Navigator.of(context).pop(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _openUrl(BuildContext context, String url) async {
    final ok = await launchUrl(
      Uri.parse(url),
      mode: LaunchMode.externalApplication,
    );
    if (!ok && context.mounted) {
      AppNotices.show(context, 'Could not open the link.');
    }
  }
}

class _Section extends StatelessWidget {
  const _Section({
    required this.title,
    required this.icon,
    required this.children,
  });

  final String title;
  final IconData icon;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Container(
      decoration: BoxDecoration(
        color: colors.surface.withValues(alpha: .62),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: colors.border),
      ),
      padding: const EdgeInsets.fromLTRB(14, 13, 14, 13),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 15, color: colors.faint),
              const SizedBox(width: 7),
              Text(
                title.toUpperCase(),
                style: TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.2,
                  color: colors.faint,
                ),
              ),
            ],
          ),
          const SizedBox(height: 13),
          ...children,
        ],
      ),
    );
  }
}

class _ThemePreview extends StatelessWidget {
  const _ThemePreview({
    required this.variant,
    required this.accent,
    required this.selected,
    required this.onTap,
  });

  final ThemeVariant variant;
  final AccentChoice accent;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.forVariant(variant);
    final palette = AppPalette.forChoice(accent);
    return Pressable(
      onTap: onTap,
      scale: .975,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(9),
        decoration: BoxDecoration(
          color: colors.background,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected ? palette.primary : colors.borderStrong,
            width: selected ? 1.5 : 1,
          ),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: palette.primary.withValues(alpha: .13),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  ),
                ]
              : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              height: 44,
              decoration: BoxDecoration(
                color: colors.surface,
                borderRadius: BorderRadius.circular(9),
                border: Border.all(color: colors.border),
              ),
              padding: const EdgeInsets.all(7),
              child: Row(
                children: [
                  Container(
                    width: 17,
                    height: 17,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(colors: palette.gradient),
                      borderRadius: BorderRadius.circular(5),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          height: 3.5,
                          width: double.infinity,
                          decoration: BoxDecoration(
                            color: colors.text.withValues(alpha: .75),
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Container(
                          height: 3,
                          width: 28,
                          decoration: BoxDecoration(
                            color: colors.faint.withValues(alpha: .6),
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Text(
                  variant.label,
                  style: TextStyle(
                    fontFamily: 'Manrope',
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                    color: colors.text,
                  ),
                ),
                const Spacer(),
                Icon(
                  selected
                      ? Icons.check_circle_rounded
                      : Icons.circle_outlined,
                  size: 14,
                  color: selected ? palette.primary : colors.faint,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _AccentSwatch extends StatelessWidget {
  const _AccentSwatch({
    required this.accent,
    required this.selected,
    required this.onTap,
  });

  final AccentChoice accent;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.forChoice(accent);
    final colors = context.colors;
    return Pressable(
      onTap: onTap,
      scale: .94,
      child: Column(
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            height: 42,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: palette.gradient,
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(13),
              border: Border.all(
                color: selected ? Colors.white.withValues(alpha: .8) : colors.border,
                width: selected ? 2 : 1,
              ),
              boxShadow: selected
                  ? [
                      BoxShadow(
                        color: palette.primary.withValues(alpha: .3),
                        blurRadius: 14,
                        offset: const Offset(0, 5),
                      ),
                    ]
                  : null,
            ),
            child: selected
                ? Icon(Icons.check_rounded,
                    size: 18, color: palette.onPrimary)
                : null,
          ),
          const SizedBox(height: 6),
          Text(
            palette.name,
            style: TextStyle(
              fontSize: 9,
              fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
              color: selected ? palette.primary : colors.faint,
            ),
          ),
        ],
      ),
    );
  }
}

class _Toggle extends StatelessWidget {
  const _Toggle({
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
    this.isLast = false,
  });

  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Column(
      children: [
        InkWell(
          onTap: () => onChanged(!value),
          borderRadius: BorderRadius.circular(10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: colors.text,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 10,
                        height: 1.4,
                        fontWeight: FontWeight.w500,
                        color: colors.faint,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Switch(
                value: value,
                onChanged: onChanged,
              ),
            ],
          ),
        ),
        if (!isLast) ...[
          const SizedBox(height: 11),
          Divider(color: colors.border, height: 1),
          const SizedBox(height: 11),
        ],
      ],
    );
  }
}

class _LinkRow extends StatelessWidget {
  const _LinkRow({
    required this.icon,
    required this.label,
    required this.onTap,
    this.trailingIcon,
    this.isLast = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final IconData? trailingIcon;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Column(
      children: [
        Pressable(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              children: [
                Icon(icon, size: 17, color: colors.muted),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    label,
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: colors.text,
                    ),
                  ),
                ),
                Icon(
                  trailingIcon ?? Icons.chevron_right_rounded,
                  size: 16,
                  color: colors.faint,
                ),
              ],
            ),
          ),
        ),
        if (!isLast) ...[
          Divider(color: colors.border, height: 1),
        ],
      ],
    );
  }
}

/// Opens the lineup refresh flow. The sheet starts idle so the user can read
/// what will happen; the download only begins when they ask for it.
Future<void> showLineupRefreshSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    isDismissible: false,
    enableDrag: false,
    builder: (_) => const _LineupRefreshSheet(),
  );
}

enum _RefreshPhase { idle, running, success, failure, canceled }

class _LineupRefreshSheet extends ConsumerStatefulWidget {
  const _LineupRefreshSheet();

  @override
  ConsumerState<_LineupRefreshSheet> createState() =>
      _LineupRefreshSheetState();
}

class _LineupRefreshSheetState extends ConsumerState<_LineupRefreshSheet> {
  _RefreshPhase _phase = _RefreshPhase.idle;
  LineupCancellationToken? _token;
  RefreshProgress? _progress;
  String? _error;
  LineupRefreshResult? _result;
  bool _cancelRequested = false;

  @override
  void dispose() {
    _token?.cancel();
    super.dispose();
  }

  Future<void> _start() async {
    final catalog = ref.read(catalogProvider).value;
    if (catalog == null) {
      setState(() {
        _phase = _RefreshPhase.failure;
        _error = 'The channel catalog is still loading. Try again in a moment.';
      });
      return;
    }
    final token = LineupCancellationToken();
    setState(() {
      _phase = _RefreshPhase.running;
      _token = token;
      _cancelRequested = false;
      _error = null;
      _result = null;
      _progress = const RefreshProgress(
        phase: RefreshPhase.downloading,
        message: 'Contacting iptv-org…',
      );
    });

    try {
      final result = await ref
          .read(catalogRepositoryProvider)
          .refreshLineup(
            knownChannelIds: catalog.byId.keys.toSet(),
            cancelToken: token,
            onProgress: (progress) {
              if (!mounted) return;
              setState(() => _progress = progress);
            },
          );
      if (!mounted) return;
      ref.invalidate(catalogProvider);
      ref.invalidate(refreshInfoProvider);
      setState(() {
        _phase = _RefreshPhase.success;
        _result = result;
      });
    } on LineupRefreshCanceled {
      if (!mounted) return;
      setState(() => _phase = _RefreshPhase.canceled);
    } catch (error) {
      if (!mounted) return;
      if (token.isCancelled) {
        setState(() => _phase = _RefreshPhase.canceled);
        return;
      }
      setState(() {
        _phase = _RefreshPhase.failure;
        _error = readableException(error);
      });
    }
  }

  void _cancel() {
    if (_phase != _RefreshPhase.running) {
      Navigator.of(context).pop();
      return;
    }
    setState(() => _cancelRequested = true);
    _token?.cancel();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final palette = context.palette;
    final running = _phase == _RefreshPhase.running;

    return Container(
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        border: Border.all(color: colors.border),
      ),
      padding: EdgeInsets.fromLTRB(
        24,
        12,
        24,
        22 + MediaQuery.paddingOf(context).bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 36,
            height: 4,
            decoration: BoxDecoration(
              color: colors.borderStrong,
              borderRadius: BorderRadius.circular(99),
            ),
          ),
          const SizedBox(height: 20),
          _icon(),
          const SizedBox(height: 15),
          Text(
            _title(),
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 8),
          Text(
            _message(),
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12,
              height: 1.55,
              color: colors.muted,
              fontWeight: FontWeight.w500,
            ),
          ),
          if (running) ...[
            const SizedBox(height: 20),
            ClipRRect(
              borderRadius: BorderRadius.circular(99),
              child: LinearProgressIndicator(
                value: _progress?.fraction,
                minHeight: 5,
                backgroundColor: colors.surfaceAlt,
                valueColor: AlwaysStoppedAnimation(palette.primary),
              ),
            ),
            const SizedBox(height: 9),
            Text(
              _progress?.message ?? 'Working…',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: colors.faint,
              ),
            ),
          ],
          if (_phase == _RefreshPhase.success && _result != null) ...[
            const SizedBox(height: 17),
            Container(
              padding: const EdgeInsets.all(13),
              decoration: BoxDecoration(
                color: colors.success.withValues(alpha: .07),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: colors.success.withValues(alpha: .2),
                ),
              ),
              child: Column(
                children: [
                  _stat(
                    'Channels updated',
                    formatCount(_result!.info.matchedChannels),
                  ),
                  const SizedBox(height: 8),
                  _stat(
                    'Streams loaded',
                    formatCount(_result!.info.sourceCount),
                  ),
                  if (_result!.newChannels > 0) ...[
                    const SizedBox(height: 8),
                    _stat(
                      'New in the public playlist',
                      '${formatCount(_result!.newChannels)} (arrives with an app update)',
                    ),
                  ],
                ],
              ),
            ),
          ],
          if (_phase == _RefreshPhase.failure && _error != null) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: colors.error.withValues(alpha: .07),
                borderRadius: BorderRadius.circular(13),
                border: Border.all(
                  color: colors.error.withValues(alpha: .2),
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.error_outline_rounded,
                      size: 16, color: colors.error),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _error!,
                      style: TextStyle(
                        fontSize: 10.5,
                        height: 1.5,
                        color: colors.muted,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 22),
          if (_phase == _RefreshPhase.idle) ...[
            PrimaryButton(
              label: 'Refresh from iptv-org',
              icon: Icons.cloud_download_rounded,
              onTap: _start,
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(
                'Not now',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: colors.muted,
                ),
              ),
            ),
          ] else if (running) ...[
            SecondaryButton(
              label: _cancelRequested ? 'Cancelling…' : 'Cancel',
              expand: true,
              icon: Icons.close_rounded,
              onTap: _cancelRequested ? null : _cancel,
            ),
          ] else ...[
            PrimaryButton(
              label: 'Done',
              icon: Icons.check_rounded,
              onTap: () => Navigator.of(context).pop(),
            ),
            if (_phase == _RefreshPhase.failure ||
                _phase == _RefreshPhase.canceled) ...[
              const SizedBox(height: 8),
              TextButton(
                onPressed: _start,
                child: Text(
                  'Try again',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: palette.primary,
                  ),
                ),
              ),
            ],
          ],
          const SizedBox(height: 4),
        ],
      ),
    );
  }

  Widget _icon() {
    final colors = context.colors;
    final palette = context.palette;
    final (icon, color) = switch (_phase) {
      _RefreshPhase.success => (Icons.check_rounded, colors.success),
      _RefreshPhase.failure => (Icons.cloud_off_rounded, colors.error),
      _RefreshPhase.canceled => (Icons.pause_rounded, colors.muted),
      _RefreshPhase.running => (Icons.sync_rounded, palette.primary),
      _RefreshPhase.idle => (Icons.cloud_download_rounded, palette.primary),
    };
    return Stack(
      alignment: Alignment.center,
      children: [
        Container(
          width: 76,
          height: 76,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: color.withValues(alpha: .08),
            border: Border.all(color: color.withValues(alpha: .2)),
          ),
        ),
        if (_phase == _RefreshPhase.idle || _phase == _RefreshPhase.running)
          const SizedBox(
            width: 76,
            height: 76,
            child: StarField(count: 12, seed: 9, color: Colors.white),
          ),
        Icon(icon, size: 33, color: color),
      ],
    );
  }

  String _title() => switch (_phase) {
        _RefreshPhase.idle => 'Refresh the lineup',
        _RefreshPhase.running => _cancelRequested ? 'Stopping…' : 'Updating channels',
        _RefreshPhase.success => 'Lineup refreshed',
        _RefreshPhase.failure => 'Refresh did not finish',
        _RefreshPhase.canceled => 'Refresh canceled',
      };

  String _message() => switch (_phase) {
        _RefreshPhase.idle =>
          'Downloads the latest public iptv-org playlist and updates stream '
              'mirrors for channels already in NightsunTV. Logos and metadata '
              'stay bundled. Your current lineup is kept if anything fails.',
        _RefreshPhase.running =>
          'Keep the app open while the playlist downloads and is verified. '
              'You can cancel at any time — the previous lineup stays intact.',
        _RefreshPhase.success =>
          'Your lineup now uses the newest available mirrors. '
              'You can restore the bundled lineup at any time in Settings.',
        _RefreshPhase.failure =>
          'Your existing lineup was not changed. Check your connection and '
              'try again when you are online.',
        _RefreshPhase.canceled =>
          'Nothing was changed. Your current lineup is still in place.',
      };

  Widget _stat(String label, String value) {
    final colors = context.colors;
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w500,
              color: colors.muted,
            ),
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 10.5,
            fontWeight: FontWeight.w800,
            color: colors.text,
          ),
        ),
      ],
    );
  }
}
