import '../../../core/formatters/app_formatters.dart';
import '../../../core/money/money.dart';
import 'ingredient_unit.dart';

class IngredientLinkedSupplierRecord {
  const IngredientLinkedSupplierRecord({
    required this.supplierId,
    required this.supplierName,
    required this.contact,
    required this.leadTimeDays,
    required this.isDefaultPreferred,
    required this.lastKnownPrice,
    required this.lastKnownPriceUnitLabel,
    required this.lastKnownPriceAt,
  });

  final String supplierId;
  final String supplierName;
  final String? contact;
  final int? leadTimeDays;
  final bool isDefaultPreferred;
  final Money? lastKnownPrice;
  final String? lastKnownPriceUnitLabel;
  final DateTime? lastKnownPriceAt;

  String get displayContact {
    final trimmedContact = contact?.trim();
    if (trimmedContact == null || trimmedContact.isEmpty) {
      return 'Sem contato registrado';
    }

    return trimmedContact;
  }

  String get displayLeadTime {
    if (leadTimeDays == null || leadTimeDays! <= 0) {
      return 'Prazo não definido';
    }

    return '${AppFormatters.wholeNumber(leadTimeDays!)} ${leadTimeDays == 1 ? 'dia' : 'dias'}';
  }

  String get displayLastKnownPrice {
    if (lastKnownPrice == null) {
      return 'Sem preço registrado';
    }

    final trimmedUnit = lastKnownPriceUnitLabel?.trim();
    if (trimmedUnit == null || trimmedUnit.isEmpty) {
      return lastKnownPrice!.format();
    }

    return '${lastKnownPrice!.format()} / $trimmedUnit';
  }
}

class IngredientRecord {
  const IngredientRecord({
    required this.id,
    required this.name,
    required this.category,
    required this.purchaseUnit,
    required this.stockUnit,
    required this.currentStockQuantity,
    required this.minimumStockQuantity,
    required this.unitCost,
    required this.defaultSupplier,
    required this.conversionFactor,
    required this.notes,
    required this.createdAt,
    required this.updatedAt,
    this.linkedSuppliers = const [],
  });

  final String id;
  final String name;
  final String? category;
  final IngredientUnit purchaseUnit;
  final IngredientUnit stockUnit;
  final int currentStockQuantity;
  final int minimumStockQuantity;
  final Money unitCost;
  final String? defaultSupplier;
  final int conversionFactor;
  final String? notes;
  final DateTime createdAt;
  final DateTime updatedAt;
  final List<IngredientLinkedSupplierRecord> linkedSuppliers;

  bool get hasMinimumConfigured => minimumStockQuantity > 0;

  bool get hasSupplierReference =>
      linkedSuppliers.isNotEmpty || defaultSupplier?.trim().isNotEmpty == true;

  IngredientLinkedSupplierRecord? get preferredSupplier {
    for (final supplier in linkedSuppliers) {
      if (supplier.isDefaultPreferred) {
        return supplier;
      }
    }

    if (linkedSuppliers.isEmpty) {
      return null;
    }

    return linkedSuppliers.first;
  }

  List<IngredientLinkedSupplierRecord> get alternativeSuppliers =>
      linkedSuppliers
          .where(
            (supplier) => supplier.supplierId != preferredSupplier?.supplierId,
          )
          .toList(growable: false);

  bool get isLowStock =>
      hasMinimumConfigured && currentStockQuantity <= minimumStockQuantity;

  String get displayCategory {
    final trimmedCategory = category?.trim();
    if (trimmedCategory == null || trimmedCategory.isEmpty) {
      return 'Sem categoria';
    }

    return trimmedCategory;
  }

  String get displaySupplier {
    final preferredSupplierName = preferredSupplier?.supplierName.trim();
    if (preferredSupplierName != null && preferredSupplierName.isNotEmpty) {
      return preferredSupplierName;
    }

    final trimmedSupplier = defaultSupplier?.trim();
    if (trimmedSupplier == null || trimmedSupplier.isEmpty) {
      return 'Sem fornecedora definida';
    }

    return trimmedSupplier;
  }

  String get displayNotes {
    final trimmedNotes = notes?.trim();
    if (trimmedNotes == null || trimmedNotes.isEmpty) {
      return 'Sem observações registradas';
    }

    return trimmedNotes;
  }

  String get displayCurrentStock =>
      stockUnit.formatQuantity(currentStockQuantity);

  String get displayMinimumStock => hasMinimumConfigured
      ? stockUnit.formatQuantity(minimumStockQuantity)
      : 'Sem mínimo definido';

  String get displayUnitCost =>
      '${unitCost.format()} / ${purchaseUnit.shortLabel}';

  String get conversionSummary =>
      '1 ${purchaseUnit.shortLabel} = ${AppFormatters.wholeNumber(conversionFactor)} ${stockUnit.shortLabel}';

  String get alertLabel => isLowStock ? 'Estoque baixo' : 'Estoque ok';
}

class IngredientUpsertInput {
  const IngredientUpsertInput({
    this.id,
    required this.name,
    required this.category,
    required this.purchaseUnit,
    required this.stockUnit,
    required this.currentStockQuantity,
    required this.minimumStockQuantity,
    required this.unitCost,
    required this.defaultSupplier,
    required this.conversionFactor,
    required this.notes,
    this.preferredSupplierId,
    this.linkedSupplierIds = const [],
  });

  final String? id;
  final String name;
  final String? category;
  final IngredientUnit purchaseUnit;
  final IngredientUnit stockUnit;
  final int currentStockQuantity;
  final int minimumStockQuantity;
  final Money unitCost;
  final String? defaultSupplier;
  final int conversionFactor;
  final String? notes;
  final String? preferredSupplierId;
  final List<String> linkedSupplierIds;
}
