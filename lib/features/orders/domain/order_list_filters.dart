import '../../../core/formatters/app_formatters.dart';
import 'order.dart';
import 'order_status.dart';

class OrderListFilters {
  const OrderListFilters({this.searchQuery = '', this.status});

  final String searchQuery;
  final OrderStatus? status;

  bool get hasActiveFilters => searchQuery.trim().isNotEmpty || status != null;

  OrderListFilters copyWith({
    String? searchQuery,
    OrderStatus? status,
    bool clearStatus = false,
  }) {
    return OrderListFilters(
      searchQuery: searchQuery ?? this.searchQuery,
      status: clearStatus ? null : (status ?? this.status),
    );
  }

  List<OrderRecord> apply(List<OrderRecord> orders) {
    return orders.where(_matches).toList(growable: false);
  }

  bool _matches(OrderRecord order) {
    if (status != null && order.status != status) {
      return false;
    }

    final normalizedQuery = searchQuery.trim().toLowerCase();
    if (normalizedQuery.isEmpty) {
      return true;
    }

    final searchableFields = [
      order.clientNameSnapshot ?? '',
      order.notes ?? '',
      order.status.label,
      order.fulfillmentMethod?.label ?? '',
      if (order.eventDate != null) AppFormatters.dayMonthYear(order.eventDate!),
      ...order.items.map((item) => item.itemNameSnapshot),
      ...order.items.map((item) => item.flavorSnapshot ?? ''),
      ...order.items.map((item) => item.variationSnapshot ?? ''),
    ];

    return searchableFields.any(
      (field) => field.toLowerCase().contains(normalizedQuery),
    );
  }
}

class OrderDateGroup {
  const OrderDateGroup({
    required this.label,
    required this.date,
    required this.orders,
  });

  final String label;
  final DateTime? date;
  final List<OrderRecord> orders;
}

List<OrderDateGroup> buildOrderDateGroups(List<OrderRecord> orders) {
  final groups = <DateTime?, List<OrderRecord>>{};

  for (final order in orders) {
    final normalizedDate = order.eventDate == null
        ? null
        : DateTime(
            order.eventDate!.year,
            order.eventDate!.month,
            order.eventDate!.day,
          );
    groups.putIfAbsent(normalizedDate, () => []).add(order);
  }

  final sortedEntries = groups.entries.toList()
    ..sort((left, right) {
      if (left.key == null) {
        return 1;
      }

      if (right.key == null) {
        return -1;
      }

      return left.key!.compareTo(right.key!);
    });

  return [
    for (final entry in sortedEntries)
      OrderDateGroup(
        label: _buildGroupLabel(entry.key),
        date: entry.key,
        orders: entry.value,
      ),
  ];
}

String _buildGroupLabel(DateTime? date) {
  if (date == null) {
    return 'Sem data definida';
  }

  final today = DateTime.now();
  final normalizedToday = DateTime(today.year, today.month, today.day);
  final tomorrow = normalizedToday.add(const Duration(days: 1));

  if (_isSameDate(date, normalizedToday)) {
    return 'Hoje • ${AppFormatters.dayMonthYear(date)}';
  }

  if (_isSameDate(date, tomorrow)) {
    return 'Amanhã • ${AppFormatters.dayMonthYear(date)}';
  }

  if (date.isBefore(normalizedToday)) {
    return 'Atrasado • ${AppFormatters.dayMonthYear(date)}';
  }

  return AppFormatters.dayMonthYear(date);
}

bool _isSameDate(DateTime left, DateTime right) {
  return left.year == right.year &&
      left.month == right.month &&
      left.day == right.day;
}
