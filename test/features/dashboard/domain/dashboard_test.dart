import 'package:doceria_pro/core/money/money.dart';
import 'package:doceria_pro/features/dashboard/domain/dashboard.dart';
import 'package:doceria_pro/features/finance/domain/finance.dart';
import 'package:doceria_pro/features/ingredients/domain/ingredient.dart';
import 'package:doceria_pro/features/ingredients/domain/ingredient_unit.dart';
import 'package:doceria_pro/features/orders/domain/order.dart';
import 'package:doceria_pro/features/orders/domain/order_fulfillment_method.dart';
import 'package:doceria_pro/features/orders/domain/order_status.dart';
import 'package:doceria_pro/features/production/domain/production_task.dart';
import 'package:doceria_pro/features/purchases/domain/purchase.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

void main() {
  setUpAll(() async {
    await initializeDateFormatting('pt_BR');
  });

  test('buildDashboardSnapshot highlights the daily priorities in seconds', () {
    final snapshot = buildDashboardSnapshot(
      now: DateTime(2026, 4, 2, 9),
      orders: [
        OrderRecord(
          id: 'order-today',
          clientNameSnapshot: 'Amanda',
          eventDate: DateTime(2026, 4, 2),
          fulfillmentMethod: OrderFulfillmentMethod.delivery,
          deliveryFee: Money.fromCents(1200),
          orderTotal: Money.fromCents(18000),
          depositAmount: Money.zero,
          predictedProfit: Money.fromCents(9000),
          status: OrderStatus.awaitingDeposit,
          createdAt: DateTime(2026, 4, 1),
          updatedAt: DateTime(2026, 4, 1),
        ),
        OrderRecord(
          id: 'order-week',
          clientNameSnapshot: 'Bianca',
          eventDate: DateTime(2026, 4, 4),
          fulfillmentMethod: OrderFulfillmentMethod.pickup,
          deliveryFee: Money.zero,
          orderTotal: Money.fromCents(22000),
          depositAmount: Money.fromCents(5000),
          predictedProfit: Money.fromCents(11000),
          status: OrderStatus.confirmed,
          createdAt: DateTime(2026, 4, 1),
          updatedAt: DateTime(2026, 4, 1),
        ),
        OrderRecord(
          id: 'budget',
          clientNameSnapshot: 'Carla',
          eventDate: DateTime(2026, 4, 5),
          fulfillmentMethod: OrderFulfillmentMethod.pickup,
          deliveryFee: Money.zero,
          orderTotal: Money.fromCents(10000),
          depositAmount: Money.zero,
          predictedProfit: Money.fromCents(6000),
          status: OrderStatus.budget,
          createdAt: DateTime(2026, 4, 1),
          updatedAt: DateTime(2026, 4, 1),
        ),
      ],
      productionTasks: [
        ProductionTaskRecord(
          plan: OrderProductionPlanRecord(
            id: 'plan-1',
            orderId: 'order-today',
            title: 'Assar massa',
            details: null,
            planType: OrderProductionPlanType.order,
            recipeNameSnapshot: null,
            itemNameSnapshot: 'Bolo',
            quantity: 1,
            notes: null,
            status: OrderProductionPlanStatus.pending,
            dueDate: DateTime(2026, 4, 1),
            completedAt: null,
            sortOrder: 0,
            createdAt: DateTime(2026, 4, 1),
          ),
          orderId: 'order-today',
          clientNameSnapshot: 'Amanda',
          orderDate: DateTime(2026, 4, 2),
          orderStatus: OrderStatus.awaitingDeposit,
          itemDisplayName: 'Bolo',
          flavorSnapshot: 'Brigadeiro',
          variationSnapshot: null,
          orderNotes: null,
          relatedMaterialNeeds: const [],
        ),
      ],
      purchaseItems: [
        PurchaseChecklistItemRecord(
          materialType: OrderMaterialType.ingredient,
          linkedEntityId: 'ingredient-1',
          nameSnapshot: 'Chocolate',
          categoryLabel: 'Base',
          stockUnitLabel: 'g',
          purchaseUnitLabel: 'kg',
          stockUnitsPerPurchaseUnit: 1000,
          currentStockQuantity: 200,
          minimumStockQuantity: 500,
          buyNowDemandQuantity: 700,
          thisWeekDemandQuantity: 900,
          buyNowShortageQuantity: 1000,
          thisWeekShortageQuantity: 1200,
          suggestedSupplier: const PurchaseSuggestedSupplier(
            supplierId: 'supplier-1',
            supplierName: 'Atacadista Central',
            contact: null,
            leadTimeDays: 2,
            lastKnownUnitPrice: null,
            priceUnitLabel: 'kg',
            lastKnownPriceAt: null,
          ),
          relatedOrders: [
            PurchaseOrderReference(
              orderId: 'order-today',
              clientNameSnapshot: 'Amanda',
              orderDate: DateTime(2026, 4, 2),
              recipeNameSnapshot: null,
              itemNameSnapshot: 'Bolo',
            ),
          ],
          note: null,
          usesDynamicStockRule: true,
        ),
      ],
      receivables: [
        FinanceReceivableRecord(
          id: 'receivable-1',
          orderId: 'order-today',
          clientNameSnapshot: 'Amanda',
          orderStatus: OrderStatus.awaitingDeposit,
          orderDate: DateTime(2026, 4, 2),
          description: 'Pedido confirmado',
          amount: Money.fromCents(18000),
          dueDate: DateTime(2026, 4, 2),
          status: OrderReceivableStatus.pending,
          createdAt: DateTime(2026, 4, 1),
          receivedAt: null,
        ),
      ],
      expenses: [
        FinanceExpenseRecord(
          id: 'expense-1',
          purchaseEntryId: 'purchase-1',
          description: 'Compra de chocolate',
          supplierId: 'supplier-1',
          supplierNameSnapshot: 'Atacadista Central',
          amount: Money.fromCents(4000),
          status: PurchaseExpenseDraftStatus.prepared,
          createdAt: DateTime(2026, 4, 2),
          paidAt: null,
        ),
      ],
      manualEntries: [
        FinanceManualEntryRecord(
          id: 'manual-1',
          entryType: FinanceManualEntryType.income,
          description: 'Pix extra',
          amount: Money.fromCents(500),
          entryDate: DateTime(2026, 4, 2),
          category: null,
          notes: null,
          createdAt: DateTime(2026, 4, 2),
          updatedAt: DateTime(2026, 4, 2),
        ),
      ],
      lowStockIngredients: [
        IngredientRecord(
          id: 'ingredient-1',
          name: 'Chocolate',
          category: 'Base',
          purchaseUnit: IngredientUnit.kilogram,
          stockUnit: IngredientUnit.gram,
          currentStockQuantity: 200,
          minimumStockQuantity: 500,
          unitCost: Money.fromCents(2500),
          defaultSupplier: null,
          conversionFactor: 1000,
          notes: null,
          createdAt: DateTime(2026, 4, 1),
          updatedAt: DateTime(2026, 4, 1),
        ),
      ],
    );

    expect(snapshot.greetingTitle, 'Bom dia');
    expect(snapshot.summaryCards[0].value, '2');
    expect(snapshot.summaryCards[1].value, 'R\$ 200,00');
    expect(snapshot.summaryCards[2].value, 'R\$ 180,00');
    expect(snapshot.summaryCards[3].value, '1');
    expect(snapshot.actions[0].valueLabel, '1 tarefa');
    expect(snapshot.actions[1].valueLabel, '1 pedido');
    expect(snapshot.alerts.first.priority, DashboardAlertPriority.high);
    expect(
      snapshot.alerts.map((alert) => alert.title),
      contains('Produção atrasada'),
    );
    expect(snapshot.financeSummary.cashInToday.cents, 500);
    expect(snapshot.financeSummary.preparedExpenses.cents, 4000);
    expect(snapshot.weekAgenda, hasLength(2));
    expect(snapshot.attentionSummary, contains('tarefa de produção'));
    expect(snapshot.attentionSummary, contains('pedido de hoje'));
  });

  test('buildDashboardSnapshot can stay calm when there is no urgent work', () {
    final snapshot = buildDashboardSnapshot(
      now: DateTime(2026, 4, 2, 16),
      orders: const [],
      productionTasks: const [],
      purchaseItems: const [],
      receivables: const [],
      expenses: const [],
      manualEntries: const [],
      lowStockIngredients: const [],
    );

    expect(snapshot.greetingTitle, 'Boa tarde');
    expect(snapshot.attentionSummary, contains('dia começou leve'));
    expect(snapshot.alerts, isEmpty);
    expect(snapshot.weekAgenda, isEmpty);
    expect(
      snapshot.financeSummary.note,
      'Ainda sem movimento financeiro real hoje.',
    );
  });
}
