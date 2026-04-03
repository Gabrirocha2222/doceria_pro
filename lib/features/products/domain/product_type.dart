enum ProductType {
  simple('simple', 'Simples'),
  perUnit('per_unit', 'Por unidade'),
  perWeight('per_weight', 'Por peso'),
  kit('kit', 'Kit'),
  monthlyPlan('monthly_plan', 'Plano mensal'),
  outsourced('outsourced', 'Terceirizado');

  const ProductType(this.databaseValue, this.label);

  final String databaseValue;
  final String label;

  static ProductType fromDatabase(String value) {
    return values.firstWhere(
      (productType) => productType.databaseValue == value,
      orElse: () => simple,
    );
  }
}
