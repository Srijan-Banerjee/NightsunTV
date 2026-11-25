import 'package:flutter_test/flutter_test.dart';
import 'package:nightsuntv/data/models/catalog.dart';
import 'package:nightsuntv/data/models/channel.dart';
import 'package:nightsuntv/data/models/stream_source.dart';

Channel channel(
  String id,
  String name,
  String country, {
  List<String> categories = const ['news'],
  int sources = 2,
  String? logo = 'https://example.com/logo.png',
  int? launched,
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
    logo: logo,
    logoFormat: logo == null ? null : 'PNG',
    launched: launched,
    sources: [
      for (var i = 0; i < sources; i++)
        StreamSource(url: 'https://example.com/$id-$i.m3u8'),
    ],
  );
}

void main() {
  final catalog = Catalog(
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
        code: 'FR',
        name: 'France',
        flag: '🇫🇷',
        languages: ['fra'],
      ),
    ],
    languages: const [CatalogLanguage(code: 'eng', name: 'English')],
    channels: [
      channel('Zed.uk', 'Zed News', 'GB', launched: 2024),
      channel('Alpha.uk', 'Alpha TV', 'GB', categories: ['news']),
      channel('Beta.fr', 'Beta', 'FR', sources: 1, launched: 2026),
      channel('Kids.us', 'Kids Time', 'US', categories: ['kids'], sources: 4),
      channel(
        'Hidden.us',
        'Hidden',
        'US',
        sources: 1,
        nsfw: true,
        logo: null,
      ),
    ],
    sourceCount: 10,
    nsfwCount: 1,
  );

  test('builds lookup indexes and resolves country metadata', () {
    expect(catalog.byId['Alpha.uk']?.name, 'Alpha TV');
    expect(catalog.countryOf(catalog.byId['Beta.fr']!).name, 'France');
    expect(catalog.countryOf(catalog.byId['Kids.us']!).name, 'International');
    expect(catalog.categoryName('news'), 'News');
    expect(catalog.categoryName('unknown-genre'), 'Unknown Genre');
  });

  test('country counts and top countries reflect the lineup', () {
    expect(catalog.countryCounts['GB'], 2);
    expect(catalog.countryCounts['US'], 2);
    final top = catalog.topCountries(limit: 4);
    expect(top, isNotEmpty);
    expect(top.first.code, anyOf('GB', 'US'));
  });

  test('strong signals only use mirrored, logo-bearing channels', () {
    final strong = catalog.strongSignals(limit: 10, now: DateTime(2026, 11, 23));
    expect(strong.map((channel) => channel.id), contains('Kids.us'));
    expect(strong.map((channel) => channel.id), isNot(contains('Beta.fr')));
    expect(strong.map((channel) => channel.id), isNot(contains('Hidden.us')));
  });

  test('new arrivals are sorted by launch year descending', () {
    final arrivals = catalog.newArrivals(limit: 4);
    expect(arrivals.first.id, 'Beta.fr');
    expect(arrivals.map((channel) => channel.id), isNot(contains('Hidden.us')));
  });

  test('related channels prefer same country and category', () {
    final alpha = catalog.byId['Alpha.uk']!;
    final related = catalog.relatedTo(alpha, limit: 4);
    expect(related, isNotEmpty);
    expect(related.first.country, 'GB');
  });

  test('json parsing filters broken rows and keeps counts', () {
    final parsed = Catalog.fromJson({
      'generatedAt': '2026-11-23T02:10:04Z',
      'categories': [
        {'id': 'news', 'name': 'News'},
      ],
      'countries': [
        {'code': 'gb', 'name': 'United Kingdom', 'flag': '🇬🇧'},
      ],
      'languages': [
        {'code': 'eng', 'name': 'English'},
      ],
      'counts': {'sources': 42, 'nsfw': 1},
      'channels': [
        {
          'id': 'One.uk',
          'name': 'One',
          'country': 'gb',
          'categories': ['news'],
          'languages': ['eng'],
          'sources': [
            {'url': 'https://example.com/one.m3u8'},
          ],
        },
        {
          'id': 'Broken.uk',
          'name': 'Broken',
          'sources': <dynamic>[],
        },
        {
          'id': 'One.uk',
          'name': 'Duplicate',
          'sources': [
            {'url': 'https://example.com/dup.m3u8'},
          ],
        },
      ],
    });
    expect(parsed.channels, hasLength(1));
    expect(parsed.sourceCount, 42);
    expect(parsed.countries.single.code, 'GB');
    expect(parsed.generatedAt, DateTime.utc(2026, 11, 23, 2, 10, 4));
  });
}
