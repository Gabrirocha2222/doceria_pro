import '../domain/sync_state.dart';

abstract interface class SyncRemoteGateway {
  Future<void> upsertSnapshots(List<RemoteEntitySnapshot> snapshots);

  Future<List<RemoteEntitySnapshot>> pullSnapshots({
    required String teamId,
    DateTime? updatedAfter,
  });
}
