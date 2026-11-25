import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nightsuntv/app.dart';
import 'package:nightsuntv/data/models/catalog.dart';
import 'package:nightsuntv/data/models/channel.dart';
import 'package:nightsuntv/data/models/stream_source.dart';
import 'package:nightsuntv/state/prefs.dart';
import 'package:nightsuntv/state/providers.dart';
import 'package:shared_preferences/shared_preferences.dart';

Channel channel(
  String id,
  String name, {
  String country = 'GB',
  List<String> categories = const ['news'],
  bool nsfw = false,
  List<String> altNames = const [],
}) {
  return Channel(
    id: id,
    name: name,
    country: country,
    categories: categories,
    languages: const ['eng'],
    altNames: altNames,
    nsfw: nsfw,
    launched: 2024,
    sources: [
      StreamSource(
        url: 'https://example.com/$id.m3u8',
        quality: '1080p',
      ),
    ],
  );
}

Catalog fixture() {
  return Catalog(
    generatedAt: DateTime.utc(2026, 11, 23),
    categories: const [
      CatalogCategory(id: 'news', name: 'News'),
      CatalogCategory(id: 'kids', name: 'Kids'),
    ],
    countries: const [
      CatalogCountry(
        code: 'GB',
        name: 'United Kingdom',
        flag: '🇬🇧',
        languages: ['eng'],
      ),
      CatalogCountry(
        code: 'US',
        name: 'United States',
        flag: '🇺🇸',
        languages: ['eng'],
      ),
    ],
    languages: const [CatalogLanguage(code: 'eng', name: 'English')],
    channels: [
      channel('BBCNews.uk', 'BBC News'),
      channel('CBeebies.uk', 'CBeebies', categories: ['kids']),
      channel('PBS.us', 'PBS', country: 'US'),
      channel('Late.us', 'Late Night', country: 'US', nsfw: true),
    ],
    sourceCount: 4,
    nsfwCount: 1,
  );
}

Future<SharedPreferences> prefsWith(Map<String, Object> values) async {
  SharedPreferences.setMockInitialValues(values);
  return SharedPreferences.getInstance();
}

Widget app(SharedPreferences prefs, Catalog catalog) {
  return ProviderScope(
    overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
      catalogProvider.overrideWith((ref) async => catalog),
      refreshInfoProvider.overrideWith((ref) async => null),
    ],
    child: const NightsunTvApp(),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('onboarding leads into a working five-tab shell', (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final prefs = await prefsWith({});
    final catalog = fixture();
    await tester.pumpWidget(app(prefs, catalog));
    await tester.pumpAndSettle();

    expect(find.text('Continue'), findsOneWidget);
    for (var step = 0; step < 6; step++) {
      final start = find.text('Start watching');
      if (start.evaluate().isNotEmpty) {
        await tester.tap(start);
        await tester.pumpAndSettle();
        break;
      }
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();
    }
    await tester.pumpAndSettle();

    expect(prefs.getBool('settings.onboarding'), isTrue);
    expect(find.text('Home'), findsWidgets);
    expect(find.text('Browse'), findsWidgets);
    expect(find.text('Search'), findsWidgets);
    expect(find.text('Library'), findsWidgets);
    expect(find.text('Settings'), findsWidgets);

    // Browse and its filter sheet.
    await tester.tap(find.text('Browse').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Filters'));
    await tester.pumpAndSettle();
    expect(find.text('Refine the lineup'), findsOneWidget);
    await tester.tapAt(const Offset(180, 16));
    await tester.pumpAndSettle();

    // Search and the channel detail page.
    await tester.tap(find.text('Search').last);
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'bbc');
    await tester.pumpAndSettle();
    expect(find.text('BBC News'), findsWidgets);
    await tester.tap(find.text('BBC News').first);
    await tester.pumpAndSettle();
    expect(find.text('Watch live'), findsOneWidget);
    expect(find.text('Streams'), findsWidgets);

    await tester.tap(find.byIcon(Icons.favorite_border_rounded).first);
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.favorite_rounded), findsWidgets);

    await tester.pageBack();
    await tester.pumpAndSettle();

    // The favourite is persisted into the Library tab.
    await tester.tap(find.text('Library').last);
    await tester.pumpAndSettle();
    expect(find.text('BBC News'), findsWidgets);

    // Settings: accent, theme and lineup information.
    await tester.tap(find.text('Settings').last);
    await tester.pumpAndSettle();
    expect(find.text('APPEARANCE'), findsOneWidget);
    await tester.tap(find.text('Pure black'));
    await tester.pumpAndSettle();

    // Verify Adult channels toggle is removed from settings
    expect(find.text('Adult channels'), findsNothing);

    await tester.scrollUntilVisible(
      find.text('Refresh lineup'),
      260,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.pumpAndSettle();
    expect(find.text('Refresh lineup'), findsOneWidget);
  });
}
