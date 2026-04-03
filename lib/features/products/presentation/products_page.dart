import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/navigation/app_destinations.dart';
import '../../../core/widgets/app_page_scaffold.dart';
import '../../../core/widgets/app_summary_metric_card.dart';
import '../../../core/widgets/states/app_empty_state.dart';
import '../../../core/widgets/states/app_error_state.dart';
import '../../../core/widgets/states/app_loading_state.dart';
import '../application/product_providers.dart';
import '../domain/product.dart';
import '../domain/product_list_filters.dart';
import '../domain/product_type.dart';
import 'widgets/product_sale_mode_badge.dart';
import 'widgets/product_state_badge.dart';
import 'widgets/product_type_badge.dart';

class ProductsPage extends ConsumerWidget {
  const ProductsPage({super.key});

  static final basePath = '${AppDestinations.businessSettings.path}/products';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final allProductsAsync = ref.watch(allProductsProvider);
    final filteredProductsAsync = ref.watch(filteredProductsProvider);
    final filters = ref.watch(productListFiltersProvider);

    return AppPageScaffold(
      title: 'Produtos',
      subtitle:
          'Organize o catálogo base de venda sem engessar a rotina. O retrato comercial fica pronto para pedidos futuros.',
      trailing: FilledButton.icon(
        onPressed: () => context.push('$basePath/new'),
        icon: const Icon(Icons.inventory_2_outlined),
        label: const Text('Novo produto'),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          allProductsAsync.when(
            loading: () =>
                const AppLoadingState(message: 'Carregando produtos...'),
            error: (error, stackTrace) => AppErrorState(
              title: 'Não foi possível carregar os produtos',
              message: 'Tente fechar e abrir a tela novamente.',
              actionLabel: 'Tentar de novo',
              onAction: () => ref.invalidate(allProductsProvider),
            ),
            data: (products) => _ProductsSummaryCard(products: products),
          ),
          const SizedBox(height: 16),
          _ProductFiltersCard(filters: filters),
          const SizedBox(height: 16),
          filteredProductsAsync.when(
            loading: () =>
                const AppLoadingState(message: 'Atualizando a lista...'),
            error: (error, stackTrace) => AppErrorState(
              title: 'Não deu para montar a lista',
              message:
                  'Os produtos continuam salvos localmente, mas a visualização falhou agora.',
              actionLabel: 'Recarregar',
              onAction: () => ref.invalidate(allProductsProvider),
            ),
            data: (products) {
              if (products.isEmpty) {
                return AppEmptyState(
                  icon: Icons.inventory_2_outlined,
                  title: filters.hasActiveFilters
                      ? 'Nenhum produto bate com esse filtro'
                      : 'Nenhum produto salvo ainda',
                  message: filters.hasActiveFilters
                      ? 'Tente limpar os filtros para voltar a enxergar seu catálogo.'
                      : 'Comece pelo que você vende com mais frequência. O restante pode entrar depois.',
                  actionLabel: filters.hasActiveFilters
                      ? 'Limpar filtros'
                      : 'Criar produto',
                  onAction: () {
                    if (filters.hasActiveFilters) {
                      ref.read(productListFiltersProvider.notifier).clear();
                      return;
                    }

                    context.push('$basePath/new');
                  },
                );
              }

              return Column(
                children: [
                  for (var index = 0; index < products.length; index++) ...[
                    _ProductListCard(
                      product: products[index],
                      onTap: () =>
                          context.push('$basePath/${products[index].id}'),
                    ),
                    if (index != products.length - 1)
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

class _ProductsSummaryCard extends StatelessWidget {
  const _ProductsSummaryCard({required this.products});

  final List<ProductRecord> products;

  @override
  Widget build(BuildContext context) {
    final activeProducts = products.where((product) => product.isActive).length;
    final withFlavors = products
        .where((product) => product.flavors.isNotEmpty)
        .length;
    final withVariations = products
        .where((product) => product.variations.isNotEmpty)
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
                    label: 'Produtos salvos',
                    value: products.length.toString(),
                  ),
                ),
                SizedBox(
                  width: itemWidth,
                  child: AppSummaryMetricCard(
                    label: 'Ativos',
                    value: activeProducts.toString(),
                  ),
                ),
                SizedBox(
                  width: itemWidth,
                  child: AppSummaryMetricCard(
                    label: 'Com sabores',
                    value: withFlavors.toString(),
                  ),
                ),
                SizedBox(
                  width: itemWidth,
                  child: AppSummaryMetricCard(
                    label: 'Com variações',
                    value: withVariations.toString(),
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

class _ProductFiltersCard extends ConsumerStatefulWidget {
  const _ProductFiltersCard({required this.filters});

  final ProductListFilters filters;

  @override
  ConsumerState<_ProductFiltersCard> createState() =>
      _ProductFiltersCardState();
}

class _ProductFiltersCardState extends ConsumerState<_ProductFiltersCard> {
  late final TextEditingController _searchController;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController(text: widget.filters.searchQuery);
  }

  @override
  void didUpdateWidget(covariant _ProductFiltersCard oldWidget) {
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
    final notifier = ref.read(productListFiltersProvider.notifier);

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
                hintText: 'Buscar por nome, categoria ou opção',
                prefixIcon: Icon(Icons.search_rounded),
              ),
            ),
            const SizedBox(height: 16),
            SegmentedButton<ProductActiveFilter>(
              showSelectedIcon: false,
              selected: {widget.filters.activeFilter},
              segments: [
                for (final filter in ProductActiveFilter.values)
                  ButtonSegment<ProductActiveFilter>(
                    value: filter,
                    label: Text(filter.label),
                  ),
              ],
              onSelectionChanged: (selection) {
                notifier.updateActiveFilter(selection.first);
              },
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ChoiceChip(
                  label: const Text('Todos os tipos'),
                  selected: widget.filters.type == null,
                  onSelected: (_) => notifier.updateType(null),
                ),
                for (final productType in ProductType.values)
                  ChoiceChip(
                    label: Text(productType.label),
                    selected: widget.filters.type == productType,
                    onSelected: (_) => notifier.updateType(productType),
                  ),
              ],
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

class _ProductListCard extends StatelessWidget {
  const _ProductListCard({required this.product, required this.onTap});

  final ProductRecord product;
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
                        Text(product.name, style: theme.textTheme.titleLarge),
                        const SizedBox(height: 6),
                        Text(
                          '${product.displayCategory} • ${product.priceLabel}',
                          style: theme.textTheme.bodyMedium,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  ProductStateBadge(isActive: product.isActive),
                ],
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  ProductTypeBadge(type: product.type),
                  ProductSaleModeBadge(saleMode: product.saleMode),
                  if (product.flavors.isNotEmpty)
                    _InfoBadge(text: '${product.flavors.length} sabor(es)'),
                  if (product.variations.isNotEmpty)
                    _InfoBadge(
                      text: '${product.variations.length} variação(ões)',
                    ),
                ],
              ),
              if (product.notes?.trim().isNotEmpty ?? false) ...[
                const SizedBox(height: 16),
                Text(
                  product.notes!,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
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

class _InfoBadge extends StatelessWidget {
  const _InfoBadge({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(text, style: theme.textTheme.labelLarge),
    );
  }
}
