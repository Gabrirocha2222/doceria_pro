import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/formatters/app_formatters.dart';
import '../../../core/widgets/app_page_scaffold.dart';
import '../../../core/widgets/states/app_empty_state.dart';
import '../../../core/widgets/states/app_error_state.dart';
import '../../../core/widgets/states/app_loading_state.dart';
import '../../cost_benefit/presentation/cost_benefit_comparator_page.dart';
import '../application/ingredient_providers.dart';
import '../domain/ingredient.dart';
import '../domain/ingredient_stock_movement.dart';
import 'ingredients_page.dart';
import 'widgets/ingredient_stock_badge.dart';
import 'widgets/stock_movement_card.dart';

class IngredientDetailsPage extends ConsumerWidget {
  const IngredientDetailsPage({super.key, required this.ingredientId});

  final String ingredientId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ingredientAsync = ref.watch(ingredientProvider(ingredientId));
    final movementsAsync = ref.watch(
      ingredientStockMovementsProvider(ingredientId),
    );

    return ingredientAsync.when(
      loading: () => const AppPageScaffold(
        title: 'Carregando ingrediente',
        subtitle: 'Separando dados do estoque e histórico local.',
        child: AppLoadingState(message: 'Carregando ingrediente...'),
      ),
      error: (error, stackTrace) => AppPageScaffold(
        title: 'Ingrediente indisponível',
        subtitle: 'Não foi possível abrir este ingrediente agora.',
        child: AppErrorState(
          title: 'Não deu para abrir o ingrediente',
          message: 'Volte para a lista e tente novamente.',
          actionLabel: 'Voltar para estoque',
          onAction: () => context.go(IngredientsPage.basePath),
        ),
      ),
      data: (ingredient) {
        if (ingredient == null) {
          return AppPageScaffold(
            title: 'Ingrediente não encontrado',
            subtitle: 'Talvez ele não exista mais neste aparelho.',
            child: AppErrorState(
              title: 'Ingrediente não encontrado',
              message:
                  'Volte para a lista e confira os ingredientes salvos localmente.',
              actionLabel: 'Voltar para estoque',
              onAction: () => context.go(IngredientsPage.basePath),
            ),
          );
        }

        return AppPageScaffold(
          title: 'Detalhes do ingrediente',
          subtitle:
              'Resumo rápido para saber quanto tem, quando repor e o que mudou no estoque.',
          trailing: Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              OutlinedButton.icon(
                onPressed: () => context.go(IngredientsPage.basePath),
                icon: const Icon(Icons.arrow_back_rounded),
                label: const Text('Voltar'),
              ),
              FilledButton.tonalIcon(
                onPressed: () => context.push(
                  '${CostBenefitComparatorPage.basePath}?ingredientId=${ingredient.id}',
                ),
                icon: const Icon(Icons.balance_rounded),
                label: const Text('Comparar compra'),
              ),
              FilledButton.tonalIcon(
                onPressed: () => context.push(
                  '${IngredientsPage.basePath}/${ingredient.id}/adjust',
                ),
                icon: const Icon(Icons.sync_alt_rounded),
                label: const Text('Ajustar estoque'),
              ),
              FilledButton.tonalIcon(
                onPressed: () => context.push(
                  '${IngredientsPage.basePath}/${ingredient.id}/edit',
                ),
                icon: const Icon(Icons.edit_rounded),
                label: const Text('Editar'),
              ),
            ],
          ),
          child: _IngredientDetailsContent(
            ingredient: ingredient,
            movementsAsync: movementsAsync,
          ),
        );
      },
    );
  }
}

class _IngredientDetailsContent extends StatelessWidget {
  const _IngredientDetailsContent({
    required this.ingredient,
    required this.movementsAsync,
  });

  final IngredientRecord ingredient;
  final AsyncValue<List<IngredientStockMovementRecord>> movementsAsync;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _IngredientHeroCard(ingredient: ingredient),
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
                    title: 'Compra e custo',
                    content: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _LabelValueRow(
                          label: 'Categoria',
                          value: ingredient.displayCategory,
                        ),
                        const SizedBox(height: 12),
                        _LabelValueRow(
                          label: 'Unidade de compra',
                          value: ingredient.purchaseUnit.label,
                        ),
                        const SizedBox(height: 12),
                        _LabelValueRow(
                          label: 'Custo base',
                          value: ingredient.displayUnitCost,
                        ),
                        const SizedBox(height: 12),
                        _LabelValueRow(
                          label: 'Conversão',
                          value: ingredient.conversionSummary,
                        ),
                      ],
                    ),
                  ),
                ),
                SizedBox(
                  width: cardWidth,
                  child: _DetailsCard(
                    title: 'Estoque',
                    content: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _LabelValueRow(
                          label: 'Atual',
                          value: ingredient.displayCurrentStock,
                        ),
                        const SizedBox(height: 12),
                        _LabelValueRow(
                          label: 'Mínimo',
                          value: ingredient.displayMinimumStock,
                        ),
                        const SizedBox(height: 12),
                        _LabelValueRow(
                          label: 'Atualizado em',
                          value: AppFormatters.dayMonthYear(
                            ingredient.updatedAt,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                SizedBox(
                  width: constraints.maxWidth,
                  child: _DetailsCard(
                    title: 'Fornecedoras',
                    content: _IngredientSuppliersContent(
                      ingredient: ingredient,
                    ),
                  ),
                ),
                SizedBox(
                  width: constraints.maxWidth,
                  child: _DetailsCard(
                    title: 'Observações',
                    content: Text(
                      ingredient.displayNotes,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ),
                ),
                SizedBox(
                  width: constraints.maxWidth,
                  child: _StockMovementsCard(
                    ingredient: ingredient,
                    movementsAsync: movementsAsync,
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

class _IngredientHeroCard extends StatelessWidget {
  const _IngredientHeroCard({required this.ingredient});

  final IngredientRecord ingredient;

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
          IngredientStockBadge(isLowStock: ingredient.isLowStock),
          const SizedBox(height: 16),
          Text(ingredient.name, style: theme.textTheme.headlineSmall),
          const SizedBox(height: 6),
          Text(ingredient.displayCategory, style: theme.textTheme.bodyLarge),
          const SizedBox(height: 20),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _HeroMetric(
                label: 'Atual',
                value: ingredient.displayCurrentStock,
              ),
              _HeroMetric(
                label: 'Mínimo',
                value: ingredient.displayMinimumStock,
              ),
              _HeroMetric(label: 'Compra', value: ingredient.conversionSummary),
            ],
          ),
        ],
      ),
    );
  }
}

class _IngredientSuppliersContent extends StatelessWidget {
  const _IngredientSuppliersContent({required this.ingredient});

  final IngredientRecord ingredient;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (ingredient.linkedSuppliers.isEmpty) {
      return Text(
        ingredient.defaultSupplier?.trim().isNotEmpty == true
            ? 'Cadastro anterior: ${ingredient.defaultSupplier!.trim()}. Você pode ligar essa fornecedora a um cadastro próprio quando quiser.'
            : 'Nenhuma fornecedora ligada ainda.',
        style: theme.textTheme.bodyMedium,
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (
          var index = 0;
          index < ingredient.linkedSuppliers.length;
          index++
        ) ...[
          _IngredientSupplierRow(supplier: ingredient.linkedSuppliers[index]),
          if (index != ingredient.linkedSuppliers.length - 1)
            const Divider(height: 24),
        ],
      ],
    );
  }
}

class _IngredientSupplierRow extends StatelessWidget {
  const _IngredientSupplierRow({required this.supplier});

  final IngredientLinkedSupplierRecord supplier;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            Text(supplier.supplierName, style: theme.textTheme.titleMedium),
            if (supplier.isDefaultPreferred)
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: theme.colorScheme.outlineVariant),
                ),
                child: Text('Preferida', style: theme.textTheme.labelLarge),
              ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          '${supplier.displayLastKnownPrice} • ${supplier.displayLeadTime}',
          style: theme.textTheme.bodyMedium,
        ),
        const SizedBox(height: 4),
        Text(supplier.displayContact, style: theme.textTheme.bodySmall),
      ],
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

class _StockMovementsCard extends StatelessWidget {
  const _StockMovementsCard({
    required this.ingredient,
    required this.movementsAsync,
  });

  final IngredientRecord ingredient;
  final AsyncValue<List<IngredientStockMovementRecord>> movementsAsync;

  @override
  Widget build(BuildContext context) {
    return _DetailsCard(
      title: 'Movimentações de estoque',
      content: movementsAsync.when(
        loading: () =>
            const AppLoadingState(message: 'Carregando movimentações...'),
        error: (error, stackTrace) =>
            const Text('Não foi possível carregar o histórico agora.'),
        data: (movements) {
          if (movements.isEmpty) {
            return const AppEmptyState(
              icon: Icons.history_rounded,
              title: 'Nenhuma movimentação registrada',
              message:
                  'Quando você ajustar este estoque, o histórico aparece aqui para manter rastreabilidade local.',
            );
          }

          return Column(
            children: [
              for (var index = 0; index < movements.length; index++) ...[
                StockMovementCard(
                  movement: movements[index],
                  stockUnit: ingredient.stockUnit,
                ),
                if (index != movements.length - 1) const SizedBox(height: 12),
              ],
            ],
          );
        },
      ),
    );
  }
}
