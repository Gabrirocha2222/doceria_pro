import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/money/currency_text_input_formatter.dart';
import '../../../core/money/money.dart';
import '../../../core/responsive/app_breakpoints.dart';
import '../../../core/widgets/app_page_scaffold.dart';
import '../../../core/widgets/app_summary_metric_card.dart';
import '../../../core/widgets/states/app_empty_state.dart';
import '../../../core/widgets/states/app_error_state.dart';
import '../../../core/widgets/states/app_loading_state.dart';
import '../../cost_benefit/presentation/cost_benefit_comparator_page.dart';
import '../../ingredients/presentation/ingredients_page.dart';
import '../../orders/domain/order.dart';
import '../../packaging/presentation/packaging_page.dart';
import '../application/purchase_providers.dart';
import '../domain/purchase.dart';

class PurchasesPage extends ConsumerStatefulWidget {
  const PurchasesPage({super.key});

  static final basePath = '/purchases';

  @override
  ConsumerState<PurchasesPage> createState() => _PurchasesPageState();
}

class _PurchasesPageState extends ConsumerState<PurchasesPage> {
  final Set<String> _updatingItemKeys = <String>{};

  @override
  Widget build(BuildContext context) {
    final view = ref.watch(purchaseListViewProvider);
    final checklistAsync = ref.watch(purchaseChecklistProvider);
    final visibleItemsAsync = ref.watch(visiblePurchaseItemsProvider);
    final groupedBySupplierAsync = ref.watch(
      groupedPurchasesBySupplierProvider,
    );
    final preparedExpensesAsync = ref.watch(
      preparedPurchaseExpenseDraftsProvider,
    );

    return AppPageScaffold(
      title: 'Compras',
      subtitle:
          'A lista já cruza pedidos ativos, estoque local, mínimo e fornecedoras quando esse contexto existe.',
      trailing: Wrap(
        spacing: 12,
        runSpacing: 12,
        children: [
          OutlinedButton.icon(
            onPressed: () => context.push(CostBenefitComparatorPage.basePath),
            icon: const Icon(Icons.balance_rounded),
            label: const Text('Comparar opções'),
          ),
          OutlinedButton.icon(
            onPressed: () => context.push(IngredientsPage.basePath),
            icon: const Icon(Icons.inventory_2_rounded),
            label: const Text('Ver estoque'),
          ),
          FilledButton.tonalIcon(
            onPressed: () => context.push(PackagingPage.basePath),
            icon: const Icon(Icons.inventory_2_outlined),
            label: const Text('Ver embalagens'),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          checklistAsync.when(
            loading: () => const AppLoadingState(
              message: 'Montando sua lista de compras...',
            ),
            error: (error, stackTrace) => AppErrorState(
              title: 'Não foi possível montar as compras',
              message:
                  'Os dados locais continuam no aparelho, mas a lista inteligente falhou agora.',
              actionLabel: 'Tentar de novo',
              onAction: () => ref.invalidate(purchaseChecklistProvider),
            ),
            data: (items) => _PurchasesSummaryCard(
              items: items,
              preparedExpensesAsync: preparedExpensesAsync,
            ),
          ),
          const SizedBox(height: 16),
          _PurchasesViewCard(view: view),
          const SizedBox(height: 16),
          const _PurchaseInfoCard(),
          const SizedBox(height: 16),
          if (view == PurchaseListView.bySupplier)
            groupedBySupplierAsync.when(
              loading: () => const AppLoadingState(
                message: 'Agrupando por fornecedora...',
              ),
              error: (error, stackTrace) => AppErrorState(
                title: 'Não foi possível agrupar as compras',
                message:
                    'Tente recarregar a tela para montar os grupos de novo.',
                actionLabel: 'Recarregar',
                onAction: () => ref.invalidate(purchaseChecklistProvider),
              ),
              data: (groups) {
                if (groups.isEmpty) {
                  return const AppEmptyState(
                    icon: Icons.shopping_bag_outlined,
                    title: 'Nada pendente por fornecedora nesta semana',
                    message:
                        'Quando faltar ingrediente ou embalagem para os próximos dias, os grupos aparecem aqui automaticamente.',
                  );
                }

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (final group in groups) ...[
                      _PurchaseSupplierGroupCard(
                        group: group,
                        isUpdatingItem: _isUpdatingItem,
                        onMarkPurchased: _openPurchaseSheet,
                        onOpenLinkedItem: _openLinkedItem,
                      ),
                      const SizedBox(height: 16),
                    ],
                  ],
                );
              },
            )
          else
            visibleItemsAsync.when(
              loading: () =>
                  const AppLoadingState(message: 'Atualizando a checklist...'),
              error: (error, stackTrace) => AppErrorState(
                title: 'Não foi possível carregar a checklist',
                message:
                    'Tente abrir a tela novamente. Os registros locais continuam salvos.',
                actionLabel: 'Recarregar',
                onAction: () => ref.invalidate(purchaseChecklistProvider),
              ),
              data: (items) {
                if (items.isEmpty) {
                  final title = switch (view) {
                    PurchaseListView.buyNow =>
                      'Nada urgente para comprar agora',
                    PurchaseListView.thisWeek =>
                      'Nada pendente para comprar nesta semana',
                    PurchaseListView.bySupplier => '',
                  };
                  final message = switch (view) {
                    PurchaseListView.buyNow =>
                      'Quando o estoque não cobrir o que sai hoje ou o mínimo necessário, os itens aparecem aqui.',
                    PurchaseListView.thisWeek =>
                      'A semana está coberta com o estoque atual e os mínimos configurados.',
                    PurchaseListView.bySupplier => '',
                  };

                  return AppEmptyState(
                    icon: Icons.shopping_bag_outlined,
                    title: title,
                    message: message,
                  );
                }

                return Column(
                  children: [
                    for (var index = 0; index < items.length; index++) ...[
                      _PurchaseChecklistCard(
                        item: items[index],
                        view: view,
                        isUpdating: _isUpdatingItem(items[index]),
                        onMarkPurchased: _openPurchaseSheet,
                        onOpenLinkedItem: _openLinkedItem,
                      ),
                      if (index != items.length - 1) const SizedBox(height: 12),
                    ],
                  ],
                );
              },
            ),
        ],
      ),
    );
  }

  bool _isUpdatingItem(PurchaseChecklistItemRecord item) {
    return _updatingItemKeys.contains(_itemKey(item));
  }

  Future<void> _openPurchaseSheet(PurchaseChecklistItemRecord item) async {
    final itemKey = _itemKey(item);
    if (_updatingItemKeys.contains(itemKey)) {
      return;
    }

    final currentView = ref.read(purchaseListViewProvider);
    final result = await showModalBottomSheet<_PurchaseSheetResult>(
      context: context,
      isScrollControlled: true,
      builder: (context) => _PurchaseSheet(item: item, view: currentView),
    );

    if (result == null) {
      return;
    }

    setState(() => _updatingItemKeys.add(itemKey));

    try {
      await ref
          .read(purchasesRepositoryProvider)
          .markItemPurchased(result.input);

      if (!mounted) {
        return;
      }

      final snackBarMessage = result.input.totalPrice.cents > 0
          ? 'Compra registrada, estoque atualizado e gasto preparado para o financeiro.'
          : 'Compra registrada e estoque atualizado neste aparelho.';

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(snackBarMessage)));
    } catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Não foi possível registrar a compra: $error')),
      );
    } finally {
      if (mounted) {
        setState(() => _updatingItemKeys.remove(itemKey));
      }
    }
  }

  void _openLinkedItem(PurchaseChecklistItemRecord item) {
    final linkedEntityId = item.linkedEntityId;
    if (linkedEntityId == null || linkedEntityId.trim().isEmpty) {
      return;
    }

    switch (item.materialType) {
      case OrderMaterialType.ingredient:
        context.push('${IngredientsPage.basePath}/$linkedEntityId');
        return;
      case OrderMaterialType.packaging:
        context.push('${PackagingPage.basePath}/$linkedEntityId');
        return;
    }
  }

  String _itemKey(PurchaseChecklistItemRecord item) {
    return '${item.materialType.databaseValue}:${item.linkedEntityId ?? item.nameSnapshot}';
  }
}

class _PurchasesSummaryCard extends StatelessWidget {
  const _PurchasesSummaryCard({
    required this.items,
    required this.preparedExpensesAsync,
  });

  final List<PurchaseChecklistItemRecord> items;
  final AsyncValue<List<PurchaseExpenseDraftRecord>> preparedExpensesAsync;

  @override
  Widget build(BuildContext context) {
    final buyNowCount = applyPurchaseView(
      items,
      PurchaseListView.buyNow,
    ).length;
    final thisWeekCount = applyPurchaseView(
      items,
      PurchaseListView.thisWeek,
    ).length;
    final supplierGroupCount = buildPurchaseGroupsBySupplier(
      applyPurchaseView(items, PurchaseListView.bySupplier),
    ).length;
    final preparedExpenses =
        preparedExpensesAsync.asData?.value ??
        const <PurchaseExpenseDraftRecord>[];
    final preparedExpenseTotal = preparedExpenses.fold(
      Money.zero,
      (total, draft) => total + draft.amount,
    );

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
                  'Leitura rápida das compras',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 6),
                Text(
                  'Uma visão curta do que pede ação agora, do que já entra na semana e do que já ficou pronto para o financeiro.',
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
                        label: 'Comprar agora',
                        value: buyNowCount.toString(),
                        attention: buyNowCount > 0,
                      ),
                    ),
                    SizedBox(
                      width: itemWidth,
                      child: AppSummaryMetricCard(
                        label: 'Nesta semana',
                        value: thisWeekCount.toString(),
                      ),
                    ),
                    SizedBox(
                      width: itemWidth,
                      child: AppSummaryMetricCard(
                        label: 'Grupos por fornecedora',
                        value: supplierGroupCount.toString(),
                      ),
                    ),
                    SizedBox(
                      width: itemWidth,
                      child: AppSummaryMetricCard(
                        label: 'Gastos preparados',
                        value: preparedExpenseTotal.isZero
                            ? preparedExpenses.length.toString()
                            : preparedExpenseTotal.format(),
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

class _PurchasesViewCard extends ConsumerWidget {
  const _PurchasesViewCard({required this.view});

  final PurchaseListView view;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Como olhar a lista',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            LayoutBuilder(
              builder: (context, constraints) {
                final compactLayout = constraints.maxWidth < 720;
                final button = SegmentedButton<PurchaseListView>(
                  segments: [
                    for (final option in PurchaseListView.values)
                      ButtonSegment<PurchaseListView>(
                        value: option,
                        label: Text(option.label),
                      ),
                  ],
                  selected: {view},
                  onSelectionChanged: (selection) {
                    ref
                        .read(purchaseListViewProvider.notifier)
                        .updateView(selection.first);
                  },
                );

                if (compactLayout) {
                  return SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: button,
                  );
                }

                return button;
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _PurchaseInfoCard extends StatelessWidget {
  const _PurchaseInfoCard();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.secondaryContainer,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Text(
        'Quando você marca uma compra, o estoque sobe na hora e a movimentação fica rastreável. Se houver valor, o app também já deixa o gasto preparado para o financeiro.',
        style: theme.textTheme.bodyMedium,
      ),
    );
  }
}

class _PurchaseChecklistCard extends StatelessWidget {
  const _PurchaseChecklistCard({
    required this.item,
    required this.view,
    required this.isUpdating,
    required this.onMarkPurchased,
    required this.onOpenLinkedItem,
  });

  final PurchaseChecklistItemRecord item;
  final PurchaseListView view;
  final bool isUpdating;
  final Future<void> Function(PurchaseChecklistItemRecord item) onMarkPurchased;
  final void Function(PurchaseChecklistItemRecord item) onOpenLinkedItem;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final estimatedCost = item.estimatedTotalCostFor(view);

    return Card(
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 8,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                _InlineBadge(label: item.materialType.label),
                if (item.buyNowShortageQuantity > 0 &&
                    view != PurchaseListView.thisWeek)
                  const _InlineBadge(
                    label: 'Urgente',
                    tone: _InlineBadgeTone.warning,
                  ),
                if (item.minimumGapQuantity > 0)
                  const _InlineBadge(label: 'Abaixo do mínimo'),
              ],
            ),
            const SizedBox(height: 16),
            Text(item.nameSnapshot, style: theme.textTheme.titleLarge),
            const SizedBox(height: 6),
            Text(
              '${item.categoryLabel} • Falta ${item.shortageLabelFor(view)}',
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                _MetricPill(
                  label: 'Comprar',
                  value: item.suggestedPurchaseLabelFor(view),
                ),
                _MetricPill(label: 'Estoque', value: item.displayCurrentStock),
                _MetricPill(label: 'Mínimo', value: item.displayMinimumStock),
                _MetricPill(
                  label: 'Pedidos ligados',
                  value: item.relatedOrders.length.toString(),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              item.hasSuggestedSupplier
                  ? 'Sugestão: ${item.supplierLabel} • ${item.suggestedSupplier!.displayLeadTime}'
                  : 'Sem fornecedora sugerida por enquanto.',
              style: theme.textTheme.bodyMedium,
            ),
            if (item.hasSuggestedSupplier) ...[
              const SizedBox(height: 4),
              Text(
                item.suggestedSupplier!.displayLastKnownPrice,
                style: theme.textTheme.bodySmall,
              ),
            ],
            if (estimatedCost != null) ...[
              const SizedBox(height: 8),
              Text(
                'Estimativa desta compra: ${estimatedCost.format()}',
                style: theme.textTheme.bodyMedium,
              ),
            ],
            const SizedBox(height: 8),
            Text(item.orderSummary, style: theme.textTheme.bodySmall),
            if (item.hasNotes) ...[
              const SizedBox(height: 8),
              Text(item.displayNote, style: theme.textTheme.bodySmall),
            ],
            const SizedBox(height: 16),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                OutlinedButton.icon(
                  onPressed: item.hasStockLink
                      ? () => onOpenLinkedItem(item)
                      : null,
                  icon: const Icon(Icons.open_in_new_rounded),
                  label: const Text('Abrir item'),
                ),
                FilledButton.icon(
                  onPressed: !item.canBeMarkedPurchased(view) || isUpdating
                      ? null
                      : () => onMarkPurchased(item),
                  icon: isUpdating
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2.2),
                        )
                      : const Icon(Icons.check_circle_outline_rounded),
                  label: Text(
                    item.hasStockLink
                        ? (isUpdating ? 'Registrando...' : 'Marcar compra')
                        : 'Sem vínculo com estoque',
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

class _PurchaseSupplierGroupCard extends StatelessWidget {
  const _PurchaseSupplierGroupCard({
    required this.group,
    required this.isUpdatingItem,
    required this.onMarkPurchased,
    required this.onOpenLinkedItem,
  });

  final PurchaseSupplierGroup group;
  final bool Function(PurchaseChecklistItemRecord item) isUpdatingItem;
  final Future<void> Function(PurchaseChecklistItemRecord item) onMarkPurchased;
  final void Function(PurchaseChecklistItemRecord item) onOpenLinkedItem;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 8,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(group.label, style: theme.textTheme.titleLarge),
                if (!group.estimatedTotal.isZero)
                  _InlineBadge(
                    label: 'Estimativa ${group.estimatedTotal.format()}',
                  ),
              ],
            ),
            const SizedBox(height: 6),
            Text(group.subtitle, style: theme.textTheme.bodyMedium),
            const SizedBox(height: 16),
            for (var index = 0; index < group.items.length; index++) ...[
              _PurchaseChecklistCard(
                item: group.items[index],
                view: PurchaseListView.bySupplier,
                isUpdating: isUpdatingItem(group.items[index]),
                onMarkPurchased: onMarkPurchased,
                onOpenLinkedItem: onOpenLinkedItem,
              ),
              if (index != group.items.length - 1) const SizedBox(height: 12),
            ],
          ],
        ),
      ),
    );
  }
}

class _MetricPill extends StatelessWidget {
  const _MetricPill({required this.label, required this.value});

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

enum _InlineBadgeTone { neutral, warning }

class _InlineBadge extends StatelessWidget {
  const _InlineBadge({
    required this.label,
    this.tone = _InlineBadgeTone.neutral,
  });

  final String label;
  final _InlineBadgeTone tone;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final backgroundColor = switch (tone) {
      _InlineBadgeTone.neutral => theme.colorScheme.surfaceContainerLow,
      _InlineBadgeTone.warning => theme.colorScheme.errorContainer,
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Text(label, style: theme.textTheme.labelLarge),
    );
  }
}

class _PurchaseSheet extends ConsumerStatefulWidget {
  const _PurchaseSheet({required this.item, required this.view});

  final PurchaseChecklistItemRecord item;
  final PurchaseListView view;

  @override
  ConsumerState<_PurchaseSheet> createState() => _PurchaseSheetState();
}

class _PurchaseSheetState extends ConsumerState<_PurchaseSheet> {
  static const _currencyFormatter = CurrencyTextInputFormatter();

  late final TextEditingController _purchaseQuantityController;
  late final TextEditingController _totalPriceController;
  late final TextEditingController _noteController;
  late bool _priceEditedManually;
  bool _updatingPriceFromSuggestion = false;

  int get _purchaseQuantity =>
      int.tryParse(_purchaseQuantityController.text.trim()) ?? 0;

  @override
  void initState() {
    super.initState();

    final suggestedPurchaseUnits = widget.item.suggestedPurchaseUnitsFor(
      widget.view,
    );
    _priceEditedManually = false;
    _purchaseQuantityController = TextEditingController(
      text: suggestedPurchaseUnits <= 0
          ? '1'
          : suggestedPurchaseUnits.toString(),
    )..addListener(_handlePurchaseQuantityChanged);
    _totalPriceController = TextEditingController(
      text: widget.item.suggestedSupplier?.lastKnownUnitPrice == null
          ? ''
          : widget.item.suggestedSupplier!.lastKnownUnitPrice!
                .multiply(
                  suggestedPurchaseUnits <= 0 ? 1 : suggestedPurchaseUnits,
                )
                .formatInput(),
    );
    _noteController = TextEditingController();
    _totalPriceController.addListener(_handleTotalPriceChanged);
  }

  @override
  void dispose() {
    _purchaseQuantityController
      ..removeListener(_handlePurchaseQuantityChanged)
      ..dispose();
    _totalPriceController
      ..removeListener(_handleTotalPriceChanged)
      ..dispose();
    _noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: 24,
          top: 24,
          right: 24,
          bottom: MediaQuery.of(context).viewInsets.bottom + 24,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Registrar compra', style: theme.textTheme.headlineSmall),
              const SizedBox(height: 8),
              Text(
                'Confirme o que entrou no estoque para a lista se recalcular sozinha.',
                style: theme.textTheme.bodyMedium,
              ),
              const SizedBox(height: 16),
              _InlineBadge(label: widget.item.nameSnapshot),
              const SizedBox(height: 16),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  _MetricPill(
                    label: 'Falta agora',
                    value: widget.item.shortageLabelFor(widget.view),
                  ),
                  _MetricPill(
                    label: 'Sugestão',
                    value: widget.item.suggestedPurchaseLabelFor(widget.view),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _purchaseQuantityController,
                keyboardType: TextInputType.number,
                inputFormatters: <TextInputFormatter>[
                  FilteringTextInputFormatter.digitsOnly,
                ],
                decoration: InputDecoration(
                  labelText:
                      'Quantidade comprada em ${widget.item.purchaseUnitLabel}',
                  helperText:
                      'Cada ${widget.item.purchaseUnitLabel} adiciona ${widget.item.stockUnitsPerPurchaseUnit} ${widget.item.stockUnitLabel} ao estoque.',
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _totalPriceController,
                keyboardType: TextInputType.number,
                inputFormatters: const <TextInputFormatter>[_currencyFormatter],
                decoration: InputDecoration(
                  labelText: 'Valor total da compra',
                  prefixText: 'R\$ ',
                  hintText: 'Opcional',
                  helperText: widget.item.hasSuggestedSupplier
                      ? 'Último preço conhecido: ${widget.item.suggestedSupplier!.displayLastKnownPrice}'
                      : 'Se deixar em branco, a compra entra sem gasto preparado.',
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _noteController,
                minLines: 2,
                maxLines: 4,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  labelText: 'Observações',
                  hintText:
                      'Ex.: comprada no mercado do bairro, valor promocional, lote maior',
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Cancelar'),
                  ),
                  const Spacer(),
                  FilledButton.icon(
                    onPressed: _confirmPurchase,
                    icon: const Icon(Icons.check_rounded),
                    label: const Text('Confirmar compra'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _confirmPurchase() {
    if (_purchaseQuantity <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Digite uma quantidade maior que zero.')),
      );
      return;
    }

    final linkedEntityId = widget.item.linkedEntityId;
    if (linkedEntityId == null || linkedEntityId.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Este item ainda não está ligado a um cadastro de estoque.',
          ),
        ),
      );
      return;
    }

    Navigator.of(context).pop(
      _PurchaseSheetResult(
        input: PurchaseMarkInput(
          materialType: widget.item.materialType,
          linkedEntityId: linkedEntityId,
          nameSnapshot: widget.item.nameSnapshot,
          purchaseUnitLabel: widget.item.purchaseUnitLabel,
          stockUnitLabel: widget.item.stockUnitLabel,
          purchaseQuantity: _purchaseQuantity,
          stockQuantityAdded:
              _purchaseQuantity * widget.item.stockUnitsPerPurchaseUnit,
          supplierId: widget.item.suggestedSupplier?.supplierId,
          supplierNameSnapshot: widget.item.suggestedSupplier?.supplierName,
          totalPrice: Money.fromInput(_totalPriceController.text),
          note: _noteController.text,
        ),
      ),
    );
  }

  void _handlePurchaseQuantityChanged() {
    if (_priceEditedManually) {
      return;
    }

    final unitPrice = widget.item.suggestedSupplier?.lastKnownUnitPrice;
    if (unitPrice == null) {
      return;
    }

    final purchaseQuantity = _purchaseQuantity <= 0 ? 1 : _purchaseQuantity;
    _updatingPriceFromSuggestion = true;
    _totalPriceController.value = TextEditingValue(
      text: unitPrice.multiply(purchaseQuantity).formatInput(),
      selection: TextSelection.collapsed(
        offset: unitPrice.multiply(purchaseQuantity).formatInput().length,
      ),
    );
    _updatingPriceFromSuggestion = false;
  }

  void _handleTotalPriceChanged() {
    if (_updatingPriceFromSuggestion) {
      return;
    }

    if (!_totalPriceController.text.contains(',')) {
      return;
    }

    _priceEditedManually = true;
  }
}

class _PurchaseSheetResult {
  const _PurchaseSheetResult({required this.input});

  final PurchaseMarkInput input;
}
