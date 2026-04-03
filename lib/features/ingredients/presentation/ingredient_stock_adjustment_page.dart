import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/widgets/app_page_scaffold.dart';
import '../../../core/widgets/states/app_error_state.dart';
import '../../../core/widgets/states/app_loading_state.dart';
import '../application/ingredient_providers.dart';
import '../domain/ingredient.dart';
import '../domain/ingredient_stock_movement.dart';
import 'ingredients_page.dart';
import 'widgets/ingredient_stock_badge.dart';

class IngredientStockAdjustmentPage extends ConsumerWidget {
  const IngredientStockAdjustmentPage({super.key, required this.ingredientId});

  final String ingredientId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ingredientAsync = ref.watch(ingredientProvider(ingredientId));

    return ingredientAsync.when(
      loading: () => const AppPageScaffold(
        title: 'Abrindo ajuste',
        subtitle: 'Carregando o estoque atual para ajuste manual.',
        child: AppLoadingState(message: 'Carregando ingrediente...'),
      ),
      error: (error, stackTrace) => AppPageScaffold(
        title: 'Ajuste indisponível',
        subtitle: 'Não foi possível abrir este ajuste agora.',
        child: AppErrorState(
          title: 'Não deu para abrir o ajuste',
          message: 'Volte para o detalhe do ingrediente e tente novamente.',
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

        return _IngredientStockAdjustmentView(ingredient: ingredient);
      },
    );
  }
}

enum _AdjustmentDirection {
  increase('Entrada'),
  decrease('Saída');

  const _AdjustmentDirection(this.label);

  final String label;
}

class _IngredientStockAdjustmentView extends ConsumerStatefulWidget {
  const _IngredientStockAdjustmentView({required this.ingredient});

  final IngredientRecord ingredient;

  @override
  ConsumerState<_IngredientStockAdjustmentView> createState() =>
      _IngredientStockAdjustmentViewState();
}

class _IngredientStockAdjustmentViewState
    extends ConsumerState<_IngredientStockAdjustmentView> {
  late final TextEditingController _quantityController;
  late final TextEditingController _reasonController;
  late final TextEditingController _notesController;
  _AdjustmentDirection _direction = _AdjustmentDirection.increase;
  bool _isSaving = false;

  int get _quantity => int.tryParse(_quantityController.text) ?? 0;

  int get _signedDelta =>
      _direction == _AdjustmentDirection.increase ? _quantity : -_quantity;

  int get _projectedStock =>
      widget.ingredient.currentStockQuantity + _signedDelta;

  @override
  void initState() {
    super.initState();
    _quantityController = TextEditingController();
    _reasonController = TextEditingController();
    _notesController = TextEditingController();
  }

  @override
  void dispose() {
    _quantityController.dispose();
    _reasonController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ingredient = widget.ingredient;

    return AppPageScaffold(
      title: 'Ajustar estoque',
      subtitle:
          'Registre uma entrada ou saída manual e mantenha o histórico do ingrediente organizado.',
      trailing: OutlinedButton.icon(
        onPressed: _isSaving
            ? null
            : () => context.go('${IngredientsPage.basePath}/${ingredient.id}'),
        icon: const Icon(Icons.arrow_back_rounded),
        label: const Text('Voltar'),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _AdjustmentPreviewCard(
            ingredient: ingredient,
            projectedStock: _projectedStock,
          ),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Movimentação',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Escolha se este ajuste entra ou sai do estoque.',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 16),
                  SegmentedButton<_AdjustmentDirection>(
                    selected: {_direction},
                    showSelectedIcon: false,
                    segments: [
                      for (final direction in _AdjustmentDirection.values)
                        ButtonSegment<_AdjustmentDirection>(
                          value: direction,
                          label: Text(direction.label),
                        ),
                    ],
                    onSelectionChanged: (selection) {
                      setState(() => _direction = selection.first);
                    },
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _quantityController,
                    keyboardType: TextInputType.number,
                    inputFormatters: <TextInputFormatter>[
                      FilteringTextInputFormatter.digitsOnly,
                    ],
                    decoration: InputDecoration(
                      labelText:
                          'Quantidade em ${ingredient.stockUnit.shortLabel}',
                      hintText: '0',
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final suggestion in _reasonSuggestions)
                        ChoiceChip(
                          label: Text(suggestion),
                          selected: _reasonController.text.trim() == suggestion,
                          onSelected: (_) {
                            setState(() => _reasonController.text = suggestion);
                          },
                        ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _reasonController,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: const InputDecoration(
                      labelText: 'Motivo',
                      hintText: 'Ex.: reposição manual, perda, ajuste',
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
                      hintText: 'Opcional',
                    ),
                  ),
                  const SizedBox(height: 20),
                  Align(
                    alignment: Alignment.centerRight,
                    child: FilledButton.icon(
                      onPressed: _isSaving ? null : _saveAdjustment,
                      icon: _isSaving
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.2,
                              ),
                            )
                          : const Icon(Icons.save_rounded),
                      label: Text(_isSaving ? 'Salvando...' : 'Salvar ajuste'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _saveAdjustment() async {
    if (_quantity <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Digite uma quantidade maior que zero.')),
      );
      return;
    }

    if (_projectedStock < 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Este ajuste faria o estoque ficar negativo.'),
        ),
      );
      return;
    }

    if (_reasonController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Explique rapidamente o motivo do ajuste.'),
        ),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      await ref
          .read(ingredientsRepositoryProvider)
          .adjustStock(
            IngredientStockAdjustmentInput(
              ingredientId: widget.ingredient.id,
              quantityDelta: _signedDelta,
              reason: _reasonController.text,
              notes: _notesController.text,
            ),
          );

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ajuste salvo neste aparelho.')),
      );
      context.go('${IngredientsPage.basePath}/${widget.ingredient.id}');
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
}

class _AdjustmentPreviewCard extends StatelessWidget {
  const _AdjustmentPreviewCard({
    required this.ingredient,
    required this.projectedStock,
  });

  final IngredientRecord ingredient;
  final int projectedStock;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final projectedLowStock =
        ingredient.minimumStockQuantity > 0 &&
        projectedStock <= ingredient.minimumStockQuantity;

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
          IngredientStockBadge(isLowStock: projectedLowStock),
          const SizedBox(height: 16),
          Text(ingredient.name, style: theme.textTheme.headlineSmall),
          const SizedBox(height: 6),
          Text(
            'Atual: ${ingredient.displayCurrentStock} • Depois do ajuste: ${ingredient.stockUnit.formatQuantity(projectedStock < 0 ? 0 : projectedStock)}',
            style: theme.textTheme.bodyLarge,
          ),
        ],
      ),
    );
  }
}

const _reasonSuggestions = [
  'Reposição manual',
  'Uso na produção',
  'Perda',
  'Correção',
];
