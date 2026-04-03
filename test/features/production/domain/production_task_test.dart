import 'package:doceria_pro/features/orders/domain/order.dart';
import 'package:doceria_pro/features/orders/domain/order_status.dart';
import 'package:doceria_pro/features/production/domain/production_filters.dart';
import 'package:doceria_pro/features/production/domain/production_task.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('today filter keeps overdue, today and undated tasks', () {
    final today = DateTime.now();
    final normalizedToday = DateTime(today.year, today.month, today.day);

    final tasks = [
      _buildTask(
        planId: 'overdue',
        dueDate: normalizedToday.subtract(const Duration(days: 1)),
      ),
      _buildTask(planId: 'today', dueDate: normalizedToday),
      _buildTask(
        planId: 'future',
        dueDate: normalizedToday.add(const Duration(days: 3)),
      ),
      _buildTask(planId: 'undated', dueDate: null),
    ];

    final filtered = applyProductionFilters(
      tasks,
      const ProductionFilters(timeframe: ProductionTimeframe.today),
    );

    expect(
      filtered.map((task) => task.plan.id),
      containsAll(['overdue', 'today', 'undated']),
    );
    expect(filtered.map((task) => task.plan.id), isNot(contains('future')));
  });

  test('grouping by recipe clusters related tasks together', () {
    final tasks = [
      _buildTask(
        planId: 'a',
        recipeName: 'Massa branca',
        itemName: 'Mini bolo',
      ),
      _buildTask(
        planId: 'b',
        recipeName: 'Massa branca',
        itemName: 'Bolo fatia',
      ),
      _buildTask(planId: 'c', recipeName: 'Ganache', itemName: 'Mini bolo'),
    ];

    final groups = buildProductionTaskGroups(tasks, ProductionGrouping.recipe);

    expect(groups, hasLength(2));
    expect(groups.first.tasks, hasLength(1));
    expect(groups.last.tasks, hasLength(2));
  });
}

ProductionTaskRecord _buildTask({
  required String planId,
  DateTime? dueDate,
  String recipeName = 'Receita base',
  String itemName = 'Mini bolo',
}) {
  return ProductionTaskRecord(
    plan: OrderProductionPlanRecord(
      id: planId,
      orderId: 'order-1',
      title: 'Produzir etapa $planId',
      details: null,
      planType: OrderProductionPlanType.recipe,
      recipeNameSnapshot: recipeName,
      itemNameSnapshot: itemName,
      quantity: 2,
      notes: null,
      status: OrderProductionPlanStatus.pending,
      dueDate: dueDate,
      completedAt: null,
      sortOrder: 0,
      createdAt: DateTime(2026, 4, 2),
    ),
    orderId: 'order-1',
    clientNameSnapshot: 'Amanda',
    orderDate: dueDate,
    orderStatus: OrderStatus.confirmed,
    itemDisplayName: itemName,
    flavorSnapshot: null,
    variationSnapshot: null,
    orderNotes: null,
    relatedMaterialNeeds: const [],
  );
}
