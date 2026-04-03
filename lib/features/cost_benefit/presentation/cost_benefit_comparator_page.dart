import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/navigation/app_destinations.dart';
import '../../../core/formatters/app_formatters.dart';
import '../../../core/money/currency_text_input_formatter.dart';
import '../../../core/money/money.dart';
import '../../../core/responsive/app_breakpoints.dart';
import '../../../core/widgets/app_page_scaffold.dart';
import '../../ingredients/application/ingredient_providers.dart';
import '../../ingredients/domain/ingredient.dart';
import '../../ingredients/domain/ingredient_unit.dart';
import '../domain/cost_benefit_comparison.dart';
import '../domain/cost_benefit_unit.dart';

class CostBenefitComparatorPage extends ConsumerStatefulWidget {
  const CostBenefitComparatorPage({super.key, this.ingredientId});

  static final basePath = '${AppDestinations.purchases.path}/comparator';

  final String? ingredientId;

  @override
  ConsumerState<CostBenefitComparatorPage> createState() =>
      _CostBenefitComparatorPageState();
}

class _CostBenefitComparatorPageState
    extends ConsumerState<CostBenefitComparatorPage> {
  static const _maxOptions = 6;
  static final RegExp _quantityPattern = RegExp(r'^(\d+)(?:[,.](\d{0,3}))?$');

  final List<_ComparatorOptionDraft> _drafts = [];
  int _nextDraftId = 0;
  late CostBenefitUnitFamily _selectedFamily;
  IngredientRecord? _importedIngredient;
  bool _hasAppliedIngredientContext = false;

  @override
  void initState() {
    super.initState();
    _selectedFamily = CostBenefitUnitFamily.weight;
    _drafts.addAll(_buildInitialDrafts());
  }

  @override
  void dispose() {
    for (final draft in _drafts) {
      draft.dispose();
    }

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ingredientAsync = widget.ingredientId == null
        ? const AsyncData<IngredientRecord?>(null)
        : ref.watch(ingredientProvider(widget.ingredientId!));

    _maybeApplyIngredientContext(ingredientAsync);

    final draftStates = <int, _DraftEvaluation>{};
    final comparableInputs = <CostBenefitOptionInput>[];

    for (var index = 0; index < _drafts.length; index++) {
      final draft = _drafts[index];
      final evaluation = _evaluateDraft(draft, index);
      draftStates[draft.id] = evaluation;

      if (evaluation.comparableInput != null) {
        comparableInputs.add(evaluation.comparableInput!);
      }
    }

    final comparison = comparableInputs.length >= 2
        ? CostBenefitComparisonCalculator.compare(comparableInputs)
        : null;
    final resultByDraftId = <int, CostBenefitOptionResult>{
      if (comparison != null)
        for (final result in comparison.rankedOptions)
          result.sourceIndex: result,
    };
    final incompleteCount = draftStates.values
        .where((state) => state.isPartiallyFilled)
        .length;
    final viewModel = _ComparisonViewModel(
      comparison: comparison,
      resultByDraftId: resultByDraftId,
      comparableCount: comparableInputs.length,
      incompleteCount: incompleteCount,
    );

    return AppPageScaffold(
      title: 'Comparador de custo-benefício',
      subtitle:
          'Compare tamanhos e preços em segundos para descobrir qual opção compensa mais por peso, volume ou unidade.',
      trailing: FilledButton.tonalIcon(
        onPressed: _resetComparison,
        icon: const Icon(Icons.restart_alt_rounded),
        label: const Text('Nova comparação'),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (widget.ingredientId != null) ...[
            _IngredientContextCard(
              ingredientAsync: ingredientAsync,
              importedIngredient: _importedIngredient,
            ),
            const SizedBox(height: 16),
          ],
          _ComparisonModeCard(
            selectedFamily: _selectedFamily,
            onSelectFamily: _selectFamily,
          ),
          const SizedBox(height: 16),
          _ComparisonSummaryCard(viewModel: viewModel),
          const SizedBox(height: 20),
          _OptionsHeader(
            canAddMore: _drafts.length < _maxOptions,
            onAddOption: _drafts.length < _maxOptions ? _addOption : null,
          ),
          const SizedBox(height: 12),
          LayoutBuilder(
            builder: (context, constraints) {
              final compactLayout = constraints.maxWidth < 920;
              final cardWidth = compactLayout
                  ? constraints.maxWidth
                  : (constraints.maxWidth - 12) / 2;

              return Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  for (var index = 0; index < _drafts.length; index++)
                    SizedBox(
                      width: cardWidth,
                      child: _ComparatorOptionCard(
                        title: 'Opção ${index + 1}',
                        draft: _drafts[index],
                        selectedFamily: _selectedFamily,
                        evaluation: draftStates[_drafts[index].id]!,
                        result: viewModel.resultByDraftId[_drafts[index].id],
                        canRemove: _drafts.length > 2,
                        onChangedUnit: (value) =>
                            _updateDraftUnit(_drafts[index], value),
                        onRemove: _drafts.length > 2
                            ? () => _removeOption(_drafts[index])
                            : null,
                      ),
                    ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  void _maybeApplyIngredientContext(
    AsyncValue<IngredientRecord?> ingredientAsync,
  ) {
    final ingredient = ingredientAsync.asData?.value;
    if (_hasAppliedIngredientContext || ingredient == null) {
      return;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _hasAppliedIngredientContext) {
        return;
      }

      _applyIngredientContext(ingredient);
    });
  }

  void _applyIngredientContext(IngredientRecord ingredient) {
    final importedUnit = _resolveImportedUnit(ingredient);
    if (importedUnit == null) {
      return;
    }

    _importedIngredient = ingredient;
    _hasAppliedIngredientContext = true;

    setState(() {
      _selectedFamily = importedUnit.family;
      _replaceDrafts(_buildInitialDrafts());
    });
  }

  List<_ComparatorOptionDraft> _buildInitialDrafts() {
    final drafts = <_ComparatorOptionDraft>[];

    if (_importedIngredient != null) {
      drafts.add(_createReferenceDraft(_importedIngredient!));
    }

    while (drafts.length < 2) {
      drafts.add(_createBlankDraft());
    }

    return drafts;
  }

  _ComparatorOptionDraft _createReferenceDraft(IngredientRecord ingredient) {
    final importedUnit = _resolveImportedUnit(ingredient)!;
    final quantityInThousandths = _resolveImportedQuantity(ingredient);

    return _createDraft(
      labelText: 'Cadastro atual',
      price: ingredient.unitCost,
      quantityInThousandths: quantityInThousandths,
      unit: importedUnit,
    );
  }

  _ComparatorOptionDraft _createBlankDraft() {
    return _createDraft(
      unit: CostBenefitUnit.defaultForFamily(_selectedFamily),
    );
  }

  _ComparatorOptionDraft _createDraft({
    required CostBenefitUnit unit,
    String labelText = '',
    Money? price,
    int? quantityInThousandths,
  }) {
    final draft = _ComparatorOptionDraft(
      id: _nextDraftId++,
      unit: unit,
      labelText: labelText,
      priceText: price?.formatInput() ?? '',
      quantityText: quantityInThousandths == null
          ? ''
          : _formatQuantity(quantityInThousandths),
    );
    draft.addListener(_handleDraftChanged);
    return draft;
  }

  void _replaceDrafts(List<_ComparatorOptionDraft> nextDrafts) {
    for (final draft in _drafts) {
      draft.removeListener(_handleDraftChanged);
      draft.dispose();
    }

    _drafts
      ..clear()
      ..addAll(nextDrafts);
  }

  void _handleDraftChanged() {
    if (!mounted) {
      return;
    }

    setState(() {});
  }

  void _resetComparison() {
    setState(() {
      if (_importedIngredient != null) {
        _selectedFamily = _resolveImportedUnit(_importedIngredient!)!.family;
      }

      _replaceDrafts(_buildInitialDrafts());
    });
  }

  void _selectFamily(CostBenefitUnitFamily family) {
    if (_selectedFamily == family) {
      return;
    }

    setState(() {
      _selectedFamily = family;
      final defaultUnit = CostBenefitUnit.defaultForFamily(family);

      for (final draft in _drafts) {
        draft.unit = defaultUnit;
      }
    });
  }

  void _updateDraftUnit(_ComparatorOptionDraft draft, CostBenefitUnit unit) {
    if (draft.unit == unit) {
      return;
    }

    setState(() {
      draft.unit = unit;
    });
  }

  void _addOption() {
    if (_drafts.length >= _maxOptions) {
      return;
    }

    setState(() {
      _drafts.add(_createBlankDraft());
    });
  }

  void _removeOption(_ComparatorOptionDraft draft) {
    setState(() {
      draft.removeListener(_handleDraftChanged);
      draft.dispose();
      _drafts.remove(draft);
    });
  }

  _DraftEvaluation _evaluateDraft(_ComparatorOptionDraft draft, int index) {
    final labelText = draft.labelController.text.trim();
    final priceText = draft.priceController.text.trim();
    final quantityText = draft.quantityController.text.trim();
    final hasStartedComparison =
        priceText.isNotEmpty || quantityText.isNotEmpty;
    final parsedPrice = priceText.isEmpty ? null : Money.fromInput(priceText);
    final parsedQuantity = quantityText.isEmpty
        ? null
        : _parseQuantityInThousandths(quantityText);

    String? priceError;
    if (hasStartedComparison && priceText.isEmpty) {
      priceError = 'Falta o preço.';
    } else if (parsedPrice != null && parsedPrice.cents <= 0) {
      priceError = 'Digite um preço maior que zero.';
    }

    String? quantityError;
    if (hasStartedComparison && quantityText.isEmpty) {
      quantityError = 'Falta a quantidade.';
    } else if (quantityText.isNotEmpty && parsedQuantity == null) {
      quantityError = 'Use até 3 casas decimais. Exemplo: 1,5';
    } else if (parsedQuantity != null && parsedQuantity <= 0) {
      quantityError = 'Digite uma quantidade maior que zero.';
    }

    final comparableInput =
        priceError == null &&
            quantityError == null &&
            parsedPrice != null &&
            parsedPrice.cents > 0 &&
            parsedQuantity != null &&
            parsedQuantity > 0
        ? CostBenefitOptionInput(
            sourceIndex: draft.id,
            label: labelText.isEmpty ? 'Opção ${index + 1}' : labelText,
            price: parsedPrice,
            quantityInThousandths: parsedQuantity,
            unit: draft.unit,
          )
        : null;

    return _DraftEvaluation(
      priceErrorText: priceError,
      quantityErrorText: quantityError,
      comparableInput: comparableInput,
      isPartiallyFilled: hasStartedComparison && comparableInput == null,
    );
  }

  int? _parseQuantityInThousandths(String rawText) {
    final match = _quantityPattern.firstMatch(rawText.trim());
    if (match == null) {
      return null;
    }

    final wholePart = int.parse(match.group(1)!);
    final fractionPart = (match.group(2) ?? '')
        .replaceAll(',', '')
        .replaceAll('.', '')
        .padRight(3, '0');

    return wholePart * 1000 + int.parse(fractionPart);
  }

  String _formatQuantity(int quantityInThousandths) {
    final wholePart = quantityInThousandths ~/ 1000;
    final fractionPart = quantityInThousandths % 1000;

    if (fractionPart == 0) {
      return AppFormatters.wholeNumber(wholePart);
    }

    final trimmedFraction = fractionPart
        .toString()
        .padLeft(3, '0')
        .replaceFirst(RegExp(r'0+$'), '');

    return '${AppFormatters.wholeNumber(wholePart)},$trimmedFraction';
  }

  CostBenefitUnit? _resolveImportedUnit(IngredientRecord ingredient) {
    if (ingredient.purchaseUnit == IngredientUnit.package) {
      return _mapIngredientUnit(ingredient.stockUnit);
    }

    return _mapIngredientUnit(ingredient.purchaseUnit);
  }

  int _resolveImportedQuantity(IngredientRecord ingredient) {
    if (ingredient.purchaseUnit == IngredientUnit.package) {
      return ingredient.conversionFactor * 1000;
    }

    return 1000;
  }

  CostBenefitUnit? _mapIngredientUnit(IngredientUnit unit) {
    return switch (unit) {
      IngredientUnit.gram => CostBenefitUnit.gram,
      IngredientUnit.kilogram => CostBenefitUnit.kilogram,
      IngredientUnit.milliliter => CostBenefitUnit.milliliter,
      IngredientUnit.liter => CostBenefitUnit.liter,
      IngredientUnit.unit => CostBenefitUnit.unit,
      IngredientUnit.package => null,
    };
  }
}

class _ComparisonViewModel {
  const _ComparisonViewModel({
    required this.comparison,
    required this.resultByDraftId,
    required this.comparableCount,
    required this.incompleteCount,
  });

  final CostBenefitComparisonResult? comparison;
  final Map<int, CostBenefitOptionResult> resultByDraftId;
  final int comparableCount;
  final int incompleteCount;
}

class _DraftEvaluation {
  const _DraftEvaluation({
    required this.priceErrorText,
    required this.quantityErrorText,
    required this.comparableInput,
    required this.isPartiallyFilled,
  });

  final String? priceErrorText;
  final String? quantityErrorText;
  final CostBenefitOptionInput? comparableInput;
  final bool isPartiallyFilled;
}

class _ComparatorOptionDraft {
  _ComparatorOptionDraft({
    required this.id,
    required this.unit,
    required String labelText,
    required String priceText,
    required String quantityText,
  }) : labelController = TextEditingController(text: labelText),
       priceController = TextEditingController(text: priceText),
       quantityController = TextEditingController(text: quantityText);

  final int id;
  final TextEditingController labelController;
  final TextEditingController priceController;
  final TextEditingController quantityController;
  CostBenefitUnit unit;

  void addListener(VoidCallback listener) {
    labelController.addListener(listener);
    priceController.addListener(listener);
    quantityController.addListener(listener);
  }

  void removeListener(VoidCallback listener) {
    labelController.removeListener(listener);
    priceController.removeListener(listener);
    quantityController.removeListener(listener);
  }

  void dispose() {
    labelController.dispose();
    priceController.dispose();
    quantityController.dispose();
  }
}

class _IngredientContextCard extends StatelessWidget {
  const _IngredientContextCard({
    required this.ingredientAsync,
    required this.importedIngredient,
  });

  final AsyncValue<IngredientRecord?> ingredientAsync;
  final IngredientRecord? importedIngredient;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: ingredientAsync.when(
          loading: () => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Puxando referência do ingrediente',
                style: theme.textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              const LinearProgressIndicator(minHeight: 4),
            ],
          ),
          error: (error, stackTrace) => Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.warning_amber_rounded, color: theme.colorScheme.error),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Não deu para importar o ingrediente agora. Você ainda pode usar o comparador normalmente.',
                  style: theme.textTheme.bodyMedium,
                ),
              ),
            ],
          ),
          data: (ingredient) {
            if (ingredient == null) {
              return Text(
                'A referência do ingrediente não foi encontrada. O comparador segue disponível de forma independente.',
                style: theme.textTheme.bodyMedium,
              );
            }

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.secondaryContainer,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        'Referência importada',
                        style: theme.textTheme.labelLarge,
                      ),
                    ),
                    if (ingredient.preferredSupplier != null)
                      Text(
                        'Base: ${ingredient.preferredSupplier!.supplierName}',
                        style: theme.textTheme.bodyMedium,
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(ingredient.name, style: theme.textTheme.titleLarge),
                const SizedBox(height: 6),
                Text(
                  _buildReferenceSummary(ingredient),
                  style: theme.textTheme.bodyMedium,
                ),
                const SizedBox(height: 8),
                Text(
                  importedIngredient == null
                      ? 'A primeira opção será preenchida assim que a referência terminar de carregar.'
                      : 'A primeira opção já entrou com o custo salvo no cadastro para você comparar com novos preços.',
                  style: theme.textTheme.bodySmall,
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  String _buildReferenceSummary(IngredientRecord ingredient) {
    if (ingredient.purchaseUnit == IngredientUnit.package) {
      return '${ingredient.unitCost.format()} por pacote com ${AppFormatters.wholeNumber(ingredient.conversionFactor)} ${ingredient.stockUnit.shortLabel}.';
    }

    return '${ingredient.unitCost.format()} por ${ingredient.purchaseUnit.shortLabel}.';
  }
}

class _ComparisonModeCard extends StatelessWidget {
  const _ComparisonModeCard({
    required this.selectedFamily,
    required this.onSelectFamily,
  });

  final CostBenefitUnitFamily selectedFamily;
  final ValueChanged<CostBenefitUnitFamily> onSelectFamily;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Como você quer comparar?', style: theme.textTheme.titleLarge),
            const SizedBox(height: 6),
            Text(
              'Escolha uma base só. O app já normaliza `g` com `kg`, `ml` com `L` e mantém tudo fácil de bater o olho.',
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                for (final family in CostBenefitUnitFamily.values)
                  ChoiceChip(
                    selected: selectedFamily == family,
                    onSelected: (_) => onSelectFamily(family),
                    avatar: Icon(_familyIcon(family), size: 18),
                    label: Text(_familyLabel(family)),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              _familyHelperText(selectedFamily),
              style: theme.textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }

  IconData _familyIcon(CostBenefitUnitFamily family) {
    return switch (family) {
      CostBenefitUnitFamily.weight => Icons.scale_rounded,
      CostBenefitUnitFamily.volume => Icons.water_drop_outlined,
      CostBenefitUnitFamily.count => Icons.category_outlined,
    };
  }

  String _familyLabel(CostBenefitUnitFamily family) {
    return switch (family) {
      CostBenefitUnitFamily.weight => 'Peso',
      CostBenefitUnitFamily.volume => 'Volume',
      CostBenefitUnitFamily.count => 'Unidade',
    };
  }

  String _familyHelperText(CostBenefitUnitFamily family) {
    return switch (family) {
      CostBenefitUnitFamily.weight =>
        'O resultado final aparece por kg, mesmo que você digite opções em g ou kg.',
      CostBenefitUnitFamily.volume =>
        'O resultado final aparece por litro, mesmo que você use ml ou L.',
      CostBenefitUnitFamily.count =>
        'O resultado final aparece por unidade para caixas, bandejas ou kits fechados.',
    };
  }
}

class _ComparisonSummaryCard extends StatelessWidget {
  const _ComparisonSummaryCard({required this.viewModel});

  final _ComparisonViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final comparison = viewModel.comparison;

    if (comparison == null) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Preencha pelo menos duas opções',
                style: theme.textTheme.titleLarge,
              ),
              const SizedBox(height: 6),
              Text(
                'Com preço e quantidade em pelo menos duas linhas, o melhor custo-benefício aparece aqui na hora.',
                style: theme.textTheme.bodyMedium,
              ),
              if (viewModel.incompleteCount > 0) ...[
                const SizedBox(height: 12),
                Text(
                  '${viewModel.incompleteCount} opção${viewModel.incompleteCount == 1 ? '' : 'ões'} ainda está${viewModel.incompleteCount == 1 ? '' : 'ão'} incompleta${viewModel.incompleteCount == 1 ? '' : 's'}.',
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ],
          ),
        ),
      );
    }

    final summary = comparison.summary;
    final bestOption = summary.bestOption;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            theme.colorScheme.primaryContainer,
            theme.colorScheme.surface,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(32),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              summary.hasTieForBestValue
                  ? 'Empate na melhor compra'
                  : 'Melhor compra agora',
              style: theme.textTheme.labelLarge,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            summary.hasTieForBestValue
                ? 'As ${summary.tiedBestOptionCount} primeiras opções ficaram com o mesmo custo-benefício.'
                : bestOption.label,
            style: theme.textTheme.headlineSmall,
          ),
          const SizedBox(height: 8),
          Text(
            summary.hasTieForBestValue
                ? '${bestOption.normalizedPrice.format()} / ${summary.normalizedUnitLabel} para as melhores opções.'
                : '${bestOption.normalizedPrice.format()} / ${summary.normalizedUnitLabel}.',
            style: theme.textTheme.bodyLarge,
          ),
          const SizedBox(height: 20),
          LayoutBuilder(
            builder: (context, constraints) {
              final compactLayout = constraints.maxWidth < 720;
              final metricWidth = compactLayout
                  ? constraints.maxWidth
                  : (constraints.maxWidth - 24) / 3;

              return Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  SizedBox(
                    width: metricWidth,
                    child: _SummaryMetric(
                      label: 'Comparadas',
                      value: viewModel.comparableCount.toString(),
                    ),
                  ),
                  SizedBox(
                    width: metricWidth,
                    child: _SummaryMetric(
                      label: 'Base',
                      value: summary.normalizedUnitLabel,
                    ),
                  ),
                  SizedBox(
                    width: metricWidth,
                    child: _SummaryMetric(
                      label: summary.hasTieForBestValue
                          ? 'Próxima diferença'
                          : 'Vantagem',
                      value:
                          summary.savingsAgainstNextBest == null ||
                              summary.savingsAgainstNextBestInTenthsPercent ==
                                  null
                          ? 'Sem folga'
                          : '${summary.savingsAgainstNextBest!.format()} / ${summary.normalizedUnitLabel}',
                      subtitle:
                          summary.savingsAgainstNextBest == null ||
                              summary.savingsAgainstNextBestInTenthsPercent ==
                                  null
                          ? null
                          : '${_formatPercent(summary.savingsAgainstNextBestInTenthsPercent!)} de diferença',
                    ),
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 20),
          Column(
            children: [
              for (
                var index = 0;
                index < comparison.rankedOptions.length;
                index++
              )
                Padding(
                  padding: EdgeInsets.only(
                    bottom: index == comparison.rankedOptions.length - 1
                        ? 0
                        : 8,
                  ),
                  child: _RankingRow(result: comparison.rankedOptions[index]),
                ),
            ],
          ),
          if (viewModel.incompleteCount > 0) ...[
            const SizedBox(height: 12),
            Text(
              '${viewModel.incompleteCount} opção${viewModel.incompleteCount == 1 ? '' : 'ões'} ainda ficou${viewModel.incompleteCount == 1 ? '' : 'ram'} fora da comparação porque está${viewModel.incompleteCount == 1 ? '' : 'ão'} incompleta${viewModel.incompleteCount == 1 ? '' : 's'}.',
              style: theme.textTheme.bodySmall,
            ),
          ],
        ],
      ),
    );
  }

  String _formatPercent(int tenthsPercent) {
    final wholePart = tenthsPercent ~/ 10;
    final decimalPart = tenthsPercent % 10;

    if (decimalPart == 0) {
      return '$wholePart%';
    }

    return '$wholePart,$decimalPart%';
  }
}

class _OptionsHeader extends StatelessWidget {
  const _OptionsHeader({required this.canAddMore, required this.onAddOption});

  final bool canAddMore;
  final VoidCallback? onAddOption;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final compactLayout = AppBreakpoints.isCompactWidth(
      MediaQuery.sizeOf(context).width,
    );

    final text = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Opções para comparar', style: theme.textTheme.titleLarge),
        const SizedBox(height: 4),
        Text(
          'Preencha só o essencial. Até 6 opções para a tela continuar leve.',
          style: theme.textTheme.bodyMedium,
        ),
      ],
    );

    final action = OutlinedButton.icon(
      onPressed: onAddOption,
      icon: const Icon(Icons.add_rounded),
      label: Text(canAddMore ? 'Adicionar opção' : 'Limite atingido'),
    );

    if (compactLayout) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [text, const SizedBox(height: 12), action],
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: text),
        const SizedBox(width: 16),
        action,
      ],
    );
  }
}

class _ComparatorOptionCard extends StatelessWidget {
  const _ComparatorOptionCard({
    required this.title,
    required this.draft,
    required this.selectedFamily,
    required this.evaluation,
    required this.result,
    required this.canRemove,
    required this.onChangedUnit,
    required this.onRemove,
  });

  final String title;
  final _ComparatorOptionDraft draft;
  final CostBenefitUnitFamily selectedFamily;
  final _DraftEvaluation evaluation;
  final CostBenefitOptionResult? result;
  final bool canRemove;
  final ValueChanged<CostBenefitUnit> onChangedUnit;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isBestValue = result?.isBestValue == true;
    final backgroundColor = isBestValue
        ? theme.colorScheme.primaryContainer.withValues(alpha: 0.55)
        : theme.colorScheme.surface;
    final borderColor = isBestValue
        ? theme.colorScheme.primary
        : theme.colorScheme.outlineVariant;

    return Container(
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: borderColor),
      ),
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
                    Text(title, style: theme.textTheme.titleMedium),
                    const SizedBox(height: 8),
                    _OptionStatusPill(result: result),
                  ],
                ),
              ),
              if (canRemove)
                IconButton(
                  onPressed: onRemove,
                  tooltip: 'Remover opção',
                  icon: const Icon(Icons.close_rounded),
                ),
            ],
          ),
          const SizedBox(height: 16),
          TextField(
            controller: draft.labelController,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(
              labelText: 'Nome curto',
              hintText: 'Ex.: Atacado, pacote grande',
            ),
          ),
          const SizedBox(height: 12),
          LayoutBuilder(
            builder: (context, constraints) {
              final compactLayout = constraints.maxWidth < 520;
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
                      controller: draft.priceController,
                      keyboardType: TextInputType.number,
                      inputFormatters: const [CurrencyTextInputFormatter()],
                      decoration: InputDecoration(
                        labelText: 'Preço',
                        prefixText: 'R\$ ',
                        errorText: evaluation.priceErrorText,
                      ),
                    ),
                  ),
                  SizedBox(
                    width: fieldWidth,
                    child: Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: draft.quantityController,
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            inputFormatters: [
                              FilteringTextInputFormatter.allow(
                                RegExp(r'[0-9,\.]'),
                              ),
                            ],
                            decoration: InputDecoration(
                              labelText: 'Quantidade',
                              hintText: _quantityHint(selectedFamily),
                              errorText: evaluation.quantityErrorText,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        SizedBox(
                          width: 112,
                          child: DropdownButtonFormField<CostBenefitUnit>(
                            key: ValueKey(
                              '${draft.id}-${selectedFamily.name}-${draft.unit.name}',
                            ),
                            initialValue: draft.unit,
                            decoration: const InputDecoration(
                              labelText: 'Unidade',
                            ),
                            items: [
                              for (final unit
                                  in CostBenefitUnit.valuesForFamily(
                                    selectedFamily,
                                  ))
                                DropdownMenuItem(
                                  value: unit,
                                  child: Text(unit.shortLabel),
                                ),
                            ],
                            onChanged: (value) {
                              if (value != null) {
                                onChangedUnit(value);
                              }
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 16),
          _OptionFootnote(result: result),
        ],
      ),
    );
  }

  String _quantityHint(CostBenefitUnitFamily family) {
    return switch (family) {
      CostBenefitUnitFamily.weight => 'Ex.: 500 ou 1,5',
      CostBenefitUnitFamily.volume => 'Ex.: 900 ou 1,5',
      CostBenefitUnitFamily.count => 'Ex.: 6 ou 12',
    };
  }
}

class _OptionStatusPill extends StatelessWidget {
  const _OptionStatusPill({required this.result});

  final CostBenefitOptionResult? result;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    late final String label;
    late final Color backgroundColor;
    late final Color foregroundColor;

    if (result == null) {
      label = 'Aguardando comparação';
      backgroundColor = colorScheme.surfaceContainerLow;
      foregroundColor = colorScheme.onSurfaceVariant;
    } else if (result!.isTiedBestValue) {
      label = 'Empatou na melhor compra';
      backgroundColor = colorScheme.tertiaryContainer;
      foregroundColor = colorScheme.onTertiaryContainer;
    } else if (result!.isBestValue) {
      label = 'Melhor compra';
      backgroundColor = colorScheme.primary;
      foregroundColor = colorScheme.onPrimary;
    } else {
      label =
          '+ ${_formatPercent(result!.differenceFromBestInTenthsPercent)} mais caro';
      backgroundColor = colorScheme.secondaryContainer;
      foregroundColor = colorScheme.onSecondaryContainer;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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

  String _formatPercent(int tenthsPercent) {
    final wholePart = tenthsPercent ~/ 10;
    final decimalPart = tenthsPercent % 10;

    if (decimalPart == 0) {
      return '$wholePart%';
    }

    return '$wholePart,$decimalPart%';
  }
}

class _OptionFootnote extends StatelessWidget {
  const _OptionFootnote({required this.result});

  final CostBenefitOptionResult? result;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (result == null) {
      return Text(
        'Assim que esta opção tiver preço e quantidade, ela entra na comparação automaticamente.',
        style: theme.textTheme.bodySmall,
      );
    }

    final priceLabel =
        '${result!.normalizedPrice.format()} / ${result!.unit.normalizedUnitLabel}';

    final supportingText = result!.isBestValue
        ? 'Essa é a base mais vantajosa até agora.'
        : 'Você paga em torno de ${result!.estimatedSavingsForSameQuantity.format()} a mais para esta mesma quantidade.';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(priceLabel, style: theme.textTheme.titleMedium),
        const SizedBox(height: 4),
        Text(supportingText, style: theme.textTheme.bodySmall),
      ],
    );
  }
}

class _SummaryMetric extends StatelessWidget {
  const _SummaryMetric({
    required this.label,
    required this.value,
    this.subtitle,
  });

  final String label;
  final String value;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: theme.textTheme.labelLarge),
            const SizedBox(height: 8),
            Text(value, style: theme.textTheme.titleLarge),
            if (subtitle != null) ...[
              const SizedBox(height: 4),
              Text(subtitle!, style: theme.textTheme.bodySmall),
            ],
          ],
        ),
      ),
    );
  }
}

class _RankingRow extends StatelessWidget {
  const _RankingRow({required this.result});

  final CostBenefitOptionResult result;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final subtitle = result.isBestValue
        ? result.isTiedBestValue
              ? 'Mesmo valor das outras melhores opções.'
              : 'Base mais econômica da comparação.'
        : '${_formatPercent(result.differenceFromBestInTenthsPercent)} acima da melhor compra.';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface.withValues(alpha: 0.78),
        borderRadius: BorderRadius.circular(22),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(result.label, style: theme.textTheme.titleMedium),
                const SizedBox(height: 4),
                Text(subtitle, style: theme.textTheme.bodySmall),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Text(
            '${result.normalizedPrice.format()} / ${result.unit.normalizedUnitLabel}',
            style: theme.textTheme.titleMedium,
            textAlign: TextAlign.end,
          ),
        ],
      ),
    );
  }

  String _formatPercent(int tenthsPercent) {
    final wholePart = tenthsPercent ~/ 10;
    final decimalPart = tenthsPercent % 10;

    if (decimalPart == 0) {
      return '$wholePart%';
    }

    return '$wholePart,$decimalPart%';
  }
}
