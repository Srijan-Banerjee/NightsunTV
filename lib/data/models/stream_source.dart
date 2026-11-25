/// One playable source for a channel.
///
/// iptv-org can list several mirrors for the same channel. Some require a
/// specific user agent or referrer; those headers are preserved so ExoPlayer
/// can open streams that a plain GET would reject.
class StreamSource {
  const StreamSource({
    required this.url,
    this.quality,
    this.userAgent,
    this.referrer,
    this.title,
  });

  final String url;
  final String? quality;
  final String? userAgent;
  final String? referrer;
  final String? title;

  factory StreamSource.fromJson(Map<String, dynamic> json) {
    String? text(Object? value) {
      if (value is! String) return null;
      final trimmed = value.trim();
      return trimmed.isEmpty ? null : trimmed;
    }

    return StreamSource(
      url: text(json['url']) ?? '',
      quality: text(json['quality']),
      userAgent: text(json['userAgent']),
      referrer: text(json['referrer']),
      title: text(json['title']),
    );
  }

  Map<String, dynamic> toJson() => {
        'url': url,
        if (quality != null) 'quality': quality,
        if (userAgent != null) 'userAgent': userAgent,
        if (referrer != null) 'referrer': referrer,
        if (title != null) 'title': title,
      };

  bool get isHttps => url.toLowerCase().startsWith('https://');

  int get qualityRank {
    final normalized = quality?.toLowerCase() ?? '';
    if (normalized.contains('4k') || normalized.contains('2160')) return 2160;
    final match = RegExp(r'(\d{3,4})').firstMatch(normalized);
    return int.tryParse(match?.group(1) ?? '') ?? 0;
  }

  String get displayQuality {
    final q = quality?.trim();
    if (q == null || q.isEmpty) return 'Auto';
    return q;
  }

  /// A small, honest label for the transport used by the source.
  String get formatLabel {
    final path = Uri.tryParse(url)?.path.toLowerCase() ?? '';
    if (path.endsWith('.m3u8')) return 'HLS';
    if (path.endsWith('.mpd')) return 'DASH';
    if (path.endsWith('.ts') || path.endsWith('.mts')) return 'MPEG-TS';
    if (path.endsWith('.mp4') || path.endsWith('.m4v')) return 'MP4';
    if (path.endsWith('.flv')) return 'FLV';
    return 'Live stream';
  }

  String get hostLabel {
    final uri = Uri.tryParse(url);
    if (uri == null || uri.host.isEmpty) return 'Unknown host';
    return uri.host;
  }

  /// Headers forwarded to ExoPlayer. `Origin` is derived when a referrer is
  /// present because a number of broadcaster CDNs check it as well.
  Map<String, String> get requestHeaders {
    final headers = <String, String>{};
    if (userAgent != null) headers['User-Agent'] = userAgent!;
    if (referrer != null) {
      headers['Referer'] = referrer!;
      final uri = Uri.tryParse(referrer!);
      if (uri != null && uri.hasScheme && uri.host.isNotEmpty) {
        headers['Origin'] = '${uri.scheme}://${uri.host}';
      }
    }
    return headers;
  }

  @override
  bool operator ==(Object other) =>
      other is StreamSource && other.url == url && other.userAgent == userAgent;

  @override
  int get hashCode => Object.hash(url, userAgent);
}
