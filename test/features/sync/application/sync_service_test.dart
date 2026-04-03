import 'package:doceria_pro/core/bootstrap/app_bootstrap_state.dart';
import 'package:doceria_pro/core/bootstrap/app_environment.dart';
import 'package:doceria_pro/core/collaboration/collaboration_definitions.dart';
import 'package:doceria_pro/core/database/app_database.dart';
import 'package:doceria_pro/core/sync/sync_definitions.dart';
import 'package:doceria_pro/features/clients/data/clients_repository.dart';
import 'package:doceria_pro/features/clients/domain/client.dart';
import 'package:doceria_pro/features/clients/domain/client_rating.dart';
import 'package:doceria_pro/features/sync/application/sync_service.dart';
import 'package:doceria_pro/features/sync/data/sync_local_repository.dart';
import 'package:doceria_pro/features/sync/data/sync_remote_gateway.dart';
import 'package:doceria_pro/features/sync/domain/sync_state.dart';
import 'package:doceria_pro/features/team/data/team_repository.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase database;
  late ClientsRepository clientsRepository;
  late TeamRepository teamRepository;
  late SyncLocalRepository syncLocalRepository;
  late FakeSyncRemoteGateway remoteGateway;
  late SyncService syncService;

  setUp(() {
    database = AppDatabase(NativeDatabase.memory());
    clientsRepository = ClientsRepository(database);
    teamRepository = TeamRepository(database);
    syncLocalRepository = SyncLocalRepository(database);
    remoteGateway = FakeSyncRemoteGateway();
    syncService = SyncService(
      database: database,
      localRepository: syncLocalRepository,
      teamRepository: teamRepository,
      bootstrapState: const AppBootstrapState(
        environment: AppEnvironment(
          supabaseUrl: 'https://example.supabase.co',
          supabaseAnonKey: 'anon-key',
        ),
        supabaseStatus: SupabaseStatus.ready,
      ),
      remoteGateway: remoteGateway,
    );
  });

  tearDown(() async {
    await database.close();
  });

  test('pushes pending local changes and clears the sync queue', () async {
    final clientId = await clientsRepository.saveClient(
      ClientUpsertInput(
        name: 'Helena',
        phone: '11999990000',
        address: 'Rua das Flores, 123',
        notes: 'Prefere contato por WhatsApp.',
        rating: ClientRating.like,
        importantDates: [
          ClientImportantDateInput(
            label: 'Aniversário',
            date: DateTime(2026, 5, 10),
          ),
        ],
      ),
    );

    final result = await syncService.runSyncNow();
    final queueItems = await database.select(database.syncQueue).get();
    final syncedClient = await (database.select(
      database.clients,
    )..where((table) => table.id.equals(clientId))).getSingle();

    expect(result.isRemoteConfigured, isTrue);
    expect(result.hadError, isFalse);
    expect(result.pushedCount, 1);
    expect(queueItems, isEmpty);
    expect(syncedClient.syncStatus, LocalSyncStatus.synced.databaseValue);
    expect(remoteGateway.pushedSnapshots, hasLength(1));
    expect(
      remoteGateway.pushedSnapshots.single.entityType,
      RootSyncEntityType.client,
    );
    expect(remoteGateway.pushedSnapshots.single.payload['name'], 'Helena');
  });

  test('applies a newer remote snapshot over the local client', () async {
    final clientId = await clientsRepository.saveClient(
      const ClientUpsertInput(
        name: 'Laura',
        phone: '21999990000',
        address: null,
        notes: null,
        rating: ClientRating.neutral,
        importantDates: [],
      ),
    );

    await database.delete(database.syncQueue).go();
    final localClient = await (database.select(
      database.clients,
    )..where((table) => table.id.equals(clientId))).getSingle();

    remoteGateway.availableRemoteSnapshots = [
      RemoteEntitySnapshot(
        teamId: DefaultCollaborationIds.teamId,
        entityType: RootSyncEntityType.client,
        entityId: clientId,
        payload: {
          'id': clientId,
          'name': 'Laura Atualizada',
          'phone': '21988887777',
          'address': 'Rua Nova, 45',
          'notes': 'Cliente atualizada pela equipe.',
          'rating': ClientRating.like.databaseValue,
          'createdAt': localClient.createdAt.toUtc().toIso8601String(),
          'importantDates': [
            {
              'id': 'date-01',
              'label': 'Entrega especial',
              'date': DateTime(2026, 6, 12).toUtc().toIso8601String(),
            },
          ],
        },
        updatedAt: localClient.updatedAt.add(const Duration(days: 1)),
        updatedByMemberId: DefaultCollaborationIds.memberId,
      ),
    ];

    final result = await syncService.runSyncNow();
    final updatedClient = await clientsRepository.getClient(clientId);

    expect(result.hadError, isFalse);
    expect(result.pulledCount, 1);
    expect(result.skippedCount, 0);
    expect(updatedClient, isNotNull);
    expect(updatedClient!.name, 'Laura Atualizada');
    expect(updatedClient.phone, '21988887777');
    expect(updatedClient.importantDates, hasLength(1));
    expect(updatedClient.importantDates.single.label, 'Entrega especial');
  });

  test('keeps the local version when the remote snapshot is older', () async {
    final clientId = await clientsRepository.saveClient(
      const ClientUpsertInput(
        name: 'Marina',
        phone: null,
        address: 'Rua do Ateliê',
        notes: 'Cliente local mais recente.',
        rating: ClientRating.like,
        importantDates: [],
      ),
    );

    await database.delete(database.syncQueue).go();
    final localClient = await (database.select(
      database.clients,
    )..where((table) => table.id.equals(clientId))).getSingle();

    remoteGateway.availableRemoteSnapshots = [
      RemoteEntitySnapshot(
        teamId: DefaultCollaborationIds.teamId,
        entityType: RootSyncEntityType.client,
        entityId: clientId,
        payload: {
          'id': clientId,
          'name': 'Marina Remota',
          'phone': null,
          'address': null,
          'notes': 'Versão antiga da nuvem.',
          'rating': ClientRating.dislike.databaseValue,
          'createdAt': localClient.createdAt.toUtc().toIso8601String(),
          'importantDates': const [],
        },
        updatedAt: localClient.updatedAt.subtract(const Duration(days: 1)),
        updatedByMemberId: DefaultCollaborationIds.memberId,
      ),
    ];

    final result = await syncService.runSyncNow();
    final preservedClient = await clientsRepository.getClient(clientId);

    expect(result.hadError, isFalse);
    expect(result.pulledCount, 0);
    expect(result.skippedCount, 1);
    expect(preservedClient, isNotNull);
    expect(preservedClient!.name, 'Marina');
    expect(preservedClient.notes, 'Cliente local mais recente.');
  });
}

class FakeSyncRemoteGateway implements SyncRemoteGateway {
  final List<RemoteEntitySnapshot> pushedSnapshots = [];
  List<RemoteEntitySnapshot> availableRemoteSnapshots = [];

  @override
  Future<List<RemoteEntitySnapshot>> pullSnapshots({
    required String teamId,
    DateTime? updatedAfter,
  }) async {
    final filtered =
        availableRemoteSnapshots
            .where((snapshot) {
              final matchesTeam = snapshot.teamId == teamId;
              final matchesDate =
                  updatedAfter == null ||
                  snapshot.updatedAt.isAfter(updatedAfter);
              return matchesTeam && matchesDate;
            })
            .toList(growable: false)
          ..sort((left, right) => left.updatedAt.compareTo(right.updatedAt));

    return filtered;
  }

  @override
  Future<void> upsertSnapshots(List<RemoteEntitySnapshot> snapshots) async {
    pushedSnapshots.addAll(snapshots);
  }
}
