import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/navigation/app_destinations.dart';
import '../../../core/widgets/app_page_scaffold.dart';
import '../../../core/widgets/app_summary_metric_card.dart';
import '../../../core/widgets/states/app_empty_state.dart';
import '../../../core/widgets/states/app_error_state.dart';
import '../../../core/widgets/states/app_loading_state.dart';
import '../application/ingredient_providers.dart';
import '../domain/ingredient.dart';
import '../domain/ingredient_list_filters.dart';
import 'widgets/ingredient_stock_badge.dart';

class IngredientsPage extends ConsumerWidget {
  const IngredientsPage({super.key});

  static final basePath = '${AppDestinations.purchases.path}/stock';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final allIngredientsAsync = ref.watch(allIngredientsProvider);
    final filteredIngredientsAsync = ref.watch(filteredIngredientsProvider);
    final lowStockIngredientsAsync = ref.watch(lowStockIngredientsProvider);
    final filters = ref.watch(ingredientListFiltersProvider);

    return AppPageScaffold(
      title: 'Ingredientes e estoque',
      subtitle:
          'Veja o que está saudável no estoque e o que já pede reposição sem transformar isso em tela pesada.',
      trailing: FilledButton.icon(
        onPressed: () => context.push('$basePath/new'),
        icon: const Icon(Icons.add_box_outlined),
        label: const Text('Novo ingrediente'),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          lowStockIngredientsAsync.when(
            loading: () => const AppLoadingState(message: 'Lendo alertas...'),
            error: (error, stackTrace) => const SizedBox.shrink(),
            data: (ingredients) => _LowStockAlertCard(ingredients: ingredients),
          ),
          const SizedBox(height: 16),
          allIngredientsAsync.when(
            loading: () =>
                const AppLoadingState(message: 'Carregando ingredientes...'),
            error: (error, stackTrace) => AppErrorState(
              title: 'Não foi possível carregar o estoque',
              message: 'Tente fechar e abrir a tela novamente.',
              actionLabel: 'Tentar de novo',
              onAction: () => ref.invalidate(allIngredientsProvider),
            ),
            data: (ingredients) =>
                _IngredientsSummaryCard(ingredients: ingredients),
          ),
          const SizedBox(height: 16),
          _IngredientFiltersCard(filters: filters),
          const SizedBox(height: 16),
          filteredIngredientsAsync.when(
            loading: () =>
                const AppLoadingState(message: 'Atualizando a lista...'),
            error: (error, stackTrace) => AppErrorState(
              title: 'Não deu para montar a lista',
              message:
                  'Os ingredientes continuam salvos localmente, mas a visualização falhou agora.',
              actionLabel: 'Recarregar',
              onAction: () => ref.invalidate(allIngredientsProvider),
            ),
            data: (ingredients) {
              if (ingredients.isEmpty) {
                return AppEmptyState(
                  icon: Icons.inventory_2_outlined,
                  title: filters.hasActiveFilters
                      ? 'Nenhum ingrediente bate com esse filtro'
                      : 'Nenhum ingrediente salvo ainda',
                  message: filters.hasActiveFilters
                      ? 'Tente limpar os filtros para voltar a enxergar seu estoque.'
                      : 'Comece pelos ingredientes que mais saem. O restante pode entrar aos poucos.',
                  actionLabel: filters.hasActiveFilters
                      ? 'Limpar filtros'
                      : 'Criar ingrediente',
                  onAction: () {
                    if (filters.hasActiveFilters) {
                      ref.read(ingredientListFiltersProvider.notifier).clear();
                      return;
                    }

                    context.push('$basePath/new');
                  },
                );
              }

              return Column(
                children: [
                  for (var index = 0; index < ingredients.length; index++) ...[
                    _IngredientListCard(
                      ingredient: ingredients[index],
                      onTap: () =>
                          context.push('$basePath/${ingredients[index].id}'),
                    ),
                    if (index != ingredients.length - 1)
                      const SizedBox(height: 12),
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

class _LowStockAlertCard extends StatelessWidget {
  const _LowStockAlertCard({required this.ingredients});

  final List<IngredientRecord> ingredients;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (ingredients.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: theme.colorScheme.secondaryContainer,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: theme.colorScheme.outlineVariant),
        ),
        child: Text(
          'Seu estoque está sem alertas de mínimo neste momento.',
          style: theme.textTheme.bodyMedium,
        ),
      );
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.errorContainer,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${ingredients.length} ${ingredients.length == 1 ? 'ingrediente está' : 'ingredientes estão'} com estoque baixo',
            style: theme.textTheme.titleMedium,
          ),
          const SizedBox(height: 4),
          Text(
            ingredients
                .take(3)
                .map((ingredient) => ingredient.name)
                .join(' • '),
            style: theme.textTheme.bodyMedium,
          ),
        ],
      ),
    );
  }
}

class _IngredientsSummaryCard extends StatelessWidget {
  const _IngredientsSummaryCard({required this.ingredients});

  final List<IngredientRecord> ingredients;

  @override
  Widget build(BuildContext context) {
    final lowStock = ingredients
        .where((ingredient) => ingredient.isLowStock)
        .length;
    final withSupplier = ingredients
        .where((ingredient) => ingredient.hasSupplierReference)
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

            return Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                SizedBox(
                  width: itemWidth,
                  child: AppSummaryMetricCard(
                    label: 'Ingredientes salvos',
                    value: ingredients.length.toString(),
                  ),
                ),
                SizedBox(
                  width: itemWidth,
                  child: AppSummaryMetricCard(
                    label: 'Com alerta',
                    value: lowStock.toString(),
                  ),
                ),
                SizedBox(
                  width: itemWidth,
                  child: AppSummaryMetricCard(
                    label: 'Com fornecedora',
                    value: withSupplier.toString(),
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

class _IngredientFiltersCard extends ConsumerStatefulWidget {
  const _IngredientFiltersCard({required this.filters});

  final IngredientListFilters filters;

  @override
  ConsumerState<_IngredientFiltersCard> createState() =>
      _IngredientFiltersCardState();
}

class _IngredientFiltersCardState
    extends ConsumerState<_IngredientFiltersCard> {
  late final TextEditingController _searchController;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController(text: widget.filters.searchQuery);
  }

  @override
  void didUpdateWidget(covariant _IngredientFiltersCard oldWidget) {
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
    final notifier = ref.read(ingredientListFiltersProvider.notifier);

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
                hintText: 'Buscar por nome, categoria ou fornecedora',
                prefixIcon: Icon(Icons.search_rounded),
              ),
            ),
            const SizedBox(height: 16),
            SegmentedButton<IngredientStockFilter>(
              showSelectedIcon: false,
              selected: {widget.filters.stockFilter},
              segments: [
                for (final filter in IngredientStockFilter.values)
                  ButtonSegment<IngredientStockFilter>(
                    value: filter,
                    label: Text(filter.label),
                  ),
              ],
              onSelectionChanged: (selection) {
                notifier.updateStockFilter(selection.first);
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

class _IngredientListCard extends StatelessWidget {
  const _IngredientListCard({required this.ingredient, required this.onTap});

  final IngredientRecord ingredient;
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
                        Text(
                          ingredient.name,
                          style: theme.textTheme.titleLarge,
                        ),
                        const SizedBox(height: 6),
                        Text(
                          '${ingredient.displayCategory} • ${ingredient.displayUnitCost}',
                          style: theme.textTheme.bodyMedium,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  IngredientStockBadge(isLowStock: ingredient.isLowStock),
                ],
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  _MetricPill(
                    label: 'Atual',
                    value: ingredient.displayCurrentStock,
                  ),
                  _MetricPill(
                    label: 'Mínimo',
                    value: ingredient.displayMinimumStock,
                  ),
                  _MetricPill(
                    label: 'Compra',
                    value: ingredient.conversionSummary,
                  ),
                ],
              ),
              if (ingredient.hasSupplierReference) ...[
                const SizedBox(height: 16),
                Text(
                  'Fornecedora: ${ingredient.displaySupplier}',
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
