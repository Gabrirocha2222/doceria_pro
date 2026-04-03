import 'ingredient.dart';

enum IngredientStockFilter {
  all('Todos'),
  lowStockOnly('Estoque baixo'),
  enoughStockOnly('Sem alerta');

  const IngredientStockFilter(this.label);

  final String label;
}

class IngredientListFilters {
  const IngredientListFilters({
    this.searchQuery = '',
    this.stockFilter = IngredientStockFilter.all,
  });

  final String searchQuery;
  final IngredientStockFilter stockFilter;

  bool get hasActiveFilters =>
      searchQuery.trim().isNotEmpty || stockFilter != IngredientStockFilter.all;

  IngredientListFilters copyWith({
    String? searchQuery,
    IngredientStockFilter? stockFilter,
  }) {
    return IngredientListFilters(
      searchQuery: searchQuery ?? this.searchQuery,
      stockFilter: stockFilter ?? this.stockFilter,
    );
  }

  List<IngredientRecord> apply(List<IngredientRecord> ingredients) {
    return ingredients.where(_matches).toList(growable: false);
  }

  bool _matches(IngredientRecord ingredient) {
    if (stockFilter == IngredientStockFilter.lowStockOnly &&
        !ingredient.isLowStock) {
      return false;
    }

    if (stockFilter == IngredientStockFilter.enoughStockOnly &&
        ingredient.isLowStock) {
      return false;
    }

    final normalizedQuery = searchQuery.trim().toLowerCase();
    if (normalizedQuery.isEmpty) {
      return true;
    }

    final searchableFields = [
      ingredient.name,
      ingredient.category ?? '',
      ingredient.defaultSupplier ?? '',
      ...ingredient.linkedSuppliers.map((supplier) => supplier.supplierName),
      ingredient.notes ?? '',
      ingredient.purchaseUnit.label,
      ingredient.stockUnit.label,
    ];

    return searchableFields.any(
      (field) => field.toLowerCase().contains(normalizedQuery),
    );
  }
}
