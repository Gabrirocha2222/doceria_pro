import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
import '../data/recipes_repository.dart';
import '../domain/recipe.dart';
import '../domain/recipe_list_filters.dart';

final recipesRepositoryProvider = Provider<RecipesRepository>((ref) {
  return RecipesRepository(ref.watch(appDatabaseProvider));
});

class RecipeListFiltersNotifier extends Notifier<RecipeListFilters> {
  @override
  RecipeListFilters build() => const RecipeListFilters();

  void updateSearchQuery(String value) {
    state = state.copyWith(searchQuery: value);
  }

  void updateTypeFilter(RecipeTypeFilter value) {
    state = state.copyWith(typeFilter: value);
  }

  void clear() {
    state = const RecipeListFilters();
  }
}

final recipeListFiltersProvider =
    NotifierProvider<RecipeListFiltersNotifier, RecipeListFilters>(
      RecipeListFiltersNotifier.new,
    );

final allRecipesProvider = StreamProvider<List<RecipeRecord>>((ref) {
  return ref.watch(recipesRepositoryProvider).watchRecipes();
});

final filteredRecipesProvider = Provider<AsyncValue<List<RecipeRecord>>>((ref) {
  final filters = ref.watch(recipeListFiltersProvider);
  final recipesAsync = ref.watch(allRecipesProvider);

  return recipesAsync.whenData(filters.apply);
});

final recipeProvider = StreamProvider.autoDispose.family<RecipeRecord?, String>(
  (ref, recipeId) {
    return ref.watch(recipesRepositoryProvider).watchRecipe(recipeId);
  },
);
