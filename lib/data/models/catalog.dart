import 'channel.dart';

class CatalogCategory {
  const CatalogCategory({required this.id, required this.name});
  final String id;
  final String name;

  factory CatalogCategory.fromJson(Map<String, dynamic> json) =>
      CatalogCategory(
        id: (json['id'] as String?)?.trim() ?? '',
        name: (json['name'] as String?)?.trim() ?? '',
      );
}

class CatalogCountry {
  const CatalogCountry({
    required this.code,
    required this.name,
    required this.flag,
    required this.languages,
  });

  final String code;
  final String name;
  final String flag;
  final List<String> languages;

  factory CatalogCountry.fromJson(Map<String, dynamic> json) => CatalogCountry(
        code: (json['code'] as String?)?.trim().toUpperCase() ?? 'ZZ',
        name: (json['name'] as String?)?.trim() ?? 'International',
        flag: (json['flag'] as String?)?.trim() ?? '🌐',
        languages: (json['languages'] as List?)
                ?.whereType<String>()
                .toList(growable: false) ??
            const [],
      );
}

class CatalogLanguage {
  const CatalogLanguage({required this.code, required this.name});
  final String code;
  final String name;

  factory CatalogLanguage.fromJson(Map<String, dynamic> json) =>
      CatalogLanguage(
        code: (json['code'] as String?)?.trim() ?? '',
        name: (json['name'] as String?)?.trim() ?? '',
      );
}

/// The complete bundled catalog, pre-indexed for the screens that need it.
class Catalog {
  Catalog({
    required this.generatedAt,
    required this.categories,
    required this.countries,
    required this.languages,
    required this.channels,
    required this.sourceCount,
    required this.nsfwCount,
  });

  final DateTime? generatedAt;
  final List<CatalogCategory> categories;
  final List<CatalogCountry> countries;
  final List<CatalogLanguage> languages;
  final List<Channel> channels;
  final int sourceCount;
  final int nsfwCount;

  late final Map<String, Channel> byId = {
    for (final channel in channels) channel.id: channel,
  };
  late final Map<String, CatalogCategory> categoriesById = {
    for (final category in categories) category.id: category,
  };
  late final Map<String, CatalogCountry> countriesByCode = {
    for (final country in countries) country.code: country,
  };
  late final Map<String, CatalogLanguage> languagesByCode = {
    for (final language in languages) language.code: language,
  };
  late final Map<String, List<Channel>> channelsByCountry = _group(
    (channel) => channel.country,
  );
  late final Map<String, List<Channel>> channelsByCategory = _group(
    (channel) => channel.primaryCategory,
    alsoFor: (channel) => channel.categories,
  );
  late final Map<String, List<Channel>> channelsByLanguage = _group(
    (channel) => channel.languages.isEmpty ? 'und' : channel.languages.first,
    alsoFor: (channel) => channel.languages,
  );

  late final Map<String, int> countryCounts = {
    for (final entry in channelsByCountry.entries) entry.key: entry.value.length,
  };
  late final Map<String, int> categoryCounts = {
    for (final category in categories)
      category.id: channelsByCategory[category.id]?.length ?? 0,
  };

  factory Catalog.fromJson(Map<String, dynamic> json) {
    List<Map<String, dynamic>> objectList(Object? value) =>
        value is List ? value.whereType<Map<String, dynamic>>().toList(growable: false) : const [];

    final channels = <Channel>[];
    final seen = <String>{};
    for (final raw in objectList(json['channels'])) {
      final channel = Channel.fromJson(raw);
      if (channel.id.isEmpty || channel.name.isEmpty || channel.sources.isEmpty) continue;
      if (seen.add(channel.id)) channels.add(channel);
    }
    channels.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

    final counts = json['counts'];
    final countMap = counts is Map<String, dynamic> ? counts : const <String, dynamic>{};
    final sourceCount = countMap['sources'] is int
        ? countMap['sources'] as int
        : channels.fold<int>(0, (total, channel) => total + channel.sources.length);

    final generated = json['generatedAt'];
    return Catalog(
      generatedAt: generated is String ? DateTime.tryParse(generated) : null,
      categories: objectList(json['categories'])
          .map(CatalogCategory.fromJson)
          .where((category) => category.id.isNotEmpty)
          .toList(growable: false),
      countries: objectList(json['countries'])
          .map(CatalogCountry.fromJson)
          .where((country) => country.code.isNotEmpty)
          .toList(growable: false),
      languages: objectList(json['languages'])
          .map(CatalogLanguage.fromJson)
          .where((language) => language.code.isNotEmpty)
          .toList(growable: false),
      channels: channels,
      sourceCount: sourceCount,
      nsfwCount: countMap['nsfw'] is int
          ? countMap['nsfw'] as int
          : channels.where((channel) => channel.nsfw).length,
    );
  }

  Map<String, List<Channel>> _group(
    String Function(Channel) keyOf, {
    Iterable<String> Function(Channel)? alsoFor,
  }) {
    final map = <String, List<Channel>>{};
    for (final channel in channels) {
      final keys = alsoFor == null ? [keyOf(channel)] : alsoFor(channel);
      for (final key in keys) {
        map.putIfAbsent(key, () => []).add(channel);
      }
    }
    for (final list in map.values) {
      list.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    }
    return map;
  }

  CatalogCountry countryOf(Channel channel) =>
      countriesByCode[channel.country] ??
      const CatalogCountry(
        code: 'ZZ',
        name: 'International',
        flag: '🌐',
        languages: [],
      );

  CatalogCategory? categoryOf(String id) => categoriesById[id];

  String categoryName(String id) => categoriesById[id]?.name ?? _titleCase(id);

  List<String> languageNames(Channel channel) => [
        for (final code in channel.languages)
          languagesByCode[code]?.name ?? code,
      ];

  String? languageName(String code) => languagesByCode[code]?.name;

  List<CatalogCountry> topCountries({int limit = 12, bool includeInternational = true}) {
    final sorted = countries
        .where((country) =>
            (includeInternational || country.code != 'ZZ') &&
            (countryCounts[country.code] ?? 0) > 0)
        .toList()
      ..sort((a, b) {
        final diff = (countryCounts[b.code] ?? 0).compareTo(countryCounts[a.code] ?? 0);
        return diff != 0 ? diff : a.name.compareTo(b.name);
      });
    return sorted.take(limit).toList(growable: false);
  }

  /// Channels likely to stay on air: more than one mirror and an identifiable
  /// logo. Rotating the head of the list daily keeps the shelf fresh without
  /// inventing popularity metrics.
  List<Channel> strongSignals({int limit = 12, DateTime? now}) {
    final candidates = channels
        .where((channel) => channel.sources.length > 1 && channel.hasLogo)
        .toList()
      ..sort((a, b) {
        final bySources = b.sources.length.compareTo(a.sources.length);
        if (bySources != 0) return bySources;
        return a.name.toLowerCase().compareTo(b.name.toLowerCase());
      });
    if (candidates.isEmpty) return const [];
    final day = (now ?? DateTime.now()).difference(DateTime(2024)).inDays;
    final pool = candidates.take(80).toList(growable: false);
    final start = day % pool.length;
    return [
      for (var i = 0; i < pool.length && i < limit; i++) pool[(start + i) % pool.length],
    ];
  }

  List<Channel> newArrivals({int limit = 12}) {
    final candidates = channels
        .where((channel) => channel.launched != null && channel.hasLogo)
        .toList()
      ..sort((a, b) {
        final byYear = (b.launched ?? 0).compareTo(a.launched ?? 0);
        if (byYear != 0) return byYear;
        return a.name.toLowerCase().compareTo(b.name.toLowerCase());
      });
    return candidates.take(limit).toList(growable: false);
  }

  /// Same country and category first, then same country, then same category.
  List<Channel> relatedTo(Channel channel, {int limit = 12}) {
    final seen = <String>{channel.id};
    final result = <Channel>[];
    void addAll(Iterable<Channel> source) {
      for (final candidate in source) {
        if (seen.add(candidate.id)) {
          result.add(candidate);
          if (result.length >= limit) return;
        }
      }
    }

    final countryChannels = channelsByCountry[channel.country] ?? const <Channel>[];
    addAll(countryChannels.where(
      (candidate) => candidate.categories.any(channel.categories.contains),
    ));
    addAll(countryChannels);
    for (final category in channel.categories) {
      addAll(channelsByCategory[category] ?? const <Channel>[]);
      if (result.length >= limit) break;
    }
    return result;
  }

  static String _titleCase(String text) {
    if (text.isEmpty) return 'General';
    return text
        .split(RegExp(r'[_\s-]+'))
        .map((word) => word.isEmpty
            ? word
            : '${word[0].toUpperCase()}${word.substring(1)}')
        .join(' ');
  }
}
