import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nightsuntv/core/theme/app_theme.dart';
import 'package:nightsuntv/data/models/channel.dart';
import 'package:nightsuntv/data/models/epg_program.dart';
import 'package:nightsuntv/data/models/stream_source.dart';
import 'package:nightsuntv/data/services/epg_service.dart';
import 'package:nightsuntv/features/epg/epg_guide_sheet.dart';
import 'package:nightsuntv/state/providers.dart';
import 'package:nightsuntv/state/settings_controller.dart';

void main() {
  group('EpgProgram Model', () {
    final now = DateTime(2026, 11, 23, 14, 30);
    final realProgram = EpgProgram(
      id: 'prog-1',
      channelId: 'bbc-news',
      title: 'Global Headlines Hour',
      description: 'Live news reporting and analysis.',
      category: 'News',
      start: DateTime(2026, 11, 23, 14, 0),
      stop: DateTime(2026, 11, 23, 15, 0),
      episode: 'Live Edition',
      rating: 'TV-14',
      isEstimated: false,
    );

    final estimatedProgram = EpgProgram(
      id: 'prog-fake',
      channelId: 'bbc-news',
      title: 'Estimated Show',
      description: 'Synthetic estimate.',
      category: 'General',
      start: DateTime(2026, 11, 23, 14, 0),
      stop: DateTime(2026, 11, 23, 15, 0),
      isEstimated: true,
    );

    test('calculates duration and time labels correctly for real programs', () {
      expect(realProgram.duration, const Duration(hours: 1));
      expect(realProgram.durationLabel, '1h');
      expect(realProgram.timeRange, '14:00 – 15:00');
      expect(realProgram.startTimeLabel, '14:00');
      expect(realProgram.stopTimeLabel, '15:00');
    });

    test('omits show time labels completely for fake or estimated programs', () {
      expect(estimatedProgram.timeRange, isEmpty);
      expect(estimatedProgram.startTimeLabel, isEmpty);
      expect(estimatedProgram.stopTimeLabel, isEmpty);
      expect(estimatedProgram.remainingLabel(now), isEmpty);
      expect(estimatedProgram.elapsedLabel(now), isEmpty);
      expect(estimatedProgram.durationLabel, isEmpty);
      expect(estimatedProgram.progress(now), 0.0);
    });

    test('accurately calculates live status, progress, and remaining time for real program', () {
      expect(realProgram.isLive(now), isTrue);
      expect(realProgram.isPast(now), isFalse);
      expect(realProgram.isUpcoming(now), isFalse);

      expect(realProgram.progress(now), closeTo(0.5, 0.001));
      expect(realProgram.remaining(now), const Duration(minutes: 30));
      expect(realProgram.elapsed(now), const Duration(minutes: 30));
      expect(realProgram.remainingLabel(now), '30m left');
      expect(realProgram.elapsedLabel(now), '30m in');
    });

    test('handles past and future times gracefully', () {
      final past = DateTime(2026, 11, 23, 16, 0);
      expect(realProgram.isLive(past), isFalse);
      expect(realProgram.isPast(past), isTrue);
      expect(realProgram.progress(past), 1.0);
      expect(realProgram.remaining(past), Duration.zero);

      final future = DateTime(2026, 11, 23, 12, 0);
      expect(realProgram.isLive(future), isFalse);
      expect(realProgram.isUpcoming(future), isTrue);
      expect(realProgram.progress(future), 0.0);
    });

    test('serializes to and from JSON including isEstimated', () {
      final json = estimatedProgram.toJson();
      final revived = EpgProgram.fromJson(json);

      expect(revived.id, estimatedProgram.id);
      expect(revived.channelId, estimatedProgram.channelId);
      expect(revived.title, estimatedProgram.title);
      expect(revived.isEstimated, isTrue);
      expect(revived.timeRange, isEmpty);
    });
  });

  group('EpgService', () {
    late EpgService service;
    const testChannel = Channel(
      id: 'bbc-news-live',
      name: 'BBC News',
      country: 'GB',
      categories: ['news'],
      languages: ['eng'],
      sources: [
        StreamSource(
          url: 'https://example.com/live.m3u8',
          quality: '1080p',
        ),
      ],
    );

    setUp(() {
      service = EpgService();
    });

    test('returns empty schedule by default without generating fake schedules', () {
      final targetDate = DateTime(2026, 11, 23);
      final schedule = service.getSchedule(testChannel, targetDate);

      expect(schedule.channelId, testChannel.id);
      expect(schedule.programs, isEmpty);
      expect(schedule.hasRealPrograms, isFalse);
      expect(service.getCurrentProgram(testChannel), isNull);
      expect(service.getNextProgram(testChannel), isNull);
    });

    test('stores and retrieves verified real program schedule', () {
      final targetDate = DateTime(2026, 11, 23);
      final now = DateTime(2026, 11, 23, 14, 15);
      final realProg = EpgProgram(
        id: 'p1',
        channelId: testChannel.id,
        title: 'BBC News at One',
        description: 'National and international news.',
        category: 'News',
        start: DateTime(2026, 11, 23, 14, 0),
        stop: DateTime(2026, 11, 23, 15, 0),
        isEstimated: false,
      );
      final nextProg = EpgProgram(
        id: 'p2',
        channelId: testChannel.id,
        title: 'BBC World News America',
        description: 'Evening edition.',
        category: 'News',
        start: DateTime(2026, 11, 23, 15, 0),
        stop: DateTime(2026, 11, 23, 16, 0),
        isEstimated: false,
      );

      service.setSchedule(testChannel.id, targetDate, [realProg, nextProg]);

      final schedule = service.getSchedule(testChannel, targetDate);
      expect(schedule.hasRealPrograms, isTrue);
      expect(schedule.programs.length, 2);

      final current = service.getCurrentProgram(testChannel, now);
      expect(current, isNotNull);
      expect(current!.title, 'BBC News at One');
      expect(current.timeRange, '14:00 – 15:00');

      final next = service.getNextProgram(testChannel, now);
      expect(next, isNotNull);
      expect(next!.title, 'BBC World News America');
    });
  });

  group('EPG Widgets', () {
    const testChannel = Channel(
      id: 'nasa-tv',
      name: 'NASA TV',
      country: 'US',
      categories: ['documentary', 'science'],
      languages: ['eng'],
      sources: [
        StreamSource(
          url: 'https://example.com/nasa.m3u8',
          quality: '720p',
        ),
      ],
    );

    testWidgets('EpgNowPlayingCard renders nothing when no real EPG data is available', (tester) async {
      final theme = AppTheme.build(const Settings());
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            theme: theme,
            home: const Scaffold(
              body: EpgNowPlayingCard(channel: testChannel),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('ON AIR NOW'), findsNothing);
      expect(find.byType(LinearProgressIndicator), findsNothing);
    });

    testWidgets('EpgPlayerOverlayBar renders nothing when no real EPG data is available', (tester) async {
      final theme = AppTheme.build(const Settings());
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            theme: theme,
            home: Scaffold(
              body: EpgPlayerOverlayBar(
                channel: testChannel,
                onTapGuide: () {},
                onSyncToLive: () {},
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('LIVE'), findsNothing);
      expect(find.byType(LinearProgressIndicator), findsNothing);
    });

    testWidgets('Widgets render verified real program data when provided', (tester) async {
      final epgService = EpgService();
      final now = DateTime.now();
      final realProg = EpgProgram(
        id: 'real-1',
        channelId: testChannel.id,
        title: 'NASA Live ISS Feed',
        description: 'Live broadcast from the International Space Station.',
        category: 'Science',
        start: now.subtract(const Duration(minutes: 20)),
        stop: now.add(const Duration(minutes: 40)),
        isEstimated: false,
      );

      epgService.setSchedule(testChannel.id, now, [realProg]);

      var syncTapped = false;
      var guideTapped = false;
      final theme = AppTheme.build(const Settings());

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            epgServiceProvider.overrideWithValue(epgService),
          ],
          child: MaterialApp(
            theme: theme,
            home: Scaffold(
              body: Column(
                children: [
                  EpgNowPlayingCard(channel: testChannel),
                  EpgPlayerOverlayBar(
                    channel: testChannel,
                    onTapGuide: () => guideTapped = true,
                    onSyncToLive: () => syncTapped = true,
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('NASA Live ISS Feed'), findsNWidgets(2));
      expect(find.text('ON AIR NOW'), findsOneWidget);
      expect(find.text('LIVE'), findsOneWidget);

      await tester.tap(find.text('LIVE'));
      expect(syncTapped, isTrue);

      await tester.tap(find.byType(EpgPlayerOverlayBar));
      expect(guideTapped, isTrue);
    });
  });
}
