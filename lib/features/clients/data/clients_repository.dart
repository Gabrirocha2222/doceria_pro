import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../../core/database/app_database.dart';
import '../../../core/sync/sync_definitions.dart';
import '../../sync/data/local_sync_support.dart';
import '../domain/client.dart';
import '../domain/client_rating.dart';

class ClientsRepository {
  ClientsRepository(this._database);

  final AppDatabase _database;
  final Uuid _uuid = const Uuid();

  Stream<List<ClientRecord>> watchClients() {
    final query = _database.select(_database.clients)
      ..orderBy([
        (table) => OrderingTerm(
          expression: table.name.lower(),
          mode: OrderingMode.asc,
        ),
      ]);

    return query.watch().asyncMap(_mapClientList);
  }

  Stream<ClientRecord?> watchClient(String clientId) {
    final query = _database.select(_database.clients)
      ..where((table) => table.id.equals(clientId));

    return query.watchSingleOrNull().asyncMap((row) async {
      if (row == null) {
        return null;
      }

      final importantDates = await _loadImportantDates(clientId);
      return _mapClientRecord(row, importantDates);
    });
  }

  Future<ClientRecord?> getClient(String clientId) async {
    final row = await (_database.select(
      _database.clients,
    )..where((table) => table.id.equals(clientId))).getSingleOrNull();

    if (row == null) {
      return null;
    }

    final importantDates = await _loadImportantDates(clientId);
    return _mapClientRecord(row, importantDates);
  }

  Future<String> saveClient(ClientUpsertInput input) async {
    final trimmedName = input.name.trim();
    if (trimmedName.isEmpty) {
      throw ArgumentError('Client name is required.');
    }

    final clientId = input.id ?? _uuid.v4();
    final now = DateTime.now();
    final normalizedImportantDates = input.importantDates
        .where((importantDate) => importantDate.label.trim().isNotEmpty)
        .map(
          (importantDate) => ClientImportantDateInput(
            label: importantDate.label.trim(),
            date: DateTime(
              importantDate.date.year,
              importantDate.date.month,
              importantDate.date.day,
            ),
          ),
        )
        .toList(growable: false);

    await _database.transaction(() async {
      if (input.id == null) {
        await _database
            .into(_database.clients)
            .insert(
              ClientsCompanion.insert(
                id: clientId,
                name: trimmedName,
                phone: Value(_trimToNull(input.phone)),
                address: Value(_trimToNull(input.address)),
                notes: Value(_trimToNull(input.notes)),
                rating: input.rating.databaseValue,
                createdAt: Value(now),
                updatedAt: Value(now),
              ),
            );
      } else {
        await (_database.update(
          _database.clients,
        )..where((table) => table.id.equals(clientId))).write(
          ClientsCompanion(
            name: Value(trimmedName),
            phone: Value(_trimToNull(input.phone)),
            address: Value(_trimToNull(input.address)),
            notes: Value(_trimToNull(input.notes)),
            rating: Value(input.rating.databaseValue),
            updatedAt: Value(now),
          ),
        );
      }

      await (_database.delete(
        _database.clientImportantDates,
      )..where((table) => table.clientId.equals(clientId))).go();

      for (final importantDate in normalizedImportantDates) {
        await _database
            .into(_database.clientImportantDates)
            .insert(
              ClientImportantDatesCompanion.insert(
                id: _uuid.v4(),
                clientId: clientId,
                label: importantDate.label,
                date: importantDate.date,
              ),
            );
      }

      await LocalSyncSupport.markEntityChanged(
        database: _database,
        entityType: RootSyncEntityType.client,
        entityId: clientId,
        updatedAt: now,
      );
    });

    return clientId;
  }

  Future<List<ClientRecord>> _mapClientList(List<Client> rows) async {
    if (rows.isEmpty) {
      return const [];
    }

    final clientIds = rows.map((row) => row.id).toList(growable: false);
    final importantDatesByClientId = await _loadImportantDatesByClientIds(
      clientIds,
    );

    return rows
        .map(
          (row) => _mapClientRecord(
            row,
            importantDatesByClientId[row.id] ?? const [],
          ),
        )
        .toList(growable: false);
  }

  Future<List<ClientImportantDateRecord>> _loadImportantDates(
    String clientId,
  ) async {
    final rows =
        await (_database.select(_database.clientImportantDates)
              ..where((table) => table.clientId.equals(clientId))
              ..orderBy([(table) => OrderingTerm(expression: table.date)]))
            .get();

    return rows.map(_mapImportantDateRecord).toList(growable: false);
  }

  Future<Map<String, List<ClientImportantDateRecord>>>
  _loadImportantDatesByClientIds(List<String> clientIds) async {
    final rows =
        await (_database.select(_database.clientImportantDates)
              ..where((table) => table.clientId.isIn(clientIds))
              ..orderBy([(table) => OrderingTerm(expression: table.date)]))
            .get();

    final result = <String, List<ClientImportantDateRecord>>{};
    for (final row in rows) {
      result
          .putIfAbsent(row.clientId, () => [])
          .add(_mapImportantDateRecord(row));
    }

    return result;
  }

  ClientRecord _mapClientRecord(
    Client row,
    List<ClientImportantDateRecord> importantDates,
  ) {
    return ClientRecord(
      id: row.id,
      name: row.name,
      phone: row.phone,
      address: row.address,
      notes: row.notes,
      rating: ClientRating.fromDatabase(row.rating),
      createdAt: row.createdAt,
      updatedAt: row.updatedAt,
      importantDates: importantDates,
    );
  }

  ClientImportantDateRecord _mapImportantDateRecord(ClientImportantDate row) {
    return ClientImportantDateRecord(
      id: row.id,
      clientId: row.clientId,
      label: row.label,
      date: row.date,
    );
  }

  String? _trimToNull(String? value) {
    final trimmed = value?.trim();
    if (trimmed == null || trimmed.isEmpty) {
      return null;
    }

    return trimmed;
  }
}
