import 'client.dart';

class ClientListFilters {
  const ClientListFilters({this.searchQuery = ''});

  final String searchQuery;

  bool get hasActiveFilters => searchQuery.trim().isNotEmpty;

  ClientListFilters copyWith({String? searchQuery}) {
    return ClientListFilters(searchQuery: searchQuery ?? this.searchQuery);
  }

  List<ClientRecord> apply(List<ClientRecord> clients) {
    final normalizedQuery = searchQuery.trim().toLowerCase();
    if (normalizedQuery.isEmpty) {
      return clients;
    }

    return clients
        .where((client) {
          final searchableFields = [
            client.name,
            client.phone ?? '',
            client.address ?? '',
            client.notes ?? '',
            client.rating.label,
            ...client.importantDates.map(
              (importantDate) => importantDate.label,
            ),
          ];

          return searchableFields.any(
            (field) => field.toLowerCase().contains(normalizedQuery),
          );
        })
        .toList(growable: false);
  }
}
