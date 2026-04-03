import 'package:drift/drift.dart';

import '../../../core/database/app_database.dart';
import '../../../core/sync/sync_definitions.dart';
import '../domain/sync_state.dart';

class LocalEntitySyncInfo {
  const LocalEntitySyncInfo({
    required this.id,
    required this.updatedAt,
    required this.syncStatus,
  });

  final String id;
  final DateTime updatedAt;
  final LocalSyncStatus syncStatus;
}

class SyncLocalRepository {
  SyncLocalRepository(this._database);

  final AppDatabase _database;

  Stream<int> watchPendingQueueCount() {
    return _database
        .select(_database.syncQueue)
        .watch()
        .map((rows) => rows.length);
  }

  Stream<SyncStateRecord> watchSyncStateRecord() {
    final query = _database.select(_database.syncStateRecords)
      ..where((table) => table.id.equals('main'));

    return query.watchSingle();
  }

  Future<DateTime?> getLastSuccessfulPullAt() async {
    final row = await (_database.select(
      _database.syncStateRecords,
    )..where((table) => table.id.equals('main'))).getSingleOrNull();

    return row?.lastSuccessfulPullAt;
  }

  Future<List<SyncQueueData>> getPendingQueueItems() {
    final query = _database.select(_database.syncQueue)
      ..orderBy([(table) => OrderingTerm(expression: table.createdAt)]);

    return query.get();
  }

  Future<void> markQueueAttemptFailed({
    required String queueId,
    required String errorMessage,
  }) async {
    final row = await (_database.select(
      _database.syncQueue,
    )..where((table) => table.id.equals(queueId))).getSingleOrNull();
    if (row == null) {
      return;
    }

    await (_database.update(
      _database.syncQueue,
    )..where((table) => table.id.equals(queueId))).write(
      SyncQueueCompanion(
        retryCount: Value(row.retryCount + 1),
        lastAttemptAt: Value(DateTime.now()),
        lastError: Value(errorMessage),
      ),
    );
  }

  Future<void> removeQueueItem(String queueId) {
    return (_database.delete(
      _database.syncQueue,
    )..where((table) => table.id.equals(queueId))).go();
  }

  Future<void> clearQueuedEntity({
    required RootSyncEntityType entityType,
    required String entityId,
  }) {
    return (_database.delete(_database.syncQueue)..where(
          (table) =>
              table.entityType.equals(entityType.databaseValue) &
              table.entityId.equals(entityId),
        ))
        .go();
  }

  Future<LocalEntitySyncInfo?> getLocalEntitySyncInfo({
    required RootSyncEntityType entityType,
    required String entityId,
  }) async {
    switch (entityType) {
      case RootSyncEntityType.client:
        final row = await (_database.select(
          _database.clients,
        )..where((table) => table.id.equals(entityId))).getSingleOrNull();
        if (row == null) {
          return null;
        }
        return LocalEntitySyncInfo(
          id: row.id,
          updatedAt: row.updatedAt,
          syncStatus: LocalSyncStatus.fromDatabase(row.syncStatus),
        );
      case RootSyncEntityType.order:
        final row = await (_database.select(
          _database.orders,
        )..where((table) => table.id.equals(entityId))).getSingleOrNull();
        if (row == null) {
          return null;
        }
        return LocalEntitySyncInfo(
          id: row.id,
          updatedAt: row.updatedAt,
          syncStatus: LocalSyncStatus.fromDatabase(row.syncStatus),
        );
      case RootSyncEntityType.product:
        final row = await (_database.select(
          _database.products,
        )..where((table) => table.id.equals(entityId))).getSingleOrNull();
        if (row == null) {
          return null;
        }
        return LocalEntitySyncInfo(
          id: row.id,
          updatedAt: row.updatedAt,
          syncStatus: LocalSyncStatus.fromDatabase(row.syncStatus),
        );
      case RootSyncEntityType.ingredient:
        final row = await (_database.select(
          _database.ingredients,
        )..where((table) => table.id.equals(entityId))).getSingleOrNull();
        if (row == null) {
          return null;
        }
        return LocalEntitySyncInfo(
          id: row.id,
          updatedAt: row.updatedAt,
          syncStatus: LocalSyncStatus.fromDatabase(row.syncStatus),
        );
      case RootSyncEntityType.recipe:
        final row = await (_database.select(
          _database.recipes,
        )..where((table) => table.id.equals(entityId))).getSingleOrNull();
        if (row == null) {
          return null;
        }
        return LocalEntitySyncInfo(
          id: row.id,
          updatedAt: row.updatedAt,
          syncStatus: LocalSyncStatus.fromDatabase(row.syncStatus),
        );
      case RootSyncEntityType.packaging:
        final row = await (_database.select(
          _database.packaging,
        )..where((table) => table.id.equals(entityId))).getSingleOrNull();
        if (row == null) {
          return null;
        }
        return LocalEntitySyncInfo(
          id: row.id,
          updatedAt: row.updatedAt,
          syncStatus: LocalSyncStatus.fromDatabase(row.syncStatus),
        );
      case RootSyncEntityType.supplier:
        final row = await (_database.select(
          _database.suppliers,
        )..where((table) => table.id.equals(entityId))).getSingleOrNull();
        if (row == null) {
          return null;
        }
        return LocalEntitySyncInfo(
          id: row.id,
          updatedAt: row.updatedAt,
          syncStatus: LocalSyncStatus.fromDatabase(row.syncStatus),
        );
      case RootSyncEntityType.monthlyPlan:
        final row = await (_database.select(
          _database.monthlyPlans,
        )..where((table) => table.id.equals(entityId))).getSingleOrNull();
        if (row == null) {
          return null;
        }
        return LocalEntitySyncInfo(
          id: row.id,
          updatedAt: row.updatedAt,
          syncStatus: LocalSyncStatus.fromDatabase(row.syncStatus),
        );
      case RootSyncEntityType.financeManualEntry:
        final row = await (_database.select(
          _database.financeManualEntries,
        )..where((table) => table.id.equals(entityId))).getSingleOrNull();
        if (row == null) {
          return null;
        }
        return LocalEntitySyncInfo(
          id: row.id,
          updatedAt: row.updatedAt,
          syncStatus: LocalSyncStatus.fromDatabase(row.syncStatus),
        );
    }
  }

  Future<RemoteEntitySnapshot?> buildSnapshot({
    required RootSyncEntityType entityType,
    required String entityId,
  }) {
    switch (entityType) {
      case RootSyncEntityType.client:
        return _buildClientSnapshot(entityId);
      case RootSyncEntityType.order:
        return _buildOrderSnapshot(entityId);
      case RootSyncEntityType.product:
        return _buildProductSnapshot(entityId);
      case RootSyncEntityType.ingredient:
        return _buildIngredientSnapshot(entityId);
      case RootSyncEntityType.recipe:
        return _buildRecipeSnapshot(entityId);
      case RootSyncEntityType.packaging:
        return _buildPackagingSnapshot(entityId);
      case RootSyncEntityType.supplier:
        return _buildSupplierSnapshot(entityId);
      case RootSyncEntityType.monthlyPlan:
        return _buildMonthlyPlanSnapshot(entityId);
      case RootSyncEntityType.financeManualEntry:
        return _buildFinanceManualEntrySnapshot(entityId);
    }
  }

  Future<void> applyRemoteSnapshot(RemoteEntitySnapshot snapshot) async {
    switch (snapshot.entityType) {
      case RootSyncEntityType.client:
        await _applyClientSnapshot(snapshot);
      case RootSyncEntityType.order:
        await _applyOrderSnapshot(snapshot);
      case RootSyncEntityType.product:
        await _applyProductSnapshot(snapshot);
      case RootSyncEntityType.ingredient:
        await _applyIngredientSnapshot(snapshot);
      case RootSyncEntityType.recipe:
        await _applyRecipeSnapshot(snapshot);
      case RootSyncEntityType.packaging:
        await _applyPackagingSnapshot(snapshot);
      case RootSyncEntityType.supplier:
        await _applySupplierSnapshot(snapshot);
      case RootSyncEntityType.monthlyPlan:
        await _applyMonthlyPlanSnapshot(snapshot);
      case RootSyncEntityType.financeManualEntry:
        await _applyFinanceManualEntrySnapshot(snapshot);
    }
  }

  Future<RemoteEntitySnapshot?> _buildClientSnapshot(String entityId) async {
    final row = await (_database.select(
      _database.clients,
    )..where((table) => table.id.equals(entityId))).getSingleOrNull();
    if (row == null) {
      return null;
    }

    final importantDates =
        await (_database.select(_database.clientImportantDates)
              ..where((table) => table.clientId.equals(entityId))
              ..orderBy([(table) => OrderingTerm(expression: table.date)]))
            .get();

    return RemoteEntitySnapshot(
      teamId: row.teamId,
      entityType: RootSyncEntityType.client,
      entityId: row.id,
      updatedAt: row.updatedAt,
      updatedByMemberId: row.updatedByMemberId,
      deletedAt: row.deletedAt,
      payload: {
        'id': row.id,
        'name': row.name,
        'phone': row.phone,
        'address': row.address,
        'notes': row.notes,
        'rating': row.rating,
        'createdAt': _encodeDateTime(row.createdAt),
        'importantDates': [
          for (final item in importantDates)
            {
              'id': item.id,
              'label': item.label,
              'date': _encodeDateTime(item.date),
            },
        ],
      },
    );
  }

  Future<RemoteEntitySnapshot?> _buildOrderSnapshot(String entityId) async {
    final row = await (_database.select(
      _database.orders,
    )..where((table) => table.id.equals(entityId))).getSingleOrNull();
    if (row == null) {
      return null;
    }

    final items =
        await (_database.select(_database.orderItems)
              ..where((table) => table.orderId.equals(entityId))
              ..orderBy([(table) => OrderingTerm(expression: table.sortOrder)]))
            .get();
    final plans =
        await (_database.select(_database.orderProductionPlans)
              ..where((table) => table.orderId.equals(entityId))
              ..orderBy([(table) => OrderingTerm(expression: table.sortOrder)]))
            .get();
    final needs =
        await (_database.select(_database.orderMaterialNeeds)
              ..where((table) => table.orderId.equals(entityId))
              ..orderBy([(table) => OrderingTerm(expression: table.sortOrder)]))
            .get();
    final receivables =
        await (_database.select(_database.orderReceivableEntries)
              ..where((table) => table.orderId.equals(entityId))
              ..orderBy([(table) => OrderingTerm(expression: table.createdAt)]))
            .get();

    return RemoteEntitySnapshot(
      teamId: row.teamId,
      entityType: RootSyncEntityType.order,
      entityId: row.id,
      updatedAt: row.updatedAt,
      updatedByMemberId: row.updatedByMemberId,
      deletedAt: row.deletedAt,
      payload: {
        'id': row.id,
        'clientId': row.clientId,
        'clientNameSnapshot': row.clientNameSnapshot,
        'eventDate': _encodeDateTime(row.eventDate),
        'fulfillmentMethod': row.fulfillmentMethod,
        'deliveryFeeCents': row.deliveryFeeCents,
        'referencePhotoPath': row.referencePhotoPath,
        'notes': row.notes,
        'estimatedCostCents': row.estimatedCostCents,
        'suggestedSalePriceCents': row.suggestedSalePriceCents,
        'predictedProfitCents': row.predictedProfitCents,
        'suggestedPackagingId': row.suggestedPackagingId,
        'suggestedPackagingNameSnapshot': row.suggestedPackagingNameSnapshot,
        'smartReviewSummary': row.smartReviewSummary,
        'orderTotalCents': row.orderTotalCents,
        'depositAmountCents': row.depositAmountCents,
        'status': row.status,
        'createdAt': _encodeDateTime(row.createdAt),
        'items': [
          for (final item in items)
            {
              'id': item.id,
              'productId': item.productId,
              'itemNameSnapshot': item.itemNameSnapshot,
              'flavorSnapshot': item.flavorSnapshot,
              'variationSnapshot': item.variationSnapshot,
              'priceCents': item.priceCents,
              'quantity': item.quantity,
              'notes': item.notes,
              'sortOrder': item.sortOrder,
            },
        ],
        'productionPlans': [
          for (final item in plans)
            {
              'id': item.id,
              'title': item.title,
              'details': item.details,
              'planType': item.planType,
              'recipeNameSnapshot': item.recipeNameSnapshot,
              'itemNameSnapshot': item.itemNameSnapshot,
              'quantity': item.quantity,
              'notes': item.notes,
              'status': item.status,
              'dueDate': _encodeDateTime(item.dueDate),
              'completedAt': _encodeDateTime(item.completedAt),
              'sortOrder': item.sortOrder,
              'createdAt': _encodeDateTime(item.createdAt),
            },
        ],
        'materialNeeds': [
          for (final item in needs)
            {
              'id': item.id,
              'materialType': item.materialType,
              'linkedEntityId': item.linkedEntityId,
              'recipeNameSnapshot': item.recipeNameSnapshot,
              'itemNameSnapshot': item.itemNameSnapshot,
              'nameSnapshot': item.nameSnapshot,
              'unitLabel': item.unitLabel,
              'requiredQuantity': item.requiredQuantity,
              'availableQuantity': item.availableQuantity,
              'shortageQuantity': item.shortageQuantity,
              'note': item.note,
              'consumedAt': _encodeDateTime(item.consumedAt),
              'consumedByPlanId': item.consumedByPlanId,
              'sortOrder': item.sortOrder,
              'createdAt': _encodeDateTime(item.createdAt),
            },
        ],
        'receivableEntries': [
          for (final item in receivables)
            {
              'id': item.id,
              'description': item.description,
              'amountCents': item.amountCents,
              'dueDate': _encodeDateTime(item.dueDate),
              'status': item.status,
              'receivedAt': _encodeDateTime(item.receivedAt),
              'createdAt': _encodeDateTime(item.createdAt),
            },
        ],
      },
    );
  }

  Future<RemoteEntitySnapshot?> _buildProductSnapshot(String entityId) async {
    final row = await (_database.select(
      _database.products,
    )..where((table) => table.id.equals(entityId))).getSingleOrNull();
    if (row == null) {
      return null;
    }

    final options =
        await (_database.select(_database.productOptions)
              ..where((table) => table.productId.equals(entityId))
              ..orderBy([(table) => OrderingTerm(expression: table.sortOrder)]))
            .get();
    final recipeLinks =
        await (_database.select(_database.productRecipeLinks)
              ..where((table) => table.productId.equals(entityId))
              ..orderBy([(table) => OrderingTerm(expression: table.sortOrder)]))
            .get();
    final packagingLinks =
        await (_database.select(_database.productPackagingLinks)
              ..where((table) => table.productId.equals(entityId))
              ..orderBy([(table) => OrderingTerm(expression: table.sortOrder)]))
            .get();

    return RemoteEntitySnapshot(
      teamId: row.teamId,
      entityType: RootSyncEntityType.product,
      entityId: row.id,
      updatedAt: row.updatedAt,
      updatedByMemberId: row.updatedByMemberId,
      deletedAt: row.deletedAt,
      payload: {
        'id': row.id,
        'name': row.name,
        'category': row.category,
        'type': row.type,
        'saleMode': row.saleMode,
        'basePriceCents': row.basePriceCents,
        'notes': row.notes,
        'yieldHint': row.yieldHint,
        'isActive': row.isActive,
        'createdAt': _encodeDateTime(row.createdAt),
        'options': [
          for (final item in options)
            {
              'id': item.id,
              'type': item.type,
              'name': item.name,
              'isActive': item.isActive,
              'sortOrder': item.sortOrder,
            },
        ],
        'recipeLinks': [
          for (final item in recipeLinks)
            {
              'id': item.id,
              'recipeId': item.recipeId,
              'sortOrder': item.sortOrder,
            },
        ],
        'packagingLinks': [
          for (final item in packagingLinks)
            {
              'id': item.id,
              'packagingId': item.packagingId,
              'isDefaultSuggested': item.isDefaultSuggested,
              'sortOrder': item.sortOrder,
            },
        ],
      },
    );
  }

  Future<RemoteEntitySnapshot?> _buildIngredientSnapshot(
    String entityId,
  ) async {
    final row = await (_database.select(
      _database.ingredients,
    )..where((table) => table.id.equals(entityId))).getSingleOrNull();
    if (row == null) {
      return null;
    }

    final supplierLinks =
        await (_database.select(_database.ingredientSupplierLinks)
              ..where((table) => table.ingredientId.equals(entityId))
              ..orderBy([(table) => OrderingTerm(expression: table.sortOrder)]))
            .get();

    return RemoteEntitySnapshot(
      teamId: row.teamId,
      entityType: RootSyncEntityType.ingredient,
      entityId: row.id,
      updatedAt: row.updatedAt,
      updatedByMemberId: row.updatedByMemberId,
      deletedAt: row.deletedAt,
      payload: {
        'id': row.id,
        'name': row.name,
        'category': row.category,
        'purchaseUnit': row.purchaseUnit,
        'stockUnit': row.stockUnit,
        'currentStockQuantity': row.currentStockQuantity,
        'minimumStockQuantity': row.minimumStockQuantity,
        'unitCostCents': row.unitCostCents,
        'defaultSupplier': row.defaultSupplier,
        'conversionFactor': row.conversionFactor,
        'notes': row.notes,
        'createdAt': _encodeDateTime(row.createdAt),
        'supplierLinks': [
          for (final item in supplierLinks)
            {
              'id': item.id,
              'supplierId': item.supplierId,
              'isDefaultPreferred': item.isDefaultPreferred,
              'sortOrder': item.sortOrder,
            },
        ],
      },
    );
  }

  Future<RemoteEntitySnapshot?> _buildRecipeSnapshot(String entityId) async {
    final row = await (_database.select(
      _database.recipes,
    )..where((table) => table.id.equals(entityId))).getSingleOrNull();
    if (row == null) {
      return null;
    }

    final items =
        await (_database.select(_database.recipeItems)
              ..where((table) => table.recipeId.equals(entityId))
              ..orderBy([(table) => OrderingTerm(expression: table.sortOrder)]))
            .get();

    return RemoteEntitySnapshot(
      teamId: row.teamId,
      entityType: RootSyncEntityType.recipe,
      entityId: row.id,
      updatedAt: row.updatedAt,
      updatedByMemberId: row.updatedByMemberId,
      deletedAt: row.deletedAt,
      payload: {
        'id': row.id,
        'name': row.name,
        'type': row.type,
        'yieldAmount': row.yieldAmount,
        'yieldUnit': row.yieldUnit,
        'baseLabel': row.baseLabel,
        'flavorLabel': row.flavorLabel,
        'notes': row.notes,
        'createdAt': _encodeDateTime(row.createdAt),
        'items': [
          for (final item in items)
            {
              'id': item.id,
              'ingredientId': item.ingredientId,
              'ingredientNameSnapshot': item.ingredientNameSnapshot,
              'stockUnitSnapshot': item.stockUnitSnapshot,
              'quantity': item.quantity,
              'notes': item.notes,
              'sortOrder': item.sortOrder,
            },
        ],
      },
    );
  }

  Future<RemoteEntitySnapshot?> _buildPackagingSnapshot(String entityId) async {
    final row = await (_database.select(
      _database.packaging,
    )..where((table) => table.id.equals(entityId))).getSingleOrNull();
    if (row == null) {
      return null;
    }

    return RemoteEntitySnapshot(
      teamId: row.teamId,
      entityType: RootSyncEntityType.packaging,
      entityId: row.id,
      updatedAt: row.updatedAt,
      updatedByMemberId: row.updatedByMemberId,
      deletedAt: row.deletedAt,
      payload: {
        'id': row.id,
        'name': row.name,
        'type': row.type,
        'costCents': row.costCents,
        'currentStockQuantity': row.currentStockQuantity,
        'minimumStockQuantity': row.minimumStockQuantity,
        'capacityDescription': row.capacityDescription,
        'notes': row.notes,
        'isActive': row.isActive,
        'createdAt': _encodeDateTime(row.createdAt),
      },
    );
  }

  Future<RemoteEntitySnapshot?> _buildSupplierSnapshot(String entityId) async {
    final row = await (_database.select(
      _database.suppliers,
    )..where((table) => table.id.equals(entityId))).getSingleOrNull();
    if (row == null) {
      return null;
    }

    final prices =
        await (_database.select(_database.supplierItemPrices)
              ..where((table) => table.supplierId.equals(entityId))
              ..orderBy([
                (table) => OrderingTerm(
                  expression: table.createdAt,
                  mode: OrderingMode.desc,
                ),
              ]))
            .get();

    return RemoteEntitySnapshot(
      teamId: row.teamId,
      entityType: RootSyncEntityType.supplier,
      entityId: row.id,
      updatedAt: row.updatedAt,
      updatedByMemberId: row.updatedByMemberId,
      deletedAt: row.deletedAt,
      payload: {
        'id': row.id,
        'name': row.name,
        'contact': row.contact,
        'notes': row.notes,
        'leadTimeDays': row.leadTimeDays,
        'isActive': row.isActive,
        'createdAt': _encodeDateTime(row.createdAt),
        'prices': [
          for (final item in prices)
            {
              'id': item.id,
              'itemType': item.itemType,
              'linkedItemId': item.linkedItemId,
              'itemNameSnapshot': item.itemNameSnapshot,
              'unitLabelSnapshot': item.unitLabelSnapshot,
              'priceCents': item.priceCents,
              'notes': item.notes,
              'createdAt': _encodeDateTime(item.createdAt),
            },
        ],
      },
    );
  }

  Future<RemoteEntitySnapshot?> _buildMonthlyPlanSnapshot(
    String entityId,
  ) async {
    final row = await (_database.select(
      _database.monthlyPlans,
    )..where((table) => table.id.equals(entityId))).getSingleOrNull();
    if (row == null) {
      return null;
    }

    final items =
        await (_database.select(_database.monthlyPlanItems)
              ..where((table) => table.monthlyPlanId.equals(entityId))
              ..orderBy([(table) => OrderingTerm(expression: table.sortOrder)]))
            .get();
    final occurrences =
        await (_database.select(_database.monthlyPlanOccurrences)
              ..where((table) => table.monthlyPlanId.equals(entityId))
              ..orderBy([
                (table) => OrderingTerm(expression: table.occurrenceIndex),
              ]))
            .get();

    return RemoteEntitySnapshot(
      teamId: row.teamId,
      entityType: RootSyncEntityType.monthlyPlan,
      entityId: row.id,
      updatedAt: row.updatedAt,
      updatedByMemberId: row.updatedByMemberId,
      deletedAt: row.deletedAt,
      payload: {
        'id': row.id,
        'clientId': row.clientId,
        'clientNameSnapshot': row.clientNameSnapshot,
        'title': row.title,
        'templateProductId': row.templateProductId,
        'templateProductNameSnapshot': row.templateProductNameSnapshot,
        'startDate': _encodeDateTime(row.startDate),
        'recurrenceType': row.recurrenceType,
        'numberOfMonths': row.numberOfMonths,
        'contractedQuantity': row.contractedQuantity,
        'notes': row.notes,
        'createdAt': _encodeDateTime(row.createdAt),
        'items': [
          for (final item in items)
            {
              'id': item.id,
              'linkedProductId': item.linkedProductId,
              'itemNameSnapshot': item.itemNameSnapshot,
              'flavorSnapshot': item.flavorSnapshot,
              'variationSnapshot': item.variationSnapshot,
              'unitPriceCents': item.unitPriceCents,
              'quantity': item.quantity,
              'notes': item.notes,
              'sortOrder': item.sortOrder,
            },
        ],
        'occurrences': [
          for (final item in occurrences)
            {
              'id': item.id,
              'occurrenceIndex': item.occurrenceIndex,
              'scheduledDate': _encodeDateTime(item.scheduledDate),
              'status': item.status,
              'generatedOrderId': item.generatedOrderId,
              'createdAt': _encodeDateTime(item.createdAt),
            },
        ],
      },
    );
  }

  Future<RemoteEntitySnapshot?> _buildFinanceManualEntrySnapshot(
    String entityId,
  ) async {
    final row = await (_database.select(
      _database.financeManualEntries,
    )..where((table) => table.id.equals(entityId))).getSingleOrNull();
    if (row == null) {
      return null;
    }

    return RemoteEntitySnapshot(
      teamId: row.teamId,
      entityType: RootSyncEntityType.financeManualEntry,
      entityId: row.id,
      updatedAt: row.updatedAt,
      updatedByMemberId: row.updatedByMemberId,
      deletedAt: row.deletedAt,
      payload: {
        'id': row.id,
        'entryType': row.entryType,
        'description': row.description,
        'amountCents': row.amountCents,
        'entryDate': _encodeDateTime(row.entryDate),
        'category': row.category,
        'notes': row.notes,
        'createdAt': _encodeDateTime(row.createdAt),
      },
    );
  }

  Future<void> _applyClientSnapshot(RemoteEntitySnapshot snapshot) async {
    await _database.transaction(() async {
      await _upsertDeletedMarkerIfNeeded(snapshot);
      if (snapshot.deletedAt != null) {
        await (_database.delete(
          _database.clientImportantDates,
        )..where((table) => table.clientId.equals(snapshot.entityId))).go();
        await clearQueuedEntity(
          entityType: snapshot.entityType,
          entityId: snapshot.entityId,
        );
        return;
      }

      final payload = snapshot.payload;
      await _database
          .into(_database.clients)
          .insertOnConflictUpdate(
            ClientsCompanion.insert(
              id: snapshot.entityId,
              name: payload['name'] as String,
              phone: Value(payload['phone'] as String?),
              address: Value(payload['address'] as String?),
              notes: Value(payload['notes'] as String?),
              rating: payload['rating'] as String,
              createdAt: Value(
                _decodeDateTime(payload['createdAt'] as String)!,
              ),
              updatedAt: Value(snapshot.updatedAt),
              teamId: Value(snapshot.teamId),
              updatedByMemberId: Value(snapshot.updatedByMemberId),
              syncStatus: Value(LocalSyncStatus.synced.databaseValue),
              lastSyncedAt: Value(DateTime.now()),
              syncError: const Value(null),
              deletedAt: const Value(null),
            ),
          );

      await (_database.delete(
        _database.clientImportantDates,
      )..where((table) => table.clientId.equals(snapshot.entityId))).go();

      for (final rawItem
          in payload['importantDates'] as List<dynamic>? ?? const []) {
        final item = Map<String, dynamic>.from(rawItem as Map);
        await _database
            .into(_database.clientImportantDates)
            .insert(
              ClientImportantDatesCompanion.insert(
                id: item['id'] as String,
                clientId: snapshot.entityId,
                label: item['label'] as String,
                date: _decodeDateTime(item['date'] as String)!,
              ),
            );
      }

      await clearQueuedEntity(
        entityType: snapshot.entityType,
        entityId: snapshot.entityId,
      );
    });
  }

  Future<void> _applyOrderSnapshot(RemoteEntitySnapshot snapshot) async {
    await _database.transaction(() async {
      await _upsertDeletedMarkerIfNeeded(snapshot);
      if (snapshot.deletedAt != null) {
        await _deleteOrderChildren(snapshot.entityId);
        await clearQueuedEntity(
          entityType: snapshot.entityType,
          entityId: snapshot.entityId,
        );
        return;
      }

      final payload = snapshot.payload;
      await _database
          .into(_database.orders)
          .insertOnConflictUpdate(
            OrdersCompanion.insert(
              id: snapshot.entityId,
              clientId: Value(payload['clientId'] as String?),
              clientNameSnapshot: Value(
                payload['clientNameSnapshot'] as String?,
              ),
              eventDate: Value(
                _decodeDateTime(payload['eventDate'] as String?),
              ),
              fulfillmentMethod: Value(payload['fulfillmentMethod'] as String?),
              deliveryFeeCents: Value(payload['deliveryFeeCents'] as int? ?? 0),
              referencePhotoPath: Value(
                payload['referencePhotoPath'] as String?,
              ),
              notes: Value(payload['notes'] as String?),
              estimatedCostCents: Value(
                payload['estimatedCostCents'] as int? ?? 0,
              ),
              suggestedSalePriceCents: Value(
                payload['suggestedSalePriceCents'] as int? ?? 0,
              ),
              predictedProfitCents: Value(
                payload['predictedProfitCents'] as int? ?? 0,
              ),
              suggestedPackagingId: Value(
                payload['suggestedPackagingId'] as String?,
              ),
              suggestedPackagingNameSnapshot: Value(
                payload['suggestedPackagingNameSnapshot'] as String?,
              ),
              smartReviewSummary: Value(
                payload['smartReviewSummary'] as String?,
              ),
              orderTotalCents: Value(payload['orderTotalCents'] as int? ?? 0),
              depositAmountCents: Value(
                payload['depositAmountCents'] as int? ?? 0,
              ),
              status: payload['status'] as String,
              createdAt: Value(
                _decodeDateTime(payload['createdAt'] as String)!,
              ),
              updatedAt: Value(snapshot.updatedAt),
              teamId: Value(snapshot.teamId),
              updatedByMemberId: Value(snapshot.updatedByMemberId),
              syncStatus: Value(LocalSyncStatus.synced.databaseValue),
              lastSyncedAt: Value(DateTime.now()),
              syncError: const Value(null),
              deletedAt: const Value(null),
            ),
          );

      await _deleteOrderChildren(snapshot.entityId);

      for (final rawItem in payload['items'] as List<dynamic>? ?? const []) {
        final item = Map<String, dynamic>.from(rawItem as Map);
        await _database
            .into(_database.orderItems)
            .insert(
              OrderItemsCompanion.insert(
                id: item['id'] as String,
                orderId: snapshot.entityId,
                productId: Value(item['productId'] as String?),
                itemNameSnapshot: item['itemNameSnapshot'] as String,
                flavorSnapshot: Value(item['flavorSnapshot'] as String?),
                variationSnapshot: Value(item['variationSnapshot'] as String?),
                priceCents: Value(item['priceCents'] as int? ?? 0),
                quantity: Value(item['quantity'] as int? ?? 1),
                notes: Value(item['notes'] as String?),
                sortOrder: Value(item['sortOrder'] as int? ?? 0),
              ),
            );
      }

      for (final rawItem
          in payload['productionPlans'] as List<dynamic>? ?? const []) {
        final item = Map<String, dynamic>.from(rawItem as Map);
        await _database
            .into(_database.orderProductionPlans)
            .insert(
              OrderProductionPlansCompanion.insert(
                id: item['id'] as String,
                orderId: snapshot.entityId,
                title: item['title'] as String,
                details: Value(item['details'] as String?),
                planType: Value(item['planType'] as String? ?? 'order'),
                recipeNameSnapshot: Value(
                  item['recipeNameSnapshot'] as String?,
                ),
                itemNameSnapshot: Value(item['itemNameSnapshot'] as String?),
                quantity: Value(item['quantity'] as int? ?? 1),
                notes: Value(item['notes'] as String?),
                status: item['status'] as String,
                dueDate: Value(_decodeDateTime(item['dueDate'] as String?)),
                completedAt: Value(
                  _decodeDateTime(item['completedAt'] as String?),
                ),
                sortOrder: Value(item['sortOrder'] as int? ?? 0),
                createdAt: Value(_decodeDateTime(item['createdAt'] as String)!),
              ),
            );
      }

      for (final rawItem
          in payload['materialNeeds'] as List<dynamic>? ?? const []) {
        final item = Map<String, dynamic>.from(rawItem as Map);
        await _database
            .into(_database.orderMaterialNeeds)
            .insert(
              OrderMaterialNeedsCompanion.insert(
                id: item['id'] as String,
                orderId: snapshot.entityId,
                materialType: item['materialType'] as String,
                linkedEntityId: Value(item['linkedEntityId'] as String?),
                recipeNameSnapshot: Value(
                  item['recipeNameSnapshot'] as String?,
                ),
                itemNameSnapshot: Value(item['itemNameSnapshot'] as String?),
                nameSnapshot: item['nameSnapshot'] as String,
                unitLabel: item['unitLabel'] as String,
                requiredQuantity: item['requiredQuantity'] as int? ?? 0,
                availableQuantity: Value(
                  item['availableQuantity'] as int? ?? 0,
                ),
                shortageQuantity: Value(item['shortageQuantity'] as int? ?? 0),
                note: Value(item['note'] as String?),
                consumedAt: Value(
                  _decodeDateTime(item['consumedAt'] as String?),
                ),
                consumedByPlanId: Value(item['consumedByPlanId'] as String?),
                sortOrder: Value(item['sortOrder'] as int? ?? 0),
                createdAt: Value(_decodeDateTime(item['createdAt'] as String)!),
              ),
            );
      }

      for (final rawItem
          in payload['receivableEntries'] as List<dynamic>? ?? const []) {
        final item = Map<String, dynamic>.from(rawItem as Map);
        await _database
            .into(_database.orderReceivableEntries)
            .insert(
              OrderReceivableEntriesCompanion.insert(
                id: item['id'] as String,
                orderId: snapshot.entityId,
                description: item['description'] as String,
                amountCents: Value(item['amountCents'] as int? ?? 0),
                dueDate: Value(_decodeDateTime(item['dueDate'] as String?)),
                status: item['status'] as String,
                receivedAt: Value(
                  _decodeDateTime(item['receivedAt'] as String?),
                ),
                createdAt: Value(_decodeDateTime(item['createdAt'] as String)!),
              ),
            );
      }

      await clearQueuedEntity(
        entityType: snapshot.entityType,
        entityId: snapshot.entityId,
      );
    });
  }

  Future<void> _applyProductSnapshot(RemoteEntitySnapshot snapshot) async {
    await _database.transaction(() async {
      await _upsertDeletedMarkerIfNeeded(snapshot);
      if (snapshot.deletedAt != null) {
        await _deleteProductChildren(snapshot.entityId);
        await clearQueuedEntity(
          entityType: snapshot.entityType,
          entityId: snapshot.entityId,
        );
        return;
      }

      final payload = snapshot.payload;
      await _database
          .into(_database.products)
          .insertOnConflictUpdate(
            ProductsCompanion.insert(
              id: snapshot.entityId,
              name: payload['name'] as String,
              category: Value(payload['category'] as String?),
              type: payload['type'] as String,
              saleMode: payload['saleMode'] as String,
              basePriceCents: Value(payload['basePriceCents'] as int? ?? 0),
              notes: Value(payload['notes'] as String?),
              yieldHint: Value(payload['yieldHint'] as String?),
              isActive: Value(payload['isActive'] as bool? ?? true),
              createdAt: Value(
                _decodeDateTime(payload['createdAt'] as String)!,
              ),
              updatedAt: Value(snapshot.updatedAt),
              teamId: Value(snapshot.teamId),
              updatedByMemberId: Value(snapshot.updatedByMemberId),
              syncStatus: Value(LocalSyncStatus.synced.databaseValue),
              lastSyncedAt: Value(DateTime.now()),
              syncError: const Value(null),
              deletedAt: const Value(null),
            ),
          );

      await _deleteProductChildren(snapshot.entityId);

      for (final rawItem in payload['options'] as List<dynamic>? ?? const []) {
        final item = Map<String, dynamic>.from(rawItem as Map);
        await _database
            .into(_database.productOptions)
            .insert(
              ProductOptionsCompanion.insert(
                id: item['id'] as String,
                productId: snapshot.entityId,
                type: item['type'] as String,
                name: item['name'] as String,
                isActive: Value(item['isActive'] as bool? ?? true),
                sortOrder: Value(item['sortOrder'] as int? ?? 0),
              ),
            );
      }

      for (final rawItem
          in payload['recipeLinks'] as List<dynamic>? ?? const []) {
        final item = Map<String, dynamic>.from(rawItem as Map);
        await _database
            .into(_database.productRecipeLinks)
            .insert(
              ProductRecipeLinksCompanion.insert(
                id: item['id'] as String,
                productId: snapshot.entityId,
                recipeId: item['recipeId'] as String,
                sortOrder: Value(item['sortOrder'] as int? ?? 0),
              ),
            );
      }

      for (final rawItem
          in payload['packagingLinks'] as List<dynamic>? ?? const []) {
        final item = Map<String, dynamic>.from(rawItem as Map);
        await _database
            .into(_database.productPackagingLinks)
            .insert(
              ProductPackagingLinksCompanion.insert(
                id: item['id'] as String,
                productId: snapshot.entityId,
                packagingId: item['packagingId'] as String,
                isDefaultSuggested: Value(
                  item['isDefaultSuggested'] as bool? ?? false,
                ),
                sortOrder: Value(item['sortOrder'] as int? ?? 0),
              ),
            );
      }

      await clearQueuedEntity(
        entityType: snapshot.entityType,
        entityId: snapshot.entityId,
      );
    });
  }

  Future<void> _applyIngredientSnapshot(RemoteEntitySnapshot snapshot) async {
    await _database.transaction(() async {
      await _upsertDeletedMarkerIfNeeded(snapshot);
      if (snapshot.deletedAt != null) {
        await (_database.delete(
          _database.ingredientSupplierLinks,
        )..where((table) => table.ingredientId.equals(snapshot.entityId))).go();
        await clearQueuedEntity(
          entityType: snapshot.entityType,
          entityId: snapshot.entityId,
        );
        return;
      }

      final payload = snapshot.payload;
      await _database
          .into(_database.ingredients)
          .insertOnConflictUpdate(
            IngredientsCompanion.insert(
              id: snapshot.entityId,
              name: payload['name'] as String,
              category: Value(payload['category'] as String?),
              purchaseUnit: payload['purchaseUnit'] as String,
              stockUnit: payload['stockUnit'] as String,
              currentStockQuantity: Value(
                payload['currentStockQuantity'] as int? ?? 0,
              ),
              minimumStockQuantity: Value(
                payload['minimumStockQuantity'] as int? ?? 0,
              ),
              unitCostCents: Value(payload['unitCostCents'] as int? ?? 0),
              defaultSupplier: Value(payload['defaultSupplier'] as String?),
              conversionFactor: Value(payload['conversionFactor'] as int? ?? 1),
              notes: Value(payload['notes'] as String?),
              createdAt: Value(
                _decodeDateTime(payload['createdAt'] as String)!,
              ),
              updatedAt: Value(snapshot.updatedAt),
              teamId: Value(snapshot.teamId),
              updatedByMemberId: Value(snapshot.updatedByMemberId),
              syncStatus: Value(LocalSyncStatus.synced.databaseValue),
              lastSyncedAt: Value(DateTime.now()),
              syncError: const Value(null),
              deletedAt: const Value(null),
            ),
          );

      await (_database.delete(
        _database.ingredientSupplierLinks,
      )..where((table) => table.ingredientId.equals(snapshot.entityId))).go();

      for (final rawItem
          in payload['supplierLinks'] as List<dynamic>? ?? const []) {
        final item = Map<String, dynamic>.from(rawItem as Map);
        await _database
            .into(_database.ingredientSupplierLinks)
            .insert(
              IngredientSupplierLinksCompanion.insert(
                id: item['id'] as String,
                ingredientId: snapshot.entityId,
                supplierId: item['supplierId'] as String,
                isDefaultPreferred: Value(
                  item['isDefaultPreferred'] as bool? ?? false,
                ),
                sortOrder: Value(item['sortOrder'] as int? ?? 0),
              ),
            );
      }

      await clearQueuedEntity(
        entityType: snapshot.entityType,
        entityId: snapshot.entityId,
      );
    });
  }

  Future<void> _applyRecipeSnapshot(RemoteEntitySnapshot snapshot) async {
    await _database.transaction(() async {
      await _upsertDeletedMarkerIfNeeded(snapshot);
      if (snapshot.deletedAt != null) {
        await (_database.delete(
          _database.recipeItems,
        )..where((table) => table.recipeId.equals(snapshot.entityId))).go();
        await clearQueuedEntity(
          entityType: snapshot.entityType,
          entityId: snapshot.entityId,
        );
        return;
      }

      final payload = snapshot.payload;
      await _database
          .into(_database.recipes)
          .insertOnConflictUpdate(
            RecipesCompanion.insert(
              id: snapshot.entityId,
              name: payload['name'] as String,
              type: payload['type'] as String,
              yieldAmount: payload['yieldAmount'] as int,
              yieldUnit: payload['yieldUnit'] as String,
              baseLabel: Value(payload['baseLabel'] as String?),
              flavorLabel: Value(payload['flavorLabel'] as String?),
              notes: Value(payload['notes'] as String?),
              createdAt: Value(
                _decodeDateTime(payload['createdAt'] as String)!,
              ),
              updatedAt: Value(snapshot.updatedAt),
              teamId: Value(snapshot.teamId),
              updatedByMemberId: Value(snapshot.updatedByMemberId),
              syncStatus: Value(LocalSyncStatus.synced.databaseValue),
              lastSyncedAt: Value(DateTime.now()),
              syncError: const Value(null),
              deletedAt: const Value(null),
            ),
          );

      await (_database.delete(
        _database.recipeItems,
      )..where((table) => table.recipeId.equals(snapshot.entityId))).go();

      for (final rawItem in payload['items'] as List<dynamic>? ?? const []) {
        final item = Map<String, dynamic>.from(rawItem as Map);
        await _database
            .into(_database.recipeItems)
            .insert(
              RecipeItemsCompanion.insert(
                id: item['id'] as String,
                recipeId: snapshot.entityId,
                ingredientId: item['ingredientId'] as String,
                ingredientNameSnapshot:
                    item['ingredientNameSnapshot'] as String,
                stockUnitSnapshot: item['stockUnitSnapshot'] as String,
                quantity: item['quantity'] as int,
                notes: Value(item['notes'] as String?),
                sortOrder: Value(item['sortOrder'] as int? ?? 0),
              ),
            );
      }

      await clearQueuedEntity(
        entityType: snapshot.entityType,
        entityId: snapshot.entityId,
      );
    });
  }

  Future<void> _applyPackagingSnapshot(RemoteEntitySnapshot snapshot) async {
    await _database.transaction(() async {
      await _upsertDeletedMarkerIfNeeded(snapshot);
      if (snapshot.deletedAt != null) {
        await clearQueuedEntity(
          entityType: snapshot.entityType,
          entityId: snapshot.entityId,
        );
        return;
      }

      final payload = snapshot.payload;
      await _database
          .into(_database.packaging)
          .insertOnConflictUpdate(
            PackagingCompanion.insert(
              id: snapshot.entityId,
              name: payload['name'] as String,
              type: payload['type'] as String,
              costCents: Value(payload['costCents'] as int? ?? 0),
              currentStockQuantity: Value(
                payload['currentStockQuantity'] as int? ?? 0,
              ),
              minimumStockQuantity: Value(
                payload['minimumStockQuantity'] as int? ?? 0,
              ),
              capacityDescription: Value(
                payload['capacityDescription'] as String?,
              ),
              notes: Value(payload['notes'] as String?),
              isActive: Value(payload['isActive'] as bool? ?? true),
              createdAt: Value(
                _decodeDateTime(payload['createdAt'] as String)!,
              ),
              updatedAt: Value(snapshot.updatedAt),
              teamId: Value(snapshot.teamId),
              updatedByMemberId: Value(snapshot.updatedByMemberId),
              syncStatus: Value(LocalSyncStatus.synced.databaseValue),
              lastSyncedAt: Value(DateTime.now()),
              syncError: const Value(null),
              deletedAt: const Value(null),
            ),
          );

      await clearQueuedEntity(
        entityType: snapshot.entityType,
        entityId: snapshot.entityId,
      );
    });
  }

  Future<void> _applySupplierSnapshot(RemoteEntitySnapshot snapshot) async {
    await _database.transaction(() async {
      await _upsertDeletedMarkerIfNeeded(snapshot);
      if (snapshot.deletedAt != null) {
        await (_database.delete(
          _database.supplierItemPrices,
        )..where((table) => table.supplierId.equals(snapshot.entityId))).go();
        await clearQueuedEntity(
          entityType: snapshot.entityType,
          entityId: snapshot.entityId,
        );
        return;
      }

      final payload = snapshot.payload;
      await _database
          .into(_database.suppliers)
          .insertOnConflictUpdate(
            SuppliersCompanion.insert(
              id: snapshot.entityId,
              name: payload['name'] as String,
              contact: Value(payload['contact'] as String?),
              notes: Value(payload['notes'] as String?),
              leadTimeDays: Value(payload['leadTimeDays'] as int?),
              isActive: Value(payload['isActive'] as bool? ?? true),
              createdAt: Value(
                _decodeDateTime(payload['createdAt'] as String)!,
              ),
              updatedAt: Value(snapshot.updatedAt),
              teamId: Value(snapshot.teamId),
              updatedByMemberId: Value(snapshot.updatedByMemberId),
              syncStatus: Value(LocalSyncStatus.synced.databaseValue),
              lastSyncedAt: Value(DateTime.now()),
              syncError: const Value(null),
              deletedAt: const Value(null),
            ),
          );

      await (_database.delete(
        _database.supplierItemPrices,
      )..where((table) => table.supplierId.equals(snapshot.entityId))).go();

      for (final rawItem in payload['prices'] as List<dynamic>? ?? const []) {
        final item = Map<String, dynamic>.from(rawItem as Map);
        await _database
            .into(_database.supplierItemPrices)
            .insert(
              SupplierItemPricesCompanion.insert(
                id: item['id'] as String,
                supplierId: snapshot.entityId,
                itemType: item['itemType'] as String,
                linkedItemId: item['linkedItemId'] as String,
                itemNameSnapshot: item['itemNameSnapshot'] as String,
                unitLabelSnapshot: Value(item['unitLabelSnapshot'] as String?),
                priceCents: Value(item['priceCents'] as int? ?? 0),
                notes: Value(item['notes'] as String?),
                createdAt: Value(_decodeDateTime(item['createdAt'] as String)!),
              ),
            );
      }

      await clearQueuedEntity(
        entityType: snapshot.entityType,
        entityId: snapshot.entityId,
      );
    });
  }

  Future<void> _applyMonthlyPlanSnapshot(RemoteEntitySnapshot snapshot) async {
    await _database.transaction(() async {
      await _upsertDeletedMarkerIfNeeded(snapshot);
      if (snapshot.deletedAt != null) {
        await (_database.delete(_database.monthlyPlanItems)
              ..where((table) => table.monthlyPlanId.equals(snapshot.entityId)))
            .go();
        await (_database.delete(_database.monthlyPlanOccurrences)
              ..where((table) => table.monthlyPlanId.equals(snapshot.entityId)))
            .go();
        await clearQueuedEntity(
          entityType: snapshot.entityType,
          entityId: snapshot.entityId,
        );
        return;
      }

      final payload = snapshot.payload;
      await _database
          .into(_database.monthlyPlans)
          .insertOnConflictUpdate(
            MonthlyPlansCompanion.insert(
              id: snapshot.entityId,
              clientId: payload['clientId'] as String,
              clientNameSnapshot: payload['clientNameSnapshot'] as String,
              title: payload['title'] as String,
              templateProductId: Value(payload['templateProductId'] as String?),
              templateProductNameSnapshot: Value(
                payload['templateProductNameSnapshot'] as String?,
              ),
              startDate: _decodeDateTime(payload['startDate'] as String)!,
              recurrenceType: Value(
                payload['recurrenceType'] as String? ?? 'monthly',
              ),
              numberOfMonths: Value(payload['numberOfMonths'] as int? ?? 1),
              contractedQuantity: Value(
                payload['contractedQuantity'] as int? ?? 1,
              ),
              notes: Value(payload['notes'] as String?),
              createdAt: Value(
                _decodeDateTime(payload['createdAt'] as String)!,
              ),
              updatedAt: Value(snapshot.updatedAt),
              teamId: Value(snapshot.teamId),
              updatedByMemberId: Value(snapshot.updatedByMemberId),
              syncStatus: Value(LocalSyncStatus.synced.databaseValue),
              lastSyncedAt: Value(DateTime.now()),
              syncError: const Value(null),
              deletedAt: const Value(null),
            ),
          );

      await (_database.delete(
        _database.monthlyPlanItems,
      )..where((table) => table.monthlyPlanId.equals(snapshot.entityId))).go();
      await (_database.delete(
        _database.monthlyPlanOccurrences,
      )..where((table) => table.monthlyPlanId.equals(snapshot.entityId))).go();

      for (final rawItem in payload['items'] as List<dynamic>? ?? const []) {
        final item = Map<String, dynamic>.from(rawItem as Map);
        await _database
            .into(_database.monthlyPlanItems)
            .insert(
              MonthlyPlanItemsCompanion.insert(
                id: item['id'] as String,
                monthlyPlanId: snapshot.entityId,
                linkedProductId: Value(item['linkedProductId'] as String?),
                itemNameSnapshot: item['itemNameSnapshot'] as String,
                flavorSnapshot: Value(item['flavorSnapshot'] as String?),
                variationSnapshot: Value(item['variationSnapshot'] as String?),
                unitPriceCents: Value(item['unitPriceCents'] as int? ?? 0),
                quantity: Value(item['quantity'] as int? ?? 1),
                notes: Value(item['notes'] as String?),
                sortOrder: Value(item['sortOrder'] as int? ?? 0),
              ),
            );
      }

      for (final rawItem
          in payload['occurrences'] as List<dynamic>? ?? const []) {
        final item = Map<String, dynamic>.from(rawItem as Map);
        await _database
            .into(_database.monthlyPlanOccurrences)
            .insert(
              MonthlyPlanOccurrencesCompanion.insert(
                id: item['id'] as String,
                monthlyPlanId: snapshot.entityId,
                occurrenceIndex: item['occurrenceIndex'] as int,
                scheduledDate: _decodeDateTime(
                  item['scheduledDate'] as String,
                )!,
                status: Value(item['status'] as String? ?? 'planned'),
                generatedOrderId: Value(item['generatedOrderId'] as String?),
                createdAt: Value(_decodeDateTime(item['createdAt'] as String)!),
              ),
            );
      }

      await clearQueuedEntity(
        entityType: snapshot.entityType,
        entityId: snapshot.entityId,
      );
    });
  }

  Future<void> _applyFinanceManualEntrySnapshot(
    RemoteEntitySnapshot snapshot,
  ) async {
    await _database.transaction(() async {
      await _upsertDeletedMarkerIfNeeded(snapshot);
      if (snapshot.deletedAt != null) {
        await clearQueuedEntity(
          entityType: snapshot.entityType,
          entityId: snapshot.entityId,
        );
        return;
      }

      final payload = snapshot.payload;
      await _database
          .into(_database.financeManualEntries)
          .insertOnConflictUpdate(
            FinanceManualEntriesCompanion.insert(
              id: snapshot.entityId,
              entryType: payload['entryType'] as String,
              description: payload['description'] as String,
              amountCents: Value(payload['amountCents'] as int? ?? 0),
              entryDate: _decodeDateTime(payload['entryDate'] as String)!,
              category: Value(payload['category'] as String?),
              notes: Value(payload['notes'] as String?),
              createdAt: Value(
                _decodeDateTime(payload['createdAt'] as String)!,
              ),
              updatedAt: Value(snapshot.updatedAt),
              teamId: Value(snapshot.teamId),
              updatedByMemberId: Value(snapshot.updatedByMemberId),
              syncStatus: Value(LocalSyncStatus.synced.databaseValue),
              lastSyncedAt: Value(DateTime.now()),
              syncError: const Value(null),
              deletedAt: const Value(null),
            ),
          );

      await clearQueuedEntity(
        entityType: snapshot.entityType,
        entityId: snapshot.entityId,
      );
    });
  }

  Future<void> _upsertDeletedMarkerIfNeeded(
    RemoteEntitySnapshot snapshot,
  ) async {
    if (snapshot.deletedAt == null) {
      return;
    }

    await _database.customUpdate(
      'UPDATE ${snapshot.entityType.tableName} '
      'SET deleted_at = ?, updated_at = ?, team_id = ?, updated_by_member_id = ?, '
      'sync_status = ?, last_synced_at = ?, sync_error = NULL '
      'WHERE id = ?',
      variables: [
        Variable<DateTime>(snapshot.deletedAt!),
        Variable<DateTime>(snapshot.updatedAt),
        Variable<String>(snapshot.teamId),
        Variable<String>(snapshot.updatedByMemberId),
        Variable<String>(LocalSyncStatus.synced.databaseValue),
        Variable<DateTime>(DateTime.now()),
        Variable<String>(snapshot.entityId),
      ],
    );
  }

  Future<void> _deleteOrderChildren(String orderId) async {
    await (_database.delete(
      _database.orderItems,
    )..where((table) => table.orderId.equals(orderId))).go();
    await (_database.delete(
      _database.orderProductionPlans,
    )..where((table) => table.orderId.equals(orderId))).go();
    await (_database.delete(
      _database.orderMaterialNeeds,
    )..where((table) => table.orderId.equals(orderId))).go();
    await (_database.delete(
      _database.orderReceivableEntries,
    )..where((table) => table.orderId.equals(orderId))).go();
  }

  Future<void> _deleteProductChildren(String productId) async {
    await (_database.delete(
      _database.productOptions,
    )..where((table) => table.productId.equals(productId))).go();
    await (_database.delete(
      _database.productRecipeLinks,
    )..where((table) => table.productId.equals(productId))).go();
    await (_database.delete(
      _database.productPackagingLinks,
    )..where((table) => table.productId.equals(productId))).go();
  }

  String? _encodeDateTime(DateTime? value) {
    if (value == null) {
      return null;
    }

    return value.toUtc().toIso8601String();
  }

  DateTime? _decodeDateTime(String? value) {
    if (value == null || value.trim().isEmpty) {
      return null;
    }

    return DateTime.parse(value).toLocal();
  }
}
