import '../../../core/formatters/app_formatters.dart';

enum RecipeYieldUnit {
  portion(
    databaseValue: 'portion',
    label: 'Porção',
    singularLabel: 'porção',
    pluralLabel: 'porções',
    shortLabel: 'porção',
  ),
  unit(
    databaseValue: 'unit',
    label: 'Unidade',
    singularLabel: 'unidade',
    pluralLabel: 'unidades',
    shortLabel: 'un',
  ),
  gram(
    databaseValue: 'gram',
    label: 'Grama',
    singularLabel: 'g',
    pluralLabel: 'g',
    shortLabel: 'g',
  ),
  milliliter(
    databaseValue: 'milliliter',
    label: 'Mililitro',
    singularLabel: 'ml',
    pluralLabel: 'ml',
    shortLabel: 'ml',
  );

  const RecipeYieldUnit({
    required this.databaseValue,
    required this.label,
    required this.singularLabel,
    required this.pluralLabel,
    required this.shortLabel,
  });

  final String databaseValue;
  final String label;
  final String singularLabel;
  final String pluralLabel;
  final String shortLabel;

  String formatAmount(int amount) {
    final amountText = AppFormatters.wholeNumber(amount);
    final unitLabel = amount == 1 ? singularLabel : pluralLabel;
    return '$amountText $unitLabel';
  }

  String get costReferenceLabel => singularLabel;

  static RecipeYieldUnit fromDatabase(String value) {
    return values.firstWhere(
      (unit) => unit.databaseValue == value,
      orElse: () => RecipeYieldUnit.portion,
    );
  }
}
