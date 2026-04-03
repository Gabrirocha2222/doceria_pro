import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/navigation/app_destinations.dart';
import '../../../core/widgets/app_page_scaffold.dart';
import '../../../core/widgets/app_summary_metric_card.dart';
import '../../../core/widgets/states/app_empty_state.dart';
import '../../../core/widgets/states/app_error_state.dart';
import '../../../core/widgets/states/app_loading_state.dart';
import '../application/packaging_providers.dart';
import '../domain/packaging.dart';
import '../domain/packaging_list_filters.dart';
import 'widgets/packaging_stock_badge.dart';

class PackagingPage extends ConsumerWidget {
  const PackagingPage({super.key});

  static final basePath = '${AppDestinations.businessSettings.path}/packaging';
  static final lowStockPath = '$basePath/low-stock';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final allPackagingAsync = ref.watch(allPackagingProvider);
    final filteredPackagingAsync = ref.watch(filteredPackagingProvider);
    final lowStockPackagingAsync = ref.watch(lowStockPackagingProvider);
    final filters = ref.watch(packagingListFiltersProvider);

    return AppPageScaffold(
      title: 'Embalagens',
      subtitle:
          'Organize o que envolve apresentação e entrega sem transformar isso em controle pesado.',
      trailing: Wrap(
        spacing: 12,
        runSpacing: 12,
        children: [
          OutlinedButton.icon(
            onPressed: () => context.push(lowStockPath),
            icon: const Icon(Icons.warning_amber_rounded),
            label: const Text('Ver baixo estoque'),
          ),
          FilledButton.icon(
            onPressed: () => context.push('$basePath/new'),
            icon: const Icon(Icons.inventory_2_outlined),
            label: const Text('Nova embalagem'),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          lowStockPackagingAsync.when(
            loading: () => const AppLoadingState(message: 'Lendo alertas...'),
            error: (error, stackTrace) => const SizedBox.shrink(),
            data: (items) => _LowStockAlertCard(items: items),
          ),
          const SizedBox(height: 16),
          allPackagingAsync.when(
            loading: () =>
                const AppLoadingState(message: 'Carregando embalagens...'),
            error: (error, stackTrace) => AppErrorState(
              title: 'Não foi possível carregar as embalagens',
              message: 'Tente fechar e abrir a tela novamente.',
              actionLabel: 'Tentar de novo',
              onAction: () => ref.invalidate(allPackagingProvider),
            ),
            data: (items) => _PackagingSummaryCard(items: items),
          ),
          const SizedBox(height: 16),
          _PackagingFiltersCard(filters: filters),
          const SizedBox(height: 16),
          filteredPackagingAsync.when(
            loading: () =>
                const AppLoadingState(message: 'Atualizando a lista...'),
            error: (error, stackTrace) => AppErrorState(
              title: 'Não deu para montar a lista',
              message:
                  'As embalagens continuam salvas localmente, mas a visualização falhou agora.',
              actionLabel: 'Recarregar',
              onAction: () => ref.invalidate(allPackagingProvider),
            ),
            data: (items) {
              if (items.isEmpty) {
                return AppEmptyState(
                  icon: Icons.inventory_2_outlined,
                  title: filters.hasActiveFilters
                      ? 'Nenhuma embalagem bate com esse filtro'
                      : 'Nenhuma embalagem salva ainda',
                  message: filters.hasActiveFilters
                      ? 'Tente limpar os filtros para voltar a enxergar sua base de embalagens.'
                      : 'Comece pelas embalagens que mais saem com os pedidos.',
                  actionLabel: filters.hasActiveFilters
                      ? 'Limpar filtros'
                      : 'Criar embalagem',
                  onAction: () {
                    if (filters.hasActiveFilters) {
                      ref.read(packagingListFiltersProvider.notifier).clear();
                      return;
                    }

                    context.push('$basePath/new');
                  },
                );
              }

              return Column(
                children: [
                  for (var index = 0; index < items.length; index++) ...[
                    _PackagingListCard(
                      item: items[index],
                      onTap: () => context.push('$basePath/${items[index].id}'),
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
}

class PackagingLowStockPage extends ConsumerWidget {
  const PackagingLowStockPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lowStockPackagingAsync = ref.watch(lowStockPackagingProvider);

    return AppPageScaffold(
      title: 'Embalagens com estoque baixo',
      subtitle:
          'Veja o que já está pedindo reposição para não faltar na finalização dos pedidos.',
      trailing: OutlinedButton.icon(
        onPressed: () => context.go(PackagingPage.basePath),
        icon: const Icon(Icons.arrow_back_rounded),
        label: const Text('Voltar'),
      ),
      child: lowStockPackagingAsync.when(
        loading: () =>
            const AppLoadingState(message: 'Carregando embalagens críticas...'),
        error: (error, stackTrace) => AppErrorState(
          title: 'Não foi possível abrir os alertas',
          message: 'Tente voltar e abrir a tela novamente.',
          actionLabel: 'Voltar para embalagens',
          onAction: () => context.go(PackagingPage.basePath),
        ),
        data: (items) {
          if (items.isEmpty) {
            return AppEmptyState(
              icon: Icons.inventory_2_outlined,
              title: 'Nenhuma embalagem com alerta agora',
              message:
                  'Sua base de embalagens está sem alerta de mínimo neste momento.',
              actionLabel: 'Voltar para embalagens',
              onAction: () => context.go(PackagingPage.basePath),
            );
          }

          return Column(
            children: [
              for (var index = 0; index < items.length; index++) ...[
                _PackagingListCard(
                  item: items[index],
                  onTap: () => context.push(
                    '${PackagingPage.basePath}/${items[index].id}',
                  ),
                ),
                if (index != items.length - 1) const SizedBox(height: 12),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _LowStockAlertCard extends StatelessWidget {
  const _LowStockAlertCard({required this.items});

  final List<PackagingRecord> items;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (items.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: theme.colorScheme.secondaryContainer,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: theme.colorScheme.outlineVariant),
        ),
        child: Text(
          'As embalagens estão sem alerta de estoque baixo neste momento.',
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
            '${items.length} ${items.length == 1 ? 'embalagem está' : 'embalagens estão'} com estoque baixo',
            style: theme.textTheme.titleMedium,
          ),
          const SizedBox(height: 4),
          Text(
            items.take(3).map((item) => item.name).join(' • '),
            style: theme.textTheme.bodyMedium,
          ),
        ],
      ),
    );
  }
}

class _PackagingSummaryCard extends StatelessWidget {
  const _PackagingSummaryCard({required this.items});

  final List<PackagingRecord> items;

  @override
  Widget build(BuildContext context) {
    final activeItems = items.where((item) => item.isActive).length;
    final lowStockItems = items.where((item) => item.isLowStock).length;
    final linkedItems = items
        .where((item) => item.linkedProducts.isNotEmpty)
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
                    label: 'Embalagens salvas',
                    value: items.length.toString(),
                  ),
                ),
                SizedBox(
                  width: itemWidth,
                  child: AppSummaryMetricCard(
                    label: 'Ativas',
                    value: activeItems.toString(),
                  ),
                ),
                SizedBox(
                  width: itemWidth,
                  child: AppSummaryMetricCard(
                    label: 'Com alerta',
                    value: lowStockItems.toString(),
                  ),
                ),
                SizedBox(
                  width: itemWidth,
                  child: AppSummaryMetricCard(
                    label: 'Compatíveis com produtos',
                    value: linkedItems.toString(),
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

class _PackagingFiltersCard extends ConsumerStatefulWidget {
  const _PackagingFiltersCard({required this.filters});

  final PackagingListFilters filters;

  @override
  ConsumerState<_PackagingFiltersCard> createState() =>
      _PackagingFiltersCardState();
}

class _PackagingFiltersCardState extends ConsumerState<_PackagingFiltersCard> {
  late final TextEditingController _searchController;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController(text: widget.filters.searchQuery);
  }

  @override
  void didUpdateWidget(covariant _PackagingFiltersCard oldWidget) {
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
    final notifier = ref.read(packagingListFiltersProvider.notifier);

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
                hintText: 'Buscar por nome, tipo ou descrição',
                prefixIcon: Icon(Icons.search_rounded),
              ),
            ),
            const SizedBox(height: 16),
            SegmentedButton<PackagingActiveFilter>(
              showSelectedIcon: false,
              selected: {widget.filters.activeFilter},
              segments: [
                for (final filter in PackagingActiveFilter.values)
                  ButtonSegment<PackagingActiveFilter>(
                    value: filter,
                    label: Text(filter.label),
                  ),
              ],
              onSelectionChanged: (selection) {
                notifier.updateActiveFilter(selection.first);
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

class _PackagingListCard extends StatelessWidget {
  const _PackagingListCard({required this.item, required this.onTap});

  final PackagingRecord item;
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
              Wrap(
                spacing: 8,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  PackagingStockBadge(isLowStock: item.isLowStock),
                  _InlineBadge(label: item.type.label),
                  if (!item.isActive)
                    const _InlineBadge(
                      label: 'Inativa',
                      tone: _InlineBadgeTone.warning,
                    ),
                ],
              ),
              const SizedBox(height: 14),
              Text(item.name, style: theme.textTheme.titleLarge),
              const SizedBox(height: 6),
              Text(
                item.displayCapacityDescription,
                style: theme.textTheme.bodyMedium,
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  _MetricPill(label: 'Custo', value: item.displayCost),
                  _MetricPill(label: 'Estoque', value: item.displayStock),
                  _MetricPill(label: 'Mínimo', value: item.displayMinimumStock),
                  _MetricPill(label: 'Uso', value: item.usageLabel),
                ],
              ),
            ],
          ),
        ),
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
