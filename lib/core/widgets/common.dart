import 'dart:async';

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'pressable.dart';

class GlassPanel extends StatelessWidget {
  const GlassPanel({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.radius = 22,
    this.color,
    this.gradient,
    this.borderColor,
    this.onTap,
    this.glow = false,
    this.clipBehavior = Clip.antiAlias,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius;
  final Color? color;
  final Gradient? gradient;
  final Color? borderColor;
  final VoidCallback? onTap;
  final bool glow;
  final Clip clipBehavior;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final palette = context.palette;
    final fill = BoxDecoration(
      color: gradient == null
          ? (color ?? colors.surface.withValues(alpha: .82))
          : null,
      gradient: gradient,
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(color: borderColor ?? colors.border),
    );
    final content = Padding(padding: padding, child: child);
    final body = ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      clipBehavior: clipBehavior,
      child: DecoratedBox(decoration: fill, child: content),
    );
    final shadowed = Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        boxShadow: glow
            ? [
                BoxShadow(
                  color: palette.primary.withValues(alpha: .10),
                  blurRadius: 28,
                  offset: const Offset(0, 12),
                ),
                BoxShadow(
                  color: Colors.black.withValues(alpha: .28),
                  blurRadius: 24,
                  offset: const Offset(0, 10),
                ),
              ]
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: .16),
                  blurRadius: 18,
                  offset: const Offset(0, 8),
                ),
              ],
      ),
      child: body,
    );
    return onTap == null ? shadowed : Pressable(onTap: onTap, child: shadowed);
  }
}

class SectionHeader extends StatelessWidget {
  const SectionHeader({
    super.key,
    required this.title,
    this.eyebrow,
    this.actionLabel,
    this.onAction,
    this.padding = const EdgeInsets.fromLTRB(20, 26, 20, 12),
  });

  final String title;
  final String? eyebrow;
  final String? actionLabel;
  final VoidCallback? onAction;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = context.colors;
    final palette = context.palette;
    return Padding(
      padding: padding,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (eyebrow != null) ...[
                  Text(
                    eyebrow!.toUpperCase(),
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: palette.primary,
                      letterSpacing: 1.3,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 5),
                ],
                Text(
                  title,
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontSize: 20,
                    letterSpacing: -.3,
                  ),
                ),
              ],
            ),
          ),
          if (actionLabel != null && onAction != null)
            TextButton(
              onPressed: onAction,
              style: TextButton.styleFrom(
                foregroundColor: palette.primary,
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                minimumSize: const Size(0, 36),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                textStyle: theme.textTheme.labelMedium?.copyWith(
                  color: palette.primary,
                  fontWeight: FontWeight.w800,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(actionLabel!, style: TextStyle(color: palette.primary)),
                  const SizedBox(width: 2),
                  Icon(Icons.chevron_right_rounded, size: 17, color: colors.faint),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class AppChip extends StatelessWidget {
  const AppChip({
    super.key,
    required this.label,
    this.onTap,
    this.selected = false,
    this.icon,
    this.trailing,
    this.dense = false,
    this.accent,
  });

  final String label;
  final VoidCallback? onTap;
  final bool selected;
  final IconData? icon;
  final Widget? trailing;
  final bool dense;
  final Color? accent;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final palette = context.palette;
    final activeColor = accent ?? palette.primary;
    final foreground = selected ? activeColor : colors.muted;
    final content = Container(
      padding: EdgeInsets.symmetric(
        horizontal: dense ? 11 : 13,
        vertical: dense ? 7 : 9,
      ),
      decoration: BoxDecoration(
        color: selected
            ? activeColor.withValues(alpha: .13)
            : colors.surfaceAlt.withValues(alpha: .72),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: selected ? activeColor.withValues(alpha: .55) : colors.border,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: dense ? 13 : 15, color: foreground),
            const SizedBox(width: 6),
          ],
          Text(
            label,
            style: TextStyle(
              fontFamily: 'Manrope',
              fontSize: dense ? 11.5 : 12.5,
              fontWeight: FontWeight.w700,
              color: selected ? activeColor : colors.text,
              height: 1.15,
            ),
          ),
          if (trailing != null) ...[
            const SizedBox(width: 6),
            trailing!,
          ],
        ],
      ),
    );
    if (onTap == null) return content;
    return Pressable(onTap: onTap, scale: .96, child: content);
  }
}

class IconCircleButton extends StatelessWidget {
  const IconCircleButton({
    super.key,
    required this.icon,
    this.onTap,
    this.tooltip,
    this.size = 42,
    this.iconSize = 20,
    this.filled = true,
    this.color,
    this.backgroundColor,
    this.badge,
  });

  final IconData icon;
  final VoidCallback? onTap;
  final String? tooltip;
  final double size;
  final double iconSize;
  final bool filled;
  final Color? color;
  final Color? backgroundColor;
  final Widget? badge;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final button = Stack(
      clipBehavior: Clip.none,
      children: [
        Material(
          color: filled
              ? (backgroundColor ?? colors.surfaceAlt.withValues(alpha: .9))
              : Colors.transparent,
          shape: CircleBorder(
            side: BorderSide(
              color: filled ? colors.border : Colors.transparent,
            ),
          ),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            customBorder: const CircleBorder(),
            child: SizedBox(
              width: size,
              height: size,
              child: Icon(icon, size: iconSize, color: color ?? colors.text),
            ),
          ),
        ),
        if (badge != null)
          Positioned(right: -2, top: -2, child: badge!),
      ],
    );
    if (tooltip == null) return button;
    return Tooltip(message: tooltip!, child: button);
  }
}

class PrimaryButton extends StatelessWidget {
  const PrimaryButton({
    super.key,
    required this.label,
    this.onTap,
    this.icon = Icons.play_arrow_rounded,
    this.height = 52,
    this.expand = true,
    this.enabled = true,
  });

  final String label;
  final VoidCallback? onTap;
  final IconData? icon;
  final double height;
  final bool expand;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final child = Container(
      height: height,
      padding: const EdgeInsets.symmetric(horizontal: 22),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: enabled
              ? palette.gradient
              : [context.colors.surfaceAlt, context.colors.surfaceAlt],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(17),
        boxShadow: enabled
            ? [
                BoxShadow(
                  color: palette.primary.withValues(alpha: .24),
                  blurRadius: 22,
                  offset: const Offset(0, 9),
                ),
              ]
            : null,
      ),
      child: Row(
        mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 22, color: palette.onPrimary),
            const SizedBox(width: 9),
          ],
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontFamily: 'Manrope',
                fontWeight: FontWeight.w800,
                fontSize: 15,
                letterSpacing: .1,
                color: enabled ? palette.onPrimary : context.colors.faint,
              ),
            ),
          ),
        ],
      ),
    );
    return Pressable(
      onTap: enabled ? onTap : null,
      child: child,
    );
  }
}

class SecondaryButton extends StatelessWidget {
  const SecondaryButton({
    super.key,
    required this.label,
    this.onTap,
    this.icon,
    this.height = 48,
    this.expand = false,
  });

  final String label;
  final VoidCallback? onTap;
  final IconData? icon;
  final double height;
  final bool expand;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final palette = context.palette;
    return Pressable(
      onTap: onTap,
      child: Container(
        height: height,
        padding: const EdgeInsets.symmetric(horizontal: 18),
        decoration: BoxDecoration(
          color: colors.surfaceAlt.withValues(alpha: .8),
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: colors.borderStrong),
        ),
        child: Row(
          mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 18, color: palette.primary),
              const SizedBox(width: 8),
            ],
            Text(
              label,
              style: TextStyle(
                fontFamily: 'Manrope',
                fontSize: 13.5,
                fontWeight: FontWeight.w700,
                color: colors.text,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class QualityBadge extends StatelessWidget {
  const QualityBadge({super.key, required this.label, this.compact = false});

  final String label;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 6 : 8,
        vertical: compact ? 2 : 3,
      ),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: .52),
        borderRadius: BorderRadius.circular(7),
        border: Border.all(color: Colors.white.withValues(alpha: .14)),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontFamily: 'Manrope',
          fontSize: compact ? 9 : 10,
          height: 1.1,
          fontWeight: FontWeight.w800,
          color: Colors.white.withValues(alpha: .92),
          letterSpacing: .2,
        ),
      ),
    );
  }
}

class SourceCountBadge extends StatelessWidget {
  const SourceCountBadge({super.key, required this.count, this.onDark = false});

  final int count;
  final bool onDark;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final palette = context.palette;
    final color = onDark ? Colors.white.withValues(alpha: .86) : colors.faint;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          count > 1 ? Icons.layers_rounded : Icons.hd_outlined,
          size: 13,
          color: count > 1 ? palette.primary.withValues(alpha: .9) : color,
        ),
        const SizedBox(width: 4),
        Text(
          count > 1 ? '$count sources' : '1 source',
          style: TextStyle(
            fontFamily: 'Manrope',
            fontSize: 10.5,
            fontWeight: FontWeight.w600,
            color: color,
          ),
        ),
      ],
    );
  }
}

class FlagText extends StatelessWidget {
  const FlagText({super.key, required this.flag, this.size = 15});

  final String flag;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Text(
      flag.isEmpty ? '🌐' : flag,
      style: TextStyle(fontSize: size, height: 1.1),
    );
  }
}

class LoadingSkeleton extends StatefulWidget {
  const LoadingSkeleton({super.key, this.rows = 6, this.showHeader = true});

  final int rows;
  final bool showHeader;

  @override
  State<LoadingSkeleton> createState() => _LoadingSkeletonState();
}

class _LoadingSkeletonState extends State<LoadingSkeleton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1250),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final t = Curves.easeInOut.transform(_controller.value);
        final base = colors.surfaceAlt.withValues(alpha: .45 + t * .35);
        Widget box(double? width, double height, {double radius = 12}) => Container(
              width: width,
              height: height,
              decoration: BoxDecoration(
                color: base,
                borderRadius: BorderRadius.circular(radius),
              ),
            );
        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (widget.showHeader) ...[
                box(160, 22, radius: 8),
                const SizedBox(height: 9),
                box(240, 13, radius: 6),
                const SizedBox(height: 26),
              ],
              for (var i = 0; i < widget.rows; i++) ...[
                Row(
                  children: [
                    box(52, 52, radius: 14),
                    const SizedBox(width: 13),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          box(170, 13, radius: 5),
                          const SizedBox(height: 8),
                          box(110, 10, radius: 5),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
              ],
            ],
          ),
        );
      },
    );
  }
}

class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
    this.compact = false,
  });

  final IconData icon;
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = context.colors;
    final palette = context.palette;
    return Center(
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: 34,
          vertical: compact ? 24 : 44,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: compact ? 64 : 86,
              height: compact ? 64 : 86,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: palette.primary.withValues(alpha: .09),
                border: Border.all(
                  color: palette.primary.withValues(alpha: .18),
                ),
              ),
              child: Icon(
                icon,
                size: compact ? 28 : 38,
                color: palette.primary,
              ),
            ),
            SizedBox(height: compact ? 16 : 22),
            Text(
              title,
              textAlign: TextAlign.center,
              style: theme.textTheme.headlineSmall?.copyWith(fontSize: 20),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(color: colors.muted),
            ),
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 22),
              SecondaryButton(
                label: actionLabel!,
                icon: Icons.explore_rounded,
                onTap: onAction,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class InlineError extends StatelessWidget {
  const InlineError({
    super.key,
    required this.message,
    this.onRetry,
    this.title = 'Something went off air',
  });

  final String message;
  final VoidCallback? onRetry;
  final String title;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = context.colors;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.cloud_off_rounded, size: 40, color: colors.error),
            const SizedBox(height: 16),
            Text(title, style: theme.textTheme.headlineSmall),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(color: colors.muted),
            ),
            if (onRetry != null) ...[
              const SizedBox(height: 20),
              SecondaryButton(
                label: 'Try again',
                icon: Icons.refresh_rounded,
                onTap: onRetry,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class AppNotices {
  AppNotices._();

  static void show(
    BuildContext context,
    String message, {
    IconData icon = Icons.info_outline_rounded,
    SnackBarAction? action,
    Duration duration = const Duration(seconds: 3),
  }) {
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        duration: duration,
        action: action,
        content: Row(
          children: [
            Icon(icon, size: 18, color: context.palette.primary),
            const SizedBox(width: 10),
            Expanded(child: Text(message)),
          ],
        ),
      ),
    );
  }

  static Future<bool> confirm(
    BuildContext context, {
    required String title,
    required String message,
    String confirmLabel = 'Confirm',
    String cancelLabel = 'Cancel',
    bool destructive = false,
  }) async {
    final colors = context.colors;
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: colors.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: BorderSide(color: colors.border),
        ),
        title: Text(title, style: Theme.of(context).textTheme.titleLarge),
        content: Text(
          message,
          style: Theme.of(context)
              .textTheme
              .bodyMedium
              ?.copyWith(color: colors.muted, height: 1.5),
        ),
        actionsPadding: const EdgeInsets.fromLTRB(18, 4, 18, 16),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(
              cancelLabel,
              style: TextStyle(color: colors.muted, fontWeight: FontWeight.w700),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(
              foregroundColor:
                  destructive ? colors.error : context.palette.primary,
            ),
            child: Text(
              confirmLabel,
              style: TextStyle(
                fontWeight: FontWeight.w800,
                color: destructive ? colors.error : context.palette.primary,
              ),
            ),
          ),
        ],
      ),
    );
    return result ?? false;
  }
}

/// Adds a safe, consistent bottom inset above the floating dock.


class BrandMark extends StatelessWidget {
  const BrandMark({super.key, this.size = 38, this.radius = 11});

  final double size;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(radius),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: .3),
              blurRadius: 14,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Image.asset(
          'assets/branding/app_icon_512.png',
          width: size,
          height: size,
          fit: BoxFit.cover,
          filterQuality: FilterQuality.medium,
        ),
      ),
    );
  }
}

class DockSpacer extends StatelessWidget {
  const DockSpacer({super.key, this.extra = 0});
  final double extra;

  @override
  Widget build(BuildContext context) =>
      SizedBox(height: 104 + MediaQuery.paddingOf(context).bottom + extra);
}

void schedulePostFrame(VoidCallback callback) {
  WidgetsBinding.instance.addPostFrameCallback((_) => callback());
}

Future<void> delay(Duration duration) => Future<void>.delayed(duration);
