import 'recipe.dart';
import 'recipe_type.dart';

enum RecipeTypeFilter {
  all(label: 'Todos'),
  dough(label: 'Massa', type: RecipeType.dough),
  filling(label: 'Recheio', type: RecipeType.filling),
  topping(label: 'Cobertura', type: RecipeType.topping),
  base(label: 'Base', type: RecipeType.base),
  complete(label: 'Completa', type: RecipeType.complete);

  const RecipeTypeFilter({required this.label, this.type});

  final String label;
  final RecipeType? type;
}

class RecipeListFilters {
  const RecipeListFilters({
    this.searchQuery = '',
    this.typeFilter = RecipeTypeFilter.all,
  });

  final String searchQuery;
  final RecipeTypeFilter typeFilter;

  bool get hasActiveFilters =>
      searchQuery.trim().isNotEmpty || typeFilter != RecipeTypeFilter.all;

  RecipeListFilters copyWith({
    String? searchQuery,
    RecipeTypeFilter? typeFilter,
  }) {
    return RecipeListFilters(
      searchQuery: searchQuery ?? this.searchQuery,
      typeFilter: typeFilter ?? this.typeFilter,
    );
  }

  List<RecipeRecord> apply(List<RecipeRecord> recipes) {
    final normalizedQuery = searchQuery.trim().toLowerCase();

    return recipes
        .where((recipe) {
          final matchesQuery =
              normalizedQuery.isEmpty ||
              recipe.name.toLowerCase().contains(normalizedQuery) ||
              recipe.type.label.toLowerCase().contains(normalizedQuery) ||
              recipe.displayBaseLabel.toLowerCase().contains(normalizedQuery) ||
              recipe.displayFlavorLabel.toLowerCase().contains(normalizedQuery);
          final matchesType =
              typeFilter.type == null || recipe.type == typeFilter.type;

          return matchesQuery && matchesType;
        })
        .toList(growable: false);
  }
}
