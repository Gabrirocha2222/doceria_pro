import '../../../core/formatters/app_formatters.dart';
import '../../orders/domain/order.dart';
import '../../orders/domain/order_status.dart';
import 'production_filters.dart';

class ProductionTaskRecord {
  const ProductionTaskRecord({
    required this.plan,
    required this.orderId,
    required this.clientNameSnapshot,
    required this.orderDate,
    required this.orderStatus,
    required this.itemDisplayName,
    required this.flavorSnapshot,
    required this.variationSnapshot,
    required this.orderNotes,
    required this.relatedMaterialNeeds,
  });

  final OrderProductionPlanRecord plan;
  final String orderId;
  final String clientNameSnapshot;
  final DateTime? orderDate;
  final OrderStatus orderStatus;
  final String itemDisplayName;
  final String? flavorSnapshot;
  final String? variationSnapshot;
  final String? orderNotes;
  final List<OrderMaterialNeedRecord> relatedMaterialNeeds;

  DateTime? get deadline => plan.dueDate ?? orderDate;

  int get shortageCount => relatedMaterialNeeds
      .where((need) => need.hasShortage && !need.isConsumed)
      .length;

  int get materialCount => relatedMaterialNeeds.length;

  bool get hasShortage => shortageCount > 0;

  bool get hasNotes => displayNotes.isNotEmpty;

  bool get stockEffectApplied => relatedMaterialNeeds.isNotEmpty
      ? relatedMaterialNeeds.every((need) => need.isConsumed)
      : plan.isCompleted;

  String get displayClientName {
    final trimmedName = clientNameSnapshot.trim();
    if (trimmedName.isEmpty) {
      return 'Cliente não definida';
    }

    return trimmedName;
  }

  String get displayDeadline {
    if (deadline == null) {
      return 'Sem prazo definido';
    }

    return AppFormatters.dayMonthYear(deadline!);
  }

  String get displayItemLabel {
    final segments = [
      itemDisplayName,
      if (flavorSnapshot?.trim().isNotEmpty ?? false) flavorSnapshot!.trim(),
      if (variationSnapshot?.trim().isNotEmpty ?? false)
        variationSnapshot!.trim(),
    ];

    return segments.join(' • ');
  }

  String get displayNotes {
    final segments = [
      if (plan.notes?.trim().isNotEmpty ?? false) plan.notes!.trim(),
      if (plan.details?.trim().isNotEmpty ?? false) plan.details!.trim(),
      if (orderNotes?.trim().isNotEmpty ?? false) orderNotes!.trim(),
    ];

    return segments.join(' • ');
  }

  String groupLabel(ProductionGrouping grouping) {
    switch (grouping) {
      case ProductionGrouping.order:
        final dateLabel = orderDate == null
            ? 'Sem data'
            : AppFormatters.dayMonthYear(orderDate!);
        return '$displayClientName • $dateLabel';
      case ProductionGrouping.recipe:
        final recipeName = plan.recipeNameSnapshot?.trim();
        if (recipeName == null || recipeName.isEmpty) {
          return 'Sem receita vinculada';
        }

        return recipeName;
      case ProductionGrouping.item:
        return displayItemLabel;
    }
  }

  String groupSubtitle(ProductionGrouping grouping) {
    switch (grouping) {
      case ProductionGrouping.order:
        return itemDisplayName;
      case ProductionGrouping.recipe:
        return displayClientName;
      case ProductionGrouping.item:
        return displayClientName;
    }
  }
}

class ProductionTaskGroup {
  const ProductionTaskGroup({
    required this.label,
    required this.subtitle,
    required this.tasks,
  });

  final String label;
  final String subtitle;
  final List<ProductionTaskRecord> tasks;
}

List<ProductionTaskRecord> applyProductionFilters(
  List<ProductionTaskRecord> tasks,
  ProductionFilters filters,
) {
  final today = DateTime.now();
  final normalizedToday = DateTime(today.year, today.month, today.day);
  final endOfWeek = normalizedToday.add(const Duration(days: 6));

  final filteredTasks = tasks
      .where((task) {
        final deadline = task.deadline;
        if (deadline == null) {
          return true;
        }

        final normalizedDeadline = DateTime(
          deadline.year,
          deadline.month,
          deadline.day,
        );

        switch (filters.timeframe) {
          case ProductionTimeframe.today:
            return !normalizedDeadline.isAfter(normalizedToday);
          case ProductionTimeframe.week:
            return !normalizedDeadline.isAfter(endOfWeek);
        }
      })
      .toList(growable: false);

  filteredTasks.sort((left, right) {
    final leftStatusOrder = _statusSortWeight(left.plan.status);
    final rightStatusOrder = _statusSortWeight(right.plan.status);
    if (leftStatusOrder != rightStatusOrder) {
      return leftStatusOrder.compareTo(rightStatusOrder);
    }

    final leftDeadline = left.deadline;
    final rightDeadline = right.deadline;
    if (leftDeadline == null && rightDeadline != null) {
      return 1;
    }
    if (leftDeadline != null && rightDeadline == null) {
      return -1;
    }
    if (leftDeadline != null && rightDeadline != null) {
      final deadlineComparison = leftDeadline.compareTo(rightDeadline);
      if (deadlineComparison != 0) {
        return deadlineComparison;
      }
    }

    return left.displayClientName.toLowerCase().compareTo(
      right.displayClientName.toLowerCase(),
    );
  });

  return filteredTasks;
}

List<ProductionTaskGroup> buildProductionTaskGroups(
  List<ProductionTaskRecord> tasks,
  ProductionGrouping grouping,
) {
  final groupedTasks = <String, List<ProductionTaskRecord>>{};
  final subtitles = <String, String>{};

  for (final task in tasks) {
    final label = task.groupLabel(grouping);
    groupedTasks.putIfAbsent(label, () => []).add(task);
    subtitles.putIfAbsent(label, () => task.groupSubtitle(grouping));
  }

  final labels = groupedTasks.keys.toList(growable: false)
    ..sort((left, right) => left.toLowerCase().compareTo(right.toLowerCase()));

  return labels
      .map(
        (label) => ProductionTaskGroup(
          label: label,
          subtitle: subtitles[label] ?? '',
          tasks: groupedTasks[label] ?? const [],
        ),
      )
      .toList(growable: false);
}

int _statusSortWeight(OrderProductionPlanStatus status) {
  switch (status) {
    case OrderProductionPlanStatus.pending:
      return 0;
    case OrderProductionPlanStatus.inProduction:
      return 1;
    case OrderProductionPlanStatus.completed:
      return 2;
  }
}
