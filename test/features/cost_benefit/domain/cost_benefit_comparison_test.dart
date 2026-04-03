import 'package:doceria_pro/core/money/money.dart';
import 'package:doceria_pro/features/cost_benefit/domain/cost_benefit_comparison.dart';
import 'package:doceria_pro/features/cost_benefit/domain/cost_benefit_unit.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('compares weight options safely across g and kg', () {
    final result = CostBenefitComparisonCalculator.compare([
      CostBenefitOptionInput(
        label: 'Pacote 500 g',
        price: Money.fromCents(1690),
        quantityInThousandths: 500000,
        unit: CostBenefitUnit.gram,
      ),
      CostBenefitOptionInput(
        label: 'Pacote 1 kg',
        price: Money.fromCents(2980),
        quantityInThousandths: 1000,
        unit: CostBenefitUnit.kilogram,
      ),
      CostBenefitOptionInput(
        label: 'Pacote 250 g',
        price: Money.fromCents(920),
        quantityInThousandths: 250000,
        unit: CostBenefitUnit.gram,
      ),
    ]);

    expect(result.summary.bestOption.label, 'Pacote 1 kg');
    expect(result.summary.bestOption.normalizedPrice, Money.fromCents(2980));
    expect(result.summary.savingsAgainstNextBest, Money.fromCents(400));
    expect(result.summary.savingsAgainstNextBestInTenthsPercent, 134);
    expect(result.rankedOptions.first.isBestValue, isTrue);
    expect(
      result.rankedOptions.last.estimatedSavingsForSameQuantity,
      Money.fromCents(175),
    );
  });

  test('compares volume options using liter as normalized reference', () {
    final result = CostBenefitComparisonCalculator.compare([
      CostBenefitOptionInput(
        label: 'Garrafa 900 ml',
        price: Money.fromCents(1180),
        quantityInThousandths: 900000,
        unit: CostBenefitUnit.milliliter,
      ),
      CostBenefitOptionInput(
        label: 'Garrafa 1,5 L',
        price: Money.fromCents(1740),
        quantityInThousandths: 1500,
        unit: CostBenefitUnit.liter,
      ),
    ]);

    expect(result.summary.normalizedUnitLabel, 'L');
    expect(result.summary.bestOption.label, 'Garrafa 1,5 L');
    expect(result.summary.bestOption.normalizedPrice, Money.fromCents(1160));
    expect(result.rankedOptions.last.differenceFromBestInTenthsPercent, 130);
  });

  test('flags tied best options when cost-benefit is the same', () {
    final result = CostBenefitComparisonCalculator.compare([
      CostBenefitOptionInput(
        label: '6 unidades',
        price: Money.fromCents(900),
        quantityInThousandths: 6000,
        unit: CostBenefitUnit.unit,
      ),
      CostBenefitOptionInput(
        label: '12 unidades',
        price: Money.fromCents(1800),
        quantityInThousandths: 12000,
        unit: CostBenefitUnit.unit,
      ),
      CostBenefitOptionInput(
        label: '10 unidades',
        price: Money.fromCents(1700),
        quantityInThousandths: 10000,
        unit: CostBenefitUnit.unit,
      ),
    ]);

    expect(result.summary.hasTieForBestValue, isTrue);
    expect(result.summary.tiedBestOptionCount, 2);
    expect(result.summary.savingsAgainstNextBest, Money.fromCents(20));
    expect(result.rankedOptions[0].isTiedBestValue, isTrue);
    expect(result.rankedOptions[1].isTiedBestValue, isTrue);
    expect(result.rankedOptions[2].differenceFromBestInTenthsPercent, 133);
  });
}
