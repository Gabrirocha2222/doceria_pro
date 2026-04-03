import '../../../core/money/money.dart';
import '../../ingredients/domain/ingredient_unit.dart';
import 'recipe_cost_calculator.dart';
import 'recipe_type.dart';
import 'recipe_yield_unit.dart';

class RecipeLinkedProductRecord {
  const RecipeLinkedProductRecord({
    required this.productId,
    required this.productName,
  });

  final String productId;
  final String productName;
}

class RecipeItemRecord {
  const RecipeItemRecord({
    required this.id,
    required this.recipeId,
    required this.ingredientId,
    required this.ingredientNameSnapshot,
    required this.ingredientName,
    required this.stockUnit,
    required this.quantity,
    required this.notes,
    required this.sortOrder,
    required this.lineCost,
    required this.ingredientAvailable,
  });

  final String id;
  final String recipeId;
  final String ingredientId;
  final String ingredientNameSnapshot;
  final String ingredientName;
  final IngredientUnit stockUnit;
  final int quantity;
  final String? notes;
  final int sortOrder;
  final Money lineCost;
  final bool ingredientAvailable;

  String get displayIngredientName => ingredientAvailable
      ? ingredientName
      : '$ingredientNameSnapshot (não encontrado)';

  String get displayQuantity => stockUnit.formatQuantity(quantity);

  String get displayNotes {
    final trimmedNotes = notes?.trim();
    if (trimmedNotes == null || trimmedNotes.isEmpty) {
      return 'Sem observações';
    }

    return trimmedNotes;
  }
}

class RecipeRecord {
  const RecipeRecord({
    required this.id,
    required this.name,
    required this.type,
    required this.yieldAmount,
    required this.yieldUnit,
    required this.baseLabel,
    required this.flavorLabel,
    required this.notes,
    required this.createdAt,
    required this.updatedAt,
    required this.items,
    required this.costSummary,
    required this.linkedProducts,
  });

  final String id;
  final String name;
  final RecipeType type;
  final int yieldAmount;
  final RecipeYieldUnit yieldUnit;
  final String? baseLabel;
  final String? flavorLabel;
  final String? notes;
  final DateTime createdAt;
  final DateTime updatedAt;
  final List<RecipeItemRecord> items;
  final RecipeCostSummary costSummary;
  final List<RecipeLinkedProductRecord> linkedProducts;

  String get displayYield => yieldUnit.formatAmount(yieldAmount);

  String get displayNotes {
    final trimmedNotes = notes?.trim();
    if (trimmedNotes == null || trimmedNotes.isEmpty) {
      return 'Sem observações registradas';
    }

    return trimmedNotes;
  }

  String get displayBaseLabel {
    final trimmedBase = baseLabel?.trim();
    if (trimmedBase == null || trimmedBase.isEmpty) {
      return 'Sem base definida';
    }

    return trimmedBase;
  }

  String get displayFlavorLabel {
    final trimmedFlavor = flavorLabel?.trim();
    if (trimmedFlavor == null || trimmedFlavor.isEmpty) {
      return 'Sem sabor definido';
    }

    return trimmedFlavor;
  }

  String get structureSummary {
    final parts = [
      if (baseLabel?.trim().isNotEmpty ?? false) 'Base: ${baseLabel!.trim()}',
      if (flavorLabel?.trim().isNotEmpty ?? false)
        'Sabor: ${flavorLabel!.trim()}',
    ];

    if (parts.isEmpty) {
      return 'Sem estrutura adicional';
    }

    return parts.join(' • ');
  }

  String get totalCostLabel => costSummary.totalCost.format();

  String get costPerYieldLabel =>
      '${costSummary.costPerYield.format()} por ${yieldUnit.costReferenceLabel}';

  int get itemCount => items.length;
}

class RecipeItemInput {
  const RecipeItemInput({
    required this.ingredientId,
    required this.quantity,
    required this.notes,
  });

  final String ingredientId;
  final int quantity;
  final String? notes;
}

class RecipeUpsertInput {
  const RecipeUpsertInput({
    this.id,
    required this.name,
    required this.type,
    required this.yieldAmount,
    required this.yieldUnit,
    required this.baseLabel,
    required this.flavorLabel,
    required this.notes,
    required this.items,
  });

  final String? id;
  final String name;
  final RecipeType type;
  final int yieldAmount;
  final RecipeYieldUnit yieldUnit;
  final String? baseLabel;
  final String? flavorLabel;
  final String? notes;
  final List<RecipeItemInput> items;
}
