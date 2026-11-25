import 'package:flutter_test/flutter_test.dart';
import 'package:nightsuntv/core/utils/text.dart';
import 'package:nightsuntv/data/models/catalog.dart';
import 'package:nightsuntv/data/models/channel.dart';
import 'package:nightsuntv/data/models/stream_source.dart';
import 'package:nightsuntv/data/services/search_engine.dart';

Channel channel(
  String id,
  String name, {
  String country = 'GB',
  List<String> categories = const ['news'],
  List<String> languages = const ['eng'],
  List<String> altNames = const [],
  bool nsfw = false,
  int sources = 1,
  int? launched,
}) {
  return Channel(
    id: id,
    name: name,
    country: country,
    categories: categories,
    languages: languages,
    altNames: altNames,
    nsfw: nsfw,
    launched: launched,
    sources: [
      for (var i = 0; i < sources; i++)
        StreamSource(
          url: 'https://example.com/$id-$i.m3u8',
          quality: i == 0 ? '1080p' : null,
        ),
    ],
  );
}

Catalog catalog() {
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
        code: 'FR',
        name: 'France',
        flag: '🇫🇷',
        languages: ['fra'],
      ),
      CatalogCountry(
        code: 'US',
        name: 'United States',
        flag: '🇺🇸',
        languages: ['eng'],
      ),
    ],
    languages: const [
      CatalogLanguage(code: 'eng', name: 'English'),
      CatalogLanguage(code: 'fra', name: 'French'),
    ],
    channels: [
      channel(
        'BBCNews.uk',
        'BBC News',
        sources: 3,
        altNames: const ['British Broadcasting Corporation'],
      ),
      channel(
        'France24.fr',
        'France 24',
        country: 'FR',
        languages: const ['fra'],
      ),
      channel(
        'CartoonNetwork.us',
        'Cartoon Network',
        country: 'US',
        categories: const ['kids'],
      ),
      channel(
        'CafeTV.fr',
        'Canal Café',
        country: 'FR',
        languages: const ['fra'],
      ),
      channel(
        'Adult.us',
        'Adult Channel',
        country: 'US',
        nsfw: true,
      ),
    ],
    sourceCount: 7,
    nsfwCount: 1,
  );
}

void main() {
  test('normalizes accents, punctuation and scripts without losing words', () {
    expect(normalizeForSearch('Café 24/7'), 'cafe 24 7');
    expect(normalizeForSearch("O'Brien"), 'obrien');
    expect(normalizeForSearch('BBC & ITV'), 'bbc and itv');
    expect(normalizeForSearch('Новости'), 'novosti');
    expect(normalizeForSearch('العربية'), 'العربية');
    expect(compactForSearch('BBC One'), 'bbcone');
    expect(channelInitials('BBC One'), 'BO');
    expect(channelInitials('tv'), 'TV');
    expect(formatCount(10352), '10,352');
  });

  test('exact and prefix names rank above metadata-only matches', () {
    final engine = SearchEngine(catalog());
    final results = engine.search('bbc');
    expect(results.channels.first.name, 'BBC News');
    expect(results.totalMatches, greaterThan(0));
    expect(
      results.channels.every((channel) => channel.name != 'Adult Channel'),
      isTrue,
    );
  });

  test('metadata, country, language and category all participate', () {
    final engine = SearchEngine(catalog());
    expect(engine.search('france').channels.first.name, 'France 24');
    expect(
      engine.search('kids').channels.map((channel) => channel.name),
      contains('Cartoon Network'),
    );
    expect(
      engine.search('french').channels.map((channel) => channel.name),
      containsAll(['France 24', 'Canal Café']),
    );
    expect(
      engine.search('united kingdom').channels.first.name,
      'BBC News',
    );
    expect(engine.search('cafe').channels.first.name, 'Canal Café');
    expect(engine.search('british broadcasting').channels.first.name, 'BBC News');
  });

  test('country and category suggestions are capped and relevant', () {
    final engine = SearchEngine(catalog());
    final results = engine.search('fr');
    expect(results.countries.map((country) => country.code), contains('FR'));
    expect(results.categories, isEmpty);
  });

  test('adult channels are hidden unless explicitly included', () {
    final safe = SearchEngine(catalog());
    expect(safe.search('adult').channels, isEmpty);

    final full = SearchEngine(catalog(), includeAdult: true);
    expect(full.search('adult').channels.single.name, 'Adult Channel');
  });

  test('one-character queries do not scan channel metadata', () {
    final engine = SearchEngine(catalog());
    final results = engine.search('b');
    expect(results.channels, isNotEmpty);
    expect(
      results.channels.every(
        (channel) => normalizeForSearch(channel.name).startsWith('b'),
      ),
      isTrue,
    );
  });

  test('result list is bounded while count stays honest', () {
    final engine = SearchEngine(catalog());
    final results = engine.search('e', limit: 1);
    expect(results.channels.length, lessThanOrEqualTo(1));
    expect(results.totalMatches, greaterThanOrEqualTo(results.channels.length));
  });
}
