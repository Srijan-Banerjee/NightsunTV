enum ChannelSort {
  nameAsc('A to Z'),
  country('Country'),
  newest('Newest'),
  sources('Most sources');

  const ChannelSort(this.label);
  final String label;
}

const Object _unset = Object();

/// The Browse tab's current filter. Values are catalog ids, not display names,
/// so a filter survives a lineup refresh.
class BrowseFilter {
  const BrowseFilter({
    this.country,
    this.category,
    this.language,
    this.sort = ChannelSort.nameAsc,
  });

  final String? country;
  final String? category;
  final String? language;
  final ChannelSort sort;

  bool get isActive =>
      country != null || category != null || language != null;

  int get activeCount => [
        country,
        category,
        language,
      ].where((value) => value != null).length;

  BrowseFilter copyWith({
    Object? country = _unset,
    Object? category = _unset,
    Object? language = _unset,
    ChannelSort? sort,
  }) =>
      BrowseFilter(
        country: identical(country, _unset) ? this.country : country as String?,
        category:
            identical(category, _unset) ? this.category : category as String?,
        language:
            identical(language, _unset) ? this.language : language as String?,
        sort: sort ?? this.sort,
      );

  BrowseFilter cleared() => BrowseFilter(sort: sort);
}
