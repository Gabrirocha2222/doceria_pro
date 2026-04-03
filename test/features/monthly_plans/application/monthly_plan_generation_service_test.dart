import 'package:doceria_pro/core/database/app_database.dart';
import 'package:doceria_pro/core/money/money.dart';
import 'package:doceria_pro/features/monthly_plans/application/monthly_plan_generation_service.dart';
import 'package:doceria_pro/features/monthly_plans/data/monthly_plans_repository.dart';
import 'package:doceria_pro/features/monthly_plans/domain/monthly_plan.dart';
import 'package:doceria_pro/features/orders/data/orders_repository.dart';
import 'package:doceria_pro/features/orders/domain/order.dart';
import 'package:doceria_pro/features/orders/domain/order_fulfillment_method.dart';
import 'package:doceria_pro/features/orders/domain/order_status.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

void main() {
  late AppDatabase database;
  late MonthlyPlansRepository monthlyPlansRepository;
  late OrdersRepository ordersRepository;
  late MonthlyPlanGenerationService generationService;

  setUpAll(() async {
    await initializeDateFormatting('pt_BR');
  });

  setUp(() {
    database = AppDatabase(NativeDatabase.memory());
    monthlyPlansRepository = MonthlyPlansRepository(database);
    ordersRepository = OrdersRepository(database);
    generationService = MonthlyPlanGenerationService(
      monthlyPlansRepository: monthlyPlansRepository,
      ordersRepository: ordersRepository,
    );
  });

  tearDown(() async {
    await database.close();
  });

  test('generates future order drafts and tracks remaining balance', () async {
    final monthlyPlanId = await monthlyPlansRepository.saveMonthlyPlan(
      MonthlyPlanUpsertInput(
        clientId: 'client-002',
        clientNameSnapshot: 'Laura',
        title: 'Mesversário da Laura',
        templateProductId: 'product-plan-002',
        templateProductNameSnapshot: 'Plano delicado',
        startDate: DateTime(2026, 2, 10),
        numberOfMonths: 4,
        contractedQuantity: 2,
        notes: 'Confirmar cor da vela na semana anterior.',
        items: [
          MonthlyPlanItemInput(
            linkedProductId: 'product-bento',
            itemNameSnapshot: 'Bento cake',
            flavorSnapshot: 'Ninho com morango',
            variationSnapshot: '12 cm',
            unitPrice: Money.fromCents(4500),
            quantity: 2,
            notes: 'Frase curta no topo',
          ),
        ],
      ),
    );

    final generationResult = await generationService.generateFutureOrderDrafts(
      monthlyPlanId: monthlyPlanId,
      referenceDate: DateTime(2026, 2, 1),
      maxDrafts: 2,
    );

    expect(generationResult.orderIds, hasLength(2));

    final orders = await ordersRepository.watchOrders().first;
    expect(orders, hasLength(2));
    expect(orders.first.eventDate, DateTime(2026, 2, 10));
    expect(orders.last.eventDate, DateTime(2026, 3, 10));
    expect(orders.first.orderTotal.cents, 9000);
    expect(orders.first.isDraft, isTrue);
    expect(
      orders.first.notes,
      contains('Gerado automaticamente a partir do mesversário'),
    );

    final generatedPlan = await monthlyPlansRepository.getMonthlyPlan(
      monthlyPlanId,
    );
    expect(generatedPlan, isNotNull);
    expect(generatedPlan!.generatedOccurrenceCount, 2);
    expect(generatedPlan.availableToGenerateCount, 0);
    expect(generatedPlan.remainingBalance, 2);
    expect(
      generatedPlan.sortedHistory.where(
        (occurrence) => occurrence.generatedOrderId != null,
      ),
      hasLength(2),
    );

    final firstGeneratedOrder = orders.first;
    await ordersRepository.saveOrder(
      OrderUpsertInput(
        id: firstGeneratedOrder.id,
        clientId: firstGeneratedOrder.clientId,
        clientNameSnapshot: firstGeneratedOrder.clientNameSnapshot,
        eventDate: firstGeneratedOrder.eventDate,
        fulfillmentMethod: OrderFulfillmentMethod.pickup,
        deliveryFee: Money.zero,
        notes: firstGeneratedOrder.notes,
        orderTotal: firstGeneratedOrder.orderTotal,
        depositAmount: firstGeneratedOrder.depositAmount,
        status: OrderStatus.delivered,
        items: [
          for (final item in firstGeneratedOrder.items)
            OrderItemInput(
              id: item.id,
              productId: item.productId,
              itemNameSnapshot: item.itemNameSnapshot,
              flavorSnapshot: item.flavorSnapshot,
              variationSnapshot: item.variationSnapshot,
              price: item.price,
              quantity: item.quantity,
              notes: item.notes,
            ),
        ],
      ),
    );

    final deliveredPlan = await monthlyPlansRepository.getMonthlyPlan(
      monthlyPlanId,
    );
    expect(deliveredPlan, isNotNull);
    expect(deliveredPlan!.remainingBalance, 1);
    expect(deliveredPlan.sortedHistory.first.displayStatusLabel, 'Entregue');
  });
}
