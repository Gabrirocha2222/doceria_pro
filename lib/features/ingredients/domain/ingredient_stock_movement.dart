import 'ingredient_stock_movement_type.dart';
import 'ingredient_unit.dart';

class IngredientStockMovementRecord {
  const IngredientStockMovementRecord({
    required this.id,
    required this.ingredientId,
    required this.movementType,
    required this.quantityDelta,
    required this.previousStockQuantity,
    required this.resultingStockQuantity,
    required this.reason,
    required this.notes,
    required this.referenceType,
    required this.referenceId,
    required this.createdAt,
  });

  final String id;
  final String ingredientId;
  final IngredientStockMovementType movementType;
  final int quantityDelta;
  final int previousStockQuantity;
  final int resultingStockQuantity;
  final String reason;
  final String? notes;
  final String? referenceType;
  final String? referenceId;
  final DateTime createdAt;

  bool get isIncrease => quantityDelta > 0;

  String formatDelta(IngredientUnit stockUnit) {
    final prefix = isIncrease ? '+' : '-';
    return '$prefix${stockUnit.formatQuantity(quantityDelta.abs())}';
  }
}

class IngredientStockAdjustmentInput {
  const IngredientStockAdjustmentInput({
    required this.ingredientId,
    required this.quantityDelta,
    required this.reason,
    required this.notes,
  });

  final String ingredientId;
  final int quantityDelta;
  final String reason;
  final String? notes;
}
