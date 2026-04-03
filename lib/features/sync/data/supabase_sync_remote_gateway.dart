import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/sync/sync_definitions.dart';
import '../domain/sync_state.dart';
import 'sync_remote_gateway.dart';

class SupabaseSyncRemoteGateway implements SyncRemoteGateway {
  SupabaseSyncRemoteGateway(this._client);

  final SupabaseClient _client;

  static const _tableName = 'sync_entity_snapshots';

  @override
  Future<void> upsertSnapshots(List<RemoteEntitySnapshot> snapshots) async {
    if (snapshots.isEmpty) {
      return;
    }

    await _client.from(_tableName).upsert([
      for (final snapshot in snapshots)
        {
          'team_id': snapshot.teamId,
          'entity_type': snapshot.entityType.databaseValue,
          'entity_id': snapshot.entityId,
          'payload': snapshot.payload,
          'payload_schema': snapshot.payloadSchema,
          'updated_at': snapshot.updatedAt.toUtc().toIso8601String(),
          'deleted_at': snapshot.deletedAt?.toUtc().toIso8601String(),
          'updated_by_member_id': snapshot.updatedByMemberId,
        },
    ], onConflict: 'team_id,entity_type,entity_id');
  }

  @override
  Future<List<RemoteEntitySnapshot>> pullSnapshots({
    required String teamId,
    DateTime? updatedAfter,
  }) async {
    final baseQuery = _client.from(_tableName).select().eq('team_id', teamId);
    final rows = updatedAfter == null
        ? await baseQuery.order('updated_at', ascending: true)
        : await baseQuery
              .gt('updated_at', updatedAfter.toUtc().toIso8601String())
              .order('updated_at', ascending: true);

    return rows.map(_mapSnapshot).toList(growable: false);
  }

  RemoteEntitySnapshot _mapSnapshot(Map<String, dynamic> row) {
    return RemoteEntitySnapshot(
      teamId: row['team_id'] as String,
      entityType: RootSyncEntityType.fromDatabase(row['entity_type'] as String),
      entityId: row['entity_id'] as String,
      payload: Map<String, Object?>.from(row['payload'] as Map),
      updatedAt: DateTime.parse(row['updated_at'] as String).toLocal(),
      updatedByMemberId: row['updated_by_member_id'] as String,
      deletedAt: row['deleted_at'] == null
          ? null
          : DateTime.parse(row['deleted_at'] as String).toLocal(),
      payloadSchema: row['payload_schema'] as int? ?? 1,
    );
  }
}
