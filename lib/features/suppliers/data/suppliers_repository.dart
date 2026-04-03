import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../../core/database/app_database.dart';
import '../../../core/money/money.dart';
import '../../../core/sync/sync_definitions.dart';
import '../../sync/data/local_sync_support.dart';
import '../domain/supplier.dart';
import '../domain/supplier_item_type.dart';

class SuppliersRepository {
  SuppliersRepository(this._database);

  final AppDatabase _database;
  final Uuid _uuid = const Uuid();

  Stream<List<SupplierRecord>> watchSuppliers() {
    final query = _database.select(_database.suppliers)
      ..orderBy([
        (table) =>
            OrderingTerm(expression: table.isActive, mode: OrderingMode.desc),
        (table) => OrderingTerm(
          expression: table.name.lower(),
          mode: OrderingMode.asc,
        ),
      ]);

    return query.watch().asyncMap(_mapSupplierList);
  }

  Stream<SupplierRecord?> watchSupplier(String supplierId) {
    final query = _database.select(_database.suppliers)
      ..where((table) => table.id.equals(supplierId));

    return query.watchSingleOrNull().asyncMap((row) async {
      if (row == null) {
        return null;
      }

      final priceHistoryBySupplierId = await _loadPriceHistoryBySupplierIds([
        supplierId,
      ]);
      final linkedIngredientsBySupplierId =
          await _loadLinkedIngredientsBySupplierIds([
            supplierId,
          ], priceHistoryBySupplierId);

      return _mapSupplierRecord(
        row,
        linkedIngredientsBySupplierId[supplierId] ?? const [],
        priceHistoryBySupplierId[supplierId] ?? const [],
      );
    });
  }

  Future<SupplierRecord?> getSupplier(String supplierId) async {
    final row = await (_database.select(
      _database.suppliers,
    )..where((table) => table.id.equals(supplierId))).getSingleOrNull();

    if (row == null) {
      return null;
    }

    final priceHistoryBySupplierId = await _loadPriceHistoryBySupplierIds([
      supplierId,
    ]);
    final linkedIngredientsBySupplierId =
        await _loadLinkedIngredientsBySupplierIds([
          supplierId,
        ], priceHistoryBySupplierId);

    return _mapSupplierRecord(
      row,
      linkedIngredientsBySupplierId[supplierId] ?? const [],
      priceHistoryBySupplierId[supplierId] ?? const [],
    );
  }

  Future<String> saveSupplier(SupplierUpsertInput input) async {
    final trimmedName = input.name.trim();
    if (trimmedName.isEmpty) {
      throw ArgumentError('Supplier name is required.');
    }

    if (input.leadTimeDays != null && input.leadTimeDays! < 0) {
      throw ArgumentError('Lead time must be positive.');
    }

    final supplierId = input.id ?? _uuid.v4();
    final now = DateTime.now();

    if (input.id == null) {
      await _database
          .into(_database.suppliers)
          .insert(
            SuppliersCompanion.insert(
              id: supplierId,
              name: trimmedName,
              contact: Value(_trimToNull(input.contact)),
              notes: Value(_trimToNull(input.notes)),
              leadTimeDays: Value(input.leadTimeDays),
              isActive: Value(input.isActive),
              createdAt: Value(now),
              updatedAt: Value(now),
            ),
          );

      await LocalSyncSupport.markEntityChanged(
        database: _database,
        entityType: RootSyncEntityType.supplier,
        entityId: supplierId,
        updatedAt: now,
      );

      return supplierId;
    }

    await (_database.update(
      _database.suppliers,
    )..where((table) => table.id.equals(supplierId))).write(
      SuppliersCompanion(
        name: Value(trimmedName),
        contact: Value(_trimToNull(input.contact)),
        notes: Value(_trimToNull(input.notes)),
        leadTimeDays: Value(input.leadTimeDays),
        isActive: Value(input.isActive),
        updatedAt: Value(now),
      ),
    );

    await LocalSyncSupport.markEntityChanged(
      database: _database,
      entityType: RootSyncEntityType.supplier,
      entityId: supplierId,
      updatedAt: now,
    );

    return supplierId;
  }

  Future<void> saveSupplierPrice(SupplierPriceUpsertInput input) async {
    final trimmedItemName = input.itemNameSnapshot.trim();
    final trimmedItemId = input.linkedItemId.trim();
    if (trimmedItemName.isEmpty || trimmedItemId.isEmpty) {
      throw ArgumentError('Linked item information is required.');
    }

    if (input.price.cents <= 0) {
      throw ArgumentError('Supplier price must be greater than zero.');
    }

    final supplierExists = await (_database.select(
      _database.suppliers,
    )..where((table) => table.id.equals(input.supplierId))).getSingleOrNull();
    if (supplierExists == null) {
      throw StateError('Supplier not found.');
    }

    final now = DateTime.now();
    await _database.transaction(() async {
      await _database
          .into(_database.supplierItemPrices)
          .insert(
            SupplierItemPricesCompanion.insert(
              id: input.id ?? _uuid.v4(),
              supplierId: input.supplierId,
              itemType: input.itemType.databaseValue,
              linkedItemId: trimmedItemId,
              itemNameSnapshot: trimmedItemName,
              unitLabelSnapshot: Value(_trimToNull(input.unitLabelSnapshot)),
              priceCents: Value(input.price.cents),
              notes: Value(_trimToNull(input.notes)),
              createdAt: Value(now),
            ),
          );

      await (_database.update(_database.suppliers)
            ..where((table) => table.id.equals(input.supplierId)))
          .write(SuppliersCompanion(updatedAt: Value(now)));

      await LocalSyncSupport.markEntityChanged(
        database: _database,
        entityType: RootSyncEntityType.supplier,
        entityId: input.supplierId,
        updatedAt: now,
      );
    });
  }

  Future<List<SupplierRecord>> _mapSupplierList(List<Supplier> rows) async {
    if (rows.isEmpty) {
      return const [];
    }

    final supplierIds = rows.map((row) => row.id).toList(growable: false);
    final priceHistoryBySupplierId = await _loadPriceHistoryBySupplierIds(
      supplierIds,
    );
    final linkedIngredientsBySupplierId =
        await _loadLinkedIngredientsBySupplierIds(
          supplierIds,
          priceHistoryBySupplierId,
        );

    return rows
        .map(
          (row) => _mapSupplierRecord(
            row,
            linkedIngredientsBySupplierId[row.id] ?? const [],
            priceHistoryBySupplierId[row.id] ?? const [],
          ),
        )
        .toList(growable: false);
  }

  Future<Map<String, List<SupplierLinkedIngredientRecord>>>
  _loadLinkedIngredientsBySupplierIds(
    List<String> supplierIds,
    Map<String, List<SupplierPriceRecord>> priceHistoryBySupplierId,
  ) async {
    if (supplierIds.isEmpty) {
      return const {};
    }

    final rows =
        await (_database.select(_database.ingredientSupplierLinks).join([
                innerJoin(
                  _database.ingredients,
                  _database.ingredients.id.equalsExp(
                    _database.ingredientSupplierLinks.ingredientId,
                  ),
                ),
              ])
              ..where(
                _database.ingredientSupplierLinks.supplierId.isIn(supplierIds),
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
                OrderingTerm(expression: _database.ingredients.name.lower()),
              ]))
            .get();

    final result = <String, List<SupplierLinkedIngredientRecord>>{};
    for (final supplierId in supplierIds) {
      final latestPrices = <String, SupplierPriceRecord>{};
      for (final price in priceHistoryBySupplierId[supplierId] ?? const []) {
        if (price.itemType != SupplierItemType.ingredient) {
          continue;
        }

        latestPrices.putIfAbsent(price.linkedItemId, () => price);
      }

      result[supplierId] = [];
      for (final row in rows) {
        final link = row.readTable(_database.ingredientSupplierLinks);
        if (link.supplierId != supplierId) {
          continue;
        }

        final ingredient = row.readTable(_database.ingredients);
        final latestPrice = latestPrices[ingredient.id];

        result[supplierId]!.add(
          SupplierLinkedIngredientRecord(
            ingredientId: ingredient.id,
            ingredientName: ingredient.name,
            ingredientCategory: ingredient.category,
            isDefaultPreferred: link.isDefaultPreferred,
            lastKnownPrice: latestPrice?.price,
            lastKnownPriceUnitLabel: latestPrice?.unitLabelSnapshot,
          ),
        );
      }
    }

    return result;
  }

  Future<Map<String, List<SupplierPriceRecord>>> _loadPriceHistoryBySupplierIds(
    List<String> supplierIds,
  ) async {
    if (supplierIds.isEmpty) {
      return const {};
    }

    final rows =
        await (_database.select(_database.supplierItemPrices)
              ..where((table) => table.supplierId.isIn(supplierIds))
              ..orderBy([
                (table) => OrderingTerm(
                  expression: table.createdAt,
                  mode: OrderingMode.desc,
                ),
              ]))
            .get();

    final result = <String, List<SupplierPriceRecord>>{};
    for (final row in rows) {
      result.putIfAbsent(row.supplierId, () => []).add(_mapPriceRecord(row));
    }

    return result;
  }

  SupplierRecord _mapSupplierRecord(
    Supplier row,
    List<SupplierLinkedIngredientRecord> linkedIngredients,
    List<SupplierPriceRecord> priceHistory,
  ) {
    return SupplierRecord(
      id: row.id,
      name: row.name,
      contact: row.contact,
      notes: row.notes,
      leadTimeDays: row.leadTimeDays,
      isActive: row.isActive,
      createdAt: row.createdAt,
      updatedAt: row.updatedAt,
      linkedIngredients: linkedIngredients,
      priceHistory: priceHistory,
    );
  }

  SupplierPriceRecord _mapPriceRecord(SupplierItemPrice row) {
    return SupplierPriceRecord(
      id: row.id,
      supplierId: row.supplierId,
      itemType: SupplierItemType.fromDatabase(row.itemType),
      linkedItemId: row.linkedItemId,
      itemNameSnapshot: row.itemNameSnapshot,
      unitLabelSnapshot: row.unitLabelSnapshot,
      price: Money.fromCents(row.priceCents),
      notes: row.notes,
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
}
