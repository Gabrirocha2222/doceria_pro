import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
import '../../ingredients/application/ingredient_providers.dart';
import '../../packaging/application/packaging_providers.dart';
import '../../suppliers/application/supplier_providers.dart';
import '../data/purchases_repository.dart';
import '../domain/purchase.dart';

final purchasesRepositoryProvider = Provider<PurchasesRepository>((ref) {
  return PurchasesRepository(ref.watch(appDatabaseProvider));
});

class PurchaseListViewNotifier extends Notifier<PurchaseListView> {
  @override
  PurchaseListView build() => PurchaseListView.buyNow;

  void updateView(PurchaseListView view) {
    state = view;
  }
}

final purchaseListViewProvider =
    NotifierProvider<PurchaseListViewNotifier, PurchaseListView>(
      PurchaseListViewNotifier.new,
    );

final projectedPurchaseNeedsProvider =
    StreamProvider<List<PurchaseProjectedNeedRecord>>((ref) {
      return ref.watch(purchasesRepositoryProvider).watchProjectedNeeds();
    });

final preparedPurchaseExpenseDraftsProvider =
    StreamProvider<List<PurchaseExpenseDraftRecord>>((ref) {
      return ref
          .watch(purchasesRepositoryProvider)
          .watchPreparedExpenseDrafts();
    });

final purchaseChecklistProvider =
    Provider<AsyncValue<List<PurchaseChecklistItemRecord>>>((ref) {
      final projectedNeedsAsync = ref.watch(projectedPurchaseNeedsProvider);
      final ingredientsAsync = ref.watch(allIngredientsProvider);
      final packagingAsync = ref.watch(allPackagingProvider);
      final suppliersAsync = ref.watch(allSuppliersProvider);

      final errorState =
          projectedNeedsAsync.asError ??
          ingredientsAsync.asError ??
          packagingAsync.asError ??
          suppliersAsync.asError;
      if (errorState != null) {
        return AsyncValue.error(errorState.error, errorState.stackTrace);
      }

      final isLoading =
          projectedNeedsAsync.isLoading ||
          ingredientsAsync.isLoading ||
          packagingAsync.isLoading ||
          suppliersAsync.isLoading;
      if (isLoading) {
        return const AsyncValue.loading();
      }

      final projectedNeeds = projectedNeedsAsync.asData?.value;
      final ingredients = ingredientsAsync.asData?.value;
      final packagingItems = packagingAsync.asData?.value;
      final suppliers = suppliersAsync.asData?.value;

      if (projectedNeeds == null ||
          ingredients == null ||
          packagingItems == null ||
          suppliers == null) {
        return const AsyncValue.loading();
      }

      return AsyncValue.data(
        buildPurchaseChecklist(
          projectedNeeds: projectedNeeds,
          ingredients: ingredients,
          packagingItems: packagingItems,
          suppliers: suppliers,
        ),
      );
    });

final visiblePurchaseItemsProvider =
    Provider<AsyncValue<List<PurchaseChecklistItemRecord>>>((ref) {
      final view = ref.watch(purchaseListViewProvider);
      final checklistAsync = ref.watch(purchaseChecklistProvider);

      return checklistAsync.whenData((items) => applyPurchaseView(items, view));
    });

final groupedPurchasesBySupplierProvider =
    Provider<AsyncValue<List<PurchaseSupplierGroup>>>((ref) {
      final checklistAsync = ref.watch(purchaseChecklistProvider);

      return checklistAsync.whenData(
        (items) => buildPurchaseGroupsBySupplier(
          applyPurchaseView(items, PurchaseListView.bySupplier),
        ),
      );
    });
