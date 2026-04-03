import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/navigation/app_destinations.dart';
import '../../../core/widgets/app_page_scaffold.dart';
import '../../../core/widgets/app_summary_metric_card.dart';
import '../../../core/widgets/states/app_empty_state.dart';
import '../../../core/widgets/states/app_error_state.dart';
import '../../../core/widgets/states/app_loading_state.dart';
import '../application/recipe_providers.dart';
import '../domain/recipe.dart';
import '../domain/recipe_list_filters.dart';
import 'widgets/recipe_type_badge.dart';

class RecipesPage extends ConsumerWidget {
  const RecipesPage({super.key});

  static final basePath = '${AppDestinations.businessSettings.path}/recipes';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final allRecipesAsync = ref.watch(allRecipesProvider);
    final filteredRecipesAsync = ref.watch(filteredRecipesProvider);
    final filters = ref.watch(recipeListFiltersProvider);

    return AppPageScaffold(
      title: 'Receitas',
      subtitle:
          'Guarde o preparo base com custo automático para decidir melhor preço, margem e uso em produtos.',
      trailing: FilledButton.icon(
        onPressed: () => context.push('$basePath/new'),
        icon: const Icon(Icons.menu_book_rounded),
        label: const Text('Nova receita'),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          allRecipesAsync.when(
            loading: () =>
                const AppLoadingState(message: 'Carregando receitas...'),
            error: (error, stackTrace) => AppErrorState(
              title: 'Não foi possível carregar as receitas',
              message: 'Tente fechar e abrir a tela novamente.',
              actionLabel: 'Tentar de novo',
              onAction: () => ref.invalidate(allRecipesProvider),
            ),
            data: (recipes) => _RecipesSummaryCard(recipes: recipes),
          ),
          const SizedBox(height: 16),
          _RecipeFiltersCard(filters: filters),
          const SizedBox(height: 16),
          filteredRecipesAsync.when(
            loading: () =>
                const AppLoadingState(message: 'Atualizando a lista...'),
            error: (error, stackTrace) => AppErrorState(
              title: 'Não deu para montar a lista',
              message:
                  'As receitas continuam salvas localmente, mas a visualização falhou agora.',
              actionLabel: 'Recarregar',
              onAction: () => ref.invalidate(allRecipesProvider),
            ),
            data: (recipes) {
              if (recipes.isEmpty) {
                return AppEmptyState(
                  icon: Icons.menu_book_outlined,
                  title: filters.hasActiveFilters
                      ? 'Nenhuma receita bate com esse filtro'
                      : 'Nenhuma receita salva ainda',
                  message: filters.hasActiveFilters
                      ? 'Tente limpar os filtros para voltar a enxergar sua base de preparo.'
                      : 'Comece pelas receitas que mais pesam no seu custo. O restante pode entrar depois.',
                  actionLabel: filters.hasActiveFilters
                      ? 'Limpar filtros'
                      : 'Criar receita',
                  onAction: () {
                    if (filters.hasActiveFilters) {
                      ref.read(recipeListFiltersProvider.notifier).clear();
                      return;
                    }

                    context.push('$basePath/new');
                  },
                );
              }

              return Column(
                children: [
                  for (var index = 0; index < recipes.length; index++) ...[
                    _RecipeListCard(
                      recipe: recipes[index],
                      onTap: () =>
                          context.push('$basePath/${recipes[index].id}'),
                    ),
                    if (index != recipes.length - 1) const SizedBox(height: 12),
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

class _RecipesSummaryCard extends StatelessWidget {
  const _RecipesSummaryCard({required this.recipes});

  final List<RecipeRecord> recipes;

  @override
  Widget build(BuildContext context) {
    final withItems = recipes.where((recipe) => recipe.items.isNotEmpty).length;
    final linkedToProducts = recipes
        .where((recipe) => recipe.linkedProducts.isNotEmpty)
        .length;
    final withWarnings = recipes
        .where((recipe) => recipe.costSummary.hasMissingIngredients)
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
                    label: 'Receitas salvas',
                    value: recipes.length.toString(),
                  ),
                ),
                SizedBox(
                  width: itemWidth,
                  child: AppSummaryMetricCard(
                    label: 'Com ingredientes',
                    value: withItems.toString(),
                  ),
                ),
                SizedBox(
                  width: itemWidth,
                  child: AppSummaryMetricCard(
                    label: 'Ligadas a produtos',
                    value: linkedToProducts.toString(),
                  ),
                ),
                SizedBox(
                  width: itemWidth,
                  child: AppSummaryMetricCard(
                    label: 'Com alerta',
                    value: withWarnings.toString(),
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

class _RecipeFiltersCard extends ConsumerStatefulWidget {
  const _RecipeFiltersCard({required this.filters});

  final RecipeListFilters filters;

  @override
  ConsumerState<_RecipeFiltersCard> createState() => _RecipeFiltersCardState();
}

class _RecipeFiltersCardState extends ConsumerState<_RecipeFiltersCard> {
  late final TextEditingController _searchController;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController(text: widget.filters.searchQuery);
  }

  @override
  void didUpdateWidget(covariant _RecipeFiltersCard oldWidget) {
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
    final notifier = ref.read(recipeListFiltersProvider.notifier);

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
                hintText: 'Buscar por nome, tipo, base ou sabor',
                prefixIcon: Icon(Icons.search_rounded),
              ),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final typeFilter in RecipeTypeFilter.values)
                  ChoiceChip(
                    label: Text(typeFilter.label),
                    selected: widget.filters.typeFilter == typeFilter,
                    onSelected: (_) => notifier.updateTypeFilter(typeFilter),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _RecipeListCard extends StatelessWidget {
  const _RecipeListCard({required this.recipe, required this.onTap});

  final RecipeRecord recipe;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return InkWell(
      borderRadius: BorderRadius.circular(28),
      onTap: onTap,
      child: Ink(
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: theme.colorScheme.outlineVariant),
        ),
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
                  RecipeTypeBadge(type: recipe.type),
                  if (recipe.linkedProducts.isNotEmpty)
                    _InlineBadge(
                      label:
                          '${recipe.linkedProducts.length} ${recipe.linkedProducts.length == 1 ? 'produto ligado' : 'produtos ligados'}',
                    ),
                  if (recipe.costSummary.hasMissingIngredients)
                    _InlineBadge(
                      label: 'Falta revisar ingrediente',
                      tone: _InlineBadgeTone.warning,
                    ),
                ],
              ),
              const SizedBox(height: 14),
              Text(recipe.name, style: theme.textTheme.titleLarge),
              const SizedBox(height: 6),
              Text(recipe.structureSummary, style: theme.textTheme.bodyMedium),
              const SizedBox(height: 16),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  _MetricPill(label: 'Rendimento', value: recipe.displayYield),
                  _MetricPill(
                    label: 'Custo total',
                    value: recipe.totalCostLabel,
                  ),
                  _MetricPill(
                    label: 'Custo por base',
                    value: recipe.costPerYieldLabel,
                  ),
                  _MetricPill(
                    label: 'Ingredientes',
                    value:
                        '${recipe.itemCount} ${recipe.itemCount == 1 ? 'item' : 'itens'}',
                  ),
                ],
              ),
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
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: theme.textTheme.labelLarge),
          const SizedBox(height: 6),
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
    final backgroundColor = tone == _InlineBadgeTone.warning
        ? theme.colorScheme.errorContainer
        : theme.colorScheme.tertiaryContainer;
    final foregroundColor = tone == _InlineBadgeTone.warning
        ? theme.colorScheme.onErrorContainer
        : theme.colorScheme.onTertiaryContainer;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: theme.textTheme.labelLarge?.copyWith(color: foregroundColor),
      ),
    );
  }
}
