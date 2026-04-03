import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../../core/database/app_database.dart';
import '../../../core/money/money.dart';
import '../../../core/sync/sync_definitions.dart';
import '../../sync/data/local_sync_support.dart';
import '../domain/order.dart';
import '../domain/order_fulfillment_method.dart';
import '../domain/order_status.dart';

class OrdersRepository {
  OrdersRepository(this._database);

  final AppDatabase _database;
  final Uuid _uuid = const Uuid();

  Stream<List<OrderRecord>> watchOrders() {
    final query = _database.select(_database.orders)
      ..orderBy([
        (table) => OrderingTerm(
          expression: table.eventDate,
          mode: OrderingMode.asc,
          nulls: NullsOrder.last,
        ),
        (table) =>
            OrderingTerm(expression: table.updatedAt, mode: OrderingMode.desc),
      ]);

    return query.watch().asyncMap(_mapOrderList);
  }

  Stream<List<OrderRecord>> watchOrdersForClient(String clientId) {
    final query = _database.select(_database.orders)
      ..where((table) => table.clientId.equals(clientId))
      ..orderBy([
        (table) => OrderingTerm(
          expression: table.eventDate,
          mode: OrderingMode.desc,
          nulls: NullsOrder.last,
        ),
        (table) =>
            OrderingTerm(expression: table.updatedAt, mode: OrderingMode.desc),
      ]);

    return query.watch().asyncMap(_mapOrderList);
  }

  Stream<OrderRecord?> watchOrder(String orderId) {
    final query = _database.select(_database.orders)
      ..where((table) => table.id.equals(orderId));

    return query.watchSingleOrNull().asyncMap((row) async {
      if (row == null) {
        return null;
      }

      return _mapCompleteOrder(row);
    });
  }

  Future<String> saveOrder(OrderUpsertInput input) async {
    if (input.orderTotal.cents < 0 ||
        input.depositAmount.cents < 0 ||
        input.deliveryFee.cents < 0 ||
        input.estimatedCost.cents < 0 ||
        input.suggestedSalePrice.cents < 0) {
      throw ArgumentError('Money values must be positive.');
    }

    if (input.orderTotal.cents > 0 &&
        input.depositAmount.cents > input.orderTotal.cents) {
      throw ArgumentError('Deposit cannot exceed total amount.');
    }

    for (final item in input.items) {
      if (item.itemNameSnapshot.trim().isEmpty) {
        throw ArgumentError('Order items need a name snapshot.');
      }
      if (item.price.cents < 0) {
        throw ArgumentError('Order item prices must be positive.');
      }
      if (item.quantity <= 0) {
        throw ArgumentError('Order item quantity must be at least one.');
      }
    }

    for (final need in input.materialNeeds) {
      if (need.nameSnapshot.trim().isEmpty || need.unitLabel.trim().isEmpty) {
        throw ArgumentError('Material needs require name and unit.');
      }
      if (need.requiredQuantity < 0 ||
          need.availableQuantity < 0 ||
          need.shortageQuantity < 0) {
        throw ArgumentError('Material quantities must be positive.');
      }
    }

    for (final receivable in input.receivableEntries) {
      if (receivable.description.trim().isEmpty) {
        throw ArgumentError('Receivable entries require a description.');
      }
      if (receivable.amount.cents < 0) {
        throw ArgumentError('Receivable amounts must be positive.');
      }
    }

    final orderId = input.id ?? _uuid.v4();
    final now = DateTime.now();
    final normalizedDate = input.eventDate == null
        ? null
        : DateTime(
            input.eventDate!.year,
            input.eventDate!.month,
            input.eventDate!.day,
          );
    final normalizedMethod = input.fulfillmentMethod?.databaseValue;
    final normalizedDeliveryFee =
        input.fulfillmentMethod == OrderFulfillmentMethod.delivery
        ? input.deliveryFee.cents
        : 0;

    await _database.transaction(() async {
      final orderCompanion = OrdersCompanion(
        clientId: Value(_trimToNull(input.clientId)),
        clientNameSnapshot: Value(_trimToNull(input.clientNameSnapshot)),
        eventDate: Value(normalizedDate),
        fulfillmentMethod: Value(normalizedMethod),
        deliveryFeeCents: Value(normalizedDeliveryFee),
        referencePhotoPath: Value(_trimToNull(input.referencePhotoPath)),
        notes: Value(_trimToNull(input.notes)),
        estimatedCostCents: Value(input.estimatedCost.cents),
        suggestedSalePriceCents: Value(input.suggestedSalePrice.cents),
        predictedProfitCents: Value(input.predictedProfit.cents),
        suggestedPackagingId: Value(_trimToNull(input.suggestedPackagingId)),
        suggestedPackagingNameSnapshot: Value(
          _trimToNull(input.suggestedPackagingNameSnapshot),
        ),
        smartReviewSummary: Value(_trimToNull(input.smartReviewSummary)),
        orderTotalCents: Value(input.orderTotal.cents),
        depositAmountCents: Value(input.depositAmount.cents),
        status: Value(input.status.databaseValue),
        updatedAt: Value(now),
      );

      if (input.id == null) {
        await _database
            .into(_database.orders)
            .insert(
              orderCompanion.copyWith(
                id: Value(orderId),
                createdAt: Value(now),
              ),
            );
      } else {
        await (_database.update(
          _database.orders,
        )..where((table) => table.id.equals(orderId))).write(orderCompanion);
      }

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

      for (var index = 0; index < input.items.length; index++) {
        final item = input.items[index];
        await _database
            .into(_database.orderItems)
            .insert(
              OrderItemsCompanion.insert(
                id: item.id ?? _uuid.v4(),
                orderId: orderId,
                productId: Value(_trimToNull(item.productId)),
                itemNameSnapshot: item.itemNameSnapshot.trim(),
                flavorSnapshot: Value(_trimToNull(item.flavorSnapshot)),
                variationSnapshot: Value(_trimToNull(item.variationSnapshot)),
                priceCents: Value(item.price.cents),
                quantity: Value(item.quantity),
                notes: Value(_trimToNull(item.notes)),
                sortOrder: Value(index),
              ),
            );
      }

      for (var index = 0; index < input.productionPlans.length; index++) {
        final plan = input.productionPlans[index];
        await _database
            .into(_database.orderProductionPlans)
            .insert(
              OrderProductionPlansCompanion.insert(
                id: plan.id ?? _uuid.v4(),
                orderId: orderId,
                title: plan.title.trim(),
                details: Value(_trimToNull(plan.details)),
                planType: Value(plan.planType.databaseValue),
                recipeNameSnapshot: Value(_trimToNull(plan.recipeNameSnapshot)),
                itemNameSnapshot: Value(_trimToNull(plan.itemNameSnapshot)),
                quantity: Value(plan.quantity <= 0 ? 1 : plan.quantity),
                notes: Value(_trimToNull(plan.notes)),
                status: plan.status.databaseValue,
                dueDate: Value(_normalizeDate(plan.dueDate)),
                completedAt: Value(_normalizeDate(plan.completedAt)),
                sortOrder: Value(index),
                createdAt: Value(now),
              ),
            );
      }

      for (var index = 0; index < input.materialNeeds.length; index++) {
        final need = input.materialNeeds[index];
        await _database
            .into(_database.orderMaterialNeeds)
            .insert(
              OrderMaterialNeedsCompanion.insert(
                id: need.id ?? _uuid.v4(),
                orderId: orderId,
                materialType: need.materialType.databaseValue,
                linkedEntityId: Value(_trimToNull(need.linkedEntityId)),
                recipeNameSnapshot: Value(_trimToNull(need.recipeNameSnapshot)),
                itemNameSnapshot: Value(_trimToNull(need.itemNameSnapshot)),
                nameSnapshot: need.nameSnapshot.trim(),
                unitLabel: need.unitLabel.trim(),
                requiredQuantity: need.requiredQuantity,
                availableQuantity: Value(need.availableQuantity),
                shortageQuantity: Value(need.shortageQuantity),
                note: Value(_trimToNull(need.note)),
                consumedAt: Value(_normalizeDate(need.consumedAt)),
                consumedByPlanId: Value(_trimToNull(need.consumedByPlanId)),
                sortOrder: Value(index),
                createdAt: Value(now),
              ),
            );
      }

      for (final receivable in input.receivableEntries) {
        await _database
            .into(_database.orderReceivableEntries)
            .insert(
              OrderReceivableEntriesCompanion.insert(
                id: receivable.id ?? _uuid.v4(),
                orderId: orderId,
                description: receivable.description.trim(),
                amountCents: Value(receivable.amount.cents),
                dueDate: Value(_normalizeDate(receivable.dueDate)),
                status: receivable.status.databaseValue,
                createdAt: Value(now),
              ),
            );
      }

      await LocalSyncSupport.markEntityChanged(
        database: _database,
        entityType: RootSyncEntityType.order,
        entityId: orderId,
        updatedAt: now,
      );
    });

    return orderId;
  }

  Future<List<OrderRecord>> _mapOrderList(List<Order> rows) async {
    if (rows.isEmpty) {
      return const [];
    }

    final orderIds = rows.map((row) => row.id).toList(growable: false);
    final itemsByOrderId = await _loadOrderItemsByOrderIds(orderIds);

    return rows
        .map(
          (row) =>
              _mapOrderRecord(row, items: itemsByOrderId[row.id] ?? const []),
        )
        .toList(growable: false);
  }

  Future<OrderRecord> _mapCompleteOrder(Order row) async {
    final items = await _loadOrderItems(row.id);
    final productionPlans = await _loadProductionPlans(row.id);
    final materialNeeds = await _loadMaterialNeeds(row.id);
    final receivableEntries = await _loadReceivableEntries(row.id);

    return _mapOrderRecord(
      row,
      items: items,
      productionPlans: productionPlans,
      materialNeeds: materialNeeds,
      receivableEntries: receivableEntries,
    );
  }

  Future<List<OrderItemRecord>> _loadOrderItems(String orderId) async {
    final rows =
        await (_database.select(_database.orderItems)
              ..where((table) => table.orderId.equals(orderId))
              ..orderBy([(table) => OrderingTerm(expression: table.sortOrder)]))
            .get();

    return rows.map(_mapOrderItemRecord).toList(growable: false);
  }

  Future<Map<String, List<OrderItemRecord>>> _loadOrderItemsByOrderIds(
    List<String> orderIds,
  ) async {
    final rows =
        await (_database.select(_database.orderItems)
              ..where((table) => table.orderId.isIn(orderIds))
              ..orderBy([(table) => OrderingTerm(expression: table.sortOrder)]))
            .get();

    final result = <String, List<OrderItemRecord>>{};
    for (final row in rows) {
      result.putIfAbsent(row.orderId, () => []).add(_mapOrderItemRecord(row));
    }

    return result;
  }

  Future<List<OrderProductionPlanRecord>> _loadProductionPlans(
    String orderId,
  ) async {
    final rows =
        await (_database.select(_database.orderProductionPlans)
              ..where((table) => table.orderId.equals(orderId))
              ..orderBy([(table) => OrderingTerm(expression: table.sortOrder)]))
            .get();

    return rows.map(_mapOrderProductionPlanRecord).toList(growable: false);
  }

  Future<List<OrderMaterialNeedRecord>> _loadMaterialNeeds(
    String orderId,
  ) async {
    final rows =
        await (_database.select(_database.orderMaterialNeeds)
              ..where((table) => table.orderId.equals(orderId))
              ..orderBy([(table) => OrderingTerm(expression: table.sortOrder)]))
            .get();

    return rows.map(_mapOrderMaterialNeedRecord).toList(growable: false);
  }

  Future<List<OrderReceivableEntryRecord>> _loadReceivableEntries(
    String orderId,
  ) async {
    final rows =
        await (_database.select(_database.orderReceivableEntries)
              ..where((table) => table.orderId.equals(orderId))
              ..orderBy([
                (table) => OrderingTerm(
                  expression: table.dueDate,
                  mode: OrderingMode.asc,
                  nulls: NullsOrder.last,
                ),
              ]))
            .get();

    return rows.map(_mapOrderReceivableEntryRecord).toList(growable: false);
  }

  OrderRecord _mapOrderRecord(
    Order row, {
    List<OrderItemRecord> items = const [],
    List<OrderProductionPlanRecord> productionPlans = const [],
    List<OrderMaterialNeedRecord> materialNeeds = const [],
    List<OrderReceivableEntryRecord> receivableEntries = const [],
  }) {
    return OrderRecord(
      id: row.id,
      clientId: row.clientId,
      clientNameSnapshot: row.clientNameSnapshot,
      eventDate: row.eventDate,
      fulfillmentMethod: row.fulfillmentMethod == null
          ? null
          : OrderFulfillmentMethod.fromDatabase(row.fulfillmentMethod!),
      deliveryFee: Money.fromCents(row.deliveryFeeCents),
      referencePhotoPath: row.referencePhotoPath,
      notes: row.notes,
      estimatedCost: Money.fromCents(row.estimatedCostCents),
      suggestedSalePrice: Money.fromCents(row.suggestedSalePriceCents),
      predictedProfit: Money.fromCents(row.predictedProfitCents),
      suggestedPackagingId: row.suggestedPackagingId,
      suggestedPackagingNameSnapshot: row.suggestedPackagingNameSnapshot,
      smartReviewSummary: row.smartReviewSummary,
      orderTotal: Money.fromCents(row.orderTotalCents),
      depositAmount: Money.fromCents(row.depositAmountCents),
      status: OrderStatus.fromDatabase(row.status),
      createdAt: row.createdAt,
      updatedAt: row.updatedAt,
      items: items,
      productionPlans: productionPlans,
      materialNeeds: materialNeeds,
      receivableEntries: receivableEntries,
    );
  }

  OrderItemRecord _mapOrderItemRecord(OrderItem row) {
    return OrderItemRecord(
      id: row.id,
      orderId: row.orderId,
      productId: row.productId,
      itemNameSnapshot: row.itemNameSnapshot,
      flavorSnapshot: row.flavorSnapshot,
      variationSnapshot: row.variationSnapshot,
      price: Money.fromCents(row.priceCents),
      quantity: row.quantity,
      notes: row.notes,
      sortOrder: row.sortOrder,
    );
  }

  OrderProductionPlanRecord _mapOrderProductionPlanRecord(
    OrderProductionPlan row,
  ) {
    return OrderProductionPlanRecord(
      id: row.id,
      orderId: row.orderId,
      title: row.title,
      details: row.details,
      planType: OrderProductionPlanType.fromDatabase(row.planType),
      recipeNameSnapshot: row.recipeNameSnapshot,
      itemNameSnapshot: row.itemNameSnapshot,
      quantity: row.quantity,
      notes: row.notes,
      status: OrderProductionPlanStatus.fromDatabase(row.status),
      dueDate: row.dueDate,
      completedAt: row.completedAt,
      sortOrder: row.sortOrder,
      createdAt: row.createdAt,
    );
  }

  OrderMaterialNeedRecord _mapOrderMaterialNeedRecord(OrderMaterialNeed row) {
    return OrderMaterialNeedRecord(
      id: row.id,
      orderId: row.orderId,
      materialType: OrderMaterialType.fromDatabase(row.materialType),
      linkedEntityId: row.linkedEntityId,
      recipeNameSnapshot: row.recipeNameSnapshot,
      itemNameSnapshot: row.itemNameSnapshot,
      nameSnapshot: row.nameSnapshot,
      unitLabel: row.unitLabel,
      requiredQuantity: row.requiredQuantity,
      availableQuantity: row.availableQuantity,
      shortageQuantity: row.shortageQuantity,
      note: row.note,
      consumedAt: row.consumedAt,
      consumedByPlanId: row.consumedByPlanId,
      sortOrder: row.sortOrder,
      createdAt: row.createdAt,
    );
  }

  OrderReceivableEntryRecord _mapOrderReceivableEntryRecord(
    OrderReceivableEntry row,
  ) {
    return OrderReceivableEntryRecord(
      id: row.id,
      orderId: row.orderId,
      description: row.description,
      amount: Money.fromCents(row.amountCents),
      dueDate: row.dueDate,
      status: OrderReceivableStatus.fromDatabase(row.status),
      createdAt: row.createdAt,
    );
  }

  DateTime? _normalizeDate(DateTime? value) {
    if (value == null) {
      return null;
    }

    return DateTime(value.year, value.month, value.day);
  }

  String? _trimToNull(String? value) {
    final trimmed = value?.trim();
    if (trimmed == null || trimmed.isEmpty) {
      return null;
    }

    return trimmed;
  }
}
