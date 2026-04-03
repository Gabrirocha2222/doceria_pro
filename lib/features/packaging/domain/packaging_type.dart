enum PackagingType {
  box(databaseValue: 'box', label: 'Caixa'),
  pot(databaseValue: 'pot', label: 'Pote'),
  bag(databaseValue: 'bag', label: 'Sacola'),
  tray(databaseValue: 'tray', label: 'Bandeja'),
  wrapper(databaseValue: 'wrapper', label: 'Envelope'),
  other(databaseValue: 'other', label: 'Outro');

  const PackagingType({required this.databaseValue, required this.label});

  final String databaseValue;
  final String label;

  static PackagingType fromDatabase(String value) {
    return values.firstWhere(
      (type) => type.databaseValue == value,
      orElse: () => PackagingType.other,
    );
  }
}
