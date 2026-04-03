enum OrderFulfillmentMethod {
  delivery('delivery', 'Entrega'),
  pickup('pickup', 'Retirada');

  const OrderFulfillmentMethod(this.databaseValue, this.label);

  final String databaseValue;
  final String label;

  static OrderFulfillmentMethod fromDatabase(String value) {
    return values.firstWhere(
      (method) => method.databaseValue == value,
      orElse: () => pickup,
    );
  }
}
