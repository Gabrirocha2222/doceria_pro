import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/navigation/app_destinations.dart';
import '../../../core/formatters/app_formatters.dart';
import '../../../core/widgets/app_page_scaffold.dart';
import '../../../core/widgets/app_summary_metric_card.dart';
import '../../../core/widgets/states/app_empty_state.dart';
import '../../../core/widgets/states/app_error_state.dart';
import '../../../core/widgets/states/app_loading_state.dart';
import '../application/monthly_plan_providers.dart';
import '../domain/monthly_plan.dart';
import '../domain/monthly_plan_list_filters.dart';

class MonthlyPlansPage extends ConsumerWidget {
  const MonthlyPlansPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final allPlansAsync = ref.watch(allMonthlyPlansProvider);
    final filteredPlansAsync = ref.watch(filteredMonthlyPlansProvider);
    final filters = ref.watch(monthlyPlanListFiltersProvider);

    return AppPageScaffold(
      title: 'Mesversários',
      subtitle:
          'Organize recorrência, saldo e próximos rascunhos sem misturar isso com o catálogo de produtos.',
      trailing: Wrap(
        spacing: 12,
        runSpacing: 12,
        children: [
          OutlinedButton.icon(
            onPressed: () => context.go(AppDestinations.clients.path),
            icon: const Icon(Icons.arrow_back_rounded),
            label: const Text('Voltar para clientes'),
          ),
          FilledButton.icon(
            onPressed: () => context.push(
              '${AppDestinations.clients.path}/monthly-plans/new',
            ),
            icon: const Icon(Icons.auto_awesome_rounded),
            label: const Text('Novo mesversário'),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          allPlansAsync.when(
            loading: () =>
                const AppLoadingState(message: 'Carregando mesversários...'),
            error: (error, stackTrace) => AppErrorState(
              title: 'Não foi possível carregar os mesversários',
              message: 'Tente abrir a tela novamente em alguns instantes.',
              actionLabel: 'Tentar de novo',
              onAction: () => ref.invalidate(allMonthlyPlansProvider),
            ),
            data: (plans) => _MonthlyPlanSummaryCard(plans: plans),
          ),
          const SizedBox(height: 16),
          _MonthlyPlanFiltersCard(filters: filters),
          const SizedBox(height: 16),
          filteredPlansAsync.when(
            loading: () =>
                const AppLoadingState(message: 'Atualizando a lista...'),
            error: (error, stackTrace) => AppErrorState(
              title: 'A lista não pôde ser montada agora',
              message:
                  'Os dados continuam salvos no aparelho, mas esta visualização falhou por enquanto.',
              actionLabel: 'Recarregar',
              onAction: () => ref.invalidate(allMonthlyPlansProvider),
            ),
            data: (plans) {
              if (plans.isEmpty) {
                return AppEmptyState(
                  icon: Icons.cake_rounded,
                  title: filters.hasActiveFilters
                      ? 'Nenhum plano bate com essa busca'
                      : 'Nenhum mesversário salvo ainda',
                  message: filters.hasActiveFilters
                      ? 'Tente outro termo ou volte para os planos em andamento.'
                      : 'Comece com um plano recorrente e deixe o app cuidar do histórico mês a mês.',
                  actionLabel: filters.hasActiveFilters
                      ? 'Limpar filtros'
                      : 'Criar mesversário',
                  onAction: () {
                    if (filters.hasActiveFilters) {
                      ref.read(monthlyPlanListFiltersProvider.notifier).clear();
                      return;
                    }

                    context.push(
                      '${AppDestinations.clients.path}/monthly-plans/new',
                    );
                  },
                );
              }

              return Column(
                children: [
                  for (var index = 0; index < plans.length; index++) ...[
                    _MonthlyPlanListCard(plan: plans[index]),
                    if (index != plans.length - 1) const SizedBox(height: 12),
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

class _MonthlyPlanSummaryCard extends StatelessWidget {
  const _MonthlyPlanSummaryCard({required this.plans});

  final List<MonthlyPlanRecord> plans;

  @override
  Widget build(BuildContext context) {
    final activePlans = plans.where((plan) => !plan.isCompleted).length;
    final readyToGenerate = plans.fold<int>(
      0,
      (total, plan) => total + plan.availableToGenerateCount,
    );
    final remainingBalance = plans.fold<int>(
      0,
      (total, plan) => total + plan.remainingBalance,
    );
    final generatedDrafts = plans.fold<int>(
      0,
      (total, plan) => total + plan.generatedOccurrenceCount,
    );

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final compactLayout = constraints.maxWidth < 900;
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
                    label: 'Planos em andamento',
                    value: activePlans.toString(),
                  ),
                ),
                SizedBox(
                  width: itemWidth,
                  child: AppSummaryMetricCard(
                    label: 'Saldo restante',
                    value: remainingBalance.toString(),
                  ),
                ),
                SizedBox(
                  width: itemWidth,
                  child: AppSummaryMetricCard(
                    label: 'Pode gerar agora',
                    value: readyToGenerate.toString(),
                  ),
                ),
                SizedBox(
                  width: itemWidth,
                  child: AppSummaryMetricCard(
                    label: 'Rascunhos já criados',
                    value: generatedDrafts.toString(),
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

class _MonthlyPlanFiltersCard extends ConsumerStatefulWidget {
  const _MonthlyPlanFiltersCard({required this.filters});

  final MonthlyPlanListFilters filters;

  @override
  ConsumerState<_MonthlyPlanFiltersCard> createState() =>
      _MonthlyPlanFiltersCardState();
}

class _MonthlyPlanFiltersCardState
    extends ConsumerState<_MonthlyPlanFiltersCard> {
  late final TextEditingController _searchController;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController(text: widget.filters.searchQuery);
  }

  @override
  void didUpdateWidget(covariant _MonthlyPlanFiltersCard oldWidget) {
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
    final notifier = ref.read(monthlyPlanListFiltersProvider.notifier);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _searchController,
              onChanged: notifier.updateSearchQuery,
              decoration: const InputDecoration(
                hintText: 'Buscar por nome do plano, cliente ou modelo base',
                prefixIcon: Icon(Icons.search_rounded),
              ),
            ),
            const SizedBox(height: 16),
            Text('Mostrar', style: Theme.of(context).textTheme.labelLarge),
            const SizedBox(height: 12),
            SegmentedButton<MonthlyPlanStateFilter>(
              selected: {widget.filters.stateFilter},
              showSelectedIcon: false,
              segments: const [
                ButtonSegment(
                  value: MonthlyPlanStateFilter.active,
                  label: Text('Em andamento'),
                ),
                ButtonSegment(
                  value: MonthlyPlanStateFilter.completed,
                  label: Text('Concluídos'),
                ),
                ButtonSegment(
                  value: MonthlyPlanStateFilter.all,
                  label: Text('Todos'),
                ),
              ],
              onSelectionChanged: (selection) {
                notifier.updateStateFilter(selection.first);
              },
            ),
            if (widget.filters.hasActiveFilters) ...[
              const SizedBox(height: 12),
              TextButton.icon(
                onPressed: notifier.clear,
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

class _MonthlyPlanListCard extends StatelessWidget {
  const _MonthlyPlanListCard({required this.plan});

  final MonthlyPlanRecord plan;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(28),
        onTap: () => context.push(
          '${AppDestinations.clients.path}/monthly-plans/${plan.id}',
        ),
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
                        Text(plan.title, style: theme.textTheme.titleLarge),
                        const SizedBox(height: 6),
                        Text(
                          plan.clientNameSnapshot,
                          style: theme.textTheme.bodyLarge,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  _PlanStateChip(isCompleted: plan.isCompleted),
                ],
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _InfoChip(
                    icon: Icons.autorenew_rounded,
                    label: '${plan.numberOfMonths} meses',
                  ),
                  _InfoChip(
                    icon: Icons.layers_outlined,
                    label: 'Saldo ${plan.remainingBalance}',
                  ),
                  _InfoChip(
                    icon: Icons.inventory_2_outlined,
                    label: '${plan.estimatedItemCount} itens por mês',
                  ),
                  _InfoChip(
                    icon: Icons.payments_outlined,
                    label: plan.estimatedMonthlyTotal.format(),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              LayoutBuilder(
                builder: (context, constraints) {
                  final compactLayout = constraints.maxWidth < 760;
                  final itemWidth = compactLayout
                      ? constraints.maxWidth
                      : (constraints.maxWidth - 12) / 2;

                  return Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      SizedBox(
                        width: itemWidth,
                        child: _DetailBlock(
                          label: 'Modelo base',
                          value: plan.displayTemplateProductName,
                        ),
                      ),
                      SizedBox(
                        width: itemWidth,
                        child: _DetailBlock(
                          label: 'Próximo mês previsto',
                          value: plan.sortedHistory.isEmpty
                              ? 'Sem histórico montado'
                              : AppFormatters.dayMonthYear(
                                  plan.sortedHistory.first.scheduledDate,
                                ),
                        ),
                      ),
                    ],
                  );
                },
              ),
              if (plan.availableToGenerateCount > 0) ...[
                const SizedBox(height: 16),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.secondaryContainer,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    'Hoje dá para gerar ${plan.availableToGenerateCount} rascunho(s) novo(s) sem estourar o saldo contratado.',
                    style: theme.textTheme.bodyMedium,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _PlanStateChip extends StatelessWidget {
  const _PlanStateChip({required this.isCompleted});

  final bool isCompleted;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = isCompleted
        ? theme.colorScheme.tertiary
        : theme.colorScheme.primary;
    final background = isCompleted
        ? theme.colorScheme.tertiaryContainer
        : theme.colorScheme.primaryContainer;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        isCompleted ? 'Concluído' : 'Em andamento',
        style: theme.textTheme.labelLarge?.copyWith(color: color),
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  const _InfoChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: theme.colorScheme.primary),
          const SizedBox(width: 8),
          Text(label, style: theme.textTheme.labelLarge),
        ],
      ),
    );
  }
}

class _DetailBlock extends StatelessWidget {
  const _DetailBlock({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(height: 6),
          Text(value, style: Theme.of(context).textTheme.bodyMedium),
        ],
      ),
    );
  }
}
