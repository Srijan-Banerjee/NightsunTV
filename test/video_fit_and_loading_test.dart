import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nightsuntv/core/theme/app_theme.dart';
import 'package:nightsuntv/core/widgets/loading_view.dart';
import 'package:nightsuntv/data/models/channel.dart';
import 'package:nightsuntv/data/models/stream_source.dart';
import 'package:nightsuntv/features/player/player_screen.dart';
import 'package:nightsuntv/state/settings_controller.dart';

void main() {
  group('VideoFitMode tests', () {
    test('VideoFitMode cycles through Contain, Cover, and Stretch', () {
      expect(VideoFitMode.contain.next, VideoFitMode.cover);
      expect(VideoFitMode.cover.next, VideoFitMode.stretch);
      expect(VideoFitMode.stretch.next, VideoFitMode.contain);

      expect(VideoFitMode.contain.label, 'Contain');
      expect(VideoFitMode.cover.label, 'Cover');
      expect(VideoFitMode.stretch.label, 'Stretch');

      expect(VideoFitMode.contain.badge, 'FIT');
      expect(VideoFitMode.cover.badge, 'CROP');
      expect(VideoFitMode.stretch.badge, 'STRETCH');
    });
  });

  group('Nightsun loading view and indicator tests', () {
    const testChannel = Channel(
      id: 'SkyNews.uk',
      name: 'Sky News',
      country: 'GB',
      categories: ['news'],
      languages: ['eng'],
      sources: [StreamSource(url: 'https://example.com/live.m3u8')],
    );

    testWidgets('NightsunPulseLoader renders with custom emblem and with channel',
        (tester) async {
      final theme = AppTheme.build(const Settings());

      await tester.pumpWidget(
        MaterialApp(
          theme: theme,
          home: const Scaffold(
            body: Center(
              child: NightsunPulseLoader(
                size: 90,
                customIcon: Icons.tv_rounded,
              ),
            ),
          ),
        ),
      );

      expect(find.byType(NightsunPulseLoader), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 200));
      expect(tester.takeException(), isNull);

      await tester.pumpWidget(
        MaterialApp(
          theme: theme,
          home: const Scaffold(
            body: Center(
              child: NightsunPulseLoader(
                size: 90,
                channel: testChannel,
              ),
            ),
          ),
        ),
      );

      expect(find.byType(NightsunPulseLoader), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 200));
      expect(tester.takeException(), isNull);
    });

    testWidgets('NightsunLoadingView renders title, subtitle, and beam',
        (tester) async {
      final theme = AppTheme.build(const Settings());

      await tester.pumpWidget(
        MaterialApp(
          theme: theme,
          home: const Scaffold(
            body: NightsunLoadingView(
              title: 'Tuning In to NightsunTV',
              subtitle: 'Connecting to global channels…',
              compact: true,
            ),
          ),
        ),
      );

      expect(find.text('Tuning In to NightsunTV'), findsOneWidget);
      expect(find.text('Connecting to global channels…'), findsOneWidget);
      expect(find.byType(NightsunPulseLoader), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 200));
      expect(tester.takeException(), isNull);
    });

    testWidgets('StreamLoadingView renders in player with live status',
        (tester) async {
      final theme = AppTheme.build(const Settings());
      var skipped = false;

      await tester.pumpWidget(
        MaterialApp(
          theme: theme,
          home: Scaffold(
            body: StreamLoadingView(
              channel: testChannel,
              status: 'Connecting to live feed…',
              flag: '🇬🇧',
              countryName: 'United Kingdom',
              hasMultipleSources: true,
              onSkipSource: () => skipped = true,
            ),
          ),
        ),
      );

      expect(find.text('Sky News'), findsOneWidget);
      expect(find.text('Connecting to live feed…'), findsOneWidget);
      expect(find.text('🇬🇧 United Kingdom'), findsOneWidget);
      expect(find.text('Skip to next mirror'), findsOneWidget);

      await tester.tap(find.text('Skip to next mirror'));
      await tester.pump();
      expect(skipped, isTrue);
    });

    testWidgets('StreamLoadingView does not collide with now playing bar during loading',
        (tester) async {
      final theme = AppTheme.build(const Settings());

      await tester.pumpWidget(
        MaterialApp(
          theme: theme,
          home: Scaffold(
            body: Center(
              child: StreamLoadingView(
                channel: testChannel,
                status: 'Connecting to source 1 of 2…',
                hasMultipleSources: true,
              ),
            ),
          ),
        ),
      );

      expect(find.byType(StreamLoadingView), findsOneWidget);
      // EpgPlayerOverlayBar should not be present while mirror is loading
      expect(find.byType(LinearProgressIndicator), findsNothing);
    });
  });
}
