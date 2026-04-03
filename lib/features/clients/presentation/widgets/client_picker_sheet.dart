import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/client_providers.dart';
import '../../domain/client.dart';
import 'client_rating_badge.dart';

Future<ClientRecord?> showClientPickerSheet(BuildContext context) {
  return showModalBottomSheet<ClientRecord>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (context) => const _ClientPickerSheet(),
  );
}

class _ClientPickerSheet extends ConsumerStatefulWidget {
  const _ClientPickerSheet();

  @override
  ConsumerState<_ClientPickerSheet> createState() => _ClientPickerSheetState();
}

class _ClientPickerSheetState extends ConsumerState<_ClientPickerSheet> {
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final clientsAsync = ref.watch(allClientsProvider);
    final normalizedQuery = _searchController.text.trim().toLowerCase();

    return Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        12,
        20,
        MediaQuery.viewInsetsOf(context).bottom + 24,
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxHeight: 640),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Escolher cliente',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 6),
            Text(
              'Busque alguém já cadastrado e preencha o pedido mais rápido.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _searchController,
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(
                hintText: 'Buscar por nome, telefone ou observação',
                prefixIcon: Icon(Icons.search_rounded),
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: clientsAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (error, stackTrace) => Center(
                  child: Text('Não foi possível carregar as clientes agora.'),
                ),
                data: (clients) {
                  final filteredClients = clients
                      .where((client) {
                        if (normalizedQuery.isEmpty) {
                          return true;
                        }

                        final searchableFields = [
                          client.name,
                          client.phone ?? '',
                          client.notes ?? '',
                        ];

                        return searchableFields.any(
                          (field) =>
                              field.toLowerCase().contains(normalizedQuery),
                        );
                      })
                      .toList(growable: false);

                  if (filteredClients.isEmpty) {
                    return const Center(
                      child: Text(
                        'Nenhuma cliente encontrada com essa busca.',
                        textAlign: TextAlign.center,
                      ),
                    );
                  }

                  return ListView.separated(
                    itemCount: filteredClients.length,
                    separatorBuilder: (context, index) =>
                        const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final client = filteredClients[index];

                      return Card(
                        child: InkWell(
                          borderRadius: BorderRadius.circular(28),
                          onTap: () => Navigator.of(context).pop(client),
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        client.name,
                                        style: Theme.of(
                                          context,
                                        ).textTheme.titleMedium,
                                      ),
                                    ),
                                    ClientRatingBadge(rating: client.rating),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  client.displayPhone,
                                  style: Theme.of(context).textTheme.bodyMedium,
                                ),
                                if (client.notes?.trim().isNotEmpty ??
                                    false) ...[
                                  const SizedBox(height: 6),
                                  Text(
                                    client.notes!,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: Theme.of(
                                      context,
                                    ).textTheme.bodySmall,
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
