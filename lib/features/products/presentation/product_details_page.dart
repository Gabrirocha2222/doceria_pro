import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/navigation/app_destinations.dart';
import '../../../core/formatters/app_formatters.dart';
import '../../../core/widgets/app_page_scaffold.dart';
import '../../../core/widgets/states/app_error_state.dart';
import '../../../core/widgets/states/app_loading_state.dart';
import '../application/product_providers.dart';
import '../domain/product.dart';
import 'widgets/product_sale_mode_badge.dart';
import 'widgets/product_state_badge.dart';
import 'widgets/product_type_badge.dart';

class ProductDetailsPage extends ConsumerWidget {
  const ProductDetailsPage({super.key, required this.productId});

  final String productId;

  static final basePath = '${AppDestinations.businessSettings.path}/products';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final productAsync = ref.watch(productProvider(productId));

    return productAsync.when(
      loading: () => const AppPageScaffold(
        title: 'Carregando produto',
        subtitle: 'Separando a base comercial e as opções deste produto.',
        child: AppLoadingState(message: 'Carregando produto...'),
      ),
      error: (error, stackTrace) => AppPageScaffold(
        title: 'Produto indisponível',
        subtitle: 'Não foi possível abrir este produto agora.',
        child: AppErrorState(
          title: 'Não deu para abrir o produto',
          message: 'Volte para a lista e tente novamente.',
          actionLabel: 'Voltar para produtos',
          onAction: () => context.go(basePath),
        ),
      ),
      data: (product) {
        if (product == null) {
          return AppPageScaffold(
            title: 'Produto não encontrado',
            subtitle: 'Talvez ele não exista mais neste aparelho.',
            child: AppErrorState(
              title: 'Produto não encontrado',
              message: 'Volte para a lista e confira os produtos locais.',
              actionLabel: 'Voltar para produtos',
              onAction: () => context.go(basePath),
            ),
          );
        }

        return AppPageScaffold(
          title: 'Detalhes do produto',
          subtitle:
              'Resumo claro da base comercial para você decidir rápido quando usar este produto em pedidos.',
          trailing: Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              OutlinedButton.icon(
                onPressed: () => context.go(basePath),
                icon: const Icon(Icons.arrow_back_rounded),
                label: const Text('Voltar'),
              ),
              FilledButton.tonalIcon(
                onPressed: () => context.push('$basePath/${product.id}/edit'),
                icon: const Icon(Icons.edit_rounded),
                label: const Text('Editar'),
              ),
            ],
          ),
          child: _ProductDetailsContent(product: product),
        );
      },
    );
  }
}

class _ProductDetailsContent extends StatelessWidget {
  const _ProductDetailsContent({required this.product});

  final ProductRecord product;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _ProductHeroCard(product: product),
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
                    title: 'Base comercial',
                    content: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _LabelValueRow(
                          label: 'Categoria',
                          value: product.displayCategory,
                        ),
                        const SizedBox(height: 12),
                        _LabelValueRow(
                          label: 'Tipo',
                          value: product.type.label,
                        ),
                        const SizedBox(height: 12),
                        _LabelValueRow(
                          label: 'Modo de venda',
                          value: product.saleMode.label,
                        ),
                        const SizedBox(height: 12),
                        _LabelValueRow(
                          label: 'Preço base',
                          value: product.priceLabel,
                        ),
                        const SizedBox(height: 12),
                        _LabelValueRow(
                          label: 'Referência',
                          value: product.displayYieldHint,
                        ),
                      ],
                    ),
                  ),
                ),
                SizedBox(
                  width: cardWidth,
                  child: _DetailsCard(
                    title: 'Status e atualização',
                    content: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _LabelValueRow(
                          label: 'Situação',
                          value: product.isActive ? 'Ativo' : 'Inativo',
                        ),
                        const SizedBox(height: 12),
                        _LabelValueRow(
                          label: 'Atualizado em',
                          value: AppFormatters.dayMonthYear(product.updatedAt),
                        ),
                        const SizedBox(height: 12),
                        _LabelValueRow(
                          label: 'Criado em',
                          value: AppFormatters.dayMonthYear(product.createdAt),
                        ),
                      ],
                    ),
                  ),
                ),
                SizedBox(
                  width: constraints.maxWidth,
                  child: _DetailsCard(
                    title: 'Observações',
                    content: Text(
                      product.displayNotes,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ),
                ),
                SizedBox(
                  width: cardWidth,
                  child: _OptionsCard(
                    title: 'Sabores',
                    options: product.flavors,
                  ),
                ),
                SizedBox(
                  width: cardWidth,
                  child: _OptionsCard(
                    title: 'Variações',
                    options: product.variations,
                  ),
                ),
                SizedBox(
                  width: constraints.maxWidth,
                  child: _LinkedRecipesCard(recipes: product.linkedRecipes),
                ),
                SizedBox(
                  width: constraints.maxWidth,
                  child: _LinkedPackagingCard(
                    packagings: product.linkedPackagings,
                    defaultSuggestedPackaging:
                        product.defaultSuggestedPackaging,
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

class _ProductHeroCard extends StatelessWidget {
  const _ProductHeroCard({required this.product});

  final ProductRecord product;

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
              ProductTypeBadge(type: product.type),
              ProductSaleModeBadge(saleMode: product.saleMode),
              ProductStateBadge(isActive: product.isActive),
            ],
          ),
          const SizedBox(height: 16),
          Text(product.name, style: theme.textTheme.headlineSmall),
          const SizedBox(height: 6),
          Text(product.displayCategory, style: theme.textTheme.bodyLarge),
          const SizedBox(height: 20),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _HeroMetric(label: 'Preço base', value: product.priceLabel),
              _HeroMetric(
                label: 'Opções',
                value:
                    '${product.flavors.length} sabores • ${product.variations.length} variações',
              ),
              _HeroMetric(
                label: 'Receitas',
                value: product.linkedRecipes.isEmpty
                    ? 'Nenhuma ligada'
                    : '${product.linkedRecipes.length} ${product.linkedRecipes.length == 1 ? 'ligada' : 'ligadas'}',
              ),
              _HeroMetric(
                label: 'Embalagens',
                value: product.linkedPackagings.isEmpty
                    ? 'Nenhuma ligada'
                    : '${product.linkedPackagings.length} ${product.linkedPackagings.length == 1 ? 'compatível' : 'compatíveis'}',
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

class _OptionsCard extends StatelessWidget {
  const _OptionsCard({required this.title, required this.options});

  final String title;
  final List<ProductOptionRecord> options;

  @override
  Widget build(BuildContext context) {
    return _DetailsCard(
      title: title,
      content: options.isEmpty
          ? Text(
              'Nenhuma opção registrada ainda.',
              style: Theme.of(context).textTheme.bodyMedium,
            )
          : Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final option in options)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surfaceContainerLow,
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Text(option.name),
                  ),
              ],
            ),
    );
  }
}

class _LinkedRecipesCard extends StatelessWidget {
  const _LinkedRecipesCard({required this.recipes});

  final List<ProductLinkedRecipeRecord> recipes;

  @override
  Widget build(BuildContext context) {
    return _DetailsCard(
      title: 'Receitas ligadas',
      content: recipes.isEmpty
          ? Text(
              'Nenhuma receita foi ligada a este produto ainda.',
              style: Theme.of(context).textTheme.bodyMedium,
            )
          : Column(
              children: [
                for (var index = 0; index < recipes.length; index++) ...[
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              recipes[index].recipeName,
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${recipes[index].recipeTypeLabel} • ${recipes[index].recipeYieldLabel}',
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  if (index != recipes.length - 1) const Divider(height: 24),
                ],
              ],
            ),
    );
  }
}

class _LinkedPackagingCard extends StatelessWidget {
  const _LinkedPackagingCard({
    required this.packagings,
    required this.defaultSuggestedPackaging,
  });

  final List<ProductLinkedPackagingRecord> packagings;
  final ProductLinkedPackagingRecord? defaultSuggestedPackaging;

  @override
  Widget build(BuildContext context) {
    return _DetailsCard(
      title: 'Embalagens compatíveis',
      content: packagings.isEmpty
          ? Text(
              'Nenhuma embalagem foi ligada a este produto ainda.',
              style: Theme.of(context).textTheme.bodyMedium,
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _LabelValueRow(
                  label: 'Sugestão padrão',
                  value: defaultSuggestedPackaging == null
                      ? 'Sem sugestão definida'
                      : defaultSuggestedPackaging!.packagingName,
                ),
                const SizedBox(height: 16),
                for (var index = 0; index < packagings.length; index++) ...[
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              packagings[index].packagingName,
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${packagings[index].packagingTypeLabel} • ${packagings[index].displayCapacityDescription}',
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${packagings[index].cost.format()} • ${packagings[index].displayStock}',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ],
                        ),
                      ),
                      if (packagings[index].isDefaultSuggested)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: Theme.of(
                              context,
                            ).colorScheme.secondaryContainer,
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            'Padrão',
                            style: Theme.of(context).textTheme.labelLarge,
                          ),
                        ),
                    ],
                  ),
                  if (index != packagings.length - 1) const Divider(height: 24),
                ],
              ],
            ),
    );
  }
}
