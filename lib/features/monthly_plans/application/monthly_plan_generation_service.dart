import '../../../core/money/money.dart';
import '../../orders/data/orders_repository.dart';
import '../../orders/domain/order.dart';
import '../../orders/domain/order_status.dart';
import '../data/monthly_plans_repository.dart';
import '../domain/monthly_plan.dart';

class MonthlyPlanGenerationResult {
  const MonthlyPlanGenerationResult({
    required this.orderIds,
    required this.occurrenceIds,
  });

  final List<String> orderIds;
  final List<String> occurrenceIds;

  bool get hasGeneratedOrders => orderIds.isNotEmpty;
}

class MonthlyPlanGenerationService {
  const MonthlyPlanGenerationService({
    required MonthlyPlansRepository monthlyPlansRepository,
    required OrdersRepository ordersRepository,
  }) : _monthlyPlansRepository = monthlyPlansRepository,
       _ordersRepository = ordersRepository;

  final MonthlyPlansRepository _monthlyPlansRepository;
  final OrdersRepository _ordersRepository;

  Future<MonthlyPlanGenerationResult> generateFutureOrderDrafts({
    required String monthlyPlanId,
    DateTime? referenceDate,
    int maxDrafts = 1,
  }) async {
    final monthlyPlan = await _monthlyPlansRepository.getMonthlyPlan(
      monthlyPlanId,
    );
    if (monthlyPlan == null) {
      throw StateError('Monthly plan not found.');
    }

    final normalizedMaxDrafts = maxDrafts <= 0 ? 1 : maxDrafts;
    final futureImpact = buildMonthlyPlanFutureImpact(
      monthlyPlan,
      referenceDate: referenceDate,
      maxEntries: monthlyPlan.numberOfMonths,
    );
    final draftEntries = futureImpact.entries
        .where((entry) => entry.canGenerateDraft)
        .take(normalizedMaxDrafts)
        .toList(growable: false);

    if (draftEntries.isEmpty) {
      return const MonthlyPlanGenerationResult(orderIds: [], occurrenceIds: []);
    }

    final orderIds = <String>[];
    final occurrenceIds = <String>[];

    for (final entry in draftEntries) {
      final orderId = await _ordersRepository.saveOrder(
        _buildDraftOrderInput(monthlyPlan, entry.occurrence),
      );
      await _monthlyPlansRepository.markOccurrenceAsGenerated(
        occurrenceId: entry.occurrence.id,
        generatedOrderId: orderId,
      );
      orderIds.add(orderId);
      occurrenceIds.add(entry.occurrence.id);
    }

    return MonthlyPlanGenerationResult(
      orderIds: orderIds,
      occurrenceIds: occurrenceIds,
    );
  }

  OrderUpsertInput _buildDraftOrderInput(
    MonthlyPlanRecord monthlyPlan,
    MonthlyPlanOccurrenceRecord occurrence,
  ) {
    final noteLines = [
      'Gerado automaticamente a partir do mesversário "${monthlyPlan.title}".',
      'Referência do ciclo: ${occurrence.displayMonthLabel}.',
      if (monthlyPlan.notes?.trim().isNotEmpty ?? false)
        'Observações do plano: ${monthlyPlan.notes!.trim()}',
    ];

    return OrderUpsertInput(
      clientId: monthlyPlan.clientId,
      clientNameSnapshot: monthlyPlan.clientNameSnapshot,
      eventDate: occurrence.scheduledDate,
      fulfillmentMethod: null,
      deliveryFee: Money.zero,
      notes: noteLines.join('\n'),
      orderTotal: monthlyPlan.estimatedMonthlyTotal,
      depositAmount: Money.zero,
      status: OrderStatus.budget,
      items: [
        for (final item in monthlyPlan.items)
          OrderItemInput(
            productId: item.linkedProductId,
            itemNameSnapshot: item.itemNameSnapshot,
            flavorSnapshot: item.flavorSnapshot,
            variationSnapshot: item.variationSnapshot,
            price: item.unitPrice,
            quantity: item.quantity,
            notes: item.notes,
          ),
      ],
    );
  }
}
