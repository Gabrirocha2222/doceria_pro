import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/navigation/app_destinations.dart';
import '../../../core/formatters/app_formatters.dart';
import '../../../core/widgets/app_page_scaffold.dart';
import '../../../core/widgets/states/app_empty_state.dart';
import '../../../core/widgets/states/app_error_state.dart';
import '../../../core/widgets/states/app_loading_state.dart';
import '../application/monthly_plan_providers.dart';
import '../domain/monthly_plan.dart';

class MonthlyPlanDetailsPage extends ConsumerWidget {
  const MonthlyPlanDetailsPage({super.key, required this.monthlyPlanId});

  final String monthlyPlanId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final monthlyPlanAsync = ref.watch(monthlyPlanProvider(monthlyPlanId));
    final futureImpactAsync = ref.watch(
      monthlyPlanFutureImpactProvider(monthlyPlanId),
    );

    return monthlyPlanAsync.when(
      loading: () => const AppPageScaffold(
        title: 'Abrindo mesversário',
        subtitle: 'Carregando recorrência, histórico e saldo.',
        child: AppLoadingState(message: 'Carregando plano mensal...'),
      ),
      error: (error, stackTrace) => AppPageScaffold(
        title: 'Mesversário indisponível',
        subtitle: 'Não foi possível abrir este plano agora.',
        child: AppErrorState(
          title: 'Não deu para abrir o mesversário',
          message: 'Volte para a lista e tente novamente.',
          actionLabel: 'Voltar para mesversários',
          onAction: () =>
              context.go('${AppDestinations.clients.path}/monthly-plans'),
        ),
      ),
      data: (monthlyPlan) {
        if (monthlyPlan == null) {
          return AppPageScaffold(
            title: 'Mesversário não encontrado',
            subtitle: 'Talvez este plano já não exista mais neste aparelho.',
            child: AppErrorState(
              title: 'Mesversário não encontrado',
              message: 'Volte para a lista e confira os planos salvos.',
              actionLabel: 'Voltar para mesversários',
              onAction: () =>
                  context.go('${AppDestinations.clients.path}/monthly-plans'),
            ),
          );
        }

        return AppPageScaffold(
          title: 'Plano de mesversário',
          subtitle:
              'Acompanhe saldo, histórico mensal e o impacto futuro sem virar um contrato pesado.',
          trailing: Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              OutlinedButton.icon(
                onPressed: () =>
                    context.go('${AppDestinations.clients.path}/monthly-plans'),
                icon: const Icon(Icons.arrow_back_rounded),
                label: const Text('Voltar'),
              ),
              FilledButton.tonalIcon(
                onPressed: () => context.push(
                  '${AppDestinations.clients.path}/monthly-plans/${monthlyPlan.id}/edit',
                ),
                icon: const Icon(Icons.edit_rounded),
                label: const Text('Editar'),
              ),
            ],
          ),
          child: _MonthlyPlanDetailsContent(
            monthlyPlan: monthlyPlan,
            futureImpactAsync: futureImpactAsync,
          ),
        );
      },
    );
  }
}

class _MonthlyPlanDetailsContent extends StatelessWidget {
  const _MonthlyPlanDetailsContent({
    required this.monthlyPlan,
    required this.futureImpactAsync,
  });

  final MonthlyPlanRecord monthlyPlan;
  final AsyncValue<MonthlyPlanFutureImpact?> futureImpactAsync;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _MonthlyPlanHeroCard(monthlyPlan: monthlyPlan),
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
                    title: 'Estrutura do plano',
                    content: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _LabelValueRow(
                          label: 'Cliente',
                          value: monthlyPlan.clientNameSnapshot,
                        ),
                        const SizedBox(height: 12),
                        _LabelValueRow(
                          label: 'Recorrência',
                          value: monthlyPlan.recurrenceSummary,
                        ),
                        const SizedBox(height: 12),
                        _LabelValueRow(
                          label: 'Modelo base',
                          value: monthlyPlan.displayTemplateProductName,
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
                      monthlyPlan.displayNotes,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ),
                ),
                SizedBox(
                  width: constraints.maxWidth,
                  child: _TemplateItemsCard(monthlyPlan: monthlyPlan),
                ),
                SizedBox(
                  width: constraints.maxWidth,
                  child: _FutureImpactCard(
                    monthlyPlan: monthlyPlan,
                    futureImpactAsync: futureImpactAsync,
                  ),
                ),
                SizedBox(
                  width: constraints.maxWidth,
                  child: _MonthlyHistoryCard(monthlyPlan: monthlyPlan),
                ),
              ],
            );
          },
        ),
      ],
    );
  }
}

class _MonthlyPlanHeroCard extends StatelessWidget {
  const _MonthlyPlanHeroCard({required this.monthlyPlan});

  final MonthlyPlanRecord monthlyPlan;

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
              _HeroChip(
                icon: Icons.people_alt_outlined,
                label: monthlyPlan.clientNameSnapshot,
              ),
              _HeroChip(
                icon: Icons.autorenew_rounded,
                label: '${monthlyPlan.numberOfMonths} meses previstos',
              ),
              _HeroChip(
                icon: Icons.inventory_2_outlined,
                label: '${monthlyPlan.estimatedItemCount} itens por ciclo',
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(monthlyPlan.title, style: theme.textTheme.headlineSmall),
          const SizedBox(height: 6),
          Text(
            'Modelo base: ${monthlyPlan.displayTemplateProductName}',
            style: theme.textTheme.bodyLarge,
          ),
          const SizedBox(height: 20),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _HeroMetric(
                label: 'Quantidade contratada',
                value: monthlyPlan.contractedQuantity.toString(),
              ),
              _HeroMetric(
                label: 'Saldo restante',
                value: monthlyPlan.remainingBalance.toString(),
              ),
              _HeroMetric(
                label: 'Pode gerar agora',
                value: monthlyPlan.availableToGenerateCount.toString(),
              ),
              _HeroMetric(
                label: 'Total previsto por mês',
                value: monthlyPlan.estimatedMonthlyTotal.format(),
              ),
            ],
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
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: theme.colorScheme.outlineVariant),
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

class _TemplateItemsCard extends StatelessWidget {
  const _TemplateItemsCard({required this.monthlyPlan});

  final MonthlyPlanRecord monthlyPlan;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Modelo mensal do pedido',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              'Esses itens são repetidos quando você gera os próximos rascunhos.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 16),
            for (var index = 0; index < monthlyPlan.items.length; index++) ...[
              _TemplateItemTile(item: monthlyPlan.items[index]),
              if (index != monthlyPlan.items.length - 1)
                const SizedBox(height: 12),
            ],
          ],
        ),
      ),
    );
  }
}

class _TemplateItemTile extends StatelessWidget {
  const _TemplateItemTile({required this.item});

  final MonthlyPlanItemRecord item;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: theme.colorScheme.primaryContainer,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(Icons.cake_outlined, color: theme.colorScheme.primary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.displayName, style: theme.textTheme.titleMedium),
                const SizedBox(height: 6),
                Text(
                  '${item.normalizedQuantity}x • ${item.unitPrice.format()} cada • total ${item.lineTotal.format()}',
                  style: theme.textTheme.bodyMedium,
                ),
                if (item.notes?.trim().isNotEmpty ?? false) ...[
                  const SizedBox(height: 6),
                  Text(item.notes!, style: theme.textTheme.bodySmall),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _FutureImpactCard extends ConsumerStatefulWidget {
  const _FutureImpactCard({
    required this.monthlyPlan,
    required this.futureImpactAsync,
  });

  final MonthlyPlanRecord monthlyPlan;
  final AsyncValue<MonthlyPlanFutureImpact?> futureImpactAsync;

  @override
  ConsumerState<_FutureImpactCard> createState() => _FutureImpactCardState();
}

class _FutureImpactCardState extends ConsumerState<_FutureImpactCard> {
  bool _isGeneratingNext = false;
  bool _isGeneratingAll = false;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Impacto futuro',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              'Veja os próximos meses antes de gerar rascunhos e respeite o saldo já contratado.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                FilledButton.icon(
                  onPressed:
                      _isGeneratingNext ||
                          _isGeneratingAll ||
                          widget.monthlyPlan.availableToGenerateCount <= 0
                      ? null
                      : () => _generateDrafts(maxDrafts: 1),
                  icon: _isGeneratingNext
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2.2),
                        )
                      : const Icon(Icons.auto_fix_high_rounded),
                  label: Text(
                    _isGeneratingNext ? 'Gerando...' : 'Gerar próximo rascunho',
                  ),
                ),
                FilledButton.tonalIcon(
                  onPressed:
                      _isGeneratingNext ||
                          _isGeneratingAll ||
                          widget.monthlyPlan.availableToGenerateCount <= 1
                      ? null
                      : () => _generateDrafts(
                          maxDrafts:
                              widget.monthlyPlan.availableToGenerateCount,
                        ),
                  icon: _isGeneratingAll
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2.2),
                        )
                      : const Icon(Icons.queue_play_next_rounded),
                  label: Text(
                    _isGeneratingAll ? 'Gerando...' : 'Gerar saldo disponível',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              'Saldo restante olha o que ainda falta entregar. A geração disponível desconta meses que já viraram rascunho.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 16),
            widget.futureImpactAsync.when(
              loading: () => const AppLoadingState(
                message: 'Montando prévia dos próximos meses...',
              ),
              error: (error, stackTrace) => AppErrorState(
                title: 'Não foi possível montar a prévia',
                message:
                    'Tente atualizar a tela antes de gerar novos rascunhos.',
                actionLabel: 'Tentar novamente',
                onAction: () => ref.invalidate(
                  monthlyPlanFutureImpactProvider(widget.monthlyPlan.id),
                ),
              ),
              data: (futureImpact) {
                if (futureImpact == null || futureImpact.entries.isEmpty) {
                  return const AppEmptyState(
                    icon: Icons.event_busy_outlined,
                    title: 'Sem meses futuros para mostrar',
                    message:
                        'Este plano não tem mais meses previstos a partir de hoje.',
                  );
                }

                return Column(
                  children: [
                    for (
                      var index = 0;
                      index < futureImpact.entries.length;
                      index++
                    ) ...[
                      _FutureImpactTile(entry: futureImpact.entries[index]),
                      if (index != futureImpact.entries.length - 1)
                        const SizedBox(height: 12),
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

  Future<void> _generateDrafts({required int maxDrafts}) async {
    final generateAll = maxDrafts > 1;
    setState(() {
      if (generateAll) {
        _isGeneratingAll = true;
      } else {
        _isGeneratingNext = true;
      }
    });

    try {
      final result = await ref
          .read(monthlyPlanGenerationServiceProvider)
          .generateFutureOrderDrafts(
            monthlyPlanId: widget.monthlyPlan.id,
            maxDrafts: maxDrafts,
          );

      if (!mounted) {
        return;
      }

      if (!result.hasGeneratedOrders) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Não havia meses disponíveis para gerar novos rascunhos agora.',
            ),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '${result.orderIds.length} rascunho(s) criado(s) a partir deste plano.',
            ),
          ),
        );
      }
    } catch (_) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Não foi possível gerar os rascunhos agora. Tente novamente.',
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isGeneratingNext = false;
          _isGeneratingAll = false;
        });
      }
    }
  }
}

class _FutureImpactTile extends StatelessWidget {
  const _FutureImpactTile({required this.entry});

  final MonthlyPlanFutureImpactEntry entry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: entry.canGenerateDraft
                  ? theme.colorScheme.primaryContainer
                  : theme.colorScheme.surfaceContainerLow,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(
              entry.alreadyGenerated
                  ? Icons.task_alt_rounded
                  : Icons.event_repeat_rounded,
              color: entry.canGenerateDraft
                  ? theme.colorScheme.primary
                  : theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  entry.occurrence.displayMonthLabel,
                  style: theme.textTheme.titleMedium,
                ),
                const SizedBox(height: 6),
                Text(
                  '${entry.estimatedItemCount} itens previstos • ${entry.estimatedMonthlyTotal.format()}',
                  style: theme.textTheme.bodyMedium,
                ),
                const SizedBox(height: 6),
                Text(
                  entry.alreadyGenerated
                      ? 'Este mês já tem um pedido rascunho ou em andamento.'
                      : entry.canGenerateDraft
                      ? 'Pode gerar rascunho agora sem consumir além do saldo contratado.'
                      : 'Está no calendário futuro, mas não entra na geração disponível agora.',
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MonthlyHistoryCard extends StatelessWidget {
  const _MonthlyHistoryCard({required this.monthlyPlan});

  final MonthlyPlanRecord monthlyPlan;

  @override
  Widget build(BuildContext context) {
    final history = monthlyPlan.sortedHistory;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Histórico mensal',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              'Cada mês mostra se já existe rascunho e como o pedido evoluiu dentro do fluxo normal.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 16),
            if (history.isEmpty)
              const AppEmptyState(
                icon: Icons.history_toggle_off_outlined,
                title: 'Sem histórico montado',
                message:
                    'Assim que o plano existir de fato, os meses previstos aparecem aqui automaticamente.',
              )
            else
              Column(
                children: [
                  for (var index = 0; index < history.length; index++) ...[
                    _HistoryTile(occurrence: history[index]),
                    if (index != history.length - 1) const SizedBox(height: 12),
                  ],
                ],
              ),
          ],
        ),
      ),
    );
  }
}

class _HistoryTile extends StatelessWidget {
  const _HistoryTile({required this.occurrence});

  final MonthlyPlanOccurrenceRecord occurrence;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  occurrence.displayMonthLabel,
                  style: theme.textTheme.titleMedium,
                ),
                const SizedBox(height: 6),
                Text(
                  'Status: ${occurrence.displayStatusLabel}',
                  style: theme.textTheme.bodyMedium,
                ),
                const SizedBox(height: 6),
                Text(
                  'Data prevista: ${AppFormatters.dayMonthYear(occurrence.scheduledDate)}',
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ),
          ),
          if (occurrence.generatedOrderId != null) ...[
            const SizedBox(width: 12),
            FilledButton.tonalIcon(
              onPressed: () => context.push(
                '${AppDestinations.orders.path}/${occurrence.generatedOrderId!}',
              ),
              icon: const Icon(Icons.receipt_long_rounded),
              label: const Text('Abrir pedido'),
            ),
          ],
        ],
      ),
    );
  }
}
