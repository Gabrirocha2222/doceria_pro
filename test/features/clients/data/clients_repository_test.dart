import 'package:doceria_pro/core/database/app_database.dart';
import 'package:doceria_pro/features/clients/data/clients_repository.dart';
import 'package:doceria_pro/features/clients/domain/client.dart';
import 'package:doceria_pro/features/clients/domain/client_rating.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

void main() {
  late AppDatabase database;
  late ClientsRepository repository;

  setUpAll(() async {
    await initializeDateFormatting('pt_BR');
  });

  setUp(() {
    database = AppDatabase(NativeDatabase.memory());
    repository = ClientsRepository(database);
  });

  tearDown(() async {
    await database.close();
  });

  test('saves and reads a client with important dates', () async {
    final clientId = await repository.saveClient(
      ClientUpsertInput(
        name: 'Mariana Silva',
        phone: '11999998888',
        address: 'Rua das Flores, 123',
        notes: 'Prefere mensagens no fim da tarde.',
        rating: ClientRating.like,
        importantDates: [
          ClientImportantDateInput(
            label: 'Aniversário',
            date: DateTime(2026, 8, 20),
          ),
          ClientImportantDateInput(
            label: 'Casamento',
            date: DateTime(2026, 10, 12),
          ),
        ],
      ),
    );

    final client = await repository.watchClient(clientId).first;

    expect(client, isNotNull);
    expect(client!.name, 'Mariana Silva');
    expect(client.displayPhone, '(11) 99999-8888');
    expect(client.rating, ClientRating.like);
    expect(client.importantDates, hasLength(2));
    expect(client.nextImportantDate?.label, 'Aniversário');
  });

  test('updating a client replaces the stored important dates', () async {
    final clientId = await repository.saveClient(
      ClientUpsertInput(
        name: 'Bianca Costa',
        phone: null,
        address: null,
        notes: null,
        rating: ClientRating.neutral,
        importantDates: [
          ClientImportantDateInput(
            label: 'Aniversário',
            date: DateTime(2026, 6, 1),
          ),
        ],
      ),
    );

    await repository.saveClient(
      ClientUpsertInput(
        id: clientId,
        name: 'Bianca Costa',
        phone: '21988887777',
        address: 'Copacabana',
        notes: 'Gosta de confirmação por WhatsApp.',
        rating: ClientRating.dislike,
        importantDates: [
          ClientImportantDateInput(
            label: 'Data especial',
            date: DateTime(2026, 9, 5),
          ),
        ],
      ),
    );

    final client = await repository.getClient(clientId);

    expect(client, isNotNull);
    expect(client!.displayPhone, '(21) 98888-7777');
    expect(client.displayAddress, 'Copacabana');
    expect(client.displayNotes, 'Gosta de confirmação por WhatsApp.');
    expect(client.rating, ClientRating.dislike);
    expect(client.importantDates, hasLength(1));
    expect(client.importantDates.single.label, 'Data especial');
  });
}
