import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../../core/database/app_database.dart';
import '../../../core/money/money.dart';
import '../../../core/sync/sync_definitions.dart';
import '../../orders/domain/order.dart';
import '../../orders/domain/order_status.dart';
import '../../purchases/domain/purchase.dart';
import '../../sync/data/local_sync_support.dart';
import '../domain/finance.dart';

class FinanceRepository {
  FinanceRepository(this._database);

  final AppDatabase _database;
  final Uuid _uuid = const Uuid();

  Stream<List<FinanceReceivableRecord>> watchReceivables() {
    final query =
        _database.select(_database.orderReceivableEntries).join([
          innerJoin(
            _database.orders,
            _database.orders.id.equalsExp(
              _database.orderReceivableEntries.orderId,
            ),
          ),
        ])..orderBy([
          OrderingTerm(
            expression: _database.orderReceivableEntries.dueDate,
            mode: OrderingMode.asc,
            nulls: NullsOrder.last,
          ),
          OrderingTerm(
            expression: _database.orderReceivableEntries.createdAt,
            mode: OrderingMode.desc,
          ),
        ]);

    return query.watch().map(
      (rows) => rows.map(_mapReceivableRecord).toList(growable: false),
    );
  }

  Stream<List<FinanceExpenseRecord>> watchExpenses() {
    final query = _database.select(_database.purchaseExpenseEntries)
      ..orderBy([
        (table) =>
            OrderingTerm(expression: table.createdAt, mode: OrderingMode.desc),
      ]);

    return query.watch().map(
      (rows) => rows.map(_mapExpenseRecord).toList(growable: false),
    );
  }

  Stream<List<FinanceManualEntryRecord>> watchManualEntries() {
    final query = _database.select(_database.financeManualEntries)
      ..orderBy([
        (table) =>
            OrderingTerm(expression: table.entryDate, mode: OrderingMode.desc),
        (table) =>
            OrderingTerm(expression: table.updatedAt, mode: OrderingMode.desc),
      ]);

    return query.watch().map(
      (rows) => rows.map(_mapManualEntryRecord).toList(growable: false),
    );
  }

  Future<String> saveManualEntry(FinanceManualEntryInput input) async {
    final trimmedDescription = input.description.trim();
    if (trimmedDescription.isEmpty) {
      throw ArgumentError('Manual entries require a description.');
    }
    if (input.amount.cents <= 0) {
      throw ArgumentError('Manual entries require a positive amount.');
    }

    final entryId = input.id ?? _uuid.v4();
    final now = DateTime.now();
    final normalizedEntryDate = _normalizeDate(input.entryDate);

    final companion = FinanceManualEntriesCompanion(
      entryType: Value(input.entryType.databaseValue),
      description: Value(trimmedDescription),
      amountCents: Value(input.amount.cents),
      entryDate: Value(normalizedEntryDate),
      category: Value(_trimToNull(input.category)),
      notes: Value(_trimToNull(input.notes)),
      updatedAt: Value(now),
    );

    await _database.transaction(() async {
      if (input.id == null) {
        await _database
            .into(_database.financeManualEntries)
            .insert(
              companion.copyWith(id: Value(entryId), createdAt: Value(now)),
            );
      } else {
        await (_database.update(
          _database.financeManualEntries,
        )..where((table) => table.id.equals(entryId))).write(companion);
      }

      await LocalSyncSupport.markEntityChanged(
        database: _database,
        entityType: RootSyncEntityType.financeManualEntry,
        entityId: entryId,
        updatedAt: now,
      );
    });

    return entryId;
  }

  Future<void> markReceivableReceived(String receivableId) async {
    final normalizedNow = _normalizeDate(DateTime.now());

    await _database.transaction(() async {
      final receivable = await (_database.select(
        _database.orderReceivableEntries,
      )..where((table) => table.id.equals(receivableId))).getSingleOrNull();
      if (receivable == null) {
        throw StateError('Receivable entry not found.');
      }

      if (receivable.status == OrderReceivableStatus.received.databaseValue &&
          receivable.receivedAt != null) {
        return;
      }

      await (_database.update(
        _database.orderReceivableEntries,
      )..where((table) => table.id.equals(receivableId))).write(
        OrderReceivableEntriesCompanion(
          status: Value(OrderReceivableStatus.received.databaseValue),
          receivedAt: Value(normalizedNow),
        ),
      );

      final receivedEntries =
          await (_database.select(_database.orderReceivableEntries)..where(
                (table) =>
                    table.orderId.equals(receivable.orderId) &
                    table.status.equals(
                      OrderReceivableStatus.received.databaseValue,
                    ),
              ))
              .get();
      final totalReceived = receivedEntries.fold<int>(
        0,
        (total, entry) => total + entry.amountCents,
      );

      await (_database.update(
        _database.orders,
      )..where((table) => table.id.equals(receivable.orderId))).write(
        OrdersCompanion(
          depositAmountCents: Value(totalReceived),
          updatedAt: Value(DateTime.now()),
        ),
      );

      await LocalSyncSupport.markEntityChanged(
        database: _database,
        entityType: RootSyncEntityType.order,
        entityId: receivable.orderId,
      );
    });
  }

  Future<void> markExpensePaid(String expenseId) async {
    final normalizedNow = _normalizeDate(DateTime.now());
    final expense = await (_database.select(
      _database.purchaseExpenseEntries,
    )..where((table) => table.id.equals(expenseId))).getSingleOrNull();
    if (expense == null) {
      throw StateError('Expense entry not found.');
    }

    if (expense.status == PurchaseExpenseDraftStatus.paid.databaseValue &&
        expense.paidAt != null) {
      return;
    }

    await (_database.update(
      _database.purchaseExpenseEntries,
    )..where((table) => table.id.equals(expenseId))).write(
      PurchaseExpenseEntriesCompanion(
        status: Value(PurchaseExpenseDraftStatus.paid.databaseValue),
        paidAt: Value(normalizedNow),
      ),
    );
  }

  FinanceReceivableRecord _mapReceivableRecord(TypedResult row) {
    final receivable = row.readTable(_database.orderReceivableEntries);
    final order = row.readTable(_database.orders);

    return FinanceReceivableRecord(
      id: receivable.id,
      orderId: receivable.orderId,
      clientNameSnapshot: order.clientNameSnapshot,
      orderStatus: OrderStatus.fromDatabase(order.status),
      orderDate: order.eventDate,
      description: receivable.description,
      amount: Money.fromCents(receivable.amountCents),
      dueDate: receivable.dueDate,
      status: OrderReceivableStatus.fromDatabase(receivable.status),
      createdAt: receivable.createdAt,
      receivedAt: receivable.receivedAt,
    );
  }

  FinanceExpenseRecord _mapExpenseRecord(PurchaseExpenseEntry row) {
    return FinanceExpenseRecord(
      id: row.id,
      purchaseEntryId: row.purchaseEntryId,
      description: row.description,
      supplierId: row.supplierId,
      supplierNameSnapshot: row.supplierNameSnapshot,
      amount: Money.fromCents(row.amountCents),
      status: PurchaseExpenseDraftStatus.fromDatabase(row.status),
      createdAt: row.createdAt,
      paidAt: row.paidAt,
    );
  }

  FinanceManualEntryRecord _mapManualEntryRecord(FinanceManualEntry row) {
    return FinanceManualEntryRecord(
      id: row.id,
      entryType: FinanceManualEntryType.fromDatabase(row.entryType),
      description: row.description,
      amount: Money.fromCents(row.amountCents),
      entryDate: row.entryDate,
      category: row.category,
      notes: row.notes,
      createdAt: row.createdAt,
      updatedAt: row.updatedAt,
    );
  }

  DateTime _normalizeDate(DateTime value) {
    return DateTime(value.year, value.month, value.day);
  }

  String? _trimToNull(String? value) {
    final trimmed = value?.trim();
    if (trimmed == null || trimmed.isEmpty) {
      return null;
    }

    return trimmed;
  }
}
