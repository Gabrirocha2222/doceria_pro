import '../../../core/formatters/app_formatters.dart';
import '../../../core/money/money.dart';
import '../../ingredients/domain/ingredient.dart';
import '../../orders/domain/order.dart';
import '../../packaging/domain/packaging.dart';
import '../../suppliers/domain/supplier.dart';
import '../../suppliers/domain/supplier_item_type.dart';

enum PurchaseListView {
  buyNow(label: 'Comprar agora'),
  thisWeek(label: 'Esta semana'),
  bySupplier(label: 'Por fornecedora');

  const PurchaseListView({required this.label});

  final String label;
}

enum PurchaseExpenseDraftStatus {
  prepared(databaseValue: 'prepared', label: 'Preparado'),
  paid(databaseValue: 'paid', label: 'Pago');

  const PurchaseExpenseDraftStatus({
    required this.databaseValue,
    required this.label,
  });

  final String databaseValue;
  final String label;

  static PurchaseExpenseDraftStatus fromDatabase(String value) {
    return PurchaseExpenseDraftStatus.values.firstWhere(
      (status) => status.databaseValue == value,
      orElse: () => PurchaseExpenseDraftStatus.prepared,
    );
  }
}

class PurchaseProjectedNeedRecord {
  const PurchaseProjectedNeedRecord({
    required this.orderId,
    required this.clientNameSnapshot,
    required this.orderDate,
    required this.materialType,
    required this.linkedEntityId,
    required this.recipeNameSnapshot,
    required this.itemNameSnapshot,
    required this.nameSnapshot,
    required this.unitLabel,
    required this.requiredQuantity,
    required this.shortageQuantity,
    required this.note,
  });

  final String orderId;
  final String? clientNameSnapshot;
  final DateTime? orderDate;
  final OrderMaterialType materialType;
  final String? linkedEntityId;
  final String? recipeNameSnapshot;
  final String? itemNameSnapshot;
  final String nameSnapshot;
  final String unitLabel;
  final int requiredQuantity;
  final int shortageQuantity;
  final String? note;

  bool isDueBy(DateTime date) {
    if (orderDate == null) {
      return true;
    }

    final normalizedOrderDate = DateTime(
      orderDate!.year,
      orderDate!.month,
      orderDate!.day,
    );
    final normalizedDate = DateTime(date.year, date.month, date.day);

    return !normalizedOrderDate.isAfter(normalizedDate);
  }
}

class PurchaseSuggestedSupplier {
  const PurchaseSuggestedSupplier({
    required this.supplierId,
    required this.supplierName,
    required this.contact,
    required this.leadTimeDays,
    required this.lastKnownUnitPrice,
    required this.priceUnitLabel,
    required this.lastKnownPriceAt,
  });

  final String? supplierId;
  final String supplierName;
  final String? contact;
  final int? leadTimeDays;
  final Money? lastKnownUnitPrice;
  final String? priceUnitLabel;
  final DateTime? lastKnownPriceAt;

  String get displayLeadTime {
    if (leadTimeDays == null || leadTimeDays! <= 0) {
      return 'Prazo não definido';
    }

    return '${AppFormatters.wholeNumber(leadTimeDays!)} ${leadTimeDays == 1 ? 'dia' : 'dias'}';
  }

  String get displayLastKnownPrice {
    if (lastKnownUnitPrice == null) {
      return 'Sem preço recente';
    }

    final trimmedUnitLabel = priceUnitLabel?.trim();
    if (trimmedUnitLabel == null || trimmedUnitLabel.isEmpty) {
      return lastKnownUnitPrice!.format();
    }

    return '${lastKnownUnitPrice!.format()} / $trimmedUnitLabel';
  }
}

class PurchaseOrderReference {
  const PurchaseOrderReference({
    required this.orderId,
    required this.clientNameSnapshot,
    required this.orderDate,
    required this.recipeNameSnapshot,
    required this.itemNameSnapshot,
  });

  final String orderId;
  final String clientNameSnapshot;
  final DateTime? orderDate;
  final String? recipeNameSnapshot;
  final String? itemNameSnapshot;

  String get displayClientName {
    final trimmedName = clientNameSnapshot.trim();
    if (trimmedName.isEmpty) {
      return 'Cliente não definida';
    }

    return trimmedName;
  }

  String get displayDeadline {
    if (orderDate == null) {
      return 'Sem data';
    }

    return AppFormatters.dayMonthYear(orderDate!);
  }
}

class PurchaseChecklistItemRecord {
  const PurchaseChecklistItemRecord({
    required this.materialType,
    required this.linkedEntityId,
    required this.nameSnapshot,
    required this.categoryLabel,
    required this.stockUnitLabel,
    required this.purchaseUnitLabel,
    required this.stockUnitsPerPurchaseUnit,
    required this.currentStockQuantity,
    required this.minimumStockQuantity,
    required this.buyNowDemandQuantity,
    required this.thisWeekDemandQuantity,
    required this.buyNowShortageQuantity,
    required this.thisWeekShortageQuantity,
    required this.suggestedSupplier,
    required this.relatedOrders,
    required this.note,
    required this.usesDynamicStockRule,
  });

  final OrderMaterialType materialType;
  final String? linkedEntityId;
  final String nameSnapshot;
  final String categoryLabel;
  final String stockUnitLabel;
  final String purchaseUnitLabel;
  final int stockUnitsPerPurchaseUnit;
  final int currentStockQuantity;
  final int minimumStockQuantity;
  final int buyNowDemandQuantity;
  final int thisWeekDemandQuantity;
  final int buyNowShortageQuantity;
  final int thisWeekShortageQuantity;
  final PurchaseSuggestedSupplier? suggestedSupplier;
  final List<PurchaseOrderReference> relatedOrders;
  final String? note;
  final bool usesDynamicStockRule;

  bool get hasSuggestedSupplier => suggestedSupplier != null;

  bool get hasMinimumConfigured => minimumStockQuantity > 0;

  bool get hasNotes => note?.trim().isNotEmpty ?? false;

  bool get isIngredient => materialType == OrderMaterialType.ingredient;

  bool get isPackaging => materialType == OrderMaterialType.packaging;

  bool get hasStockLink => linkedEntityId?.trim().isNotEmpty ?? false;

  int get minimumGapQuantity {
    if (!hasMinimumConfigured || currentStockQuantity >= minimumStockQuantity) {
      return 0;
    }

    return minimumStockQuantity - currentStockQuantity;
  }

  int shortageQuantityFor(PurchaseListView view) {
    return switch (_normalizeView(view)) {
      PurchaseListView.buyNow => buyNowShortageQuantity,
      PurchaseListView.thisWeek => thisWeekShortageQuantity,
      PurchaseListView.bySupplier => thisWeekShortageQuantity,
    };
  }

  int demandQuantityFor(PurchaseListView view) {
    return switch (_normalizeView(view)) {
      PurchaseListView.buyNow => buyNowDemandQuantity,
      PurchaseListView.thisWeek => thisWeekDemandQuantity,
      PurchaseListView.bySupplier => thisWeekDemandQuantity,
    };
  }

  int suggestedPurchaseUnitsFor(PurchaseListView view) {
    final shortageQuantity = shortageQuantityFor(view);
    if (shortageQuantity <= 0) {
      return 0;
    }

    return (shortageQuantity + stockUnitsPerPurchaseUnit - 1) ~/
        stockUnitsPerPurchaseUnit;
  }

  bool canBeMarkedPurchased(PurchaseListView view) =>
      hasStockLink && suggestedPurchaseUnitsFor(view) > 0;

  Money? estimatedTotalCostFor(PurchaseListView view) {
    final unitPrice = suggestedSupplier?.lastKnownUnitPrice;
    if (unitPrice == null) {
      return null;
    }

    return unitPrice.multiply(suggestedPurchaseUnitsFor(view));
  }

  DateTime? get nearestDeadline {
    DateTime? nearestDate;
    for (final order in relatedOrders) {
      if (order.orderDate == null) {
        continue;
      }

      if (nearestDate == null || order.orderDate!.isBefore(nearestDate)) {
        nearestDate = order.orderDate;
      }
    }

    return nearestDate;
  }

  String get displayCurrentStock =>
      '${AppFormatters.wholeNumber(currentStockQuantity)} $stockUnitLabel';

  String get displayMinimumStock => hasMinimumConfigured
      ? '${AppFormatters.wholeNumber(minimumStockQuantity)} $stockUnitLabel'
      : 'Sem mínimo definido';

  String shortageLabelFor(PurchaseListView view) {
    final shortageQuantity = shortageQuantityFor(view);
    return '${AppFormatters.wholeNumber(shortageQuantity)} $stockUnitLabel';
  }

  String suggestedPurchaseLabelFor(PurchaseListView view) {
    final purchaseUnits = suggestedPurchaseUnitsFor(view);
    return '${AppFormatters.wholeNumber(purchaseUnits)} $purchaseUnitLabel';
  }

  String get supplierLabel =>
      suggestedSupplier?.supplierName ?? 'Sem fornecedora sugerida';

  String get orderSummary {
    if (relatedOrders.isEmpty) {
      return 'Sem pedido relacionado';
    }

    final highlightedOrders = relatedOrders
        .take(2)
        .map((order) {
          return '${order.displayClientName} • ${order.displayDeadline}';
        })
        .join(' • ');

    if (relatedOrders.length <= 2) {
      return highlightedOrders;
    }

    return '$highlightedOrders • +${relatedOrders.length - 2}';
  }

  String get displayNote {
    final trimmedNote = note?.trim();
    if (trimmedNote == null || trimmedNote.isEmpty) {
      return 'Sem observação adicional';
    }

    return trimmedNote;
  }
}

class PurchaseSupplierGroup {
  const PurchaseSupplierGroup({
    required this.label,
    required this.subtitle,
    required this.items,
    required this.estimatedTotal,
  });

  final String label;
  final String subtitle;
  final List<PurchaseChecklistItemRecord> items;
  final Money estimatedTotal;
}

class PurchaseMarkInput {
  const PurchaseMarkInput({
    required this.materialType,
    required this.linkedEntityId,
    required this.nameSnapshot,
    required this.purchaseUnitLabel,
    required this.stockUnitLabel,
    required this.purchaseQuantity,
    required this.stockQuantityAdded,
    required this.supplierId,
    required this.supplierNameSnapshot,
    required this.totalPrice,
    required this.note,
  });

  final OrderMaterialType materialType;
  final String linkedEntityId;
  final String nameSnapshot;
  final String purchaseUnitLabel;
  final String stockUnitLabel;
  final int purchaseQuantity;
  final int stockQuantityAdded;
  final String? supplierId;
  final String? supplierNameSnapshot;
  final Money totalPrice;
  final String? note;
}

class PurchaseExpenseDraftRecord {
  const PurchaseExpenseDraftRecord({
    required this.id,
    required this.purchaseEntryId,
    required this.description,
    required this.supplierId,
    required this.supplierNameSnapshot,
    required this.amount,
    required this.status,
    required this.createdAt,
  });

  final String id;
  final String purchaseEntryId;
  final String description;
  final String? supplierId;
  final String? supplierNameSnapshot;
  final Money amount;
  final PurchaseExpenseDraftStatus status;
  final DateTime createdAt;
}

List<PurchaseChecklistItemRecord> buildPurchaseChecklist({
  required List<PurchaseProjectedNeedRecord> projectedNeeds,
  required List<IngredientRecord> ingredients,
  required List<PackagingRecord> packagingItems,
  required List<SupplierRecord> suppliers,
  DateTime? now,
}) {
  final today = now ?? DateTime.now();
  final normalizedToday = DateTime(today.year, today.month, today.day);
  final endOfWeek = normalizedToday.add(const Duration(days: 6));

  final ingredientsById = {
    for (final ingredient in ingredients) ingredient.id: ingredient,
  };
  final packagingById = {
    for (final packaging in packagingItems) packaging.id: packaging,
  };
  final latestIngredientSupplierSuggestions =
      _buildLatestSupplierSuggestionsByLinkedItemId(
        suppliers: suppliers,
        itemType: SupplierItemType.ingredient,
      );
  final latestPackagingSupplierSuggestions =
      _buildLatestSupplierSuggestionsByLinkedItemId(
        suppliers: suppliers,
        itemType: SupplierItemType.packaging,
      );

  final groupedNeeds = <String, _PurchaseNeedAccumulator>{};
  for (final need in projectedNeeds) {
    final lookupKey = [
      need.materialType.databaseValue,
      need.linkedEntityId ?? need.nameSnapshot.toLowerCase(),
      need.unitLabel.toLowerCase(),
    ].join('::');
    groupedNeeds
        .putIfAbsent(
          lookupKey,
          () => _PurchaseNeedAccumulator(
            materialType: need.materialType,
            linkedEntityId: need.linkedEntityId,
            nameSnapshot: need.nameSnapshot,
            unitLabel: need.unitLabel,
          ),
        )
        .addNeed(need: need, today: normalizedToday, endOfWeek: endOfWeek);
  }

  final items = groupedNeeds.values
      .map((accumulator) {
        final ingredient = accumulator.linkedEntityId == null
            ? null
            : ingredientsById[accumulator.linkedEntityId!];
        final packaging = accumulator.linkedEntityId == null
            ? null
            : packagingById[accumulator.linkedEntityId!];

        if (ingredient != null) {
          final suggestedSupplier = _resolveIngredientSupplierSuggestion(
            ingredient: ingredient,
            latestSupplierSuggestions: latestIngredientSupplierSuggestions,
          );
          return PurchaseChecklistItemRecord(
            materialType: accumulator.materialType,
            linkedEntityId: ingredient.id,
            nameSnapshot: ingredient.name,
            categoryLabel: ingredient.displayCategory,
            stockUnitLabel: ingredient.stockUnit.shortLabel,
            purchaseUnitLabel: ingredient.purchaseUnit.shortLabel,
            stockUnitsPerPurchaseUnit: ingredient.conversionFactor,
            currentStockQuantity: ingredient.currentStockQuantity,
            minimumStockQuantity: ingredient.minimumStockQuantity,
            buyNowDemandQuantity: accumulator.buyNowDemandQuantity,
            thisWeekDemandQuantity: accumulator.thisWeekDemandQuantity,
            buyNowShortageQuantity: _calculateDynamicShortage(
              currentStockQuantity: ingredient.currentStockQuantity,
              demandQuantity: accumulator.buyNowDemandQuantity,
              minimumStockQuantity: ingredient.minimumStockQuantity,
            ),
            thisWeekShortageQuantity: _calculateDynamicShortage(
              currentStockQuantity: ingredient.currentStockQuantity,
              demandQuantity: accumulator.thisWeekDemandQuantity,
              minimumStockQuantity: ingredient.minimumStockQuantity,
            ),
            suggestedSupplier: suggestedSupplier,
            relatedOrders: accumulator.relatedOrders,
            note: accumulator.primaryNote,
            usesDynamicStockRule: true,
          );
        }

        if (packaging != null) {
          final suggestedSupplier =
              latestPackagingSupplierSuggestions[packaging.id];
          return PurchaseChecklistItemRecord(
            materialType: accumulator.materialType,
            linkedEntityId: packaging.id,
            nameSnapshot: packaging.name,
            categoryLabel: packaging.type.label,
            stockUnitLabel: 'un',
            purchaseUnitLabel: 'un',
            stockUnitsPerPurchaseUnit: 1,
            currentStockQuantity: packaging.currentStockQuantity,
            minimumStockQuantity: packaging.minimumStockQuantity,
            buyNowDemandQuantity: accumulator.buyNowDemandQuantity,
            thisWeekDemandQuantity: accumulator.thisWeekDemandQuantity,
            buyNowShortageQuantity: _calculateDynamicShortage(
              currentStockQuantity: packaging.currentStockQuantity,
              demandQuantity: accumulator.buyNowDemandQuantity,
              minimumStockQuantity: packaging.minimumStockQuantity,
            ),
            thisWeekShortageQuantity: _calculateDynamicShortage(
              currentStockQuantity: packaging.currentStockQuantity,
              demandQuantity: accumulator.thisWeekDemandQuantity,
              minimumStockQuantity: packaging.minimumStockQuantity,
            ),
            suggestedSupplier: suggestedSupplier,
            relatedOrders: accumulator.relatedOrders,
            note: accumulator.primaryNote,
            usesDynamicStockRule: true,
          );
        }

        final linkedEntitySuggestion = accumulator.linkedEntityId == null
            ? null
            : latestIngredientSupplierSuggestions[accumulator
                      .linkedEntityId!] ??
                  latestPackagingSupplierSuggestions[accumulator
                      .linkedEntityId!];

        return PurchaseChecklistItemRecord(
          materialType: accumulator.materialType,
          linkedEntityId: accumulator.linkedEntityId,
          nameSnapshot: accumulator.nameSnapshot,
          categoryLabel: accumulator.materialType.label,
          stockUnitLabel: accumulator.unitLabel,
          purchaseUnitLabel: accumulator.unitLabel,
          stockUnitsPerPurchaseUnit: 1,
          currentStockQuantity: 0,
          minimumStockQuantity: 0,
          buyNowDemandQuantity: accumulator.buyNowDemandQuantity,
          thisWeekDemandQuantity: accumulator.thisWeekDemandQuantity,
          buyNowShortageQuantity: accumulator.buyNowSnapshotShortageQuantity,
          thisWeekShortageQuantity:
              accumulator.thisWeekSnapshotShortageQuantity,
          suggestedSupplier: linkedEntitySuggestion,
          relatedOrders: accumulator.relatedOrders,
          note: accumulator.primaryNote,
          usesDynamicStockRule: false,
        );
      })
      .toList(growable: false);

  items.sort((left, right) {
    final leftUrgency = left.buyNowShortageQuantity > 0 ? 0 : 1;
    final rightUrgency = right.buyNowShortageQuantity > 0 ? 0 : 1;
    if (leftUrgency != rightUrgency) {
      return leftUrgency.compareTo(rightUrgency);
    }

    final leftDeadline = left.nearestDeadline;
    final rightDeadline = right.nearestDeadline;
    if (leftDeadline == null && rightDeadline != null) {
      return 1;
    }
    if (leftDeadline != null && rightDeadline == null) {
      return -1;
    }
    if (leftDeadline != null && rightDeadline != null) {
      final deadlineComparison = leftDeadline.compareTo(rightDeadline);
      if (deadlineComparison != 0) {
        return deadlineComparison;
      }
    }

    return left.nameSnapshot.toLowerCase().compareTo(
      right.nameSnapshot.toLowerCase(),
    );
  });

  return items;
}

List<PurchaseChecklistItemRecord> applyPurchaseView(
  List<PurchaseChecklistItemRecord> items,
  PurchaseListView view,
) {
  return items
      .where((item) => item.shortageQuantityFor(view) > 0)
      .toList(growable: false);
}

List<PurchaseSupplierGroup> buildPurchaseGroupsBySupplier(
  List<PurchaseChecklistItemRecord> items,
) {
  final groupedItems = <String, List<PurchaseChecklistItemRecord>>{};
  final groupSubtitles = <String, String>{};
  final groupEstimatedTotals = <String, Money>{};

  for (final item in items) {
    final label =
        item.suggestedSupplier?.supplierName ?? 'Sem fornecedora sugerida';
    final subtitle = item.suggestedSupplier == null
        ? 'Itens sem vínculo de fornecedora ou preço recente.'
        : '${item.suggestedSupplier!.displayLeadTime} • ${item.suggestedSupplier!.displayLastKnownPrice}';
    groupedItems.putIfAbsent(label, () => []).add(item);
    groupSubtitles.putIfAbsent(label, () => subtitle);
    groupEstimatedTotals[label] =
        (groupEstimatedTotals[label] ?? Money.zero) +
        (item.estimatedTotalCostFor(PurchaseListView.bySupplier) ?? Money.zero);
  }

  final labels = groupedItems.keys.toList(growable: false)
    ..sort((left, right) {
      if (left == 'Sem fornecedora sugerida' && right != left) {
        return 1;
      }
      if (right == 'Sem fornecedora sugerida' && left != right) {
        return -1;
      }

      return left.toLowerCase().compareTo(right.toLowerCase());
    });

  return labels
      .map(
        (label) => PurchaseSupplierGroup(
          label: label,
          subtitle: groupSubtitles[label] ?? '',
          items: groupedItems[label] ?? const [],
          estimatedTotal: groupEstimatedTotals[label] ?? Money.zero,
        ),
      )
      .toList(growable: false);
}

PurchaseSuggestedSupplier? _resolveIngredientSupplierSuggestion({
  required IngredientRecord ingredient,
  required Map<String, PurchaseSuggestedSupplier> latestSupplierSuggestions,
}) {
  final preferredSupplier = ingredient.preferredSupplier;
  if (preferredSupplier != null) {
    return PurchaseSuggestedSupplier(
      supplierId: preferredSupplier.supplierId,
      supplierName: preferredSupplier.supplierName,
      contact: preferredSupplier.contact,
      leadTimeDays: preferredSupplier.leadTimeDays,
      lastKnownUnitPrice: preferredSupplier.lastKnownPrice,
      priceUnitLabel: preferredSupplier.lastKnownPriceUnitLabel,
      lastKnownPriceAt: preferredSupplier.lastKnownPriceAt,
    );
  }

  for (final supplier in ingredient.linkedSuppliers) {
    return PurchaseSuggestedSupplier(
      supplierId: supplier.supplierId,
      supplierName: supplier.supplierName,
      contact: supplier.contact,
      leadTimeDays: supplier.leadTimeDays,
      lastKnownUnitPrice: supplier.lastKnownPrice,
      priceUnitLabel: supplier.lastKnownPriceUnitLabel,
      lastKnownPriceAt: supplier.lastKnownPriceAt,
    );
  }

  return latestSupplierSuggestions[ingredient.id];
}

Map<String, PurchaseSuggestedSupplier>
_buildLatestSupplierSuggestionsByLinkedItemId({
  required List<SupplierRecord> suppliers,
  required SupplierItemType itemType,
}) {
  final suggestions = <String, PurchaseSuggestedSupplier>{};

  for (final supplier in suppliers) {
    for (final price in supplier.priceHistory) {
      if (price.itemType != itemType) {
        continue;
      }

      final currentSuggestion = suggestions[price.linkedItemId];
      if (currentSuggestion != null &&
          currentSuggestion.lastKnownPriceAt != null &&
          !price.createdAt.isAfter(currentSuggestion.lastKnownPriceAt!)) {
        continue;
      }

      suggestions[price.linkedItemId] = PurchaseSuggestedSupplier(
        supplierId: supplier.id,
        supplierName: supplier.name,
        contact: supplier.contact,
        leadTimeDays: supplier.leadTimeDays,
        lastKnownUnitPrice: price.price,
        priceUnitLabel: price.unitLabelSnapshot,
        lastKnownPriceAt: price.createdAt,
      );
    }
  }

  return suggestions;
}

int _calculateDynamicShortage({
  required int currentStockQuantity,
  required int demandQuantity,
  required int minimumStockQuantity,
}) {
  final desiredQuantity = demandQuantity + minimumStockQuantity;
  if (desiredQuantity <= currentStockQuantity) {
    return 0;
  }

  return desiredQuantity - currentStockQuantity;
}

PurchaseListView _normalizeView(PurchaseListView view) {
  if (view == PurchaseListView.bySupplier) {
    return PurchaseListView.thisWeek;
  }

  return view;
}

class _PurchaseNeedAccumulator {
  _PurchaseNeedAccumulator({
    required this.materialType,
    required this.linkedEntityId,
    required this.nameSnapshot,
    required this.unitLabel,
  });

  final OrderMaterialType materialType;
  final String? linkedEntityId;
  final String nameSnapshot;
  final String unitLabel;

  int buyNowDemandQuantity = 0;
  int thisWeekDemandQuantity = 0;
  int buyNowSnapshotShortageQuantity = 0;
  int thisWeekSnapshotShortageQuantity = 0;
  final List<PurchaseOrderReference> relatedOrders = <PurchaseOrderReference>[];
  String? primaryNote;

  void addNeed({
    required PurchaseProjectedNeedRecord need,
    required DateTime today,
    required DateTime endOfWeek,
  }) {
    if (need.isDueBy(today)) {
      buyNowDemandQuantity += need.requiredQuantity;
      buyNowSnapshotShortageQuantity += need.shortageQuantity;
    }
    if (need.isDueBy(endOfWeek)) {
      thisWeekDemandQuantity += need.requiredQuantity;
      thisWeekSnapshotShortageQuantity += need.shortageQuantity;
    }

    if (primaryNote == null && need.note?.trim().isNotEmpty == true) {
      primaryNote = need.note!.trim();
    }

    final clientName = need.clientNameSnapshot?.trim();
    relatedOrders.add(
      PurchaseOrderReference(
        orderId: need.orderId,
        clientNameSnapshot: clientName == null || clientName.isEmpty
            ? ''
            : clientName,
        orderDate: need.orderDate,
        recipeNameSnapshot: need.recipeNameSnapshot,
        itemNameSnapshot: need.itemNameSnapshot,
      ),
    );
  }
}
