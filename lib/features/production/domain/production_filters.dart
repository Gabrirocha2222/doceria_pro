enum ProductionTimeframe {
  today('today', 'Hoje'),
  week('week', 'Semana');

  const ProductionTimeframe(this.databaseValue, this.label);

  final String databaseValue;
  final String label;
}

enum ProductionGrouping {
  order('order', 'Pedido'),
  recipe('recipe', 'Receita'),
  item('item', 'Item');

  const ProductionGrouping(this.databaseValue, this.label);

  final String databaseValue;
  final String label;
}

class ProductionFilters {
  const ProductionFilters({
    this.timeframe = ProductionTimeframe.today,
    this.grouping = ProductionGrouping.order,
  });

  final ProductionTimeframe timeframe;
  final ProductionGrouping grouping;

  ProductionFilters copyWith({
    ProductionTimeframe? timeframe,
    ProductionGrouping? grouping,
  }) {
    return ProductionFilters(
      timeframe: timeframe ?? this.timeframe,
      grouping: grouping ?? this.grouping,
    );
  }
}
