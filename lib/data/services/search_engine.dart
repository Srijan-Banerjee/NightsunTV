import '../models/catalog.dart';
import '../models/channel.dart';
import '../../core/utils/text.dart';

class SearchResults {
  const SearchResults({
    required this.query,
    required this.channels,
    required this.countries,
    required this.categories,
    required this.totalMatches,
    required this.truncated,
  });

  final String query;
  final List<Channel> channels;
  final List<CatalogCountry> countries;
  final List<CatalogCategory> categories;
  final int totalMatches;
  final bool truncated;

  static const empty = SearchResults(
    query: '',
    channels: [],
    countries: [],
    categories: [],
    totalMatches: 0,
    truncated: false,
  );

  bool get isEmpty =>
      channels.isEmpty && countries.isEmpty && categories.isEmpty;
}

class _IndexedChannel {
  _IndexedChannel(this.channel, Catalog catalog) {
    name = normalizeForSearch(channel.name);
    compactName = compactForSearch(name);
    alt = normalizeForSearch(channel.altNames.join(' '));
    final country = catalog.countryOf(channel);
    final categoryNames = channel.categories
        .map(catalog.categoryName)
        .join(' ');
    final languageNames = catalog.languageNames(channel).join(' ');
    meta = normalizeForSearch(
      '${country.name} ${country.code} $categoryNames $languageNames '
      '${channel.network ?? ''}',
    );
    haystack = '$name $alt $meta';
  }

  final Channel channel;
  late final String name;
  late final String compactName;
  late final String alt;
  late final String meta;
  late final String haystack;
}

/// Relevance-ranked, metadata-aware search over the bundled catalog.
///
/// Everything is indexed once; a query only scans the in-memory entries, so
/// results arrive within a frame on a phone-class CPU.
class SearchEngine {
  SearchEngine(this.catalog, {this.includeAdult = false}) {
    _entries = [
      for (final channel in catalog.channels)
        if (includeAdult || !channel.nsfw) _IndexedChannel(channel, catalog),
    ];
    _sortedCountries = [...catalog.countries]
      ..sort((a, b) => a.name.compareTo(b.name));
    _sortedCategories = [...catalog.categories]
      ..sort((a, b) => a.name.compareTo(b.name));
  }

  final Catalog catalog;
  final bool includeAdult;
  late final List<_IndexedChannel> _entries;
  late final List<CatalogCountry> _sortedCountries;
  late final List<CatalogCategory> _sortedCategories;

  SearchResults search(String rawQuery, {int limit = 120}) {
    final query = normalizeForSearch(rawQuery);
    if (query.isEmpty) return SearchResults.empty;

    final tokens = query.split(' ').where((token) => token.isNotEmpty).toList();
    final compactQuery = compactForSearch(query);
    final isSingleCharacter = query.length < 2;

    final countries = <CatalogCountry>[];
    final categories = <CatalogCategory>[];
    if (!isSingleCharacter) {
      for (final country in _sortedCountries) {
        final name = normalizeForSearch(country.name);
        final code = country.code.toLowerCase();
        if (name.startsWith(query) ||
            name.split(' ').any((word) => word.startsWith(query)) ||
            code == query ||
            code.startsWith(query)) {
          countries.add(country);
          if (countries.length >= 6) break;
        }
      }
      for (final category in _sortedCategories) {
        final name = normalizeForSearch(category.name);
        if (name.startsWith(query) ||
            name.split(' ').any((word) => word.startsWith(query))) {
          categories.add(category);
          if (categories.length >= 5) break;
        }
      }
    }

    final scored = <_ScoredChannel>[];
    var total = 0;
    for (final entry in _entries) {
      final score = _score(entry, query, compactQuery, tokens, isSingleCharacter);
      if (score < 0) continue;
      total++;
      if (scored.length < limit) {
        scored.add(_ScoredChannel(entry.channel, score, entry.name));
      } else {
        // Keep the list bounded: replace the worst result if this one is
        // better, then re-sort. limit is small, so this stays cheap.
        var worstIndex = 0;
        for (var i = 1; i < scored.length; i++) {
          if (scored[i].compareTo(scored[worstIndex]) > 0) worstIndex = i;
        }
        if (score > scored[worstIndex].score) {
          scored[worstIndex] = _ScoredChannel(entry.channel, score, entry.name);
        }
      }
    }
    scored.sort();

    return SearchResults(
      query: rawQuery.trim(),
      channels: [for (final item in scored) item.channel],
      countries: countries,
      categories: categories,
      totalMatches: total,
      truncated: total > scored.length,
    );
  }

  int _score(
    _IndexedChannel entry,
    String query,
    String compactQuery,
    List<String> tokens,
    bool isSingleCharacter,
  ) {
    final name = entry.name;
    var score = 0;

    if (name == query) {
      score += 1200;
    } else if (name.startsWith(query)) {
      score += 960;
    } else if (entry.compactName.startsWith(compactQuery)) {
      score += 880;
    } else if (_startsAtWord(name, query)) {
      score += 800;
    } else if (name.contains(query)) {
      score += 640;
    } else if (entry.compactName.contains(compactQuery)) {
      score += 560;
    } else if (entry.alt.contains(query)) {
      score += 420;
    } else if (isSingleCharacter) {
      return -1;
    }

    for (var i = 0; i < tokens.length; i++) {
      final token = tokens[i];
      if (name == token) {
        score += 180;
      } else if (_startsAtWord(name, token)) {
        score += 125;
      } else if (name.contains(token)) {
        score += 55;
      } else if (entry.alt.contains(token)) {
        score += 38;
      } else if (!isSingleCharacter && entry.meta.contains(token)) {
        score += 22;
      } else {
        return -1;
      }
      if (i == 0 && name.startsWith(token)) score += 30;
    }

    if (score == 0) return -1;
    if (entry.channel.sources.length > 1) score += 9;
    if (entry.channel.hasLogo) score += 4;
    if (entry.channel.altNames.any((alias) => normalizeForSearch(alias) == query)) {
      score += 25;
    }
    return score;
  }

  bool _startsAtWord(String haystack, String needle) {
    var index = haystack.indexOf(needle);
    while (index >= 0) {
      if (index == 0 || haystack[index - 1] == ' ') return true;
      index = haystack.indexOf(needle, index + 1);
    }
    return false;
  }
}

class _ScoredChannel implements Comparable<_ScoredChannel> {
  _ScoredChannel(this.channel, this.score, this.normalizedName);

  final Channel channel;
  final int score;
  final String normalizedName;

  @override
  int compareTo(_ScoredChannel other) {
    final byScore = other.score.compareTo(score);
    if (byScore != 0) return byScore;
    return normalizedName.compareTo(other.normalizedName);
  }
}
