import 'package:drift/drift.dart';

import '../../../core/collaboration/collaboration_definitions.dart';
import '../../../core/database/app_database.dart';
import '../domain/team.dart';

class TeamRepository {
  TeamRepository(this._database);

  final AppDatabase _database;

  Stream<TeamContextRecord> watchTeamContext() {
    return _database.select(_database.localTeams).watchSingle().asyncMap((
      teamRow,
    ) async {
      final memberRow =
          await (_database.select(_database.localTeamMembers)..where(
                (table) =>
                    table.teamId.equals(teamRow.id) &
                    table.isCurrentDeviceMember.equals(true),
              ))
              .getSingle();

      return TeamContextRecord(
        team: _mapTeamRecord(teamRow),
        currentMember: _mapMemberRecord(memberRow),
      );
    });
  }

  Future<TeamContextRecord> getTeamContext() async {
    final teamRow = await _database.select(_database.localTeams).getSingle();
    final memberRow =
        await (_database.select(_database.localTeamMembers)..where(
              (table) =>
                  table.teamId.equals(teamRow.id) &
                  table.isCurrentDeviceMember.equals(true),
            ))
            .getSingle();

    return TeamContextRecord(
      team: _mapTeamRecord(teamRow),
      currentMember: _mapMemberRecord(memberRow),
    );
  }

  LocalTeamRecord _mapTeamRecord(LocalTeam row) {
    return LocalTeamRecord(
      id: row.id,
      name: row.name,
      createdAt: row.createdAt,
      updatedAt: row.updatedAt,
    );
  }

  LocalTeamMemberRecord _mapMemberRecord(LocalTeamMember row) {
    return LocalTeamMemberRecord(
      id: row.id,
      teamId: row.teamId,
      displayName: row.displayName,
      role: TeamRole.fromDatabase(row.role),
      remoteAuthUserId: row.remoteAuthUserId,
      isCurrentDeviceMember: row.isCurrentDeviceMember,
      isActive: row.isActive,
      createdAt: row.createdAt,
      updatedAt: row.updatedAt,
    );
  }
}
