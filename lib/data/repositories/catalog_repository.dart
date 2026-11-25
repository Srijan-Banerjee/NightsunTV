import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../models/catalog.dart';
import '../models/channel.dart';
import '../models/stream_source.dart';
import '../services/lineup_refresh_service.dart';

class CatalogException implements Exception {
  const CatalogException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// Loads the bundled catalog and applies a downloaded lineup overlay on top.
///
/// Metadata (logos, countries, languages) only changes with an app update,
/// while stream mirrors can be refreshed safely at any time.
class CatalogRepository {
  CatalogRepository({LineupRefreshService? refreshService})
      : _refresh = refreshService ?? LineupRefreshService();

  final LineupRefreshService _refresh;

  Catalog? _bundled;
  StoredLineup? _stored;
  bool _storedLoaded = false;

  Future<Catalog> loadCatalog() async {
    final bundled = await _loadBundled();
    final stored = await _loadStored();
    if (stored == null) return bundled;

    var replaced = 0;
    final channels = <Channel>[];
    for (final channel in bundled.channels) {
      final overlay = stored.sources[channel.id];
      if (overlay != null && overlay.isNotEmpty) {
        replaced++;
        // Freshly refreshed streams are placed first; preserve any distinct bundled
        // sources (from Samsung TV Plus, Free-TV, Plex, etc.) as additional fallbacks.
        final seenUrls = overlay.map((s) => s.url).toSet();
        final merged = <StreamSource>[...overlay];
        for (final src in channel.sources) {
          if (seenUrls.add(src.url) && merged.length < 10) {
            merged.add(src);
          }
        }
        channels.add(channel.copyWithSources(merged));
      } else {
        channels.add(channel);
      }
    }
    if (replaced == 0) return bundled;

    return Catalog(
      generatedAt: bundled.generatedAt,
      categories: bundled.categories,
      countries: bundled.countries,
      languages: bundled.languages,
      channels: channels,
      sourceCount: channels.fold<int>(
        0,
        (total, channel) => total + channel.sources.length,
      ),
      nsfwCount: bundled.nsfwCount,
    );
  }

  Future<Catalog> _loadBundled() async {
    if (_bundled != null) return _bundled!;
    try {
      final data = await rootBundle.load('assets/data/catalog.json');
      final bytes = data.buffer.asUint8List(
        data.offsetInBytes,
        data.lengthInBytes,
      );
      final catalog = await compute(parseCatalogBytes, bytes);
      if (catalog.channels.length < 1000) {
        throw const CatalogException(
          'The channel catalog is incomplete. Reinstall the app to restore it.',
        );
      }
      _bundled = catalog;
      return catalog;
    } on CatalogException {
      rethrow;
    } catch (error) {
      debugPrint('Catalog load failed: $error');
      throw const CatalogException(
        'The channel catalog could not be read. '
        'Reinstall the app to restore the bundled lineup.',
      );
    }
  }

  Future<StoredLineup?> _loadStored() async {
    if (_storedLoaded) return _stored;
    _stored = await _refresh.readStored();
    _storedLoaded = true;
    return _stored;
  }

  Future<RefreshInfo?> readRefreshInfo() async {
    final stored = await _loadStored();
    return stored?.info;
  }

  Future<LineupRefreshResult> refreshLineup({
    required Set<String> knownChannelIds,
    required void Function(RefreshProgress progress) onProgress,
    required LineupCancellationToken cancelToken,
  }) async {
    final result = await _refresh.refresh(
      knownChannelIds: knownChannelIds,
      onProgress: onProgress,
      cancelToken: cancelToken,
    );
    _stored = null;
    _storedLoaded = false;
    return result;
  }

  Future<void> restoreBundledLineup() async {
    await _refresh.clearStored();
    _stored = null;
    _storedLoaded = false;
  }
}

/// Runs on a background isolate so a 5 MB JSON decode never blocks a frame.
Catalog parseCatalogBytes(Uint8List bytes) {
  final decoded = jsonDecode(utf8.decode(bytes, allowMalformed: true));
  if (decoded is! Map<String, dynamic>) {
    throw const CatalogException('The bundled catalog has an invalid format.');
  }
  return Catalog.fromJson(decoded);
}
