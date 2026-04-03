import '../../../core/formatters/app_formatters.dart';
import '../../../core/money/money.dart';
import 'packaging_type.dart';

class PackagingLinkedProductRecord {
  const PackagingLinkedProductRecord({
    required this.productId,
    required this.productName,
    required this.isDefaultSuggested,
  });

  final String productId;
  final String productName;
  final bool isDefaultSuggested;
}

class PackagingRecord {
  const PackagingRecord({
    required this.id,
    required this.name,
    required this.type,
    required this.cost,
    required this.currentStockQuantity,
    required this.minimumStockQuantity,
    required this.capacityDescription,
    required this.notes,
    required this.isActive,
    required this.createdAt,
    required this.updatedAt,
    required this.linkedProducts,
  });

  final String id;
  final String name;
  final PackagingType type;
  final Money cost;
  final int currentStockQuantity;
  final int minimumStockQuantity;
  final String? capacityDescription;
  final String? notes;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;
  final List<PackagingLinkedProductRecord> linkedProducts;

  bool get hasMinimumConfigured => minimumStockQuantity > 0;

  bool get isLowStock =>
      hasMinimumConfigured && currentStockQuantity <= minimumStockQuantity;

  String get displayCost => cost.format();

  String get displayStock =>
      '${AppFormatters.wholeNumber(currentStockQuantity)} un';

  String get displayMinimumStock => hasMinimumConfigured
      ? '${AppFormatters.wholeNumber(minimumStockQuantity)} un'
      : 'Sem mínimo definido';

  String get displayCapacityDescription {
    final trimmedCapacity = capacityDescription?.trim();
    if (trimmedCapacity == null || trimmedCapacity.isEmpty) {
      return 'Sem descrição registrada';
    }

    return trimmedCapacity;
  }

  String get displayNotes {
    final trimmedNotes = notes?.trim();
    if (trimmedNotes == null || trimmedNotes.isEmpty) {
      return 'Sem observações registradas';
    }

    return trimmedNotes;
  }

  String get usageLabel => linkedProducts.isEmpty
      ? 'Ainda sem produto compatível'
      : '${linkedProducts.length} ${linkedProducts.length == 1 ? 'produto compatível' : 'produtos compatíveis'}';
}

class PackagingUpsertInput {
  const PackagingUpsertInput({
    this.id,
    required this.name,
    required this.type,
    required this.cost,
    required this.currentStockQuantity,
    required this.minimumStockQuantity,
    required this.capacityDescription,
    required this.notes,
    required this.isActive,
  });

  final String? id;
  final String name;
  final PackagingType type;
  final Money cost;
  final int currentStockQuantity;
  final int minimumStockQuantity;
  final String? capacityDescription;
  final String? notes;
  final bool isActive;
}
