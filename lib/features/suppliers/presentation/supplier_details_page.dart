import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/formatters/app_formatters.dart';
import '../../../core/money/currency_text_input_formatter.dart';
import '../../../core/money/money.dart';
import '../../../core/widgets/app_page_scaffold.dart';
import '../../../core/widgets/states/app_error_state.dart';
import '../../../core/widgets/states/app_loading_state.dart';
import '../../ingredients/application/ingredient_providers.dart';
import '../../ingredients/domain/ingredient.dart';
import '../../packaging/application/packaging_providers.dart';
import '../../packaging/domain/packaging.dart';
import '../application/supplier_providers.dart';
import '../domain/supplier.dart';
import '../domain/supplier_item_type.dart';
import 'suppliers_page.dart';

class SupplierDetailsPage extends ConsumerWidget {
  const SupplierDetailsPage({super.key, required this.supplierId});

  final String supplierId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final supplierAsync = ref.watch(supplierProvider(supplierId));

    return supplierAsync.when(
      loading: () => const AppPageScaffold(
        title: 'Carregando fornecedora',
        subtitle: 'Separando contato, prazo e últimos preços.',
        child: AppLoadingState(message: 'Carregando fornecedora...'),
      ),
      error: (error, stackTrace) => AppPageScaffold(
        title: 'Fornecedora indisponível',
        subtitle: 'Não foi possível abrir esta fornecedora agora.',
        child: AppErrorState(
          title: 'Não deu para abrir a fornecedora',
          message: 'Volte para a lista e tente novamente.',
          actionLabel: 'Voltar para fornecedoras',
          onAction: () => context.go(SuppliersPage.basePath),
        ),
      ),
      data: (supplier) {
        if (supplier == null) {
          return AppPageScaffold(
            title: 'Fornecedora não encontrada',
            subtitle: 'Talvez ela não exista mais neste aparelho.',
            child: AppErrorState(
              title: 'Fornecedora não encontrada',
              message:
                  'Volte para a lista e confira os cadastros salvos localmente.',
              actionLabel: 'Voltar para fornecedoras',
              onAction: () => context.go(SuppliersPage.basePath),
            ),
          );
        }

        return AppPageScaffold(
          title: 'Detalhes da fornecedora',
          subtitle:
              'Resumo prático para decidir onde comprar e lembrar do último preço.',
          trailing: Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              OutlinedButton.icon(
                onPressed: () => context.go(SuppliersPage.basePath),
                icon: const Icon(Icons.arrow_back_rounded),
                label: const Text('Voltar'),
              ),
              FilledButton.tonalIcon(
                onPressed: () => _openPriceSheet(context, supplier),
                icon: const Icon(Icons.attach_money_rounded),
                label: const Text('Registrar preço'),
              ),
              FilledButton.tonalIcon(
                onPressed: () => context.push(
                  '${SuppliersPage.basePath}/${supplier.id}/edit',
                ),
                icon: const Icon(Icons.edit_rounded),
                label: const Text('Editar'),
              ),
            ],
          ),
          child: _SupplierDetailsContent(supplier: supplier),
        );
      },
    );
  }

  Future<void> _openPriceSheet(BuildContext context, SupplierRecord supplier) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) => _SupplierPriceSheet(supplier: supplier),
    );
  }
}

class _SupplierDetailsContent extends StatelessWidget {
  const _SupplierDetailsContent({required this.supplier});

  final SupplierRecord supplier;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SupplierHeroCard(supplier: supplier),
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
                    title: 'Contato e prazo',
                    content: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _LabelValueRow(
                          label: 'Contato',
                          value: supplier.displayContact,
                        ),
                        const SizedBox(height: 12),
                        _LabelValueRow(
                          label: 'Prazo médio',
                          value: supplier.displayLeadTime,
                        ),
                        const SizedBox(height: 12),
                        _LabelValueRow(
                          label: 'Atualizada em',
                          value: AppFormatters.dayMonthYear(supplier.updatedAt),
                        ),
                      ],
                    ),
                  ),
                ),
                SizedBox(
                  width: cardWidth,
                  child: _DetailsCard(
                    title: 'Observações',
                    content: Text(
                      supplier.displayNotes,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ),
                ),
                SizedBox(
                  width: constraints.maxWidth,
                  child: _DetailsCard(
                    title: 'Ingredientes ligados',
                    content: supplier.linkedIngredients.isEmpty
                        ? Text(
                            'Nenhum ingrediente usa esta fornecedora ainda.',
                            style: Theme.of(context).textTheme.bodyMedium,
                          )
                        : Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              for (
                                var index = 0;
                                index < supplier.linkedIngredients.length;
                                index++
                              ) ...[
                                _LinkedIngredientRow(
                                  ingredient: supplier.linkedIngredients[index],
                                ),
                                if (index !=
                                    supplier.linkedIngredients.length - 1)
                                  const Divider(height: 24),
                              ],
                            ],
                          ),
                  ),
                ),
                SizedBox(
                  width: constraints.maxWidth,
                  child: _DetailsCard(
                    title: 'Últimos preços',
                    content: supplier.priceHistory.isEmpty
                        ? Text(
                            'Nenhum preço registrado ainda.',
                            style: Theme.of(context).textTheme.bodyMedium,
                          )
                        : Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              for (
                                var index = 0;
                                index < supplier.priceHistory.length;
                                index++
                              ) ...[
                                _PriceHistoryRow(
                                  price: supplier.priceHistory[index],
                                ),
                                if (index != supplier.priceHistory.length - 1)
                                  const Divider(height: 24),
                              ],
                            ],
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

class _SupplierHeroCard extends StatelessWidget {
  const _SupplierHeroCard({required this.supplier});

  final SupplierRecord supplier;

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
              _StatusBadge(isActive: supplier.isActive),
              if (supplier.latestPrice != null)
                _InlineBadge(
                  label:
                      'Último preço em ${supplier.latestPrice!.displayCreatedAt}',
                ),
            ],
          ),
          const SizedBox(height: 16),
          Text(supplier.name, style: theme.textTheme.headlineSmall),
          const SizedBox(height: 6),
          Text(supplier.displayContact, style: theme.textTheme.bodyLarge),
          const SizedBox(height: 20),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _HeroMetric(
                label: 'Prazo médio',
                value: supplier.displayLeadTime,
              ),
              _HeroMetric(
                label: 'Ingredientes ligados',
                value: supplier.linkedIngredients.length.toString(),
              ),
              _HeroMetric(
                label: 'Último preço',
                value: supplier.latestPrice?.displayPrice ?? 'Sem registro',
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

class _InlineBadge extends StatelessWidget {
  const _InlineBadge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Text(label, style: theme.textTheme.labelLarge),
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
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: theme.textTheme.labelLarge),
        const SizedBox(height: 4),
        Text(value, style: theme.textTheme.bodyLarge),
      ],
    );
  }
}

class _LinkedIngredientRow extends StatelessWidget {
  const _LinkedIngredientRow({required this.ingredient});

  final SupplierLinkedIngredientRecord ingredient;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text(ingredient.ingredientName, style: theme.textTheme.titleMedium),
            if (ingredient.isDefaultPreferred) _InlineBadge(label: 'Preferida'),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          '${ingredient.displayCategory} • ${ingredient.displayLastKnownPrice}',
          style: theme.textTheme.bodyMedium,
        ),
      ],
    );
  }
}

class _PriceHistoryRow extends StatelessWidget {
  const _PriceHistoryRow({required this.price});

  final SupplierPriceRecord price;

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
            Text(price.itemNameSnapshot, style: theme.textTheme.titleMedium),
            _InlineBadge(label: price.itemType.label),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          '${price.displayPrice} • ${price.displayCreatedAt}',
          style: theme.textTheme.bodyMedium,
        ),
        const SizedBox(height: 4),
        Text(price.displayNotes, style: theme.textTheme.bodySmall),
      ],
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

class _SupplierPriceSheet extends ConsumerStatefulWidget {
  const _SupplierPriceSheet({required this.supplier});

  final SupplierRecord supplier;

  @override
  ConsumerState<_SupplierPriceSheet> createState() =>
      _SupplierPriceSheetState();
}

class _SupplierPriceSheetState extends ConsumerState<_SupplierPriceSheet> {
  static const _currencyFormatter = CurrencyTextInputFormatter();

  late final TextEditingController _priceController;
  late final TextEditingController _notesController;
  SupplierItemType _itemType = SupplierItemType.ingredient;
  String? _selectedItemId;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _priceController = TextEditingController();
    _notesController = TextEditingController();
  }

  @override
  void dispose() {
    _priceController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ingredientsAsync = ref.watch(allIngredientsProvider);
    final packagingAsync = ref.watch(allPackagingProvider);
    final items = _resolveItems(
      ingredients: ingredientsAsync.asData?.value ?? const [],
      packaging: packagingAsync.asData?.value ?? const [],
    );
    final selectedItem = _resolveSelectedItem(items);

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
              Text(
                'Registrar preço',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 8),
              Text(
                'Guarde um preço recente para lembrar onde comprar melhor.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 16),
              SegmentedButton<SupplierItemType>(
                segments: [
                  for (final itemType in SupplierItemType.values)
                    ButtonSegment<SupplierItemType>(
                      value: itemType,
                      label: Text(itemType.label),
                    ),
                ],
                selected: {_itemType},
                onSelectionChanged: (selection) {
                  setState(() {
                    _itemType = selection.first;
                    _selectedItemId = null;
                  });
                },
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                key: ValueKey(
                  'supplier-price-item-${_itemType.databaseValue}-$_selectedItemId-${items.length}',
                ),
                initialValue: items.any((item) => item.id == _selectedItemId)
                    ? _selectedItemId
                    : null,
                items: [
                  for (final item in items)
                    DropdownMenuItem<String>(
                      value: item.id,
                      child: Text(item.label),
                    ),
                ],
                decoration: InputDecoration(
                  labelText: _itemType == SupplierItemType.ingredient
                      ? 'Ingrediente'
                      : 'Embalagem',
                ),
                onChanged: items.isEmpty
                    ? null
                    : (value) {
                        setState(() => _selectedItemId = value);
                      },
              ),
              if (items.isEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  _itemType == SupplierItemType.ingredient
                      ? 'Cadastre um ingrediente antes de registrar preço.'
                      : 'Cadastre uma embalagem antes de registrar preço.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
              const SizedBox(height: 16),
              TextField(
                controller: _priceController,
                keyboardType: TextInputType.number,
                inputFormatters: const <TextInputFormatter>[_currencyFormatter],
                decoration: InputDecoration(
                  labelText: selectedItem == null
                      ? 'Preço'
                      : 'Preço por ${selectedItem.unitLabel}',
                  prefixText: 'R\$ ',
                  hintText: '0,00',
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _notesController,
                minLines: 2,
                maxLines: 4,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  labelText: 'Observações',
                  hintText:
                      'Ex.: preço promocional, pedido mínimo, frete incluso',
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  TextButton(
                    onPressed: _isSaving
                        ? null
                        : () => Navigator.of(context).pop(),
                    child: const Text('Cancelar'),
                  ),
                  const Spacer(),
                  FilledButton.icon(
                    onPressed: _isSaving || selectedItem == null
                        ? null
                        : _savePrice,
                    icon: _isSaving
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2.2),
                          )
                        : const Icon(Icons.save_rounded),
                    label: Text(_isSaving ? 'Salvando...' : 'Salvar preço'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _savePrice() async {
    final ingredients =
        ref.read(allIngredientsProvider).asData?.value ?? const [];
    final packaging = ref.read(allPackagingProvider).asData?.value ?? const [];
    final items = _resolveItems(ingredients: ingredients, packaging: packaging);
    final selectedItem = _resolveSelectedItem(items);

    if (selectedItem == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Escolha um item para registrar o preço.'),
        ),
      );
      return;
    }

    final price = Money.fromInput(_priceController.text);
    if (price.cents <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Digite um preço maior que zero.')),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      await ref
          .read(suppliersRepositoryProvider)
          .saveSupplierPrice(
            SupplierPriceUpsertInput(
              supplierId: widget.supplier.id,
              itemType: _itemType,
              linkedItemId: selectedItem.id,
              itemNameSnapshot: selectedItem.label,
              unitLabelSnapshot: selectedItem.unitLabel,
              price: price,
              notes: _notesController.text,
            ),
          );

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Preço salvo neste aparelho.')),
      );
      Navigator.of(context).pop();
    } catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Não foi possível salvar: $error')),
      );
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  List<_SupplierItemChoice> _resolveItems({
    required List<IngredientRecord> ingredients,
    required List<PackagingRecord> packaging,
  }) {
    return switch (_itemType) {
      SupplierItemType.ingredient =>
        ingredients
            .map(
              (ingredient) => _SupplierItemChoice(
                id: ingredient.id,
                label: ingredient.name,
                unitLabel: ingredient.purchaseUnit.shortLabel,
              ),
            )
            .toList(growable: false),
      SupplierItemType.packaging =>
        packaging
            .map(
              (item) => _SupplierItemChoice(
                id: item.id,
                label: item.name,
                unitLabel: 'un',
              ),
            )
            .toList(growable: false),
    };
  }

  _SupplierItemChoice? _resolveSelectedItem(List<_SupplierItemChoice> items) {
    for (final item in items) {
      if (item.id == _selectedItemId) {
        return item;
      }
    }

    return null;
  }
}

class _SupplierItemChoice {
  const _SupplierItemChoice({
    required this.id,
    required this.label,
    required this.unitLabel,
  });

  final String id;
  final String label;
  final String unitLabel;
}
