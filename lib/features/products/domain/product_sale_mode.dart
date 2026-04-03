enum ProductSaleMode {
  fixedPrice('fixed_price', 'Preço fechado'),
  startingAt('starting_at', 'A partir de'),
  quoteOnly('quote_only', 'Sob orçamento');

  const ProductSaleMode(this.databaseValue, this.label);

  final String databaseValue;
  final String label;

  static ProductSaleMode fromDatabase(String value) {
    return values.firstWhere(
      (saleMode) => saleMode.databaseValue == value,
      orElse: () => fixedPrice,
    );
  }
}
