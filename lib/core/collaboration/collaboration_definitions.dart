enum TeamRole {
  owner(databaseValue: 'owner', label: 'Proprietária'),
  employee(databaseValue: 'employee', label: 'Funcionária');

  const TeamRole({required this.databaseValue, required this.label});

  final String databaseValue;
  final String label;

  static TeamRole fromDatabase(String value) {
    return values.firstWhere(
      (role) => role.databaseValue == value,
      orElse: () => TeamRole.owner,
    );
  }
}

abstract final class DefaultCollaborationIds {
  static const teamId = 'local-team-default';
  static const memberId = 'local-owner-default';
  static const syncStateId = 'main';
}
