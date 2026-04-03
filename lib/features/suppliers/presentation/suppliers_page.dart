import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/navigation/app_destinations.dart';
import '../../../core/widgets/app_page_scaffold.dart';
import '../../../core/widgets/app_summary_metric_card.dart';
import '../../../core/widgets/states/app_empty_state.dart';
import '../../../core/widgets/states/app_error_state.dart';
import '../../../core/widgets/states/app_loading_state.dart';
import '../application/supplier_providers.dart';
import '../domain/supplier.dart';
import '../domain/supplier_list_filters.dart';

class SuppliersPage extends ConsumerWidget {
  const SuppliersPage({super.key});

  static final basePath = '${AppDestinations.businessSettings.path}/suppliers';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final allSuppliersAsync = ref.watch(allSuppliersProvider);
    final filteredSuppliersAsync = ref.watch(filteredSuppliersProvider);
    final filters = ref.watch(supplierListFiltersProvider);

    return AppPageScaffold(
      title: 'Fornecedoras',
      subtitle:
          'Centralize quem vende para você, com prazo e último preço sem virar uma tela pesada.',
      trailing: FilledButton.icon(
        onPressed: () => context.push('$basePath/new'),
        icon: const Icon(Icons.store_mall_directory_rounded),
        label: const Text('Nova fornecedora'),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          allSuppliersAsync.when(
            loading: () =>
                const AppLoadingState(message: 'Carregando fornecedoras...'),
            error: (error, stackTrace) => AppErrorState(
              title: 'Não foi possível carregar as fornecedoras',
              message: 'Tente fechar e abrir a tela novamente.',
              actionLabel: 'Tentar de novo',
              onAction: () => ref.invalidate(allSuppliersProvider),
            ),
            data: (suppliers) => _SuppliersSummaryCard(suppliers: suppliers),
          ),
          const SizedBox(height: 16),
          _SupplierFiltersCard(filters: filters),
          const SizedBox(height: 16),
          filteredSuppliersAsync.when(
            loading: () =>
                const AppLoadingState(message: 'Atualizando a lista...'),
            error: (error, stackTrace) => AppErrorState(
              title: 'Não deu para montar a lista',
              message:
                  'As fornecedoras continuam salvas localmente, mas a visualização falhou agora.',
              actionLabel: 'Recarregar',
              onAction: () => ref.invalidate(allSuppliersProvider),
            ),
            data: (suppliers) {
              if (suppliers.isEmpty) {
                return AppEmptyState(
                  icon: Icons.local_shipping_outlined,
                  title: filters.hasActiveFilters
                      ? 'Nenhuma fornecedora bate com essa busca'
                      : 'Nenhuma fornecedora salva ainda',
                  message: filters.hasActiveFilters
                      ? 'Tente outro termo ou limpe o filtro para voltar a encontrar suas opções.'
                      : 'Comece com quem você mais compra. O restante pode entrar aos poucos.',
                  actionLabel: filters.hasActiveFilters
                      ? 'Limpar filtros'
                      : 'Criar fornecedora',
                  onAction: () {
                    if (filters.hasActiveFilters) {
                      ref.read(supplierListFiltersProvider.notifier).clear();
                      return;
                    }

                    context.push('$basePath/new');
                  },
                );
              }

              return Column(
                children: [
                  for (var index = 0; index < suppliers.length; index++) ...[
                    _SupplierListCard(
                      supplier: suppliers[index],
                      onTap: () =>
                          context.push('$basePath/${suppliers[index].id}'),
                    ),
                    if (index != suppliers.length - 1)
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

class _SuppliersSummaryCard extends StatelessWidget {
  const _SuppliersSummaryCard({required this.suppliers});

  final List<SupplierRecord> suppliers;

  @override
  Widget build(BuildContext context) {
    final activeSuppliers = suppliers
        .where((supplier) => supplier.isActive)
        .length;
    final withPrice = suppliers
        .where((supplier) => supplier.latestPrice != null)
        .length;
    final linkedToIngredients = suppliers
        .where((supplier) => supplier.linkedIngredients.isNotEmpty)
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
                    label: 'Fornecedoras salvas',
                    value: suppliers.length.toString(),
                  ),
                ),
                SizedBox(
                  width: itemWidth,
                  child: AppSummaryMetricCard(
                    label: 'Ativas',
                    value: activeSuppliers.toString(),
                  ),
                ),
                SizedBox(
                  width: itemWidth,
                  child: AppSummaryMetricCard(
                    label: 'Com preço registrado',
                    value: withPrice.toString(),
                  ),
                ),
                SizedBox(
                  width: itemWidth,
                  child: AppSummaryMetricCard(
                    label: 'Ligadas a ingredientes',
                    value: linkedToIngredients.toString(),
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

class _SupplierFiltersCard extends ConsumerStatefulWidget {
  const _SupplierFiltersCard({required this.filters});

  final SupplierListFilters filters;

  @override
  ConsumerState<_SupplierFiltersCard> createState() =>
      _SupplierFiltersCardState();
}

class _SupplierFiltersCardState extends ConsumerState<_SupplierFiltersCard> {
  late final TextEditingController _searchController;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController(text: widget.filters.searchQuery);
  }

  @override
  void didUpdateWidget(covariant _SupplierFiltersCard oldWidget) {
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
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _searchController,
              onChanged: (value) {
                ref
                    .read(supplierListFiltersProvider.notifier)
                    .updateSearchQuery(value);
              },
              decoration: const InputDecoration(
                hintText: 'Buscar por nome, contato, ingrediente ou observação',
                prefixIcon: Icon(Icons.search_rounded),
              ),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final filter in SupplierActiveFilter.values)
                  ChoiceChip(
                    label: Text(filter.label),
                    selected: widget.filters.activeFilter == filter,
                    onSelected: (_) {
                      ref
                          .read(supplierListFiltersProvider.notifier)
                          .updateActiveFilter(filter);
                    },
                  ),
              ],
            ),
            if (widget.filters.hasActiveFilters) ...[
              const SizedBox(height: 12),
              TextButton.icon(
                onPressed: () {
                  ref.read(supplierListFiltersProvider.notifier).clear();
                },
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

class _SupplierListCard extends StatelessWidget {
  const _SupplierListCard({required this.supplier, required this.onTap});

  final SupplierRecord supplier;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
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
                        Text(supplier.name, style: theme.textTheme.titleLarge),
                        const SizedBox(height: 6),
                        Text(
                          supplier.displayContact,
                          style: theme.textTheme.bodyMedium,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  _StatusBadge(isActive: supplier.isActive),
                ],
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  _MetricPill(label: 'Prazo', value: supplier.displayLeadTime),
                  _MetricPill(
                    label: 'Ingredientes',
                    value: supplier.linkedIngredientsSummary,
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                'Último preço: ${supplier.latestPriceSummary}',
                style: theme.textTheme.bodyMedium,
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

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.isActive});

  final bool isActive;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: isActive
            ? theme.colorScheme.secondaryContainer
            : theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Text(
        isActive ? 'Ativa' : 'Inativa',
        style: theme.textTheme.labelLarge,
      ),
    );
  }
}
