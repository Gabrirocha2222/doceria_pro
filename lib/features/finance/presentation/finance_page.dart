import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/navigation/app_destinations.dart';
import '../../../core/formatters/app_formatters.dart';
import '../../../core/money/currency_text_input_formatter.dart';
import '../../../core/money/money.dart';
import '../../../core/responsive/app_breakpoints.dart';
import '../../../core/widgets/app_page_scaffold.dart';
import '../../../core/widgets/states/app_empty_state.dart';
import '../../../core/widgets/states/app_error_state.dart';
import '../../../core/widgets/states/app_loading_state.dart';
import '../../orders/application/order_providers.dart';
import '../application/finance_providers.dart';
import '../domain/finance.dart';

class FinancePage extends ConsumerStatefulWidget {
  const FinancePage({super.key});

  static final basePath = AppDestinations.finance.path;

  @override
  ConsumerState<FinancePage> createState() => _FinancePageState();
}

class _FinancePageState extends ConsumerState<FinancePage> {
  final Set<String> _updatingReceivableIds = <String>{};
  final Set<String> _updatingExpenseIds = <String>{};
  bool _isSavingManualEntry = false;

  @override
  Widget build(BuildContext context) {
    final view = ref.watch(financeViewProvider);
    final periodFilter = ref.watch(financePeriodFilterProvider);
    final overviewAsync = ref.watch(financeOverviewProvider);
    final receivablesAsync = ref.watch(filteredFinanceReceivablesProvider);
    final expensesAsync = ref.watch(filteredFinanceExpensesProvider);
    final manualEntriesAsync = ref.watch(filteredFinanceManualEntriesProvider);

    return AppPageScaffold(
      title: 'Financeiro',
      subtitle:
          'Veja o que entrou, saiu e ainda falta receber sem separar o financeiro da operação.',
      trailing: Wrap(
        spacing: 12,
        runSpacing: 12,
        children: [
          OutlinedButton.icon(
            onPressed: () => context.push(AppDestinations.orders.path),
            icon: const Icon(Icons.receipt_long_rounded),
            label: const Text('Ver pedidos'),
          ),
          FilledButton.icon(
            onPressed: _isSavingManualEntry ? null : _openManualEntrySheet,
            icon: const Icon(Icons.add_rounded),
            label: const Text('Novo lançamento'),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          overviewAsync.when(
            loading: () => const AppLoadingState(
              message: 'Montando o resumo financeiro...',
            ),
            error: (error, stackTrace) => AppErrorState(
              title: 'Não foi possível montar o financeiro',
              message:
                  'Os dados locais continuam salvos, mas o resumo integrado falhou agora.',
              actionLabel: 'Tentar de novo',
              onAction: _reloadFinanceData,
            ),
            data: (overview) => _FinanceOverviewSummaryCard(overview: overview),
          ),
          const SizedBox(height: 16),
          _FinanceControlsCard(view: view, periodFilter: periodFilter),
          const SizedBox(height: 16),
          const _FinanceInfoCard(),
          const SizedBox(height: 16),
          _buildContent(
            view: view,
            overviewAsync: overviewAsync,
            receivablesAsync: receivablesAsync,
            expensesAsync: expensesAsync,
            manualEntriesAsync: manualEntriesAsync,
          ),
        ],
      ),
    );
  }

  Widget _buildContent({
    required FinanceView view,
    required AsyncValue<FinanceOverviewMetrics> overviewAsync,
    required AsyncValue<List<FinanceReceivableRecord>> receivablesAsync,
    required AsyncValue<List<FinanceExpenseRecord>> expensesAsync,
    required AsyncValue<List<FinanceManualEntryRecord>> manualEntriesAsync,
  }) {
    switch (view) {
      case FinanceView.overview:
        return _buildOverviewContent(
          overviewAsync: overviewAsync,
          receivablesAsync: receivablesAsync,
          expensesAsync: expensesAsync,
          manualEntriesAsync: manualEntriesAsync,
        );
      case FinanceView.receivables:
        return _buildReceivablesView(receivablesAsync);
      case FinanceView.expenses:
        return _buildExpensesView(expensesAsync, manualEntriesAsync);
      case FinanceView.manualEntries:
        return _buildManualEntriesView(manualEntriesAsync);
    }
  }

  Widget _buildOverviewContent({
    required AsyncValue<FinanceOverviewMetrics> overviewAsync,
    required AsyncValue<List<FinanceReceivableRecord>> receivablesAsync,
    required AsyncValue<List<FinanceExpenseRecord>> expensesAsync,
    required AsyncValue<List<FinanceManualEntryRecord>> manualEntriesAsync,
  }) {
    final errorState =
        overviewAsync.asError ??
        receivablesAsync.asError ??
        expensesAsync.asError ??
        manualEntriesAsync.asError;
    if (errorState != null) {
      return AppErrorState(
        title: 'O painel integrado não abriu agora',
        message:
            'Tente recarregar para montar o resumo com pedidos, compras e lançamentos.',
        actionLabel: 'Recarregar',
        onAction: _reloadFinanceData,
      );
    }

    if (overviewAsync.isLoading ||
        receivablesAsync.isLoading ||
        expensesAsync.isLoading ||
        manualEntriesAsync.isLoading) {
      return const AppLoadingState(
        message: 'Organizando recebimentos, saídas e previsões...',
      );
    }

    final overview = overviewAsync.asData?.value;
    final receivables = receivablesAsync.asData?.value;
    final expenses = expensesAsync.asData?.value;
    final manualEntries = manualEntriesAsync.asData?.value;
    if (overview == null ||
        receivables == null ||
        expenses == null ||
        manualEntries == null) {
      return const AppLoadingState(message: 'Atualizando o painel...');
    }

    final pendingReceivables = receivables
        .where((entry) => entry.isPending)
        .take(3)
        .toList(growable: false);
    final preparedExpenses = expenses
        .where((entry) => entry.isPrepared)
        .take(3)
        .toList(growable: false);
    final latestManualEntries = manualEntries.take(3).toList(growable: false);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        LayoutBuilder(
          builder: (context, constraints) {
            final compactLayout = AppBreakpoints.isCompactWidth(
              constraints.maxWidth,
            );
            final cardWidth = compactLayout
                ? constraints.maxWidth
                : (constraints.maxWidth - 12) / 2;

            return Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                SizedBox(
                  width: cardWidth,
                  child: _FinanceInsightCard(
                    icon: Icons.balance_rounded,
                    title: overview.breakEvenTitle,
                    message: overview.breakEvenMessage,
                    footer:
                        '${overview.pendingReceivablesCount} recebimentos pendentes • ${overview.preparedExpensesCount} saídas preparadas',
                  ),
                ),
                SizedBox(
                  width: cardWidth,
                  child: _FinanceInsightCard(
                    icon: Icons.auto_graph_rounded,
                    title:
                        'Leitura rápida de ${overview.periodLabel.toLowerCase()}',
                    message:
                        'Lucro estimado de ${overview.estimatedProfit.format()} e lucro real de ${overview.actualProfit.format()} com base no que já entrou e saiu.',
                    footer:
                        '${overview.manualEntriesCount} lançamentos manuais no filtro atual',
                  ),
                ),
              ],
            );
          },
        ),
        const SizedBox(height: 16),
        _PreviewSectionCard<FinanceReceivableRecord>(
          title: 'Falta receber primeiro',
          emptyTitle: 'Nada pendente neste filtro',
          emptyMessage:
              'Os pedidos já cobertos ou sem lançamentos pendentes somem daqui automaticamente.',
          items: pendingReceivables,
          itemBuilder: (entry) => _FinanceReceivableRow(
            entry: entry,
            isUpdating: _updatingReceivableIds.contains(entry.id),
            onMarkReceived: _markReceivableReceived,
          ),
        ),
        const SizedBox(height: 12),
        _PreviewSectionCard<FinanceExpenseRecord>(
          title: 'Saídas preparadas',
          emptyTitle: 'Nenhuma saída preparada agora',
          emptyMessage:
              'Quando uma compra é registrada com valor, o financeiro prepara a saída automaticamente.',
          items: preparedExpenses,
          itemBuilder: (entry) => _FinanceExpenseRow(
            entry: entry,
            isUpdating: _updatingExpenseIds.contains(entry.id),
            onMarkPaid: _markExpensePaid,
          ),
        ),
        const SizedBox(height: 12),
        _PreviewSectionCard<FinanceManualEntryRecord>(
          title: 'Últimos lançamentos manuais',
          emptyTitle: 'Nenhum lançamento manual neste filtro',
          emptyMessage:
              'Use lançamentos manuais só para exceções que ainda não nascem da operação.',
          items: latestManualEntries,
          itemBuilder: (entry) => _FinanceManualEntryRow(entry: entry),
        ),
      ],
    );
  }

  Widget _buildReceivablesView(
    AsyncValue<List<FinanceReceivableRecord>> receivablesAsync,
  ) {
    return receivablesAsync.when(
      loading: () => const AppLoadingState(
        message: 'Carregando os recebimentos do período...',
      ),
      error: (error, stackTrace) => AppErrorState(
        title: 'Não foi possível abrir os recebimentos',
        message:
            'Tente recarregar a tela. Os dados dos pedidos continuam salvos no aparelho.',
        actionLabel: 'Recarregar',
        onAction: _reloadFinanceData,
      ),
      data: (receivables) {
        if (receivables.isEmpty) {
          return const AppEmptyState(
            icon: Icons.payments_outlined,
            title: 'Nada para acompanhar neste filtro',
            message:
                'Quando houver sinal, restante ou recebimento confirmado, eles aparecem aqui.',
          );
        }

        return Column(
          children: [
            for (var index = 0; index < receivables.length; index++) ...[
              _FinanceReceivableCard(
                entry: receivables[index],
                isUpdating: _updatingReceivableIds.contains(
                  receivables[index].id,
                ),
                onMarkReceived: _markReceivableReceived,
              ),
              if (index != receivables.length - 1) const SizedBox(height: 12),
            ],
          ],
        );
      },
    );
  }

  Widget _buildExpensesView(
    AsyncValue<List<FinanceExpenseRecord>> expensesAsync,
    AsyncValue<List<FinanceManualEntryRecord>> manualEntriesAsync,
  ) {
    final errorState = expensesAsync.asError ?? manualEntriesAsync.asError;
    if (errorState != null) {
      return AppErrorState(
        title: 'Não foi possível abrir as saídas',
        message:
            'Tente recarregar a tela para remontar as despesas automáticas e manuais.',
        actionLabel: 'Recarregar',
        onAction: _reloadFinanceData,
      );
    }

    if (expensesAsync.isLoading || manualEntriesAsync.isLoading) {
      return const AppLoadingState(
        message: 'Carregando as saídas do período...',
      );
    }

    final expenses =
        expensesAsync.asData?.value ?? const <FinanceExpenseRecord>[];
    final manualExpenses =
        (manualEntriesAsync.asData?.value ?? const <FinanceManualEntryRecord>[])
            .where((entry) => entry.isExpense)
            .toList(growable: false);

    if (expenses.isEmpty && manualExpenses.isEmpty) {
      return AppEmptyState(
        icon: Icons.shopping_bag_outlined,
        title: 'Nenhuma saída neste filtro',
        message:
            'As saídas de compras pagas e as saídas manuais aparecem aqui assim que existirem.',
        actionLabel: 'Novo lançamento',
        onAction: _openManualEntrySheet,
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (expenses.isNotEmpty) ...[
          const _SectionTitle(
            title: 'Compras e saídas automáticas',
            subtitle:
                'O que veio das compras registradas e já está preparado ou pago.',
          ),
          const SizedBox(height: 12),
          for (var index = 0; index < expenses.length; index++) ...[
            _FinanceExpenseCard(
              entry: expenses[index],
              isUpdating: _updatingExpenseIds.contains(expenses[index].id),
              onMarkPaid: _markExpensePaid,
            ),
            if (index != expenses.length - 1) const SizedBox(height: 12),
          ],
        ],
        if (expenses.isNotEmpty && manualExpenses.isNotEmpty)
          const SizedBox(height: 20),
        if (manualExpenses.isNotEmpty) ...[
          const _SectionTitle(
            title: 'Saídas manuais',
            subtitle:
                'Use só para despesas excepcionais que ainda não nascem da operação.',
          ),
          const SizedBox(height: 12),
          for (var index = 0; index < manualExpenses.length; index++) ...[
            _FinanceManualEntryCard(entry: manualExpenses[index]),
            if (index != manualExpenses.length - 1) const SizedBox(height: 12),
          ],
        ],
      ],
    );
  }

  Widget _buildManualEntriesView(
    AsyncValue<List<FinanceManualEntryRecord>> manualEntriesAsync,
  ) {
    return manualEntriesAsync.when(
      loading: () => const AppLoadingState(
        message: 'Carregando os lançamentos manuais...',
      ),
      error: (error, stackTrace) => AppErrorState(
        title: 'Não foi possível abrir os lançamentos',
        message:
            'Tente recarregar a tela. Os lançamentos já salvos continuam preservados.',
        actionLabel: 'Recarregar',
        onAction: _reloadFinanceData,
      ),
      data: (entries) {
        if (entries.isEmpty) {
          return AppEmptyState(
            icon: Icons.edit_note_rounded,
            title: 'Nenhum lançamento manual neste filtro',
            message:
                'Crie uma entrada ou saída manual só quando o valor não vier automaticamente de pedidos ou compras.',
            actionLabel: 'Novo lançamento',
            onAction: _openManualEntrySheet,
          );
        }

        return Column(
          children: [
            for (var index = 0; index < entries.length; index++) ...[
              _FinanceManualEntryCard(entry: entries[index]),
              if (index != entries.length - 1) const SizedBox(height: 12),
            ],
          ],
        );
      },
    );
  }

  Future<void> _openManualEntrySheet() async {
    if (_isSavingManualEntry) {
      return;
    }

    final result = await showModalBottomSheet<FinanceManualEntryInput>(
      context: context,
      isScrollControlled: true,
      builder: (context) => const _ManualEntrySheet(),
    );
    if (result == null) {
      return;
    }

    setState(() => _isSavingManualEntry = true);
    try {
      await ref.read(financeRepositoryProvider).saveManualEntry(result);
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Lançamento salvo no financeiro.')),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Não foi possível salvar o lançamento: $error')),
      );
    } finally {
      if (mounted) {
        setState(() => _isSavingManualEntry = false);
      }
    }
  }

  Future<void> _markReceivableReceived(FinanceReceivableRecord entry) async {
    if (_updatingReceivableIds.contains(entry.id)) {
      return;
    }

    setState(() => _updatingReceivableIds.add(entry.id));
    try {
      await ref
          .read(financeRepositoryProvider)
          .markReceivableReceived(entry.id);
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Recebimento confirmado e pedido atualizado.'),
        ),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Não foi possível confirmar o recebimento: $error'),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _updatingReceivableIds.remove(entry.id));
      }
    }
  }

  Future<void> _markExpensePaid(FinanceExpenseRecord entry) async {
    if (_updatingExpenseIds.contains(entry.id)) {
      return;
    }

    setState(() => _updatingExpenseIds.add(entry.id));
    try {
      await ref.read(financeRepositoryProvider).markExpensePaid(entry.id);
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Saída marcada como paga neste aparelho.'),
        ),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Não foi possível marcar a saída como paga: $error'),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _updatingExpenseIds.remove(entry.id));
      }
    }
  }

  void _reloadFinanceData() {
    ref.invalidate(financeReceivablesProvider);
    ref.invalidate(financeExpensesProvider);
    ref.invalidate(financeManualEntriesProvider);
    ref.invalidate(ordersProvider);
  }
}

class _FinanceOverviewSummaryCard extends StatelessWidget {
  const _FinanceOverviewSummaryCard({required this.overview});

  final FinanceOverviewMetrics overview;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Resumo de ${overview.periodLabel.toLowerCase()}',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              'Os números juntam o que já veio dos pedidos, das compras e dos lançamentos manuais.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 16),
            LayoutBuilder(
              builder: (context, constraints) {
                final compactLayout = constraints.maxWidth < 760;
                final cardWidth = compactLayout
                    ? constraints.maxWidth
                    : (constraints.maxWidth - 24) / 3;

                return Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    SizedBox(
                      width: cardWidth,
                      child: _MetricCard(
                        label: 'Entrou',
                        value: overview.cashIn.format(),
                      ),
                    ),
                    SizedBox(
                      width: cardWidth,
                      child: _MetricCard(
                        label: 'Saiu',
                        value: overview.cashOut.format(),
                      ),
                    ),
                    SizedBox(
                      width: cardWidth,
                      child: _MetricCard(
                        label: 'Falta receber',
                        value: overview.pendingReceivables.format(),
                      ),
                    ),
                    SizedBox(
                      width: cardWidth,
                      child: _MetricCard(
                        label: 'Lucro estimado',
                        value: overview.estimatedProfit.format(),
                      ),
                    ),
                    SizedBox(
                      width: cardWidth,
                      child: _MetricCard(
                        label: 'Lucro real',
                        value: overview.actualProfit.format(),
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

class _FinanceControlsCard extends ConsumerWidget {
  const _FinanceControlsCard({required this.view, required this.periodFilter});

  final FinanceView view;
  final FinancePeriodFilter periodFilter;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final compactLayout = constraints.maxWidth < 860;

            final viewSelector = Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Mostrar primeiro',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const SizedBox(height: 10),
                SegmentedButton<FinanceView>(
                  segments: [
                    for (final item in FinanceView.values)
                      ButtonSegment<FinanceView>(
                        value: item,
                        label: Text(item.label),
                      ),
                  ],
                  selected: {view},
                  multiSelectionEnabled: false,
                  showSelectedIcon: false,
                  onSelectionChanged: (selection) {
                    ref
                        .read(financeViewProvider.notifier)
                        .updateView(selection.first);
                  },
                ),
              ],
            );

            final periodSelector = Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Período', style: Theme.of(context).textTheme.titleSmall),
                const SizedBox(height: 10),
                SegmentedButton<FinancePeriodFilter>(
                  segments: [
                    for (final item in FinancePeriodFilter.values)
                      ButtonSegment<FinancePeriodFilter>(
                        value: item,
                        label: Text(item.label),
                      ),
                  ],
                  selected: {periodFilter},
                  multiSelectionEnabled: false,
                  showSelectedIcon: false,
                  onSelectionChanged: (selection) {
                    ref
                        .read(financePeriodFilterProvider.notifier)
                        .updateFilter(selection.first);
                  },
                ),
              ],
            );

            if (compactLayout) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  viewSelector,
                  const SizedBox(height: 16),
                  periodSelector,
                ],
              );
            }

            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: viewSelector),
                const SizedBox(width: 16),
                Expanded(child: periodSelector),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _FinanceInfoCard extends StatelessWidget {
  const _FinanceInfoCard();

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Theme.of(context).colorScheme.surfaceContainerLowest,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              Icons.info_outline_rounded,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Pedidos confirmados já entregam contas a receber. Compras com valor já preparam saídas. Use lançamentos manuais só para o que foge do fluxo normal.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({required this.label, required this.value});

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
          Text(value, style: Theme.of(context).textTheme.titleLarge),
        ],
      ),
    );
  }
}

class _FinanceInsightCard extends StatelessWidget {
  const _FinanceInsightCard({
    required this.icon,
    required this.title,
    required this.message,
    required this.footer,
  });

  final IconData icon;
  final String title;
  final String message;
  final String footer;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: theme.colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(icon, color: theme.colorScheme.primary),
            ),
            const SizedBox(height: 16),
            Text(title, style: theme.textTheme.titleLarge),
            const SizedBox(height: 8),
            Text(message, style: theme.textTheme.bodyMedium),
            const SizedBox(height: 12),
            Text(footer, style: theme.textTheme.labelLarge),
          ],
        ),
      ),
    );
  }
}

class _PreviewSectionCard<T> extends StatelessWidget {
  const _PreviewSectionCard({
    required this.title,
    required this.emptyTitle,
    required this.emptyMessage,
    required this.items,
    required this.itemBuilder,
  });

  final String title;
  final String emptyTitle;
  final String emptyMessage;
  final List<T> items;
  final Widget Function(T item) itemBuilder;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 12),
            if (items.isEmpty)
              AppEmptyState(
                icon: Icons.inbox_outlined,
                title: emptyTitle,
                message: emptyMessage,
              )
            else
              Column(
                children: [
                  for (var index = 0; index < items.length; index++) ...[
                    itemBuilder(items[index]),
                    if (index != items.length - 1) const Divider(height: 24),
                  ],
                ],
              ),
          ],
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 6),
        Text(subtitle, style: Theme.of(context).textTheme.bodyMedium),
      ],
    );
  }
}

class _FinanceReceivableCard extends StatelessWidget {
  const _FinanceReceivableCard({
    required this.entry,
    required this.isUpdating,
    required this.onMarkReceived,
  });

  final FinanceReceivableRecord entry;
  final bool isUpdating;
  final ValueChanged<FinanceReceivableRecord> onMarkReceived;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _FinanceReceivableRow(
              entry: entry,
              isUpdating: isUpdating,
              onMarkReceived: onMarkReceived,
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                _MetaPill(
                  icon: Icons.account_circle_outlined,
                  label: entry.displayClientName,
                ),
                _MetaPill(
                  icon: Icons.calendar_today_outlined,
                  label: entry.displayReferenceDateLabel,
                ),
                _MetaPill(
                  icon: Icons.sell_outlined,
                  label: entry.orderStatus.label,
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                OutlinedButton.icon(
                  onPressed: () => context.push(
                    '${AppDestinations.orders.path}/${entry.orderId}',
                  ),
                  icon: const Icon(Icons.open_in_new_rounded),
                  label: const Text('Abrir pedido'),
                ),
                const SizedBox(width: 12),
                if (entry.isPending)
                  FilledButton.icon(
                    onPressed: isUpdating ? null : () => onMarkReceived(entry),
                    icon: isUpdating
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.check_circle_outline_rounded),
                    label: Text(
                      isUpdating ? 'Confirmando...' : 'Marcar como recebido',
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _FinanceReceivableRow extends StatelessWidget {
  const _FinanceReceivableRow({
    required this.entry,
    required this.isUpdating,
    required this.onMarkReceived,
  });

  final FinanceReceivableRecord entry;
  final bool isUpdating;
  final ValueChanged<FinanceReceivableRecord> onMarkReceived;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(entry.description, style: theme.textTheme.titleMedium),
              const SizedBox(height: 6),
              Text(entry.amount.format(), style: theme.textTheme.headlineSmall),
            ],
          ),
        ),
        const SizedBox(width: 12),
        _StatusBadge(
          label: entry.isPending ? 'Pendente' : 'Recebido',
          color: entry.isPending
              ? theme.colorScheme.tertiaryContainer
              : theme.colorScheme.primaryContainer,
          icon: entry.isPending
              ? Icons.schedule_outlined
              : Icons.check_circle_outline_rounded,
        ),
      ],
    );
  }
}

class _FinanceExpenseCard extends StatelessWidget {
  const _FinanceExpenseCard({
    required this.entry,
    required this.isUpdating,
    required this.onMarkPaid,
  });

  final FinanceExpenseRecord entry;
  final bool isUpdating;
  final ValueChanged<FinanceExpenseRecord> onMarkPaid;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _FinanceExpenseRow(
              entry: entry,
              isUpdating: isUpdating,
              onMarkPaid: onMarkPaid,
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                _MetaPill(
                  icon: Icons.local_shipping_outlined,
                  label: entry.displaySupplierName,
                ),
                _MetaPill(
                  icon: Icons.calendar_today_outlined,
                  label: entry.displayReferenceDateLabel,
                ),
              ],
            ),
            if (entry.isPrepared) ...[
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: isUpdating ? null : () => onMarkPaid(entry),
                icon: isUpdating
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.paid_outlined),
                label: Text(isUpdating ? 'Salvando...' : 'Marcar como paga'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _FinanceExpenseRow extends StatelessWidget {
  const _FinanceExpenseRow({
    required this.entry,
    required this.isUpdating,
    required this.onMarkPaid,
  });

  final FinanceExpenseRecord entry;
  final bool isUpdating;
  final ValueChanged<FinanceExpenseRecord> onMarkPaid;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(entry.description, style: theme.textTheme.titleMedium),
              const SizedBox(height: 6),
              Text(entry.amount.format(), style: theme.textTheme.headlineSmall),
            ],
          ),
        ),
        const SizedBox(width: 12),
        _StatusBadge(
          label: entry.isPrepared ? 'Preparada' : 'Paga',
          color: entry.isPrepared
              ? theme.colorScheme.secondaryContainer
              : theme.colorScheme.primaryContainer,
          icon: entry.isPrepared
              ? Icons.pending_actions_outlined
              : Icons.check_circle_outline_rounded,
        ),
      ],
    );
  }
}

class _FinanceManualEntryCard extends StatelessWidget {
  const _FinanceManualEntryCard({required this.entry});

  final FinanceManualEntryRecord entry;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: _FinanceManualEntryRow(entry: entry),
      ),
    );
  }
}

class _FinanceManualEntryRow extends StatelessWidget {
  const _FinanceManualEntryRow({required this.entry});

  final FinanceManualEntryRecord entry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(entry.description, style: theme.textTheme.titleMedium),
                  const SizedBox(height: 6),
                  Text(
                    entry.amount.format(),
                    style: theme.textTheme.headlineSmall,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            _StatusBadge(
              label: entry.entryType.label,
              color: entry.isIncome
                  ? theme.colorScheme.primaryContainer
                  : theme.colorScheme.errorContainer,
              icon: entry.isIncome
                  ? Icons.south_west_rounded
                  : Icons.north_east_rounded,
            ),
          ],
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            _MetaPill(
              icon: Icons.calendar_today_outlined,
              label: AppFormatters.dayMonthYear(entry.entryDate),
            ),
            _MetaPill(
              icon: Icons.label_outline_rounded,
              label: entry.displayCategory,
            ),
          ],
        ),
        if (entry.notes?.trim().isNotEmpty ?? false) ...[
          const SizedBox(height: 12),
          Text(entry.displayNotes, style: theme.textTheme.bodyMedium),
        ],
      ],
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({
    required this.label,
    required this.color,
    required this.icon,
  });

  final String label;
  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16),
          const SizedBox(width: 8),
          Text(label, style: Theme.of(context).textTheme.labelLarge),
        ],
      ),
    );
  }
}

class _MetaPill extends StatelessWidget {
  const _MetaPill({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16),
          const SizedBox(width: 8),
          Text(label, style: Theme.of(context).textTheme.bodyMedium),
        ],
      ),
    );
  }
}

class _ManualEntrySheet extends StatefulWidget {
  const _ManualEntrySheet();

  @override
  State<_ManualEntrySheet> createState() => _ManualEntrySheetState();
}

class _ManualEntrySheetState extends State<_ManualEntrySheet> {
  final _formKey = GlobalKey<FormState>();
  final _descriptionController = TextEditingController();
  final _amountController = TextEditingController();
  final _categoryController = TextEditingController();
  final _notesController = TextEditingController();
  FinanceManualEntryType _entryType = FinanceManualEntryType.expense;
  DateTime _entryDate = DateTime.now();

  @override
  void dispose() {
    _descriptionController.dispose();
    _amountController.dispose();
    _categoryController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          20,
          20,
          20,
          20 + MediaQuery.of(context).viewInsets.bottom,
        ),
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Novo lançamento',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 8),
                Text(
                  'Use este espaço só para valores que ainda não nasceram automaticamente da operação.',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 20),
                Text('Tipo', style: Theme.of(context).textTheme.titleSmall),
                const SizedBox(height: 10),
                SegmentedButton<FinanceManualEntryType>(
                  segments: [
                    for (final item in FinanceManualEntryType.values)
                      ButtonSegment<FinanceManualEntryType>(
                        value: item,
                        label: Text(item.label),
                      ),
                  ],
                  selected: {_entryType},
                  showSelectedIcon: false,
                  multiSelectionEnabled: false,
                  onSelectionChanged: (selection) {
                    setState(() => _entryType = selection.first);
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _descriptionController,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(
                    labelText: 'Descrição',
                    hintText: 'Ex.: taxa da maquininha, pix de cliente, feira',
                  ),
                  validator: (value) {
                    final trimmed = value?.trim() ?? '';
                    if (trimmed.isEmpty) {
                      return 'Escreva uma descrição curta.';
                    }

                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _amountController,
                  textInputAction: TextInputAction.next,
                  keyboardType: TextInputType.number,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    CurrencyTextInputFormatter(),
                  ],
                  decoration: const InputDecoration(
                    labelText: 'Valor',
                    prefixText: 'R\$ ',
                  ),
                  validator: (value) {
                    if (Money.fromInput(value ?? '').isZero) {
                      return 'Digite um valor maior que zero.';
                    }

                    return null;
                  },
                ),
                const SizedBox(height: 16),
                InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: _pickDate,
                  child: InputDecorator(
                    decoration: const InputDecoration(
                      labelText: 'Data do lançamento',
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.calendar_today_outlined, size: 18),
                        const SizedBox(width: 10),
                        Text(AppFormatters.dayMonthYear(_entryDate)),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _categoryController,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(
                    labelText: 'Categoria opcional',
                    hintText: 'Ex.: entrega, manutenção, venda extra',
                  ),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _notesController,
                  minLines: 2,
                  maxLines: 4,
                  decoration: const InputDecoration(
                    labelText: 'Observação opcional',
                    hintText: 'Algo que ajude a lembrar depois',
                  ),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: _submit,
                    icon: const Icon(Icons.save_outlined),
                    label: const Text('Salvar lançamento'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _pickDate() async {
    final selectedDate = await showDatePicker(
      context: context,
      initialDate: _entryDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
      locale: const Locale('pt', 'BR'),
    );
    if (selectedDate == null) {
      return;
    }

    setState(() => _entryDate = selectedDate);
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    Navigator.of(context).pop(
      FinanceManualEntryInput(
        entryType: _entryType,
        description: _descriptionController.text.trim(),
        amount: Money.fromInput(_amountController.text),
        entryDate: _entryDate,
        category: _categoryController.text.trim(),
        notes: _notesController.text.trim(),
      ),
    );
  }
}
