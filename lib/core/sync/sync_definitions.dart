enum LocalSyncStatus {
  pending(databaseValue: 'pending'),
  synced(databaseValue: 'synced'),
  failed(databaseValue: 'failed');

  const LocalSyncStatus({required this.databaseValue});

  final String databaseValue;

  static LocalSyncStatus fromDatabase(String value) {
    return values.firstWhere(
      (status) => status.databaseValue == value,
      orElse: () => LocalSyncStatus.pending,
    );
  }
}

enum SyncRunStatus {
  idle(databaseValue: 'idle'),
  syncing(databaseValue: 'syncing'),
  success(databaseValue: 'success'),
  failed(databaseValue: 'failed');

  const SyncRunStatus({required this.databaseValue});

  final String databaseValue;

  static SyncRunStatus fromDatabase(String value) {
    return values.firstWhere(
      (status) => status.databaseValue == value,
      orElse: () => SyncRunStatus.idle,
    );
  }
}

enum RootSyncEntityType {
  client(databaseValue: 'client', tableName: 'clients'),
  order(databaseValue: 'order', tableName: 'orders'),
  product(databaseValue: 'product', tableName: 'products'),
  ingredient(databaseValue: 'ingredient', tableName: 'ingredients'),
  recipe(databaseValue: 'recipe', tableName: 'recipes'),
  packaging(databaseValue: 'packaging', tableName: 'packaging'),
  supplier(databaseValue: 'supplier', tableName: 'suppliers'),
  monthlyPlan(databaseValue: 'monthly_plan', tableName: 'monthly_plans'),
  financeManualEntry(
    databaseValue: 'finance_manual_entry',
    tableName: 'finance_manual_entries',
  );

  const RootSyncEntityType({
    required this.databaseValue,
    required this.tableName,
  });

  final String databaseValue;
  final String tableName;

  static RootSyncEntityType fromDatabase(String value) {
    return values.firstWhere(
      (entityType) => entityType.databaseValue == value,
      orElse: () => RootSyncEntityType.order,
    );
  }
}
