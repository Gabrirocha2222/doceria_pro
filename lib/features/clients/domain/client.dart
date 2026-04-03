import '../../../core/formatters/app_formatters.dart';
import 'client_rating.dart';

class ClientImportantDateRecord {
  const ClientImportantDateRecord({
    required this.id,
    required this.clientId,
    required this.label,
    required this.date,
  });

  final String id;
  final String clientId;
  final String label;
  final DateTime date;

  String get displayDate => AppFormatters.dayMonthYear(date);
}

class ClientRecord {
  const ClientRecord({
    required this.id,
    required this.name,
    required this.phone,
    required this.address,
    required this.notes,
    required this.rating,
    required this.createdAt,
    required this.updatedAt,
    required this.importantDates,
  });

  final String id;
  final String name;
  final String? phone;
  final String? address;
  final String? notes;
  final ClientRating rating;
  final DateTime createdAt;
  final DateTime updatedAt;
  final List<ClientImportantDateRecord> importantDates;

  String get displayPhone => AppFormatters.formatPhone(phone);

  String get displayAddress {
    final trimmedAddress = address?.trim();
    if (trimmedAddress == null || trimmedAddress.isEmpty) {
      return 'Sem endereço registrado';
    }

    return trimmedAddress;
  }

  String get displayNotes {
    final trimmedNotes = notes?.trim();
    if (trimmedNotes == null || trimmedNotes.isEmpty) {
      return 'Sem observações registradas';
    }

    return trimmedNotes;
  }

  ClientImportantDateRecord? get nextImportantDate {
    if (importantDates.isEmpty) {
      return null;
    }

    final sortedDates = [...importantDates]
      ..sort((left, right) => left.date.compareTo(right.date));

    return sortedDates.first;
  }
}

class ClientImportantDateInput {
  const ClientImportantDateInput({required this.label, required this.date});

  final String label;
  final DateTime date;
}

class ClientUpsertInput {
  const ClientUpsertInput({
    this.id,
    required this.name,
    required this.phone,
    required this.address,
    required this.notes,
    required this.rating,
    required this.importantDates,
  });

  final String? id;
  final String name;
  final String? phone;
  final String? address;
  final String? notes;
  final ClientRating rating;
  final List<ClientImportantDateInput> importantDates;
}
