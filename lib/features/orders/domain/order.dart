import '../../../core/money/money.dart';
import 'order_fulfillment_method.dart';
import 'order_status.dart';

enum OrderProductionPlanStatus {
  pending(databaseValue: 'pending', label: 'Pendente'),
  inProduction(databaseValue: 'in_production', label: 'Em produção'),
  completed(databaseValue: 'completed', label: 'Concluído');

  const OrderProductionPlanStatus({
    required this.databaseValue,
    required this.label,
  });

  final String databaseValue;
  final String label;

  static OrderProductionPlanStatus fromDatabase(String value) {
    return values.firstWhere(
      (status) => status.databaseValue == value,
      orElse: () => OrderProductionPlanStatus.pending,
    );
  }
}

enum OrderProductionPlanType {
  order(databaseValue: 'order', label: 'Pedido'),
  recipe(databaseValue: 'recipe', label: 'Receita'),
  packaging(databaseValue: 'packaging', label: 'Embalagem');

  const OrderProductionPlanType({
    required this.databaseValue,
    required this.label,
  });

  final String databaseValue;
  final String label;

  static OrderProductionPlanType fromDatabase(String value) {
    return values.firstWhere(
      (type) => type.databaseValue == value,
      orElse: () => OrderProductionPlanType.order,
    );
  }
}

enum OrderMaterialType {
  ingredient(databaseValue: 'ingredient', label: 'Ingrediente'),
  packaging(databaseValue: 'packaging', label: 'Embalagem');

  const OrderMaterialType({required this.databaseValue, required this.label});

  final String databaseValue;
  final String label;

  static OrderMaterialType fromDatabase(String value) {
    return values.firstWhere(
      (type) => type.databaseValue == value,
      orElse: () => OrderMaterialType.ingredient,
    );
  }
}

enum OrderReceivableStatus {
  pending(databaseValue: 'pending', label: 'Pendente'),
  received(databaseValue: 'received', label: 'Recebido');

  const OrderReceivableStatus({
    required this.databaseValue,
    required this.label,
  });

  final String databaseValue;
  final String label;

  static OrderReceivableStatus fromDatabase(String value) {
    return values.firstWhere(
      (status) => status.databaseValue == value,
      orElse: () => OrderReceivableStatus.pending,
    );
  }
}

class OrderItemRecord {
  const OrderItemRecord({
    required this.id,
    required this.orderId,
    required this.productId,
    required this.itemNameSnapshot,
    required this.flavorSnapshot,
    required this.variationSnapshot,
    required this.price,
    this.quantity = 1,
    required this.notes,
    required this.sortOrder,
  });

  final String id;
  final String orderId;
  final String? productId;
  final String itemNameSnapshot;
  final String? flavorSnapshot;
  final String? variationSnapshot;
  final Money price;
  final int quantity;
  final String? notes;
  final int sortOrder;

  String get displayName {
    final segments = [
      itemNameSnapshot,
      if (flavorSnapshot?.trim().isNotEmpty ?? false) flavorSnapshot!.trim(),
      if (variationSnapshot?.trim().isNotEmpty ?? false)
        variationSnapshot!.trim(),
    ];

    return segments.join(' • ');
  }

  String get displayQuantity => '${quantity <= 0 ? 1 : quantity}x';

  Money get lineTotal => price.multiply(quantity <= 0 ? 1 : quantity);
}

class OrderProductionPlanRecord {
  const OrderProductionPlanRecord({
    required this.id,
    required this.orderId,
    required this.title,
    required this.details,
    required this.planType,
    required this.recipeNameSnapshot,
    required this.itemNameSnapshot,
    this.quantity = 1,
    required this.notes,
    required this.status,
    required this.dueDate,
    required this.completedAt,
    required this.sortOrder,
    required this.createdAt,
  });

  final String id;
  final String orderId;
  final String title;
  final String? details;
  final OrderProductionPlanType planType;
  final String? recipeNameSnapshot;
  final String? itemNameSnapshot;
  final int quantity;
  final String? notes;
  final OrderProductionPlanStatus status;
  final DateTime? dueDate;
  final DateTime? completedAt;
  final int sortOrder;
  final DateTime createdAt;

  bool get isCompleted => status == OrderProductionPlanStatus.completed;

  String get displaySourceLabel {
    switch (planType) {
      case OrderProductionPlanType.order:
        final trimmedItem = itemNameSnapshot?.trim();
        return trimmedItem == null || trimmedItem.isEmpty
            ? 'Pedido'
            : trimmedItem;
      case OrderProductionPlanType.recipe:
        final trimmedRecipe = recipeNameSnapshot?.trim();
        return trimmedRecipe == null || trimmedRecipe.isEmpty
            ? 'Receita'
            : trimmedRecipe;
      case OrderProductionPlanType.packaging:
        return 'Separação de embalagem';
    }
  }

  String get displayDetails {
    final trimmedDetails = details?.trim();
    if (trimmedDetails == null || trimmedDetails.isEmpty) {
      return 'Sem detalhe adicional';
    }

    return trimmedDetails;
  }
}

class OrderMaterialNeedRecord {
  const OrderMaterialNeedRecord({
    required this.id,
    required this.orderId,
    required this.materialType,
    required this.linkedEntityId,
    required this.recipeNameSnapshot,
    required this.itemNameSnapshot,
    required this.nameSnapshot,
    required this.unitLabel,
    required this.requiredQuantity,
    required this.availableQuantity,
    required this.shortageQuantity,
    required this.note,
    required this.consumedAt,
    required this.consumedByPlanId,
    required this.sortOrder,
    required this.createdAt,
  });

  final String id;
  final String orderId;
  final OrderMaterialType materialType;
  final String? linkedEntityId;
  final String? recipeNameSnapshot;
  final String? itemNameSnapshot;
  final String nameSnapshot;
  final String unitLabel;
  final int requiredQuantity;
  final int availableQuantity;
  final int shortageQuantity;
  final String? note;
  final DateTime? consumedAt;
  final String? consumedByPlanId;
  final int sortOrder;
  final DateTime createdAt;

  bool get hasShortage => shortageQuantity > 0;

  bool get isConsumed => consumedAt != null;

  String get displayRequiredQuantity => '$requiredQuantity $unitLabel';

  String get displayAvailableQuantity => '$availableQuantity $unitLabel';

  String get displayShortageQuantity => '$shortageQuantity $unitLabel';

  String get displayNote {
    final trimmedNote = note?.trim();
    if (trimmedNote == null || trimmedNote.isEmpty) {
      return 'Sem observação adicional';
    }

    return trimmedNote;
  }
}

class OrderReceivableEntryRecord {
  const OrderReceivableEntryRecord({
    required this.id,
    required this.orderId,
    required this.description,
    required this.amount,
    required this.dueDate,
    required this.status,
    required this.createdAt,
  });

  final String id;
  final String orderId;
  final String description;
  final Money amount;
  final DateTime? dueDate;
  final OrderReceivableStatus status;
  final DateTime createdAt;
}

class OrderRecord {
  const OrderRecord({
    required this.id,
    this.clientId,
    required this.clientNameSnapshot,
    required this.eventDate,
    required this.fulfillmentMethod,
    required this.deliveryFee,
    this.referencePhotoPath,
    this.notes,
    this.estimatedCost = Money.zero,
    this.suggestedSalePrice = Money.zero,
    this.predictedProfit = Money.zero,
    this.suggestedPackagingId,
    this.suggestedPackagingNameSnapshot,
    this.smartReviewSummary,
    required this.orderTotal,
    required this.depositAmount,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
    this.items = const [],
    this.productionPlans = const [],
    this.materialNeeds = const [],
    this.receivableEntries = const [],
  });

  final String id;
  final String? clientId;
  final String? clientNameSnapshot;
  final DateTime? eventDate;
  final OrderFulfillmentMethod? fulfillmentMethod;
  final Money deliveryFee;
  final String? referencePhotoPath;
  final String? notes;
  final Money estimatedCost;
  final Money suggestedSalePrice;
  final Money predictedProfit;
  final String? suggestedPackagingId;
  final String? suggestedPackagingNameSnapshot;
  final String? smartReviewSummary;
  final Money orderTotal;
  final Money depositAmount;
  final OrderStatus status;
  final DateTime createdAt;
  final DateTime updatedAt;
  final List<OrderItemRecord> items;
  final List<OrderProductionPlanRecord> productionPlans;
  final List<OrderMaterialNeedRecord> materialNeeds;
  final List<OrderReceivableEntryRecord> receivableEntries;

  String get displayClientName {
    final trimmedName = clientNameSnapshot?.trim();
    if (trimmedName == null || trimmedName.isEmpty) {
      return 'Cliente não definida';
    }

    return trimmedName;
  }

  bool get hasClientName {
    final trimmedName = clientNameSnapshot?.trim();
    return trimmedName != null && trimmedName.isNotEmpty;
  }

  bool get isDraft =>
      !hasClientName ||
      eventDate == null ||
      fulfillmentMethod == null ||
      orderTotal.isZero;

  Money get itemsTotal {
    var total = Money.zero;
    for (final item in items) {
      total += item.lineTotal;
    }

    return total;
  }

  int get itemCount {
    var total = 0;
    for (final item in items) {
      total += item.quantity <= 0 ? 1 : item.quantity;
    }

    return total;
  }

  Money get receivedAmount {
    if (receivableEntries.isEmpty) {
      return depositAmount;
    }

    var total = Money.zero;
    for (final entry in receivableEntries) {
      if (entry.status == OrderReceivableStatus.received) {
        total += entry.amount;
      }
    }

    if (total.isZero && depositAmount.isPositive) {
      return depositAmount;
    }

    return total;
  }

  Money get remainingAmount {
    if (receivableEntries.isEmpty) {
      return orderTotal - receivedAmount;
    }

    var pendingTotal = Money.zero;
    for (final entry in receivableEntries) {
      if (entry.status == OrderReceivableStatus.pending) {
        pendingTotal += entry.amount;
      }
    }

    return pendingTotal;
  }

  String get depositStateLabel {
    if (receivedAmount.isZero) {
      return 'Sem sinal';
    }
    if (orderTotal.isPositive && receivedAmount.cents >= orderTotal.cents) {
      return 'Sinal coberto';
    }

    return 'Sinal parcial';
  }

  bool get hasSmartSummary =>
      estimatedCost.isPositive ||
      suggestedSalePrice.isPositive ||
      predictedProfit.isPositive ||
      (smartReviewSummary?.trim().isNotEmpty ?? false);

  String get displaySuggestedPackagingName {
    final trimmedName = suggestedPackagingNameSnapshot?.trim();
    if (trimmedName == null || trimmedName.isEmpty) {
      return 'Sem sugestão automática';
    }

    return trimmedName;
  }

  String get displaySmartReviewSummary {
    final trimmedSummary = smartReviewSummary?.trim();
    if (trimmedSummary == null || trimmedSummary.isEmpty) {
      return 'Sem observações automáticas registradas.';
    }

    return trimmedSummary;
  }

  String get displayReferencePhotoPath {
    final trimmedPath = referencePhotoPath?.trim();
    if (trimmedPath == null || trimmedPath.isEmpty) {
      return 'Nenhuma foto de referência adicionada';
    }

    return trimmedPath;
  }
}

class OrderItemInput {
  const OrderItemInput({
    this.id,
    required this.productId,
    required this.itemNameSnapshot,
    required this.flavorSnapshot,
    required this.variationSnapshot,
    required this.price,
    this.quantity = 1,
    required this.notes,
  });

  final String? id;
  final String? productId;
  final String itemNameSnapshot;
  final String? flavorSnapshot;
  final String? variationSnapshot;
  final Money price;
  final int quantity;
  final String? notes;
}

class OrderProductionPlanInput {
  const OrderProductionPlanInput({
    this.id,
    required this.title,
    required this.details,
    this.planType = OrderProductionPlanType.order,
    this.recipeNameSnapshot,
    this.itemNameSnapshot,
    this.quantity = 1,
    this.notes,
    required this.status,
    required this.dueDate,
    this.completedAt,
    required this.sortOrder,
  });

  final String? id;
  final String title;
  final String? details;
  final OrderProductionPlanType planType;
  final String? recipeNameSnapshot;
  final String? itemNameSnapshot;
  final int quantity;
  final String? notes;
  final OrderProductionPlanStatus status;
  final DateTime? dueDate;
  final DateTime? completedAt;
  final int sortOrder;
}

class OrderMaterialNeedInput {
  const OrderMaterialNeedInput({
    this.id,
    required this.materialType,
    required this.linkedEntityId,
    this.recipeNameSnapshot,
    this.itemNameSnapshot,
    required this.nameSnapshot,
    required this.unitLabel,
    required this.requiredQuantity,
    required this.availableQuantity,
    required this.shortageQuantity,
    required this.note,
    this.consumedAt,
    this.consumedByPlanId,
    required this.sortOrder,
  });

  final String? id;
  final OrderMaterialType materialType;
  final String? linkedEntityId;
  final String? recipeNameSnapshot;
  final String? itemNameSnapshot;
  final String nameSnapshot;
  final String unitLabel;
  final int requiredQuantity;
  final int availableQuantity;
  final int shortageQuantity;
  final String? note;
  final DateTime? consumedAt;
  final String? consumedByPlanId;
  final int sortOrder;
}

class OrderReceivableEntryInput {
  const OrderReceivableEntryInput({
    this.id,
    required this.description,
    required this.amount,
    required this.dueDate,
    required this.status,
  });

  final String? id;
  final String description;
  final Money amount;
  final DateTime? dueDate;
  final OrderReceivableStatus status;
}

class OrderUpsertInput {
  const OrderUpsertInput({
    this.id,
    this.clientId,
    required this.clientNameSnapshot,
    required this.eventDate,
    required this.fulfillmentMethod,
    required this.deliveryFee,
    this.referencePhotoPath,
    this.notes,
    this.estimatedCost = Money.zero,
    this.suggestedSalePrice = Money.zero,
    this.predictedProfit = Money.zero,
    this.suggestedPackagingId,
    this.suggestedPackagingNameSnapshot,
    this.smartReviewSummary,
    required this.orderTotal,
    required this.depositAmount,
    required this.status,
    this.items = const [],
    this.productionPlans = const [],
    this.materialNeeds = const [],
    this.receivableEntries = const [],
  });

  final String? id;
  final String? clientId;
  final String? clientNameSnapshot;
  final DateTime? eventDate;
  final OrderFulfillmentMethod? fulfillmentMethod;
  final Money deliveryFee;
  final String? referencePhotoPath;
  final String? notes;
  final Money estimatedCost;
  final Money suggestedSalePrice;
  final Money predictedProfit;
  final String? suggestedPackagingId;
  final String? suggestedPackagingNameSnapshot;
  final String? smartReviewSummary;
  final Money orderTotal;
  final Money depositAmount;
  final OrderStatus status;
  final List<OrderItemInput> items;
  final List<OrderProductionPlanInput> productionPlans;
  final List<OrderMaterialNeedInput> materialNeeds;
  final List<OrderReceivableEntryInput> receivableEntries;
}
