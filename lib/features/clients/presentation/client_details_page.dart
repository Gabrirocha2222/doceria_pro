import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/navigation/app_destinations.dart';
import '../../../core/formatters/app_formatters.dart';
import '../../../core/widgets/app_page_scaffold.dart';
import '../../../core/widgets/states/app_empty_state.dart';
import '../../../core/widgets/states/app_error_state.dart';
import '../../../core/widgets/states/app_loading_state.dart';
import '../../monthly_plans/application/monthly_plan_providers.dart';
import '../../monthly_plans/domain/monthly_plan.dart';
import '../../orders/domain/order.dart';
import '../../orders/presentation/widgets/order_status_badge.dart';
import '../application/client_providers.dart';
import '../domain/client.dart';
import 'widgets/client_rating_badge.dart';

class ClientDetailsPage extends ConsumerWidget {
  const ClientDetailsPage({super.key, required this.clientId});

  final String clientId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final clientAsync = ref.watch(clientProvider(clientId));
    final orderHistoryAsync = ref.watch(clientOrderHistoryProvider(clientId));
    final monthlyPlansAsync = ref.watch(clientMonthlyPlansProvider(clientId));

    return clientAsync.when(
      loading: () => const AppPageScaffold(
        title: 'Carregando cliente',
        subtitle: 'Separando o perfil e o histórico local.',
        child: AppLoadingState(message: 'Carregando cliente...'),
      ),
      error: (error, stackTrace) => AppPageScaffold(
        title: 'Cliente indisponível',
        subtitle: 'Não foi possível abrir esta cliente agora.',
        child: AppErrorState(
          title: 'Não deu para abrir a cliente',
          message: 'Volte para a lista e tente novamente.',
          actionLabel: 'Voltar para clientes',
          onAction: () => context.go(AppDestinations.clients.path),
        ),
      ),
      data: (client) {
        if (client == null) {
          return AppPageScaffold(
            title: 'Cliente não encontrada',
            subtitle: 'Talvez esse cadastro não exista mais neste aparelho.',
            child: AppErrorState(
              title: 'Cliente não encontrada',
              message:
                  'Volte para a lista e confira os cadastros salvos localmente.',
              actionLabel: 'Voltar para clientes',
              onAction: () => context.go(AppDestinations.clients.path),
            ),
          );
        }

        return AppPageScaffold(
          title: 'Perfil da cliente',
          subtitle:
              'Contexto rápido para atender melhor sem virar um cadastro pesado.',
          trailing: Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              OutlinedButton.icon(
                onPressed: () => context.go(AppDestinations.clients.path),
                icon: const Icon(Icons.arrow_back_rounded),
                label: const Text('Voltar'),
              ),
              FilledButton.tonalIcon(
                onPressed: () => context.push(
                  '${AppDestinations.clients.path}/monthly-plans/new?clientId=${client.id}&clientName=${Uri.encodeComponent(client.name)}',
                ),
                icon: const Icon(Icons.auto_awesome_rounded),
                label: const Text('Novo mesversário'),
              ),
              FilledButton.tonalIcon(
                onPressed: () => context.push(
                  '${AppDestinations.clients.path}/${client.id}/edit',
                ),
                icon: const Icon(Icons.edit_rounded),
                label: const Text('Editar'),
              ),
            ],
          ),
          child: _ClientDetailsContent(
            client: client,
            orderHistoryAsync: orderHistoryAsync,
            monthlyPlansAsync: monthlyPlansAsync,
          ),
        );
      },
    );
  }
}

class _ClientDetailsContent extends StatelessWidget {
  const _ClientDetailsContent({
    required this.client,
    required this.orderHistoryAsync,
    required this.monthlyPlansAsync,
  });

  final ClientRecord client;
  final AsyncValue<List<OrderRecord>> orderHistoryAsync;
  final AsyncValue<List<MonthlyPlanRecord>> monthlyPlansAsync;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _ClientHeroCard(
          client: client,
          orderHistoryAsync: orderHistoryAsync,
          monthlyPlansAsync: monthlyPlansAsync,
        ),
        const SizedBox(height: 16),
        LayoutBuilder(
          builder: (context, constraints) {
            final compactLayout = constraints.maxWidth < 760;
            final cardWidth = compactLayout
                ? constraints.maxWidth
                : (constraints.maxWidth - 12) / 2;

            return Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                SizedBox(
                  width: cardWidth,
                  child: _DetailsCard(
                    title: 'Contato',
                    content: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _LabelValueRow(
                          label: 'Telefone',
                          value: client.displayPhone,
                        ),
                        const SizedBox(height: 12),
                        _LabelValueRow(
                          label: 'Endereço',
                          value: client.displayAddress,
                        ),
                      ],
                    ),
                  ),
                ),
                SizedBox(
                  width: cardWidth,
                  child: _DetailsCard(
                    title: 'Observações',
                    content: Text(
                      client.displayNotes,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ),
                ),
                SizedBox(
                  width: constraints.maxWidth,
                  child: _ImportantDatesCard(client: client),
                ),
                SizedBox(
                  width: constraints.maxWidth,
                  child: _MonthlyPlansCard(
                    client: client,
                    monthlyPlansAsync: monthlyPlansAsync,
                  ),
                ),
                SizedBox(
                  width: constraints.maxWidth,
                  child: _OrderHistoryCard(
                    orderHistoryAsync: orderHistoryAsync,
                  ),
                ),
              ],
            );
          },
        ),
      ],
    );
  }
}

class _ClientHeroCard extends StatelessWidget {
  const _ClientHeroCard({
    required this.client,
    required this.orderHistoryAsync,
    required this.monthlyPlansAsync,
  });

  final ClientRecord client;
  final AsyncValue<List<OrderRecord>> orderHistoryAsync;
  final AsyncValue<List<MonthlyPlanRecord>> monthlyPlansAsync;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final orderCount = orderHistoryAsync.asData?.value.length;
    final monthlyPlanCount = monthlyPlansAsync.asData?.value.length;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(32),
        gradient: LinearGradient(
          colors: [
            theme.colorScheme.primaryContainer,
            theme.colorScheme.surface,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              ClientRatingBadge(rating: client.rating),
              if (client.nextImportantDate != null)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surface,
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: theme.colorScheme.outlineVariant),
                  ),
                  child: Text(
                    '${client.nextImportantDate!.label} • ${client.nextImportantDate!.displayDate}',
                    style: theme.textTheme.labelLarge,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          Text(client.name, style: theme.textTheme.headlineSmall),
          const SizedBox(height: 6),
          Text(client.displayPhone, style: theme.textTheme.bodyLarge),
          const SizedBox(height: 20),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _HeroMetric(
                label: 'Pedidos ligados',
                value: orderCount?.toString() ?? '...',
              ),
              _HeroMetric(
                label: 'Mesversários',
                value: monthlyPlanCount?.toString() ?? '...',
              ),
              _HeroMetric(
                label: 'Atualizado em',
                value: AppFormatters.dayMonthYear(client.updatedAt),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MonthlyPlansCard extends StatelessWidget {
  const _MonthlyPlansCard({
    required this.client,
    required this.monthlyPlansAsync,
  });

  final ClientRecord client;
  final AsyncValue<List<MonthlyPlanRecord>> monthlyPlansAsync;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Mesversários', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            Text(
              'Planos recorrentes desta cliente ficam separados do catálogo e do histórico comum de pedidos.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 16),
            monthlyPlansAsync.when(
              loading: () => const AppLoadingState(
                message: 'Carregando mesversários da cliente...',
              ),
              error: (error, stackTrace) => AppErrorState(
                title: 'Não foi possível abrir os mesversários',
                message: 'Tente novamente em alguns instantes.',
                actionLabel: 'Abrir lista geral',
                onAction: () => context.push(
                  '${AppDestinations.clients.path}/monthly-plans',
                ),
              ),
              data: (plans) {
                if (plans.isEmpty) {
                  return AppEmptyState(
                    icon: Icons.auto_awesome_outlined,
                    title: 'Nenhum mesversário ligado ainda',
                    message:
                        'Quando esta cliente fechar um plano recorrente, ele aparece aqui com saldo e histórico mensal.',
                    actionLabel: 'Criar mesversário',
                    onAction: () => context.push(
                      '${AppDestinations.clients.path}/monthly-plans/new?clientId=${client.id}&clientName=${Uri.encodeComponent(client.name)}',
                    ),
                  );
                }

                return Column(
                  children: [
                    for (var index = 0; index < plans.length; index++) ...[
                      _ClientMonthlyPlanTile(plan: plans[index]),
                      if (index != plans.length - 1) const SizedBox(height: 12),
                    ],
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _ClientMonthlyPlanTile extends StatelessWidget {
  const _ClientMonthlyPlanTile({required this.plan});

  final MonthlyPlanRecord plan;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  plan.title,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 6),
                Text(
                  '${plan.numberOfMonths} meses • saldo ${plan.remainingBalance} • ${plan.estimatedMonthlyTotal.format()} por mês',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          FilledButton.tonalIcon(
            onPressed: () => context.push(
              '${AppDestinations.clients.path}/monthly-plans/${plan.id}',
            ),
            icon: const Icon(Icons.chevron_right_rounded),
            label: const Text('Abrir'),
          ),
        ],
      ),
    );
  }
}

class _HeroMetric extends StatelessWidget {
  const _HeroMetric({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: theme.textTheme.labelLarge),
          const SizedBox(height: 6),
          Text(value, style: theme.textTheme.titleLarge),
        ],
      ),
    );
  }
}

class _DetailsCard extends StatelessWidget {
  const _DetailsCard({required this.title, required this.content});

  final String title;
  final Widget content;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 16),
            content,
          ],
        ),
      ),
    );
  }
}

class _LabelValueRow extends StatelessWidget {
  const _LabelValueRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: Theme.of(context).textTheme.labelLarge),
        const SizedBox(height: 4),
        Text(value, style: Theme.of(context).textTheme.bodyMedium),
      ],
    );
  }
}

class _ImportantDatesCard extends StatelessWidget {
  const _ImportantDatesCard({required this.client});

  final ClientRecord client;

  @override
  Widget build(BuildContext context) {
    return _DetailsCard(
      title: 'Datas importantes',
      content: client.importantDates.isEmpty
          ? Text(
              'Nenhuma data importante registrada ainda.',
              style: Theme.of(context).textTheme.bodyMedium,
            )
          : Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                for (final importantDate in client.importantDates)
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surfaceContainerLow,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          importantDate.label,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 6),
                        Text(
                          importantDate.displayDate,
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ],
                    ),
                  ),
              ],
            ),
    );
  }
}

class _OrderHistoryCard extends StatelessWidget {
  const _OrderHistoryCard({required this.orderHistoryAsync});

  final AsyncValue<List<OrderRecord>> orderHistoryAsync;

  @override
  Widget build(BuildContext context) {
    return _DetailsCard(
      title: 'Histórico de pedidos',
      content: orderHistoryAsync.when(
        loading: () =>
            const AppLoadingState(message: 'Carregando histórico...'),
        error: (error, stackTrace) =>
            const Text('Não foi possível carregar o histórico agora.'),
        data: (orders) {
          if (orders.isEmpty) {
            return const AppEmptyState(
              icon: Icons.receipt_long_rounded,
              title: 'Ainda não há pedidos ligados',
              message:
                  'Quando um pedido for salvo com esta cliente vinculada, ele aparece aqui.',
            );
          }

          return Column(
            children: [
              for (var index = 0; index < orders.length; index++) ...[
                _OrderHistoryRow(order: orders[index]),
                if (index != orders.length - 1) const SizedBox(height: 12),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _OrderHistoryRow extends StatelessWidget {
  const _OrderHistoryRow({required this.order});

  final OrderRecord order;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(20),
      ),
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
                    Text(
                      order.displayClientName,
                      style: theme.textTheme.titleMedium,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      order.eventDate == null
                          ? 'Sem data definida'
                          : AppFormatters.dayMonthYear(order.eventDate!),
                      style: theme.textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              OrderStatusBadge(status: order.status),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              Text('Total: ${order.orderTotal.format()}'),
              Text('Entrou: ${order.receivedAmount.format()}'),
              Text('Restante: ${order.remainingAmount.format()}'),
            ],
          ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: () =>
                  context.push('${AppDestinations.orders.path}/${order.id}'),
              icon: const Icon(Icons.open_in_new_rounded),
              label: const Text('Abrir pedido'),
            ),
          ),
        ],
      ),
    );
  }
}
