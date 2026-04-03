import 'supplier.dart';

enum SupplierActiveFilter {
  all(label: 'Todas'),
  activeOnly(label: 'Ativas'),
  inactiveOnly(label: 'Inativas');

  const SupplierActiveFilter({required this.label});

  final String label;
}

class SupplierListFilters {
  const SupplierListFilters({
    this.searchQuery = '',
    this.activeFilter = SupplierActiveFilter.all,
  });

  final String searchQuery;
  final SupplierActiveFilter activeFilter;

  bool get hasActiveFilters =>
      searchQuery.trim().isNotEmpty || activeFilter != SupplierActiveFilter.all;

  SupplierListFilters copyWith({
    String? searchQuery,
    SupplierActiveFilter? activeFilter,
  }) {
    return SupplierListFilters(
      searchQuery: searchQuery ?? this.searchQuery,
      activeFilter: activeFilter ?? this.activeFilter,
    );
  }

  List<SupplierRecord> apply(List<SupplierRecord> suppliers) {
    final normalizedQuery = searchQuery.trim().toLowerCase();

    return suppliers
        .where((supplier) {
          final matchesQuery =
              normalizedQuery.isEmpty ||
              supplier.name.toLowerCase().contains(normalizedQuery) ||
              supplier.displayContact.toLowerCase().contains(normalizedQuery) ||
              supplier.displayNotes.toLowerCase().contains(normalizedQuery) ||
              supplier.linkedIngredients.any(
                (ingredient) =>
                    ingredient.ingredientName.toLowerCase().contains(
                      normalizedQuery,
                    ) ||
                    ingredient.displayCategory.toLowerCase().contains(
                      normalizedQuery,
                    ),
              );

          final matchesActive = switch (activeFilter) {
            SupplierActiveFilter.all => true,
            SupplierActiveFilter.activeOnly => supplier.isActive,
            SupplierActiveFilter.inactiveOnly => !supplier.isActive,
          };

          return matchesQuery && matchesActive;
        })
        .toList(growable: false);
  }
}
