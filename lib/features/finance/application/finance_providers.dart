import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
import '../../orders/application/order_providers.dart';
import '../data/finance_repository.dart';
import '../domain/finance.dart';

final financeRepositoryProvider = Provider<FinanceRepository>((ref) {
  return FinanceRepository(ref.watch(appDatabaseProvider));
});

class FinanceViewNotifier extends Notifier<FinanceView> {
  @override
  FinanceView build() => FinanceView.overview;

  void updateView(FinanceView view) {
    state = view;
  }
}

final financeViewProvider = NotifierProvider<FinanceViewNotifier, FinanceView>(
  FinanceViewNotifier.new,
);

class FinancePeriodFilterNotifier extends Notifier<FinancePeriodFilter> {
  @override
  FinancePeriodFilter build() => FinancePeriodFilter.daily;

  void updateFilter(FinancePeriodFilter filter) {
    state = filter;
  }
}

final financePeriodFilterProvider =
    NotifierProvider<FinancePeriodFilterNotifier, FinancePeriodFilter>(
      FinancePeriodFilterNotifier.new,
    );

final financeReceivablesProvider =
    StreamProvider<List<FinanceReceivableRecord>>((ref) {
      return ref.watch(financeRepositoryProvider).watchReceivables();
    });

final financeExpensesProvider = StreamProvider<List<FinanceExpenseRecord>>((
  ref,
) {
  return ref.watch(financeRepositoryProvider).watchExpenses();
});

final financeManualEntriesProvider =
    StreamProvider<List<FinanceManualEntryRecord>>((ref) {
      return ref.watch(financeRepositoryProvider).watchManualEntries();
    });

final financeOverviewProvider = Provider<AsyncValue<FinanceOverviewMetrics>>((
  ref,
) {
  final periodFilter = ref.watch(financePeriodFilterProvider);
  final ordersAsync = ref.watch(ordersProvider);
  final receivablesAsync = ref.watch(financeReceivablesProvider);
  final expensesAsync = ref.watch(financeExpensesProvider);
  final manualEntriesAsync = ref.watch(financeManualEntriesProvider);

  final errorState =
      ordersAsync.asError ??
      receivablesAsync.asError ??
      expensesAsync.asError ??
      manualEntriesAsync.asError;
  if (errorState != null) {
    return AsyncValue.error(errorState.error, errorState.stackTrace);
  }

  if (ordersAsync.isLoading ||
      receivablesAsync.isLoading ||
      expensesAsync.isLoading ||
      manualEntriesAsync.isLoading) {
    return const AsyncValue.loading();
  }

  final orders = ordersAsync.asData?.value;
  final receivables = receivablesAsync.asData?.value;
  final expenses = expensesAsync.asData?.value;
  final manualEntries = manualEntriesAsync.asData?.value;
  if (orders == null ||
      receivables == null ||
      expenses == null ||
      manualEntries == null) {
    return const AsyncValue.loading();
  }

  return AsyncValue.data(
    buildFinanceOverview(
      filter: periodFilter,
      orders: orders,
      receivables: receivables,
      expenses: expenses,
      manualEntries: manualEntries,
    ),
  );
});

final filteredFinanceReceivablesProvider =
    Provider<AsyncValue<List<FinanceReceivableRecord>>>((ref) {
      final periodFilter = ref.watch(financePeriodFilterProvider);
      final receivablesAsync = ref.watch(financeReceivablesProvider);

      return receivablesAsync.whenData(
        (receivables) => filterReceivablesByPeriod(receivables, periodFilter),
      );
    });

final filteredFinanceExpensesProvider =
    Provider<AsyncValue<List<FinanceExpenseRecord>>>((ref) {
      final periodFilter = ref.watch(financePeriodFilterProvider);
      final expensesAsync = ref.watch(financeExpensesProvider);

      return expensesAsync.whenData(
        (expenses) => filterExpensesByPeriod(expenses, periodFilter),
      );
    });

final filteredFinanceManualEntriesProvider =
    Provider<AsyncValue<List<FinanceManualEntryRecord>>>((ref) {
      final periodFilter = ref.watch(financePeriodFilterProvider);
      final manualEntriesAsync = ref.watch(financeManualEntriesProvider);

      return manualEntriesAsync.whenData(
        (entries) => filterManualEntriesByPeriod(entries, periodFilter),
      );
    });
