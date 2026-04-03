import 'package:doceria_pro/core/database/app_database.dart';
import 'package:doceria_pro/core/money/money.dart';
import 'package:doceria_pro/features/orders/data/orders_repository.dart';
import 'package:doceria_pro/features/orders/domain/order.dart';
import 'package:doceria_pro/features/orders/domain/order_fulfillment_method.dart';
import 'package:doceria_pro/features/orders/domain/order_status.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase database;
  late OrdersRepository repository;

  setUp(() {
    database = AppDatabase(NativeDatabase.memory());
    repository = OrdersRepository(database);
  });

  tearDown(() async {
    await database.close();
  });

  test('saves and reads a locally persisted order', () async {
    final savedId = await repository.saveOrder(
      OrderUpsertInput(
        clientId: 'client-001',
        clientNameSnapshot: 'Mariana',
        eventDate: DateTime(2026, 5, 10),
        fulfillmentMethod: OrderFulfillmentMethod.delivery,
        deliveryFee: Money.fromCents(1500),
        notes: 'Levar na portaria.',
        orderTotal: Money.fromCents(25000),
        depositAmount: Money.fromCents(5000),
        status: OrderStatus.awaitingDeposit,
        items: [
          OrderItemInput(
            productId: 'product-001',
            itemNameSnapshot: 'Bolo no pote',
            flavorSnapshot: 'Brigadeiro',
            variationSnapshot: '250 ml',
            price: Money.fromCents(1800),
            quantity: 2,
            notes: 'Com colher',
          ),
        ],
      ),
    );

    final orders = await repository.watchOrders().first;

    expect(orders, hasLength(1));
    expect(orders.single.id, savedId);
    expect(orders.single.clientId, 'client-001');
    expect(orders.single.displayClientName, 'Mariana');
    expect(orders.single.orderTotal.cents, 25000);
    expect(orders.single.depositAmount.cents, 5000);
    expect(orders.single.remainingAmount.cents, 20000);
    expect(orders.single.fulfillmentMethod, OrderFulfillmentMethod.delivery);
    expect(orders.single.status, OrderStatus.awaitingDeposit);
    expect(orders.single.items, hasLength(1));
    expect(orders.single.items.single.productId, 'product-001');
    expect(orders.single.items.single.quantity, 2);
    expect(orders.single.items.single.lineTotal.cents, 3600);
    expect(
      orders.single.items.single.displayName,
      'Bolo no pote • Brigadeiro • 250 ml',
    );
    expect(orders.single.isDraft, isFalse);
  });

  test('updates an existing order and keeps the persisted row', () async {
    final savedId = await repository.saveOrder(
      OrderUpsertInput(
        clientNameSnapshot: 'Bianca',
        eventDate: DateTime(2026, 6, 1),
        fulfillmentMethod: OrderFulfillmentMethod.pickup,
        deliveryFee: Money.zero,
        notes: null,
        orderTotal: Money.fromCents(18000),
        depositAmount: Money.fromCents(3000),
        status: OrderStatus.budget,
      ),
    );

    await repository.saveOrder(
      OrderUpsertInput(
        id: savedId,
        clientNameSnapshot: 'Bianca Costa',
        eventDate: DateTime(2026, 6, 2),
        fulfillmentMethod: OrderFulfillmentMethod.pickup,
        deliveryFee: Money.fromCents(999),
        notes: 'Confirmado por mensagem.',
        orderTotal: Money.fromCents(21000),
        depositAmount: Money.fromCents(7000),
        status: OrderStatus.confirmed,
        items: [
          OrderItemInput(
            productId: null,
            itemNameSnapshot: 'Caixa premium',
            flavorSnapshot: null,
            variationSnapshot: null,
            price: Money.fromCents(21000),
            quantity: 1,
            notes: null,
          ),
        ],
      ),
    );

    final updatedOrder = await repository.watchOrder(savedId).first;

    expect(updatedOrder, isNotNull);
    expect(updatedOrder!.displayClientName, 'Bianca Costa');
    expect(updatedOrder.eventDate, DateTime(2026, 6, 2));
    expect(updatedOrder.status, OrderStatus.confirmed);
    expect(updatedOrder.deliveryFee, Money.zero);
    expect(updatedOrder.remainingAmount.cents, 14000);
    expect(updatedOrder.notes, 'Confirmado por mensagem.');
    expect(updatedOrder.items.single.itemNameSnapshot, 'Caixa premium');
  });

  test(
    'persists smart review snapshots and generated internal records',
    () async {
      final savedId = await repository.saveOrder(
        OrderUpsertInput(
          clientId: 'client-smart',
          clientNameSnapshot: 'Fernanda',
          eventDate: DateTime(2026, 8, 15),
          fulfillmentMethod: OrderFulfillmentMethod.delivery,
          deliveryFee: Money.fromCents(1200),
          referencePhotoPath: '/tmp/referencia.jpg',
          notes: 'Levar topper junto.',
          estimatedCost: Money.fromCents(9800),
          suggestedSalePrice: Money.fromCents(18000),
          predictedProfit: Money.fromCents(9400),
          suggestedPackagingId: 'packaging-1',
          suggestedPackagingNameSnapshot: 'Caixa premium G',
          smartReviewSummary: 'Falta açúcar e a embalagem está no limite.',
          orderTotal: Money.fromCents(19200),
          depositAmount: Money.fromCents(5000),
          status: OrderStatus.confirmed,
          items: [
            OrderItemInput(
              productId: 'product-smart',
              itemNameSnapshot: 'Bolo premium',
              flavorSnapshot: null,
              variationSnapshot: null,
              price: Money.fromCents(9000),
              quantity: 2,
              notes: null,
            ),
          ],
          productionPlans: [
            OrderProductionPlanInput(
              title: 'Produzir massa base',
              details: 'Separar produção um dia antes.',
              status: OrderProductionPlanStatus.pending,
              dueDate: DateTime(2026, 8, 14),
              sortOrder: 0,
            ),
          ],
          materialNeeds: [
            OrderMaterialNeedInput(
              materialType: OrderMaterialType.ingredient,
              linkedEntityId: 'ingredient-1',
              nameSnapshot: 'Açúcar',
              unitLabel: 'g',
              requiredQuantity: 500,
              availableQuantity: 200,
              shortageQuantity: 300,
              note: 'Comprar antes da produção',
              sortOrder: 0,
            ),
          ],
          receivableEntries: [
            OrderReceivableEntryInput(
              description: 'Sinal do pedido',
              amount: Money.fromCents(5000),
              dueDate: DateTime(2026, 8, 15),
              status: OrderReceivableStatus.received,
            ),
            OrderReceivableEntryInput(
              description: 'Saldo restante do pedido',
              amount: Money.fromCents(14200),
              dueDate: DateTime(2026, 8, 15),
              status: OrderReceivableStatus.pending,
            ),
          ],
        ),
      );

      final order = await repository.watchOrder(savedId).first;

      expect(order, isNotNull);
      expect(order!.estimatedCost.cents, 9800);
      expect(order.suggestedSalePrice.cents, 18000);
      expect(order.predictedProfit.cents, 9400);
      expect(order.suggestedPackagingNameSnapshot, 'Caixa premium G');
      expect(order.referencePhotoPath, '/tmp/referencia.jpg');
      expect(order.productionPlans, hasLength(1));
      expect(order.productionPlans.single.title, 'Produzir massa base');
      expect(order.materialNeeds, hasLength(1));
      expect(order.materialNeeds.single.shortageQuantity, 300);
      expect(order.receivableEntries, hasLength(2));
      expect(order.receivableEntries.last.amount.cents, 14200);
    },
  );

  test('filters local order history by linked client', () async {
    await repository.saveOrder(
      OrderUpsertInput(
        clientId: 'client-a',
        clientNameSnapshot: 'Amanda',
        eventDate: DateTime(2026, 7, 3),
        fulfillmentMethod: OrderFulfillmentMethod.pickup,
        deliveryFee: Money.zero,
        notes: null,
        orderTotal: Money.fromCents(14000),
        depositAmount: Money.fromCents(2000),
        status: OrderStatus.confirmed,
      ),
    );
    await repository.saveOrder(
      OrderUpsertInput(
        clientId: 'client-b',
        clientNameSnapshot: 'Bianca',
        eventDate: DateTime(2026, 7, 7),
        fulfillmentMethod: OrderFulfillmentMethod.delivery,
        deliveryFee: Money.fromCents(1000),
        notes: null,
        orderTotal: Money.fromCents(22000),
        depositAmount: Money.fromCents(5000),
        status: OrderStatus.inProduction,
      ),
    );

    final clientAOrders = await repository
        .watchOrdersForClient('client-a')
        .first;

    expect(clientAOrders, hasLength(1));
    expect(clientAOrders.single.clientId, 'client-a');
    expect(clientAOrders.single.displayClientName, 'Amanda');
  });
}
