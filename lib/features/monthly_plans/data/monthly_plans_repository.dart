import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../../core/database/app_database.dart';
import '../../../core/money/money.dart';
import '../../../core/sync/sync_definitions.dart';
import '../../orders/domain/order_status.dart';
import '../../sync/data/local_sync_support.dart';
import '../domain/monthly_plan.dart';

class MonthlyPlansRepository {
  MonthlyPlansRepository(this._database);

  final AppDatabase _database;
  final Uuid _uuid = const Uuid();

  Stream<List<MonthlyPlanRecord>> watchMonthlyPlans() {
    final query = _database.select(_database.monthlyPlans).join([
      leftOuterJoin(
        _database.monthlyPlanOccurrences,
        _database.monthlyPlanOccurrences.monthlyPlanId.equalsExp(
          _database.monthlyPlans.id,
        ),
      ),
      leftOuterJoin(
        _database.orders,
        _database.orders.id.equalsExp(
          _database.monthlyPlanOccurrences.generatedOrderId,
        ),
      ),
    ]);

    return query.watch().asyncMap((rows) async {
      if (rows.isEmpty) {
        return const [];
      }

      return _mapPlanList(_dedupePlanRows(rows));
    });
  }

  Stream<List<MonthlyPlanRecord>> watchMonthlyPlansForClient(String clientId) {
    final query = _database.select(_database.monthlyPlans).join([
      leftOuterJoin(
        _database.monthlyPlanOccurrences,
        _database.monthlyPlanOccurrences.monthlyPlanId.equalsExp(
          _database.monthlyPlans.id,
        ),
      ),
      leftOuterJoin(
        _database.orders,
        _database.orders.id.equalsExp(
          _database.monthlyPlanOccurrences.generatedOrderId,
        ),
      ),
    ])..where(_database.monthlyPlans.clientId.equals(clientId));

    return query.watch().asyncMap((rows) async {
      if (rows.isEmpty) {
        return const [];
      }

      return _mapPlanList(_dedupePlanRows(rows));
    });
  }

  Stream<MonthlyPlanRecord?> watchMonthlyPlan(String monthlyPlanId) {
    final query = _database.select(_database.monthlyPlans).join([
      leftOuterJoin(
        _database.monthlyPlanOccurrences,
        _database.monthlyPlanOccurrences.monthlyPlanId.equalsExp(
          _database.monthlyPlans.id,
        ),
      ),
      leftOuterJoin(
        _database.orders,
        _database.orders.id.equalsExp(
          _database.monthlyPlanOccurrences.generatedOrderId,
        ),
      ),
    ])..where(_database.monthlyPlans.id.equals(monthlyPlanId));

    return query.watch().asyncMap((rows) async {
      if (rows.isEmpty) {
        return null;
      }

      return _mapCompletePlan(rows.first.readTable(_database.monthlyPlans));
    });
  }

  Future<MonthlyPlanRecord?> getMonthlyPlan(String monthlyPlanId) async {
    final row = await (_database.select(
      _database.monthlyPlans,
    )..where((table) => table.id.equals(monthlyPlanId))).getSingleOrNull();

    if (row == null) {
      return null;
    }

    return _mapCompletePlan(row);
  }

  Future<String> saveMonthlyPlan(MonthlyPlanUpsertInput input) async {
    final trimmedClientName = input.clientNameSnapshot.trim();
    final trimmedTitle = input.title.trim();
    if (trimmedClientName.isEmpty) {
      throw ArgumentError('Client snapshot is required.');
    }
    if (trimmedTitle.isEmpty) {
      throw ArgumentError('Monthly plan title is required.');
    }
    if (input.numberOfMonths <= 0) {
      throw ArgumentError('Monthly plan needs at least one month.');
    }
    if (input.contractedQuantity <= 0) {
      throw ArgumentError('Monthly plan needs a contracted quantity.');
    }
    if (input.contractedQuantity > input.numberOfMonths) {
      throw ArgumentError(
        'Contracted quantity cannot exceed the monthly schedule horizon.',
      );
    }

    final normalizedItems = input.items
        .where((item) => item.itemNameSnapshot.trim().isNotEmpty)
        .toList(growable: false);
    if (normalizedItems.isEmpty) {
      throw ArgumentError('Monthly plan needs at least one template item.');
    }

    for (final item in normalizedItems) {
      if (item.unitPrice.cents < 0) {
        throw ArgumentError('Template item prices must be positive.');
      }
      if (item.quantity <= 0) {
        throw ArgumentError('Template item quantity must be at least one.');
      }
    }

    final planId = input.id ?? _uuid.v4();
    final now = DateTime.now();
    final normalizedStartDate = _normalizeDate(input.startDate);
    final scheduleDates = buildMonthlyPlanScheduleDates(
      startDate: normalizedStartDate,
      numberOfMonths: input.numberOfMonths,
    );
    final trimmedTemplateProductId = _trimToNull(input.templateProductId);
    final trimmedTemplateProductName = _trimToNull(
      input.templateProductNameSnapshot,
    );

    await _database.transaction(() async {
      final companion = MonthlyPlansCompanion(
        clientId: Value(input.clientId.trim()),
        clientNameSnapshot: Value(trimmedClientName),
        title: Value(trimmedTitle),
        templateProductId: Value(trimmedTemplateProductId),
        templateProductNameSnapshot: Value(trimmedTemplateProductName),
        startDate: Value(normalizedStartDate),
        recurrenceType: Value(input.recurrence.databaseValue),
        numberOfMonths: Value(input.numberOfMonths),
        contractedQuantity: Value(input.contractedQuantity),
        notes: Value(_trimToNull(input.notes)),
        updatedAt: Value(now),
      );

      if (input.id == null) {
        await _database
            .into(_database.monthlyPlans)
            .insert(
              companion.copyWith(id: Value(planId), createdAt: Value(now)),
            );
      } else {
        await (_database.update(
          _database.monthlyPlans,
        )..where((table) => table.id.equals(planId))).write(companion);
      }

      await (_database.delete(
        _database.monthlyPlanItems,
      )..where((table) => table.monthlyPlanId.equals(planId))).go();

      for (var index = 0; index < normalizedItems.length; index++) {
        final item = normalizedItems[index];
        await _database
            .into(_database.monthlyPlanItems)
            .insert(
              MonthlyPlanItemsCompanion.insert(
                id: item.id ?? _uuid.v4(),
                monthlyPlanId: planId,
                linkedProductId: Value(_trimToNull(item.linkedProductId)),
                itemNameSnapshot: item.itemNameSnapshot.trim(),
                flavorSnapshot: Value(_trimToNull(item.flavorSnapshot)),
                variationSnapshot: Value(_trimToNull(item.variationSnapshot)),
                unitPriceCents: Value(item.unitPrice.cents),
                quantity: Value(item.quantity),
                notes: Value(_trimToNull(item.notes)),
                sortOrder: Value(index),
              ),
            );
      }

      await _reconcileOccurrences(
        monthlyPlanId: planId,
        scheduleDates: scheduleDates,
      );

      await LocalSyncSupport.markEntityChanged(
        database: _database,
        entityType: RootSyncEntityType.monthlyPlan,
        entityId: planId,
        updatedAt: now,
      );
    });

    return planId;
  }

  Future<void> markOccurrenceAsGenerated({
    required String occurrenceId,
    required String generatedOrderId,
  }) async {
    await _database.transaction(() async {
      final occurrence = await (_database.select(
        _database.monthlyPlanOccurrences,
      )..where((table) => table.id.equals(occurrenceId))).getSingleOrNull();
      if (occurrence == null) {
        throw StateError('Monthly plan occurrence not found.');
      }

      final now = DateTime.now();
      await (_database.update(
        _database.monthlyPlanOccurrences,
      )..where((table) => table.id.equals(occurrenceId))).write(
        MonthlyPlanOccurrencesCompanion(
          status: Value(
            MonthlyPlanOccurrenceStatus.draftGenerated.databaseValue,
          ),
          generatedOrderId: Value(generatedOrderId),
        ),
      );
      await (_database.update(_database.monthlyPlans)
            ..where((table) => table.id.equals(occurrence.monthlyPlanId)))
          .write(MonthlyPlansCompanion(updatedAt: Value(now)));

      await LocalSyncSupport.markEntityChanged(
        database: _database,
        entityType: RootSyncEntityType.monthlyPlan,
        entityId: occurrence.monthlyPlanId,
        updatedAt: now,
      );
    });
  }

  Future<List<MonthlyPlanRecord>> _mapPlanList(List<MonthlyPlan> rows) async {
    if (rows.isEmpty) {
      return const [];
    }

    final monthlyPlanIds = rows.map((row) => row.id).toList(growable: false);
    final itemsByPlanId = await _loadItemsByPlanIds(monthlyPlanIds);
    final historyByPlanId = await _loadHistoryByPlanIds(monthlyPlanIds);

    return rows
        .map(
          (row) => _mapPlanRecord(
            row,
            itemsByPlanId[row.id] ?? const [],
            historyByPlanId[row.id] ?? const [],
          ),
        )
        .toList(growable: false);
  }

  Future<MonthlyPlanRecord> _mapCompletePlan(MonthlyPlan row) async {
    final items = await _loadItems(row.id);
    final history = await _loadHistory(row.id);
    return _mapPlanRecord(row, items, history);
  }

  Future<List<MonthlyPlanItemRecord>> _loadItems(String monthlyPlanId) async {
    final rows =
        await (_database.select(_database.monthlyPlanItems)
              ..where((table) => table.monthlyPlanId.equals(monthlyPlanId))
              ..orderBy([(table) => OrderingTerm(expression: table.sortOrder)]))
            .get();

    return rows.map(_mapItemRecord).toList(growable: false);
  }

  Future<Map<String, List<MonthlyPlanItemRecord>>> _loadItemsByPlanIds(
    List<String> monthlyPlanIds,
  ) async {
    final rows =
        await (_database.select(_database.monthlyPlanItems)
              ..where((table) => table.monthlyPlanId.isIn(monthlyPlanIds))
              ..orderBy([(table) => OrderingTerm(expression: table.sortOrder)]))
            .get();

    final result = <String, List<MonthlyPlanItemRecord>>{};
    for (final row in rows) {
      result.putIfAbsent(row.monthlyPlanId, () => []).add(_mapItemRecord(row));
    }

    return result;
  }

  Future<List<MonthlyPlanOccurrenceRecord>> _loadHistory(
    String monthlyPlanId,
  ) async {
    final query =
        _database.select(_database.monthlyPlanOccurrences).join([
            leftOuterJoin(
              _database.orders,
              _database.orders.id.equalsExp(
                _database.monthlyPlanOccurrences.generatedOrderId,
              ),
            ),
          ])
          ..where(
            _database.monthlyPlanOccurrences.monthlyPlanId.equals(
              monthlyPlanId,
            ),
          )
          ..orderBy([
            OrderingTerm(
              expression: _database.monthlyPlanOccurrences.scheduledDate,
            ),
          ]);

    final rows = await query.get();
    return rows
        .map(
          (row) => _mapOccurrenceRecord(
            row.readTable(_database.monthlyPlanOccurrences),
            row.readTableOrNull(_database.orders),
          ),
        )
        .toList(growable: false);
  }

  Future<Map<String, List<MonthlyPlanOccurrenceRecord>>> _loadHistoryByPlanIds(
    List<String> monthlyPlanIds,
  ) async {
    final query =
        _database.select(_database.monthlyPlanOccurrences).join([
            leftOuterJoin(
              _database.orders,
              _database.orders.id.equalsExp(
                _database.monthlyPlanOccurrences.generatedOrderId,
              ),
            ),
          ])
          ..where(
            _database.monthlyPlanOccurrences.monthlyPlanId.isIn(monthlyPlanIds),
          )
          ..orderBy([
            OrderingTerm(
              expression: _database.monthlyPlanOccurrences.scheduledDate,
            ),
          ]);

    final rows = await query.get();
    final result = <String, List<MonthlyPlanOccurrenceRecord>>{};

    for (final row in rows) {
      final occurrence = row.readTable(_database.monthlyPlanOccurrences);
      final order = row.readTableOrNull(_database.orders);
      result
          .putIfAbsent(occurrence.monthlyPlanId, () => [])
          .add(_mapOccurrenceRecord(occurrence, order));
    }

    return result;
  }

  Future<void> _reconcileOccurrences({
    required String monthlyPlanId,
    required List<DateTime> scheduleDates,
  }) async {
    final existingRows =
        await (_database.select(_database.monthlyPlanOccurrences)
              ..where((table) => table.monthlyPlanId.equals(monthlyPlanId))
              ..orderBy([
                (table) => OrderingTerm(expression: table.occurrenceIndex),
              ]))
            .get();
    final existingByIndex = {
      for (final row in existingRows) row.occurrenceIndex: row,
    };
    final maxIndex = scheduleDates.length;

    for (var index = 0; index < scheduleDates.length; index++) {
      final occurrenceIndex = index + 1;
      final scheduledDate = scheduleDates[index];
      final existingRow = existingByIndex[occurrenceIndex];

      if (existingRow == null) {
        await _database
            .into(_database.monthlyPlanOccurrences)
            .insert(
              MonthlyPlanOccurrencesCompanion.insert(
                id: _uuid.v4(),
                monthlyPlanId: monthlyPlanId,
                occurrenceIndex: occurrenceIndex,
                scheduledDate: scheduledDate,
              ),
            );
        continue;
      }

      if (existingRow.generatedOrderId != null) {
        continue;
      }

      await (_database.update(
        _database.monthlyPlanOccurrences,
      )..where((table) => table.id.equals(existingRow.id))).write(
        MonthlyPlanOccurrencesCompanion(
          occurrenceIndex: Value(occurrenceIndex),
          scheduledDate: Value(scheduledDate),
        ),
      );
    }

    for (final existingRow in existingRows) {
      if (existingRow.occurrenceIndex <= maxIndex) {
        continue;
      }
      if (existingRow.generatedOrderId != null) {
        continue;
      }

      await (_database.delete(
        _database.monthlyPlanOccurrences,
      )..where((table) => table.id.equals(existingRow.id))).go();
    }
  }

  MonthlyPlanRecord _mapPlanRecord(
    MonthlyPlan row,
    List<MonthlyPlanItemRecord> items,
    List<MonthlyPlanOccurrenceRecord> history,
  ) {
    return MonthlyPlanRecord(
      id: row.id,
      clientId: row.clientId,
      clientNameSnapshot: row.clientNameSnapshot,
      title: row.title,
      templateProductId: row.templateProductId,
      templateProductNameSnapshot: row.templateProductNameSnapshot,
      startDate: row.startDate,
      recurrence: MonthlyPlanRecurrence.fromDatabase(row.recurrenceType),
      numberOfMonths: row.numberOfMonths,
      contractedQuantity: row.contractedQuantity,
      notes: row.notes,
      createdAt: row.createdAt,
      updatedAt: row.updatedAt,
      items: items,
      history: history,
    );
  }

  MonthlyPlanItemRecord _mapItemRecord(MonthlyPlanItem row) {
    return MonthlyPlanItemRecord(
      id: row.id,
      monthlyPlanId: row.monthlyPlanId,
      linkedProductId: row.linkedProductId,
      itemNameSnapshot: row.itemNameSnapshot,
      flavorSnapshot: row.flavorSnapshot,
      variationSnapshot: row.variationSnapshot,
      unitPrice: Money.fromCents(row.unitPriceCents),
      quantity: row.quantity,
      notes: row.notes,
      sortOrder: row.sortOrder,
    );
  }

  MonthlyPlanOccurrenceRecord _mapOccurrenceRecord(
    MonthlyPlanOccurrence row,
    Order? order,
  ) {
    return MonthlyPlanOccurrenceRecord(
      id: row.id,
      monthlyPlanId: row.monthlyPlanId,
      occurrenceIndex: row.occurrenceIndex,
      scheduledDate: row.scheduledDate,
      status: MonthlyPlanOccurrenceStatus.fromDatabase(row.status),
      generatedOrderId: row.generatedOrderId,
      generatedOrderStatus: order == null
          ? null
          : OrderStatus.fromDatabase(order.status),
      createdAt: row.createdAt,
    );
  }

  String? _trimToNull(String? value) {
    final trimmedValue = value?.trim();
    if (trimmedValue == null || trimmedValue.isEmpty) {
      return null;
    }

    return trimmedValue;
  }

  DateTime _normalizeDate(DateTime date) {
    return DateTime(date.year, date.month, date.day);
  }

  List<MonthlyPlan> _dedupePlanRows(List<TypedResult> rows) {
    final result = <String, MonthlyPlan>{};
    for (final row in rows) {
      final monthlyPlan = row.readTable(_database.monthlyPlans);
      result.putIfAbsent(monthlyPlan.id, () => monthlyPlan);
    }

    final plans = result.values.toList(growable: false);
    plans.sort((a, b) {
      final startDateComparison = a.startDate.compareTo(b.startDate);
      if (startDateComparison != 0) {
        return startDateComparison;
      }

      return b.updatedAt.compareTo(a.updatedAt);
    });

    return plans;
  }
}
