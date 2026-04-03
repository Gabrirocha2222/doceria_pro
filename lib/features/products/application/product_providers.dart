import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
import '../data/products_repository.dart';
import '../domain/product.dart';
import '../domain/product_list_filters.dart';
import '../domain/product_type.dart';

final productsRepositoryProvider = Provider<ProductsRepository>((ref) {
  return ProductsRepository(ref.watch(appDatabaseProvider));
});

class ProductListFiltersNotifier extends Notifier<ProductListFilters> {
  @override
  ProductListFilters build() => const ProductListFilters();

  void updateSearchQuery(String value) {
    state = state.copyWith(searchQuery: value);
  }

  void updateActiveFilter(ProductActiveFilter value) {
    state = state.copyWith(activeFilter: value);
  }

  void updateType(ProductType? value) {
    if (value == null) {
      state = state.copyWith(clearType: true);
      return;
    }

    state = state.copyWith(type: value);
  }

  void clear() {
    state = const ProductListFilters();
  }
}

final productListFiltersProvider =
    NotifierProvider<ProductListFiltersNotifier, ProductListFilters>(
      ProductListFiltersNotifier.new,
    );

final allProductsProvider = StreamProvider<List<ProductRecord>>((ref) {
  return ref.watch(productsRepositoryProvider).watchProducts();
});

final filteredProductsProvider = Provider<AsyncValue<List<ProductRecord>>>((
  ref,
) {
  final filters = ref.watch(productListFiltersProvider);
  final productsAsync = ref.watch(allProductsProvider);

  return productsAsync.whenData(filters.apply);
});

final activeProductsProvider = Provider<AsyncValue<List<ProductRecord>>>((ref) {
  final productsAsync = ref.watch(allProductsProvider);

  return productsAsync.whenData(
    (products) => products.where((product) => product.isActive).toList(),
  );
});

final productProvider = StreamProvider.autoDispose
    .family<ProductRecord?, String>((ref, productId) {
      return ref.watch(productsRepositoryProvider).watchProduct(productId);
    });
