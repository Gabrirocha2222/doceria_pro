import '../../../core/formatters/app_formatters.dart';
import '../../../core/money/money.dart';
import '../../finance/domain/finance.dart';
import '../../ingredients/domain/ingredient.dart';
import '../../orders/domain/order.dart';
import '../../orders/domain/order_status.dart';
import '../../production/domain/production_task.dart';
import '../../purchases/domain/purchase.dart';

enum DashboardDestination {
  orders,
  newOrder,
  production,
  purchases,
  finance,
  stock,
}

enum DashboardAlertPriority {
  high(label: 'Alta'),
  medium(label: 'Média'),
  low(label: 'Baixa');

  const DashboardAlertPriority({required this.label});

  final String label;
}

class DashboardSummaryCardData {
  const DashboardSummaryCardData({
    required this.title,
    required this.value,
    required this.caption,
    required this.destination,
  });

  final String title;
  final String value;
  final String caption;
  final DashboardDestination destination;
}

class DashboardActionItem {
  const DashboardActionItem({
    required this.title,
    required this.subtitle,
    required this.valueLabel,
    required this.destination,
  });

  final String title;
  final String subtitle;
  final String valueLabel;
  final DashboardDestination destination;
}

class DashboardAgendaEntry {
  const DashboardAgendaEntry({
    required this.label,
    required this.subtitle,
    required this.orderCount,
    required this.totalAmount,
    required this.destination,
  });

  final String label;
  final String subtitle;
  final int orderCount;
  final Money totalAmount;
  final DashboardDestination destination;
}

class DashboardAlertItem {
  const DashboardAlertItem({
    required this.priority,
    required this.title,
    required this.message,
    required this.destination,
  });

  final DashboardAlertPriority priority;
  final String title;
  final String message;
  final DashboardDestination destination;
}

class DashboardFinanceSummary {
  const DashboardFinanceSummary({
    required this.cashInToday,
    required this.cashOutToday,
    required this.pendingReceivables,
    required this.preparedExpenses,
    required this.netToday,
  });

  final Money cashInToday;
  final Money cashOutToday;
  final Money pendingReceivables;
  final Money preparedExpenses;
  final Money netToday;

  String get note {
    if (cashInToday.isZero && cashOutToday.isZero) {
      return 'Ainda sem movimento financeiro real hoje.';
    }
    if (netToday.isPositive) {
      return 'Hoje o caixa real está positivo em ${netToday.format()}.';
    }
    if (netToday.isZero) {
      return 'Hoje o caixa está empatado até agora.';
    }

    return 'Hoje o caixa real está negativo em ${Money.fromCents(netToday.cents.abs()).format()}.';
  }
}

class DashboardSnapshot {
  const DashboardSnapshot({
    required this.greetingTitle,
    required this.greetingSubtitle,
    required this.attentionSummary,
    required this.summaryCards,
    required this.actions,
    required this.weekAgenda,
    required this.alerts,
    required this.financeSummary,
  });

  final String greetingTitle;
  final String greetingSubtitle;
  final String attentionSummary;
  final List<DashboardSummaryCardData> summaryCards;
  final List<DashboardActionItem> actions;
  final List<DashboardAgendaEntry> weekAgenda;
  final List<DashboardAlertItem> alerts;
  final DashboardFinanceSummary financeSummary;
}

DashboardSnapshot buildDashboardSnapshot({
  required List<OrderRecord> orders,
  required List<ProductionTaskRecord> productionTasks,
  required List<PurchaseChecklistItemRecord> purchaseItems,
  required List<FinanceReceivableRecord> receivables,
  required List<FinanceExpenseRecord> expenses,
  required List<FinanceManualEntryRecord> manualEntries,
  required List<IngredientRecord> lowStockIngredients,
  DateTime? now,
}) {
  final baseDate = now ?? DateTime.now();
  final today = _normalizeDate(baseDate);
  final tomorrow = today.add(const Duration(days: 1));
  final endOfWeekExclusive = today.add(const Duration(days: 7));

  final weekOrders = orders
      .where(_isOperationalOrder)
      .where(
        (order) =>
            order.eventDate != null &&
            !_normalizeDate(order.eventDate!).isBefore(today) &&
            _normalizeDate(order.eventDate!).isBefore(endOfWeekExclusive),
      )
      .toList(growable: false);
  final todayOrders = weekOrders
      .where((order) => _normalizeDate(order.eventDate!) == today)
      .toList(growable: false);
  final awaitingDepositOrders = orders
      .where((order) => order.status == OrderStatus.awaitingDeposit)
      .where(
        (order) =>
            order.eventDate == null ||
            _normalizeDate(order.eventDate!).isBefore(endOfWeekExclusive),
      )
      .toList(growable: false);

  final openTodayProduction = productionTasks
      .where((task) => !task.plan.isCompleted)
      .where((task) => task.deadline != null)
      .where((task) => !_normalizeDate(task.deadline!).isAfter(today))
      .toList(growable: false);
  final overdueProduction = openTodayProduction
      .where((task) => _normalizeDate(task.deadline!).isBefore(today))
      .toList(growable: false);

  final urgentPurchaseItems = purchaseItems
      .where((item) => item.buyNowShortageQuantity > 0)
      .toList(growable: false);
  final urgentPurchaseItemsDueNow = urgentPurchaseItems
      .where((item) {
        final deadline = item.nearestDeadline;
        if (deadline == null) {
          return true;
        }

        return !_normalizeDate(deadline).isAfter(today);
      })
      .toList(growable: false);

  final pendingReceivables = receivables
      .where((entry) => entry.isPending)
      .where((entry) => !_normalizeDate(entry.referenceDate).isAfter(today))
      .toList(growable: false);
  final pendingReceivablesThisWeek = receivables
      .where((entry) => entry.isPending)
      .where(
        (entry) => !_normalizeDate(
          entry.referenceDate,
        ).isAfter(endOfWeekExclusive.subtract(const Duration(days: 1))),
      )
      .toList(growable: false);

  final weeklyPredictedProfit = weekOrders.fold<Money>(
    Money.zero,
    (total, order) => total + order.predictedProfit,
  );
  final weeklyAmountToReceive = pendingReceivablesThisWeek.fold<Money>(
    Money.zero,
    (total, entry) => total + entry.amount,
  );

  final cashInToday = receivables
      .where(
        (entry) =>
            entry.isReceived && _normalizeDate(entry.referenceDate) == today,
      )
      .fold<Money>(Money.zero, (total, entry) => total + entry.amount);
  final cashOutToday = expenses
      .where(
        (entry) => entry.isPaid && _normalizeDate(entry.referenceDate) == today,
      )
      .fold<Money>(Money.zero, (total, entry) => total + entry.amount);
  final preparedExpenses = expenses
      .where((entry) => entry.isPrepared)
      .fold<Money>(Money.zero, (total, entry) => total + entry.amount);
  final manualIncomeToday = manualEntries
      .where(
        (entry) => entry.isIncome && _normalizeDate(entry.entryDate) == today,
      )
      .fold<Money>(Money.zero, (total, entry) => total + entry.amount);
  final manualExpenseToday = manualEntries
      .where(
        (entry) => entry.isExpense && _normalizeDate(entry.entryDate) == today,
      )
      .fold<Money>(Money.zero, (total, entry) => total + entry.amount);

  final financeSummary = DashboardFinanceSummary(
    cashInToday: cashInToday + manualIncomeToday,
    cashOutToday: cashOutToday + manualExpenseToday,
    pendingReceivables: weeklyAmountToReceive,
    preparedExpenses: preparedExpenses,
    netToday:
        (cashInToday + manualIncomeToday) - (cashOutToday + manualExpenseToday),
  );

  final attentionSummary = _buildAttentionSummary(
    productionCount: openTodayProduction.length,
    deliveryCount: todayOrders.length,
    pendingDepositCount: awaitingDepositOrders.length,
    urgentPurchasesCount: urgentPurchaseItems.length,
  );

  return DashboardSnapshot(
    greetingTitle: _buildGreetingTitle(baseDate),
    greetingSubtitle:
        'Você abre o dia com um resumo das próximas entregas, do caixa e do que pode travar a operação.',
    attentionSummary: attentionSummary,
    summaryCards: [
      DashboardSummaryCardData(
        title: 'Pedidos da semana',
        value: weekOrders.length.toString(),
        caption: weekOrders.isEmpty
            ? 'Nenhum pedido operacional nos próximos 7 dias.'
            : '${weekOrders.length} ${weekOrders.length == 1 ? 'pedido programado' : 'pedidos programados'} até ${AppFormatters.shortDate(endOfWeekExclusive.subtract(const Duration(days: 1)))}.',
        destination: DashboardDestination.orders,
      ),
      DashboardSummaryCardData(
        title: 'Lucro previsto',
        value: weeklyPredictedProfit.format(),
        caption: weekOrders.isEmpty
            ? 'O lucro previsto aparece quando a semana tem pedidos operacionais.'
            : 'Previsão somada dos pedidos ativos dos próximos dias.',
        destination: DashboardDestination.finance,
      ),
      DashboardSummaryCardData(
        title: 'Falta receber',
        value: weeklyAmountToReceive.format(),
        caption: pendingReceivablesThisWeek.isEmpty
            ? 'Nenhum valor pendente até o fim da semana.'
            : '${pendingReceivablesThisWeek.length} ${pendingReceivablesThisWeek.length == 1 ? 'cobrança pendente' : 'cobranças pendentes'} até o fim da semana.',
        destination: DashboardDestination.finance,
      ),
      DashboardSummaryCardData(
        title: 'Materiais baixos',
        value: lowStockIngredients.length.toString(),
        caption: urgentPurchaseItems.isEmpty
            ? 'Sem compra urgente aberta agora.'
            : '${urgentPurchaseItems.length} ${urgentPurchaseItems.length == 1 ? 'item pede compra agora' : 'itens pedem compra agora'}.',
        destination: DashboardDestination.stock,
      ),
    ],
    actions: [
      DashboardActionItem(
        title: 'Produção de hoje',
        subtitle: openTodayProduction.isEmpty
            ? 'Sem tarefa vencida ou para hoje no painel de produção.'
            : overdueProduction.isEmpty
            ? 'Tudo que vence hoje está concentrado no fluxo de produção.'
            : '${overdueProduction.length} ${overdueProduction.length == 1 ? 'tarefa já passou do prazo' : 'tarefas já passaram do prazo'}.',
        valueLabel:
            '${openTodayProduction.length} ${openTodayProduction.length == 1 ? 'tarefa' : 'tarefas'}',
        destination: DashboardDestination.production,
      ),
      DashboardActionItem(
        title: 'Entregas e retiradas',
        subtitle: todayOrders.isEmpty
            ? 'Nenhum pedido programado para hoje.'
            : '${todayOrders.length} ${todayOrders.length == 1 ? 'pedido precisa ser acompanhado hoje' : 'pedidos precisam ser acompanhados hoje'}.',
        valueLabel:
            '${todayOrders.length} ${todayOrders.length == 1 ? 'pedido' : 'pedidos'}',
        destination: DashboardDestination.orders,
      ),
      DashboardActionItem(
        title: 'Sinais pendentes',
        subtitle: awaitingDepositOrders.isEmpty
            ? 'Nenhum pedido aguardando sinal nesta janela.'
            : 'Vale cobrar antes de confirmar a produção e a entrega.',
        valueLabel:
            '${awaitingDepositOrders.length} ${awaitingDepositOrders.length == 1 ? 'pedido' : 'pedidos'}',
        destination: DashboardDestination.finance,
      ),
      DashboardActionItem(
        title: 'Itens para comprar',
        subtitle: urgentPurchaseItems.isEmpty
            ? 'Sem compra urgente aberta agora.'
            : 'A checklist já mostra só o que realmente está faltando.',
        valueLabel:
            '${urgentPurchaseItems.length} ${urgentPurchaseItems.length == 1 ? 'item' : 'itens'}',
        destination: DashboardDestination.purchases,
      ),
    ],
    weekAgenda: _buildWeekAgenda(
      weekOrders: weekOrders,
      today: today,
      tomorrow: tomorrow,
    ),
    alerts: _buildAlerts(
      overdueProductionCount: overdueProduction.length,
      todayOrdersAtRiskCount: todayOrders
          .where((order) => order.status != OrderStatus.ready)
          .length,
      pendingDepositCount: awaitingDepositOrders.length,
      urgentPurchaseCount: urgentPurchaseItems.length,
      urgentPurchaseDueNowCount: urgentPurchaseItemsDueNow.length,
      lowStockCount: lowStockIngredients.length,
      overdueReceivableCount: pendingReceivables.length,
    ),
    financeSummary: financeSummary,
  );
}

List<DashboardAgendaEntry> _buildWeekAgenda({
  required List<OrderRecord> weekOrders,
  required DateTime today,
  required DateTime tomorrow,
}) {
  final groupedOrders = <DateTime, List<OrderRecord>>{};

  for (final order in weekOrders) {
    final date = _normalizeDate(order.eventDate!);
    groupedOrders.putIfAbsent(date, () => []).add(order);
  }

  final orderedDates = groupedOrders.keys.toList(growable: false)
    ..sort((left, right) => left.compareTo(right));

  return orderedDates
      .map((date) {
        final orders = groupedOrders[date] ?? const <OrderRecord>[];
        final totalAmount = orders.fold<Money>(
          Money.zero,
          (total, order) => total + order.orderTotal,
        );
        final highlightedClients = orders
            .take(3)
            .map((order) => order.displayClientName)
            .join(' • ');
        final remainingCount = orders.length - 3;
        final subtitle = remainingCount > 0
            ? '$highlightedClients • +$remainingCount'
            : highlightedClients;

        return DashboardAgendaEntry(
          label: _buildAgendaDateLabel(date, today: today, tomorrow: tomorrow),
          subtitle: subtitle,
          orderCount: orders.length,
          totalAmount: totalAmount,
          destination: DashboardDestination.orders,
        );
      })
      .toList(growable: false);
}

List<DashboardAlertItem> _buildAlerts({
  required int overdueProductionCount,
  required int todayOrdersAtRiskCount,
  required int pendingDepositCount,
  required int urgentPurchaseCount,
  required int urgentPurchaseDueNowCount,
  required int lowStockCount,
  required int overdueReceivableCount,
}) {
  final alerts = <DashboardAlertItem>[
    if (overdueProductionCount > 0)
      DashboardAlertItem(
        priority: DashboardAlertPriority.high,
        title: 'Produção atrasada',
        message:
            '$overdueProductionCount ${overdueProductionCount == 1 ? 'tarefa já passou do prazo' : 'tarefas já passaram do prazo'} e pedem revisão agora.',
        destination: DashboardDestination.production,
      ),
    if (todayOrdersAtRiskCount > 0)
      DashboardAlertItem(
        priority: DashboardAlertPriority.high,
        title: 'Pedido de hoje ainda não está pronto',
        message:
            '$todayOrdersAtRiskCount ${todayOrdersAtRiskCount == 1 ? 'pedido de hoje segue fora do ponto ideal' : 'pedidos de hoje seguem fora do ponto ideal'} para entrega ou retirada.',
        destination: DashboardDestination.orders,
      ),
    if (urgentPurchaseDueNowCount > 0)
      DashboardAlertItem(
        priority: DashboardAlertPriority.high,
        title: 'Compra urgente para hoje',
        message:
            '$urgentPurchaseDueNowCount ${urgentPurchaseDueNowCount == 1 ? 'item já ameaça o dia de hoje' : 'itens já ameaçam o dia de hoje'} na checklist de compras.',
        destination: DashboardDestination.purchases,
      ),
    if (pendingDepositCount > 0)
      DashboardAlertItem(
        priority: DashboardAlertPriority.medium,
        title: 'Pedidos aguardando sinal',
        message:
            '$pendingDepositCount ${pendingDepositCount == 1 ? 'pedido ainda depende de sinal' : 'pedidos ainda dependem de sinal'} para seguir com mais segurança.',
        destination: DashboardDestination.finance,
      ),
    if (overdueReceivableCount > 0)
      DashboardAlertItem(
        priority: DashboardAlertPriority.medium,
        title: 'Cobrança pendente',
        message:
            '$overdueReceivableCount ${overdueReceivableCount == 1 ? 'valor já pode ser cobrado' : 'valores já podem ser cobrados'} no financeiro.',
        destination: DashboardDestination.finance,
      ),
    if (urgentPurchaseCount > 0 && urgentPurchaseDueNowCount == 0)
      DashboardAlertItem(
        priority: DashboardAlertPriority.medium,
        title: 'Reposição para os próximos dias',
        message:
            '$urgentPurchaseCount ${urgentPurchaseCount == 1 ? 'item pede compra ainda nesta semana' : 'itens pedem compra ainda nesta semana'}.',
        destination: DashboardDestination.purchases,
      ),
    if (lowStockCount > 0)
      DashboardAlertItem(
        priority: DashboardAlertPriority.low,
        title: 'Estoque mínimo pedindo revisão',
        message:
            '$lowStockCount ${lowStockCount == 1 ? 'ingrediente está no limite' : 'ingredientes estão no limite'} do estoque mínimo.',
        destination: DashboardDestination.stock,
      ),
  ];

  alerts.sort((left, right) {
    final priorityComparison = _priorityWeight(
      left.priority,
    ).compareTo(_priorityWeight(right.priority));
    if (priorityComparison != 0) {
      return priorityComparison;
    }

    return left.title.toLowerCase().compareTo(right.title.toLowerCase());
  });

  return alerts.take(4).toList(growable: false);
}

String _buildGreetingTitle(DateTime now) {
  final hour = now.hour;
  if (hour < 12) {
    return 'Bom dia';
  }
  if (hour < 18) {
    return 'Boa tarde';
  }

  return 'Boa noite';
}

String _buildAttentionSummary({
  required int productionCount,
  required int deliveryCount,
  required int pendingDepositCount,
  required int urgentPurchasesCount,
}) {
  final segments = <String>[
    if (productionCount > 0)
      '$productionCount ${productionCount == 1 ? 'tarefa de produção' : 'tarefas de produção'}',
    if (deliveryCount > 0)
      '$deliveryCount ${deliveryCount == 1 ? 'pedido de hoje' : 'pedidos de hoje'}',
    if (pendingDepositCount > 0)
      '$pendingDepositCount ${pendingDepositCount == 1 ? 'sinal pendente' : 'sinais pendentes'}',
    if (urgentPurchasesCount > 0)
      '$urgentPurchasesCount ${urgentPurchasesCount == 1 ? 'compra urgente' : 'compras urgentes'}',
  ];

  if (segments.isEmpty) {
    return 'Hoje o dia começou leve: sem produção crítica, sem compra urgente e sem pedido travando a operação.';
  }

  final highlights = segments.take(3).join(' • ');
  return 'Sua atenção de hoje está concentrada em $highlights.';
}

String _buildAgendaDateLabel(
  DateTime date, {
  required DateTime today,
  required DateTime tomorrow,
}) {
  if (date == today) {
    return 'Hoje';
  }
  if (date == tomorrow) {
    return 'Amanhã';
  }

  return AppFormatters.weekdayAndDate(date);
}

bool _isOperationalOrder(OrderRecord order) {
  switch (order.status) {
    case OrderStatus.budget:
    case OrderStatus.delivered:
      return false;
    case OrderStatus.awaitingDeposit:
    case OrderStatus.confirmed:
    case OrderStatus.inProduction:
    case OrderStatus.ready:
      return true;
  }
}

DateTime _normalizeDate(DateTime value) {
  return DateTime(value.year, value.month, value.day);
}

int _priorityWeight(DashboardAlertPriority priority) {
  switch (priority) {
    case DashboardAlertPriority.high:
      return 0;
    case DashboardAlertPriority.medium:
      return 1;
    case DashboardAlertPriority.low:
      return 2;
  }
}
