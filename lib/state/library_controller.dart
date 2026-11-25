import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/models/channel.dart';
import 'prefs.dart';

class RecentEntry {
  const RecentEntry({required this.channelId, required this.watchedAt});

  final String channelId;
  final DateTime watchedAt;

  Map<String, dynamic> toJson() => {
        'id': channelId,
        'at': watchedAt.toIso8601String(),
      };

  factory RecentEntry.fromJson(Map<String, dynamic> json) => RecentEntry(
        channelId: json['id'] is String ? json['id'] as String : '',
        watchedAt: DateTime.tryParse(json['at'] as String? ?? '') ??
            DateTime.fromMillisecondsSinceEpoch(0),
      );
}

class LibraryState {
  const LibraryState({
    this.favoriteIds = const [],
    this.recents = const [],
    this.lastGoodSources = const {},
  });

  final List<String> favoriteIds;
  final List<RecentEntry> recents;

  /// channel id → last source that successfully opened. Used to start a
  /// channel on the mirror that worked last time.
  final Map<String, String> lastGoodSources;

  static const _storageKey = 'library.v1';

  factory LibraryState.load(SharedPreferences prefs) {
    final raw = prefs.getString(_storageKey);
    if (raw == null || raw.isEmpty) return const LibraryState();
    try {
      final json = jsonDecode(raw);
      if (json is! Map<String, dynamic>) return const LibraryState();
      final favorites = <String>[];
      final rawFavorites = json['favorites'];
      if (rawFavorites is List) {
        for (final item in rawFavorites.whereType<String>()) {
          if (item.isNotEmpty && !favorites.contains(item)) favorites.add(item);
        }
      }
      final recents = <RecentEntry>[];
      final rawRecents = json['recents'];
      if (rawRecents is List) {
        for (final item in rawRecents.whereType<Map<String, dynamic>>()) {
          final entry = RecentEntry.fromJson(item);
          if (entry.channelId.isNotEmpty) recents.add(entry);
        }
      }
      final lastGood = <String, String>{};
      final rawLastGood = json['lastGood'];
      if (rawLastGood is Map) {
        rawLastGood.forEach((key, value) {
          if (key is String && value is String && key.isNotEmpty) {
            lastGood[key] = value;
          }
        });
      }
      return LibraryState(
        favoriteIds: favorites,
        recents: recents,
        lastGoodSources: lastGood,
      );
    } catch (_) {
      // A corrupt preferences blob should never prevent the app from opening.
      return const LibraryState();
    }
  }

  String encode() => jsonEncode({
        'favorites': favoriteIds,
        'recents': [for (final entry in recents) entry.toJson()],
        'lastGood': lastGoodSources,
      });

  bool isFavorite(String channelId) => favoriteIds.contains(channelId);

  Channel? channelFor(RecentEntry entry, Map<String, Channel> lookup) =>
      lookup[entry.channelId];

  LibraryState copyWith({
    List<String>? favoriteIds,
    List<RecentEntry>? recents,
    Map<String, String>? lastGoodSources,
  }) =>
      LibraryState(
        favoriteIds: favoriteIds ?? this.favoriteIds,
        recents: recents ?? this.recents,
        lastGoodSources: lastGoodSources ?? this.lastGoodSources,
      );
}

class LibraryController extends Notifier<LibraryState> {
  late SharedPreferences _prefs;

  @override
  LibraryState build() {
    _prefs = ref.watch(sharedPreferencesProvider);
    return LibraryState.load(_prefs);
  }

  void _update(LibraryState next) {
    state = next;
    unawaited(_prefs.setString(LibraryState._storageKey, next.encode()));
  }

  bool isFavorite(String channelId) => state.favoriteIds.contains(channelId);

  void toggleFavorite(String channelId) {
    final favorites = [...state.favoriteIds];
    if (favorites.remove(channelId)) {
      _update(state.copyWith(favoriteIds: favorites));
      return;
    }
    favorites.insert(0, channelId);
    _update(state.copyWith(favoriteIds: favorites));
  }

  void recordWatch(String channelId, {String? sourceUrl}) {
    final recents = [
      RecentEntry(channelId: channelId, watchedAt: DateTime.now()),
      ...state.recents.where((entry) => entry.channelId != channelId),
    ];
    final trimmed = recents.take(50).toList(growable: false);
    final lastGood = {...state.lastGoodSources};
    if (sourceUrl != null && sourceUrl.isNotEmpty) {
      lastGood[channelId] = sourceUrl;
    }
    _update(state.copyWith(recents: trimmed, lastGoodSources: lastGood));
  }

  void removeRecent(String channelId) {
    _update(state.copyWith(
      recents:
          state.recents.where((entry) => entry.channelId != channelId).toList(),
    ));
  }

  void clearRecents() => _update(state.copyWith(recents: const []));

  void setLastGoodSource(String channelId, String sourceUrl) {
    if (state.lastGoodSources[channelId] == sourceUrl) return;
    _update(state.copyWith(
      lastGoodSources: {...state.lastGoodSources, channelId: sourceUrl},
    ));
  }
}

final libraryProvider = NotifierProvider<LibraryController, LibraryState>(
  LibraryController.new,
);
