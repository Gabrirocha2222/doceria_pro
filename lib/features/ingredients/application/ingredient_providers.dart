import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
import '../data/ingredients_repository.dart';
import '../domain/ingredient.dart';
import '../domain/ingredient_list_filters.dart';
import '../domain/ingredient_stock_movement.dart';

final ingredientsRepositoryProvider = Provider<IngredientsRepository>((ref) {
  return IngredientsRepository(ref.watch(appDatabaseProvider));
});

class IngredientListFiltersNotifier extends Notifier<IngredientListFilters> {
  @override
  IngredientListFilters build() => const IngredientListFilters();

  void updateSearchQuery(String value) {
    state = state.copyWith(searchQuery: value);
  }

  void updateStockFilter(IngredientStockFilter value) {
    state = state.copyWith(stockFilter: value);
  }

  void clear() {
    state = const IngredientListFilters();
  }
}

final ingredientListFiltersProvider =
    NotifierProvider<IngredientListFiltersNotifier, IngredientListFilters>(
      IngredientListFiltersNotifier.new,
    );

final allIngredientsProvider = StreamProvider<List<IngredientRecord>>((ref) {
  return ref.watch(ingredientsRepositoryProvider).watchIngredients();
});

final filteredIngredientsProvider =
    Provider<AsyncValue<List<IngredientRecord>>>((ref) {
      final filters = ref.watch(ingredientListFiltersProvider);
      final ingredientsAsync = ref.watch(allIngredientsProvider);

      return ingredientsAsync.whenData(filters.apply);
    });

final lowStockIngredientsProvider =
    Provider<AsyncValue<List<IngredientRecord>>>((ref) {
      final ingredientsAsync = ref.watch(allIngredientsProvider);

      return ingredientsAsync.whenData(
        (ingredients) =>
            ingredients.where((ingredient) => ingredient.isLowStock).toList(),
      );
    });

final ingredientProvider = StreamProvider.autoDispose
    .family<IngredientRecord?, String>((ref, ingredientId) {
      return ref
          .watch(ingredientsRepositoryProvider)
          .watchIngredient(ingredientId);
    });

final ingredientStockMovementsProvider = StreamProvider.autoDispose
    .family<List<IngredientStockMovementRecord>, String>((ref, ingredientId) {
      return ref
          .watch(ingredientsRepositoryProvider)
          .watchStockMovements(ingredientId);
    });
