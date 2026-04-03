import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/navigation/app_destinations.dart';
import '../../../core/widgets/app_page_scaffold.dart';
import '../../../core/widgets/app_summary_metric_card.dart';
import '../../../core/widgets/states/app_empty_state.dart';
import '../../../core/widgets/states/app_error_state.dart';
import '../../../core/widgets/states/app_loading_state.dart';
import '../application/order_providers.dart';
import '../domain/order.dart';
import '../domain/order_list_filters.dart';
import '../domain/order_status.dart';
import 'widgets/order_list_card.dart';

class OrdersPage extends ConsumerWidget {
  const OrdersPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final allOrdersAsync = ref.watch(ordersProvider);
    final groupedOrdersAsync = ref.watch(groupedOrdersProvider);
    final filters = ref.watch(orderListFiltersProvider);

    return AppPageScaffold(
      title: 'Pedidos',
      subtitle:
          'Veja rápido o que precisa de atenção hoje e o que já pode seguir para o próximo passo.',
      trailing: FilledButton.icon(
        onPressed: () => context.push('${AppDestinations.orders.path}/new'),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Novo pedido'),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          allOrdersAsync.when(
            loading: () =>
                const AppLoadingState(message: 'Carregando pedidos...'),
            error: (error, stackTrace) => AppErrorState(
              title: 'Não foi possível carregar os pedidos',
              message: 'Tente fechar e abrir a tela novamente.',
              actionLabel: 'Tentar de novo',
              onAction: () => ref.invalidate(ordersProvider),
            ),
            data: (orders) => _OrdersSummaryCard(orders: orders),
          ),
          const SizedBox(height: 16),
          _OrderFiltersCard(filters: filters),
          const SizedBox(height: 16),
          groupedOrdersAsync.when(
            loading: () =>
                const AppLoadingState(message: 'Atualizando a lista...'),
            error: (error, stackTrace) => AppErrorState(
              title: 'Não foi possível montar a lista',
              message:
                  'Os pedidos estão salvos, mas a visualização falhou agora.',
              actionLabel: 'Recarregar',
              onAction: () => ref.invalidate(ordersProvider),
            ),
            data: (groups) {
              if (groups.isEmpty) {
                return AppEmptyState(
                  icon: Icons.receipt_long_rounded,
                  title: filters.hasActiveFilters
                      ? 'Nenhum pedido bate com esse filtro'
                      : 'Nenhum pedido salvo ainda',
                  message: filters.hasActiveFilters
                      ? 'Tente limpar a busca ou trocar o status para voltar a ver seus pedidos.'
                      : 'Comece com um pedido simples. Você pode salvar incompleto e ajustar depois.',
                  actionLabel: filters.hasActiveFilters
                      ? 'Limpar filtros'
                      : 'Criar pedido',
                  onAction: () {
                    if (filters.hasActiveFilters) {
                      ref.read(orderListFiltersProvider.notifier).clear();
                      return;
                    }

                    context.push('${AppDestinations.orders.path}/new');
                  },
                );
              }

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (final group in groups) ...[
                    _GroupHeader(group: group),
                    const SizedBox(height: 12),
                    Column(
                      children: [
                        for (
                          var index = 0;
                          index < group.orders.length;
                          index++
                        ) ...[
                          OrderListCard(
                            order: group.orders[index],
                            onTap: () => context.push(
                              '${AppDestinations.orders.path}/${group.orders[index].id}',
                            ),
                          ),
                          if (index != group.orders.length - 1)
                            const SizedBox(height: 12),
                        ],
                      ],
                    ),
                    const SizedBox(height: 20),
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

class _OrdersSummaryCard extends StatelessWidget {
  const _OrdersSummaryCard({required this.orders});

  final List<OrderRecord> orders;

  @override
  Widget build(BuildContext context) {
    final today = DateTime.now();
    final ordersForToday = orders.where((order) {
      final date = order.eventDate;
      return date != null &&
          date.year == today.year &&
          date.month == today.month &&
          date.day == today.day;
    }).length;
    final draftOrders = orders.where((order) => order.isDraft).length;
    final waitingDepositOrders = orders
        .where((order) => order.status == OrderStatus.awaitingDeposit)
        .length;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final compactLayout = constraints.maxWidth < 720;
            final itemWidth = compactLayout
                ? constraints.maxWidth
                : (constraints.maxWidth - 24) / 3;

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Resumo da operação',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 6),
                Text(
                  'Uma leitura rápida do que já entrou e do que ainda pede definição.',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    SizedBox(
                      width: itemWidth,
                      child: AppSummaryMetricCard(
                        label: 'Pedidos salvos',
                        value: orders.length.toString(),
                      ),
                    ),
                    SizedBox(
                      width: itemWidth,
                      child: AppSummaryMetricCard(
                        label: 'Para hoje',
                        value: ordersForToday.toString(),
                      ),
                    ),
                    SizedBox(
                      width: itemWidth,
                      child: AppSummaryMetricCard(
                        label: 'Aguardando sinal',
                        value: waitingDepositOrders.toString(),
                      ),
                    ),
                    SizedBox(
                      width: itemWidth,
                      child: AppSummaryMetricCard(
                        label: 'Incompletos',
                        value: draftOrders.toString(),
                      ),
                    ),
                  ],
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _OrderFiltersCard extends ConsumerStatefulWidget {
  const _OrderFiltersCard({required this.filters});

  final OrderListFilters filters;

  @override
  ConsumerState<_OrderFiltersCard> createState() => _OrderFiltersCardState();
}

class _OrderFiltersCardState extends ConsumerState<_OrderFiltersCard> {
  late final TextEditingController _searchController;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController(text: widget.filters.searchQuery);
  }

  @override
  void didUpdateWidget(covariant _OrderFiltersCard oldWidget) {
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
                    .read(orderListFiltersProvider.notifier)
                    .updateSearchQuery(value);
              },
              decoration: const InputDecoration(
                hintText: 'Buscar por cliente, observação ou data',
                prefixIcon: Icon(Icons.search_rounded),
              ),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ChoiceChip(
                  label: const Text('Todos'),
                  selected: widget.filters.status == null,
                  onSelected: (_) {
                    ref
                        .read(orderListFiltersProvider.notifier)
                        .updateStatus(null);
                  },
                ),
                for (final status in OrderStatus.values)
                  ChoiceChip(
                    label: Text(status.label),
                    selected: widget.filters.status == status,
                    onSelected: (_) {
                      ref
                          .read(orderListFiltersProvider.notifier)
                          .updateStatus(status);
                    },
                  ),
              ],
            ),
            if (widget.filters.hasActiveFilters) ...[
              const SizedBox(height: 12),
              TextButton.icon(
                onPressed: () {
                  ref.read(orderListFiltersProvider.notifier).clear();
                },
                icon: const Icon(Icons.filter_alt_off_rounded),
                label: const Text('Limpar filtros'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _GroupHeader extends StatelessWidget {
  const _GroupHeader({required this.group});

  final OrderDateGroup group;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
      children: [
        Expanded(child: Text(group.label, style: theme.textTheme.titleLarge)),
        const SizedBox(width: 12),
        Text('${group.orders.length}', style: theme.textTheme.labelLarge),
      ],
    );
  }
}
