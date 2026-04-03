enum RecipeType {
  dough(databaseValue: 'dough', label: 'Massa'),
  filling(databaseValue: 'filling', label: 'Recheio'),
  topping(databaseValue: 'topping', label: 'Cobertura'),
  base(databaseValue: 'base', label: 'Base'),
  complete(databaseValue: 'complete', label: 'Receita completa');

  const RecipeType({required this.databaseValue, required this.label});

  final String databaseValue;
  final String label;

  static RecipeType fromDatabase(String value) {
    return values.firstWhere(
      (type) => type.databaseValue == value,
      orElse: () => RecipeType.complete,
    );
  }
}
