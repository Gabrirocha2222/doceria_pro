import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/navigation/app_destinations.dart';
import '../../../core/money/currency_text_input_formatter.dart';
import '../../../core/money/money.dart';
import '../../../core/widgets/app_page_scaffold.dart';
import '../../../core/widgets/states/app_error_state.dart';
import '../../../core/widgets/states/app_loading_state.dart';
import '../../packaging/application/packaging_providers.dart';
import '../../recipes/application/recipe_providers.dart';
import '../../packaging/presentation/packaging_form_page.dart';
import '../application/product_providers.dart';
import '../domain/product.dart';
import '../domain/product_option_type.dart';
import '../domain/product_sale_mode.dart';
import '../domain/product_type.dart';
import '../../recipes/presentation/recipe_form_page.dart';
import 'widgets/product_sale_mode_badge.dart';
import 'widgets/product_state_badge.dart';
import 'widgets/product_type_badge.dart';

class ProductFormPage extends ConsumerWidget {
  const ProductFormPage({super.key, this.productId});

  final String? productId;

  static final basePath = '${AppDestinations.businessSettings.path}/products';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (productId == null) {
      return const _ProductFormView();
    }

    final productAsync = ref.watch(productProvider(productId!));

    return productAsync.when(
      loading: () => const AppPageScaffold(
        title: 'Abrindo produto',
        subtitle: 'Carregando os dados para edição.',
        child: AppLoadingState(message: 'Carregando produto...'),
      ),
      error: (error, stackTrace) => AppPageScaffold(
        title: 'Não deu para editar',
        subtitle: 'Algo falhou ao abrir este produto.',
        child: AppErrorState(
          title: 'Produto indisponível',
          message: 'Volte para a lista e tente novamente.',
          actionLabel: 'Voltar para produtos',
          onAction: () => context.go(basePath),
        ),
      ),
      data: (product) {
        if (product == null) {
          return AppPageScaffold(
            title: 'Produto não encontrado',
            subtitle: 'Não existe um produto local com esse identificador.',
            child: AppErrorState(
              title: 'Produto não encontrado',
              message: 'Volte para a lista e escolha um cadastro salvo.',
              actionLabel: 'Voltar para produtos',
              onAction: () => context.go(basePath),
            ),
          );
        }

        return _ProductFormView(initialProduct: product);
      },
    );
  }
}

class _ProductFormView extends ConsumerStatefulWidget {
  const _ProductFormView({this.initialProduct});

  final ProductRecord? initialProduct;

  @override
  ConsumerState<_ProductFormView> createState() => _ProductFormViewState();
}

class _ProductFormViewState extends ConsumerState<_ProductFormView> {
  static const _currencyFormatter = CurrencyTextInputFormatter();

  late final TextEditingController _nameController;
  late final TextEditingController _categoryController;
  late final TextEditingController _basePriceController;
  late final TextEditingController _yieldHintController;
  late final TextEditingController _notesController;
  late ProductType _type;
  late ProductSaleMode _saleMode;
  late bool _isActive;
  late final List<_EditableOption> _flavorOptions;
  late final List<_EditableOption> _variationOptions;
  late final Set<String> _selectedRecipeIds;
  late final Set<String> _selectedPackagingIds;
  String? _defaultSuggestedPackagingId;
  bool _isSaving = false;

  bool get _isEditing => widget.initialProduct != null;

  Money get _basePrice => Money.fromInput(_basePriceController.text);

  @override
  void initState() {
    super.initState();

    final initialProduct = widget.initialProduct;
    _nameController = TextEditingController(text: initialProduct?.name ?? '')
      ..addListener(_handleFormChanged);
    _categoryController = TextEditingController(
      text: initialProduct?.category ?? '',
    )..addListener(_handleFormChanged);
    _basePriceController = TextEditingController(
      text: initialProduct == null || initialProduct.basePrice.isZero
          ? ''
          : initialProduct.basePrice.formatInput(),
    )..addListener(_handleFormChanged);
    _yieldHintController = TextEditingController(
      text: initialProduct?.yieldHint ?? '',
    )..addListener(_handleFormChanged);
    _notesController = TextEditingController(text: initialProduct?.notes ?? '')
      ..addListener(_handleFormChanged);
    _type = initialProduct?.type ?? ProductType.simple;
    _saleMode = initialProduct?.saleMode ?? ProductSaleMode.fixedPrice;
    _isActive = initialProduct?.isActive ?? true;
    _flavorOptions = [
      for (final option in initialProduct?.flavors ?? const [])
        _EditableOption(option.name)
          ..controller.addListener(_handleFormChanged),
    ];
    _variationOptions = [
      for (final option in initialProduct?.variations ?? const [])
        _EditableOption(option.name)
          ..controller.addListener(_handleFormChanged),
    ];
    _selectedRecipeIds = {
      for (final linkedRecipe in initialProduct?.linkedRecipes ?? const [])
        linkedRecipe.recipeId,
    };
    _selectedPackagingIds = {
      for (final linkedPackaging
          in initialProduct?.linkedPackagings ?? const [])
        linkedPackaging.packagingId,
    };
    _defaultSuggestedPackagingId =
        initialProduct?.defaultSuggestedPackaging?.packagingId;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _categoryController.dispose();
    _basePriceController.dispose();
    _yieldHintController.dispose();
    _notesController.dispose();
    for (final option in [..._flavorOptions, ..._variationOptions]) {
      option.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final recipesAsync = ref.watch(allRecipesProvider);
    final packagingAsync = ref.watch(activePackagingProvider);
    final title = _isEditing ? 'Editar produto' : 'Novo produto';
    final subtitle = _isEditing
        ? 'Ajuste a base de venda em blocos curtos, sem transformar isso em cadastro pesado.'
        : 'Escolha o tipo primeiro e salve só o que já ajuda na operação.';

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
                        ? '${ProductFormPage.basePath}/${widget.initialProduct!.id}'
                        : ProductFormPage.basePath,
                  ),
            icon: const Icon(Icons.arrow_back_rounded),
            label: Text(_isEditing ? 'Cancelar' : 'Voltar'),
          ),
          FilledButton.icon(
            onPressed: _isSaving ? null : _saveProduct,
            icon: _isSaving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2.2),
                  )
                : const Icon(Icons.save_rounded),
            label: Text(_isSaving ? 'Salvando...' : 'Salvar produto'),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _ProductPreviewCard(
            name: _nameController.text.trim().isEmpty
                ? 'Produto sem nome definido'
                : _nameController.text.trim(),
            category: _categoryController.text.trim(),
            type: _type,
            saleMode: _saleMode,
            basePrice: _basePrice,
            isActive: _isActive,
          ),
          const SizedBox(height: 16),
          _SectionCard(
            title: 'Tipo do produto',
            subtitle:
                'Escolha primeiro como esse produto entra na rotina. O restante da tela se adapta a partir daqui.',
            child: Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                for (final type in ProductType.values)
                  _TypeChoiceCard(
                    type: type,
                    selected: _type == type,
                    onTap: () => setState(() => _type = type),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _SectionCard(
            title: 'Base comercial',
            subtitle:
                'Defina o básico de venda sem perder flexibilidade para ajustar depois.',
            child: Column(
              children: [
                TextField(
                  controller: _nameController,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(
                    labelText: 'Nome do produto',
                    hintText: 'Ex.: Bolo no pote',
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _categoryController,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(
                    labelText: 'Categoria',
                    hintText: 'Ex.: Bolos, doces finos, kits',
                  ),
                ),
                const SizedBox(height: 16),
                SegmentedButton<ProductSaleMode>(
                  selected: {_saleMode},
                  showSelectedIcon: false,
                  segments: [
                    for (final saleMode in ProductSaleMode.values)
                      ButtonSegment<ProductSaleMode>(
                        value: saleMode,
                        label: Text(saleMode.label),
                      ),
                  ],
                  onSelectionChanged: (selection) {
                    setState(() => _saleMode = selection.first);
                  },
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _basePriceController,
                  keyboardType: TextInputType.number,
                  inputFormatters: const <TextInputFormatter>[
                    _currencyFormatter,
                  ],
                  decoration: InputDecoration(
                    labelText: _saleMode == ProductSaleMode.quoteOnly
                        ? 'Preço base opcional'
                        : 'Preço base',
                    prefixText: 'R\$ ',
                    hintText: '0,00',
                    helperText: _saleMode == ProductSaleMode.quoteOnly
                        ? 'Se quiser, guarde um valor de referência mesmo em produtos sob orçamento.'
                        : null,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _TypeSpecificSection(type: _type, controller: _yieldHintController),
          const SizedBox(height: 16),
          _SectionCard(
            title: 'Sabores e variações',
            subtitle:
                'Guarde só a estrutura leve que vai ajudar pedidos e receitas mais adiante.',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _OptionsEditorSection(
                  title: 'Sabores',
                  emptyMessage: 'Nenhum sabor cadastrado ainda.',
                  options: _flavorOptions,
                  onAdd: () => _addOption(_flavorOptions),
                  onRemove: (option) => _removeOption(_flavorOptions, option),
                ),
                const SizedBox(height: 16),
                _OptionsEditorSection(
                  title: 'Variações',
                  emptyMessage: 'Nenhuma variação cadastrada ainda.',
                  options: _variationOptions,
                  onAdd: () => _addOption(_variationOptions),
                  onRemove: (option) =>
                      _removeOption(_variationOptions, option),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _SectionCard(
            title: 'Receitas ligadas',
            subtitle:
                'Se este produto já usa uma ou mais receitas, deixe isso marcado para a base crescer conectada.',
            child: recipesAsync.when(
              loading: () =>
                  const AppLoadingState(message: 'Carregando receitas...'),
              error: (error, stackTrace) => Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Não foi possível carregar as receitas agora.',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 12),
                  TextButton.icon(
                    onPressed: () => ref.invalidate(allRecipesProvider),
                    icon: const Icon(Icons.refresh_rounded),
                    label: const Text('Tentar de novo'),
                  ),
                ],
              ),
              data: (recipes) {
                if (recipes.isEmpty) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Nenhuma receita foi cadastrada ainda.',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      const SizedBox(height: 12),
                      FilledButton.tonalIcon(
                        onPressed: () =>
                            context.push('${RecipeFormPage.basePath}/new'),
                        icon: const Icon(Icons.menu_book_rounded),
                        label: const Text('Criar receita'),
                      ),
                    ],
                  );
                }

                return Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final recipe in recipes)
                      FilterChip(
                        label: Text(recipe.name),
                        selected: _selectedRecipeIds.contains(recipe.id),
                        onSelected: (_) => _toggleRecipeSelection(recipe.id),
                      ),
                  ],
                );
              },
            ),
          ),
          const SizedBox(height: 16),
          _SectionCard(
            title: 'Embalagens compatíveis',
            subtitle:
                'Marque só o que realmente faz sentido para este produto e, se quiser, deixe uma sugestão padrão.',
            child: packagingAsync.when(
              loading: () =>
                  const AppLoadingState(message: 'Carregando embalagens...'),
              error: (error, stackTrace) => Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Não foi possível carregar as embalagens agora.',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 12),
                  TextButton.icon(
                    onPressed: () => ref.invalidate(activePackagingProvider),
                    icon: const Icon(Icons.refresh_rounded),
                    label: const Text('Tentar de novo'),
                  ),
                ],
              ),
              data: (packagingItems) {
                if (packagingItems.isEmpty) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Nenhuma embalagem ativa foi cadastrada ainda.',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      const SizedBox(height: 12),
                      FilledButton.tonalIcon(
                        onPressed: () =>
                            context.push('${PackagingFormPage.basePath}/new'),
                        icon: const Icon(Icons.inventory_2_rounded),
                        label: const Text('Criar embalagem'),
                      ),
                    ],
                  );
                }

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final packaging in packagingItems)
                          FilterChip(
                            label: Text(packaging.name),
                            selected: _selectedPackagingIds.contains(
                              packaging.id,
                            ),
                            onSelected: (_) =>
                                _togglePackagingSelection(packaging.id),
                          ),
                      ],
                    ),
                    if (_selectedPackagingIds.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      Text(
                        'Sugestão padrão',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          ChoiceChip(
                            label: const Text('Sem sugestão'),
                            selected: _defaultSuggestedPackagingId == null,
                            onSelected: (_) {
                              setState(
                                () => _defaultSuggestedPackagingId = null,
                              );
                            },
                          ),
                          for (final packaging in packagingItems)
                            if (_selectedPackagingIds.contains(packaging.id))
                              ChoiceChip(
                                label: Text(packaging.name),
                                selected:
                                    _defaultSuggestedPackagingId ==
                                    packaging.id,
                                onSelected: (_) {
                                  setState(
                                    () => _defaultSuggestedPackagingId =
                                        packaging.id,
                                  );
                                },
                              ),
                        ],
                      ),
                    ],
                  ],
                );
              },
            ),
          ),
          const SizedBox(height: 16),
          _SectionCard(
            title: 'Observações e status',
            subtitle:
                'Registre só o que realmente ajuda depois e mantenha o catálogo leve.',
            child: Column(
              children: [
                TextField(
                  controller: _notesController,
                  minLines: 3,
                  maxLines: 5,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: const InputDecoration(
                    labelText: 'Observações',
                    hintText:
                        'Pontos importantes sobre venda, atendimento ou produção.',
                  ),
                ),
                const SizedBox(height: 16),
                SwitchListTile.adaptive(
                  contentPadding: EdgeInsets.zero,
                  value: _isActive,
                  title: const Text('Produto ativo'),
                  subtitle: Text(
                    _isActive
                        ? 'Ele continua disponível para novos pedidos.'
                        : 'Ele some das escolhas rápidas, mas continua salvo no histórico.',
                  ),
                  onChanged: (value) => setState(() => _isActive = value),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _saveProduct() async {
    if (_nameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Digite pelo menos o nome do produto.')),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      final productId = await ref
          .read(productsRepositoryProvider)
          .saveProduct(
            ProductUpsertInput(
              id: widget.initialProduct?.id,
              name: _nameController.text,
              category: _categoryController.text,
              type: _type,
              saleMode: _saleMode,
              basePrice: _basePrice,
              notes: _notesController.text,
              yieldHint: _yieldHintController.text,
              isActive: _isActive,
              options: [
                for (final option in _flavorOptions)
                  ProductOptionInput(
                    type: ProductOptionType.flavor,
                    name: option.controller.text,
                  ),
                for (final option in _variationOptions)
                  ProductOptionInput(
                    type: ProductOptionType.variation,
                    name: option.controller.text,
                  ),
              ],
              linkedRecipeIds: _selectedRecipeIds.toList(growable: false),
              linkedPackagingIds: _selectedPackagingIds.toList(growable: false),
              defaultSuggestedPackagingId: _defaultSuggestedPackagingId,
            ),
          );

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _isEditing
                ? 'Produto atualizado neste aparelho.'
                : 'Produto salvo neste aparelho.',
          ),
        ),
      );
      context.go('${ProductFormPage.basePath}/$productId');
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

  void _addOption(List<_EditableOption> target) {
    final option = _EditableOption()
      ..controller.addListener(_handleFormChanged);
    setState(() => target.add(option));
  }

  void _removeOption(List<_EditableOption> target, _EditableOption option) {
    setState(() => target.remove(option));
    option.dispose();
  }

  void _handleFormChanged() {
    setState(() {});
  }

  void _toggleRecipeSelection(String recipeId) {
    setState(() {
      if (_selectedRecipeIds.contains(recipeId)) {
        _selectedRecipeIds.remove(recipeId);
      } else {
        _selectedRecipeIds.add(recipeId);
      }
    });
  }

  void _togglePackagingSelection(String packagingId) {
    setState(() {
      if (_selectedPackagingIds.contains(packagingId)) {
        _selectedPackagingIds.remove(packagingId);
        if (_defaultSuggestedPackagingId == packagingId) {
          _defaultSuggestedPackagingId = null;
        }
      } else {
        _selectedPackagingIds.add(packagingId);
      }
    });
  }
}

class _EditableOption {
  _EditableOption([String initialValue = ''])
    : controller = TextEditingController(text: initialValue);

  final TextEditingController controller;

  void dispose() {
    controller.dispose();
  }
}

class _ProductPreviewCard extends StatelessWidget {
  const _ProductPreviewCard({
    required this.name,
    required this.category,
    required this.type,
    required this.saleMode,
    required this.basePrice,
    required this.isActive,
  });

  final String name;
  final String category;
  final ProductType type;
  final ProductSaleMode saleMode;
  final Money basePrice;
  final bool isActive;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final priceLabel = switch (saleMode) {
      ProductSaleMode.fixedPrice => basePrice.format(),
      ProductSaleMode.startingAt => 'A partir de ${basePrice.format()}',
      ProductSaleMode.quoteOnly =>
        basePrice.isZero
            ? 'Sob orçamento'
            : 'Sob orçamento • base ${basePrice.format()}',
    };

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
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              ProductTypeBadge(type: type),
              ProductSaleModeBadge(saleMode: saleMode),
              ProductStateBadge(isActive: isActive),
            ],
          ),
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
          Text(priceLabel, style: theme.textTheme.titleLarge),
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

class _TypeChoiceCard extends StatelessWidget {
  const _TypeChoiceCard({
    required this.type,
    required this.selected,
    required this.onTap,
  });

  final ProductType type;
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
        child: Text(type.label, style: theme.textTheme.titleMedium),
      ),
    );
  }
}

class _TypeSpecificSection extends StatelessWidget {
  const _TypeSpecificSection({required this.type, required this.controller});

  final ProductType type;
  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    final sectionData = switch (type) {
      ProductType.simple => (
        title: 'Como ele entra na rotina',
        subtitle:
            'Neste tipo você pode manter a base enxuta. Se quiser, guarde só observações mais adiante.',
        showYieldField: false,
        yieldLabel: '',
        yieldHint: '',
        infoMessage:
            'Produto direto, sem necessidade de referência extra agora.',
      ),
      ProductType.perUnit => (
        title: 'Referência por unidade',
        subtitle:
            'Guarde a unidade que orienta a venda e evita dúvida quando o pedido voltar depois.',
        showYieldField: true,
        yieldLabel: 'Referência de unidade',
        yieldHint: 'Ex.: 1 pote de 250 ml, 1 cento, 1 bandeja',
        infoMessage: '',
      ),
      ProductType.perWeight => (
        title: 'Referência por peso',
        subtitle:
            'Registre a base que ajuda a lembrar como esse produto costuma ser vendido.',
        showYieldField: true,
        yieldLabel: 'Referência de peso',
        yieldHint: 'Ex.: preço base por kg, fatia de 120 g, mini de 30 g',
        infoMessage: '',
      ),
      ProductType.kit => (
        title: 'Estrutura do kit',
        subtitle:
            'Anote o que ajuda a reconhecer rápido o formato do kit antes da receita detalhada existir.',
        showYieldField: true,
        yieldLabel: 'O que entra no kit',
        yieldHint: 'Ex.: 6 brownies + 2 brigadeiros, box com 12 unidades',
        infoMessage: '',
      ),
      ProductType.monthlyPlan => (
        title: 'Base do plano mensal',
        subtitle:
            'A lógica de recorrência ainda não entra aqui. Por agora, cadastre só a base comercial.',
        showYieldField: true,
        yieldLabel: 'Resumo do plano',
        yieldHint: 'Ex.: 4 entregas por mês, combo fixo semanal',
        infoMessage:
            'O fluxo completo de plano mensal entra em um bloco futuro. Este cadastro já deixa o tipo pronto para catálogo e pedidos.',
      ),
      ProductType.outsourced => (
        title: 'Referência terceirizada',
        subtitle:
            'Guarde a informação mínima que ajuda a lembrar de quem vem ou como costuma ser vendido.',
        showYieldField: true,
        yieldLabel: 'Parceira ou referência',
        yieldHint: 'Ex.: fornecedor, embalagem padrão, prazo base',
        infoMessage: '',
      ),
    };

    return _SectionCard(
      title: sectionData.title,
      subtitle: sectionData.subtitle,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (sectionData.infoMessage.isNotEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.secondaryContainer,
                borderRadius: BorderRadius.circular(24),
              ),
              child: Text(sectionData.infoMessage),
            ),
          if (sectionData.showYieldField) ...[
            if (sectionData.infoMessage.isNotEmpty) const SizedBox(height: 16),
            TextField(
              controller: controller,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                labelText: sectionData.yieldLabel,
                hintText: sectionData.yieldHint,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _OptionsEditorSection extends StatelessWidget {
  const _OptionsEditorSection({
    required this.title,
    required this.emptyMessage,
    required this.options,
    required this.onAdd,
    required this.onRemove,
  });

  final String title;
  final String emptyMessage;
  final List<_EditableOption> options;
  final VoidCallback onAdd;
  final void Function(_EditableOption option) onRemove;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                title,
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            TextButton.icon(
              onPressed: onAdd,
              icon: const Icon(Icons.add_rounded),
              label: const Text('Adicionar'),
            ),
          ],
        ),
        if (options.isEmpty)
          Text(emptyMessage, style: Theme.of(context).textTheme.bodyMedium)
        else
          Column(
            children: [
              for (var index = 0; index < options.length; index++) ...[
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: options[index].controller,
                        textCapitalization: TextCapitalization.words,
                        decoration: InputDecoration(
                          labelText: '$title ${index + 1}',
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    IconButton.filledTonal(
                      onPressed: () => onRemove(options[index]),
                      icon: const Icon(Icons.delete_outline_rounded),
                    ),
                  ],
                ),
                if (index != options.length - 1) const SizedBox(height: 12),
              ],
            ],
          ),
      ],
    );
  }
}
