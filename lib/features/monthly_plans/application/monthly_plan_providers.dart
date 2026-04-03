import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
import '../../orders/application/order_providers.dart';
import '../data/monthly_plans_repository.dart';
import '../domain/monthly_plan.dart';
import '../domain/monthly_plan_list_filters.dart';
import 'monthly_plan_generation_service.dart';

final monthlyPlansRepositoryProvider = Provider<MonthlyPlansRepository>((ref) {
  return MonthlyPlansRepository(ref.watch(appDatabaseProvider));
});

final monthlyPlanGenerationServiceProvider =
    Provider<MonthlyPlanGenerationService>((ref) {
      return MonthlyPlanGenerationService(
        monthlyPlansRepository: ref.watch(monthlyPlansRepositoryProvider),
        ordersRepository: ref.watch(ordersRepositoryProvider),
      );
    });

class MonthlyPlanListFiltersNotifier extends Notifier<MonthlyPlanListFilters> {
  @override
  MonthlyPlanListFilters build() => const MonthlyPlanListFilters();

  void updateSearchQuery(String value) {
    state = state.copyWith(searchQuery: value);
  }

  void updateStateFilter(MonthlyPlanStateFilter value) {
    state = state.copyWith(stateFilter: value);
  }

  void clear() {
    state = const MonthlyPlanListFilters();
  }
}

final monthlyPlanListFiltersProvider =
    NotifierProvider<MonthlyPlanListFiltersNotifier, MonthlyPlanListFilters>(
      MonthlyPlanListFiltersNotifier.new,
    );

final allMonthlyPlansProvider = StreamProvider<List<MonthlyPlanRecord>>((ref) {
  return ref.watch(monthlyPlansRepositoryProvider).watchMonthlyPlans();
});

final filteredMonthlyPlansProvider =
    Provider<AsyncValue<List<MonthlyPlanRecord>>>((ref) {
      final filters = ref.watch(monthlyPlanListFiltersProvider);
      final plansAsync = ref.watch(allMonthlyPlansProvider);

      return plansAsync.whenData(filters.apply);
    });

final monthlyPlanProvider = StreamProvider.autoDispose
    .family<MonthlyPlanRecord?, String>((ref, monthlyPlanId) {
      return ref
          .watch(monthlyPlansRepositoryProvider)
          .watchMonthlyPlan(monthlyPlanId);
    });

final clientMonthlyPlansProvider = StreamProvider.autoDispose
    .family<List<MonthlyPlanRecord>, String>((ref, clientId) {
      return ref
          .watch(monthlyPlansRepositoryProvider)
          .watchMonthlyPlansForClient(clientId);
    });

final monthlyPlanFutureImpactProvider = Provider.autoDispose
    .family<AsyncValue<MonthlyPlanFutureImpact?>, String>((ref, monthlyPlanId) {
      final monthlyPlanAsync = ref.watch(monthlyPlanProvider(monthlyPlanId));

      return monthlyPlanAsync.whenData((monthlyPlan) {
        if (monthlyPlan == null) {
          return null;
        }

        return buildMonthlyPlanFutureImpact(monthlyPlan);
      });
    });
