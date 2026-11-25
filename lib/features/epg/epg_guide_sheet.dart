import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import '../../core/widgets/channel_logo.dart';
import '../../core/widgets/pressable.dart';
import '../../data/models/channel.dart';
import '../../data/models/epg_program.dart';
import '../../state/providers.dart';

/// Opens the 24-hour Electronic Program Guide (EPG) modal sheet for [channel].
Future<void> showEpgGuideSheet(
  BuildContext context, {
  required Channel channel,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => _EpgSheetContent(channel: channel),
  );
}

class _EpgSheetContent extends ConsumerStatefulWidget {
  const _EpgSheetContent({required this.channel});

  final Channel channel;

  @override
  ConsumerState<_EpgSheetContent> createState() => _EpgSheetContentState();
}

class _EpgSheetContentState extends ConsumerState<_EpgSheetContent> {
  final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final palette = context.palette;
    final theme = Theme.of(context);
    final schedule = ref.watch(channelScheduleProvider(widget.channel));
    final now = DateTime.now();

    final maxHeight = MediaQuery.sizeOf(context).height * 0.85;

    return Container(
      constraints: BoxConstraints(maxHeight: maxHeight),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        border: Border.all(color: colors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.6),
            blurRadius: 36,
            offset: const Offset(0, -10),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 12, bottom: 8),
              width: 38,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.25),
                borderRadius: BorderRadius.circular(99),
              ),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 4, 18, 12),
            child: Row(
              children: [
                ChannelLogo(
                  channel: widget.channel,
                  width: 38,
                  height: 38,
                  radius: 10,
                  padding: 4,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              widget.channel.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: palette.primary.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                color: palette.primary.withValues(alpha: 0.35),
                              ),
                            ),
                            child: Text(
                              'EPG GUIDE',
                              style: TextStyle(
                                fontSize: 8.5,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.6,
                                color: palette.primary,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '24-Hour Broadcast Schedule · Today',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w500,
                          color: colors.muted,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded, size: 20),
                  color: colors.muted,
                  tooltip: 'Close guide',
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
          ),

          const Divider(height: 1, thickness: 1),

          // Schedule list
          if (!schedule.hasRealPrograms)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 36),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.event_busy_rounded,
                    size: 48,
                    color: colors.muted,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'No Guide Data Available',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'This live stream does not carry an electronic broadcast guide. Streaming live broadcast directly.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 12,
                      color: colors.muted,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            )
          else
            Flexible(
              child: ListView.separated(
                controller: _scrollController,
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                itemCount: schedule.programs.length,
                separatorBuilder: (_, _) => const SizedBox(height: 8),
                itemBuilder: (context, index) {
                  final program = schedule.programs[index];
                  final isLive = program.isLive(now);
                  final isPast = program.isPast(now);

                  return _ProgramGuideRow(
                    program: program,
                    isLive: isLive,
                    isPast: isPast,
                    now: now,
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}

class _ProgramGuideRow extends StatelessWidget {
  const _ProgramGuideRow({
    required this.program,
    required this.isLive,
    required this.isPast,
    required this.now,
  });

  final EpgProgram program;
  final bool isLive;
  final bool isPast;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final palette = context.palette;
    final theme = Theme.of(context);

    return Container(
      decoration: BoxDecoration(
        color: isLive
            ? palette.primary.withValues(alpha: 0.12)
            : (isPast
                ? colors.background.withValues(alpha: 0.4)
                : colors.elevated.withValues(alpha: 0.4)),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isLive
              ? palette.primary.withValues(alpha: 0.45)
              : (isPast
                  ? Colors.white.withValues(alpha: 0.05)
                  : colors.border),
          width: isLive ? 1.5 : 1,
        ),
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Time badge (only shown if not empty / verified)
              if (program.timeRange.isNotEmpty) ...[
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                  decoration: BoxDecoration(
                    color: isLive
                        ? palette.primary.withValues(alpha: 0.25)
                        : Colors.white.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    program.timeRange,
                    style: TextStyle(
                      fontFamily: 'Manrope',
                      fontSize: 9.5,
                      fontWeight: FontWeight.w700,
                      color: isLive
                          ? Colors.white
                          : (isPast ? colors.faint : colors.muted),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
              ],

              // Category tag
              Flexible(
                child: Text(
                  program.category,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w600,
                    color: isLive ? palette.secondary : colors.faint,
                  ),
                ),
              ),

              if (program.rating != null) ...[
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
                  ),
                  child: Text(
                    program.rating!,
                    style: TextStyle(
                      fontSize: 8,
                      fontWeight: FontWeight.w600,
                      color: colors.faint,
                    ),
                  ),
                ),
              ],

              const Spacer(),

              // Live or duration status
              if (isLive)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: colors.success,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: colors.success.withValues(alpha: 0.7),
                            blurRadius: 6,
                          ),
                        ],
                      ),
                    ),
                    if (program.remainingLabel(now).isNotEmpty) ...[
                      const SizedBox(width: 5),
                      Text(
                        program.remainingLabel(now).toUpperCase(),
                        style: TextStyle(
                          fontSize: 8.5,
                          fontWeight: FontWeight.w800,
                          color: colors.success,
                        ),
                      ),
                    ],
                  ],
                )
              else if (isPast)
                Text(
                  'COMPLETED',
                  style: TextStyle(
                    fontSize: 8,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.5,
                    color: colors.faint,
                  ),
                )
              else if (program.durationLabel.isNotEmpty)
                Text(
                  program.durationLabel,
                  style: TextStyle(
                    fontSize: 8.5,
                    fontWeight: FontWeight.w600,
                    color: colors.faint,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 7),

          // Title
          Text(
            program.title,
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w700,
              color: isLive
                  ? Colors.white
                  : (isPast ? colors.muted : Colors.white),
            ),
          ),

          if (program.description.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              program.description,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 9.5,
                height: 1.4,
                color: isLive
                    ? colors.muted
                    : (isPast ? colors.faint : colors.muted),
              ),
            ),
          ],

          // Progress bar if live
          if (isLive) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(99),
                    child: LinearProgressIndicator(
                      value: program.progress(now),
                      minHeight: 4,
                      backgroundColor: Colors.white.withValues(alpha: 0.12),
                      valueColor: AlwaysStoppedAnimation(palette.primary),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  '${(program.progress(now) * 100).round()}%',
                  style: TextStyle(
                    fontSize: 8.5,
                    fontWeight: FontWeight.w700,
                    color: palette.primary,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

/// A featured "On Air Now" card widget used in ChannelDetailScreen.
class EpgNowPlayingCard extends ConsumerWidget {
  const EpgNowPlayingCard({
    super.key,
    required this.channel,
    this.onViewGuide,
  });

  final Channel channel;
  final VoidCallback? onViewGuide;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final palette = context.palette;
    final theme = Theme.of(context);
    final schedule = ref.watch(channelScheduleProvider(channel));
    final current = schedule.currentProgram();
    final next = schedule.nextProgram();
    final now = DateTime.now();

    if (current == null || current.isEstimated) {
      return const SizedBox.shrink();
    }

    final progress = current.progress(now);

    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color.lerp(colors.surface, palette.primary, 0.12)!,
            colors.surface,
            Color.lerp(colors.surface, palette.secondary, 0.05)!,
          ],
        ),
        border: Border.all(
          color: palette.primary.withValues(alpha: 0.3),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.25),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top live badge & time slot
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3.5),
                decoration: BoxDecoration(
                  color: colors.success.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: colors.success.withValues(alpha: 0.4)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 5,
                      height: 5,
                      decoration: BoxDecoration(
                        color: colors.success,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: colors.success.withValues(alpha: 0.7),
                            blurRadius: 4,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 5),
                    Text(
                      'ON AIR NOW',
                      style: TextStyle(
                        fontSize: 8,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.6,
                        color: colors.success,
                      ),
                    ),
                  ],
                ),
              ),
              if (current.timeRange.isNotEmpty) ...[
                const SizedBox(width: 6),
                Flexible(
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 3.5),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      current.timeRange,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontFamily: 'Manrope',
                        fontSize: 8.5,
                        fontWeight: FontWeight.w700,
                        color: colors.muted,
                      ),
                    ),
                  ),
                ),
              ],
              if (current.remainingLabel(now).isNotEmpty) ...[
                const SizedBox(width: 6),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 3.5),
                  decoration: BoxDecoration(
                    color: palette.primary.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    current.remainingLabel(now),
                    style: TextStyle(
                      fontSize: 8.5,
                      fontWeight: FontWeight.w700,
                      color: palette.primary,
                    ),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 10),

          // Show title
          Text(
            current.title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w800,
              fontSize: 16,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 4),

          // Category & episode
          Row(
            children: [
              Flexible(
                child: Text(
                  current.category,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: palette.secondary,
                  ),
                ),
              ),
              if (current.episode != null) ...[
                Text(
                  ' · ',
                  style: TextStyle(fontSize: 10, color: colors.faint),
                ),
                Flexible(
                  child: Text(
                    current.episode!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w500,
                      color: colors.muted,
                    ),
                  ),
                ),
              ],
              if (current.rating != null) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 4.5, vertical: 1),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
                  ),
                  child: Text(
                    current.rating!,
                    style: TextStyle(
                      fontSize: 8,
                      fontWeight: FontWeight.w600,
                      color: colors.faint,
                    ),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 10),

          // Progress bar
          ClipRRect(
            borderRadius: BorderRadius.circular(99),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 4.5,
              backgroundColor: Colors.white.withValues(alpha: 0.12),
              valueColor: AlwaysStoppedAnimation(palette.primary),
            ),
          ),
          const SizedBox(height: 6),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                current.elapsedLabel(now),
                style: TextStyle(
                  fontSize: 8.5,
                  fontWeight: FontWeight.w500,
                  color: colors.faint,
                ),
              ),
              Text(
                '${(progress * 100).round()}% complete',
                style: TextStyle(
                  fontSize: 8.5,
                  fontWeight: FontWeight.w600,
                  color: colors.muted,
                ),
              ),
            ],
          ),

          // Description
          if (current.description.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              current.description,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 9.5,
                height: 1.45,
                color: colors.muted,
              ),
            ),
          ],

          // Up Next teaser + Guide button
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.28),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.schedule_rounded,
                  size: 14,
                  color: palette.primary,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'UP NEXT',
                        style: TextStyle(
                          fontSize: 7.5,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.6,
                          color: colors.faint,
                        ),
                      ),
                      const SizedBox(height: 1),
                      Text(
                        next != null
                            ? '${next.startTimeLabel} · ${next.title}'
                            : 'Continuous Broadcast',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
                if (onViewGuide != null) ...[
                  const SizedBox(width: 8),
                  Pressable(
                    onTap: onViewGuide,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 9,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: palette.primary.withValues(alpha: 0.18),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: palette.primary.withValues(alpha: 0.35),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.view_timeline_rounded,
                            size: 13,
                            color: palette.primary,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'Full Guide',
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w700,
                              color: palette.primary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Compact Now Playing bar for the live player HUD.
class EpgPlayerOverlayBar extends ConsumerWidget {
  const EpgPlayerOverlayBar({
    super.key,
    required this.channel,
    required this.onTapGuide,
    this.onSyncToLive,
  });

  final Channel channel;
  final VoidCallback onTapGuide;
  final VoidCallback? onSyncToLive;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final palette = context.palette;
    final schedule = ref.watch(channelScheduleProvider(channel));
    final current = schedule.currentProgram();
    final next = schedule.nextProgram();
    final now = DateTime.now();

    if (current == null || current.isEstimated) return const SizedBox.shrink();

    final progress = current.progress(now);

    return Pressable(
      onTap: onTapGuide,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 10),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.72),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.5),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                // Live indicator with tap-to-sync
                Tooltip(
                  message: onSyncToLive != null ? 'Catch up to live broadcast' : '',
                  child: Pressable(
                    onTap: onSyncToLive,
                    child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                    decoration: BoxDecoration(
                      color: colors.success.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(5),
                      border: Border.all(
                        color: colors.success.withValues(alpha: 0.35),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 5,
                          height: 5,
                          decoration: BoxDecoration(
                            color: colors.success,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: colors.success.withValues(alpha: 0.8),
                                blurRadius: 5,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 5),
                        Text(
                          'LIVE',
                          style: TextStyle(
                            fontSize: 7.5,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.6,
                            color: colors.success,
                          ),
                        ),
                        if (onSyncToLive != null) ...[
                          const SizedBox(width: 3),
                          Icon(
                            Icons.refresh_rounded,
                            size: 8.5,
                            color: colors.success,
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
              if (current.timeRange.isNotEmpty) ...[
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    current.timeRange,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: 'Manrope',
                      fontSize: 8,
                      fontWeight: FontWeight.w600,
                      color: Colors.white.withValues(alpha: 0.55),
                    ),
                  ),
                ),
              ],
              if (current.remainingLabel(now).isNotEmpty) ...[
                const SizedBox(width: 6),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                  decoration: BoxDecoration(
                    color: palette.primary.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    current.remainingLabel(now),
                    style: TextStyle(
                      fontSize: 7.5,
                      fontWeight: FontWeight.w700,
                      color: palette.primary,
                    ),
                  ),
                ),
              ],
                const SizedBox(width: 4),
                Icon(
                  Icons.chevron_right_rounded,
                  size: 14,
                  color: Colors.white.withValues(alpha: 0.4),
                ),
              ],
            ),
            const SizedBox(height: 5),

            // Show title
            Row(
              children: [
                Expanded(
                  child: Text(
                    current.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontFamily: 'Manrope',
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ),
                if (next != null) ...[
                  const SizedBox(width: 8),
                  Text(
                    'Next: ${next.title}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 8.5,
                      fontWeight: FontWeight.w500,
                      color: Colors.white.withValues(alpha: 0.45),
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 6),

            // Progress bar
            ClipRRect(
              borderRadius: BorderRadius.circular(99),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 2.5,
                backgroundColor: Colors.white.withValues(alpha: 0.15),
                valueColor: AlwaysStoppedAnimation(palette.primary),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
