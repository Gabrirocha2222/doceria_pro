import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../../core/database/app_database.dart';
import '../../../core/money/money.dart';
import '../../../core/sync/sync_definitions.dart';
import '../../sync/data/local_sync_support.dart';
import '../domain/ingredient.dart';
import '../domain/ingredient_stock_movement.dart';
import '../domain/ingredient_stock_movement_type.dart';
import '../domain/ingredient_unit.dart';

class IngredientsRepository {
  IngredientsRepository(this._database);

  final AppDatabase _database;
  final Uuid _uuid = const Uuid();
  static const _supplierIngredientItemType = 'ingredient';

  Stream<List<IngredientRecord>> watchIngredients() {
    final query = _database.select(_database.ingredients)
      ..orderBy([
        (table) => OrderingTerm(
          expression: table.name.lower(),
          mode: OrderingMode.asc,
        ),
      ]);

    return query.watch().asyncMap(_mapIngredientList);
  }

  Stream<IngredientRecord?> watchIngredient(String ingredientId) {
    final query = _database.select(_database.ingredients)
      ..where((table) => table.id.equals(ingredientId));

    return query.watchSingleOrNull().asyncMap((row) async {
      if (row == null) {
        return null;
      }

      final linkedSuppliers = await _loadLinkedSuppliers(ingredientId);
      return _mapIngredientRecord(row, linkedSuppliers);
    });
  }

  Future<IngredientRecord?> getIngredient(String ingredientId) async {
    final row = await (_database.select(
      _database.ingredients,
    )..where((table) => table.id.equals(ingredientId))).getSingleOrNull();

    if (row == null) {
      return null;
    }

    final linkedSuppliers = await _loadLinkedSuppliers(ingredientId);
    return _mapIngredientRecord(row, linkedSuppliers);
  }

  Stream<List<IngredientStockMovementRecord>> watchStockMovements(
    String ingredientId,
  ) {
    final query = _database.select(_database.ingredientStockMovements)
      ..where((table) => table.ingredientId.equals(ingredientId))
      ..orderBy([
        (table) =>
            OrderingTerm(expression: table.createdAt, mode: OrderingMode.desc),
      ]);

    return query.watch().map(
      (rows) => rows.map(_mapStockMovementRecord).toList(growable: false),
    );
  }

  Future<String> saveIngredient(IngredientUpsertInput input) async {
    final trimmedName = input.name.trim();
    if (trimmedName.isEmpty) {
      throw ArgumentError('Ingredient name is required.');
    }

    if (!input.stockUnit.canBeStockUnit) {
      throw ArgumentError('Stock unit must be a supported stock unit.');
    }

    if (!availableStockUnitsForPurchase(
      input.purchaseUnit,
    ).contains(input.stockUnit)) {
      throw ArgumentError('Purchase unit and stock unit are not compatible.');
    }

    if (input.currentStockQuantity < 0 ||
        input.minimumStockQuantity < 0 ||
        input.unitCost.cents < 0) {
      throw ArgumentError('Ingredient quantities and costs must be positive.');
    }

    if (input.conversionFactor <= 0) {
      throw ArgumentError('Conversion factor must be greater than zero.');
    }

    final ingredientId = input.id ?? _uuid.v4();
    final now = DateTime.now();
    final linkedSupplierIds = _normalizeSupplierIds(
      input.linkedSupplierIds,
      input.preferredSupplierId,
    );

    await _database.transaction(() async {
      final suppliersById = await _loadSuppliersByIds(linkedSupplierIds);
      if (suppliersById.length != linkedSupplierIds.length) {
        throw StateError('One or more linked suppliers were not found.');
      }

      final firstLinkedSupplierId = linkedSupplierIds.isEmpty
          ? null
          : linkedSupplierIds.first;
      final defaultSupplierSnapshot =
          suppliersById[input.preferredSupplierId ?? firstLinkedSupplierId]
              ?.name ??
          _trimToNull(input.defaultSupplier);

      if (input.id == null) {
        await _database
            .into(_database.ingredients)
            .insert(
              IngredientsCompanion.insert(
                id: ingredientId,
                name: trimmedName,
                category: Value(_trimToNull(input.category)),
                purchaseUnit: input.purchaseUnit.databaseValue,
                stockUnit: input.stockUnit.databaseValue,
                currentStockQuantity: Value(input.currentStockQuantity),
                minimumStockQuantity: Value(input.minimumStockQuantity),
                unitCostCents: Value(input.unitCost.cents),
                defaultSupplier: Value(defaultSupplierSnapshot),
                conversionFactor: Value(input.conversionFactor),
                notes: Value(_trimToNull(input.notes)),
                createdAt: Value(now),
                updatedAt: Value(now),
              ),
            );
      } else {
        await (_database.update(
          _database.ingredients,
        )..where((table) => table.id.equals(ingredientId))).write(
          IngredientsCompanion(
            name: Value(trimmedName),
            category: Value(_trimToNull(input.category)),
            purchaseUnit: Value(input.purchaseUnit.databaseValue),
            stockUnit: Value(input.stockUnit.databaseValue),
            currentStockQuantity: Value(input.currentStockQuantity),
            minimumStockQuantity: Value(input.minimumStockQuantity),
            unitCostCents: Value(input.unitCost.cents),
            defaultSupplier: Value(defaultSupplierSnapshot),
            conversionFactor: Value(input.conversionFactor),
            notes: Value(_trimToNull(input.notes)),
            updatedAt: Value(now),
          ),
        );
      }

      await (_database.delete(
        _database.ingredientSupplierLinks,
      )..where((table) => table.ingredientId.equals(ingredientId))).go();

      for (var index = 0; index < linkedSupplierIds.length; index++) {
        final supplierId = linkedSupplierIds[index];
        await _database
            .into(_database.ingredientSupplierLinks)
            .insert(
              IngredientSupplierLinksCompanion.insert(
                id: _uuid.v4(),
                ingredientId: ingredientId,
                supplierId: supplierId,
                isDefaultPreferred: Value(
                  supplierId == input.preferredSupplierId,
                ),
                sortOrder: Value(index),
              ),
            );
      }

      await LocalSyncSupport.markEntityChanged(
        database: _database,
        entityType: RootSyncEntityType.ingredient,
        entityId: ingredientId,
        updatedAt: now,
      );
    });

    return ingredientId;
  }

  Future<void> adjustStock(IngredientStockAdjustmentInput input) async {
    if (input.quantityDelta == 0) {
      throw ArgumentError('Stock movement needs a non-zero quantity delta.');
    }

    final trimmedReason = input.reason.trim();
    if (trimmedReason.isEmpty) {
      throw ArgumentError('Stock movement reason is required.');
    }

    await _database.transaction(() async {
      final now = DateTime.now();
      final ingredient =
          await (_database.select(_database.ingredients)
                ..where((table) => table.id.equals(input.ingredientId)))
              .getSingleOrNull();

      if (ingredient == null) {
        throw StateError('Ingredient not found.');
      }

      final newQuantity = ingredient.currentStockQuantity + input.quantityDelta;
      if (newQuantity < 0) {
        throw ArgumentError('Stock cannot become negative.');
      }

      await (_database.update(
        _database.ingredients,
      )..where((table) => table.id.equals(input.ingredientId))).write(
        IngredientsCompanion(
          currentStockQuantity: Value(newQuantity),
          updatedAt: Value(now),
        ),
      );

      await _database
          .into(_database.ingredientStockMovements)
          .insert(
            IngredientStockMovementsCompanion.insert(
              id: _uuid.v4(),
              ingredientId: input.ingredientId,
              movementType:
                  IngredientStockMovementType.manualAdjustment.databaseValue,
              quantityDelta: input.quantityDelta,
              previousStockQuantity: ingredient.currentStockQuantity,
              resultingStockQuantity: newQuantity,
              reason: trimmedReason,
              notes: Value(_trimToNull(input.notes)),
            ),
          );

      await LocalSyncSupport.markEntityChanged(
        database: _database,
        entityType: RootSyncEntityType.ingredient,
        entityId: input.ingredientId,
        updatedAt: now,
      );
    });
  }

  Future<List<IngredientRecord>> _mapIngredientList(
    List<Ingredient> rows,
  ) async {
    if (rows.isEmpty) {
      return const [];
    }

    final ingredientIds = rows.map((row) => row.id).toList(growable: false);
    final linkedSuppliersByIngredientId =
        await _loadLinkedSuppliersByIngredientIds(ingredientIds);

    final items = rows
        .map(
          (row) => _mapIngredientRecord(
            row,
            linkedSuppliersByIngredientId[row.id] ?? const [],
          ),
        )
        .toList(growable: false);

    items.sort((left, right) {
      if (left.isLowStock != right.isLowStock) {
        return left.isLowStock ? -1 : 1;
      }

      return left.name.toLowerCase().compareTo(right.name.toLowerCase());
    });

    return items;
  }

  Future<List<IngredientLinkedSupplierRecord>> _loadLinkedSuppliers(
    String ingredientId,
  ) async {
    final linkedSuppliersByIngredientId =
        await _loadLinkedSuppliersByIngredientIds([ingredientId]);

    return linkedSuppliersByIngredientId[ingredientId] ?? const [];
  }

  Future<Map<String, List<IngredientLinkedSupplierRecord>>>
  _loadLinkedSuppliersByIngredientIds(List<String> ingredientIds) async {
    if (ingredientIds.isEmpty) {
      return const {};
    }

    final rows =
        await (_database.select(_database.ingredientSupplierLinks).join([
                innerJoin(
                  _database.suppliers,
                  _database.suppliers.id.equalsExp(
                    _database.ingredientSupplierLinks.supplierId,
                  ),
                ),
              ])
              ..where(
                _database.ingredientSupplierLinks.ingredientId.isIn(
                  ingredientIds,
                ),
              )
              ..orderBy([
                OrderingTerm(
                  expression:
                      _database.ingredientSupplierLinks.isDefaultPreferred,
                  mode: OrderingMode.desc,
                ),
                OrderingTerm(
                  expression: _database.ingredientSupplierLinks.sortOrder,
                ),
                OrderingTerm(expression: _database.suppliers.name.lower()),
              ]))
            .get();

    if (rows.isEmpty) {
      return const {};
    }

    final supplierIds = rows
        .map((row) => row.readTable(_database.suppliers).id)
        .toSet()
        .toList(growable: false);
    final latestPricesByKey =
        await _loadLatestSupplierPricesByIngredientAndSupplier(
          ingredientIds: ingredientIds,
          supplierIds: supplierIds,
        );

    final result = <String, List<IngredientLinkedSupplierRecord>>{};
    for (final row in rows) {
      final link = row.readTable(_database.ingredientSupplierLinks);
      final supplier = row.readTable(_database.suppliers);
      final latestPrice =
          latestPricesByKey[_priceLookupKey(
            ingredientId: link.ingredientId,
            supplierId: supplier.id,
          )];

      result
          .putIfAbsent(link.ingredientId, () => [])
          .add(
            IngredientLinkedSupplierRecord(
              supplierId: supplier.id,
              supplierName: supplier.name,
              contact: supplier.contact,
              leadTimeDays: supplier.leadTimeDays,
              isDefaultPreferred: link.isDefaultPreferred,
              lastKnownPrice: latestPrice?.price,
              lastKnownPriceUnitLabel: latestPrice?.unitLabel,
              lastKnownPriceAt: latestPrice?.createdAt,
            ),
          );
    }

    return result;
  }

  Future<Map<String, _LatestSupplierPriceSnapshot>>
  _loadLatestSupplierPricesByIngredientAndSupplier({
    required List<String> ingredientIds,
    required List<String> supplierIds,
  }) async {
    if (ingredientIds.isEmpty || supplierIds.isEmpty) {
      return const {};
    }

    final rows =
        await (_database.select(_database.supplierItemPrices)
              ..where(
                (table) =>
                    table.itemType.equals(_supplierIngredientItemType) &
                    table.linkedItemId.isIn(ingredientIds) &
                    table.supplierId.isIn(supplierIds),
              )
              ..orderBy([
                (table) => OrderingTerm(
                  expression: table.createdAt,
                  mode: OrderingMode.desc,
                ),
              ]))
            .get();

    final result = <String, _LatestSupplierPriceSnapshot>{};
    for (final row in rows) {
      final key = _priceLookupKey(
        ingredientId: row.linkedItemId,
        supplierId: row.supplierId,
      );
      result.putIfAbsent(
        key,
        () => _LatestSupplierPriceSnapshot(
          price: Money.fromCents(row.priceCents),
          unitLabel: row.unitLabelSnapshot,
          createdAt: row.createdAt,
        ),
      );
    }

    return result;
  }

  Future<Map<String, Supplier>> _loadSuppliersByIds(
    List<String> supplierIds,
  ) async {
    if (supplierIds.isEmpty) {
      return const {};
    }

    final rows = await (_database.select(
      _database.suppliers,
    )..where((table) => table.id.isIn(supplierIds))).get();

    return {for (final row in rows) row.id: row};
  }

  IngredientRecord _mapIngredientRecord(
    Ingredient row,
    List<IngredientLinkedSupplierRecord> linkedSuppliers,
  ) {
    return IngredientRecord(
      id: row.id,
      name: row.name,
      category: row.category,
      purchaseUnit: IngredientUnit.fromDatabase(row.purchaseUnit),
      stockUnit: IngredientUnit.fromDatabase(row.stockUnit),
      currentStockQuantity: row.currentStockQuantity,
      minimumStockQuantity: row.minimumStockQuantity,
      unitCost: Money.fromCents(row.unitCostCents),
      defaultSupplier: row.defaultSupplier,
      conversionFactor: row.conversionFactor,
      notes: row.notes,
      createdAt: row.createdAt,
      updatedAt: row.updatedAt,
      linkedSuppliers: linkedSuppliers,
    );
  }

  IngredientStockMovementRecord _mapStockMovementRecord(
    IngredientStockMovement row,
  ) {
    return IngredientStockMovementRecord(
      id: row.id,
      ingredientId: row.ingredientId,
      movementType: IngredientStockMovementType.fromDatabase(row.movementType),
      quantityDelta: row.quantityDelta,
      previousStockQuantity: row.previousStockQuantity,
      resultingStockQuantity: row.resultingStockQuantity,
      reason: row.reason,
      notes: row.notes,
      referenceType: row.referenceType,
      referenceId: row.referenceId,
      createdAt: row.createdAt,
    );
  }

  String? _trimToNull(String? value) {
    final trimmed = value?.trim();
    if (trimmed == null || trimmed.isEmpty) {
      return null;
    }

    return trimmed;
  }

  List<String> _normalizeSupplierIds(
    List<String> linkedSupplierIds,
    String? preferredSupplierId,
  ) {
    final result = <String>[];

    void addValue(String? value) {
      final trimmed = value?.trim();
      if (trimmed == null || trimmed.isEmpty || result.contains(trimmed)) {
        return;
      }

      result.add(trimmed);
    }

    addValue(preferredSupplierId);
    for (final supplierId in linkedSupplierIds) {
      addValue(supplierId);
    }

    return result;
  }

  String _priceLookupKey({
    required String ingredientId,
    required String supplierId,
  }) {
    return '$ingredientId::$supplierId';
  }
}

class _LatestSupplierPriceSnapshot {
  const _LatestSupplierPriceSnapshot({
    required this.price,
    required this.unitLabel,
    required this.createdAt,
  });

  final Money price;
  final String? unitLabel;
  final DateTime createdAt;
}
