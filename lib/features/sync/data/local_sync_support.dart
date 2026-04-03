import 'package:drift/drift.dart';

import '../../../core/collaboration/collaboration_definitions.dart';
import '../../../core/database/app_database.dart';
import '../../../core/sync/sync_definitions.dart';

abstract final class LocalSyncSupport {
  static Future<void> markEntityChanged({
    required AppDatabase database,
    required RootSyncEntityType entityType,
    required String entityId,
    DateTime? updatedAt,
    SyncOperation operation = SyncOperation.upsert,
  }) async {
    final sqlBuffer = StringBuffer()
      ..write('UPDATE ${entityType.tableName} ')
      ..write(
        'SET sync_status = ?, sync_error = NULL, team_id = ?, updated_by_member_id = ?',
      );
    final variables = <Variable<Object>>[
      Variable<String>(LocalSyncStatus.pending.databaseValue),
      Variable<String>(DefaultCollaborationIds.teamId),
      Variable<String>(DefaultCollaborationIds.memberId),
    ];

    if (updatedAt != null) {
      sqlBuffer.write(', updated_at = ?');
      variables.add(Variable<DateTime>(updatedAt));
    }

    sqlBuffer.write(' WHERE id = ?');
    variables.add(Variable<String>(entityId));

    await database.customUpdate(sqlBuffer.toString(), variables: variables);
    await database.enqueueSyncTask(
      entityType: entityType.databaseValue,
      entityId: entityId,
      operation: operation,
    );
  }

  static Future<void> markEntitySynced({
    required AppDatabase database,
    required RootSyncEntityType entityType,
    required String entityId,
    required DateTime syncedAt,
  }) {
    return database.customUpdate(
      'UPDATE ${entityType.tableName} '
      'SET sync_status = ?, last_synced_at = ?, sync_error = NULL '
      'WHERE id = ?',
      variables: [
        Variable<String>(LocalSyncStatus.synced.databaseValue),
        Variable<DateTime>(syncedAt),
        Variable<String>(entityId),
      ],
    );
  }

  static Future<void> markEntitySyncFailed({
    required AppDatabase database,
    required RootSyncEntityType entityType,
    required String entityId,
    required String errorMessage,
  }) {
    return database.customUpdate(
      'UPDATE ${entityType.tableName} SET sync_status = ?, sync_error = ? '
      'WHERE id = ?',
      variables: [
        Variable<String>(LocalSyncStatus.failed.databaseValue),
        Variable<String>(errorMessage),
        Variable<String>(entityId),
      ],
    );
  }
}
