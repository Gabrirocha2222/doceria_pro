import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/bootstrap/app_bootstrap_state.dart';
import '../../../core/database/app_database.dart';
import '../../../core/sync/sync_definitions.dart';
import '../../team/application/team_providers.dart';
import '../data/supabase_sync_remote_gateway.dart';
import '../data/sync_local_repository.dart';
import '../data/sync_remote_gateway.dart';
import '../domain/sync_state.dart';
import 'sync_service.dart';

final syncLocalRepositoryProvider = Provider<SyncLocalRepository>((ref) {
  return SyncLocalRepository(ref.watch(appDatabaseProvider));
});

final syncRemoteGatewayProvider = Provider<SyncRemoteGateway?>((ref) {
  final bootstrapState = ref.watch(appBootstrapStateProvider);
  if (bootstrapState.supabaseStatus != SupabaseStatus.ready) {
    return null;
  }

  return SupabaseSyncRemoteGateway(Supabase.instance.client);
});

final syncServiceProvider = Provider<SyncService>((ref) {
  return SyncService(
    database: ref.watch(appDatabaseProvider),
    localRepository: ref.watch(syncLocalRepositoryProvider),
    teamRepository: ref.watch(teamRepositoryProvider),
    bootstrapState: ref.watch(appBootstrapStateProvider),
    remoteGateway: ref.watch(syncRemoteGatewayProvider),
  );
});

final syncPendingQueueCountProvider = StreamProvider<int>((ref) {
  return ref.watch(syncLocalRepositoryProvider).watchPendingQueueCount();
});

final syncStateRecordProvider = StreamProvider<SyncStateRecord>((ref) {
  return ref.watch(syncLocalRepositoryProvider).watchSyncStateRecord();
});

class SyncController extends AsyncNotifier<SyncRunResult?> {
  @override
  SyncRunResult? build() => null;

  Future<SyncRunResult> runSyncNow() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => ref.read(syncServiceProvider).runSyncNow(),
    );

    return state.requireValue ??
        const SyncRunResult(
          pushedCount: 0,
          pulledCount: 0,
          skippedCount: 0,
          isRemoteConfigured: false,
          hadError: true,
          errorMessage: 'Falha inesperada ao concluir a sincronização.',
        );
  }
}

final syncControllerProvider =
    AsyncNotifierProvider<SyncController, SyncRunResult?>(SyncController.new);

final syncOverviewProvider = Provider<AsyncValue<SyncOverview>>((ref) {
  final bootstrapState = ref.watch(appBootstrapStateProvider);
  final teamContextAsync = ref.watch(teamContextProvider);
  final pendingChangesAsync = ref.watch(syncPendingQueueCountProvider);
  final syncStateAsync = ref.watch(syncStateRecordProvider);
  final controllerState = ref.watch(syncControllerProvider);

  if (teamContextAsync.hasError) {
    return AsyncValue.error(
      teamContextAsync.error!,
      teamContextAsync.stackTrace ?? StackTrace.current,
    );
  }
  if (pendingChangesAsync.hasError) {
    return AsyncValue.error(
      pendingChangesAsync.error!,
      pendingChangesAsync.stackTrace ?? StackTrace.current,
    );
  }
  if (syncStateAsync.hasError) {
    return AsyncValue.error(
      syncStateAsync.error!,
      syncStateAsync.stackTrace ?? StackTrace.current,
    );
  }

  if (teamContextAsync.isLoading ||
      pendingChangesAsync.isLoading ||
      syncStateAsync.isLoading) {
    return const AsyncLoading();
  }

  final syncState = syncStateAsync.requireValue;
  return AsyncValue.data(
    SyncOverview(
      bootstrapState: bootstrapState,
      teamContext: teamContextAsync.requireValue,
      pendingChangesCount: pendingChangesAsync.requireValue,
      lastStatus: SyncRunStatus.fromDatabase(syncState.status),
      lastAttemptAt: syncState.lastAttemptAt,
      lastSuccessfulPushAt: syncState.lastSuccessfulPushAt,
      lastSuccessfulPullAt: syncState.lastSuccessfulPullAt,
      lastError: syncState.lastError,
      isSyncing:
          controllerState.isLoading ||
          syncState.status == SyncRunStatus.syncing.databaseValue,
    ),
  );
});
