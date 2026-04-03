import 'package:doceria_pro/core/database/app_database.dart';
import 'package:doceria_pro/core/money/money.dart';
import 'package:doceria_pro/core/sync/sync_definitions.dart';
import 'package:doceria_pro/features/finance/data/finance_repository.dart';
import 'package:doceria_pro/features/finance/domain/finance.dart';
import 'package:doceria_pro/features/orders/domain/order.dart';
import 'package:doceria_pro/features/purchases/domain/purchase.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase database;
  late FinanceRepository repository;

  setUp(() {
    database = AppDatabase(NativeDatabase.memory());
    repository = FinanceRepository(database);
  });

  tearDown(() async {
    await database.close();
  });

  test(
    'markReceivableReceived updates status and received total on the order',
    () async {
      await database
          .into(database.orders)
          .insert(
            OrdersCompanion.insert(
              id: 'order-1',
              clientNameSnapshot: const Value('Amanda'),
              orderTotalCents: const Value(10000),
              depositAmountCents: const Value(2000),
              status: 'confirmed',
              createdAt: Value(DateTime(2026, 4, 2)),
              updatedAt: Value(DateTime(2026, 4, 2)),
            ),
          );
      await database
          .into(database.orderReceivableEntries)
          .insert(
            OrderReceivableEntriesCompanion.insert(
              id: 'entry-1',
              orderId: 'order-1',
              description: 'Sinal',
              amountCents: const Value(2000),
              status: OrderReceivableStatus.received.databaseValue,
              receivedAt: Value(DateTime(2026, 4, 2)),
              createdAt: Value(DateTime(2026, 4, 2)),
            ),
          );
      await database
          .into(database.orderReceivableEntries)
          .insert(
            OrderReceivableEntriesCompanion.insert(
              id: 'entry-2',
              orderId: 'order-1',
              description: 'Restante',
              amountCents: const Value(8000),
              status: OrderReceivableStatus.pending.databaseValue,
              createdAt: Value(DateTime(2026, 4, 2)),
            ),
          );

      await repository.markReceivableReceived('entry-2');

      final entry = await (database.select(
        database.orderReceivableEntries,
      )..where((table) => table.id.equals('entry-2'))).getSingle();
      final order = await (database.select(
        database.orders,
      )..where((table) => table.id.equals('order-1'))).getSingle();
      final syncQueue = await database.select(database.syncQueue).get();

      expect(entry.status, OrderReceivableStatus.received.databaseValue);
      expect(entry.receivedAt, isNotNull);
      expect(order.depositAmountCents, 10000);
      expect(
        syncQueue.any(
          (item) => item.entityType == 'order' && item.entityId == 'order-1',
        ),
        isTrue,
      );
    },
  );

  test(
    'markExpensePaid updates purchase expense status with a paid date',
    () async {
      await database
          .into(database.purchaseExpenseEntries)
          .insert(
            PurchaseExpenseEntriesCompanion.insert(
              id: 'expense-1',
              purchaseEntryId: 'purchase-1',
              description: 'Compra de chocolate',
              amountCents: const Value(4500),
              status: PurchaseExpenseDraftStatus.prepared.databaseValue,
              createdAt: Value(DateTime(2026, 4, 2)),
            ),
          );

      await repository.markExpensePaid('expense-1');

      final expense = await (database.select(
        database.purchaseExpenseEntries,
      )..where((table) => table.id.equals('expense-1'))).getSingle();

      expect(expense.status, PurchaseExpenseDraftStatus.paid.databaseValue);
      expect(expense.paidAt, isNotNull);
    },
  );

  test('saveManualEntry stores a normalized manual entry locally', () async {
    final entryId = await repository.saveManualEntry(
      FinanceManualEntryInput(
        entryType: FinanceManualEntryType.expense,
        description: 'Taxa da maquininha',
        amount: Money.fromCents(900),
        entryDate: DateTime(2026, 4, 15, 18, 45),
        category: 'Venda',
        notes: 'Feira de sábado',
      ),
    );

    final entry = await (database.select(
      database.financeManualEntries,
    )..where((table) => table.id.equals(entryId))).getSingle();

    expect(entry.entryType, FinanceManualEntryType.expense.databaseValue);
    expect(entry.amountCents, 900);
    expect(entry.entryDate, DateTime(2026, 4, 15));
    expect(entry.category, 'Venda');
    expect(entry.syncStatus, LocalSyncStatus.pending.databaseValue);

    final syncQueue = await database.select(database.syncQueue).get();
    expect(
      syncQueue.any(
        (item) =>
            item.entityType == 'finance_manual_entry' &&
            item.entityId == entryId,
      ),
      isTrue,
    );
  });
}
