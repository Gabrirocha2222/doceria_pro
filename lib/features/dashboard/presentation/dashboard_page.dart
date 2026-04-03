import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/navigation/app_destinations.dart';
import '../../../core/bootstrap/app_bootstrap_state.dart';
import '../../../core/formatters/app_formatters.dart';
import '../../../core/responsive/app_breakpoints.dart';
import '../../../core/widgets/app_page_scaffold.dart';
import '../../../core/widgets/states/app_empty_state.dart';
import '../../../core/widgets/states/app_error_state.dart';
import '../../../core/widgets/states/app_loading_state.dart';
import '../../finance/application/finance_providers.dart';
import '../../ingredients/application/ingredient_providers.dart';
import '../../orders/application/order_providers.dart';
import '../../production/application/production_providers.dart';
import '../../purchases/application/purchase_providers.dart';
import '../application/dashboard_providers.dart';
import '../domain/dashboard.dart';

class DashboardPage extends ConsumerWidget {
  const DashboardPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bootstrapState = ref.watch(appBootstrapStateProvider);
    final snapshotAsync = ref.watch(dashboardSnapshotProvider);
    final today = DateTime.now();

    return AppPageScaffold(
      title: 'Hoje',
      subtitle:
          'O painel responde o que fazer agora, o que está em risco e como a semana anda.',
      trailing: FilledButton.icon(
        onPressed: () => context.push('${AppDestinations.orders.path}/new'),
        icon: const Icon(Icons.add_rounded),
        label: const Text('+ Novo pedido'),
      ),
      child: snapshotAsync.when(
        loading: () => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _DashboardHero(
              greetingTitle: _buildFallbackGreeting(today),
              greetingSubtitle:
                  'Estou organizando seus pedidos, produção, compras e financeiro para o resumo do dia.',
              attentionSummary: 'Montando a leitura principal da sua operação.',
              dateLabel: AppFormatters.weekdayAndDate(today),
              statusLabel: bootstrapState.statusLabel,
            ),
            const SizedBox(height: 16),
            const AppLoadingState(
              message: 'Preparando o painel diário do negócio...',
            ),
          ],
        ),
        error: (error, stackTrace) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _DashboardHero(
              greetingTitle: _buildFallbackGreeting(today),
              greetingSubtitle:
                  'Hoje eu começaria pelo que vence primeiro e pelo que ainda falta receber.',
              attentionSummary:
                  'O painel não abriu agora, mas seus dados continuam salvos no aparelho.',
              dateLabel: AppFormatters.weekdayAndDate(today),
              statusLabel: bootstrapState.statusLabel,
            ),
            const SizedBox(height: 16),
            AppErrorState(
              title: 'Não foi possível montar o dashboard',
              message:
                  'Tente recarregar para juntar pedidos, compras, produção e financeiro de novo.',
              actionLabel: 'Tentar de novo',
              onAction: () => _reloadDashboardData(ref),
            ),
          ],
        ),
        data: (snapshot) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _DashboardHero(
              greetingTitle: snapshot.greetingTitle,
              greetingSubtitle: snapshot.greetingSubtitle,
              attentionSummary: snapshot.attentionSummary,
              dateLabel: AppFormatters.weekdayAndDate(today),
              statusLabel: bootstrapState.statusLabel,
            ),
            const SizedBox(height: 16),
            _DashboardSummaryCards(
              cards: snapshot.summaryCards,
              onTap: (destination) => _openDestination(context, destination),
            ),
            const SizedBox(height: 20),
            LayoutBuilder(
              builder: (context, constraints) {
                final compactLayout = !AppBreakpoints.isExpandedWidth(
                  constraints.maxWidth,
                );
                final columnWidth = compactLayout
                    ? constraints.maxWidth
                    : (constraints.maxWidth - 16) / 2;

                final leftColumn = SizedBox(
                  width: columnWidth,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _SectionCard(
                        title: 'O que fazer hoje',
                        subtitle:
                            'Quatro frentes para você olhar primeiro, sem abrir cinco módulos para descobrir.',
                        child: Column(
                          children: [
                            for (
                              var index = 0;
                              index < snapshot.actions.length;
                              index++
                            ) ...[
                              _ActionRow(
                                item: snapshot.actions[index],
                                onTap: () => _openDestination(
                                  context,
                                  snapshot.actions[index].destination,
                                ),
                              ),
                              if (index != snapshot.actions.length - 1)
                                const Divider(height: 24),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      _SectionCard(
                        title: 'Agenda da semana',
                        subtitle:
                            'Uma visão curta do que já está marcado nos próximos dias.',
                        child: snapshot.weekAgenda.isEmpty
                            ? const AppEmptyState(
                                icon: Icons.event_available_outlined,
                                title: 'Nenhum pedido operacional na semana',
                                message:
                                    'Quando a agenda começar a encher, os próximos dias aparecem aqui em ordem.',
                              )
                            : Column(
                                children: [
                                  for (
                                    var index = 0;
                                    index < snapshot.weekAgenda.length;
                                    index++
                                  ) ...[
                                    _AgendaRow(
                                      entry: snapshot.weekAgenda[index],
                                      onTap: () => _openDestination(
                                        context,
                                        snapshot.weekAgenda[index].destination,
                                      ),
                                    ),
                                    if (index != snapshot.weekAgenda.length - 1)
                                      const Divider(height: 24),
                                  ],
                                ],
                              ),
                      ),
                    ],
                  ),
                );

                final rightColumn = SizedBox(
                  width: columnWidth,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _SectionCard(
                        title: 'Precisa de atenção',
                        subtitle:
                            'Alertas curtos para o que pode travar o dia ou a semana.',
                        child: snapshot.alerts.isEmpty
                            ? const AppEmptyState(
                                icon: Icons.favorite_border_rounded,
                                title: 'Sem alerta crítico agora',
                                message:
                                    'O dia parece sob controle. Vale seguir pela produção e pela agenda normal.',
                              )
                            : Column(
                                children: [
                                  for (
                                    var index = 0;
                                    index < snapshot.alerts.length;
                                    index++
                                  ) ...[
                                    _AlertRow(
                                      alert: snapshot.alerts[index],
                                      onTap: () => _openDestination(
                                        context,
                                        snapshot.alerts[index].destination,
                                      ),
                                    ),
                                    if (index != snapshot.alerts.length - 1)
                                      const Divider(height: 24),
                                  ],
                                ],
                              ),
                      ),
                      const SizedBox(height: 16),
                      _FinanceSummaryCard(
                        summary: snapshot.financeSummary,
                        onTap: () => _openDestination(
                          context,
                          DashboardDestination.finance,
                        ),
                      ),
                    ],
                  ),
                );

                if (compactLayout) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      leftColumn,
                      const SizedBox(height: 16),
                      rightColumn,
                    ],
                  );
                }

                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    leftColumn,
                    const SizedBox(width: 16),
                    rightColumn,
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  static void _reloadDashboardData(WidgetRef ref) {
    ref.invalidate(dashboardSnapshotProvider);
    ref.invalidate(lowStockIngredientsProvider);
    ref.invalidate(productionTasksProvider);
    ref.invalidate(purchaseChecklistProvider);
    ref.invalidate(ordersProvider);
    ref.invalidate(financeReceivablesProvider);
    ref.invalidate(financeExpensesProvider);
    ref.invalidate(financeManualEntriesProvider);
  }

  static void _openDestination(
    BuildContext context,
    DashboardDestination destination,
  ) {
    switch (destination) {
      case DashboardDestination.orders:
        context.go(AppDestinations.orders.path);
        return;
      case DashboardDestination.newOrder:
        context.push('${AppDestinations.orders.path}/new');
        return;
      case DashboardDestination.production:
        context.go(AppDestinations.production.path);
        return;
      case DashboardDestination.purchases:
        context.go(AppDestinations.purchases.path);
        return;
      case DashboardDestination.finance:
        context.go(AppDestinations.finance.path);
        return;
      case DashboardDestination.stock:
        context.go('${AppDestinations.purchases.path}/stock');
        return;
    }
  }
}

class _DashboardHero extends StatelessWidget {
  const _DashboardHero({
    required this.greetingTitle,
    required this.greetingSubtitle,
    required this.attentionSummary,
    required this.dateLabel,
    required this.statusLabel,
  });

  final String greetingTitle;
  final String greetingSubtitle;
  final String attentionSummary;
  final String dateLabel;
  final String statusLabel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

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
              _HeroChip(icon: Icons.calendar_today_outlined, label: dateLabel),
              _HeroChip(icon: Icons.cloud_done_outlined, label: statusLabel),
            ],
          ),
          const SizedBox(height: 18),
          Text(greetingTitle, style: theme.textTheme.headlineSmall),
          const SizedBox(height: 8),
          Text(greetingSubtitle, style: theme.textTheme.bodyLarge),
          const SizedBox(height: 16),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: theme.colorScheme.surface.withValues(alpha: 0.86),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: theme.colorScheme.outlineVariant),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.auto_awesome_rounded,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    attentionSummary,
                    style: theme.textTheme.titleMedium,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _HeroChip extends StatelessWidget {
  const _HeroChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Wrap(
        spacing: 8,
        runSpacing: 4,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Icon(icon, size: 18, color: theme.colorScheme.primary),
          Text(label, style: theme.textTheme.labelLarge),
        ],
      ),
    );
  }
}

class _DashboardSummaryCards extends StatelessWidget {
  const _DashboardSummaryCards({required this.cards, required this.onTap});

  final List<DashboardSummaryCardData> cards;
  final ValueChanged<DashboardDestination> onTap;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compactLayout = constraints.maxWidth < 760;
        final cardWidth = compactLayout
            ? constraints.maxWidth
            : (constraints.maxWidth - 36) / 4;

        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            for (final card in cards)
              SizedBox(
                width: cardWidth,
                child: _SummaryCard(
                  card: card,
                  onTap: () => onTap(card.destination),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.card, required this.onTap});

  final DashboardSummaryCardData card;
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
              Icon(_metricIcon(card.title), color: theme.colorScheme.primary),
              const SizedBox(height: 14),
              Text(card.title, style: theme.textTheme.titleMedium),
              const SizedBox(height: 10),
              Text(card.value, style: theme.textTheme.headlineSmall),
              const SizedBox(height: 8),
              Text(card.caption, style: theme.textTheme.bodyMedium),
            ],
          ),
        ),
      ),
    );
  }

  IconData _metricIcon(String title) {
    switch (title) {
      case 'Pedidos da semana':
        return Icons.receipt_long_rounded;
      case 'Lucro previsto':
        return Icons.trending_up_rounded;
      case 'Falta receber':
        return Icons.payments_outlined;
      case 'Materiais baixos':
        return Icons.inventory_2_outlined;
    }

    return Icons.auto_graph_rounded;
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.title,
    required this.subtitle,
    required this.child,
  });

  final String title;
  final String subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            Text(subtitle, style: Theme.of(context).textTheme.bodyMedium),
            const SizedBox(height: 16),
            child,
          ],
        ),
      ),
    );
  }
}

class _ActionRow extends StatelessWidget {
  const _ActionRow({required this.item, required this.onTap});

  final DashboardActionItem item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerLow,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(_actionIcon(item.destination)),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(item.title, style: theme.textTheme.titleMedium),
                  const SizedBox(height: 6),
                  Text(item.subtitle, style: theme.textTheme.bodyMedium),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(item.valueLabel, style: theme.textTheme.titleMedium),
                const SizedBox(height: 8),
                const Icon(Icons.chevron_right_rounded),
              ],
            ),
          ],
        ),
      ),
    );
  }

  IconData _actionIcon(DashboardDestination destination) {
    switch (destination) {
      case DashboardDestination.production:
        return Icons.bakery_dining_outlined;
      case DashboardDestination.orders:
      case DashboardDestination.newOrder:
        return Icons.receipt_long_outlined;
      case DashboardDestination.purchases:
      case DashboardDestination.stock:
        return Icons.shopping_bag_outlined;
      case DashboardDestination.finance:
        return Icons.account_balance_wallet_outlined;
    }
  }
}

class _AgendaRow extends StatelessWidget {
  const _AgendaRow({required this.entry, required this.onTap});

  final DashboardAgendaEntry entry;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(entry.label, style: theme.textTheme.titleMedium),
                  const SizedBox(height: 6),
                  Text(entry.subtitle, style: theme.textTheme.bodyMedium),
                ],
              ),
            ),
            const SizedBox(width: 16),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '${entry.orderCount} ${entry.orderCount == 1 ? 'pedido' : 'pedidos'}',
                  style: theme.textTheme.labelLarge,
                ),
                const SizedBox(height: 6),
                Text(
                  entry.totalAmount.format(),
                  style: theme.textTheme.titleMedium,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _AlertRow extends StatelessWidget {
  const _AlertRow({required this.alert, required this.onTap});

  final DashboardAlertItem alert;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _PriorityBadge(priority: alert.priority),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(alert.title, style: theme.textTheme.titleMedium),
                  const SizedBox(height: 6),
                  Text(alert.message, style: theme.textTheme.bodyMedium),
                ],
              ),
            ),
            const SizedBox(width: 12),
            const Icon(Icons.chevron_right_rounded),
          ],
        ),
      ),
    );
  }
}

class _PriorityBadge extends StatelessWidget {
  const _PriorityBadge({required this.priority});

  final DashboardAlertPriority priority;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final (backgroundColor, foregroundColor) = switch (priority) {
      DashboardAlertPriority.high => (
        theme.colorScheme.errorContainer,
        theme.colorScheme.onErrorContainer,
      ),
      DashboardAlertPriority.medium => (
        theme.colorScheme.tertiaryContainer,
        theme.colorScheme.onTertiaryContainer,
      ),
      DashboardAlertPriority.low => (
        theme.colorScheme.secondaryContainer,
        theme.colorScheme.onSecondaryContainer,
      ),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        priority.label,
        style: Theme.of(
          context,
        ).textTheme.labelLarge?.copyWith(color: foregroundColor),
      ),
    );
  }
}

class _FinanceSummaryCard extends StatelessWidget {
  const _FinanceSummaryCard({required this.summary, required this.onTap});

  final DashboardFinanceSummary summary;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
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
                children: [
                  const Icon(Icons.account_balance_wallet_outlined),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Financeiro rápido',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'O caixa de hoje e o que ainda falta receber sem sair do painel.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 16),
              LayoutBuilder(
                builder: (context, constraints) {
                  final compactLayout = constraints.maxWidth < 560;
                  final cardWidth = compactLayout
                      ? constraints.maxWidth
                      : (constraints.maxWidth - 12) / 2;

                  return Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      SizedBox(
                        width: cardWidth,
                        child: _FinanceMetricPill(
                          label: 'Entrou hoje',
                          value: summary.cashInToday.format(),
                        ),
                      ),
                      SizedBox(
                        width: cardWidth,
                        child: _FinanceMetricPill(
                          label: 'Saiu hoje',
                          value: summary.cashOutToday.format(),
                        ),
                      ),
                      SizedBox(
                        width: cardWidth,
                        child: _FinanceMetricPill(
                          label: 'Falta receber',
                          value: summary.pendingReceivables.format(),
                        ),
                      ),
                      SizedBox(
                        width: cardWidth,
                        child: _FinanceMetricPill(
                          label: 'Saídas preparadas',
                          value: summary.preparedExpenses.format(),
                        ),
                      ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 16),
              Text(summary.note, style: Theme.of(context).textTheme.bodyMedium),
            ],
          ),
        ),
      ),
    );
  }
}

class _FinanceMetricPill extends StatelessWidget {
  const _FinanceMetricPill({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(height: 8),
          Text(value, style: Theme.of(context).textTheme.titleMedium),
        ],
      ),
    );
  }
}

String _buildFallbackGreeting(DateTime now) {
  if (now.hour < 12) {
    return 'Bom dia';
  }
  if (now.hour < 18) {
    return 'Boa tarde';
  }

  return 'Boa noite';
}
