import 'package:doceria_pro/core/database/app_database.dart';
import 'package:doceria_pro/core/money/money.dart';
import 'package:doceria_pro/features/orders/domain/order.dart';
import 'package:doceria_pro/features/packaging/domain/packaging_stock_movement_type.dart';
import 'package:doceria_pro/features/packaging/domain/packaging_type.dart';
import 'package:doceria_pro/features/purchases/data/purchases_repository.dart';
import 'package:doceria_pro/features/purchases/domain/purchase.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase database;
  late PurchasesRepository repository;

  setUp(() {
    database = AppDatabase(NativeDatabase.memory());
    repository = PurchasesRepository(database);
  });

  tearDown(() async {
    await database.close();
  });

  test(
    'watchProjectedNeeds ignores delivered orders and consumed needs',
    () async {
      await database
          .into(database.orders)
          .insert(
            OrdersCompanion.insert(
              id: 'order-confirmed',
              status: 'confirmed',
              createdAt: Value(DateTime(2026, 4, 2)),
              updatedAt: Value(DateTime(2026, 4, 2)),
            ),
          );
      await database
          .into(database.orders)
          .insert(
            OrdersCompanion.insert(
              id: 'order-delivered',
              status: 'delivered',
              createdAt: Value(DateTime(2026, 4, 2)),
              updatedAt: Value(DateTime(2026, 4, 2)),
            ),
          );

      await database
          .into(database.orderMaterialNeeds)
          .insert(
            OrderMaterialNeedsCompanion.insert(
              id: 'need-active',
              orderId: 'order-confirmed',
              materialType: OrderMaterialType.ingredient.databaseValue,
              nameSnapshot: 'Chocolate',
              unitLabel: 'g',
              requiredQuantity: 500,
            ),
          );
      await database
          .into(database.orderMaterialNeeds)
          .insert(
            OrderMaterialNeedsCompanion.insert(
              id: 'need-consumed',
              orderId: 'order-confirmed',
              materialType: OrderMaterialType.ingredient.databaseValue,
              nameSnapshot: 'Leite',
              unitLabel: 'ml',
              requiredQuantity: 400,
              consumedAt: Value(DateTime(2026, 4, 2)),
            ),
          );
      await database
          .into(database.orderMaterialNeeds)
          .insert(
            OrderMaterialNeedsCompanion.insert(
              id: 'need-delivered',
              orderId: 'order-delivered',
              materialType: OrderMaterialType.ingredient.databaseValue,
              nameSnapshot: 'Açúcar',
              unitLabel: 'g',
              requiredQuantity: 300,
            ),
          );

      final needs = await repository.watchProjectedNeeds().first;

      expect(needs, hasLength(1));
      expect(needs.single.nameSnapshot, 'Chocolate');
    },
  );

  test(
    'markItemPurchased updates ingredient stock and prepares expense entry',
    () async {
      await database
          .into(database.ingredients)
          .insert(
            IngredientsCompanion.insert(
              id: 'ingredient-1',
              name: 'Chocolate em pó',
              purchaseUnit: 'kilogram',
              stockUnit: 'gram',
              currentStockQuantity: const Value(1200),
              minimumStockQuantity: const Value(500),
              unitCostCents: const Value(4200),
              conversionFactor: const Value(1000),
            ),
          );

      await repository.markItemPurchased(
        PurchaseMarkInput(
          materialType: OrderMaterialType.ingredient,
          linkedEntityId: 'ingredient-1',
          nameSnapshot: 'Chocolate em pó',
          purchaseUnitLabel: 'kg',
          stockUnitLabel: 'g',
          purchaseQuantity: 1,
          stockQuantityAdded: 1000,
          supplierId: 'supplier-1',
          supplierNameSnapshot: 'Atacadista Central',
          totalPrice: Money.fromCents(4500),
          note: 'Reposição da semana',
        ),
      );

      final ingredient = await (database.select(
        database.ingredients,
      )..where((table) => table.id.equals('ingredient-1'))).getSingle();
      final movements = await database
          .select(database.ingredientStockMovements)
          .get();
      final expenseDrafts = await database
          .select(database.purchaseExpenseEntries)
          .get();
      final syncQueue = await database.select(database.syncQueue).get();

      expect(ingredient.currentStockQuantity, 2200);
      expect(movements, hasLength(1));
      expect(movements.single.quantityDelta, 1000);
      expect(movements.single.movementType, 'purchase_entry');
      expect(expenseDrafts, hasLength(1));
      expect(expenseDrafts.single.amountCents, 4500);
      expect(
        syncQueue.any(
          (item) =>
              item.entityType == 'ingredient' &&
              item.entityId == 'ingredient-1',
        ),
        isTrue,
      );
    },
  );

  test(
    'markItemPurchased updates packaging stock with traceable movement',
    () async {
      await database
          .into(database.packaging)
          .insert(
            PackagingCompanion.insert(
              id: 'packaging-1',
              name: 'Caixa premium',
              type: PackagingType.box.databaseValue,
              costCents: const Value(320),
              currentStockQuantity: const Value(2),
              minimumStockQuantity: const Value(3),
            ),
          );

      await repository.markItemPurchased(
        const PurchaseMarkInput(
          materialType: OrderMaterialType.packaging,
          linkedEntityId: 'packaging-1',
          nameSnapshot: 'Caixa premium',
          purchaseUnitLabel: 'un',
          stockUnitLabel: 'un',
          purchaseQuantity: 10,
          stockQuantityAdded: 10,
          supplierId: null,
          supplierNameSnapshot: null,
          totalPrice: Money.zero,
          note: 'Compra de reposição',
        ),
      );

      final packaging = await (database.select(
        database.packaging,
      )..where((table) => table.id.equals('packaging-1'))).getSingle();
      final movements = await database
          .select(database.packagingStockMovements)
          .get();
      final syncQueue = await database.select(database.syncQueue).get();

      expect(packaging.currentStockQuantity, 12);
      expect(movements, hasLength(1));
      expect(
        movements.single.movementType,
        PackagingStockMovementType.purchaseEntry.databaseValue,
      );
      expect(movements.single.quantityDelta, 10);
      expect(
        syncQueue.any(
          (item) =>
              item.entityType == 'packaging' && item.entityId == 'packaging-1',
        ),
        isTrue,
      );
    },
  );
}
