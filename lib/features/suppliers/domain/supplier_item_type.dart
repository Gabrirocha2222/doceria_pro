enum SupplierItemType {
  ingredient(databaseValue: 'ingredient', label: 'Ingrediente'),
  packaging(databaseValue: 'packaging', label: 'Embalagem');

  const SupplierItemType({required this.databaseValue, required this.label});

  final String databaseValue;
  final String label;

  static SupplierItemType fromDatabase(String value) {
    return SupplierItemType.values.firstWhere(
      (itemType) => itemType.databaseValue == value,
      orElse: () => SupplierItemType.ingredient,
    );
  }
}
