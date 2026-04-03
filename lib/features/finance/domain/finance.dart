import '../../../core/formatters/app_formatters.dart';
import '../../../core/money/money.dart';
import '../../orders/domain/order.dart';
import '../../orders/domain/order_status.dart';
import '../../purchases/domain/purchase.dart';

enum FinanceView {
  overview(label: 'Visão geral'),
  receivables(label: 'Recebimentos'),
  expenses(label: 'Saídas'),
  manualEntries(label: 'Lançamentos');

  const FinanceView({required this.label});

  final String label;
}

enum FinancePeriodFilter {
  daily(label: 'Hoje'),
  weekly(label: 'Semana'),
  monthly(label: 'Mês');

  const FinancePeriodFilter({required this.label});

  final String label;
}

enum FinanceManualEntryType {
  income(databaseValue: 'income', label: 'Entrada manual'),
  expense(databaseValue: 'expense', label: 'Saída manual');

  const FinanceManualEntryType({
    required this.databaseValue,
    required this.label,
  });

  final String databaseValue;
  final String label;

  static FinanceManualEntryType fromDatabase(String value) {
    return values.firstWhere(
      (type) => type.databaseValue == value,
      orElse: () => FinanceManualEntryType.expense,
    );
  }
}

class FinanceDateWindow {
  const FinanceDateWindow({
    required this.start,
    required this.endExclusive,
    required this.label,
  });

  final DateTime start;
  final DateTime endExclusive;
  final String label;

  bool contains(DateTime value) {
    final normalized = DateTime(value.year, value.month, value.day);
    return !normalized.isBefore(start) && normalized.isBefore(endExclusive);
  }
}

class FinanceReceivableRecord {
  const FinanceReceivableRecord({
    required this.id,
    required this.orderId,
    required this.clientNameSnapshot,
    required this.orderStatus,
    required this.orderDate,
    required this.description,
    required this.amount,
    required this.dueDate,
    required this.status,
    required this.createdAt,
    required this.receivedAt,
  });

  final String id;
  final String orderId;
  final String? clientNameSnapshot;
  final OrderStatus orderStatus;
  final DateTime? orderDate;
  final String description;
  final Money amount;
  final DateTime? dueDate;
  final OrderReceivableStatus status;
  final DateTime createdAt;
  final DateTime? receivedAt;

  bool get isPending => status == OrderReceivableStatus.pending;

  bool get isReceived => status == OrderReceivableStatus.received;

  String get displayClientName {
    final trimmedName = clientNameSnapshot?.trim();
    if (trimmedName == null || trimmedName.isEmpty) {
      return 'Cliente não definida';
    }

    return trimmedName;
  }

  DateTime get referenceDate => receivedAt ?? dueDate ?? orderDate ?? createdAt;

  String get displayReferenceDateLabel {
    if (isReceived) {
      final date = receivedAt ?? createdAt;
      return 'Recebido em ${AppFormatters.dayMonthYear(date)}';
    }

    if (dueDate != null) {
      return 'Previsto para ${AppFormatters.dayMonthYear(dueDate!)}';
    }

    return 'Registrado em ${AppFormatters.dayMonthYear(createdAt)}';
  }
}

class FinanceExpenseRecord {
  const FinanceExpenseRecord({
    required this.id,
    required this.purchaseEntryId,
    required this.description,
    required this.supplierId,
    required this.supplierNameSnapshot,
    required this.amount,
    required this.status,
    required this.createdAt,
    required this.paidAt,
  });

  final String id;
  final String? purchaseEntryId;
  final String description;
  final String? supplierId;
  final String? supplierNameSnapshot;
  final Money amount;
  final PurchaseExpenseDraftStatus status;
  final DateTime createdAt;
  final DateTime? paidAt;

  bool get isPrepared => status == PurchaseExpenseDraftStatus.prepared;

  bool get isPaid => status == PurchaseExpenseDraftStatus.paid;

  DateTime get referenceDate => paidAt ?? createdAt;

  String get displaySupplierName {
    final trimmedName = supplierNameSnapshot?.trim();
    if (trimmedName == null || trimmedName.isEmpty) {
      return 'Sem fornecedora definida';
    }

    return trimmedName;
  }

  String get displayReferenceDateLabel {
    if (isPaid) {
      final date = paidAt ?? createdAt;
      return 'Pago em ${AppFormatters.dayMonthYear(date)}';
    }

    return 'Preparado em ${AppFormatters.dayMonthYear(createdAt)}';
  }
}

class FinanceManualEntryRecord {
  const FinanceManualEntryRecord({
    required this.id,
    required this.entryType,
    required this.description,
    required this.amount,
    required this.entryDate,
    required this.category,
    required this.notes,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final FinanceManualEntryType entryType;
  final String description;
  final Money amount;
  final DateTime entryDate;
  final String? category;
  final String? notes;
  final DateTime createdAt;
  final DateTime updatedAt;

  bool get isIncome => entryType == FinanceManualEntryType.income;

  bool get isExpense => entryType == FinanceManualEntryType.expense;

  String get displayCategory {
    final trimmedCategory = category?.trim();
    if (trimmedCategory == null || trimmedCategory.isEmpty) {
      return 'Sem categoria';
    }

    return trimmedCategory;
  }

  String get displayNotes {
    final trimmedNotes = notes?.trim();
    if (trimmedNotes == null || trimmedNotes.isEmpty) {
      return 'Sem observações';
    }

    return trimmedNotes;
  }
}

class FinanceManualEntryInput {
  const FinanceManualEntryInput({
    this.id,
    required this.entryType,
    required this.description,
    required this.amount,
    required this.entryDate,
    required this.category,
    required this.notes,
  });

  final String? id;
  final FinanceManualEntryType entryType;
  final String description;
  final Money amount;
  final DateTime entryDate;
  final String? category;
  final String? notes;
}

class FinanceOverviewMetrics {
  const FinanceOverviewMetrics({
    required this.periodLabel,
    required this.cashIn,
    required this.cashOut,
    required this.pendingReceivables,
    required this.estimatedProfit,
    required this.actualProfit,
    required this.pendingReceivablesCount,
    required this.preparedExpensesCount,
    required this.preparedExpensesAmount,
    required this.manualEntriesCount,
  });

  final String periodLabel;
  final Money cashIn;
  final Money cashOut;
  final Money pendingReceivables;
  final Money estimatedProfit;
  final Money actualProfit;
  final int pendingReceivablesCount;
  final int preparedExpensesCount;
  final Money preparedExpensesAmount;
  final int manualEntriesCount;

  bool get hasBreakEvenData => cashIn.isPositive || cashOut.isPositive;

  bool get isBreakEvenCovered => cashIn.cents >= cashOut.cents;

  Money get breakEvenGap => isBreakEvenCovered ? Money.zero : cashOut - cashIn;

  String get breakEvenTitle {
    if (!hasBreakEvenData) {
      return 'Ponto de equilíbrio em preparo';
    }
    if (isBreakEvenCovered) {
      return 'Período acima do equilíbrio';
    }

    return 'Faltam ${breakEvenGap.format()} para empatar';
  }

  String get breakEvenMessage {
    if (!hasBreakEvenData) {
      return 'Assim que entrar dinheiro ou sair algum gasto real, o indicador aparece aqui.';
    }
    if (isBreakEvenCovered) {
      final surplus = cashIn - cashOut;
      return 'As entradas reais já cobrem as saídas do período. Sobra ${surplus.format()} até agora.';
    }

    return 'As saídas reais ainda estão acima das entradas do período filtrado.';
  }
}

FinanceDateWindow resolveFinanceDateWindow(
  FinancePeriodFilter filter, {
  DateTime? now,
}) {
  final base = now ?? DateTime.now();
  final today = DateTime(base.year, base.month, base.day);

  switch (filter) {
    case FinancePeriodFilter.daily:
      return FinanceDateWindow(
        start: today,
        endExclusive: today.add(const Duration(days: 1)),
        label: 'Hoje',
      );
    case FinancePeriodFilter.weekly:
      final weekStart = today.subtract(Duration(days: today.weekday - 1));
      return FinanceDateWindow(
        start: weekStart,
        endExclusive: weekStart.add(const Duration(days: 7)),
        label: 'Esta semana',
      );
    case FinancePeriodFilter.monthly:
      final monthStart = DateTime(today.year, today.month);
      final nextMonthStart = today.month == 12
          ? DateTime(today.year + 1, 1)
          : DateTime(today.year, today.month + 1);
      return FinanceDateWindow(
        start: monthStart,
        endExclusive: nextMonthStart,
        label: 'Este mês',
      );
  }
}

List<FinanceReceivableRecord> filterReceivablesByPeriod(
  List<FinanceReceivableRecord> receivables,
  FinancePeriodFilter filter, {
  DateTime? now,
}) {
  final window = resolveFinanceDateWindow(filter, now: now);
  final filtered = receivables
      .where((receivable) {
        if (receivable.isPending) {
          return _normalizeDate(
            receivable.referenceDate,
          ).isBefore(window.endExclusive);
        }

        return window.contains(receivable.referenceDate);
      })
      .toList(growable: false);

  filtered.sort((left, right) {
    if (left.isPending != right.isPending) {
      return left.isPending ? -1 : 1;
    }
    if (left.isPending) {
      return left.referenceDate.compareTo(right.referenceDate);
    }

    return right.referenceDate.compareTo(left.referenceDate);
  });

  return filtered;
}

List<FinanceExpenseRecord> filterExpensesByPeriod(
  List<FinanceExpenseRecord> expenses,
  FinancePeriodFilter filter, {
  DateTime? now,
}) {
  final window = resolveFinanceDateWindow(filter, now: now);
  final filtered = expenses
      .where((expense) {
        if (expense.isPrepared) {
          return _normalizeDate(
            expense.createdAt,
          ).isBefore(window.endExclusive);
        }

        return window.contains(expense.referenceDate);
      })
      .toList(growable: false);

  filtered.sort((left, right) {
    if (left.isPrepared != right.isPrepared) {
      return left.isPrepared ? -1 : 1;
    }
    if (left.isPrepared) {
      return left.createdAt.compareTo(right.createdAt);
    }

    return right.referenceDate.compareTo(left.referenceDate);
  });

  return filtered;
}

List<FinanceManualEntryRecord> filterManualEntriesByPeriod(
  List<FinanceManualEntryRecord> entries,
  FinancePeriodFilter filter, {
  DateTime? now,
}) {
  final window = resolveFinanceDateWindow(filter, now: now);
  final filtered = entries
      .where((entry) => window.contains(entry.entryDate))
      .toList(growable: false);
  filtered.sort((left, right) => right.entryDate.compareTo(left.entryDate));
  return filtered;
}

FinanceOverviewMetrics buildFinanceOverview({
  required FinancePeriodFilter filter,
  required List<OrderRecord> orders,
  required List<FinanceReceivableRecord> receivables,
  required List<FinanceExpenseRecord> expenses,
  required List<FinanceManualEntryRecord> manualEntries,
  DateTime? now,
}) {
  final window = resolveFinanceDateWindow(filter, now: now);
  final visibleReceivables = filterReceivablesByPeriod(
    receivables,
    filter,
    now: now,
  );
  final visibleExpenses = filterExpensesByPeriod(expenses, filter, now: now);
  final visibleManualEntries = filterManualEntriesByPeriod(
    manualEntries,
    filter,
    now: now,
  );

  var cashIn = Money.zero;
  var cashOut = Money.zero;
  var pendingReceivables = Money.zero;
  var preparedExpensesAmount = Money.zero;

  for (final receivable in visibleReceivables) {
    if (receivable.isReceived) {
      cashIn += receivable.amount;
    } else {
      pendingReceivables += receivable.amount;
    }
  }

  for (final expense in visibleExpenses) {
    if (expense.isPaid) {
      cashOut += expense.amount;
    } else {
      preparedExpensesAmount += expense.amount;
    }
  }

  for (final entry in visibleManualEntries) {
    if (entry.isIncome) {
      cashIn += entry.amount;
    } else {
      cashOut += entry.amount;
    }
  }

  final estimatedProfit = orders
      .where(_isOrderRelevantForEstimatedProfit)
      .where((order) => window.contains(order.eventDate ?? order.createdAt))
      .fold<Money>(Money.zero, (total, order) => total + order.predictedProfit);

  return FinanceOverviewMetrics(
    periodLabel: window.label,
    cashIn: cashIn,
    cashOut: cashOut,
    pendingReceivables: pendingReceivables,
    estimatedProfit: estimatedProfit,
    actualProfit: cashIn - cashOut,
    pendingReceivablesCount: visibleReceivables
        .where((entry) => entry.isPending)
        .length,
    preparedExpensesCount: visibleExpenses
        .where((entry) => entry.isPrepared)
        .length,
    preparedExpensesAmount: preparedExpensesAmount,
    manualEntriesCount: visibleManualEntries.length,
  );
}

bool _isOrderRelevantForEstimatedProfit(OrderRecord order) {
  switch (order.status) {
    case OrderStatus.budget:
      return false;
    case OrderStatus.awaitingDeposit:
    case OrderStatus.confirmed:
    case OrderStatus.inProduction:
    case OrderStatus.ready:
    case OrderStatus.delivered:
      return true;
  }
}

DateTime _normalizeDate(DateTime value) {
  return DateTime(value.year, value.month, value.day);
}
