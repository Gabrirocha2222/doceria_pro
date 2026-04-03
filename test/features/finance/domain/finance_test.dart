import 'package:doceria_pro/core/money/money.dart';
import 'package:doceria_pro/features/finance/domain/finance.dart';
import 'package:doceria_pro/features/orders/domain/order.dart';
import 'package:doceria_pro/features/orders/domain/order_fulfillment_method.dart';
import 'package:doceria_pro/features/orders/domain/order_status.dart';
import 'package:doceria_pro/features/purchases/domain/purchase.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('buildFinanceOverview aggregates real and projected values safely', () {
    final overview = buildFinanceOverview(
      filter: FinancePeriodFilter.monthly,
      now: DateTime(2026, 4, 15),
      orders: [
        OrderRecord(
          id: 'order-1',
          clientNameSnapshot: 'Amanda',
          eventDate: DateTime(2026, 4, 20),
          fulfillmentMethod: OrderFulfillmentMethod.pickup,
          deliveryFee: Money.zero,
          orderTotal: Money.fromCents(12000),
          depositAmount: Money.fromCents(3000),
          predictedProfit: Money.fromCents(7000),
          status: OrderStatus.confirmed,
          createdAt: DateTime(2026, 4, 10),
          updatedAt: DateTime(2026, 4, 10),
        ),
      ],
      receivables: [
        FinanceReceivableRecord(
          id: 'receivable-received',
          orderId: 'order-1',
          clientNameSnapshot: 'Amanda',
          orderStatus: OrderStatus.confirmed,
          orderDate: DateTime(2026, 4, 20),
          description: 'Sinal',
          amount: Money.fromCents(3000),
          dueDate: DateTime(2026, 4, 10),
          status: OrderReceivableStatus.received,
          createdAt: DateTime(2026, 4, 10),
          receivedAt: DateTime(2026, 4, 12),
        ),
        FinanceReceivableRecord(
          id: 'receivable-pending',
          orderId: 'order-1',
          clientNameSnapshot: 'Amanda',
          orderStatus: OrderStatus.confirmed,
          orderDate: DateTime(2026, 4, 20),
          description: 'Restante',
          amount: Money.fromCents(9000),
          dueDate: DateTime(2026, 4, 20),
          status: OrderReceivableStatus.pending,
          createdAt: DateTime(2026, 4, 10),
          receivedAt: null,
        ),
      ],
      expenses: [
        FinanceExpenseRecord(
          id: 'expense-paid',
          purchaseEntryId: 'purchase-1',
          description: 'Compra de chocolate',
          supplierId: 'supplier-1',
          supplierNameSnapshot: 'Atacadista Central',
          amount: Money.fromCents(2000),
          status: PurchaseExpenseDraftStatus.paid,
          createdAt: DateTime(2026, 4, 11),
          paidAt: DateTime(2026, 4, 13),
        ),
        FinanceExpenseRecord(
          id: 'expense-prepared',
          purchaseEntryId: 'purchase-2',
          description: 'Compra de caixa',
          supplierId: 'supplier-2',
          supplierNameSnapshot: 'Embalagens Express',
          amount: Money.fromCents(1500),
          status: PurchaseExpenseDraftStatus.prepared,
          createdAt: DateTime(2026, 4, 14),
          paidAt: null,
        ),
      ],
      manualEntries: [
        FinanceManualEntryRecord(
          id: 'manual-income',
          entryType: FinanceManualEntryType.income,
          description: 'Pix extra',
          amount: Money.fromCents(500),
          entryDate: DateTime(2026, 4, 15),
          category: 'Ajuste',
          notes: null,
          createdAt: DateTime(2026, 4, 15),
          updatedAt: DateTime(2026, 4, 15),
        ),
        FinanceManualEntryRecord(
          id: 'manual-expense',
          entryType: FinanceManualEntryType.expense,
          description: 'Entrega',
          amount: Money.fromCents(700),
          entryDate: DateTime(2026, 4, 15),
          category: 'Logística',
          notes: null,
          createdAt: DateTime(2026, 4, 15),
          updatedAt: DateTime(2026, 4, 15),
        ),
      ],
    );

    expect(overview.cashIn.cents, 3500);
    expect(overview.cashOut.cents, 2700);
    expect(overview.pendingReceivables.cents, 9000);
    expect(overview.estimatedProfit.cents, 7000);
    expect(overview.actualProfit.cents, 800);
    expect(overview.preparedExpensesCount, 1);
    expect(overview.preparedExpensesAmount.cents, 1500);
    expect(overview.breakEvenTitle, 'Período acima do equilíbrio');
  });

  test('filterReceivablesByPeriod keeps overdue pending entries visible', () {
    final filtered = filterReceivablesByPeriod(
      [
        FinanceReceivableRecord(
          id: 'overdue',
          orderId: 'order-1',
          clientNameSnapshot: 'Amanda',
          orderStatus: OrderStatus.confirmed,
          orderDate: DateTime(2026, 4, 20),
          description: 'Restante',
          amount: Money.fromCents(8000),
          dueDate: DateTime(2026, 4, 10),
          status: OrderReceivableStatus.pending,
          createdAt: DateTime(2026, 4, 10),
          receivedAt: null,
        ),
        FinanceReceivableRecord(
          id: 'future',
          orderId: 'order-2',
          clientNameSnapshot: 'Bianca',
          orderStatus: OrderStatus.confirmed,
          orderDate: DateTime(2026, 4, 22),
          description: 'Restante',
          amount: Money.fromCents(5000),
          dueDate: DateTime(2026, 4, 20),
          status: OrderReceivableStatus.pending,
          createdAt: DateTime(2026, 4, 15),
          receivedAt: null,
        ),
        FinanceReceivableRecord(
          id: 'received',
          orderId: 'order-3',
          clientNameSnapshot: 'Carla',
          orderStatus: OrderStatus.delivered,
          orderDate: DateTime(2026, 4, 15),
          description: 'Sinal',
          amount: Money.fromCents(2000),
          dueDate: DateTime(2026, 4, 15),
          status: OrderReceivableStatus.received,
          createdAt: DateTime(2026, 4, 12),
          receivedAt: DateTime(2026, 4, 15),
        ),
      ],
      FinancePeriodFilter.daily,
      now: DateTime(2026, 4, 15),
    );

    expect(filtered.map((entry) => entry.id), ['overdue', 'received']);
  });
}
