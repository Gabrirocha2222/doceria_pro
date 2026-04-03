import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
import '../data/packaging_repository.dart';
import '../domain/packaging.dart';
import '../domain/packaging_list_filters.dart';

final packagingRepositoryProvider = Provider<PackagingRepository>((ref) {
  return PackagingRepository(ref.watch(appDatabaseProvider));
});

class PackagingListFiltersNotifier extends Notifier<PackagingListFilters> {
  @override
  PackagingListFilters build() => const PackagingListFilters();

  void updateSearchQuery(String value) {
    state = state.copyWith(searchQuery: value);
  }

  void updateActiveFilter(PackagingActiveFilter value) {
    state = state.copyWith(activeFilter: value);
  }

  void clear() {
    state = const PackagingListFilters();
  }
}

final packagingListFiltersProvider =
    NotifierProvider<PackagingListFiltersNotifier, PackagingListFilters>(
      PackagingListFiltersNotifier.new,
    );

final allPackagingProvider = StreamProvider<List<PackagingRecord>>((ref) {
  return ref.watch(packagingRepositoryProvider).watchPackaging();
});

final filteredPackagingProvider = Provider<AsyncValue<List<PackagingRecord>>>((
  ref,
) {
  final filters = ref.watch(packagingListFiltersProvider);
  final packagingAsync = ref.watch(allPackagingProvider);

  return packagingAsync.whenData(filters.apply);
});

final lowStockPackagingProvider = Provider<AsyncValue<List<PackagingRecord>>>((
  ref,
) {
  final packagingAsync = ref.watch(allPackagingProvider);

  return packagingAsync.whenData(
    (items) => items.where((item) => item.isLowStock).toList(growable: false),
  );
});

final activePackagingProvider = Provider<AsyncValue<List<PackagingRecord>>>((
  ref,
) {
  final packagingAsync = ref.watch(allPackagingProvider);

  return packagingAsync.whenData(
    (items) => items.where((item) => item.isActive).toList(growable: false),
  );
});

final packagingProvider = StreamProvider.autoDispose
    .family<PackagingRecord?, String>((ref, packagingId) {
      return ref
          .watch(packagingRepositoryProvider)
          .watchPackagingItem(packagingId);
    });
