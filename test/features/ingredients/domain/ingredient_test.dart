import 'package:doceria_pro/core/money/money.dart';
import 'package:doceria_pro/features/ingredients/domain/ingredient.dart';
import 'package:doceria_pro/features/ingredients/domain/ingredient_list_filters.dart';
import 'package:doceria_pro/features/ingredients/domain/ingredient_unit.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('low stock depends on configured minimum', () {
    final ingredient = IngredientRecord(
      id: 'ingredient-1',
      name: 'Farinha',
      category: 'Secos',
      purchaseUnit: IngredientUnit.kilogram,
      stockUnit: IngredientUnit.gram,
      currentStockQuantity: 900,
      minimumStockQuantity: 1000,
      unitCost: Money.fromCents(850),
      defaultSupplier: null,
      conversionFactor: 1000,
      notes: null,
      createdAt: DateTime(2026, 4, 2),
      updatedAt: DateTime(2026, 4, 2),
    );

    expect(ingredient.isLowStock, isTrue);
    expect(ingredient.displayCurrentStock, '900 g');
    expect(ingredient.conversionSummary, '1 kg = 1.000 g');
  });

  test('filters can isolate low stock ingredients locally', () {
    final ingredients = [
      IngredientRecord(
        id: '1',
        name: 'Farinha',
        category: 'Secos',
        purchaseUnit: IngredientUnit.kilogram,
        stockUnit: IngredientUnit.gram,
        currentStockQuantity: 900,
        minimumStockQuantity: 1000,
        unitCost: Money.fromCents(850),
        defaultSupplier: null,
        conversionFactor: 1000,
        notes: null,
        createdAt: DateTime(2026, 4, 2),
        updatedAt: DateTime(2026, 4, 2),
      ),
      IngredientRecord(
        id: '2',
        name: 'Leite',
        category: 'Laticínios',
        purchaseUnit: IngredientUnit.liter,
        stockUnit: IngredientUnit.milliliter,
        currentStockQuantity: 4000,
        minimumStockQuantity: 1000,
        unitCost: Money.fromCents(599),
        defaultSupplier: null,
        conversionFactor: 1000,
        notes: null,
        createdAt: DateTime(2026, 4, 2),
        updatedAt: DateTime(2026, 4, 2),
      ),
    ];

    final filtered = const IngredientListFilters(
      searchQuery: 'secos',
      stockFilter: IngredientStockFilter.lowStockOnly,
    ).apply(ingredients);

    expect(filtered, hasLength(1));
    expect(filtered.single.id, '1');
  });

  test(
    'display supplier prefers linked supplier over legacy snapshot text',
    () {
      final ingredient = IngredientRecord(
        id: 'ingredient-1',
        name: 'Chocolate',
        category: 'Secos',
        purchaseUnit: IngredientUnit.kilogram,
        stockUnit: IngredientUnit.gram,
        currentStockQuantity: 1500,
        minimumStockQuantity: 500,
        unitCost: Money.fromCents(3200),
        defaultSupplier: 'Texto antigo',
        conversionFactor: 1000,
        notes: null,
        createdAt: DateTime(2026, 4, 2),
        updatedAt: DateTime(2026, 4, 2),
        linkedSuppliers: const [
          IngredientLinkedSupplierRecord(
            supplierId: 'supplier-1',
            supplierName: 'Distribuidora Atual',
            contact: null,
            leadTimeDays: 2,
            isDefaultPreferred: true,
            lastKnownPrice: null,
            lastKnownPriceUnitLabel: null,
            lastKnownPriceAt: null,
          ),
        ],
      );

      expect(ingredient.displaySupplier, 'Distribuidora Atual');
      expect(ingredient.hasSupplierReference, isTrue);
    },
  );
}
