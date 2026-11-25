import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import '../../core/widgets/app_background.dart';
import '../../core/widgets/common.dart';
import '../../state/settings_controller.dart';

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final PageController _controller = PageController();
  int _page = 0;

  static const _pages = [
    _OnboardingData(
      eyebrow: 'WELCOME TO NIGHTSUN',
      title: 'Every channel.\nOne night sky.',
      message:
          'Thousands of free live channels from around the world — news, '
          'movies, sport, music and more. No account, no subscription, no ads.',
      bullets: ['15,239 channels', '184 countries', 'No watch limits'],
    ),
    _OnboardingData(
      eyebrow: 'FIND YOUR CHANNEL',
      title: 'A smarter way\nto channel surf.',
      message:
          'Search by name, country, language or category. Save favourites, '
          'pick up where you left off, and keep your own lineup close.',
      bullets: ['Smart search', 'Favourites', 'Watch history'],
    ),
    _OnboardingData(
      eyebrow: 'MADE FOR LATE NIGHTS',
      title: 'Built to keep\nplaying.',
      message:
          'Backup sources step in automatically when a stream drops. '
          'Picture-in-picture and a sleep timer make the last hour yours.',
      bullets: ['Auto fallback', 'Picture-in-picture', 'Sleep timer'],
    ),
  ];

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _finish() {
    ref.read(settingsProvider.notifier).completeOnboarding();
  }

  void _next() {
    if (_page == _pages.length - 1) {
      _finish();
      return;
    }
    _controller.nextPage(
      duration: const Duration(milliseconds: 420),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final palette = context.palette;

    return Scaffold(
      backgroundColor: colors.background,
      body: AppBackground(
        stars: true,
        starCount: 80,
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(22, 12, 14, 4),
                child: Row(
                  children: [
                    const BrandMark(size: 34, radius: 10),
                    const SizedBox(width: 10),
                    Text(
                      'NightsunTV',
                      style: TextStyle(
                        fontFamily: 'Sora',
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -.3,
                        color: colors.text,
                      ),
                    ),
                    const Spacer(),
                    AnimatedOpacity(
                      duration: const Duration(milliseconds: 200),
                      opacity: _page == _pages.length - 1 ? 0 : 1,
                      child: IgnorePointer(
                        ignoring: _page == _pages.length - 1,
                        child: TextButton(
                          onPressed: _finish,
                          style: TextButton.styleFrom(
                            foregroundColor: colors.muted,
                            textStyle: const TextStyle(
                              fontFamily: 'Manrope',
                              fontWeight: FontWeight.w700,
                              fontSize: 12.5,
                            ),
                          ),
                          child: const Text('Skip'),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: PageView.builder(
                  controller: _controller,
                  itemCount: _pages.length,
                  onPageChanged: (index) => setState(() => _page = index),
                  itemBuilder: (context, index) {
                    final page = _pages[index];
                    return LayoutBuilder(
                      builder: (context, constraints) {
                        final artHeight = math.min(290.0, constraints.maxHeight * .48);
                        return SingleChildScrollView(
                          physics: const ClampingScrollPhysics(),
                          padding: const EdgeInsets.fromLTRB(26, 14, 26, 16),
                          child: ConstrainedBox(
                            constraints: BoxConstraints(
                              minHeight: constraints.maxHeight - 30,
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                SizedBox(
                                  height: artHeight,
                                  child: Center(
                                    child: FittedBox(
                                      fit: BoxFit.scaleDown,
                                      child: _artFor(index),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 24),
                                Text(
                                  page.eyebrow,
                                  style: TextStyle(
                                    fontFamily: 'Manrope',
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 1.5,
                                    color: palette.primary,
                                  ),
                                ),
                                const SizedBox(height: 10),
                                Text(
                                  page.title,
                                  style: Theme.of(context)
                                      .textTheme
                                      .displaySmall
                                      ?.copyWith(
                                        fontSize: 31,
                                        height: 1.1,
                                        letterSpacing: -1,
                                      ),
                                ),
                                const SizedBox(height: 13),
                                Text(
                                  page.message,
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodyMedium
                                      ?.copyWith(
                                        color: colors.muted,
                                        fontSize: 13.5,
                                        height: 1.55,
                                      ),
                                ),
                                const SizedBox(height: 18),
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  children: [
                                    for (final bullet in page.bullets)
                                      AppChip(
                                        label: bullet,
                                        dense: true,
                                        selected: true,
                                        icon: Icons.check_rounded,
                                      ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(26, 6, 26, 18),
                child: Column(
                  children: [
                    Row(
                      children: [
                        for (var index = 0; index < _pages.length; index++)
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 260),
                            curve: Curves.easeOutCubic,
                            margin: const EdgeInsets.only(right: 6),
                            width: index == _page ? 22 : 6,
                            height: 6,
                            decoration: BoxDecoration(
                              color: index == _page
                                  ? palette.primary
                                  : colors.borderStrong,
                              borderRadius: BorderRadius.circular(99),
                            ),
                          ),
                        const Spacer(),
                        Text(
                          '${_page + 1} / ${_pages.length}',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: colors.faint,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    PrimaryButton(
                      label: _page == _pages.length - 1
                          ? 'Start watching'
                          : 'Continue',
                      icon: _page == _pages.length - 1
                          ? Icons.live_tv_rounded
                          : Icons.arrow_forward_rounded,
                      onTap: _next,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Data from iptv-org · NightsunTV does not host streams',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 9.5,
                        fontWeight: FontWeight.w500,
                        color: colors.faint,
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

  Widget _artFor(int index) {
    return switch (index) {
      0 => const _ConstellationArt(),
      1 => const _SearchArt(),
      _ => const _PlayerArt(),
    };
  }
}

class _OnboardingData {
  const _OnboardingData({
    required this.eyebrow,
    required this.title,
    required this.message,
    required this.bullets,
  });

  final String eyebrow;
  final String title;
  final String message;
  final List<String> bullets;
}

class _ConstellationArt extends StatelessWidget {
  const _ConstellationArt();

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final colors = context.colors;
    Widget label(String text, IconData icon) => Container(
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
          decoration: BoxDecoration(
            color: colors.surface.withValues(alpha: .88),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: colors.border),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 12, color: palette.primary),
              const SizedBox(width: 5),
              Text(
                text,
                style: TextStyle(
                  fontSize: 9.5,
                  fontWeight: FontWeight.w700,
                  color: colors.text,
                  letterSpacing: .2,
                ),
              ),
            ],
          ),
        );

    return SizedBox(
      width: 300,
      height: 270,
      child: Stack(
        alignment: Alignment.center,
        children: [
          for (final size in [258.0, 198.0, 138.0])
            Container(
              width: size,
              height: size,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: palette.primary.withValues(alpha: .10),
                ),
              ),
            ),
          Container(
            width: 190,
            height: 190,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  palette.primary.withValues(alpha: .16),
                  palette.primary.withValues(alpha: 0),
                ],
              ),
            ),
          ),
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(30),
              boxShadow: [
                BoxShadow(
                  color: palette.primary.withValues(alpha: .22),
                  blurRadius: 44,
                  spreadRadius: 4,
                ),
              ],
            ),
            child: const BrandMark(size: 128, radius: 31),
          ),
          Positioned(left: 0, top: 54, child: label('LIVE NEWS', Icons.public_rounded)),
          Positioned(right: 0, top: 108, child: label('SPORT', Icons.sports_soccer_rounded)),
          Positioned(left: 16, bottom: 42, child: label('MOVIES', Icons.movie_rounded)),
          Positioned(right: 8, bottom: 26, child: label('MUSIC', Icons.graphic_eq_rounded)),
        ],
      ),
    );
  }
}

class _SearchArt extends StatelessWidget {
  const _SearchArt();

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final palette = context.palette;
    Widget result(IconData icon, String title, String subtitle) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 7),
          child: Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(9),
                  color: palette.primary.withValues(alpha: .10),
                  border: Border.all(
                    color: palette.primary.withValues(alpha: .18),
                  ),
                ),
                child: Icon(icon, size: 16, color: palette.primary),
              ),
              const SizedBox(width: 9),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                        color: colors.text,
                      ),
                    ),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 9.5,
                        color: colors.faint,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded, size: 15, color: colors.faint),
            ],
          ),
        );

    return SizedBox(
      width: 314,
      height: 280,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            left: 14,
            right: -8,
            top: 22,
            bottom: 6,
            child: Container(
              decoration: BoxDecoration(
                color: colors.surface,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: colors.border),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: .35),
                    blurRadius: 30,
                    offset: const Offset(0, 14),
                  ),
                ],
              ),
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 11,
                    ),
                    decoration: BoxDecoration(
                      color: colors.surfaceAlt,
                      borderRadius: BorderRadius.circular(13),
                      border: Border.all(color: colors.borderStrong),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.search_rounded, size: 17, color: palette.primary),
                        const SizedBox(width: 8),
                        Text(
                          'world news',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: colors.text,
                          ),
                        ),
                        const Spacer(),
                        Container(
                          width: 1.5,
                          height: 14,
                          color: palette.primary.withValues(alpha: .6),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 7),
                  result(Icons.public_rounded, 'World News', '486 live channels'),
                  result(Icons.movie_rounded, 'Movies', '1,204 live channels'),
                  result(Icons.graphic_eq_rounded, 'Music', '612 live channels'),
                  const SizedBox(height: 5),
                  Wrap(
                    spacing: 6,
                    children: [
                      _miniTag(context, 'News', selected: true),
                      _miniTag(context, 'Documentary'),
                      _miniTag(context, 'English'),
                    ],
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            right: -12,
            top: 6,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: palette.gradient),
                borderRadius: BorderRadius.circular(11),
                boxShadow: [
                  BoxShadow(
                    color: palette.primary.withValues(alpha: .3),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.auto_awesome_rounded, size: 12, color: palette.onPrimary),
                  const SizedBox(width: 4),
                  Text(
                    'Smart search',
                    style: TextStyle(
                      fontSize: 9.5,
                      fontWeight: FontWeight.w800,
                      color: palette.onPrimary,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _miniTag(BuildContext context, String label, {bool selected = false}) {
    final colors = context.colors;
    final palette = context.palette;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: selected
            ? palette.primary.withValues(alpha: .14)
            : colors.surfaceAlt,
        borderRadius: BorderRadius.circular(99),
        border: Border.all(
          color: selected ? palette.primary.withValues(alpha: .4) : colors.border,
        ),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 8.5,
          fontWeight: FontWeight.w700,
          color: selected ? palette.primary : colors.muted,
        ),
      ),
    );
  }
}

class _PlayerArt extends StatelessWidget {
  const _PlayerArt();

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final palette = context.palette;
    return SizedBox(
      width: 314,
      height: 260,
      child: Stack(
        children: [
          Positioned(
            left: 6,
            right: 6,
            top: 18,
            child: Container(
              height: 190,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFF17233A), Color(0xFF070B14)],
                ),
                border: Border.all(
                  color: Colors.white.withValues(alpha: .10),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: .4),
                    blurRadius: 26,
                    offset: const Offset(0, 14),
                  ),
                ],
              ),
              child: Stack(
                children: [
                  Positioned(
                    right: -30,
                    top: -40,
                    child: Container(
                      width: 170,
                      height: 170,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(
                          colors: [
                            palette.secondary.withValues(alpha: .25),
                            palette.secondary.withValues(alpha: 0),
                          ],
                        ),
                      ),
                    ),
                  ),
                  Center(
                    child: Container(
                      width: 62,
                      height: 62,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(colors: palette.gradient),
                        boxShadow: [
                          BoxShadow(
                            color: palette.primary.withValues(alpha: .35),
                            blurRadius: 30,
                          ),
                        ],
                      ),
                      child: Icon(
                        Icons.play_arrow_rounded,
                        color: palette.onPrimary,
                        size: 38,
                      ),
                    ),
                  ),
                  Positioned(
                    left: 14,
                    top: 14,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: .4),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: .16),
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 5,
                            height: 5,
                            decoration: BoxDecoration(
                              color: palette.primary,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 5),
                          const Text(
                            'LIVE',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 8.5,
                              fontWeight: FontWeight.w800,
                              letterSpacing: .7,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  Positioned(
                    left: 14,
                    right: 14,
                    bottom: 14,
                    child: Row(
                      children: [
                        Icon(Icons.pause_rounded, color: Colors.white.withValues(alpha: .8), size: 17),
                        const SizedBox(width: 10),
                        Expanded(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(99),
                            child: LinearProgressIndicator(
                              value: .62,
                              minHeight: 3,
                              backgroundColor: Colors.white.withValues(alpha: .16),
                              valueColor: AlwaysStoppedAnimation(palette.primary),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          'HD · HLS',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: .6),
                            fontSize: 8.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            left: 26,
            right: 26,
            bottom: 4,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: colors.elevated,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: colors.borderStrong),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: .32),
                    blurRadius: 18,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: context.colors.success.withValues(alpha: .12),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.swap_horiz_rounded,
                      size: 16,
                      color: palette.primary,
                    ),
                  ),
                  const SizedBox(width: 9),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Backup source ready',
                          style: TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w700,
                            color: colors.text,
                          ),
                        ),
                        Text(
                          'Automatic fallback keeps you watching',
                          style: TextStyle(
                            fontSize: 8.8,
                            fontWeight: FontWeight.w500,
                            color: colors.muted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(Icons.check_circle_rounded, size: 17, color: context.colors.success),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
