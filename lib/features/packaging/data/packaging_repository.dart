import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../../core/database/app_database.dart';
import '../../../core/money/money.dart';
import '../../../core/sync/sync_definitions.dart';
import '../../sync/data/local_sync_support.dart';
import '../domain/packaging.dart';
import '../domain/packaging_type.dart';

class PackagingRepository {
  PackagingRepository(this._database);

  final AppDatabase _database;
  final Uuid _uuid = const Uuid();

  Stream<List<PackagingRecord>> watchPackaging() {
    final query = _database.select(_database.packaging)
      ..orderBy([
        (table) =>
            OrderingTerm(expression: table.isActive, mode: OrderingMode.desc),
        (table) => OrderingTerm(
          expression: table.name.lower(),
          mode: OrderingMode.asc,
        ),
      ]);

    return query.watch().asyncMap(_mapPackagingList);
  }

  Stream<PackagingRecord?> watchPackagingItem(String packagingId) {
    final query = _database.select(_database.packaging)
      ..where((table) => table.id.equals(packagingId));

    return query.watchSingleOrNull().asyncMap((row) async {
      if (row == null) {
        return null;
      }

      final linkedProducts = await _loadLinkedProducts(packagingId);
      return _mapPackagingRecord(row, linkedProducts);
    });
  }

  Future<PackagingRecord?> getPackagingItem(String packagingId) async {
    final row = await (_database.select(
      _database.packaging,
    )..where((table) => table.id.equals(packagingId))).getSingleOrNull();

    if (row == null) {
      return null;
    }

    final linkedProducts = await _loadLinkedProducts(packagingId);
    return _mapPackagingRecord(row, linkedProducts);
  }

  Future<String> savePackaging(PackagingUpsertInput input) async {
    final trimmedName = input.name.trim();
    if (trimmedName.isEmpty) {
      throw ArgumentError('Packaging name is required.');
    }

    if (input.cost.cents < 0 ||
        input.currentStockQuantity < 0 ||
        input.minimumStockQuantity < 0) {
      throw ArgumentError('Packaging cost and stock values must be positive.');
    }

    final packagingId = input.id ?? _uuid.v4();
    final now = DateTime.now();

    if (input.id == null) {
      await _database
          .into(_database.packaging)
          .insert(
            PackagingCompanion.insert(
              id: packagingId,
              name: trimmedName,
              type: input.type.databaseValue,
              costCents: Value(input.cost.cents),
              currentStockQuantity: Value(input.currentStockQuantity),
              minimumStockQuantity: Value(input.minimumStockQuantity),
              capacityDescription: Value(
                _trimToNull(input.capacityDescription),
              ),
              notes: Value(_trimToNull(input.notes)),
              isActive: Value(input.isActive),
              createdAt: Value(now),
              updatedAt: Value(now),
            ),
          );

      await LocalSyncSupport.markEntityChanged(
        database: _database,
        entityType: RootSyncEntityType.packaging,
        entityId: packagingId,
        updatedAt: now,
      );

      return packagingId;
    }

    await (_database.update(
      _database.packaging,
    )..where((table) => table.id.equals(packagingId))).write(
      PackagingCompanion(
        name: Value(trimmedName),
        type: Value(input.type.databaseValue),
        costCents: Value(input.cost.cents),
        currentStockQuantity: Value(input.currentStockQuantity),
        minimumStockQuantity: Value(input.minimumStockQuantity),
        capacityDescription: Value(_trimToNull(input.capacityDescription)),
        notes: Value(_trimToNull(input.notes)),
        isActive: Value(input.isActive),
        updatedAt: Value(now),
      ),
    );

    await LocalSyncSupport.markEntityChanged(
      database: _database,
      entityType: RootSyncEntityType.packaging,
      entityId: packagingId,
      updatedAt: now,
    );

    return packagingId;
  }

  Future<List<PackagingRecord>> _mapPackagingList(
    List<PackagingData> rows,
  ) async {
    if (rows.isEmpty) {
      return const [];
    }

    final packagingIds = rows.map((row) => row.id).toList(growable: false);
    final linkedProductsByPackagingId = await _loadLinkedProductsByPackagingIds(
      packagingIds,
    );

    final items = rows
        .map(
          (row) => _mapPackagingRecord(
            row,
            linkedProductsByPackagingId[row.id] ?? const [],
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

  Future<List<PackagingLinkedProductRecord>> _loadLinkedProducts(
    String packagingId,
  ) async {
    final rows =
        await (_database.select(_database.productPackagingLinks).join([
                innerJoin(
                  _database.products,
                  _database.products.id.equalsExp(
                    _database.productPackagingLinks.productId,
                  ),
                ),
              ])
              ..where(
                _database.productPackagingLinks.packagingId.equals(packagingId),
              )
              ..orderBy([
                OrderingTerm(
                  expression:
                      _database.productPackagingLinks.isDefaultSuggested,
                  mode: OrderingMode.desc,
                ),
                OrderingTerm(expression: _database.products.name.lower()),
              ]))
            .get();

    return rows.map(_mapLinkedProductRecord).toList(growable: false);
  }

  Future<Map<String, List<PackagingLinkedProductRecord>>>
  _loadLinkedProductsByPackagingIds(List<String> packagingIds) async {
    final rows =
        await (_database.select(_database.productPackagingLinks).join([
                innerJoin(
                  _database.products,
                  _database.products.id.equalsExp(
                    _database.productPackagingLinks.productId,
                  ),
                ),
              ])
              ..where(
                _database.productPackagingLinks.packagingId.isIn(packagingIds),
              )
              ..orderBy([
                OrderingTerm(
                  expression:
                      _database.productPackagingLinks.isDefaultSuggested,
                  mode: OrderingMode.desc,
                ),
                OrderingTerm(expression: _database.products.name.lower()),
              ]))
            .get();

    final result = <String, List<PackagingLinkedProductRecord>>{};
    for (final row in rows) {
      final link = row.readTable(_database.productPackagingLinks);
      result
          .putIfAbsent(link.packagingId, () => [])
          .add(_mapLinkedProductRecord(row));
    }

    return result;
  }

  PackagingRecord _mapPackagingRecord(
    PackagingData row,
    List<PackagingLinkedProductRecord> linkedProducts,
  ) {
    return PackagingRecord(
      id: row.id,
      name: row.name,
      type: PackagingType.fromDatabase(row.type),
      cost: Money.fromCents(row.costCents),
      currentStockQuantity: row.currentStockQuantity,
      minimumStockQuantity: row.minimumStockQuantity,
      capacityDescription: row.capacityDescription,
      notes: row.notes,
      isActive: row.isActive,
      createdAt: row.createdAt,
      updatedAt: row.updatedAt,
      linkedProducts: linkedProducts,
    );
  }

  PackagingLinkedProductRecord _mapLinkedProductRecord(TypedResult row) {
    final link = row.readTable(_database.productPackagingLinks);
    final product = row.readTable(_database.products);

    return PackagingLinkedProductRecord(
      productId: product.id,
      productName: product.name,
      isDefaultSuggested: link.isDefaultSuggested,
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
