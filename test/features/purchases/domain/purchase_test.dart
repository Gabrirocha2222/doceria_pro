import 'package:doceria_pro/core/money/money.dart';
import 'package:doceria_pro/features/ingredients/domain/ingredient.dart';
import 'package:doceria_pro/features/ingredients/domain/ingredient_unit.dart';
import 'package:doceria_pro/features/orders/domain/order.dart';
import 'package:doceria_pro/features/packaging/domain/packaging.dart';
import 'package:doceria_pro/features/packaging/domain/packaging_type.dart';
import 'package:doceria_pro/features/purchases/domain/purchase.dart';
import 'package:doceria_pro/features/suppliers/domain/supplier.dart';
import 'package:doceria_pro/features/suppliers/domain/supplier_item_type.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'buildPurchaseChecklist uses current stock and minimum to show only the real missing quantity',
    () {
      final ingredient = IngredientRecord(
        id: 'ingredient-1',
        name: 'Chocolate em pó',
        category: 'Secos',
        purchaseUnit: IngredientUnit.kilogram,
        stockUnit: IngredientUnit.gram,
        currentStockQuantity: 1200,
        minimumStockQuantity: 500,
        unitCost: Money.fromCents(4200),
        defaultSupplier: null,
        conversionFactor: 1000,
        notes: null,
        createdAt: DateTime(2026, 4, 2),
        updatedAt: DateTime(2026, 4, 2),
        linkedSuppliers: [
          IngredientLinkedSupplierRecord(
            supplierId: 'supplier-1',
            supplierName: 'Atacadista Central',
            contact: null,
            leadTimeDays: 2,
            isDefaultPreferred: true,
            lastKnownPrice: Money.fromCents(4500),
            lastKnownPriceUnitLabel: 'kg',
            lastKnownPriceAt: null,
          ),
        ],
      );

      final checklist = buildPurchaseChecklist(
        projectedNeeds: [
          PurchaseProjectedNeedRecord(
            orderId: 'order-1',
            clientNameSnapshot: 'Marina',
            orderDate: DateTime(2026, 4, 2),
            materialType: OrderMaterialType.ingredient,
            linkedEntityId: 'ingredient-1',
            recipeNameSnapshot: 'Brigadeiro',
            itemNameSnapshot: 'Bolo de pote',
            nameSnapshot: 'Chocolate em pó',
            unitLabel: 'g',
            requiredQuantity: 1000,
            shortageQuantity: 0,
            note: null,
          ),
        ],
        ingredients: [ingredient],
        packagingItems: const [],
        suppliers: const [],
        now: DateTime(2026, 4, 2),
      );

      expect(checklist, hasLength(1));
      expect(checklist.single.buyNowShortageQuantity, 300);
      expect(
        checklist.single.shortageLabelFor(PurchaseListView.buyNow),
        '300 g',
      );
      expect(
        checklist.single.suggestedPurchaseLabelFor(PurchaseListView.buyNow),
        '1 kg',
      );
      expect(checklist.single.supplierLabel, 'Atacadista Central');
    },
  );

  test(
    'buildPurchaseChecklist can suggest packaging supplier from last known price history',
    () {
      final packaging = PackagingRecord(
        id: 'packaging-1',
        name: 'Caixa premium',
        type: PackagingType.box,
        cost: Money.fromCents(320),
        currentStockQuantity: 2,
        minimumStockQuantity: 3,
        capacityDescription: null,
        notes: null,
        isActive: true,
        createdAt: DateTime(2026, 4, 2),
        updatedAt: DateTime(2026, 4, 2),
        linkedProducts: const [],
      );

      final suppliers = [
        SupplierRecord(
          id: 'supplier-1',
          name: 'Embalagens Express',
          contact: 'WhatsApp',
          notes: null,
          leadTimeDays: 1,
          isActive: true,
          createdAt: DateTime(2026, 4, 2),
          updatedAt: DateTime(2026, 4, 2),
          linkedIngredients: const [],
          priceHistory: [
            SupplierPriceRecord(
              id: 'price-1',
              supplierId: 'supplier-1',
              itemType: SupplierItemType.packaging,
              linkedItemId: 'packaging-1',
              itemNameSnapshot: 'Caixa premium',
              unitLabelSnapshot: 'un',
              price: Money.fromCents(350),
              notes: null,
              createdAt: DateTime(2026, 4, 2),
            ),
          ],
        ),
      ];

      final checklist = buildPurchaseChecklist(
        projectedNeeds: [
          PurchaseProjectedNeedRecord(
            orderId: 'order-1',
            clientNameSnapshot: 'Marina',
            orderDate: DateTime(2026, 4, 4),
            materialType: OrderMaterialType.packaging,
            linkedEntityId: 'packaging-1',
            recipeNameSnapshot: null,
            itemNameSnapshot: 'Caixa premium',
            nameSnapshot: 'Caixa premium',
            unitLabel: 'un',
            requiredQuantity: 4,
            shortageQuantity: 2,
            note: null,
          ),
        ],
        ingredients: const [],
        packagingItems: [packaging],
        suppliers: suppliers,
        now: DateTime(2026, 4, 2),
      );

      expect(checklist, hasLength(1));
      expect(checklist.single.thisWeekShortageQuantity, 5);
      expect(checklist.single.supplierLabel, 'Embalagens Express');
      expect(
        checklist.single.suggestedSupplier?.displayLastKnownPrice,
        'R\$ 3,50 / un',
      );
    },
  );
}
