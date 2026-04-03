import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../../core/database/app_database.dart';
import '../../../core/sync/sync_definitions.dart';
import '../../ingredients/domain/ingredient_stock_movement_type.dart';
import '../../orders/domain/order.dart';
import '../../orders/domain/order_status.dart';
import '../../packaging/domain/packaging_stock_movement_type.dart';
import '../../sync/data/local_sync_support.dart';
import '../domain/production_task.dart';

class ProductionRepository {
  ProductionRepository(this._database);

  final AppDatabase _database;
  final Uuid _uuid = const Uuid();

  Stream<List<ProductionTaskRecord>> watchTasks() {
    final query =
        _database.select(_database.orderProductionPlans).join([
          innerJoin(
            _database.orders,
            _database.orders.id.equalsExp(
              _database.orderProductionPlans.orderId,
            ),
          ),
        ])..orderBy([
          OrderingTerm(
            expression: _database.orderProductionPlans.dueDate,
            mode: OrderingMode.asc,
            nulls: NullsOrder.last,
          ),
          OrderingTerm(expression: _database.orderProductionPlans.sortOrder),
        ]);

    return query.watch().asyncMap(_mapTaskRows);
  }

  Future<void> updatePlanStatus({
    required String planId,
    required OrderProductionPlanStatus status,
  }) async {
    await _database.transaction(() async {
      final plan = await (_database.select(
        _database.orderProductionPlans,
      )..where((table) => table.id.equals(planId))).getSingleOrNull();

      if (plan == null) {
        throw StateError('Production plan not found.');
      }

      final currentStatus = OrderProductionPlanStatus.fromDatabase(plan.status);
      if (currentStatus == status) {
        return;
      }

      if (currentStatus == OrderProductionPlanStatus.completed &&
          status != OrderProductionPlanStatus.completed) {
        throw StateError(
          'Completed production plans cannot be reopened to avoid duplicate stock effects.',
        );
      }

      final now = DateTime.now();

      if (status == OrderProductionPlanStatus.completed) {
        await _applyCompletionEffects(plan: plan, completedAt: now);
      }

      await (_database.update(
        _database.orderProductionPlans,
      )..where((table) => table.id.equals(planId))).write(
        OrderProductionPlansCompanion(
          status: Value(status.databaseValue),
          completedAt: Value(
            status == OrderProductionPlanStatus.completed ? now : null,
          ),
        ),
      );

      await (_database.update(_database.orders)
            ..where((table) => table.id.equals(plan.orderId)))
          .write(OrdersCompanion(updatedAt: Value(now)));

      await LocalSyncSupport.markEntityChanged(
        database: _database,
        entityType: RootSyncEntityType.order,
        entityId: plan.orderId,
        updatedAt: now,
      );
    });
  }

  Future<List<ProductionTaskRecord>> _mapTaskRows(
    List<TypedResult> rows,
  ) async {
    if (rows.isEmpty) {
      return const [];
    }

    final orderIds = rows
        .map((row) => row.readTable(_database.orders).id)
        .toSet()
        .toList(growable: false);
    final itemsByOrderId = await _loadOrderItemsByOrderIds(orderIds);
    final materialNeedsByOrderId = await _loadMaterialNeedsByOrderIds(orderIds);

    return rows
        .map((row) {
          final planRow = row.readTable(_database.orderProductionPlans);
          final orderRow = row.readTable(_database.orders);
          final orderItems = itemsByOrderId[orderRow.id] ?? const <OrderItem>[];
          final matchingItem = _findMatchingOrderItem(
            plan: planRow,
            orderItems: orderItems,
          );
          final relatedMaterialNeeds = _pickRelatedMaterialNeeds(
            plan: planRow,
            materialNeeds: materialNeedsByOrderId[orderRow.id] ?? const [],
          );

          return ProductionTaskRecord(
            plan: OrderProductionPlanRecord(
              id: planRow.id,
              orderId: planRow.orderId,
              title: planRow.title,
              details: planRow.details,
              planType: OrderProductionPlanType.fromDatabase(planRow.planType),
              recipeNameSnapshot: planRow.recipeNameSnapshot,
              itemNameSnapshot: planRow.itemNameSnapshot,
              quantity: planRow.quantity,
              notes: planRow.notes,
              status: OrderProductionPlanStatus.fromDatabase(planRow.status),
              dueDate: planRow.dueDate,
              completedAt: planRow.completedAt,
              sortOrder: planRow.sortOrder,
              createdAt: planRow.createdAt,
            ),
            orderId: orderRow.id,
            clientNameSnapshot: orderRow.clientNameSnapshot ?? '',
            orderDate: orderRow.eventDate,
            orderStatus: OrderStatus.fromDatabase(orderRow.status),
            itemDisplayName:
                matchingItem?.itemNameSnapshot ??
                planRow.itemNameSnapshot ??
                orderItems.firstOrNull?.itemNameSnapshot ??
                'Item do pedido',
            flavorSnapshot: matchingItem?.flavorSnapshot,
            variationSnapshot: matchingItem?.variationSnapshot,
            orderNotes: orderRow.notes,
            relatedMaterialNeeds: relatedMaterialNeeds
                .map(_mapMaterialNeedRecord)
                .toList(growable: false),
          );
        })
        .toList(growable: false);
  }

  Future<Map<String, List<OrderItem>>> _loadOrderItemsByOrderIds(
    List<String> orderIds,
  ) async {
    final rows =
        await (_database.select(_database.orderItems)
              ..where((table) => table.orderId.isIn(orderIds))
              ..orderBy([(table) => OrderingTerm(expression: table.sortOrder)]))
            .get();

    final result = <String, List<OrderItem>>{};
    for (final row in rows) {
      result.putIfAbsent(row.orderId, () => []).add(row);
    }

    return result;
  }

  Future<Map<String, List<OrderMaterialNeed>>> _loadMaterialNeedsByOrderIds(
    List<String> orderIds,
  ) async {
    final rows =
        await (_database.select(_database.orderMaterialNeeds)
              ..where((table) => table.orderId.isIn(orderIds))
              ..orderBy([(table) => OrderingTerm(expression: table.sortOrder)]))
            .get();

    final result = <String, List<OrderMaterialNeed>>{};
    for (final row in rows) {
      result.putIfAbsent(row.orderId, () => []).add(row);
    }

    return result;
  }

  OrderItem? _findMatchingOrderItem({
    required OrderProductionPlan plan,
    required List<OrderItem> orderItems,
  }) {
    for (final item in orderItems) {
      if (item.itemNameSnapshot == plan.itemNameSnapshot) {
        return item;
      }
    }

    if (orderItems.isEmpty) {
      return null;
    }

    return orderItems.first;
  }

  List<OrderMaterialNeed> _pickRelatedMaterialNeeds({
    required OrderProductionPlan plan,
    required List<OrderMaterialNeed> materialNeeds,
  }) {
    return materialNeeds
        .where((need) {
          final materialType = OrderMaterialType.fromDatabase(
            need.materialType,
          );
          switch (OrderProductionPlanType.fromDatabase(plan.planType)) {
            case OrderProductionPlanType.order:
              return true;
            case OrderProductionPlanType.recipe:
              return materialType == OrderMaterialType.ingredient &&
                  need.recipeNameSnapshot == plan.recipeNameSnapshot;
            case OrderProductionPlanType.packaging:
              return materialType == OrderMaterialType.packaging &&
                  need.itemNameSnapshot == plan.itemNameSnapshot;
          }
        })
        .toList(growable: false);
  }

  Future<void> _applyCompletionEffects({
    required OrderProductionPlan plan,
    required DateTime completedAt,
  }) async {
    final planType = OrderProductionPlanType.fromDatabase(plan.planType);
    if (planType == OrderProductionPlanType.order) {
      return;
    }

    final materialNeeds =
        await (_database.select(_database.orderMaterialNeeds)
              ..where((table) => table.orderId.equals(plan.orderId))
              ..orderBy([(table) => OrderingTerm(expression: table.sortOrder)]))
            .get();

    final matchingNeeds = materialNeeds
        .where((need) {
          if (need.consumedAt != null) {
            return false;
          }

          final materialType = OrderMaterialType.fromDatabase(
            need.materialType,
          );
          switch (planType) {
            case OrderProductionPlanType.order:
              return false;
            case OrderProductionPlanType.recipe:
              return materialType == OrderMaterialType.ingredient &&
                  need.recipeNameSnapshot == plan.recipeNameSnapshot;
            case OrderProductionPlanType.packaging:
              return materialType == OrderMaterialType.packaging &&
                  need.itemNameSnapshot == plan.itemNameSnapshot;
          }
        })
        .toList(growable: false);

    for (final need in matchingNeeds) {
      switch (OrderMaterialType.fromDatabase(need.materialType)) {
        case OrderMaterialType.ingredient:
          await _consumeIngredientNeed(
            need: need,
            plan: plan,
            completedAt: completedAt,
          );
        case OrderMaterialType.packaging:
          await _consumePackagingNeed(
            need: need,
            plan: plan,
            completedAt: completedAt,
          );
      }
    }
  }

  Future<void> _consumeIngredientNeed({
    required OrderMaterialNeed need,
    required OrderProductionPlan plan,
    required DateTime completedAt,
  }) async {
    if (need.requiredQuantity <= 0) {
      await _markNeedConsumed(
        needId: need.id,
        planId: plan.id,
        consumedAt: completedAt,
      );
      return;
    }

    if (need.linkedEntityId == null) {
      throw StateError(
        'Ingredient material need is missing the linked entity id.',
      );
    }

    final ingredient =
        await (_database.select(_database.ingredients)
              ..where((table) => table.id.equals(need.linkedEntityId!)))
            .getSingleOrNull();
    if (ingredient == null) {
      throw StateError('Ingredient not found for the production need.');
    }

    final resultingStock =
        ingredient.currentStockQuantity - need.requiredQuantity;
    if (resultingStock < 0) {
      throw StateError(
        'Not enough ingredient stock to complete this production task.',
      );
    }

    await (_database.update(
      _database.ingredients,
    )..where((table) => table.id.equals(ingredient.id))).write(
      IngredientsCompanion(
        currentStockQuantity: Value(resultingStock),
        updatedAt: Value(completedAt),
      ),
    );

    await _database
        .into(_database.ingredientStockMovements)
        .insert(
          IngredientStockMovementsCompanion.insert(
            id: _uuid.v4(),
            ingredientId: ingredient.id,
            movementType:
                IngredientStockMovementType.productionConsumption.databaseValue,
            quantityDelta: -need.requiredQuantity,
            previousStockQuantity: ingredient.currentStockQuantity,
            resultingStockQuantity: resultingStock,
            reason: 'Conclusão da produção',
            notes: Value(plan.title),
            referenceType: const Value('order_production_plan'),
            referenceId: Value(plan.id),
            createdAt: Value(completedAt),
          ),
        );

    await LocalSyncSupport.markEntityChanged(
      database: _database,
      entityType: RootSyncEntityType.ingredient,
      entityId: ingredient.id,
      updatedAt: completedAt,
    );

    await _markNeedConsumed(
      needId: need.id,
      planId: plan.id,
      consumedAt: completedAt,
    );
  }

  Future<void> _consumePackagingNeed({
    required OrderMaterialNeed need,
    required OrderProductionPlan plan,
    required DateTime completedAt,
  }) async {
    if (need.requiredQuantity <= 0) {
      await _markNeedConsumed(
        needId: need.id,
        planId: plan.id,
        consumedAt: completedAt,
      );
      return;
    }

    if (need.linkedEntityId == null) {
      throw StateError(
        'Packaging material need is missing the linked entity id.',
      );
    }

    final packaging =
        await (_database.select(_database.packaging)
              ..where((table) => table.id.equals(need.linkedEntityId!)))
            .getSingleOrNull();
    if (packaging == null) {
      throw StateError('Packaging item not found for the production need.');
    }

    final resultingStock =
        packaging.currentStockQuantity - need.requiredQuantity;
    if (resultingStock < 0) {
      throw StateError(
        'Not enough packaging stock to complete this production task.',
      );
    }

    await (_database.update(
      _database.packaging,
    )..where((table) => table.id.equals(packaging.id))).write(
      PackagingCompanion(
        currentStockQuantity: Value(resultingStock),
        updatedAt: Value(completedAt),
      ),
    );

    await _database
        .into(_database.packagingStockMovements)
        .insert(
          PackagingStockMovementsCompanion.insert(
            id: _uuid.v4(),
            packagingId: packaging.id,
            movementType:
                PackagingStockMovementType.productionConsumption.databaseValue,
            quantityDelta: -need.requiredQuantity,
            previousStockQuantity: packaging.currentStockQuantity,
            resultingStockQuantity: resultingStock,
            reason: 'Conclusão da produção',
            notes: Value(plan.title),
            referenceType: const Value('order_production_plan'),
            referenceId: Value(plan.id),
            createdAt: Value(completedAt),
          ),
        );

    await LocalSyncSupport.markEntityChanged(
      database: _database,
      entityType: RootSyncEntityType.packaging,
      entityId: packaging.id,
      updatedAt: completedAt,
    );

    await _markNeedConsumed(
      needId: need.id,
      planId: plan.id,
      consumedAt: completedAt,
    );
  }

  Future<void> _markNeedConsumed({
    required String needId,
    required String planId,
    required DateTime consumedAt,
  }) {
    return (_database.update(
      _database.orderMaterialNeeds,
    )..where((table) => table.id.equals(needId))).write(
      OrderMaterialNeedsCompanion(
        consumedAt: Value(consumedAt),
        consumedByPlanId: Value(planId),
      ),
    );
  }

  OrderMaterialNeedRecord _mapMaterialNeedRecord(OrderMaterialNeed row) {
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
}

extension on List<OrderItem> {
  OrderItem? get firstOrNull => isEmpty ? null : first;
}
