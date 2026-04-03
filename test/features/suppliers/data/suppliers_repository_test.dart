import 'package:doceria_pro/core/database/app_database.dart';
import 'package:doceria_pro/core/money/money.dart';
import 'package:doceria_pro/features/ingredients/data/ingredients_repository.dart';
import 'package:doceria_pro/features/ingredients/domain/ingredient.dart';
import 'package:doceria_pro/features/ingredients/domain/ingredient_unit.dart';
import 'package:doceria_pro/features/packaging/domain/packaging_type.dart';
import 'package:doceria_pro/features/suppliers/data/suppliers_repository.dart';
import 'package:doceria_pro/features/suppliers/domain/supplier.dart';
import 'package:doceria_pro/features/suppliers/domain/supplier_item_type.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase database;
  late SuppliersRepository suppliersRepository;
  late IngredientsRepository ingredientsRepository;

  setUp(() {
    database = AppDatabase(NativeDatabase.memory());
    suppliersRepository = SuppliersRepository(database);
    ingredientsRepository = IngredientsRepository(database);
  });

  tearDown(() async {
    await database.close();
  });

  test(
    'reads linked ingredients and latest known ingredient price for a supplier',
    () async {
      final supplierId = await suppliersRepository.saveSupplier(
        const SupplierUpsertInput(
          name: 'Casa dos Insumos',
          contact: 'WhatsApp',
          notes: 'Entrega rápida',
          leadTimeDays: 2,
          isActive: true,
        ),
      );
      final alternativeSupplierId = await suppliersRepository.saveSupplier(
        const SupplierUpsertInput(
          name: 'Plano B',
          contact: null,
          notes: null,
          leadTimeDays: 4,
          isActive: true,
        ),
      );

      final ingredientId = await ingredientsRepository.saveIngredient(
        IngredientUpsertInput(
          name: 'Chocolate nobre',
          category: 'Secos',
          purchaseUnit: IngredientUnit.kilogram,
          stockUnit: IngredientUnit.gram,
          currentStockQuantity: 3000,
          minimumStockQuantity: 1000,
          unitCost: Money.fromCents(5290),
          defaultSupplier: null,
          conversionFactor: 1000,
          notes: null,
          preferredSupplierId: supplierId,
          linkedSupplierIds: [supplierId, alternativeSupplierId],
        ),
      );

      await suppliersRepository.saveSupplierPrice(
        SupplierPriceUpsertInput(
          supplierId: supplierId,
          itemType: SupplierItemType.ingredient,
          linkedItemId: ingredientId,
          itemNameSnapshot: 'Chocolate nobre',
          unitLabelSnapshot: 'kg',
          price: Money.fromCents(5490),
          notes: 'Tabela de abril',
        ),
      );

      final supplier = await suppliersRepository.getSupplier(supplierId);

      expect(supplier, isNotNull);
      expect(supplier!.linkedIngredients, hasLength(1));
      expect(
        supplier.linkedIngredients.single.ingredientName,
        'Chocolate nobre',
      );
      expect(supplier.linkedIngredients.single.isDefaultPreferred, isTrue);
      expect(
        supplier.linkedIngredients.single.displayLastKnownPrice,
        'R\$ 54,90 / kg',
      );
      expect(supplier.latestPriceSummary, 'Chocolate nobre • R\$ 54,90 / kg');
    },
  );

  test('stores generic price history for packaging items too', () async {
    final supplierId = await suppliersRepository.saveSupplier(
      const SupplierUpsertInput(
        name: 'Embalagens Express',
        contact: null,
        notes: null,
        leadTimeDays: 1,
        isActive: true,
      ),
    );

    await database
        .into(database.packaging)
        .insert(
          PackagingCompanion.insert(
            id: 'packaging-1',
            name: 'Caixa premium',
            type: PackagingType.box.databaseValue,
            costCents: const Value(320),
          ),
        );

    await suppliersRepository.saveSupplierPrice(
      SupplierPriceUpsertInput(
        supplierId: supplierId,
        itemType: SupplierItemType.packaging,
        linkedItemId: 'packaging-1',
        itemNameSnapshot: 'Caixa premium',
        unitLabelSnapshot: 'un',
        price: Money.fromCents(350),
        notes: 'Pacote com melhor acabamento',
      ),
    );

    final supplier = await suppliersRepository.getSupplier(supplierId);

    expect(supplier, isNotNull);
    expect(supplier!.priceHistory, hasLength(1));
    expect(supplier.priceHistory.single.itemType, SupplierItemType.packaging);
    expect(supplier.priceHistory.single.displayPrice, 'R\$ 3,50 / un');
    expect(supplier.latestPrice?.itemNameSnapshot, 'Caixa premium');
  });
}
