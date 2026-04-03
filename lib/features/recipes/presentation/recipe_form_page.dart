import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/navigation/app_destinations.dart';
import '../../../core/widgets/app_page_scaffold.dart';
import '../../../core/widgets/states/app_error_state.dart';
import '../../../core/widgets/states/app_loading_state.dart';
import '../../ingredients/application/ingredient_providers.dart';
import '../../ingredients/domain/ingredient.dart';
import '../../ingredients/presentation/ingredients_page.dart';
import '../application/recipe_providers.dart';
import '../domain/recipe.dart';
import '../domain/recipe_cost_calculator.dart';
import '../domain/recipe_type.dart';
import '../domain/recipe_yield_unit.dart';
import 'widgets/recipe_type_badge.dart';

class RecipeFormPage extends ConsumerWidget {
  const RecipeFormPage({super.key, this.recipeId});

  final String? recipeId;

  static final basePath = '${AppDestinations.businessSettings.path}/recipes';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (recipeId == null) {
      return const _RecipeFormView();
    }

    final recipeAsync = ref.watch(recipeProvider(recipeId!));

    return recipeAsync.when(
      loading: () => const AppPageScaffold(
        title: 'Abrindo receita',
        subtitle: 'Carregando os dados para edição.',
        child: AppLoadingState(message: 'Carregando receita...'),
      ),
      error: (error, stackTrace) => AppPageScaffold(
        title: 'Não deu para editar',
        subtitle: 'Algo falhou ao abrir esta receita.',
        child: AppErrorState(
          title: 'Receita indisponível',
          message: 'Volte para a lista e tente novamente.',
          actionLabel: 'Voltar para receitas',
          onAction: () => context.go(basePath),
        ),
      ),
      data: (recipe) {
        if (recipe == null) {
          return AppPageScaffold(
            title: 'Receita não encontrada',
            subtitle: 'Não existe uma receita local com esse identificador.',
            child: AppErrorState(
              title: 'Receita não encontrada',
              message: 'Volte para a lista e escolha um cadastro salvo.',
              actionLabel: 'Voltar para receitas',
              onAction: () => context.go(basePath),
            ),
          );
        }

        return _RecipeFormView(initialRecipe: recipe);
      },
    );
  }
}

class _RecipeFormView extends ConsumerStatefulWidget {
  const _RecipeFormView({this.initialRecipe});

  final RecipeRecord? initialRecipe;

  @override
  ConsumerState<_RecipeFormView> createState() => _RecipeFormViewState();
}

class _RecipeFormViewState extends ConsumerState<_RecipeFormView> {
  late final TextEditingController _nameController;
  late final TextEditingController _yieldAmountController;
  late final TextEditingController _baseLabelController;
  late final TextEditingController _flavorLabelController;
  late final TextEditingController _notesController;
  late RecipeType _type;
  late RecipeYieldUnit _yieldUnit;
  late final List<_EditableRecipeItem> _items;
  bool _isSaving = false;

  bool get _isEditing => widget.initialRecipe != null;

  int get _yieldAmount => int.tryParse(_yieldAmountController.text) ?? 0;

  @override
  void initState() {
    super.initState();

    final initialRecipe = widget.initialRecipe;
    _nameController = TextEditingController(text: initialRecipe?.name ?? '')
      ..addListener(_handleFormChanged);
    _yieldAmountController = TextEditingController(
      text: initialRecipe?.yieldAmount.toString() ?? '',
    )..addListener(_handleFormChanged);
    _baseLabelController = TextEditingController(
      text: initialRecipe?.baseLabel ?? '',
    )..addListener(_handleFormChanged);
    _flavorLabelController = TextEditingController(
      text: initialRecipe?.flavorLabel ?? '',
    )..addListener(_handleFormChanged);
    _notesController = TextEditingController(text: initialRecipe?.notes ?? '')
      ..addListener(_handleFormChanged);
    _type = initialRecipe?.type ?? RecipeType.complete;
    _yieldUnit = initialRecipe?.yieldUnit ?? RecipeYieldUnit.portion;
    _items = [
      for (final item in initialRecipe?.items ?? const <RecipeItemRecord>[])
        _EditableRecipeItem(
          ingredientId: item.ingredientId,
          ingredientNameSnapshot: item.ingredientNameSnapshot,
          quantity: item.quantity,
          notes: item.notes ?? '',
        ),
    ];
  }

  @override
  void dispose() {
    _nameController.dispose();
    _yieldAmountController.dispose();
    _baseLabelController.dispose();
    _flavorLabelController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ingredientsAsync = ref.watch(allIngredientsProvider);
    final ingredientMap = {
      for (final ingredient
          in ingredientsAsync.asData?.value ?? const <IngredientRecord>[])
        ingredient.id: ingredient,
    };
    final summary = RecipeCostCalculator.calculateSummary(
      items: _items
          .map(
            (item) => RecipeCostEntry(
              ingredientId: item.ingredientId,
              quantityInStockUnit: item.quantity,
            ),
          )
          .toList(growable: false),
      ingredientsById: ingredientMap,
      yieldAmount: _yieldAmount,
    );
    final title = _isEditing ? 'Editar receita' : 'Nova receita';
    final subtitle = _isEditing
        ? 'Ajuste o preparo em blocos curtos, com custo atualizado a partir dos ingredientes.'
        : 'Comece pela base da receita e monte os ingredientes logo abaixo.';

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
                        ? '${RecipeFormPage.basePath}/${widget.initialRecipe!.id}'
                        : RecipeFormPage.basePath,
                  ),
            icon: const Icon(Icons.arrow_back_rounded),
            label: Text(_isEditing ? 'Cancelar' : 'Voltar'),
          ),
          FilledButton.icon(
            onPressed: _isSaving ? null : _saveRecipe,
            icon: _isSaving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2.2),
                  )
                : const Icon(Icons.save_rounded),
            label: Text(_isSaving ? 'Salvando...' : 'Salvar receita'),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _RecipePreviewCard(
            name: _nameController.text.trim().isEmpty
                ? 'Receita sem nome definido'
                : _nameController.text.trim(),
            type: _type,
            yieldText: _yieldAmount <= 0
                ? 'Defina o rendimento'
                : _yieldUnit.formatAmount(_yieldAmount),
            totalCostText: summary.totalCost.format(),
            costPerYieldText: _yieldAmount <= 0
                ? 'Defina o rendimento'
                : '${summary.costPerYield.format()} por ${_yieldUnit.costReferenceLabel}',
          ),
          const SizedBox(height: 16),
          _SectionCard(
            title: 'Essencial',
            subtitle:
                'Defina primeiro o que essa receita é e quanto ela rende para o custo fazer sentido.',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: _nameController,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(
                    labelText: 'Nome da receita',
                    hintText: 'Ex.: Brigadeiro cremoso',
                  ),
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    for (final type in RecipeType.values)
                      _TypeChoiceCard(
                        type: type,
                        selected: _type == type,
                        onTap: () => setState(() => _type = type),
                      ),
                  ],
                ),
                const SizedBox(height: 16),
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
                            controller: _yieldAmountController,
                            keyboardType: TextInputType.number,
                            inputFormatters: <TextInputFormatter>[
                              FilteringTextInputFormatter.digitsOnly,
                            ],
                            decoration: const InputDecoration(
                              labelText: 'Quanto rende',
                              hintText: 'Ex.: 20',
                            ),
                          ),
                        ),
                        SizedBox(
                          width: fieldWidth,
                          child: Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              for (final yieldUnit in RecipeYieldUnit.values)
                                ChoiceChip(
                                  label: Text(yieldUnit.label),
                                  selected: _yieldUnit == yieldUnit,
                                  onSelected: (_) {
                                    setState(() => _yieldUnit = yieldUnit);
                                  },
                                ),
                            ],
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
            title: 'Estrutura opcional',
            subtitle:
                'Se esta receita tiver uma base ou sabor específicos, deixe isso claro agora para facilitar os próximos blocos.',
            child: Column(
              children: [
                TextField(
                  controller: _baseLabelController,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(
                    labelText: 'Base',
                    hintText: 'Ex.: Massa branca, base tradicional',
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _flavorLabelController,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(
                    labelText: 'Sabor',
                    hintText: 'Ex.: Chocolate, ninho, maracujá',
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _notesController,
                  minLines: 3,
                  maxLines: 5,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: const InputDecoration(
                    labelText: 'Observações',
                    hintText:
                        'Pontos importantes sobre textura, uso ou acabamento.',
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _SectionCard(
            title: 'Ingredientes',
            subtitle:
                'Adicione as linhas usando a unidade do estoque. O custo total se atualiza a partir daqui.',
            child: ingredientsAsync.when(
              loading: () => const AppLoadingState(
                message: 'Carregando ingredientes do estoque...',
              ),
              error: (error, stackTrace) => AppErrorState(
                title: 'Não deu para carregar os ingredientes',
                message:
                    'Sem os ingredientes não dá para calcular custo agora. Tente novamente.',
                actionLabel: 'Recarregar ingredientes',
                onAction: () => ref.invalidate(allIngredientsProvider),
              ),
              data: (ingredients) {
                if (ingredients.isEmpty) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Cadastre pelo menos um ingrediente antes de montar a receita.',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      const SizedBox(height: 16),
                      FilledButton.tonalIcon(
                        onPressed: () =>
                            context.push('${IngredientsPage.basePath}/new'),
                        icon: const Icon(Icons.inventory_2_outlined),
                        label: const Text('Criar ingrediente'),
                      ),
                    ],
                  );
                }

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton.icon(
                        onPressed: () =>
                            _openItemSheet(ingredients: ingredients),
                        icon: const Icon(Icons.add_rounded),
                        label: const Text('Adicionar ingrediente'),
                      ),
                    ),
                    if (_items.isEmpty)
                      Text(
                        'Nenhum ingrediente adicionado ainda.',
                        style: Theme.of(context).textTheme.bodyMedium,
                      )
                    else
                      Column(
                        children: [
                          for (
                            var index = 0;
                            index < _items.length;
                            index++
                          ) ...[
                            _RecipeItemEditorCard(
                              item: _items[index],
                              ingredient:
                                  ingredientMap[_items[index].ingredientId],
                              onEdit: () => _openItemSheet(
                                ingredients: ingredients,
                                index: index,
                              ),
                              onRemove: () => _removeItem(index),
                            ),
                            if (index != _items.length - 1)
                              const SizedBox(height: 12),
                          ],
                        ],
                      ),
                  ],
                );
              },
            ),
          ),
          const SizedBox(height: 16),
          _SectionCard(
            title: 'Resumo',
            subtitle:
                'Aqui você confirma se o preparo faz sentido comercialmente antes de seguir.',
            child: _RecipeSummaryPanel(
              itemCount: _items.length,
              totalCostText: summary.totalCost.format(),
              costPerYieldText: _yieldAmount <= 0
                  ? 'Defina o rendimento para ver o custo por base'
                  : '${summary.costPerYield.format()} por ${_yieldUnit.costReferenceLabel}',
              warningText: summary.missingIngredientsCount > 0
                  ? '${summary.missingIngredientsCount} ${summary.missingIngredientsCount == 1 ? 'linha depende' : 'linhas dependem'} de ingrediente que não foi encontrado.'
                  : null,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _openItemSheet({
    required List<IngredientRecord> ingredients,
    int? index,
  }) async {
    final currentItem = index == null ? null : _items[index];
    final result = await showModalBottomSheet<_EditableRecipeItem>(
      context: context,
      isScrollControlled: true,
      builder: (context) =>
          _RecipeItemSheet(ingredients: ingredients, initialItem: currentItem),
    );

    if (result == null) {
      return;
    }

    setState(() {
      if (index == null) {
        _items.add(result);
      } else {
        _items[index] = result;
      }
    });
  }

  void _removeItem(int index) {
    setState(() => _items.removeAt(index));
  }

  Future<void> _saveRecipe() async {
    if (_nameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Digite pelo menos o nome da receita.')),
      );
      return;
    }

    if (_yieldAmount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Defina um rendimento maior que zero.')),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      final recipeId = await ref
          .read(recipesRepositoryProvider)
          .saveRecipe(
            RecipeUpsertInput(
              id: widget.initialRecipe?.id,
              name: _nameController.text,
              type: _type,
              yieldAmount: _yieldAmount,
              yieldUnit: _yieldUnit,
              baseLabel: _baseLabelController.text,
              flavorLabel: _flavorLabelController.text,
              notes: _notesController.text,
              items: [
                for (final item in _items)
                  RecipeItemInput(
                    ingredientId: item.ingredientId,
                    quantity: item.quantity,
                    notes: item.notes,
                  ),
              ],
            ),
          );

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _isEditing
                ? 'Receita atualizada neste aparelho.'
                : 'Receita salva neste aparelho.',
          ),
        ),
      );
      context.go('${RecipeFormPage.basePath}/$recipeId');
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

  void _handleFormChanged() {
    setState(() {});
  }
}

class _EditableRecipeItem {
  const _EditableRecipeItem({
    required this.ingredientId,
    required this.ingredientNameSnapshot,
    required this.quantity,
    required this.notes,
  });

  final String ingredientId;
  final String ingredientNameSnapshot;
  final int quantity;
  final String notes;
}

class _RecipePreviewCard extends StatelessWidget {
  const _RecipePreviewCard({
    required this.name,
    required this.type,
    required this.yieldText,
    required this.totalCostText,
    required this.costPerYieldText,
  });

  final String name;
  final RecipeType type;
  final String yieldText;
  final String totalCostText;
  final String costPerYieldText;

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
          RecipeTypeBadge(type: type),
          const SizedBox(height: 16),
          Text(name, style: theme.textTheme.headlineSmall),
          const SizedBox(height: 16),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _PreviewMetric(label: 'Rendimento', value: yieldText),
              _PreviewMetric(label: 'Custo total', value: totalCostText),
              _PreviewMetric(label: 'Custo por base', value: costPerYieldText),
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
          Text(value, style: theme.textTheme.titleMedium),
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

  final RecipeType type;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return InkWell(
      borderRadius: BorderRadius.circular(24),
      onTap: onTap,
      child: Ink(
        width: 170,
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

class _RecipeItemEditorCard extends StatelessWidget {
  const _RecipeItemEditorCard({
    required this.item,
    required this.ingredient,
    required this.onEdit,
    required this.onRemove,
  });

  final _EditableRecipeItem item;
  final IngredientRecord? ingredient;
  final VoidCallback onEdit;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final lineCost = ingredient == null
        ? null
        : RecipeCostCalculator.calculateLineCost(
            ingredient: ingredient!,
            quantityInStockUnit: item.quantity,
          );

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  ingredient?.name ?? item.ingredientNameSnapshot,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              IconButton(
                onPressed: onEdit,
                icon: const Icon(Icons.edit_outlined),
                tooltip: 'Editar linha',
              ),
              IconButton(
                onPressed: onRemove,
                icon: const Icon(Icons.delete_outline_rounded),
                tooltip: 'Remover linha',
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            ingredient == null
                ? 'Ingrediente não encontrado agora.'
                : '${ingredient!.stockUnit.formatQuantity(item.quantity)} • ${lineCost!.format()}',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          if (item.notes.trim().isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              item.notes.trim(),
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ],
      ),
    );
  }
}

class _RecipeSummaryPanel extends StatelessWidget {
  const _RecipeSummaryPanel({
    required this.itemCount,
    required this.totalCostText,
    required this.costPerYieldText,
    required this.warningText,
  });

  final int itemCount;
  final String totalCostText;
  final String costPerYieldText;
  final String? warningText;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            _PreviewMetric(label: 'Itens', value: itemCount.toString()),
            _PreviewMetric(label: 'Custo total', value: totalCostText),
            _PreviewMetric(label: 'Custo por base', value: costPerYieldText),
          ],
        ),
        if (warningText != null) ...[
          const SizedBox(height: 16),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: theme.colorScheme.errorContainer,
              borderRadius: BorderRadius.circular(24),
            ),
            child: Text(
              warningText!,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onErrorContainer,
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _RecipeItemSheet extends StatefulWidget {
  const _RecipeItemSheet({required this.ingredients, this.initialItem});

  final List<IngredientRecord> ingredients;
  final _EditableRecipeItem? initialItem;

  @override
  State<_RecipeItemSheet> createState() => _RecipeItemSheetState();
}

class _RecipeItemSheetState extends State<_RecipeItemSheet> {
  late final TextEditingController _quantityController;
  late final TextEditingController _notesController;
  String? _ingredientId;

  int get _quantity => int.tryParse(_quantityController.text) ?? 0;

  IngredientRecord? get _selectedIngredient {
    final selectedIngredientId = _ingredientId;
    if (selectedIngredientId == null) {
      return null;
    }

    for (final ingredient in widget.ingredients) {
      if (ingredient.id == selectedIngredientId) {
        return ingredient;
      }
    }

    return null;
  }

  @override
  void initState() {
    super.initState();
    _ingredientId = widget.initialItem?.ingredientId;
    _quantityController = TextEditingController(
      text: widget.initialItem?.quantity.toString() ?? '',
    );
    _notesController = TextEditingController(
      text: widget.initialItem?.notes ?? '',
    );
  }

  @override
  void dispose() {
    _quantityController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final viewInsets = MediaQuery.of(context).viewInsets;
    final selectedIngredient = _selectedIngredient;
    final previewCost = selectedIngredient == null
        ? null
        : RecipeCostCalculator.calculateLineCost(
            ingredient: selectedIngredient,
            quantityInStockUnit: _quantity,
          );
    final hasSelectedIngredient = widget.ingredients.any(
      (ingredient) => ingredient.id == _ingredientId,
    );

    return Padding(
      padding: EdgeInsets.fromLTRB(20, 20, 20, 20 + viewInsets.bottom),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.initialItem == null
                  ? 'Adicionar ingrediente'
                  : 'Editar ingrediente',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 6),
            Text(
              'Use a mesma unidade que você controla no estoque.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 16),
            if (!hasSelectedIngredient && widget.initialItem != null) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.errorContainer,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  'O ingrediente anterior não foi encontrado. Escolha outro para continuar.',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onErrorContainer,
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],
            DropdownButtonFormField<String>(
              initialValue: hasSelectedIngredient ? _ingredientId : null,
              items: [
                for (final ingredient in widget.ingredients)
                  DropdownMenuItem<String>(
                    value: ingredient.id,
                    child: Text(ingredient.name),
                  ),
              ],
              onChanged: (value) => setState(() => _ingredientId = value),
              decoration: const InputDecoration(labelText: 'Ingrediente'),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _quantityController,
              keyboardType: TextInputType.number,
              inputFormatters: <TextInputFormatter>[
                FilteringTextInputFormatter.digitsOnly,
              ],
              decoration: InputDecoration(
                labelText: selectedIngredient == null
                    ? 'Quantidade'
                    : 'Quantidade em ${selectedIngredient.stockUnit.shortLabel}',
                hintText: '0',
                helperText: selectedIngredient == null
                    ? 'Escolha um ingrediente para ver a unidade.'
                    : 'Custo base: ${selectedIngredient.unitCost.format()} por ${selectedIngredient.purchaseUnit.shortLabel}',
              ),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _notesController,
              minLines: 2,
              maxLines: 4,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Observações',
                hintText: 'Opcional',
              ),
            ),
            const SizedBox(height: 16),
            if (selectedIngredient != null)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Text(
                  _quantity <= 0
                      ? 'Digite a quantidade para ver o custo desta linha.'
                      : '${selectedIngredient.stockUnit.formatQuantity(_quantity)} • ${previewCost!.format()}',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
            const SizedBox(height: 20),
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton.icon(
                onPressed: _save,
                icon: const Icon(Icons.check_rounded),
                label: const Text('Salvar linha'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _save() {
    final selectedIngredient = _selectedIngredient;
    if (selectedIngredient == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Escolha um ingrediente.')));
      return;
    }

    if (_quantity <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Digite uma quantidade maior que zero.')),
      );
      return;
    }

    Navigator.of(context).pop(
      _EditableRecipeItem(
        ingredientId: selectedIngredient.id,
        ingredientNameSnapshot: selectedIngredient.name,
        quantity: _quantity,
        notes: _notesController.text,
      ),
    );
  }
}
