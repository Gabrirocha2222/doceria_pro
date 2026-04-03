import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
import '../data/production_repository.dart';
import '../domain/production_filters.dart';
import '../domain/production_task.dart';

final productionRepositoryProvider = Provider<ProductionRepository>((ref) {
  return ProductionRepository(ref.watch(appDatabaseProvider));
});

class ProductionFiltersNotifier extends Notifier<ProductionFilters> {
  @override
  ProductionFilters build() => const ProductionFilters();

  void updateTimeframe(ProductionTimeframe timeframe) {
    state = state.copyWith(timeframe: timeframe);
  }

  void updateGrouping(ProductionGrouping grouping) {
    state = state.copyWith(grouping: grouping);
  }
}

final productionFiltersProvider =
    NotifierProvider<ProductionFiltersNotifier, ProductionFilters>(
      ProductionFiltersNotifier.new,
    );

final productionTasksProvider = StreamProvider<List<ProductionTaskRecord>>((
  ref,
) {
  return ref.watch(productionRepositoryProvider).watchTasks();
});

final filteredProductionTasksProvider =
    Provider<AsyncValue<List<ProductionTaskRecord>>>((ref) {
      final filters = ref.watch(productionFiltersProvider);
      final tasksAsync = ref.watch(productionTasksProvider);

      return tasksAsync.whenData(
        (tasks) => applyProductionFilters(tasks, filters),
      );
    });

final groupedProductionTasksProvider =
    Provider<AsyncValue<List<ProductionTaskGroup>>>((ref) {
      final filters = ref.watch(productionFiltersProvider);
      final tasksAsync = ref.watch(filteredProductionTasksProvider);

      return tasksAsync.whenData(
        (tasks) => buildProductionTaskGroups(tasks, filters.grouping),
      );
    });
