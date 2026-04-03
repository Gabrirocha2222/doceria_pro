enum ProductOptionType {
  flavor('flavor', 'Sabor'),
  variation('variation', 'Variação');

  const ProductOptionType(this.databaseValue, this.label);

  final String databaseValue;
  final String label;

  static ProductOptionType fromDatabase(String value) {
    return values.firstWhere(
      (optionType) => optionType.databaseValue == value,
      orElse: () => variation,
    );
  }
}
