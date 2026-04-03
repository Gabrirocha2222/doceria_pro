import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
import '../data/suppliers_repository.dart';
import '../domain/supplier.dart';
import '../domain/supplier_list_filters.dart';

final suppliersRepositoryProvider = Provider<SuppliersRepository>((ref) {
  return SuppliersRepository(ref.watch(appDatabaseProvider));
});

class SupplierListFiltersNotifier extends Notifier<SupplierListFilters> {
  @override
  SupplierListFilters build() => const SupplierListFilters();

  void updateSearchQuery(String value) {
    state = state.copyWith(searchQuery: value);
  }

  void updateActiveFilter(SupplierActiveFilter value) {
    state = state.copyWith(activeFilter: value);
  }

  void clear() {
    state = const SupplierListFilters();
  }
}

final supplierListFiltersProvider =
    NotifierProvider<SupplierListFiltersNotifier, SupplierListFilters>(
      SupplierListFiltersNotifier.new,
    );

final allSuppliersProvider = StreamProvider<List<SupplierRecord>>((ref) {
  return ref.watch(suppliersRepositoryProvider).watchSuppliers();
});

final filteredSuppliersProvider = Provider<AsyncValue<List<SupplierRecord>>>((
  ref,
) {
  final filters = ref.watch(supplierListFiltersProvider);
  final suppliersAsync = ref.watch(allSuppliersProvider);

  return suppliersAsync.whenData(filters.apply);
});

final supplierProvider = StreamProvider.autoDispose
    .family<SupplierRecord?, String>((ref, supplierId) {
      return ref.watch(suppliersRepositoryProvider).watchSupplier(supplierId);
    });
