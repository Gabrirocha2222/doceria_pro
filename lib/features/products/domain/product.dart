import '../../../core/money/money.dart';
import '../../../core/formatters/app_formatters.dart';
import 'product_option_type.dart';
import 'product_sale_mode.dart';
import 'product_type.dart';

class ProductOptionRecord {
  const ProductOptionRecord({
    required this.id,
    required this.productId,
    required this.type,
    required this.name,
    required this.isActive,
    required this.sortOrder,
  });

  final String id;
  final String productId;
  final ProductOptionType type;
  final String name;
  final bool isActive;
  final int sortOrder;
}

class ProductLinkedRecipeRecord {
  const ProductLinkedRecipeRecord({
    required this.recipeId,
    required this.recipeName,
    required this.recipeTypeLabel,
    required this.recipeYieldLabel,
  });

  final String recipeId;
  final String recipeName;
  final String recipeTypeLabel;
  final String recipeYieldLabel;
}

class ProductLinkedPackagingRecord {
  const ProductLinkedPackagingRecord({
    required this.packagingId,
    required this.packagingName,
    required this.packagingTypeLabel,
    required this.capacityDescription,
    required this.cost,
    required this.currentStockQuantity,
    required this.minimumStockQuantity,
    required this.isDefaultSuggested,
  });

  final String packagingId;
  final String packagingName;
  final String packagingTypeLabel;
  final String? capacityDescription;
  final Money cost;
  final int currentStockQuantity;
  final int minimumStockQuantity;
  final bool isDefaultSuggested;

  bool get isLowStock =>
      minimumStockQuantity > 0 && currentStockQuantity <= minimumStockQuantity;

  String get displayCapacityDescription {
    final trimmedCapacity = capacityDescription?.trim();
    if (trimmedCapacity == null || trimmedCapacity.isEmpty) {
      return 'Sem descrição registrada';
    }

    return trimmedCapacity;
  }

  String get displayStock =>
      '${AppFormatters.wholeNumber(currentStockQuantity)} un';
}

class ProductRecord {
  const ProductRecord({
    required this.id,
    required this.name,
    required this.category,
    required this.type,
    required this.saleMode,
    required this.basePrice,
    required this.notes,
    required this.yieldHint,
    required this.isActive,
    required this.createdAt,
    required this.updatedAt,
    required this.options,
    required this.linkedRecipes,
    required this.linkedPackagings,
  });

  final String id;
  final String name;
  final String? category;
  final ProductType type;
  final ProductSaleMode saleMode;
  final Money basePrice;
  final String? notes;
  final String? yieldHint;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;
  final List<ProductOptionRecord> options;
  final List<ProductLinkedRecipeRecord> linkedRecipes;
  final List<ProductLinkedPackagingRecord> linkedPackagings;

  List<ProductOptionRecord> get flavors => options
      .where((option) => option.type == ProductOptionType.flavor)
      .toList(growable: false);

  List<ProductOptionRecord> get variations => options
      .where((option) => option.type == ProductOptionType.variation)
      .toList(growable: false);

  String get displayCategory {
    final trimmedCategory = category?.trim();
    if (trimmedCategory == null || trimmedCategory.isEmpty) {
      return 'Sem categoria';
    }

    return trimmedCategory;
  }

  String get displayNotes {
    final trimmedNotes = notes?.trim();
    if (trimmedNotes == null || trimmedNotes.isEmpty) {
      return 'Sem observações registradas';
    }

    return trimmedNotes;
  }

  String get displayYieldHint {
    final trimmedHint = yieldHint?.trim();
    if (trimmedHint == null || trimmedHint.isEmpty) {
      return 'Sem referência registrada';
    }

    return trimmedHint;
  }

  String get priceLabel {
    switch (saleMode) {
      case ProductSaleMode.fixedPrice:
        return basePrice.format();
      case ProductSaleMode.startingAt:
        return 'A partir de ${basePrice.format()}';
      case ProductSaleMode.quoteOnly:
        return basePrice.isZero
            ? 'Sob orçamento'
            : 'Sob orçamento • base ${basePrice.format()}';
    }
  }

  ProductLinkedPackagingRecord? get defaultSuggestedPackaging {
    for (final packaging in linkedPackagings) {
      if (packaging.isDefaultSuggested) {
        return packaging;
      }
    }

    return null;
  }
}

class ProductOptionInput {
  const ProductOptionInput({
    required this.type,
    required this.name,
    this.isActive = true,
  });

  final ProductOptionType type;
  final String name;
  final bool isActive;
}

class ProductUpsertInput {
  const ProductUpsertInput({
    this.id,
    required this.name,
    required this.category,
    required this.type,
    required this.saleMode,
    required this.basePrice,
    required this.notes,
    required this.yieldHint,
    required this.isActive,
    required this.options,
    required this.linkedRecipeIds,
    required this.linkedPackagingIds,
    required this.defaultSuggestedPackagingId,
  });

  final String? id;
  final String name;
  final String? category;
  final ProductType type;
  final ProductSaleMode saleMode;
  final Money basePrice;
  final String? notes;
  final String? yieldHint;
  final bool isActive;
  final List<ProductOptionInput> options;
  final List<String> linkedRecipeIds;
  final List<String> linkedPackagingIds;
  final String? defaultSuggestedPackagingId;
}
