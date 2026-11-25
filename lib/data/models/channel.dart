import 'stream_source.dart';

/// A single free live TV channel from the iptv-org catalog.
class Channel {
  const Channel({
    required this.id,
    required this.name,
    required this.country,
    required this.categories,
    required this.languages,
    required this.sources,
    this.altNames = const [],
    this.network,
    this.website,
    this.launched,
    this.logo,
    this.logoFormat,
    this.nsfw = false,
  });

  final String id;
  final String name;
  final List<String> altNames;
  final String country;
  final List<String> categories;
  final List<String> languages;
  final String? network;
  final String? website;
  final int? launched;
  final bool nsfw;
  final String? logo;
  final String? logoFormat;
  final List<StreamSource> sources;

  factory Channel.fromJson(Map<String, dynamic> json) {
    String text(Object? value) {
      if (value is! String) return '';
      return value.trim();
    }

    String? optionalText(Object? value) {
      final result = text(value);
      return result.isEmpty ? null : result;
    }

    List<String> textList(Object? value) {
      if (value is! List) return const [];
      return value
          .whereType<String>()
          .map((item) => item.trim())
          .where((item) => item.isNotEmpty)
          .toList(growable: false);
    }

    final rawSources = json['sources'];
    final sources = <StreamSource>[];
    if (rawSources is List) {
      for (final raw in rawSources) {
        if (raw is Map<String, dynamic>) {
          final source = StreamSource.fromJson(raw);
          if (source.url.isNotEmpty) sources.add(source);
        }
      }
    }

    return Channel(
      id: text(json['id']),
      name: text(json['name']),
      altNames: textList(json['altNames']),
      country: text(json['country']).isEmpty ? 'ZZ' : text(json['country']),
      categories: textList(json['categories']),
      languages: textList(json['languages']),
      network: optionalText(json['network']),
      website: optionalText(json['website']),
      launched: json['launched'] is int ? json['launched'] as int : null,
      nsfw: json['nsfw'] == true,
      logo: optionalText(json['logo']),
      logoFormat: optionalText(json['logoFormat']),
      sources: sources,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        if (altNames.isNotEmpty) 'altNames': altNames,
        'country': country,
        if (categories.isNotEmpty) 'categories': categories,
        if (languages.isNotEmpty) 'languages': languages,
        if (network != null) 'network': network,
        if (website != null) 'website': website,
        if (launched != null) 'launched': launched,
        'nsfw': nsfw,
        if (logo != null) 'logo': logo,
        if (logoFormat != null) 'logoFormat': logoFormat,
        'sources': sources.map((source) => source.toJson()).toList(growable: false),
      };

  String get primaryCategory =>
      categories.isNotEmpty ? categories.first : 'general';

  bool get hasLogo => logo != null && logo!.isNotEmpty;

  bool get hasBackupSource => sources.length > 1;

  String get bestQuality {
    var best = 0;
    for (final source in sources) {
      if (source.qualityRank > best) best = source.qualityRank;
    }
    return best == 0 ? 'Auto' : '${best}p';
  }

  String get searchableAliases => altNames.join(' ');

  Channel copyWithSources(List<StreamSource> updated) => Channel(
        id: id,
        name: name,
        altNames: altNames,
        country: country,
        categories: categories,
        languages: languages,
        network: network,
        website: website,
        launched: launched,
        nsfw: nsfw,
        logo: logo,
        logoFormat: logoFormat,
        sources: updated,
      );

  @override
  bool operator ==(Object other) => other is Channel && other.id == id;

  @override
  int get hashCode => id.hashCode;
}
