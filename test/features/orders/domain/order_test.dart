import 'package:doceria_pro/core/money/money.dart';
import 'package:doceria_pro/features/orders/domain/order.dart';
import 'package:doceria_pro/features/orders/domain/order_fulfillment_method.dart';
import 'package:doceria_pro/features/orders/domain/order_list_filters.dart';
import 'package:doceria_pro/features/orders/domain/order_status.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

void main() {
  setUpAll(() async {
    await initializeDateFormatting('pt_BR');
  });

  test('order draft state depends on key operational fields', () {
    final draftOrder = OrderRecord(
      id: 'draft-1',
      clientNameSnapshot: null,
      eventDate: null,
      fulfillmentMethod: null,
      deliveryFee: Money.zero,
      notes: null,
      orderTotal: Money.zero,
      depositAmount: Money.zero,
      status: OrderStatus.budget,
      createdAt: DateTime(2026, 4, 2),
      updatedAt: DateTime(2026, 4, 2),
    );

    final readyOrder = OrderRecord(
      id: 'ready-1',
      clientNameSnapshot: 'Amanda',
      eventDate: DateTime(2026, 4, 10),
      fulfillmentMethod: OrderFulfillmentMethod.pickup,
      deliveryFee: Money.zero,
      notes: null,
      orderTotal: Money.fromCents(12000),
      depositAmount: Money.fromCents(2000),
      status: OrderStatus.confirmed,
      createdAt: DateTime(2026, 4, 2),
      updatedAt: DateTime(2026, 4, 2),
    );

    expect(draftOrder.isDraft, isTrue);
    expect(readyOrder.isDraft, isFalse);
    expect(readyOrder.remainingAmount.cents, 10000);
    expect(readyOrder.depositStateLabel, 'Sinal parcial');
  });

  test('order totals account for item quantity safely', () {
    final order = OrderRecord(
      id: 'with-items',
      clientNameSnapshot: 'Amanda',
      eventDate: DateTime(2026, 4, 10),
      fulfillmentMethod: OrderFulfillmentMethod.pickup,
      deliveryFee: Money.zero,
      orderTotal: Money.fromCents(18000),
      depositAmount: Money.fromCents(18000),
      status: OrderStatus.confirmed,
      createdAt: DateTime(2026, 4, 2),
      updatedAt: DateTime(2026, 4, 2),
      items: [
        OrderItemRecord(
          id: 'item-1',
          orderId: 'with-items',
          productId: 'product-1',
          itemNameSnapshot: 'Bolo no pote',
          flavorSnapshot: 'Brigadeiro',
          variationSnapshot: null,
          price: Money.fromCents(1800),
          quantity: 3,
          notes: null,
          sortOrder: 0,
        ),
      ],
    );

    expect(order.itemCount, 3);
    expect(order.items.single.lineTotal.cents, 5400);
    expect(order.itemsTotal.cents, 5400);
    expect(order.depositStateLabel, 'Sinal coberto');
  });

  test('filters apply search and status locally', () {
    final orders = [
      OrderRecord(
        id: '1',
        clientNameSnapshot: 'Amanda',
        eventDate: DateTime(2026, 4, 10),
        fulfillmentMethod: OrderFulfillmentMethod.pickup,
        deliveryFee: Money.zero,
        notes: 'Bolo com morango',
        orderTotal: Money.fromCents(12000),
        depositAmount: Money.fromCents(2000),
        status: OrderStatus.confirmed,
        createdAt: DateTime(2026, 4, 2),
        updatedAt: DateTime(2026, 4, 2),
      ),
      OrderRecord(
        id: '2',
        clientNameSnapshot: 'Bianca',
        eventDate: DateTime(2026, 4, 11),
        fulfillmentMethod: OrderFulfillmentMethod.delivery,
        deliveryFee: Money.fromCents(1500),
        notes: 'Entregar cedo',
        orderTotal: Money.fromCents(25000),
        depositAmount: Money.fromCents(5000),
        status: OrderStatus.awaitingDeposit,
        createdAt: DateTime(2026, 4, 2),
        updatedAt: DateTime(2026, 4, 2),
      ),
    ];

    final filtered = const OrderListFilters(
      searchQuery: 'entregar',
      status: OrderStatus.awaitingDeposit,
    ).apply(orders);

    expect(filtered, hasLength(1));
    expect(filtered.single.id, '2');
  });

  test('date groups keep undated orders at the end', () {
    final groups = buildOrderDateGroups([
      OrderRecord(
        id: 'with-date',
        clientNameSnapshot: 'Amanda',
        eventDate: DateTime(2099, 4, 10),
        fulfillmentMethod: OrderFulfillmentMethod.pickup,
        deliveryFee: Money.zero,
        notes: null,
        orderTotal: Money.fromCents(12000),
        depositAmount: Money.fromCents(2000),
        status: OrderStatus.confirmed,
        createdAt: DateTime(2026, 4, 2),
        updatedAt: DateTime(2026, 4, 2),
      ),
      OrderRecord(
        id: 'no-date',
        clientNameSnapshot: 'Bianca',
        eventDate: null,
        fulfillmentMethod: OrderFulfillmentMethod.delivery,
        deliveryFee: Money.fromCents(1500),
        notes: null,
        orderTotal: Money.fromCents(25000),
        depositAmount: Money.fromCents(5000),
        status: OrderStatus.awaitingDeposit,
        createdAt: DateTime(2026, 4, 2),
        updatedAt: DateTime(2026, 4, 2),
      ),
    ]);

    expect(groups, hasLength(2));
    expect(groups.first.orders.single.id, 'with-date');
    expect(groups.last.label, 'Sem data definida');
  });
}
