import '../../../core/formatters/app_formatters.dart';

enum IngredientUnitFamily { weight, volume, count }

enum IngredientUnit {
  kilogram(
    databaseValue: 'kilogram',
    label: 'Quilo',
    shortLabel: 'kg',
    family: IngredientUnitFamily.weight,
  ),
  gram(
    databaseValue: 'gram',
    label: 'Grama',
    shortLabel: 'g',
    family: IngredientUnitFamily.weight,
  ),
  liter(
    databaseValue: 'liter',
    label: 'Litro',
    shortLabel: 'L',
    family: IngredientUnitFamily.volume,
  ),
  milliliter(
    databaseValue: 'milliliter',
    label: 'Mililitro',
    shortLabel: 'ml',
    family: IngredientUnitFamily.volume,
  ),
  unit(
    databaseValue: 'unit',
    label: 'Unidade',
    shortLabel: 'un',
    family: IngredientUnitFamily.count,
  ),
  package(
    databaseValue: 'package',
    label: 'Pacote',
    shortLabel: 'pacote',
    family: null,
  );

  const IngredientUnit({
    required this.databaseValue,
    required this.label,
    required this.shortLabel,
    required this.family,
  });

  final String databaseValue;
  final String label;
  final String shortLabel;
  final IngredientUnitFamily? family;

  bool get canBeStockUnit =>
      this == IngredientUnit.gram ||
      this == IngredientUnit.milliliter ||
      this == IngredientUnit.unit;

  bool get isPackage => this == IngredientUnit.package;

  IngredientUnit? get defaultStockUnit {
    switch (this) {
      case IngredientUnit.kilogram:
      case IngredientUnit.gram:
        return IngredientUnit.gram;
      case IngredientUnit.liter:
      case IngredientUnit.milliliter:
        return IngredientUnit.milliliter;
      case IngredientUnit.unit:
        return IngredientUnit.unit;
      case IngredientUnit.package:
        return null;
    }
  }

  int? defaultConversionFactor(IngredientUnit stockUnit) {
    if (this == IngredientUnit.package) {
      return null;
    }

    return switch ((this, stockUnit)) {
      (IngredientUnit.kilogram, IngredientUnit.gram) => 1000,
      (IngredientUnit.gram, IngredientUnit.gram) => 1,
      (IngredientUnit.liter, IngredientUnit.milliliter) => 1000,
      (IngredientUnit.milliliter, IngredientUnit.milliliter) => 1,
      (IngredientUnit.unit, IngredientUnit.unit) => 1,
      _ => null,
    };
  }

  String formatQuantity(int quantity) {
    return '${AppFormatters.wholeNumber(quantity)} $shortLabel';
  }

  static IngredientUnit fromDatabase(String value) {
    return values.firstWhere(
      (unit) => unit.databaseValue == value,
      orElse: () => IngredientUnit.unit,
    );
  }
}

List<IngredientUnit> availableStockUnitsForPurchase(
  IngredientUnit purchaseUnit,
) {
  final defaultStockUnit = purchaseUnit.defaultStockUnit;
  if (defaultStockUnit != null) {
    return [defaultStockUnit];
  }

  return const [
    IngredientUnit.gram,
    IngredientUnit.milliliter,
    IngredientUnit.unit,
  ];
}
