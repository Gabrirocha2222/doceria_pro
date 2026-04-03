import 'package:doceria_pro/core/money/money.dart';
import 'package:doceria_pro/features/ingredients/domain/ingredient.dart';
import 'package:doceria_pro/features/ingredients/domain/ingredient_unit.dart';
import 'package:doceria_pro/features/recipes/domain/recipe_cost_calculator.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('calculates ingredient line cost using stock conversion safely', () {
    final ingredient = IngredientRecord(
      id: 'ingredient-1',
      name: 'Chocolate em pó',
      category: 'Secos',
      purchaseUnit: IngredientUnit.kilogram,
      stockUnit: IngredientUnit.gram,
      currentStockQuantity: 1500,
      minimumStockQuantity: 300,
      unitCost: Money.fromCents(4200),
      defaultSupplier: null,
      conversionFactor: 1000,
      notes: null,
      createdAt: DateTime(2026, 4, 2),
      updatedAt: DateTime(2026, 4, 2),
    );

    final cost = RecipeCostCalculator.calculateLineCost(
      ingredient: ingredient,
      quantityInStockUnit: 250,
    );

    expect(cost, Money.fromCents(1050));
  });

  test('rounds package-based cost and cost per yield without doubles', () {
    final ingredient = IngredientRecord(
      id: 'ingredient-2',
      name: 'Granulado',
      category: 'Cobertura',
      purchaseUnit: IngredientUnit.package,
      stockUnit: IngredientUnit.gram,
      currentStockQuantity: 1000,
      minimumStockQuantity: 200,
      unitCost: Money.fromCents(790),
      defaultSupplier: null,
      conversionFactor: 500,
      notes: null,
      createdAt: DateTime(2026, 4, 2),
      updatedAt: DateTime(2026, 4, 2),
    );

    final summary = RecipeCostCalculator.calculateSummary(
      items: const [
        RecipeCostEntry(ingredientId: 'ingredient-2', quantityInStockUnit: 125),
      ],
      ingredientsById: {'ingredient-2': ingredient},
      yieldAmount: 3,
    );

    expect(summary.totalCost, Money.fromCents(198));
    expect(summary.costPerYield, Money.fromCents(66));
  });
}
