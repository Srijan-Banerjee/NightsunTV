import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/utils/text.dart';
import '../data/models/browse_filter.dart';
import '../data/models/catalog.dart';
import '../data/models/channel.dart';
import '../data/models/epg_program.dart';
import '../data/repositories/catalog_repository.dart';
import '../data/services/epg_service.dart';
import '../data/services/lineup_refresh_service.dart';
import '../data/services/search_engine.dart';
import '../state/library_controller.dart';
import '../state/settings_controller.dart';

final catalogRepositoryProvider = Provider<CatalogRepository>(
  (ref) => CatalogRepository(),
);

/// Loads the bundled 10k-channel snapshot, plus a previously downloaded
/// lineup overlay when one exists.
final catalogProvider = FutureProvider<Catalog>((ref) async {
  final repository = ref.watch(catalogRepositoryProvider);
  return repository.loadCatalog();
});

final refreshInfoProvider = FutureProvider<RefreshInfo?>((ref) async {
  // Re-read metadata whenever the catalog itself is refreshed.
  ref.watch(catalogProvider);
  return ref.watch(catalogRepositoryProvider).readRefreshInfo();
});

final visibleChannelsProvider = Provider<List<Channel>>((ref) {
  final catalog = ref.watch(catalogProvider).value;
  if (catalog == null) return const [];
  final includeAdult =
      ref.watch(settingsProvider.select((settings) => settings.showAdult));
  if (includeAdult) return catalog.channels;
  return catalog.channels
      .where((channel) => !channel.nsfw)
      .toList(growable: false);
});

final channelLookupProvider = Provider<Map<String, Channel>>((ref) {
  final catalog = ref.watch(catalogProvider).value;
  return catalog?.byId ?? const {};
});

final searchEngineProvider = Provider<SearchEngine?>((ref) {
  final catalog = ref.watch(catalogProvider).value;
  if (catalog == null) return null;
  final includeAdult =
      ref.watch(settingsProvider.select((settings) => settings.showAdult));
  return SearchEngine(catalog, includeAdult: includeAdult);
});

class ShellTabController extends Notifier<int> {
  @override
  int build() => 0;

  void select(int index) {
    if (index == state) return;
    state = index;
  }
}

final shellTabProvider = NotifierProvider<ShellTabController, int>(
  ShellTabController.new,
);

class SearchFocusController extends Notifier<int> {
  @override
  int build() => 0;

  void requestFocus() => state++;
}

final searchFocusProvider = NotifierProvider<SearchFocusController, int>(
  SearchFocusController.new,
);

class BrowseFilterController extends Notifier<BrowseFilter> {
  @override
  BrowseFilter build() => const BrowseFilter();

  void setCountry(String? code) => state = state.copyWith(country: code);

  void setCategory(String? id) => state = state.copyWith(category: id);

  void setLanguage(String? code) => state = state.copyWith(language: code);

  void setSort(ChannelSort sort) => state = state.copyWith(sort: sort);

  void clear() => state = state.cleared();

  void reset() => state = const BrowseFilter();
}

final browseFilterProvider =
    NotifierProvider<BrowseFilterController, BrowseFilter>(
  BrowseFilterController.new,
);

/// Filtered and sorted channels for the Browse tab. Recomputing 10k entries is
/// cheap enough to stay on the UI isolate and keeps results immediate.
final filteredChannelsProvider = Provider<List<Channel>>((ref) {
  final catalog = ref.watch(catalogProvider).value;
  if (catalog == null) return const [];
  final includeAdult =
      ref.watch(settingsProvider.select((settings) => settings.showAdult));
  final filter = ref.watch(browseFilterProvider);

  final result = <Channel>[];
  for (final channel in catalog.channels) {
    if (!includeAdult && channel.nsfw) continue;
    if (filter.country != null && channel.country != filter.country) continue;
    if (filter.category != null &&
        !channel.categories.contains(filter.category)) {
      continue;
    }
    if (filter.language != null &&
        !channel.languages.contains(filter.language)) {
      continue;
    }
    result.add(channel);
  }

  final countryName = <String, String>{
    for (final country in catalog.countries) country.code: country.name,
  };
  final sort = filter.sort;
  final normalized = <String, String>{};
  String getNorm(Channel c) =>
      normalized.putIfAbsent(c.id, () => normalizeForSearch(c.name));

  if (sort == ChannelSort.nameAsc) {
    result.sort(
      (a, b) => getNorm(a).compareTo(getNorm(b)),
    );
  } else if (sort == ChannelSort.country) {
    result.sort((a, b) {
      final byCountry = (countryName[a.country] ?? a.country)
          .compareTo(countryName[b.country] ?? b.country);
      if (byCountry != 0) return byCountry;
      return getNorm(a).compareTo(getNorm(b));
    });
  } else if (sort == ChannelSort.newest) {
    result.sort((a, b) {
      final byYear = (b.launched ?? 0).compareTo(a.launched ?? 0);
      if (byYear != 0) return byYear;
      return getNorm(a).compareTo(getNorm(b));
    });
  } else {
    result.sort((a, b) {
      final bySources = b.sources.length.compareTo(a.sources.length);
      if (bySources != 0) return bySources;
      return getNorm(a).compareTo(getNorm(b));
    });
  }
  return List<Channel>.unmodifiable(result);
});

final favoriteChannelsProvider = Provider<List<Channel>>((ref) {
  final catalog = ref.watch(catalogProvider).value;
  final library = ref.watch(libraryProvider);
  if (catalog == null) return const [];
  final channels = <Channel>[];
  for (final id in library.favoriteIds) {
    final channel = catalog.byId[id];
    if (channel != null) channels.add(channel);
  }
  return channels;
});

final recentChannelsProvider = Provider<List<Channel>>((ref) {
  final catalog = ref.watch(catalogProvider).value;
  final library = ref.watch(libraryProvider);
  if (catalog == null) return const [];
  final channels = <Channel>[];
  for (final entry in library.recents) {
    final channel = catalog.byId[entry.channelId];
    if (channel != null) channels.add(channel);
  }
  return channels;
});

/// Electronic Program Guide (EPG) service provider for real-time program guide schedules.
final epgServiceProvider = Provider<EpgService>((ref) => EpgService());

/// The 24-hour program schedule for a given channel.
final channelScheduleProvider =
    Provider.family<ChannelSchedule, Channel>((ref, channel) {
  return ref.watch(epgServiceProvider).getSchedule(channel);
});

/// The program currently broadcasting on a given channel.
final currentProgramProvider =
    Provider.family<EpgProgram?, Channel>((ref, channel) {
  return ref.watch(channelScheduleProvider(channel)).currentProgram();
});

/// The upcoming program list for a given channel.
final upcomingProgramsProvider =
    Provider.family<List<EpgProgram>, Channel>((ref, channel) {
  return ref.watch(channelScheduleProvider(channel)).upcomingPrograms();
});
