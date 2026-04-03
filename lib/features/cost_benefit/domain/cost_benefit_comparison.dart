import 'package:flutter/foundation.dart';

import '../../../core/money/money.dart';
import 'cost_benefit_unit.dart';

@immutable
class CostBenefitOptionInput {
  const CostBenefitOptionInput({
    this.sourceIndex,
    required this.label,
    required this.price,
    required this.quantityInThousandths,
    required this.unit,
  });

  final int? sourceIndex;
  final String label;
  final Money price;
  final int quantityInThousandths;
  final CostBenefitUnit unit;
}

@immutable
class CostBenefitOptionResult {
  const CostBenefitOptionResult({
    required this.sourceIndex,
    required this.label,
    required this.price,
    required this.unit,
    required this.quantityInThousandths,
    required this.normalizedPrice,
    required this.estimatedSavingsForSameQuantity,
    required this.differenceFromBestInTenthsPercent,
    required this.isBestValue,
    required this.isTiedBestValue,
  });

  final int sourceIndex;
  final String label;
  final Money price;
  final CostBenefitUnit unit;
  final int quantityInThousandths;
  final Money normalizedPrice;
  final Money estimatedSavingsForSameQuantity;
  final int differenceFromBestInTenthsPercent;
  final bool isBestValue;
  final bool isTiedBestValue;
}

@immutable
class CostBenefitComparisonSummary {
  const CostBenefitComparisonSummary({
    required this.bestOption,
    required this.normalizedUnitLabel,
    required this.hasTieForBestValue,
    required this.tiedBestOptionCount,
    required this.savingsAgainstNextBest,
    required this.savingsAgainstNextBestInTenthsPercent,
  });

  final CostBenefitOptionResult bestOption;
  final String normalizedUnitLabel;
  final bool hasTieForBestValue;
  final int tiedBestOptionCount;
  final Money? savingsAgainstNextBest;
  final int? savingsAgainstNextBestInTenthsPercent;
}

@immutable
class CostBenefitComparisonResult {
  const CostBenefitComparisonResult({
    required this.summary,
    required this.rankedOptions,
  });

  final CostBenefitComparisonSummary summary;
  final List<CostBenefitOptionResult> rankedOptions;
}

abstract final class CostBenefitComparisonCalculator {
  static CostBenefitComparisonResult compare(
    List<CostBenefitOptionInput> options,
  ) {
    if (options.length < 2) {
      throw ArgumentError('At least two options are required for comparison.');
    }

    final family = options.first.unit.family;

    for (final option in options) {
      if (option.unit.family != family) {
        throw ArgumentError('All options must belong to the same unit family.');
      }

      if (option.price.cents <= 0 || option.quantityInThousandths <= 0) {
        throw ArgumentError('Price and quantity must be greater than zero.');
      }
    }

    final candidates = <_OptionCandidate>[
      for (var index = 0; index < options.length; index++)
        _OptionCandidate.fromInput(index, options[index]),
    ]..sort(_compareCandidates);

    final bestCandidate = candidates.first;
    final tiedBestOptionCount = candidates.takeWhile((candidate) {
      return _compareRate(candidate, bestCandidate) == 0;
    }).length;
    final nextBestCandidate = tiedBestOptionCount < candidates.length
        ? candidates[tiedBestOptionCount]
        : null;

    final rankedOptions = candidates
        .map((candidate) {
          final isBestValue = _compareRate(candidate, bestCandidate) == 0;
          final estimatedSavingsForSameQuantity = isBestValue
              ? Money.zero
              : candidate.price -
                    Money.fromCents(
                      _divideRounded(
                        bestCandidate.price.cents * candidate.baseMilliQuantity,
                        bestCandidate.baseMilliQuantity,
                      ),
                    );

          return CostBenefitOptionResult(
            sourceIndex: candidate.sourceIndex,
            label: candidate.label,
            price: candidate.price,
            unit: candidate.unit,
            quantityInThousandths: candidate.quantityInThousandths,
            normalizedPrice: candidate.normalizedPrice,
            estimatedSavingsForSameQuantity: estimatedSavingsForSameQuantity,
            differenceFromBestInTenthsPercent: isBestValue
                ? 0
                : _calculateDifferenceFromBestInTenthsPercent(
                    candidate: candidate,
                    bestCandidate: bestCandidate,
                  ),
            isBestValue: isBestValue,
            isTiedBestValue: isBestValue && tiedBestOptionCount > 1,
          );
        })
        .toList(growable: false);

    return CostBenefitComparisonResult(
      summary: CostBenefitComparisonSummary(
        bestOption: rankedOptions.first,
        normalizedUnitLabel: bestCandidate.unit.normalizedUnitLabel,
        hasTieForBestValue: tiedBestOptionCount > 1,
        tiedBestOptionCount: tiedBestOptionCount,
        savingsAgainstNextBest: nextBestCandidate == null
            ? null
            : nextBestCandidate.normalizedPrice - bestCandidate.normalizedPrice,
        savingsAgainstNextBestInTenthsPercent: nextBestCandidate == null
            ? null
            : _calculateDifferenceFromBestInTenthsPercent(
                candidate: nextBestCandidate,
                bestCandidate: bestCandidate,
              ),
      ),
      rankedOptions: rankedOptions,
    );
  }

  static int _compareCandidates(_OptionCandidate left, _OptionCandidate right) {
    final comparison = _compareRate(left, right);

    if (comparison != 0) {
      return comparison;
    }

    return left.sourceIndex.compareTo(right.sourceIndex);
  }

  static int _compareRate(_OptionCandidate left, _OptionCandidate right) {
    final leftScore = left.price.cents * right.baseMilliQuantity;
    final rightScore = right.price.cents * left.baseMilliQuantity;
    return leftScore.compareTo(rightScore);
  }

  static int _calculateDifferenceFromBestInTenthsPercent({
    required _OptionCandidate candidate,
    required _OptionCandidate bestCandidate,
  }) {
    final numerator =
        candidate.price.cents * bestCandidate.baseMilliQuantity -
        bestCandidate.price.cents * candidate.baseMilliQuantity;
    final denominator = bestCandidate.price.cents * candidate.baseMilliQuantity;

    if (numerator <= 0 || denominator <= 0) {
      return 0;
    }

    return _divideRounded(numerator * 1000, denominator);
  }

  static int _divideRounded(int numerator, int denominator) {
    if (denominator <= 0) {
      return 0;
    }

    return (numerator + (denominator ~/ 2)) ~/ denominator;
  }
}

class _OptionCandidate {
  const _OptionCandidate({
    required this.sourceIndex,
    required this.label,
    required this.price,
    required this.unit,
    required this.quantityInThousandths,
    required this.baseMilliQuantity,
    required this.normalizedPrice,
  });

  factory _OptionCandidate.fromInput(
    int fallbackSourceIndex,
    CostBenefitOptionInput input,
  ) {
    final baseMilliQuantity = input.unit.toBaseMilliUnits(
      input.quantityInThousandths,
    );
    final normalizedQuantityInBaseMilli = input.unit.normalizedBaseUnits * 1000;

    return _OptionCandidate(
      sourceIndex: input.sourceIndex ?? fallbackSourceIndex,
      label: input.label,
      price: input.price,
      unit: input.unit,
      quantityInThousandths: input.quantityInThousandths,
      baseMilliQuantity: baseMilliQuantity,
      normalizedPrice: Money.fromCents(
        CostBenefitComparisonCalculator._divideRounded(
          input.price.cents * normalizedQuantityInBaseMilli,
          baseMilliQuantity,
        ),
      ),
    );
  }

  final int sourceIndex;
  final String label;
  final Money price;
  final CostBenefitUnit unit;
  final int quantityInThousandths;
  final int baseMilliQuantity;
  final Money normalizedPrice;
}
