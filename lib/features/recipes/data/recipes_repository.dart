import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../../core/database/app_database.dart';
import '../../../core/money/money.dart';
import '../../ingredients/domain/ingredient.dart';
import '../../ingredients/domain/ingredient_unit.dart';
import '../../sync/data/local_sync_support.dart';
import '../../../core/sync/sync_definitions.dart';
import '../domain/recipe.dart';
import '../domain/recipe_cost_calculator.dart';
import '../domain/recipe_type.dart';
import '../domain/recipe_yield_unit.dart';

class RecipesRepository {
  RecipesRepository(this._database);

  final AppDatabase _database;
  final Uuid _uuid = const Uuid();

  Stream<List<RecipeRecord>> watchRecipes() {
    final query = _recipeAggregateQuery();

    return query.watch().map(_mapRecipeRows);
  }

  Stream<RecipeRecord?> watchRecipe(String recipeId) {
    final query = _recipeAggregateQuery(recipeId: recipeId);

    return query.watch().map((rows) {
      final recipes = _mapRecipeRows(rows);
      if (recipes.isEmpty) {
        return null;
      }

      return recipes.single;
    });
  }

  Future<RecipeRecord?> getRecipe(String recipeId) async {
    final rows = await _recipeAggregateQuery(recipeId: recipeId).get();
    final recipes = _mapRecipeRows(rows);
    if (recipes.isEmpty) {
      return null;
    }

    return recipes.single;
  }

  Future<String> saveRecipe(RecipeUpsertInput input) async {
    final trimmedName = input.name.trim();
    if (trimmedName.isEmpty) {
      throw ArgumentError('Recipe name is required.');
    }

    if (input.yieldAmount <= 0) {
      throw ArgumentError('Recipe yield amount must be greater than zero.');
    }

    final normalizedItems = input.items
        .where(
          (item) => item.ingredientId.trim().isNotEmpty && item.quantity > 0,
        )
        .toList(growable: false);

    final recipeId = input.id ?? _uuid.v4();
    final now = DateTime.now();

    await _database.transaction(() async {
      if (input.id == null) {
        await _database
            .into(_database.recipes)
            .insert(
              RecipesCompanion.insert(
                id: recipeId,
                name: trimmedName,
                type: input.type.databaseValue,
                yieldAmount: input.yieldAmount,
                yieldUnit: input.yieldUnit.databaseValue,
                baseLabel: Value(_trimToNull(input.baseLabel)),
                flavorLabel: Value(_trimToNull(input.flavorLabel)),
                notes: Value(_trimToNull(input.notes)),
                createdAt: Value(now),
                updatedAt: Value(now),
              ),
            );
      } else {
        await (_database.update(
          _database.recipes,
        )..where((table) => table.id.equals(recipeId))).write(
          RecipesCompanion(
            name: Value(trimmedName),
            type: Value(input.type.databaseValue),
            yieldAmount: Value(input.yieldAmount),
            yieldUnit: Value(input.yieldUnit.databaseValue),
            baseLabel: Value(_trimToNull(input.baseLabel)),
            flavorLabel: Value(_trimToNull(input.flavorLabel)),
            notes: Value(_trimToNull(input.notes)),
            updatedAt: Value(now),
          ),
        );
      }

      await (_database.delete(
        _database.recipeItems,
      )..where((table) => table.recipeId.equals(recipeId))).go();

      for (var index = 0; index < normalizedItems.length; index++) {
        final item = normalizedItems[index];
        final ingredient =
            await (_database.select(_database.ingredients)
                  ..where((table) => table.id.equals(item.ingredientId)))
                .getSingleOrNull();

        if (ingredient == null) {
          throw StateError('Ingredient ${item.ingredientId} not found.');
        }

        await _database
            .into(_database.recipeItems)
            .insert(
              RecipeItemsCompanion.insert(
                id: _uuid.v4(),
                recipeId: recipeId,
                ingredientId: ingredient.id,
                ingredientNameSnapshot: ingredient.name,
                stockUnitSnapshot: ingredient.stockUnit,
                quantity: item.quantity,
                notes: Value(_trimToNull(item.notes)),
                sortOrder: Value(index),
              ),
            );
      }

      await LocalSyncSupport.markEntityChanged(
        database: _database,
        entityType: RootSyncEntityType.recipe,
        entityId: recipeId,
        updatedAt: now,
      );
    });

    return recipeId;
  }

  JoinedSelectStatement<HasResultSet, dynamic> _recipeAggregateQuery({
    String? recipeId,
  }) {
    final query = _database.select(_database.recipes).join([
      leftOuterJoin(
        _database.recipeItems,
        _database.recipeItems.recipeId.equalsExp(_database.recipes.id),
      ),
      leftOuterJoin(
        _database.ingredients,
        _database.ingredients.id.equalsExp(_database.recipeItems.ingredientId),
      ),
      leftOuterJoin(
        _database.productRecipeLinks,
        _database.productRecipeLinks.recipeId.equalsExp(_database.recipes.id),
      ),
      leftOuterJoin(
        _database.products,
        _database.products.id.equalsExp(_database.productRecipeLinks.productId),
      ),
    ]);

    if (recipeId != null) {
      query.where(_database.recipes.id.equals(recipeId));
    }

    query.orderBy([
      OrderingTerm(
        expression: _database.recipes.updatedAt,
        mode: OrderingMode.desc,
      ),
      OrderingTerm(
        expression: _database.recipeItems.sortOrder,
        mode: OrderingMode.asc,
      ),
      OrderingTerm(
        expression: _database.products.name.lower(),
        mode: OrderingMode.asc,
      ),
    ]);

    return query;
  }

  List<RecipeRecord> _mapRecipeRows(List<TypedResult> rows) {
    if (rows.isEmpty) {
      return const [];
    }

    final aggregates = <String, _RecipeAggregate>{};

    for (final row in rows) {
      final recipe = row.readTable(_database.recipes);
      final aggregate = aggregates.putIfAbsent(
        recipe.id,
        () => _RecipeAggregate(recipe: recipe),
      );

      final recipeItem = row.readTableOrNull(_database.recipeItems);
      if (recipeItem != null) {
        aggregate.addItem(
          item: recipeItem,
          ingredient: row.readTableOrNull(_database.ingredients),
        );
      }

      final product = row.readTableOrNull(_database.products);
      if (product != null) {
        aggregate.addLinkedProduct(product);
      }
    }

    return aggregates.values
        .map((aggregate) => aggregate.build())
        .toList(growable: false);
  }

  String? _trimToNull(String? value) {
    final trimmed = value?.trim();
    if (trimmed == null || trimmed.isEmpty) {
      return null;
    }

    return trimmed;
  }
}

class _RecipeAggregate {
  _RecipeAggregate({required this.recipe});

  final Recipe recipe;
  final Map<String, RecipeItemRecord> _itemsById = {};
  final Map<String, RecipeLinkedProductRecord> _linkedProductsById = {};

  void addItem({required RecipeItem item, required Ingredient? ingredient}) {
    if (_itemsById.containsKey(item.id)) {
      return;
    }

    final stockUnit = IngredientUnit.fromDatabase(
      ingredient?.stockUnit ?? item.stockUnitSnapshot,
    );
    final ingredientRecord = ingredient == null
        ? null
        : _mapIngredient(ingredient);
    final lineCost = ingredientRecord == null
        ? Money.zero
        : RecipeCostCalculator.calculateLineCost(
            ingredient: ingredientRecord,
            quantityInStockUnit: item.quantity,
          );

    _itemsById[item.id] = RecipeItemRecord(
      id: item.id,
      recipeId: item.recipeId,
      ingredientId: item.ingredientId,
      ingredientNameSnapshot: item.ingredientNameSnapshot,
      ingredientName: ingredient?.name ?? item.ingredientNameSnapshot,
      stockUnit: stockUnit,
      quantity: item.quantity,
      notes: item.notes,
      sortOrder: item.sortOrder,
      lineCost: lineCost,
      ingredientAvailable: ingredient != null,
    );
  }

  void addLinkedProduct(Product product) {
    _linkedProductsById.putIfAbsent(
      product.id,
      () => RecipeLinkedProductRecord(
        productId: product.id,
        productName: product.name,
      ),
    );
  }

  RecipeRecord build() {
    final items = _itemsById.values.toList(growable: false)
      ..sort((left, right) => left.sortOrder.compareTo(right.sortOrder));
    final totalCost = items.fold(
      Money.zero,
      (sum, item) => sum + item.lineCost,
    );
    final costSummary = RecipeCostSummary(
      totalCost: totalCost,
      costPerYield: recipe.yieldAmount <= 0
          ? Money.zero
          : Money.fromCents(
              (totalCost.cents + (recipe.yieldAmount ~/ 2)) ~/
                  recipe.yieldAmount,
            ),
      missingIngredientsCount: items
          .where((item) => item.ingredientAvailable == false)
          .length,
      pricedItemsCount: items.where((item) => item.ingredientAvailable).length,
    );

    return RecipeRecord(
      id: recipe.id,
      name: recipe.name,
      type: RecipeType.fromDatabase(recipe.type),
      yieldAmount: recipe.yieldAmount,
      yieldUnit: RecipeYieldUnit.fromDatabase(recipe.yieldUnit),
      baseLabel: recipe.baseLabel,
      flavorLabel: recipe.flavorLabel,
      notes: recipe.notes,
      createdAt: recipe.createdAt,
      updatedAt: recipe.updatedAt,
      items: items,
      costSummary: costSummary,
      linkedProducts: _linkedProductsById.values.toList(growable: false),
    );
  }

  IngredientRecord _mapIngredient(Ingredient row) {
    return IngredientRecord(
      id: row.id,
      name: row.name,
      category: row.category,
      purchaseUnit: IngredientUnit.fromDatabase(row.purchaseUnit),
      stockUnit: IngredientUnit.fromDatabase(row.stockUnit),
      currentStockQuantity: row.currentStockQuantity,
      minimumStockQuantity: row.minimumStockQuantity,
      unitCost: Money.fromCents(row.unitCostCents),
      defaultSupplier: row.defaultSupplier,
      conversionFactor: row.conversionFactor,
      notes: row.notes,
      createdAt: row.createdAt,
      updatedAt: row.updatedAt,
    );
  }
}
