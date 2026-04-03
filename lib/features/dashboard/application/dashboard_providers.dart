import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../finance/application/finance_providers.dart';
import '../../ingredients/application/ingredient_providers.dart';
import '../../orders/application/order_providers.dart';
import '../../production/application/production_providers.dart';
import '../../purchases/application/purchase_providers.dart';
import '../domain/dashboard.dart';

final dashboardSnapshotProvider = Provider<AsyncValue<DashboardSnapshot>>((
  ref,
) {
  final ordersAsync = ref.watch(ordersProvider);
  final productionTasksAsync = ref.watch(productionTasksProvider);
  final purchaseChecklistAsync = ref.watch(purchaseChecklistProvider);
  final receivablesAsync = ref.watch(financeReceivablesProvider);
  final expensesAsync = ref.watch(financeExpensesProvider);
  final manualEntriesAsync = ref.watch(financeManualEntriesProvider);
  final lowStockIngredientsAsync = ref.watch(lowStockIngredientsProvider);

  final errorState =
      ordersAsync.asError ??
      productionTasksAsync.asError ??
      purchaseChecklistAsync.asError ??
      receivablesAsync.asError ??
      expensesAsync.asError ??
      manualEntriesAsync.asError ??
      lowStockIngredientsAsync.asError;
  if (errorState != null) {
    return AsyncValue.error(errorState.error, errorState.stackTrace);
  }

  final orders = ordersAsync.asData?.value ?? const [];
  final productionTasks = productionTasksAsync.asData?.value ?? const [];
  final purchaseChecklist = purchaseChecklistAsync.asData?.value ?? const [];
  final receivables = receivablesAsync.asData?.value ?? const [];
  final expenses = expensesAsync.asData?.value ?? const [];
  final manualEntries = manualEntriesAsync.asData?.value ?? const [];
  final lowStockIngredients =
      lowStockIngredientsAsync.asData?.value ?? const [];

  return AsyncValue.data(
    buildDashboardSnapshot(
      orders: orders,
      productionTasks: productionTasks,
      purchaseItems: purchaseChecklist,
      receivables: receivables,
      expenses: expenses,
      manualEntries: manualEntries,
      lowStockIngredients: lowStockIngredients,
    ),
  );
});
