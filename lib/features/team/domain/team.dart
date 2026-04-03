import '../../../core/collaboration/collaboration_definitions.dart';

class LocalTeamRecord {
  const LocalTeamRecord({
    required this.id,
    required this.name,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String name;
  final DateTime createdAt;
  final DateTime updatedAt;
}

class LocalTeamMemberRecord {
  const LocalTeamMemberRecord({
    required this.id,
    required this.teamId,
    required this.displayName,
    required this.role,
    required this.remoteAuthUserId,
    required this.isCurrentDeviceMember,
    required this.isActive,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String teamId;
  final String displayName;
  final TeamRole role;
  final String? remoteAuthUserId;
  final bool isCurrentDeviceMember;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;
}

class TeamContextRecord {
  const TeamContextRecord({required this.team, required this.currentMember});

  final LocalTeamRecord team;
  final LocalTeamMemberRecord currentMember;
}
