import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nightsuntv/core/theme/app_theme.dart';
import 'package:nightsuntv/core/widgets/channel_logo.dart';
import 'package:nightsuntv/data/models/channel.dart';
import 'package:nightsuntv/data/models/stream_source.dart';
import 'package:nightsuntv/state/settings_controller.dart';

void main() {
  testWidgets('theme exposes the NightSun palette and monogram fallback',
      (tester) async {
    final theme = AppTheme.build(const Settings());
    late AppLook look;
    await tester.pumpWidget(
      MaterialApp(
        theme: theme,
        home: Scaffold(
          body: Builder(
            builder: (context) {
              look = context.look;
              return ChannelLogo(
                channel: const Channel(
                  id: 'BBCOne.uk',
                  name: 'BBC One',
                  country: 'GB',
                  categories: ['general'],
                  languages: ['eng'],
                  sources: [
                    StreamSource(url: 'https://example.com/bbc.m3u8'),
                  ],
                ),
                width: 60,
                height: 60,
              );
            },
          ),
        ),
      ),
    );

    expect(look.variant, ThemeVariant.midnight);
    expect(look.palette.name, 'Solar');
    expect(look.colors.background, const Color(0xFF070B14));
    expect(find.text('BO'), findsOneWidget);
  });

  testWidgets('pure black theme and every accent build without collisions',
      (tester) async {
    for (final accent in AccentChoice.values) {
      final theme = AppTheme.build(
        Settings(themeVariant: ThemeVariant.pureBlack, accent: accent),
      );
      await tester.pumpWidget(
        MaterialApp(
          theme: theme,
          home: const Scaffold(body: SizedBox()),
        ),
      );
      await tester.pump();
      expect(tester.takeException(), isNull);
    }
  });
}
