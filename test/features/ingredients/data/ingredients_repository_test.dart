import 'package:doceria_pro/core/database/app_database.dart';
import 'package:doceria_pro/core/money/money.dart';
import 'package:doceria_pro/features/ingredients/data/ingredients_repository.dart';
import 'package:doceria_pro/features/ingredients/domain/ingredient.dart';
import 'package:doceria_pro/features/ingredients/domain/ingredient_stock_movement.dart';
import 'package:doceria_pro/features/ingredients/domain/ingredient_unit.dart';
import 'package:doceria_pro/features/suppliers/data/suppliers_repository.dart';
import 'package:doceria_pro/features/suppliers/domain/supplier.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase database;
  late IngredientsRepository repository;
  late SuppliersRepository suppliersRepository;

  setUp(() {
    database = AppDatabase(NativeDatabase.memory());
    repository = IngredientsRepository(database);
    suppliersRepository = SuppliersRepository(database);
  });

  tearDown(() async {
    await database.close();
  });

  test('saves and reads a locally persisted ingredient', () async {
    final savedId = await repository.saveIngredient(
      IngredientUpsertInput(
        name: 'Chocolate em pó',
        category: 'Secos',
        purchaseUnit: IngredientUnit.kilogram,
        stockUnit: IngredientUnit.gram,
        currentStockQuantity: 2500,
        minimumStockQuantity: 1000,
        unitCost: Money.fromCents(4200),
        defaultSupplier: 'Distribuidora Central',
        conversionFactor: 1000,
        notes: 'Usar para brigadeiro e recheio.',
      ),
    );

    final ingredients = await repository.watchIngredients().first;

    expect(ingredients, hasLength(1));
    expect(ingredients.single.id, savedId);
    expect(ingredients.single.name, 'Chocolate em pó');
    expect(ingredients.single.displayCategory, 'Secos');
    expect(ingredients.single.displayCurrentStock, '2.500 g');
    expect(ingredients.single.displayMinimumStock, '1.000 g');
    expect(ingredients.single.displayUnitCost, 'R\$ 42,00 / kg');
    expect(ingredients.single.displaySupplier, 'Distribuidora Central');
    expect(ingredients.single.conversionSummary, '1 kg = 1.000 g');
    expect(ingredients.single.isLowStock, isFalse);
  });

  test('adjusts stock and records a local stock movement', () async {
    final savedId = await repository.saveIngredient(
      IngredientUpsertInput(
        name: 'Leite condensado',
        category: 'Laticínios',
        purchaseUnit: IngredientUnit.unit,
        stockUnit: IngredientUnit.unit,
        currentStockQuantity: 8,
        minimumStockQuantity: 5,
        unitCost: Money.fromCents(699),
        defaultSupplier: null,
        conversionFactor: 1,
        notes: null,
      ),
    );

    await repository
        .adjustStock(
          const IngredientStockAdjustmentInput(
            ingredientId: 'placeholder',
            quantityDelta: 0,
            reason: '',
            notes: null,
          ),
        )
        .catchError((_) {});

    await repository.adjustStock(
      IngredientStockAdjustmentInput(
        ingredientId: savedId,
        quantityDelta: -3,
        reason: 'Uso na produção',
        notes: 'Feito para recheios do dia.',
      ),
    );

    final ingredient = await repository.getIngredient(savedId);
    final movements = await repository.watchStockMovements(savedId).first;

    expect(ingredient, isNotNull);
    expect(ingredient!.currentStockQuantity, 5);
    expect(ingredient.isLowStock, isTrue);
    expect(movements, hasLength(1));
    expect(movements.single.quantityDelta, -3);
    expect(movements.single.previousStockQuantity, 8);
    expect(movements.single.resultingStockQuantity, 5);
    expect(movements.single.reason, 'Uso na produção');
  });

  test(
    'loads preferred supplier and alternatives from linked supplier records',
    () async {
      final preferredSupplierId = await suppliersRepository.saveSupplier(
        const SupplierUpsertInput(
          name: 'Atacadista Central',
          contact: 'WhatsApp',
          notes: null,
          leadTimeDays: 2,
          isActive: true,
        ),
      );
      final alternativeSupplierId = await suppliersRepository.saveSupplier(
        const SupplierUpsertInput(
          name: 'Mercado do Bairro',
          contact: null,
          notes: null,
          leadTimeDays: 0,
          isActive: true,
        ),
      );

      final ingredientId = await repository.saveIngredient(
        IngredientUpsertInput(
          name: 'Leite em pó',
          category: 'Secos',
          purchaseUnit: IngredientUnit.kilogram,
          stockUnit: IngredientUnit.gram,
          currentStockQuantity: 1200,
          minimumStockQuantity: 500,
          unitCost: Money.fromCents(3890),
          defaultSupplier: null,
          conversionFactor: 1000,
          notes: null,
          preferredSupplierId: preferredSupplierId,
          linkedSupplierIds: [preferredSupplierId, alternativeSupplierId],
        ),
      );

      final ingredient = await repository.getIngredient(ingredientId);

      expect(ingredient, isNotNull);
      expect(ingredient!.displaySupplier, 'Atacadista Central');
      expect(ingredient.preferredSupplier?.supplierId, preferredSupplierId);
      expect(ingredient.alternativeSuppliers, hasLength(1));
      expect(
        ingredient.alternativeSuppliers.single.supplierId,
        alternativeSupplierId,
      );
    },
  );
}
