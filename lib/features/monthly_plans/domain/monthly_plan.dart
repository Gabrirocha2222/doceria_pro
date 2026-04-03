import 'dart:math' as math;

import '../../../core/formatters/app_formatters.dart';
import '../../../core/money/money.dart';
import '../../orders/domain/order_status.dart';

enum MonthlyPlanRecurrence {
  monthly(databaseValue: 'monthly', label: 'Mensal');

  const MonthlyPlanRecurrence({
    required this.databaseValue,
    required this.label,
  });

  final String databaseValue;
  final String label;

  static MonthlyPlanRecurrence fromDatabase(String value) {
    return values.firstWhere(
      (recurrence) => recurrence.databaseValue == value,
      orElse: () => MonthlyPlanRecurrence.monthly,
    );
  }
}

enum MonthlyPlanOccurrenceStatus {
  planned(databaseValue: 'planned', label: 'Planejado'),
  draftGenerated(databaseValue: 'draft_generated', label: 'Rascunho gerado'),
  skipped(databaseValue: 'skipped', label: 'Pulada');

  const MonthlyPlanOccurrenceStatus({
    required this.databaseValue,
    required this.label,
  });

  final String databaseValue;
  final String label;

  static MonthlyPlanOccurrenceStatus fromDatabase(String value) {
    return values.firstWhere(
      (status) => status.databaseValue == value,
      orElse: () => MonthlyPlanOccurrenceStatus.planned,
    );
  }
}

class MonthlyPlanItemRecord {
  const MonthlyPlanItemRecord({
    required this.id,
    required this.monthlyPlanId,
    required this.linkedProductId,
    required this.itemNameSnapshot,
    required this.flavorSnapshot,
    required this.variationSnapshot,
    required this.unitPrice,
    required this.quantity,
    required this.notes,
    required this.sortOrder,
  });

  final String id;
  final String monthlyPlanId;
  final String? linkedProductId;
  final String itemNameSnapshot;
  final String? flavorSnapshot;
  final String? variationSnapshot;
  final Money unitPrice;
  final int quantity;
  final String? notes;
  final int sortOrder;

  String get displayName {
    final segments = [
      itemNameSnapshot,
      if (flavorSnapshot?.trim().isNotEmpty ?? false) flavorSnapshot!.trim(),
      if (variationSnapshot?.trim().isNotEmpty ?? false)
        variationSnapshot!.trim(),
    ];

    return segments.join(' • ');
  }

  int get normalizedQuantity => quantity <= 0 ? 1 : quantity;

  Money get lineTotal => unitPrice.multiply(normalizedQuantity);
}

class MonthlyPlanOccurrenceRecord {
  const MonthlyPlanOccurrenceRecord({
    required this.id,
    required this.monthlyPlanId,
    required this.occurrenceIndex,
    required this.scheduledDate,
    required this.status,
    required this.generatedOrderId,
    required this.generatedOrderStatus,
    required this.createdAt,
  });

  final String id;
  final String monthlyPlanId;
  final int occurrenceIndex;
  final DateTime scheduledDate;
  final MonthlyPlanOccurrenceStatus status;
  final String? generatedOrderId;
  final OrderStatus? generatedOrderStatus;
  final DateTime createdAt;

  bool get hasGeneratedOrder {
    final trimmedValue = generatedOrderId?.trim();
    return trimmedValue != null && trimmedValue.isNotEmpty;
  }

  bool get isSkipped => status == MonthlyPlanOccurrenceStatus.skipped;

  bool get isFulfilled => generatedOrderStatus == OrderStatus.delivered;

  bool get isReserved => isSkipped || hasGeneratedOrder;

  String get displayMonthLabel =>
      'Mês ${occurrenceIndex.toString().padLeft(2, '0')} • ${AppFormatters.dayMonthYear(scheduledDate)}';

  String get displayStatusLabel {
    if (isSkipped) {
      return MonthlyPlanOccurrenceStatus.skipped.label;
    }

    switch (generatedOrderStatus) {
      case OrderStatus.budget:
        return 'Rascunho gerado';
      case OrderStatus.awaitingDeposit:
        return 'Aguardando sinal';
      case OrderStatus.confirmed:
        return 'Confirmado';
      case OrderStatus.inProduction:
        return 'Em produção';
      case OrderStatus.ready:
        return 'Pronto';
      case OrderStatus.delivered:
        return 'Entregue';
      case null:
        if (status == MonthlyPlanOccurrenceStatus.draftGenerated ||
            hasGeneratedOrder) {
          return 'Rascunho gerado';
        }
        return MonthlyPlanOccurrenceStatus.planned.label;
    }
  }
}

class MonthlyPlanRecord {
  const MonthlyPlanRecord({
    required this.id,
    required this.clientId,
    required this.clientNameSnapshot,
    required this.title,
    required this.templateProductId,
    required this.templateProductNameSnapshot,
    required this.startDate,
    required this.recurrence,
    required this.numberOfMonths,
    required this.contractedQuantity,
    required this.notes,
    required this.createdAt,
    required this.updatedAt,
    required this.items,
    required this.history,
  });

  final String id;
  final String clientId;
  final String clientNameSnapshot;
  final String title;
  final String? templateProductId;
  final String? templateProductNameSnapshot;
  final DateTime startDate;
  final MonthlyPlanRecurrence recurrence;
  final int numberOfMonths;
  final int contractedQuantity;
  final String? notes;
  final DateTime createdAt;
  final DateTime updatedAt;
  final List<MonthlyPlanItemRecord> items;
  final List<MonthlyPlanOccurrenceRecord> history;

  String get displayTemplateProductName {
    final trimmedValue = templateProductNameSnapshot?.trim();
    if (trimmedValue == null || trimmedValue.isEmpty) {
      return 'Sem modelo base';
    }

    return trimmedValue;
  }

  String get displayNotes {
    final trimmedValue = notes?.trim();
    if (trimmedValue == null || trimmedValue.isEmpty) {
      return 'Sem observações registradas';
    }

    return trimmedValue;
  }

  List<MonthlyPlanOccurrenceRecord> get sortedHistory {
    final items = [...history];
    items.sort((a, b) => a.scheduledDate.compareTo(b.scheduledDate));
    return items;
  }

  Money get estimatedMonthlyTotal {
    var total = Money.zero;
    for (final item in items) {
      total += item.lineTotal;
    }

    return total;
  }

  int get estimatedItemCount {
    var total = 0;
    for (final item in items) {
      total += item.normalizedQuantity;
    }

    return total;
  }

  int get fulfilledOccurrenceCount =>
      history.where((occurrence) => occurrence.isFulfilled).length;

  int get reservedOccurrenceCount =>
      history.where((occurrence) => occurrence.isReserved).length;

  int get generatedOccurrenceCount =>
      history.where((occurrence) => occurrence.hasGeneratedOrder).length;

  int get remainingBalance =>
      math.max(contractedQuantity - fulfilledOccurrenceCount, 0);

  int get availableToGenerateCount =>
      math.max(contractedQuantity - reservedOccurrenceCount, 0);

  bool get isCompleted => remainingBalance == 0 && contractedQuantity > 0;

  String get recurrenceSummary =>
      '${recurrence.label} a partir de ${AppFormatters.dayMonthYear(startDate)}';
}

class MonthlyPlanItemInput {
  const MonthlyPlanItemInput({
    this.id,
    required this.linkedProductId,
    required this.itemNameSnapshot,
    required this.flavorSnapshot,
    required this.variationSnapshot,
    required this.unitPrice,
    required this.quantity,
    required this.notes,
  });

  final String? id;
  final String? linkedProductId;
  final String itemNameSnapshot;
  final String? flavorSnapshot;
  final String? variationSnapshot;
  final Money unitPrice;
  final int quantity;
  final String? notes;
}

class MonthlyPlanUpsertInput {
  const MonthlyPlanUpsertInput({
    this.id,
    required this.clientId,
    required this.clientNameSnapshot,
    required this.title,
    required this.templateProductId,
    required this.templateProductNameSnapshot,
    required this.startDate,
    this.recurrence = MonthlyPlanRecurrence.monthly,
    required this.numberOfMonths,
    required this.contractedQuantity,
    required this.notes,
    required this.items,
  });

  final String? id;
  final String clientId;
  final String clientNameSnapshot;
  final String title;
  final String? templateProductId;
  final String? templateProductNameSnapshot;
  final DateTime startDate;
  final MonthlyPlanRecurrence recurrence;
  final int numberOfMonths;
  final int contractedQuantity;
  final String? notes;
  final List<MonthlyPlanItemInput> items;
}

class MonthlyPlanFutureImpactEntry {
  const MonthlyPlanFutureImpactEntry({
    required this.occurrence,
    required this.estimatedMonthlyTotal,
    required this.estimatedItemCount,
    required this.canGenerateDraft,
  });

  final MonthlyPlanOccurrenceRecord occurrence;
  final Money estimatedMonthlyTotal;
  final int estimatedItemCount;
  final bool canGenerateDraft;

  bool get alreadyGenerated => occurrence.hasGeneratedOrder;
}

class MonthlyPlanFutureImpact {
  const MonthlyPlanFutureImpact({
    required this.planId,
    required this.remainingBalance,
    required this.availableToGenerateCount,
    required this.entries,
  });

  final String planId;
  final int remainingBalance;
  final int availableToGenerateCount;
  final List<MonthlyPlanFutureImpactEntry> entries;
}

MonthlyPlanFutureImpact buildMonthlyPlanFutureImpact(
  MonthlyPlanRecord plan, {
  DateTime? referenceDate,
  int maxEntries = 6,
}) {
  final normalizedReferenceDate = _normalizeDate(
    referenceDate ?? DateTime.now(),
  );
  final futureOccurrences = plan.sortedHistory
      .where(
        (occurrence) =>
            !occurrence.isSkipped &&
            !occurrence.scheduledDate.isBefore(normalizedReferenceDate),
      )
      .toList(growable: false);
  final availableToGenerateCount = plan.availableToGenerateCount;
  var remainingEligibleEntries = availableToGenerateCount;

  final entries = <MonthlyPlanFutureImpactEntry>[];
  for (final occurrence in futureOccurrences) {
    final canGenerateDraft =
        !occurrence.hasGeneratedOrder &&
        remainingEligibleEntries > 0 &&
        entries.length < maxEntries;

    if (entries.length >= maxEntries) {
      break;
    }

    entries.add(
      MonthlyPlanFutureImpactEntry(
        occurrence: occurrence,
        estimatedMonthlyTotal: plan.estimatedMonthlyTotal,
        estimatedItemCount: plan.estimatedItemCount,
        canGenerateDraft: canGenerateDraft,
      ),
    );

    if (canGenerateDraft) {
      remainingEligibleEntries -= 1;
    }
  }

  return MonthlyPlanFutureImpact(
    planId: plan.id,
    remainingBalance: plan.remainingBalance,
    availableToGenerateCount: plan.availableToGenerateCount,
    entries: entries,
  );
}

List<DateTime> buildMonthlyPlanScheduleDates({
  required DateTime startDate,
  required int numberOfMonths,
}) {
  final normalizedStartDate = _normalizeDate(startDate);
  final normalizedMonthCount = numberOfMonths <= 0 ? 1 : numberOfMonths;

  return List<DateTime>.generate(
    normalizedMonthCount,
    (index) => addMonthsKeepingDay(normalizedStartDate, index),
    growable: false,
  );
}

DateTime addMonthsKeepingDay(DateTime date, int monthsToAdd) {
  final targetYear = date.year + ((date.month - 1 + monthsToAdd) ~/ 12);
  final targetMonth = ((date.month - 1 + monthsToAdd) % 12) + 1;
  final lastDayOfMonth = DateTime(targetYear, targetMonth + 1, 0).day;
  final targetDay = math.min(date.day, lastDayOfMonth);

  return DateTime(targetYear, targetMonth, targetDay);
}

DateTime _normalizeDate(DateTime date) {
  return DateTime(date.year, date.month, date.day);
}
