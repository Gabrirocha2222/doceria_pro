enum OrderStatus {
  budget('budget', 'Orçamento'),
  awaitingDeposit('awaiting_deposit', 'Aguardando sinal'),
  confirmed('confirmed', 'Confirmado'),
  inProduction('in_production', 'Em produção'),
  ready('ready', 'Pronto'),
  delivered('delivered', 'Entregue');

  const OrderStatus(this.databaseValue, this.label);

  final String databaseValue;
  final String label;

  static OrderStatus fromDatabase(String value) {
    return values.firstWhere(
      (status) => status.databaseValue == value,
      orElse: () => budget,
    );
  }
}
