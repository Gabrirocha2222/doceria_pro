import 'packaging.dart';

enum PackagingActiveFilter {
  all(label: 'Todas'),
  activeOnly(label: 'Ativas'),
  inactiveOnly(label: 'Inativas');

  const PackagingActiveFilter({required this.label});

  final String label;
}

class PackagingListFilters {
  const PackagingListFilters({
    this.searchQuery = '',
    this.activeFilter = PackagingActiveFilter.all,
  });

  final String searchQuery;
  final PackagingActiveFilter activeFilter;

  bool get hasActiveFilters =>
      searchQuery.trim().isNotEmpty ||
      activeFilter != PackagingActiveFilter.all;

  PackagingListFilters copyWith({
    String? searchQuery,
    PackagingActiveFilter? activeFilter,
  }) {
    return PackagingListFilters(
      searchQuery: searchQuery ?? this.searchQuery,
      activeFilter: activeFilter ?? this.activeFilter,
    );
  }

  List<PackagingRecord> apply(List<PackagingRecord> items) {
    final normalizedQuery = searchQuery.trim().toLowerCase();

    return items
        .where((item) {
          final matchesQuery =
              normalizedQuery.isEmpty ||
              item.name.toLowerCase().contains(normalizedQuery) ||
              item.type.label.toLowerCase().contains(normalizedQuery) ||
              item.displayCapacityDescription.toLowerCase().contains(
                normalizedQuery,
              );

          final matchesActive = switch (activeFilter) {
            PackagingActiveFilter.all => true,
            PackagingActiveFilter.activeOnly => item.isActive,
            PackagingActiveFilter.inactiveOnly => !item.isActive,
          };

          return matchesQuery && matchesActive;
        })
        .toList(growable: false);
  }
}
