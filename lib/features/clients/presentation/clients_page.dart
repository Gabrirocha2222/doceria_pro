import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/navigation/app_destinations.dart';
import '../../../core/widgets/app_page_scaffold.dart';
import '../../../core/widgets/app_summary_metric_card.dart';
import '../../../core/widgets/states/app_empty_state.dart';
import '../../../core/widgets/states/app_error_state.dart';
import '../../../core/widgets/states/app_loading_state.dart';
import '../../monthly_plans/application/monthly_plan_providers.dart';
import '../application/client_providers.dart';
import '../domain/client.dart';
import '../domain/client_list_filters.dart';
import 'widgets/client_rating_badge.dart';

class ClientsPage extends ConsumerWidget {
  const ClientsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final allClientsAsync = ref.watch(allClientsProvider);
    final allMonthlyPlansAsync = ref.watch(allMonthlyPlansProvider);
    final filteredClientsAsync = ref.watch(filteredClientsProvider);
    final filters = ref.watch(clientListFiltersProvider);

    return AppPageScaffold(
      title: 'Clientes',
      subtitle:
          'Guarde contexto útil do relacionamento sem transformar isso em um CRM pesado.',
      trailing: Wrap(
        spacing: 12,
        runSpacing: 12,
        children: [
          FilledButton.tonalIcon(
            onPressed: () =>
                context.push('${AppDestinations.clients.path}/monthly-plans'),
            icon: const Icon(Icons.auto_awesome_rounded),
            label: const Text('Mesversários'),
          ),
          FilledButton.icon(
            onPressed: () =>
                context.push('${AppDestinations.clients.path}/new'),
            icon: const Icon(Icons.person_add_alt_1_rounded),
            label: const Text('Nova cliente'),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          allClientsAsync.when(
            loading: () =>
                const AppLoadingState(message: 'Carregando clientes...'),
            error: (error, stackTrace) => AppErrorState(
              title: 'Não foi possível carregar as clientes',
              message: 'Tente fechar e abrir a tela novamente.',
              actionLabel: 'Tentar de novo',
              onAction: () => ref.invalidate(allClientsProvider),
            ),
            data: (clients) => _ClientsSummaryCard(
              clients: clients,
              activeMonthlyPlans:
                  allMonthlyPlansAsync.asData?.value
                      .where((plan) => !plan.isCompleted)
                      .length ??
                  0,
            ),
          ),
          const SizedBox(height: 16),
          _ClientFiltersCard(filters: filters),
          const SizedBox(height: 16),
          filteredClientsAsync.when(
            loading: () =>
                const AppLoadingState(message: 'Atualizando a lista...'),
            error: (error, stackTrace) => AppErrorState(
              title: 'Não deu para montar a lista',
              message:
                  'As clientes continuam salvas localmente, mas a visualização falhou agora.',
              actionLabel: 'Recarregar',
              onAction: () => ref.invalidate(allClientsProvider),
            ),
            data: (clients) {
              if (clients.isEmpty) {
                return AppEmptyState(
                  icon: Icons.people_rounded,
                  title: filters.hasActiveFilters
                      ? 'Nenhuma cliente bate com essa busca'
                      : 'Nenhuma cliente salva ainda',
                  message: filters.hasActiveFilters
                      ? 'Tente outro termo para voltar a encontrar suas clientes.'
                      : 'Comece com um cadastro curto. Nome já resolve o básico e o restante pode vir depois.',
                  actionLabel: filters.hasActiveFilters
                      ? 'Limpar busca'
                      : 'Criar cliente',
                  onAction: () {
                    if (filters.hasActiveFilters) {
                      ref.read(clientListFiltersProvider.notifier).clear();
                      return;
                    }

                    context.push('${AppDestinations.clients.path}/new');
                  },
                );
              }

              return Column(
                children: [
                  for (var index = 0; index < clients.length; index++) ...[
                    _ClientListCard(
                      client: clients[index],
                      onTap: () => context.push(
                        '${AppDestinations.clients.path}/${clients[index].id}',
                      ),
                    ),
                    if (index != clients.length - 1) const SizedBox(height: 12),
                  ],
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _ClientsSummaryCard extends StatelessWidget {
  const _ClientsSummaryCard({
    required this.clients,
    required this.activeMonthlyPlans,
  });

  final List<ClientRecord> clients;
  final int activeMonthlyPlans;

  @override
  Widget build(BuildContext context) {
    final withPhone = clients
        .where((client) => client.phone?.trim().isNotEmpty ?? false)
        .length;
    final withImportantDates = clients
        .where((client) => client.importantDates.isNotEmpty)
        .length;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final compactLayout = constraints.maxWidth < 720;
            final itemWidth = compactLayout
                ? constraints.maxWidth
                : (constraints.maxWidth - 36) / 4;

            return Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                SizedBox(
                  width: itemWidth,
                  child: AppSummaryMetricCard(
                    label: 'Clientes salvas',
                    value: clients.length.toString(),
                  ),
                ),
                SizedBox(
                  width: itemWidth,
                  child: AppSummaryMetricCard(
                    label: 'Com telefone',
                    value: withPhone.toString(),
                  ),
                ),
                SizedBox(
                  width: itemWidth,
                  child: AppSummaryMetricCard(
                    label: 'Com datas importantes',
                    value: withImportantDates.toString(),
                  ),
                ),
                SizedBox(
                  width: itemWidth,
                  child: AppSummaryMetricCard(
                    label: 'Mesversários ativos',
                    value: activeMonthlyPlans.toString(),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _ClientFiltersCard extends ConsumerStatefulWidget {
  const _ClientFiltersCard({required this.filters});

  final ClientListFilters filters;

  @override
  ConsumerState<_ClientFiltersCard> createState() => _ClientFiltersCardState();
}

class _ClientFiltersCardState extends ConsumerState<_ClientFiltersCard> {
  late final TextEditingController _searchController;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController(text: widget.filters.searchQuery);
  }

  @override
  void didUpdateWidget(covariant _ClientFiltersCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_searchController.text != widget.filters.searchQuery) {
      _searchController.value = TextEditingValue(
        text: widget.filters.searchQuery,
        selection: TextSelection.collapsed(
          offset: widget.filters.searchQuery.length,
        ),
      );
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _searchController,
              onChanged: (value) {
                ref
                    .read(clientListFiltersProvider.notifier)
                    .updateSearchQuery(value);
              },
              decoration: const InputDecoration(
                hintText: 'Buscar por nome, telefone ou observação',
                prefixIcon: Icon(Icons.search_rounded),
              ),
            ),
            if (widget.filters.hasActiveFilters) ...[
              const SizedBox(height: 12),
              TextButton.icon(
                onPressed: () {
                  ref.read(clientListFiltersProvider.notifier).clear();
                },
                icon: const Icon(Icons.filter_alt_off_rounded),
                label: const Text('Limpar busca'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ClientListCard extends StatelessWidget {
  const _ClientListCard({required this.client, required this.onTap});

  final ClientRecord client;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(28),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(client.name, style: theme.textTheme.titleLarge),
                        const SizedBox(height: 6),
                        Text(
                          client.displayPhone,
                          style: theme.textTheme.bodyMedium,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  ClientRatingBadge(rating: client.rating),
                ],
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  _InfoPill(label: 'Endereço', value: client.displayAddress),
                  _InfoPill(
                    label: 'Próxima data',
                    value:
                        client.nextImportantDate?.displayDate ??
                        'Sem data importante',
                  ),
                ],
              ),
              if (client.notes?.trim().isNotEmpty ?? false) ...[
                const SizedBox(height: 16),
                Text(
                  client.notes!,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyMedium,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _InfoPill extends StatelessWidget {
  const _InfoPill({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label, style: theme.textTheme.labelMedium),
          const SizedBox(height: 4),
          Text(value, style: theme.textTheme.titleMedium),
        ],
      ),
    );
  }
}
