import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

import '../models/stream_source.dart';

/// The official iptv-org playlist. It is a few megabytes and is the same
/// lineup the public repository publishes, so refreshing here cannot invent
/// channels or bypass the catalog's blocklist.
const lineupPlaylistUrl = 'https://iptv-org.github.io/iptv/index.m3u';
const _storageFileName = 'lineup_refresh.json';
const _schemaVersion = 1;
const _maxDownloadBytes = 32 * 1024 * 1024;
const _maxSourcesPerChannel = 10;

class LineupCancellationToken {
  bool _cancelled = false;
  bool get isCancelled => _cancelled;
  void cancel() => _cancelled = true;
}

class LineupRefreshCanceled implements Exception {
  const LineupRefreshCanceled();
  @override
  String toString() => 'Lineup refresh canceled';
}

class LineupRefreshException implements Exception {
  const LineupRefreshException(this.message);
  final String message;
  @override
  String toString() => message;
}

enum RefreshPhase { downloading, parsing, saving, done }

class RefreshProgress {
  const RefreshProgress({
    required this.phase,
    required this.message,
    this.fraction,
    this.receivedBytes,
    this.totalBytes,
  });

  final RefreshPhase phase;
  final String message;
  final double? fraction;
  final int? receivedBytes;
  final int? totalBytes;
}

class RefreshInfo {
  const RefreshInfo({
    required this.fetchedAt,
    required this.playlistSha256,
    required this.matchedChannels,
    required this.sourceCount,
    required this.downloadedBytes,
  });

  final DateTime fetchedAt;
  final String playlistSha256;
  final int matchedChannels;
  final int sourceCount;
  final int downloadedBytes;

  Map<String, dynamic> toJson() => {
        'fetchedAt': fetchedAt.toUtc().toIso8601String(),
        'playlistSha256': playlistSha256,
        'matchedChannels': matchedChannels,
        'sourceCount': sourceCount,
        'downloadedBytes': downloadedBytes,
      };

  factory RefreshInfo.fromJson(Map<String, dynamic> json) => RefreshInfo(
        fetchedAt: DateTime.tryParse(json['fetchedAt'] as String? ?? '') ??
            DateTime.fromMillisecondsSinceEpoch(0),
        playlistSha256: json['playlistSha256'] as String? ?? '',
        matchedChannels: json['matchedChannels'] is int
            ? json['matchedChannels'] as int
            : 0,
        sourceCount:
            json['sourceCount'] is int ? json['sourceCount'] as int : 0,
        downloadedBytes:
            json['downloadedBytes'] is int ? json['downloadedBytes'] as int : 0,
      );
}

class StoredLineup {
  const StoredLineup({required this.info, required this.sources});
  final RefreshInfo info;
  final Map<String, List<StreamSource>> sources;
}

class LineupRefreshResult {
  const LineupRefreshResult({
    required this.info,
    required this.newChannels,
  });

  final RefreshInfo info;
  final int newChannels;
}

class LineupRefreshService {
  LineupRefreshService({http.Client Function()? clientFactory})
      : _clientFactory = clientFactory ?? http.Client.new;

  final http.Client Function() _clientFactory;

  Future<LineupRefreshResult> refresh({
    required Set<String> knownChannelIds,
    required void Function(RefreshProgress progress) onProgress,
    required LineupCancellationToken cancelToken,
  }) async {
    if (knownChannelIds.isEmpty) {
      throw const LineupRefreshException(
        'The channel catalog is still loading. Try again in a moment.',
      );
    }

    final client = _clientFactory();
    try {
      onProgress(const RefreshProgress(
        phase: RefreshPhase.downloading,
        message: 'Contacting iptv-org…',
      ));
      final request = http.Request('GET', Uri.parse(lineupPlaylistUrl))
        ..headers['User-Agent'] = 'NightsunTV/1.0 (+https://github.com/iptv-org/iptv)'
        ..headers['Accept'] =
            'application/x-mpegURL, application/vnd.apple.mpegurl, text/plain, */*';
      final response =
          await client.send(request).timeout(const Duration(seconds: 35));
      if (response.statusCode != 200) {
        throw LineupRefreshException(
          'The lineup service answered HTTP ${response.statusCode}. '
          'Your current lineup was kept.',
        );
      }
      final total = response.contentLength ?? 0;
      final builder = BytesBuilder(copy: false);
      var received = 0;
      await for (final chunk in response.stream.timeout(const Duration(seconds: 90))) {
        if (cancelToken.isCancelled) throw const LineupRefreshCanceled();
        received += chunk.length;
        if (received > _maxDownloadBytes) {
          throw const LineupRefreshException(
            'The downloaded playlist was unexpectedly large. '
            'Your current lineup was kept.',
          );
        }
        builder.add(chunk);
        final fraction =
            total > 0 ? (received / total).clamp(0.0, 0.7).toDouble() : null;
        onProgress(RefreshProgress(
          phase: RefreshPhase.downloading,
          message: total > 0
              ? 'Downloading lineup… ${(received / total * 100).round()}%'
              : 'Downloading lineup…',
          fraction: fraction,
          receivedBytes: received,
          totalBytes: total,
        ));
      }
      if (cancelToken.isCancelled) throw const LineupRefreshCanceled();
      final bytes = builder.takeBytes();
      if (bytes.length < 100 * 1024) {
        throw const LineupRefreshException(
          'The downloaded playlist looked incomplete. '
          'Your current lineup was kept.',
        );
      }
      final text = utf8.decode(bytes, allowMalformed: true);
      if (!text.contains('#EXTM3U')) {
        throw const LineupRefreshException(
          'The lineup service returned an unrecognised file. '
          'Your current lineup was kept.',
        );
      }
      onProgress(const RefreshProgress(
        phase: RefreshPhase.parsing,
        message: 'Reading channels and backup sources…',
        fraction: 0.76,
      ));

      final parsed = parseM3uLineup(text, knownChannelIds: knownChannelIds);
      final matchedChannels = parsed.sources.length;
      final sourceCount = parsed.sources.values.fold<int>(
        0,
        (total, sources) => total + sources.length,
      );
      if (matchedChannels < 2500 || sourceCount < 5000) {
        throw LineupRefreshException(
          'Only $matchedChannels channels matched the catalog. '
          'That is lower than expected, so your current lineup was kept.',
        );
      }
      if (cancelToken.isCancelled) throw const LineupRefreshCanceled();

      final now = DateTime.now().toUtc();
      final info = RefreshInfo(
        fetchedAt: now,
        playlistSha256: sha256.convert(bytes).toString(),
        matchedChannels: matchedChannels,
        sourceCount: sourceCount,
        downloadedBytes: bytes.length,
      );
      onProgress(const RefreshProgress(
        phase: RefreshPhase.saving,
        message: 'Saving the refreshed lineup…',
        fraction: 0.93,
      ));
      await _commit(info: info, sources: parsed.sources);
      onProgress(RefreshProgress(
        phase: RefreshPhase.done,
        message:
            'Updated ${parsed.sources.length} channels with $sourceCount streams.',
        fraction: 1,
        receivedBytes: bytes.length,
        totalBytes: bytes.length,
      ));
      return LineupRefreshResult(info: info, newChannels: parsed.unknownChannels);
    } on TimeoutException {
      throw const LineupRefreshException(
        'The lineup download timed out. Check your connection and try again. '
        'Your current lineup was kept.',
      );
    } on SocketException {
      throw const LineupRefreshException(
        'No connection to iptv-org. Your current lineup was kept.',
      );
    } on http.ClientException catch (e) {
      throw LineupRefreshException(
        'Network error while connecting to iptv-org (${e.message}). '
        'Your current lineup was kept.',
      );
    } catch (e) {
      if (e is LineupRefreshException || e is LineupRefreshCanceled) rethrow;
      throw LineupRefreshException(
        'Lineup refresh encountered an unexpected error: $e. '
        'Your current lineup was kept.',
      );
    } finally {
      client.close();
    }
  }

  Future<File> _storageFile() async {
    final directory = await getApplicationSupportDirectory();
    if (!await directory.exists()) {
      await directory.create(recursive: true);
    }
    return File('${directory.path}${Platform.pathSeparator}$_storageFileName');
  }

  Future<void> _commit({
    required RefreshInfo info,
    required Map<String, List<StreamSource>> sources,
  }) async {
    final target = await _storageFile();
    final temp = File('${target.path}.tmp');
    final payload = jsonEncode({
      'schema': _schemaVersion,
      'info': info.toJson(),
      'channels': {
        for (final entry in sources.entries)
          entry.key: [for (final source in entry.value) source.toJson()],
      },
    });
    try {
      await temp.writeAsString(payload, flush: true);
      // Atomic replace: a crash can leave a .tmp file, never a half-written
      // lineup. If atomic rename fails across filesystems/devices, fall back to copy.
      try {
        await temp.rename(target.path);
      } catch (_) {
        await temp.copy(target.path);
        await temp.delete();
      }
    } catch (_) {
      if (await temp.exists()) {
        try {
          await temp.delete();
        } catch (_) {}
      }
      rethrow;
    }
  }

  Future<StoredLineup?> readStored() async {
    try {
      final file = await _storageFile();
      if (!await file.exists()) return null;
      final raw = await file.readAsString();
      if (raw.length < 100) return null;
      final json = jsonDecode(raw);
      if (json is! Map<String, dynamic> ||
          json['schema'] != _schemaVersion ||
          json['info'] is! Map<String, dynamic> ||
          json['channels'] is! Map<String, dynamic>) {
        return null;
      }
      final rawChannels = json['channels'] as Map<String, dynamic>;
      final result = <String, List<StreamSource>>{};
      rawChannels.forEach((key, value) {
        if (value is! List) return;
        final sources = <StreamSource>[];
        for (final item in value.whereType<Map<String, dynamic>>()) {
          final source = StreamSource.fromJson(item);
          if (source.url.isNotEmpty) sources.add(source);
        }
        if (sources.isNotEmpty) result[key] = sources;
      });
      if (result.isEmpty) return null;
      return StoredLineup(
        info: RefreshInfo.fromJson(json['info'] as Map<String, dynamic>),
        sources: result,
      );
    } catch (_) {
      // A corrupt or unreadable overlay is ignored; the bundled lineup remains
      // the source of truth and can be restored from Settings.
      return null;
    }
  }

  Future<void> clearStored() async {
    try {
      final file = await _storageFile();
      if (await file.exists()) await file.delete();
      final temp = File('${file.path}.tmp');
      if (await temp.exists()) await temp.delete();
    } catch (_) {
      // Best effort: the repository can still fall back to bundled data.
    }
  }
}

class ParsedLineup {
  const ParsedLineup({
    required this.sources,
    required this.unknownChannels,
  });
  final Map<String, List<StreamSource>> sources;
  final int unknownChannels;
}

/// Parses the extended M3U format used by iptv-org.
///
/// Only channels already present in the catalog are returned, which prevents a
/// refresh from adding unvetted metadata. Channel IDs are matched accurately
/// against known channels, including handling quality/region suffixes like
/// '@SD', '@HD', '@East' or case differences. Unknown channel ids are counted so
/// the UI can explain that the catalog itself is updated with app releases.
ParsedLineup parseM3uLineup(
  String content, {
  required Set<String> knownChannelIds,
}) {
  final sources = <String, List<StreamSource>>{};
  final seenUrls = <String, Set<String>>{};
  final unknown = <String>{};
  final lowerToKnownId = {
    for (final id in knownChannelIds) id.toLowerCase(): id,
  };

  String? resolveChannelId(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    final trimmed = raw.trim();
    if (knownChannelIds.contains(trimmed)) return trimmed;
    final atIndex = trimmed.indexOf('@');
    if (atIndex > 0) {
      final base = trimmed.substring(0, atIndex);
      if (knownChannelIds.contains(base)) return base;
      final lowerBase = lowerToKnownId[base.toLowerCase()];
      if (lowerBase != null) return lowerBase;
    }
    final directLower = lowerToKnownId[trimmed.toLowerCase()];
    if (directLower != null) return directLower;
    return null;
  }

  String? pendingId;
  String? pendingTitle;
  String? pendingUserAgent;
  String? pendingReferrer;
  final lines = const LineSplitter().convert(content);

  String? unquote(String value) {
    var result = value.trim();
    if (result.length >= 2 &&
        ((result.startsWith('"') && result.endsWith('"')) ||
            (result.startsWith("'") && result.endsWith("'")))) {
      result = result.substring(1, result.length - 1).trim();
    }
    return result.isEmpty ? null : result;
  }

  void resetPending() {
    pendingId = null;
    pendingTitle = null;
    pendingUserAgent = null;
    pendingReferrer = null;
  }

  final attributePattern =
      RegExp(r'''([\w-]+)=(?:"([^"]*)"|'([^']*)'|([^\s,]+))''');

  for (final rawLine in lines) {
    final line = rawLine.trim();
    if (line.isEmpty) continue;
    if (line.startsWith('#EXTINF')) {
      pendingId = null;
      pendingTitle = null;
      pendingUserAgent = null;
      pendingReferrer = null;
      for (final match in attributePattern.allMatches(line)) {
        final key = match.group(1)!.toLowerCase();
        final rawVal =
            match.group(2) ?? match.group(3) ?? match.group(4) ?? '';
        final value = unquote(rawVal);
        if (value == null) continue;
        if (key == 'tvg-id') pendingId = value;
        if (key == 'tvg-name') pendingTitle ??= value;
      }
      final comma = line.lastIndexOf(',');
      if (comma >= 0 && comma + 1 < line.length) {
        final displayName = unquote(line.substring(comma + 1));
        if (displayName != null) pendingTitle = displayName;
      }
      continue;
    }
    if (line.startsWith('#EXTVLCOPT:')) {
      final option = line.substring('#EXTVLCOPT:'.length);
      final separator = option.indexOf('=');
      if (separator <= 0) continue;
      final key = option.substring(0, separator).trim().toLowerCase();
      final value = unquote(option.substring(separator + 1));
      if (value == null) continue;
      if (key == 'http-user-agent' || key == 'user-agent') {
        pendingUserAgent = value;
      } else if (key == 'http-referrer' ||
          key == 'http-referer' ||
          key == 'referrer' ||
          key == 'referer') {
        pendingReferrer = value;
      }
      continue;
    }
    if (line.startsWith('#KODIPROP:')) {
      final option = line.substring('#KODIPROP:'.length);
      if (option.toLowerCase().startsWith('inputstream.adaptive.stream_headers=')) {
        final rawHeaders =
            option.substring('inputstream.adaptive.stream_headers='.length);
        try {
          final decoded = Uri.splitQueryString(rawHeaders);
          decoded.forEach((key, value) {
            final lowerKey = key.toLowerCase();
            if (lowerKey == 'user-agent') {
              pendingUserAgent ??= unquote(value);
            } else if (lowerKey == 'referer' || lowerKey == 'referrer') {
              pendingReferrer ??= unquote(value);
            }
          });
        } catch (_) {
          // Header hints are optional; ignore malformed ones.
        }
      }
      continue;
    }
    if (line.startsWith('#')) continue;

    final rawId = pendingId;
    final title = pendingTitle;
    final userAgent = pendingUserAgent;
    final referrer = pendingReferrer;
    resetPending();
    if (rawId == null || rawId.isEmpty) continue;
    final lowered = line.toLowerCase();
    if (!lowered.startsWith('http://') && !lowered.startsWith('https://')) {
      continue;
    }
    final channelId = resolveChannelId(rawId) ??
        (title != null ? resolveChannelId(title) : null);
    if (channelId == null) {
      unknown.add(rawId);
      continue;
    }
    final channelUrls = seenUrls.putIfAbsent(channelId, () => <String>{});
    if (!channelUrls.add(line)) continue;
    final quality = _qualityFromTitleAndId(title, rawId);
    final list = sources.putIfAbsent(channelId, () => <StreamSource>[]);
    if (list.length >= _maxSourcesPerChannel) continue;
    list.add(StreamSource(
      url: line,
      quality: quality,
      userAgent: userAgent,
      referrer: referrer,
      title: title,
    ));
  }

  return ParsedLineup(
    sources: {
      for (final entry in sources.entries)
        if (entry.value.isNotEmpty) entry.key: entry.value,
    },
    unknownChannels: unknown.length,
  );
}

String? _qualityFromTitleAndId(String? title, String? rawId) {
  if (title != null) {
    final upper = title.toUpperCase();
    if (upper.contains('4K') || upper.contains('UHD') || upper.contains('2160')) {
      return '2160p';
    }
    final match = RegExp(r'(\d{3,4})P').firstMatch(upper);
    if (match != null) return '${match.group(1)}p';
  }
  if (rawId != null && rawId.contains('@')) {
    final suffix = rawId.substring(rawId.indexOf('@') + 1).toUpperCase();
    if (suffix.contains('4K') || suffix.contains('UHD') || suffix.contains('2160')) {
      return '2160p';
    }
    if (suffix.contains('FHD') || suffix.contains('1080')) {
      return '1080p';
    }
    if (suffix.contains('HD') || suffix.contains('720')) {
      return '720p';
    }
    if (suffix.contains('SD') || suffix.contains('480') || suffix.contains('576')) {
      return '480p';
    }
    if (suffix.contains('360')) {
      return '360p';
    }
  }
  return null;
}
