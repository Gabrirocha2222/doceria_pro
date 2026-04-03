import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/navigation/app_destinations.dart';
import '../../../core/responsive/app_breakpoints.dart';
import '../../../core/widgets/app_page_scaffold.dart';
import '../../../core/widgets/app_summary_metric_card.dart';
import '../../../core/widgets/states/app_empty_state.dart';
import '../../../core/widgets/states/app_error_state.dart';
import '../../../core/widgets/states/app_loading_state.dart';
import '../../orders/domain/order.dart';
import '../application/production_providers.dart';
import '../domain/production_filters.dart';
import '../domain/production_task.dart';

class ProductionPage extends ConsumerStatefulWidget {
  const ProductionPage({super.key});

  @override
  ConsumerState<ProductionPage> createState() => _ProductionPageState();
}

class _ProductionPageState extends ConsumerState<ProductionPage> {
  final Set<String> _updatingPlanIds = <String>{};

  @override
  Widget build(BuildContext context) {
    final filters = ref.watch(productionFiltersProvider);
    final filteredTasksAsync = ref.watch(filteredProductionTasksProvider);
    final groupedTasksAsync = ref.watch(groupedProductionTasksProvider);

    return AppPageScaffold(
      title: 'Produção',
      subtitle:
          'Veja o que precisa sair hoje e nesta semana sem lançar tudo duas vezes.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          filteredTasksAsync.when(
            loading: () =>
                const AppLoadingState(message: 'Carregando produção...'),
            error: (error, stackTrace) => AppErrorState(
              title: 'Não foi possível montar a produção',
              message: 'Tente abrir a tela novamente em alguns instantes.',
              actionLabel: 'Tentar de novo',
              onAction: () => ref.invalidate(productionTasksProvider),
            ),
            data: (tasks) => _ProductionSummaryCard(tasks: tasks),
          ),
          const SizedBox(height: 16),
          _ProductionFiltersCard(filters: filters),
          const SizedBox(height: 16),
          const _ProjectedDemandInfoCard(),
          const SizedBox(height: 16),
          groupedTasksAsync.when(
            loading: () =>
                const AppLoadingState(message: 'Atualizando agenda...'),
            error: (error, stackTrace) => AppErrorState(
              title: 'Não foi possível carregar a agenda',
              message:
                  'Os registros locais existem, mas a visualização falhou agora.',
              actionLabel: 'Recarregar',
              onAction: () => ref.invalidate(productionTasksProvider),
            ),
            data: (groups) {
              if (groups.isEmpty) {
                return AppEmptyState(
                  icon: Icons.bakery_dining_rounded,
                  title: filters.timeframe == ProductionTimeframe.today
                      ? 'Nada pendente para hoje'
                      : 'Nada programado para esta semana',
                  message: filters.timeframe == ProductionTimeframe.today
                      ? 'Quando pedidos confirmados gerarem etapas com prazo para hoje, elas aparecem aqui automaticamente.'
                      : 'As etapas da semana vão entrando aqui conforme os pedidos forem confirmados.',
                );
              }

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (final group in groups) ...[
                    _TaskGroupCard(
                      group: group,
                      isPlanUpdating: (planId) =>
                          _updatingPlanIds.contains(planId),
                      onChangeStatus: _changePlanStatus,
                    ),
                    const SizedBox(height: 16),
                  ],
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Future<void> _changePlanStatus(
    ProductionTaskRecord task,
    OrderProductionPlanStatus status,
  ) async {
    if (_updatingPlanIds.contains(task.plan.id)) {
      return;
    }

    setState(() => _updatingPlanIds.add(task.plan.id));

    try {
      await ref
          .read(productionRepositoryProvider)
          .updatePlanStatus(planId: task.plan.id, status: status);

      if (!mounted) {
        return;
      }

      final message = switch (status) {
        OrderProductionPlanStatus.pending =>
          'Etapa marcada como pendente neste aparelho.',
        OrderProductionPlanStatus.inProduction => 'Etapa colocada em produção.',
        OrderProductionPlanStatus.completed =>
          task.materialCount == 0
              ? 'Etapa concluída e registrada.'
              : 'Etapa concluída com baixa rastreável aplicada quando havia consumo real.',
      };

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    } catch (_) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            status == OrderProductionPlanStatus.completed
                ? 'Não foi possível concluir esta etapa agora. Revise o estoque antes de finalizar.'
                : 'Não foi possível atualizar o status desta etapa.',
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _updatingPlanIds.remove(task.plan.id));
      }
    }
  }
}

class _ProductionSummaryCard extends StatelessWidget {
  const _ProductionSummaryCard({required this.tasks});

  final List<ProductionTaskRecord> tasks;

  @override
  Widget build(BuildContext context) {
    final pendingCount = tasks
        .where((task) => task.plan.status == OrderProductionPlanStatus.pending)
        .length;
    final inProductionCount = tasks
        .where(
          (task) => task.plan.status == OrderProductionPlanStatus.inProduction,
        )
        .length;
    final completedCount = tasks
        .where(
          (task) => task.plan.status == OrderProductionPlanStatus.completed,
        )
        .length;
    final shortageCount = tasks.where((task) => task.hasShortage).length;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final compactLayout = AppBreakpoints.isCompactWidth(
              constraints.maxWidth,
            );
            final itemWidth = compactLayout
                ? constraints.maxWidth
                : (constraints.maxWidth - 24) / 3;

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Leitura rápida da produção',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 6),
                Text(
                  'Uma visão curta do que ainda pede ação e do que já foi concluído.',
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
                        label: 'Pendentes',
                        value: pendingCount.toString(),
                      ),
                    ),
                    SizedBox(
                      width: itemWidth,
                      child: AppSummaryMetricCard(
                        label: 'Em produção',
                        value: inProductionCount.toString(),
                      ),
                    ),
                    SizedBox(
                      width: itemWidth,
                      child: AppSummaryMetricCard(
                        label: 'Concluídas',
                        value: completedCount.toString(),
                      ),
                    ),
                    SizedBox(
                      width: itemWidth,
                      child: AppSummaryMetricCard(
                        label: 'Com falta prevista',
                        value: shortageCount.toString(),
                        attention: shortageCount > 0,
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

class _ProductionFiltersCard extends ConsumerWidget {
  const _ProductionFiltersCard({required this.filters});

  final ProductionFilters filters;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Como olhar a fila',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            LayoutBuilder(
              builder: (context, constraints) {
                final compactLayout = constraints.maxWidth < 720;

                if (compactLayout) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _FilterSegmentedButton<ProductionTimeframe>(
                        label: 'Período',
                        value: filters.timeframe,
                        values: ProductionTimeframe.values,
                        onChanged: (value) {
                          ref
                              .read(productionFiltersProvider.notifier)
                              .updateTimeframe(value);
                        },
                      ),
                      const SizedBox(height: 16),
                      _FilterSegmentedButton<ProductionGrouping>(
                        label: 'Agrupar por',
                        value: filters.grouping,
                        values: ProductionGrouping.values,
                        onChanged: (value) {
                          ref
                              .read(productionFiltersProvider.notifier)
                              .updateGrouping(value);
                        },
                      ),
                    ],
                  );
                }

                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: _FilterSegmentedButton<ProductionTimeframe>(
                        label: 'Período',
                        value: filters.timeframe,
                        values: ProductionTimeframe.values,
                        onChanged: (value) {
                          ref
                              .read(productionFiltersProvider.notifier)
                              .updateTimeframe(value);
                        },
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _FilterSegmentedButton<ProductionGrouping>(
                        label: 'Agrupar por',
                        value: filters.grouping,
                        values: ProductionGrouping.values,
                        onChanged: (value) {
                          ref
                              .read(productionFiltersProvider.notifier)
                              .updateGrouping(value);
                        },
                      ),
                    ),
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

class _FilterSegmentedButton<T> extends StatelessWidget {
  const _FilterSegmentedButton({
    required this.label,
    required this.value,
    required this.values,
    required this.onChanged,
  });

  final String label;
  final T value;
  final List<T> values;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: Theme.of(context).textTheme.labelLarge),
        const SizedBox(height: 10),
        SegmentedButton<T>(
          selected: {value},
          showSelectedIcon: false,
          segments: [
            for (final item in values)
              ButtonSegment<T>(value: item, label: Text(_segmentLabel(item))),
          ],
          onSelectionChanged: (selection) {
            if (selection.isNotEmpty) {
              onChanged(selection.first);
            }
          },
        ),
      ],
    );
  }

  String _segmentLabel(T item) {
    if (item is ProductionTimeframe) {
      return item.label;
    }
    if (item is ProductionGrouping) {
      return item.label;
    }

    return item.toString();
  }
}

class _ProjectedDemandInfoCard extends StatelessWidget {
  const _ProjectedDemandInfoCard();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.secondaryContainer,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline_rounded, color: theme.colorScheme.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'As necessidades aqui funcionam como demanda projetada. A baixa real de estoque só acontece na conclusão da etapa certa e uma única vez.',
              style: theme.textTheme.bodyMedium,
            ),
          ),
        ],
      ),
    );
  }
}

class _TaskGroupCard extends StatelessWidget {
  const _TaskGroupCard({
    required this.group,
    required this.isPlanUpdating,
    required this.onChangeStatus,
  });

  final ProductionTaskGroup group;
  final bool Function(String planId) isPlanUpdating;
  final Future<void> Function(
    ProductionTaskRecord task,
    OrderProductionPlanStatus status,
  )
  onChangeStatus;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(group.label, style: theme.textTheme.titleLarge),
            if (group.subtitle.trim().isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(group.subtitle, style: theme.textTheme.bodyMedium),
            ],
            const SizedBox(height: 16),
            for (var index = 0; index < group.tasks.length; index++) ...[
              _ProductionTaskCard(
                task: group.tasks[index],
                isUpdating: isPlanUpdating(group.tasks[index].plan.id),
                onChangeStatus: onChangeStatus,
              ),
              if (index != group.tasks.length - 1) const SizedBox(height: 12),
            ],
          ],
        ),
      ),
    );
  }
}

class _ProductionTaskCard extends StatelessWidget {
  const _ProductionTaskCard({
    required this.task,
    required this.isUpdating,
    required this.onChangeStatus,
  });

  final ProductionTaskRecord task;
  final bool isUpdating;
  final Future<void> Function(
    ProductionTaskRecord task,
    OrderProductionPlanStatus status,
  )
  onChangeStatus;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: theme.colorScheme.outlineVariant),
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
                    Text(task.plan.title, style: theme.textTheme.titleMedium),
                    const SizedBox(height: 6),
                    Text(
                      '${task.displayItemLabel} • ${task.displayClientName}',
                      style: theme.textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              _ProductionStatusPill(status: task.plan.status),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _TaskInfoPill(label: task.plan.planType.label),
              _TaskInfoPill(label: task.displayDeadline),
              _TaskInfoPill(
                label:
                    '${task.plan.quantity} ${task.plan.quantity == 1 ? 'un' : 'un'}',
              ),
              if (task.materialCount > 0)
                _TaskInfoPill(
                  label:
                      '${task.materialCount} ${task.materialCount == 1 ? 'material' : 'materiais'}',
                ),
              if (task.hasShortage)
                _TaskInfoPill(
                  label:
                      '${task.shortageCount} ${task.shortageCount == 1 ? 'falta prevista' : 'faltas previstas'}',
                  attention: true,
                ),
              if (task.stockEffectApplied)
                const _TaskInfoPill(label: 'Baixa registrada'),
            ],
          ),
          if (task.hasNotes) ...[
            const SizedBox(height: 12),
            Text(
              task.displayNotes,
              style: theme.textTheme.bodyMedium,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
          ],
          if (task.relatedMaterialNeeds.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(_buildMaterialLine(task), style: theme.textTheme.bodySmall),
          ],
          const SizedBox(height: 16),
          LayoutBuilder(
            builder: (context, constraints) {
              final compactLayout = constraints.maxWidth < 680;

              final statusSelector = Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final status in OrderProductionPlanStatus.values)
                    ChoiceChip(
                      label: Text(status.label),
                      selected: task.plan.status == status,
                      onSelected: isUpdating
                          ? null
                          : (_) => onChangeStatus(task, status),
                    ),
                ],
              );

              final actions = Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  OutlinedButton.icon(
                    onPressed: () => context.push(
                      '${AppDestinations.orders.path}/${task.orderId}',
                    ),
                    icon: const Icon(Icons.receipt_long_outlined),
                    label: const Text('Abrir pedido'),
                  ),
                  if (isUpdating)
                    const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2.2),
                    ),
                ],
              );

              if (compactLayout) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    statusSelector,
                    const SizedBox(height: 12),
                    actions,
                  ],
                );
              }

              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: statusSelector),
                  const SizedBox(width: 12),
                  actions,
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  String _buildMaterialLine(ProductionTaskRecord task) {
    final pendingNeeds = task.relatedMaterialNeeds
        .where((need) => !need.isConsumed)
        .toList(growable: false);
    if (pendingNeeds.isEmpty) {
      return 'Todos os materiais relacionados a esta etapa já tiveram o efeito aplicado.';
    }

    return pendingNeeds
        .map(
          (need) =>
              '${need.nameSnapshot} (${need.requiredQuantity} ${need.unitLabel})',
        )
        .join(' • ');
  }
}

class _ProductionStatusPill extends StatelessWidget {
  const _ProductionStatusPill({required this.status});

  final OrderProductionPlanStatus status;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final backgroundColor = switch (status) {
      OrderProductionPlanStatus.pending => theme.colorScheme.secondaryContainer,
      OrderProductionPlanStatus.inProduction =>
        theme.colorScheme.tertiaryContainer,
      OrderProductionPlanStatus.completed => theme.colorScheme.primaryContainer,
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(status.label, style: theme.textTheme.labelLarge),
    );
  }
}

class _TaskInfoPill extends StatelessWidget {
  const _TaskInfoPill({required this.label, this.attention = false});

  final String label;
  final bool attention;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: attention
            ? theme.colorScheme.errorContainer
            : theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Text(label, style: theme.textTheme.labelLarge),
    );
  }
}
