import '../../../core/formatters/app_formatters.dart';
import '../../../core/money/money.dart';
import 'supplier_item_type.dart';

class SupplierLinkedIngredientRecord {
  const SupplierLinkedIngredientRecord({
    required this.ingredientId,
    required this.ingredientName,
    required this.ingredientCategory,
    required this.isDefaultPreferred,
    required this.lastKnownPrice,
    required this.lastKnownPriceUnitLabel,
  });

  final String ingredientId;
  final String ingredientName;
  final String? ingredientCategory;
  final bool isDefaultPreferred;
  final Money? lastKnownPrice;
  final String? lastKnownPriceUnitLabel;

  String get displayCategory {
    final trimmedCategory = ingredientCategory?.trim();
    if (trimmedCategory == null || trimmedCategory.isEmpty) {
      return 'Sem categoria';
    }

    return trimmedCategory;
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

class SupplierPriceRecord {
  const SupplierPriceRecord({
    required this.id,
    required this.supplierId,
    required this.itemType,
    required this.linkedItemId,
    required this.itemNameSnapshot,
    required this.unitLabelSnapshot,
    required this.price,
    required this.notes,
    required this.createdAt,
  });

  final String id;
  final String supplierId;
  final SupplierItemType itemType;
  final String linkedItemId;
  final String itemNameSnapshot;
  final String? unitLabelSnapshot;
  final Money price;
  final String? notes;
  final DateTime createdAt;

  String get displayPrice {
    final trimmedUnit = unitLabelSnapshot?.trim();
    if (trimmedUnit == null || trimmedUnit.isEmpty) {
      return price.format();
    }

    return '${price.format()} / $trimmedUnit';
  }

  String get displayNotes {
    final trimmedNotes = notes?.trim();
    if (trimmedNotes == null || trimmedNotes.isEmpty) {
      return 'Sem observações';
    }

    return trimmedNotes;
  }

  String get displayCreatedAt => AppFormatters.dayMonthYear(createdAt);
}

class SupplierRecord {
  const SupplierRecord({
    required this.id,
    required this.name,
    required this.contact,
    required this.notes,
    required this.leadTimeDays,
    required this.isActive,
    required this.createdAt,
    required this.updatedAt,
    required this.linkedIngredients,
    required this.priceHistory,
  });

  final String id;
  final String name;
  final String? contact;
  final String? notes;
  final int? leadTimeDays;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;
  final List<SupplierLinkedIngredientRecord> linkedIngredients;
  final List<SupplierPriceRecord> priceHistory;

  SupplierPriceRecord? get latestPrice =>
      priceHistory.isEmpty ? null : priceHistory.first;

  String get displayContact {
    final trimmedContact = contact?.trim();
    if (trimmedContact == null || trimmedContact.isEmpty) {
      return 'Sem contato registrado';
    }

    return trimmedContact;
  }

  String get displayNotes {
    final trimmedNotes = notes?.trim();
    if (trimmedNotes == null || trimmedNotes.isEmpty) {
      return 'Sem observações registradas';
    }

    return trimmedNotes;
  }

  String get displayLeadTime {
    if (leadTimeDays == null || leadTimeDays! <= 0) {
      return 'Prazo não definido';
    }

    return '${AppFormatters.wholeNumber(leadTimeDays!)} ${leadTimeDays == 1 ? 'dia' : 'dias'}';
  }

  String get linkedIngredientsSummary {
    if (linkedIngredients.isEmpty) {
      return 'Nenhum ingrediente ligado ainda';
    }

    return '${linkedIngredients.length} ${linkedIngredients.length == 1 ? 'ingrediente ligado' : 'ingredientes ligados'}';
  }

  String get latestPriceSummary {
    final latest = latestPrice;
    if (latest == null) {
      return 'Sem preço registrado ainda';
    }

    return '${latest.itemNameSnapshot} • ${latest.displayPrice}';
  }
}

class SupplierUpsertInput {
  const SupplierUpsertInput({
    this.id,
    required this.name,
    required this.contact,
    required this.notes,
    required this.leadTimeDays,
    required this.isActive,
  });

  final String? id;
  final String name;
  final String? contact;
  final String? notes;
  final int? leadTimeDays;
  final bool isActive;
}

class SupplierPriceUpsertInput {
  const SupplierPriceUpsertInput({
    this.id,
    required this.supplierId,
    required this.itemType,
    required this.linkedItemId,
    required this.itemNameSnapshot,
    required this.unitLabelSnapshot,
    required this.price,
    required this.notes,
  });

  final String? id;
  final String supplierId;
  final SupplierItemType itemType;
  final String linkedItemId;
  final String itemNameSnapshot;
  final String? unitLabelSnapshot;
  final Money price;
  final String? notes;
}
