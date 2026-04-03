enum CostBenefitUnitFamily { weight, volume, count }

enum CostBenefitUnit {
  gram(
    label: 'Grama',
    shortLabel: 'g',
    family: CostBenefitUnitFamily.weight,
    thousandthsToBaseMilliFactor: 1,
  ),
  kilogram(
    label: 'Quilo',
    shortLabel: 'kg',
    family: CostBenefitUnitFamily.weight,
    thousandthsToBaseMilliFactor: 1000,
  ),
  milliliter(
    label: 'Mililitro',
    shortLabel: 'ml',
    family: CostBenefitUnitFamily.volume,
    thousandthsToBaseMilliFactor: 1,
  ),
  liter(
    label: 'Litro',
    shortLabel: 'L',
    family: CostBenefitUnitFamily.volume,
    thousandthsToBaseMilliFactor: 1000,
  ),
  unit(
    label: 'Unidade',
    shortLabel: 'un',
    family: CostBenefitUnitFamily.count,
    thousandthsToBaseMilliFactor: 1,
  );

  const CostBenefitUnit({
    required this.label,
    required this.shortLabel,
    required this.family,
    required this.thousandthsToBaseMilliFactor,
  });

  final String label;
  final String shortLabel;
  final CostBenefitUnitFamily family;

  // Quantity is kept in thousandths to support values such as 1,5 kg safely.
  final int thousandthsToBaseMilliFactor;

  int toBaseMilliUnits(int quantityInThousandths) {
    return quantityInThousandths * thousandthsToBaseMilliFactor;
  }

  String get normalizedUnitLabel {
    return switch (family) {
      CostBenefitUnitFamily.weight => 'kg',
      CostBenefitUnitFamily.volume => 'L',
      CostBenefitUnitFamily.count => 'un',
    };
  }

  int get normalizedBaseUnits {
    return switch (family) {
      CostBenefitUnitFamily.weight || CostBenefitUnitFamily.volume => 1000,
      CostBenefitUnitFamily.count => 1,
    };
  }

  static List<CostBenefitUnit> valuesForFamily(CostBenefitUnitFamily family) {
    return values
        .where((unit) => unit.family == family)
        .toList(growable: false);
  }

  static CostBenefitUnit defaultForFamily(CostBenefitUnitFamily family) {
    return valuesForFamily(family).first;
  }
}
