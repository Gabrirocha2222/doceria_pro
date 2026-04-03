import 'product.dart';
import 'product_type.dart';

enum ProductActiveFilter {
  activeOnly('Ativos'),
  all('Todos'),
  inactiveOnly('Inativos');

  const ProductActiveFilter(this.label);

  final String label;
}

class ProductListFilters {
  const ProductListFilters({
    this.searchQuery = '',
    this.activeFilter = ProductActiveFilter.activeOnly,
    this.type,
  });

  final String searchQuery;
  final ProductActiveFilter activeFilter;
  final ProductType? type;

  bool get hasActiveFilters =>
      searchQuery.trim().isNotEmpty ||
      activeFilter != ProductActiveFilter.activeOnly ||
      type != null;

  ProductListFilters copyWith({
    String? searchQuery,
    ProductActiveFilter? activeFilter,
    ProductType? type,
    bool clearType = false,
  }) {
    return ProductListFilters(
      searchQuery: searchQuery ?? this.searchQuery,
      activeFilter: activeFilter ?? this.activeFilter,
      type: clearType ? null : (type ?? this.type),
    );
  }

  List<ProductRecord> apply(List<ProductRecord> products) {
    return products.where(_matches).toList(growable: false);
  }

  bool _matches(ProductRecord product) {
    if (activeFilter == ProductActiveFilter.activeOnly && !product.isActive) {
      return false;
    }

    if (activeFilter == ProductActiveFilter.inactiveOnly && product.isActive) {
      return false;
    }

    if (type != null && product.type != type) {
      return false;
    }

    final normalizedQuery = searchQuery.trim().toLowerCase();
    if (normalizedQuery.isEmpty) {
      return true;
    }

    final searchableFields = [
      product.name,
      product.category ?? '',
      product.type.label,
      product.saleMode.label,
      product.notes ?? '',
      product.yieldHint ?? '',
      ...product.options.map((option) => option.name),
    ];

    return searchableFields.any(
      (field) => field.toLowerCase().contains(normalizedQuery),
    );
  }
}
