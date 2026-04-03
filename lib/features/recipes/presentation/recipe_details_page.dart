import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/formatters/app_formatters.dart';
import '../../../core/widgets/app_page_scaffold.dart';
import '../../../core/widgets/states/app_error_state.dart';
import '../../../core/widgets/states/app_loading_state.dart';
import '../application/recipe_providers.dart';
import '../domain/recipe.dart';
import 'recipes_page.dart';
import 'widgets/recipe_type_badge.dart';

class RecipeDetailsPage extends ConsumerWidget {
  const RecipeDetailsPage({super.key, required this.recipeId});

  final String recipeId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final recipeAsync = ref.watch(recipeProvider(recipeId));

    return recipeAsync.when(
      loading: () => const AppPageScaffold(
        title: 'Carregando receita',
        subtitle: 'Separando custo, rendimento e ingredientes.',
        child: AppLoadingState(message: 'Carregando receita...'),
      ),
      error: (error, stackTrace) => AppPageScaffold(
        title: 'Receita indisponível',
        subtitle: 'Não foi possível abrir esta receita agora.',
        child: AppErrorState(
          title: 'Não deu para abrir a receita',
          message: 'Volte para a lista e tente novamente.',
          actionLabel: 'Voltar para receitas',
          onAction: () => context.go(RecipesPage.basePath),
        ),
      ),
      data: (recipe) {
        if (recipe == null) {
          return AppPageScaffold(
            title: 'Receita não encontrada',
            subtitle: 'Talvez ela não exista mais neste aparelho.',
            child: AppErrorState(
              title: 'Receita não encontrada',
              message:
                  'Volte para a lista e confira as receitas salvas localmente.',
              actionLabel: 'Voltar para receitas',
              onAction: () => context.go(RecipesPage.basePath),
            ),
          );
        }

        return AppPageScaffold(
          title: 'Detalhes da receita',
          subtitle:
              'Resumo rápido do preparo, do custo e do que já está ligado aos seus produtos.',
          trailing: Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              OutlinedButton.icon(
                onPressed: () => context.go(RecipesPage.basePath),
                icon: const Icon(Icons.arrow_back_rounded),
                label: const Text('Voltar'),
              ),
              FilledButton.tonalIcon(
                onPressed: () =>
                    context.push('${RecipesPage.basePath}/${recipe.id}/edit'),
                icon: const Icon(Icons.edit_rounded),
                label: const Text('Editar'),
              ),
            ],
          ),
          child: _RecipeDetailsContent(recipe: recipe),
        );
      },
    );
  }
}

class _RecipeDetailsContent extends StatelessWidget {
  const _RecipeDetailsContent({required this.recipe});

  final RecipeRecord recipe;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _RecipeHeroCard(recipe: recipe),
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
                    title: 'Rendimento e custo',
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _LabelValueRow(
                          label: 'Rendimento',
                          value: recipe.displayYield,
                        ),
                        const SizedBox(height: 12),
                        _LabelValueRow(
                          label: 'Custo total',
                          value: recipe.totalCostLabel,
                        ),
                        const SizedBox(height: 12),
                        _LabelValueRow(
                          label: 'Custo por base',
                          value: recipe.costPerYieldLabel,
                        ),
                        const SizedBox(height: 12),
                        _LabelValueRow(
                          label: 'Atualizada em',
                          value: AppFormatters.dayMonthYear(recipe.updatedAt),
                        ),
                      ],
                    ),
                  ),
                ),
                SizedBox(
                  width: cardWidth,
                  child: _DetailsCard(
                    title: 'Estrutura',
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _LabelValueRow(label: 'Tipo', value: recipe.type.label),
                        const SizedBox(height: 12),
                        _LabelValueRow(
                          label: 'Base',
                          value: recipe.displayBaseLabel,
                        ),
                        const SizedBox(height: 12),
                        _LabelValueRow(
                          label: 'Sabor',
                          value: recipe.displayFlavorLabel,
                        ),
                        const SizedBox(height: 12),
                        _LabelValueRow(
                          label: 'Ligada a',
                          value: recipe.linkedProducts.isEmpty
                              ? 'Nenhum produto ainda'
                              : '${recipe.linkedProducts.length} ${recipe.linkedProducts.length == 1 ? 'produto' : 'produtos'}',
                        ),
                      ],
                    ),
                  ),
                ),
                SizedBox(
                  width: constraints.maxWidth,
                  child: _DetailsCard(
                    title: 'Ingredientes',
                    child: recipe.items.isEmpty
                        ? Text(
                            'Nenhum ingrediente foi adicionado ainda.',
                            style: Theme.of(context).textTheme.bodyMedium,
                          )
                        : Column(
                            children: [
                              for (
                                var index = 0;
                                index < recipe.items.length;
                                index++
                              ) ...[
                                _RecipeItemTile(item: recipe.items[index]),
                                if (index != recipe.items.length - 1)
                                  const Divider(height: 24),
                              ],
                            ],
                          ),
                  ),
                ),
                SizedBox(
                  width: cardWidth,
                  child: _DetailsCard(
                    title: 'Produtos ligados',
                    child: recipe.linkedProducts.isEmpty
                        ? Text(
                            'Nenhum produto usa esta receita ainda.',
                            style: Theme.of(context).textTheme.bodyMedium,
                          )
                        : Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              for (
                                var index = 0;
                                index < recipe.linkedProducts.length;
                                index++
                              ) ...[
                                Text(
                                  recipe.linkedProducts[index].productName,
                                  style: Theme.of(
                                    context,
                                  ).textTheme.titleMedium,
                                ),
                                if (index != recipe.linkedProducts.length - 1)
                                  const SizedBox(height: 10),
                              ],
                            ],
                          ),
                  ),
                ),
                SizedBox(
                  width: cardWidth,
                  child: _DetailsCard(
                    title: 'Observações',
                    child: Text(
                      recipe.displayNotes,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
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

class _RecipeHeroCard extends StatelessWidget {
  const _RecipeHeroCard({required this.recipe});

  final RecipeRecord recipe;

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
              RecipeTypeBadge(type: recipe.type),
              if (recipe.costSummary.hasMissingIngredients)
                _AttentionBadge(
                  label: 'Falta revisar ingrediente',
                  icon: Icons.warning_amber_rounded,
                ),
            ],
          ),
          const SizedBox(height: 16),
          Text(recipe.name, style: theme.textTheme.headlineSmall),
          const SizedBox(height: 6),
          Text(recipe.structureSummary, style: theme.textTheme.bodyLarge),
          const SizedBox(height: 20),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _HeroMetric(label: 'Rendimento', value: recipe.displayYield),
              _HeroMetric(label: 'Custo total', value: recipe.totalCostLabel),
              _HeroMetric(
                label: 'Custo por base',
                value: recipe.costPerYieldLabel,
              ),
            ],
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

class _AttentionBadge extends StatelessWidget {
  const _AttentionBadge({required this.label, required this.icon});

  final String label;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: theme.colorScheme.errorContainer,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: theme.colorScheme.onErrorContainer),
          const SizedBox(width: 6),
          Text(
            label,
            style: theme.textTheme.labelLarge?.copyWith(
              color: theme.colorScheme.onErrorContainer,
            ),
          ),
        ],
      ),
    );
  }
}

class _DetailsCard extends StatelessWidget {
  const _DetailsCard({required this.title, required this.child});

  final String title;
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
            const SizedBox(height: 16),
            child,
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
        Text(value, style: Theme.of(context).textTheme.bodyLarge),
      ],
    );
  }
}

class _RecipeItemTile extends StatelessWidget {
  const _RecipeItemTile({required this.item});

  final RecipeItemRecord item;

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
              Text(
                item.displayIngredientName,
                style: theme.textTheme.titleMedium,
              ),
              const SizedBox(height: 6),
              Text(
                '${item.displayQuantity} • ${item.lineCost.format()}',
                style: theme.textTheme.bodyMedium,
              ),
              if (item.notes?.trim().isNotEmpty ?? false) ...[
                const SizedBox(height: 6),
                Text(item.displayNotes, style: theme.textTheme.bodySmall),
              ],
            ],
          ),
        ),
        if (!item.ingredientAvailable)
          Icon(Icons.warning_amber_rounded, color: theme.colorScheme.error),
      ],
    );
  }
}
