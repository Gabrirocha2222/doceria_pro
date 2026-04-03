import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/formatters/app_formatters.dart';
import '../../../core/widgets/app_page_scaffold.dart';
import '../../../core/widgets/states/app_error_state.dart';
import '../../../core/widgets/states/app_loading_state.dart';
import '../application/packaging_providers.dart';
import '../domain/packaging.dart';
import 'packaging_page.dart';
import 'widgets/packaging_stock_badge.dart';

class PackagingDetailsPage extends ConsumerWidget {
  const PackagingDetailsPage({super.key, required this.packagingId});

  final String packagingId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final packagingAsync = ref.watch(packagingProvider(packagingId));

    return packagingAsync.when(
      loading: () => const AppPageScaffold(
        title: 'Carregando embalagem',
        subtitle: 'Separando custo, estoque e compatibilidades.',
        child: AppLoadingState(message: 'Carregando embalagem...'),
      ),
      error: (error, stackTrace) => AppPageScaffold(
        title: 'Embalagem indisponível',
        subtitle: 'Não foi possível abrir esta embalagem agora.',
        child: AppErrorState(
          title: 'Não deu para abrir a embalagem',
          message: 'Volte para a lista e tente novamente.',
          actionLabel: 'Voltar para embalagens',
          onAction: () => context.go(PackagingPage.basePath),
        ),
      ),
      data: (item) {
        if (item == null) {
          return AppPageScaffold(
            title: 'Embalagem não encontrada',
            subtitle: 'Talvez ela não exista mais neste aparelho.',
            child: AppErrorState(
              title: 'Embalagem não encontrada',
              message: 'Volte para a lista e confira as embalagens locais.',
              actionLabel: 'Voltar para embalagens',
              onAction: () => context.go(PackagingPage.basePath),
            ),
          );
        }

        return AppPageScaffold(
          title: 'Detalhes da embalagem',
          subtitle:
              'Resumo claro de custo, estoque e produtos que podem usar esta embalagem.',
          trailing: Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              OutlinedButton.icon(
                onPressed: () => context.go(PackagingPage.basePath),
                icon: const Icon(Icons.arrow_back_rounded),
                label: const Text('Voltar'),
              ),
              FilledButton.tonalIcon(
                onPressed: () =>
                    context.push('${PackagingPage.basePath}/${item.id}/edit'),
                icon: const Icon(Icons.edit_rounded),
                label: const Text('Editar'),
              ),
            ],
          ),
          child: _PackagingDetailsContent(item: item),
        );
      },
    );
  }
}

class _PackagingDetailsContent extends StatelessWidget {
  const _PackagingDetailsContent({required this.item});

  final PackagingRecord item;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _PackagingHeroCard(item: item),
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
                    title: 'Custo e estoque',
                    content: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _LabelValueRow(label: 'Tipo', value: item.type.label),
                        const SizedBox(height: 12),
                        _LabelValueRow(label: 'Custo', value: item.displayCost),
                        const SizedBox(height: 12),
                        _LabelValueRow(
                          label: 'Atual',
                          value: item.displayStock,
                        ),
                        const SizedBox(height: 12),
                        _LabelValueRow(
                          label: 'Mínimo',
                          value: item.displayMinimumStock,
                        ),
                      ],
                    ),
                  ),
                ),
                SizedBox(
                  width: cardWidth,
                  child: _DetailsCard(
                    title: 'Uso e atualização',
                    content: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _LabelValueRow(
                          label: 'Compatibilidade',
                          value: item.usageLabel,
                        ),
                        const SizedBox(height: 12),
                        _LabelValueRow(
                          label: 'Situação',
                          value: item.isActive ? 'Ativa' : 'Inativa',
                        ),
                        const SizedBox(height: 12),
                        _LabelValueRow(
                          label: 'Atualizada em',
                          value: AppFormatters.dayMonthYear(item.updatedAt),
                        ),
                      ],
                    ),
                  ),
                ),
                SizedBox(
                  width: constraints.maxWidth,
                  child: _DetailsCard(
                    title: 'Capacidade ou descrição',
                    content: Text(
                      item.displayCapacityDescription,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ),
                ),
                SizedBox(
                  width: cardWidth,
                  child: _DetailsCard(
                    title: 'Produtos compatíveis',
                    content: item.linkedProducts.isEmpty
                        ? Text(
                            'Nenhum produto usa esta embalagem ainda.',
                            style: Theme.of(context).textTheme.bodyMedium,
                          )
                        : Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              for (
                                var index = 0;
                                index < item.linkedProducts.length;
                                index++
                              ) ...[
                                _LinkedProductRow(
                                  item: item.linkedProducts[index],
                                ),
                                if (index != item.linkedProducts.length - 1)
                                  const Divider(height: 24),
                              ],
                            ],
                          ),
                  ),
                ),
                SizedBox(
                  width: cardWidth,
                  child: _DetailsCard(
                    title: 'Observações',
                    content: Text(
                      item.displayNotes,
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

class _PackagingHeroCard extends StatelessWidget {
  const _PackagingHeroCard({required this.item});

  final PackagingRecord item;

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
              PackagingStockBadge(isLowStock: item.isLowStock),
              _InlineBadge(label: item.type.label),
              if (!item.isActive)
                const _InlineBadge(
                  label: 'Inativa',
                  tone: _InlineBadgeTone.warning,
                ),
            ],
          ),
          const SizedBox(height: 16),
          Text(item.name, style: theme.textTheme.headlineSmall),
          const SizedBox(height: 6),
          Text(
            item.displayCapacityDescription,
            style: theme.textTheme.bodyLarge,
          ),
          const SizedBox(height: 20),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _HeroMetric(label: 'Custo', value: item.displayCost),
              _HeroMetric(label: 'Estoque', value: item.displayStock),
              _HeroMetric(label: 'Uso', value: item.usageLabel),
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

class _LinkedProductRow extends StatelessWidget {
  const _LinkedProductRow({required this.item});

  final PackagingLinkedProductRecord item;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Text(
            item.productName,
            style: Theme.of(context).textTheme.titleMedium,
          ),
        ),
        if (item.isDefaultSuggested)
          const _InlineBadge(label: 'Sugestão padrão'),
      ],
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
