enum IngredientStockMovementType {
  manualAdjustment('manual_adjustment', 'Ajuste manual'),
  purchaseEntry('purchase_entry', 'Entrada de compra'),
  productionConsumption('production_consumption', 'Baixa de produção'),
  correction('correction', 'Correção');

  const IngredientStockMovementType(this.databaseValue, this.label);

  final String databaseValue;
  final String label;

  static IngredientStockMovementType fromDatabase(String value) {
    return values.firstWhere(
      (movementType) => movementType.databaseValue == value,
      orElse: () => manualAdjustment,
    );
  }
}
