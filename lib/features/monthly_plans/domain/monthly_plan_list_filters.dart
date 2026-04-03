import 'monthly_plan.dart';

enum MonthlyPlanStateFilter {
  all(label: 'Todos'),
  active(label: 'Em andamento'),
  completed(label: 'Concluídos');

  const MonthlyPlanStateFilter({required this.label});

  final String label;
}

class MonthlyPlanListFilters {
  const MonthlyPlanListFilters({
    this.searchQuery = '',
    this.stateFilter = MonthlyPlanStateFilter.active,
  });

  final String searchQuery;
  final MonthlyPlanStateFilter stateFilter;

  bool get hasActiveFilters =>
      searchQuery.trim().isNotEmpty ||
      stateFilter != MonthlyPlanStateFilter.active;

  MonthlyPlanListFilters copyWith({
    String? searchQuery,
    MonthlyPlanStateFilter? stateFilter,
  }) {
    return MonthlyPlanListFilters(
      searchQuery: searchQuery ?? this.searchQuery,
      stateFilter: stateFilter ?? this.stateFilter,
    );
  }

  List<MonthlyPlanRecord> apply(List<MonthlyPlanRecord> plans) {
    final normalizedQuery = searchQuery.trim().toLowerCase();

    return plans
        .where((plan) {
          final matchesQuery =
              normalizedQuery.isEmpty ||
              plan.title.toLowerCase().contains(normalizedQuery) ||
              plan.clientNameSnapshot.toLowerCase().contains(normalizedQuery) ||
              plan.displayTemplateProductName.toLowerCase().contains(
                normalizedQuery,
              );

          final matchesState = switch (stateFilter) {
            MonthlyPlanStateFilter.all => true,
            MonthlyPlanStateFilter.active => !plan.isCompleted,
            MonthlyPlanStateFilter.completed => plan.isCompleted,
          };

          return matchesQuery && matchesState;
        })
        .toList(growable: false);
  }
}
