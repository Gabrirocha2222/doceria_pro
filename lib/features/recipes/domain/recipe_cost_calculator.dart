import '../../../core/money/money.dart';
import '../../ingredients/domain/ingredient.dart';

class RecipeCostEntry {
  const RecipeCostEntry({
    required this.ingredientId,
    required this.quantityInStockUnit,
  });

  final String ingredientId;
  final int quantityInStockUnit;
}

class RecipeCostSummary {
  const RecipeCostSummary({
    required this.totalCost,
    required this.costPerYield,
    required this.missingIngredientsCount,
    required this.pricedItemsCount,
  });

  final Money totalCost;
  final Money costPerYield;
  final int missingIngredientsCount;
  final int pricedItemsCount;

  bool get hasMissingIngredients => missingIngredientsCount > 0;
}

abstract final class RecipeCostCalculator {
  static RecipeCostSummary calculateSummary({
    required Iterable<RecipeCostEntry> items,
    required Map<String, IngredientRecord> ingredientsById,
    required int yieldAmount,
  }) {
    var totalCostCents = 0;
    var missingIngredientsCount = 0;
    var pricedItemsCount = 0;

    for (final item in items) {
      final ingredient = ingredientsById[item.ingredientId];
      if (ingredient == null) {
        missingIngredientsCount += 1;
        continue;
      }

      totalCostCents += calculateLineCost(
        ingredient: ingredient,
        quantityInStockUnit: item.quantityInStockUnit,
      ).cents;
      pricedItemsCount += 1;
    }

    final totalCost = Money.fromCents(totalCostCents);
    final costPerYield = yieldAmount <= 0
        ? Money.zero
        : _roundedDivision(totalCost.cents, yieldAmount);

    return RecipeCostSummary(
      totalCost: totalCost,
      costPerYield: costPerYield,
      missingIngredientsCount: missingIngredientsCount,
      pricedItemsCount: pricedItemsCount,
    );
  }

  static Money calculateLineCost({
    required IngredientRecord ingredient,
    required int quantityInStockUnit,
  }) {
    if (quantityInStockUnit <= 0 || ingredient.conversionFactor <= 0) {
      return Money.zero;
    }

    final numerator = ingredient.unitCost.cents * quantityInStockUnit;
    return _roundedDivision(numerator, ingredient.conversionFactor);
  }

  static Money _roundedDivision(int numerator, int denominator) {
    if (denominator <= 0) {
      return Money.zero;
    }

    final rounded = (numerator + (denominator ~/ 2)) ~/ denominator;
    return Money.fromCents(rounded);
  }
}
