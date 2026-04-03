import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
import '../../orders/application/order_providers.dart';
import '../../orders/domain/order.dart';
import '../data/clients_repository.dart';
import '../domain/client.dart';
import '../domain/client_list_filters.dart';

final clientsRepositoryProvider = Provider<ClientsRepository>((ref) {
  return ClientsRepository(ref.watch(appDatabaseProvider));
});

class ClientListFiltersNotifier extends Notifier<ClientListFilters> {
  @override
  ClientListFilters build() => const ClientListFilters();

  void updateSearchQuery(String value) {
    state = state.copyWith(searchQuery: value);
  }

  void clear() {
    state = const ClientListFilters();
  }
}

final clientListFiltersProvider =
    NotifierProvider<ClientListFiltersNotifier, ClientListFilters>(
      ClientListFiltersNotifier.new,
    );

final allClientsProvider = StreamProvider<List<ClientRecord>>((ref) {
  return ref.watch(clientsRepositoryProvider).watchClients();
});

final filteredClientsProvider = Provider<AsyncValue<List<ClientRecord>>>((ref) {
  final filters = ref.watch(clientListFiltersProvider);
  final clientsAsync = ref.watch(allClientsProvider);

  return clientsAsync.whenData(filters.apply);
});

final clientProvider = StreamProvider.autoDispose.family<ClientRecord?, String>(
  (ref, clientId) {
    return ref.watch(clientsRepositoryProvider).watchClient(clientId);
  },
);

final clientOrderHistoryProvider = StreamProvider.autoDispose
    .family<List<OrderRecord>, String>((ref, clientId) {
      return ref.watch(ordersRepositoryProvider).watchOrdersForClient(clientId);
    });
