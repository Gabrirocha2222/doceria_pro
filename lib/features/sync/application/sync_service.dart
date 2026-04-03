import 'package:drift/drift.dart';

import '../../../core/bootstrap/app_bootstrap_state.dart';
import '../../../core/database/app_database.dart';
import '../../../core/sync/sync_definitions.dart';
import '../../team/data/team_repository.dart';
import '../data/local_sync_support.dart';
import '../data/sync_local_repository.dart';
import '../data/sync_remote_gateway.dart';
import '../domain/sync_state.dart';

class SyncService {
  const SyncService({
    required AppDatabase database,
    required SyncLocalRepository localRepository,
    required TeamRepository teamRepository,
    required AppBootstrapState bootstrapState,
    required SyncRemoteGateway? remoteGateway,
  }) : _database = database,
       _localRepository = localRepository,
       _teamRepository = teamRepository,
       _bootstrapState = bootstrapState,
       _remoteGateway = remoteGateway;

  final AppDatabase _database;
  final SyncLocalRepository _localRepository;
  final TeamRepository _teamRepository;
  final AppBootstrapState _bootstrapState;
  final SyncRemoteGateway? _remoteGateway;

  Future<SyncRunResult> runSyncNow() async {
    if (_bootstrapState.supabaseStatus != SupabaseStatus.ready ||
        _remoteGateway == null) {
      return const SyncRunResult(
        pushedCount: 0,
        pulledCount: 0,
        skippedCount: 0,
        isRemoteConfigured: false,
        hadError: false,
      );
    }

    final teamContext = await _teamRepository.getTeamContext();
    final startedAt = DateTime.now();

    await _database.upsertSyncStateRecord(
      status: SyncRunStatus.syncing,
      lastAttemptAt: Value(startedAt),
      lastError: const Value(null),
    );

    var pushedCount = 0;
    var pulledCount = 0;
    var skippedCount = 0;
    var hadError = false;
    String? lastError;
    DateTime? lastSuccessfulPushAt;
    DateTime? lastSuccessfulPullAt;

    try {
      final queueItems = await _localRepository.getPendingQueueItems();
      for (final queueItem in queueItems) {
        try {
          final entityType = RootSyncEntityType.fromDatabase(
            queueItem.entityType,
          );
          final snapshot = await _localRepository.buildSnapshot(
            entityType: entityType,
            entityId: queueItem.entityId,
          );

          if (snapshot == null) {
            await _localRepository.removeQueueItem(queueItem.id);
            continue;
          }

          await _remoteGateway.upsertSnapshots([snapshot]);
          final syncedAt = DateTime.now();
          await LocalSyncSupport.markEntitySynced(
            database: _database,
            entityType: entityType,
            entityId: snapshot.entityId,
            syncedAt: syncedAt,
          );
          await _localRepository.clearQueuedEntity(
            entityType: entityType,
            entityId: snapshot.entityId,
          );
          pushedCount += 1;
          lastSuccessfulPushAt = syncedAt;
        } catch (error) {
          hadError = true;
          lastError = _formatError(error);

          await _localRepository.markQueueAttemptFailed(
            queueId: queueItem.id,
            errorMessage: lastError,
          );
          await LocalSyncSupport.markEntitySyncFailed(
            database: _database,
            entityType: RootSyncEntityType.fromDatabase(queueItem.entityType),
            entityId: queueItem.entityId,
            errorMessage: lastError,
          );
        }
      }

      final remoteSnapshots = await _remoteGateway.pullSnapshots(
        teamId: teamContext.team.id,
        updatedAfter: await _localRepository.getLastSuccessfulPullAt(),
      );

      for (final snapshot in remoteSnapshots) {
        try {
          final localInfo = await _localRepository.getLocalEntitySyncInfo(
            entityType: snapshot.entityType,
            entityId: snapshot.entityId,
          );

          if (localInfo != null &&
              !snapshot.updatedAt.isAfter(localInfo.updatedAt)) {
            skippedCount += 1;
            continue;
          }

          await _localRepository.applyRemoteSnapshot(snapshot);
          pulledCount += 1;
        } catch (error) {
          hadError = true;
          lastError = _formatError(error);
        }
      }

      lastSuccessfulPullAt = DateTime.now();
    } catch (error) {
      hadError = true;
      lastError = _formatError(error);
    }

    await _database.upsertSyncStateRecord(
      status: hadError ? SyncRunStatus.failed : SyncRunStatus.success,
      lastAttemptAt: Value(startedAt),
      lastSuccessfulPushAt: lastSuccessfulPushAt == null
          ? const Value.absent()
          : Value(lastSuccessfulPushAt),
      lastSuccessfulPullAt: lastSuccessfulPullAt == null
          ? const Value.absent()
          : Value(lastSuccessfulPullAt),
      lastError: hadError ? Value(lastError) : const Value(null),
    );

    return SyncRunResult(
      pushedCount: pushedCount,
      pulledCount: pulledCount,
      skippedCount: skippedCount,
      isRemoteConfigured: true,
      hadError: hadError,
      errorMessage: lastError,
    );
  }

  String _formatError(Object error) {
    final message = error.toString().trim();
    if (message.isEmpty) {
      return 'Falha inesperada na sincronização.';
    }

    return message.length > 220 ? '${message.substring(0, 220)}...' : message;
  }
}
