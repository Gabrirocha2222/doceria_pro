import 'package:doceria_pro/core/database/app_database.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('enqueueSyncTask stores a sync queue item locally', () async {
    final database = AppDatabase(NativeDatabase.memory());
    addTearDown(database.close);

    await database.enqueueSyncTask(
      entityType: 'order',
      entityId: 'order-001',
      operation: SyncOperation.upsert,
      payloadJson: '{"status":"draft"}',
    );

    final entries = await database.select(database.syncQueue).get();

    expect(entries, hasLength(1));
    expect(entries.single.entityType, 'order');
    expect(entries.single.entityId, 'order-001');
    expect(entries.single.operation, 'upsert');
    expect(entries.single.retryCount, 0);
  });

  test(
    'enqueueSyncTask keeps only the latest queue entry per entity',
    () async {
      final database = AppDatabase(NativeDatabase.memory());
      addTearDown(database.close);

      await database.enqueueSyncTask(
        entityType: 'client',
        entityId: 'client-001',
        operation: SyncOperation.upsert,
      );
      await database.enqueueSyncTask(
        entityType: 'client',
        entityId: 'client-001',
        operation: SyncOperation.upsert,
      );

      final entries = await database.select(database.syncQueue).get();

      expect(entries, hasLength(1));
      expect(entries.single.entityType, 'client');
      expect(entries.single.entityId, 'client-001');
    },
  );

  test(
    'seeds local team and sync state defaults on database creation',
    () async {
      final database = AppDatabase(NativeDatabase.memory());
      addTearDown(database.close);

      final teams = await database.select(database.localTeams).get();
      final members = await database.select(database.localTeamMembers).get();
      final syncStates = await database.select(database.syncStateRecords).get();

      expect(teams, hasLength(1));
      expect(teams.single.name, 'Equipe principal');
      expect(members, hasLength(1));
      expect(members.single.isCurrentDeviceMember, isTrue);
      expect(syncStates, hasLength(1));
      expect(syncStates.single.status, 'idle');
    },
  );
}
