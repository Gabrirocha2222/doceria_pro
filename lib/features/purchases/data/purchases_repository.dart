import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../../core/database/app_database.dart';
import '../../../core/money/money.dart';
import '../../../core/sync/sync_definitions.dart';
import '../../ingredients/domain/ingredient_stock_movement_type.dart';
import '../../orders/domain/order.dart';
import '../../packaging/domain/packaging_stock_movement_type.dart';
import '../../sync/data/local_sync_support.dart';
import '../domain/purchase.dart';

class PurchasesRepository {
  PurchasesRepository(this._database);

  final AppDatabase _database;
  final Uuid _uuid = const Uuid();

  static const _activeOrderStatuses = <String>[
    'confirmed',
    'in_production',
    'ready',
  ];

  Stream<List<PurchaseProjectedNeedRecord>> watchProjectedNeeds() {
    final query =
        _database.select(_database.orderMaterialNeeds).join([
            innerJoin(
              _database.orders,
              _database.orders.id.equalsExp(
                _database.orderMaterialNeeds.orderId,
              ),
            ),
          ])
          ..where(
            _database.orderMaterialNeeds.consumedAt.isNull() &
                _database.orders.status.isIn(_activeOrderStatuses),
          )
          ..orderBy([
            OrderingTerm(
              expression: _database.orders.eventDate,
              mode: OrderingMode.asc,
              nulls: NullsOrder.last,
            ),
            OrderingTerm(expression: _database.orderMaterialNeeds.sortOrder),
          ]);

    return query.watch().map(
      (rows) => rows.map(_mapProjectedNeedRecord).toList(growable: false),
    );
  }

  Stream<List<PurchaseExpenseDraftRecord>> watchPreparedExpenseDrafts() {
    final query = _database.select(_database.purchaseExpenseEntries)
      ..where(
        (table) => table.status.equals(
          PurchaseExpenseDraftStatus.prepared.databaseValue,
        ),
      )
      ..orderBy([
        (table) =>
            OrderingTerm(expression: table.createdAt, mode: OrderingMode.desc),
      ]);

    return query.watch().map(
      (rows) => rows.map(_mapExpenseDraftRecord).toList(growable: false),
    );
  }

  Future<void> markItemPurchased(PurchaseMarkInput input) async {
    if (input.linkedEntityId.trim().isEmpty) {
      throw ArgumentError('A linked entity is required to update stock.');
    }
    if (input.purchaseQuantity <= 0 || input.stockQuantityAdded <= 0) {
      throw ArgumentError('Purchase quantities must be greater than zero.');
    }
    if (input.totalPrice.cents < 0) {
      throw ArgumentError('Purchase total price must be positive.');
    }

    final purchaseEntryId = _uuid.v4();
    final now = DateTime.now();

    await _database.transaction(() async {
      await _database
          .into(_database.purchaseEntries)
          .insert(
            PurchaseEntriesCompanion.insert(
              id: purchaseEntryId,
              materialType: input.materialType.databaseValue,
              linkedEntityId: Value(input.linkedEntityId.trim()),
              nameSnapshot: input.nameSnapshot.trim(),
              purchaseUnitLabel: input.purchaseUnitLabel.trim(),
              stockUnitLabel: input.stockUnitLabel.trim(),
              purchaseQuantity: Value(input.purchaseQuantity),
              stockQuantityAdded: Value(input.stockQuantityAdded),
              supplierId: Value(_trimToNull(input.supplierId)),
              supplierNameSnapshot: Value(
                _trimToNull(input.supplierNameSnapshot),
              ),
              totalPriceCents: Value(input.totalPrice.cents),
              note: Value(_trimToNull(input.note)),
              createdAt: Value(now),
            ),
          );

      switch (input.materialType) {
        case OrderMaterialType.ingredient:
          await _registerIngredientPurchase(
            purchaseEntryId: purchaseEntryId,
            linkedEntityId: input.linkedEntityId,
            stockQuantityAdded: input.stockQuantityAdded,
            note: input.note,
            purchasedAt: now,
          );
          break;
        case OrderMaterialType.packaging:
          await _registerPackagingPurchase(
            purchaseEntryId: purchaseEntryId,
            linkedEntityId: input.linkedEntityId,
            stockQuantityAdded: input.stockQuantityAdded,
            note: input.note,
            purchasedAt: now,
          );
          break;
      }

      if (input.totalPrice.cents > 0) {
        await _database
            .into(_database.purchaseExpenseEntries)
            .insert(
              PurchaseExpenseEntriesCompanion.insert(
                id: _uuid.v4(),
                purchaseEntryId: purchaseEntryId,
                description: 'Compra de ${input.nameSnapshot.trim()}',
                supplierId: Value(_trimToNull(input.supplierId)),
                supplierNameSnapshot: Value(
                  _trimToNull(input.supplierNameSnapshot),
                ),
                amountCents: Value(input.totalPrice.cents),
                status: PurchaseExpenseDraftStatus.prepared.databaseValue,
                createdAt: Value(now),
              ),
            );
      }
    });
  }

  PurchaseProjectedNeedRecord _mapProjectedNeedRecord(TypedResult row) {
    final materialNeed = row.readTable(_database.orderMaterialNeeds);
    final order = row.readTable(_database.orders);

    return PurchaseProjectedNeedRecord(
      orderId: order.id,
      clientNameSnapshot: order.clientNameSnapshot,
      orderDate: order.eventDate,
      materialType: OrderMaterialType.fromDatabase(materialNeed.materialType),
      linkedEntityId: materialNeed.linkedEntityId,
      recipeNameSnapshot: materialNeed.recipeNameSnapshot,
      itemNameSnapshot: materialNeed.itemNameSnapshot,
      nameSnapshot: materialNeed.nameSnapshot,
      unitLabel: materialNeed.unitLabel,
      requiredQuantity: materialNeed.requiredQuantity,
      shortageQuantity: materialNeed.shortageQuantity,
      note: materialNeed.note,
    );
  }

  PurchaseExpenseDraftRecord _mapExpenseDraftRecord(PurchaseExpenseEntry row) {
    return PurchaseExpenseDraftRecord(
      id: row.id,
      purchaseEntryId: row.purchaseEntryId,
      description: row.description,
      supplierId: row.supplierId,
      supplierNameSnapshot: row.supplierNameSnapshot,
      amount: Money.fromCents(row.amountCents),
      status: PurchaseExpenseDraftStatus.fromDatabase(row.status),
      createdAt: row.createdAt,
    );
  }

  Future<void> _registerIngredientPurchase({
    required String purchaseEntryId,
    required String linkedEntityId,
    required int stockQuantityAdded,
    required String? note,
    required DateTime purchasedAt,
  }) async {
    final ingredient = await (_database.select(
      _database.ingredients,
    )..where((table) => table.id.equals(linkedEntityId))).getSingleOrNull();
    if (ingredient == null) {
      throw StateError('Ingredient not found for this purchase.');
    }

    final resultingStock = ingredient.currentStockQuantity + stockQuantityAdded;

    await (_database.update(
      _database.ingredients,
    )..where((table) => table.id.equals(ingredient.id))).write(
      IngredientsCompanion(
        currentStockQuantity: Value(resultingStock),
        updatedAt: Value(purchasedAt),
      ),
    );

    await _database
        .into(_database.ingredientStockMovements)
        .insert(
          IngredientStockMovementsCompanion.insert(
            id: _uuid.v4(),
            ingredientId: ingredient.id,
            movementType:
                IngredientStockMovementType.purchaseEntry.databaseValue,
            quantityDelta: stockQuantityAdded,
            previousStockQuantity: ingredient.currentStockQuantity,
            resultingStockQuantity: resultingStock,
            reason: 'Compra registrada',
            notes: Value(_trimToNull(note)),
            referenceType: const Value('purchase_entry'),
            referenceId: Value(purchaseEntryId),
            createdAt: Value(purchasedAt),
          ),
        );

    await LocalSyncSupport.markEntityChanged(
      database: _database,
      entityType: RootSyncEntityType.ingredient,
      entityId: ingredient.id,
      updatedAt: purchasedAt,
    );
  }

  Future<void> _registerPackagingPurchase({
    required String purchaseEntryId,
    required String linkedEntityId,
    required int stockQuantityAdded,
    required String? note,
    required DateTime purchasedAt,
  }) async {
    final packaging = await (_database.select(
      _database.packaging,
    )..where((table) => table.id.equals(linkedEntityId))).getSingleOrNull();
    if (packaging == null) {
      throw StateError('Packaging not found for this purchase.');
    }

    final resultingStock = packaging.currentStockQuantity + stockQuantityAdded;

    await (_database.update(
      _database.packaging,
    )..where((table) => table.id.equals(packaging.id))).write(
      PackagingCompanion(
        currentStockQuantity: Value(resultingStock),
        updatedAt: Value(purchasedAt),
      ),
    );

    await _database
        .into(_database.packagingStockMovements)
        .insert(
          PackagingStockMovementsCompanion.insert(
            id: _uuid.v4(),
            packagingId: packaging.id,
            movementType:
                PackagingStockMovementType.purchaseEntry.databaseValue,
            quantityDelta: stockQuantityAdded,
            previousStockQuantity: packaging.currentStockQuantity,
            resultingStockQuantity: resultingStock,
            reason: 'Compra registrada',
            notes: Value(_trimToNull(note)),
            referenceType: const Value('purchase_entry'),
            referenceId: Value(purchaseEntryId),
            createdAt: Value(purchasedAt),
          ),
        );

    await LocalSyncSupport.markEntityChanged(
      database: _database,
      entityType: RootSyncEntityType.packaging,
      entityId: packaging.id,
      updatedAt: purchasedAt,
    );
  }

  String? _trimToNull(String? value) {
    final trimmedValue = value?.trim();
    if (trimmedValue == null || trimmedValue.isEmpty) {
      return null;
    }

    return trimmedValue;
  }
}
