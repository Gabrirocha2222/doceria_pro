import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/money/currency_text_input_formatter.dart';
import '../../../core/money/money.dart';
import '../../../core/widgets/app_page_scaffold.dart';
import '../../../core/widgets/states/app_error_state.dart';
import '../../../core/widgets/states/app_loading_state.dart';
import '../../suppliers/application/supplier_providers.dart';
import '../../suppliers/domain/supplier.dart';
import '../../suppliers/presentation/suppliers_page.dart';
import '../application/ingredient_providers.dart';
import '../domain/ingredient.dart';
import '../domain/ingredient_unit.dart';
import 'ingredients_page.dart';
import 'widgets/ingredient_stock_badge.dart';

class IngredientFormPage extends ConsumerWidget {
  const IngredientFormPage({super.key, this.ingredientId});

  final String? ingredientId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (ingredientId == null) {
      return const _IngredientFormView();
    }

    final ingredientAsync = ref.watch(ingredientProvider(ingredientId!));

    return ingredientAsync.when(
      loading: () => const AppPageScaffold(
        title: 'Abrindo ingrediente',
        subtitle: 'Carregando os dados para edição.',
        child: AppLoadingState(message: 'Carregando ingrediente...'),
      ),
      error: (error, stackTrace) => AppPageScaffold(
        title: 'Não deu para editar',
        subtitle: 'Algo falhou ao abrir este ingrediente.',
        child: AppErrorState(
          title: 'Ingrediente indisponível',
          message: 'Volte para a lista e tente novamente.',
          actionLabel: 'Voltar para estoque',
          onAction: () => context.go(IngredientsPage.basePath),
        ),
      ),
      data: (ingredient) {
        if (ingredient == null) {
          return AppPageScaffold(
            title: 'Ingrediente não encontrado',
            subtitle: 'Não existe um ingrediente local com esse identificador.',
            child: AppErrorState(
              title: 'Ingrediente não encontrado',
              message: 'Volte para a lista e escolha um cadastro salvo.',
              actionLabel: 'Voltar para estoque',
              onAction: () => context.go(IngredientsPage.basePath),
            ),
          );
        }

        return _IngredientFormView(initialIngredient: ingredient);
      },
    );
  }
}

class _IngredientFormView extends ConsumerStatefulWidget {
  const _IngredientFormView({this.initialIngredient});

  final IngredientRecord? initialIngredient;

  @override
  ConsumerState<_IngredientFormView> createState() =>
      _IngredientFormViewState();
}

class _IngredientFormViewState extends ConsumerState<_IngredientFormView> {
  static const _currencyFormatter = CurrencyTextInputFormatter();

  late final TextEditingController _nameController;
  late final TextEditingController _categoryController;
  late final TextEditingController _currentStockController;
  late final TextEditingController _minimumStockController;
  late final TextEditingController _unitCostController;
  late final TextEditingController _conversionFactorController;
  late final TextEditingController _notesController;
  late IngredientUnit _purchaseUnit;
  late IngredientUnit _stockUnit;
  late final String? _legacySupplierName;
  late Set<String> _selectedSupplierIds;
  String? _preferredSupplierId;
  bool _isSaving = false;

  bool get _isEditing => widget.initialIngredient != null;

  int get _currentStockQuantity =>
      int.tryParse(_currentStockController.text) ?? 0;

  int get _minimumStockQuantity =>
      int.tryParse(_minimumStockController.text) ?? 0;

  int get _conversionFactor =>
      int.tryParse(_conversionFactorController.text) ?? 0;

  Money get _unitCost => Money.fromInput(_unitCostController.text);

  bool get _isLowStockPreview =>
      _minimumStockQuantity > 0 &&
      _currentStockQuantity <= _minimumStockQuantity;

  bool get _isCustomConversion => _purchaseUnit == IngredientUnit.package;

  @override
  void initState() {
    super.initState();

    final initialIngredient = widget.initialIngredient;
    final initialLinkedSuppliers =
        initialIngredient?.linkedSuppliers ?? const [];
    _purchaseUnit = initialIngredient?.purchaseUnit ?? IngredientUnit.kilogram;
    _stockUnit =
        initialIngredient?.stockUnit ??
        _purchaseUnit.defaultStockUnit ??
        IngredientUnit.gram;
    _legacySupplierName = initialIngredient?.defaultSupplier;
    _selectedSupplierIds = initialLinkedSuppliers
        .map((supplier) => supplier.supplierId)
        .toSet();
    _preferredSupplierId = initialIngredient?.preferredSupplier?.supplierId;
    _nameController = TextEditingController(text: initialIngredient?.name ?? '')
      ..addListener(_handleFormChanged);
    _categoryController = TextEditingController(
      text: initialIngredient?.category ?? '',
    )..addListener(_handleFormChanged);
    _currentStockController = TextEditingController(
      text: initialIngredient == null
          ? ''
          : initialIngredient.currentStockQuantity.toString(),
    )..addListener(_handleFormChanged);
    _minimumStockController = TextEditingController(
      text: initialIngredient == null
          ? ''
          : initialIngredient.minimumStockQuantity.toString(),
    )..addListener(_handleFormChanged);
    _unitCostController = TextEditingController(
      text: initialIngredient == null || initialIngredient.unitCost.isZero
          ? ''
          : initialIngredient.unitCost.formatInput(),
    )..addListener(_handleFormChanged);
    _conversionFactorController = TextEditingController(
      text:
          initialIngredient?.conversionFactor.toString() ??
          (_purchaseUnit.defaultConversionFactor(_stockUnit) ?? 1).toString(),
    )..addListener(_handleFormChanged);
    _notesController = TextEditingController(
      text: initialIngredient?.notes ?? '',
    )..addListener(_handleFormChanged);

    if (!_isCustomConversion) {
      _applyAutomaticConversion();
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _categoryController.dispose();
    _currentStockController.dispose();
    _minimumStockController.dispose();
    _unitCostController.dispose();
    _conversionFactorController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final suppliersAsync = ref.watch(allSuppliersProvider);
    final title = _isEditing ? 'Editar ingrediente' : 'Novo ingrediente';
    final subtitle = _isEditing
        ? 'Ajuste o cadastro em blocos curtos, sem transformar o estoque em tela pesada.'
        : 'Cadastre o essencial primeiro e deixe o restante para quando fizer sentido.';

    return AppPageScaffold(
      title: title,
      subtitle: subtitle,
      trailing: Wrap(
        spacing: 12,
        runSpacing: 12,
        children: [
          OutlinedButton.icon(
            onPressed: _isSaving
                ? null
                : () => context.go(
                    _isEditing
                        ? '${IngredientsPage.basePath}/${widget.initialIngredient!.id}'
                        : IngredientsPage.basePath,
                  ),
            icon: const Icon(Icons.arrow_back_rounded),
            label: Text(_isEditing ? 'Cancelar' : 'Voltar'),
          ),
          FilledButton.icon(
            onPressed: _isSaving ? null : _saveIngredient,
            icon: _isSaving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2.2),
                  )
                : const Icon(Icons.save_rounded),
            label: Text(_isSaving ? 'Salvando...' : 'Salvar ingrediente'),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _IngredientPreviewCard(
            name: _nameController.text.trim().isEmpty
                ? 'Ingrediente sem nome definido'
                : _nameController.text.trim(),
            category: _categoryController.text.trim(),
            stockLabel: _stockUnit.formatQuantity(_currentStockQuantity),
            minimumLabel: _minimumStockQuantity > 0
                ? _stockUnit.formatQuantity(_minimumStockQuantity)
                : 'Sem mínimo definido',
            isLowStock: _isLowStockPreview,
          ),
          const SizedBox(height: 16),
          _SectionCard(
            title: 'Essencial',
            subtitle:
                'Salve o básico que ajuda a reconhecer o ingrediente rápido.',
            child: Column(
              children: [
                TextField(
                  controller: _nameController,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(
                    labelText: 'Nome do ingrediente',
                    hintText: 'Ex.: Chocolate em pó',
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _categoryController,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(
                    labelText: 'Categoria',
                    hintText: 'Ex.: Secos, laticínios, embalagens',
                  ),
                ),
                const SizedBox(height: 16),
                _SupplierSelectorCard(
                  suppliersAsync: suppliersAsync,
                  preferredSupplierId: _preferredSupplierId,
                  selectedSupplierIds: _selectedSupplierIds,
                  legacySupplierName: _legacySupplierName,
                  onPreferredChanged: _handlePreferredSupplierChanged,
                  onToggleSupplier: _toggleSupplierSelection,
                  onOpenSuppliers: () => context.push(SuppliersPage.basePath),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _SectionCard(
            title: 'Como você compra',
            subtitle:
                'Escolha a unidade em que este ingrediente costuma entrar no negócio.',
            child: Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                for (final unit in IngredientUnit.values)
                  _UnitChoiceCard(
                    label: unit.label,
                    selected: _purchaseUnit == unit,
                    onTap: () => _selectPurchaseUnit(unit),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _SectionCard(
            title: 'Como você controla no estoque',
            subtitle:
                'O estoque fica em uma unidade simples. A conversão faz a ponte entre compra e saldo.',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (_isCustomConversion)
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      for (final unit in availableStockUnitsForPurchase(
                        _purchaseUnit,
                      ))
                        _UnitChoiceCard(
                          label: unit.label,
                          selected: _stockUnit == unit,
                          onTap: () => _selectStockUnit(unit),
                        ),
                    ],
                  )
                else
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surfaceContainerLow,
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: Text(
                      'Controle em ${_stockUnit.label.toLowerCase()}',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                const SizedBox(height: 16),
                TextField(
                  controller: _conversionFactorController,
                  keyboardType: TextInputType.number,
                  inputFormatters: <TextInputFormatter>[
                    FilteringTextInputFormatter.digitsOnly,
                  ],
                  readOnly: !_isCustomConversion,
                  decoration: InputDecoration(
                    labelText: 'Fator de conversão',
                    hintText: 'Ex.: 1000',
                    helperText: _isCustomConversion
                        ? 'Ex.: se 1 pacote rende 500 g, use 500.'
                        : 'Esta conversão é padrão para a unidade escolhida.',
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Resumo: 1 ${_purchaseUnit.shortLabel} = ${_conversionFactorController.text.trim().isEmpty ? '0' : _conversionFactorController.text.trim()} ${_stockUnit.shortLabel}',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _SectionCard(
            title: 'Estoque e custo',
            subtitle:
                'Registre o saldo atual, o mínimo desejado e o custo da unidade de compra.',
            child: Column(
              children: [
                LayoutBuilder(
                  builder: (context, constraints) {
                    final compactLayout = constraints.maxWidth < 720;
                    final fieldWidth = compactLayout
                        ? constraints.maxWidth
                        : (constraints.maxWidth - 12) / 2;

                    return Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: [
                        SizedBox(
                          width: fieldWidth,
                          child: TextField(
                            controller: _currentStockController,
                            keyboardType: TextInputType.number,
                            inputFormatters: <TextInputFormatter>[
                              FilteringTextInputFormatter.digitsOnly,
                            ],
                            decoration: InputDecoration(
                              labelText:
                                  'Estoque atual em ${_stockUnit.shortLabel}',
                              hintText: '0',
                            ),
                          ),
                        ),
                        SizedBox(
                          width: fieldWidth,
                          child: TextField(
                            controller: _minimumStockController,
                            keyboardType: TextInputType.number,
                            inputFormatters: <TextInputFormatter>[
                              FilteringTextInputFormatter.digitsOnly,
                            ],
                            decoration: InputDecoration(
                              labelText:
                                  'Estoque mínimo em ${_stockUnit.shortLabel}',
                              hintText: '0',
                            ),
                          ),
                        ),
                        SizedBox(
                          width: fieldWidth,
                          child: TextField(
                            controller: _unitCostController,
                            keyboardType: TextInputType.number,
                            inputFormatters: const <TextInputFormatter>[
                              _currencyFormatter,
                            ],
                            decoration: InputDecoration(
                              labelText:
                                  'Custo por ${_purchaseUnit.shortLabel}',
                              prefixText: 'R\$ ',
                              hintText: '0,00',
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _SectionCard(
            title: 'Observações',
            subtitle:
                'Guarde só o que ajuda de verdade quando este ingrediente voltar para a rotina.',
            child: TextField(
              controller: _notesController,
              minLines: 3,
              maxLines: 5,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Observações',
                hintText:
                    'Ex.: marca preferida, cuidado ao armazenar, validade média',
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _saveIngredient() async {
    if (_nameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Digite pelo menos o nome do ingrediente.'),
        ),
      );
      return;
    }

    if (_conversionFactor <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Revise o fator de conversão antes de salvar.'),
        ),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      final ingredientId = await ref
          .read(ingredientsRepositoryProvider)
          .saveIngredient(
            IngredientUpsertInput(
              id: widget.initialIngredient?.id,
              name: _nameController.text,
              category: _categoryController.text,
              purchaseUnit: _purchaseUnit,
              stockUnit: _stockUnit,
              currentStockQuantity: _currentStockQuantity,
              minimumStockQuantity: _minimumStockQuantity,
              unitCost: _unitCost,
              defaultSupplier: _legacySupplierName,
              conversionFactor: _conversionFactor,
              notes: _notesController.text,
              preferredSupplierId: _preferredSupplierId,
              linkedSupplierIds: _selectedSupplierIds.toList(growable: false),
            ),
          );

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _isEditing
                ? 'Ingrediente atualizado neste aparelho.'
                : 'Ingrediente salvo neste aparelho.',
          ),
        ),
      );
      context.go('${IngredientsPage.basePath}/$ingredientId');
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

  void _selectPurchaseUnit(IngredientUnit unit) {
    setState(() {
      _purchaseUnit = unit;
      final defaultStockUnit = unit.defaultStockUnit;
      if (defaultStockUnit != null) {
        _stockUnit = defaultStockUnit;
        _applyAutomaticConversion();
      } else {
        if (!availableStockUnitsForPurchase(unit).contains(_stockUnit)) {
          _stockUnit = IngredientUnit.gram;
        }
        _conversionFactorController.text = '1';
      }
    });
  }

  void _selectStockUnit(IngredientUnit unit) {
    setState(() {
      _stockUnit = unit;
      if (!_isCustomConversion) {
        _applyAutomaticConversion();
      }
    });
  }

  void _handlePreferredSupplierChanged(String? supplierId) {
    setState(() {
      _preferredSupplierId = supplierId;
      if (supplierId != null) {
        _selectedSupplierIds.add(supplierId);
      }
    });
  }

  void _toggleSupplierSelection(String supplierId, bool selected) {
    setState(() {
      if (selected) {
        _selectedSupplierIds.add(supplierId);
      } else {
        _selectedSupplierIds.remove(supplierId);
        if (_preferredSupplierId == supplierId) {
          _preferredSupplierId = null;
        }
      }
    });
  }

  void _applyAutomaticConversion() {
    final conversionFactor =
        _purchaseUnit.defaultConversionFactor(_stockUnit) ?? 1;
    _conversionFactorController.text = conversionFactor.toString();
  }

  void _handleFormChanged() {
    setState(() {});
  }
}

class _SupplierSelectorCard extends StatelessWidget {
  const _SupplierSelectorCard({
    required this.suppliersAsync,
    required this.preferredSupplierId,
    required this.selectedSupplierIds,
    required this.legacySupplierName,
    required this.onPreferredChanged,
    required this.onToggleSupplier,
    required this.onOpenSuppliers,
  });

  final AsyncValue<List<SupplierRecord>> suppliersAsync;
  final String? preferredSupplierId;
  final Set<String> selectedSupplierIds;
  final String? legacySupplierName;
  final ValueChanged<String?> onPreferredChanged;
  final void Function(String supplierId, bool selected) onToggleSupplier;
  final VoidCallback onOpenSuppliers;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: suppliersAsync.when(
        loading: () => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Fornecedoras', style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            const LinearProgressIndicator(),
            const SizedBox(height: 8),
            Text(
              'Carregando opções salvas neste aparelho...',
              style: theme.textTheme.bodySmall,
            ),
          ],
        ),
        error: (error, stackTrace) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Fornecedoras', style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(
              'Não deu para carregar as fornecedoras agora. Você pode salvar o ingrediente e ligar depois.',
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 8),
            TextButton.icon(
              onPressed: onOpenSuppliers,
              icon: const Icon(Icons.open_in_new_rounded),
              label: const Text('Abrir fornecedoras'),
            ),
          ],
        ),
        data: (suppliers) {
          if (suppliers.isEmpty) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Fornecedoras', style: theme.textTheme.titleMedium),
                const SizedBox(height: 8),
                Text(
                  'Ainda não há fornecedoras salvas. Você pode continuar e ligar este ingrediente depois.',
                  style: theme.textTheme.bodyMedium,
                ),
                const SizedBox(height: 8),
                TextButton.icon(
                  onPressed: onOpenSuppliers,
                  icon: const Icon(Icons.add_business_rounded),
                  label: const Text('Cadastrar fornecedora'),
                ),
              ],
            );
          }

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Fornecedoras', style: theme.textTheme.titleMedium),
              const SizedBox(height: 4),
              Text(
                'Escolha a preferida e, se quiser, deixe outras opções ligadas como plano B.',
                style: theme.textTheme.bodySmall,
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                key: ValueKey(
                  'preferred-supplier-$preferredSupplierId-${suppliers.length}',
                ),
                initialValue:
                    suppliers.any(
                      (supplier) => supplier.id == preferredSupplierId,
                    )
                    ? preferredSupplierId
                    : '',
                items: [
                  const DropdownMenuItem<String>(
                    value: '',
                    child: Text('Sem fornecedora preferida'),
                  ),
                  for (final supplier in suppliers)
                    DropdownMenuItem<String>(
                      value: supplier.id,
                      child: Text(
                        supplier.isActive
                            ? supplier.name
                            : '${supplier.name} • Inativa',
                      ),
                    ),
                ],
                onChanged: (value) {
                  onPreferredChanged(
                    value == null || value.isEmpty ? null : value,
                  );
                },
                decoration: const InputDecoration(
                  labelText: 'Fornecedora preferida',
                ),
              ),
              if (legacySupplierName?.trim().isNotEmpty == true &&
                  preferredSupplierId == null &&
                  selectedSupplierIds.isEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  'Cadastro anterior: ${legacySupplierName!.trim()}. Escolha uma fornecedora salva para atualizar esse vínculo quando fizer sentido.',
                  style: theme.textTheme.bodySmall,
                ),
              ],
              const SizedBox(height: 16),
              Text(
                'Fornecedoras alternativas',
                style: theme.textTheme.titleSmall,
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final supplier in suppliers)
                    if (supplier.id != preferredSupplierId)
                      FilterChip(
                        label: Text(
                          supplier.isActive
                              ? supplier.name
                              : '${supplier.name} • Inativa',
                        ),
                        selected: selectedSupplierIds.contains(supplier.id),
                        onSelected: (selected) {
                          onToggleSupplier(supplier.id, selected);
                        },
                      ),
                ],
              ),
              const SizedBox(height: 12),
              TextButton.icon(
                onPressed: onOpenSuppliers,
                icon: const Icon(Icons.open_in_new_rounded),
                label: const Text('Abrir fornecedoras'),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _IngredientPreviewCard extends StatelessWidget {
  const _IngredientPreviewCard({
    required this.name,
    required this.category,
    required this.stockLabel,
    required this.minimumLabel,
    required this.isLowStock,
  });

  final String name;
  final String category;
  final String stockLabel;
  final String minimumLabel;
  final bool isLowStock;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(32),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          IngredientStockBadge(isLowStock: isLowStock),
          const SizedBox(height: 16),
          Text(name, style: theme.textTheme.headlineSmall),
          const SizedBox(height: 6),
          Text(
            category.trim().isEmpty
                ? 'Sem categoria definida'
                : category.trim(),
            style: theme.textTheme.bodyLarge,
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _PreviewMetric(label: 'Atual', value: stockLabel),
              _PreviewMetric(label: 'Mínimo', value: minimumLabel),
            ],
          ),
        ],
      ),
    );
  }
}

class _PreviewMetric extends StatelessWidget {
  const _PreviewMetric({required this.label, required this.value});

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

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.title,
    required this.subtitle,
    required this.child,
  });

  final String title;
  final String subtitle;
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
            const SizedBox(height: 6),
            Text(subtitle, style: Theme.of(context).textTheme.bodyMedium),
            const SizedBox(height: 16),
            child,
          ],
        ),
      ),
    );
  }
}

class _UnitChoiceCard extends StatelessWidget {
  const _UnitChoiceCard({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return InkWell(
      borderRadius: BorderRadius.circular(24),
      onTap: onTap,
      child: Ink(
        width: 180,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: selected
              ? theme.colorScheme.primaryContainer
              : theme.colorScheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: selected
                ? theme.colorScheme.primary
                : theme.colorScheme.outlineVariant,
          ),
        ),
        child: Text(label, style: theme.textTheme.titleMedium),
      ),
    );
  }
}
