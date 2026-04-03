import 'package:doceria_pro/core/database/app_database.dart';
import 'package:doceria_pro/core/money/money.dart';
import 'package:doceria_pro/features/ingredients/data/ingredients_repository.dart';
import 'package:doceria_pro/features/ingredients/domain/ingredient.dart';
import 'package:doceria_pro/features/ingredients/domain/ingredient_unit.dart';
import 'package:doceria_pro/features/orders/data/orders_repository.dart';
import 'package:doceria_pro/features/orders/domain/order.dart';
import 'package:doceria_pro/features/orders/domain/order_fulfillment_method.dart';
import 'package:doceria_pro/features/orders/domain/order_status.dart';
import 'package:doceria_pro/features/packaging/data/packaging_repository.dart';
import 'package:doceria_pro/features/packaging/domain/packaging.dart';
import 'package:doceria_pro/features/packaging/domain/packaging_type.dart';
import 'package:doceria_pro/features/production/data/production_repository.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase database;
  late OrdersRepository ordersRepository;
  late IngredientsRepository ingredientsRepository;
  late PackagingRepository packagingRepository;
  late ProductionRepository productionRepository;

  setUp(() {
    database = AppDatabase(NativeDatabase.memory());
    ordersRepository = OrdersRepository(database);
    ingredientsRepository = IngredientsRepository(database);
    packagingRepository = PackagingRepository(database);
    productionRepository = ProductionRepository(database);
  });

  tearDown(() async {
    await database.close();
  });

  test(
    'loads tasks and applies stock effects only once on completion',
    () async {
      final ingredientId = await ingredientsRepository.saveIngredient(
        IngredientUpsertInput(
          name: 'Farinha',
          category: 'Secos',
          purchaseUnit: IngredientUnit.kilogram,
          stockUnit: IngredientUnit.gram,
          currentStockQuantity: 500,
          minimumStockQuantity: 100,
          unitCost: Money.fromCents(1000),
          defaultSupplier: null,
          conversionFactor: 1000,
          notes: null,
        ),
      );
      final packagingId = await packagingRepository.savePackaging(
        PackagingUpsertInput(
          name: 'Caixa mini bolo',
          type: PackagingType.box,
          cost: Money.fromCents(120),
          currentStockQuantity: 10,
          minimumStockQuantity: 2,
          capacityDescription: 'Serve 1 mini bolo',
          notes: null,
          isActive: true,
        ),
      );

      final orderId = await ordersRepository.saveOrder(
        OrderUpsertInput(
          clientNameSnapshot: 'Amanda',
          eventDate: DateTime(2026, 8, 10),
          fulfillmentMethod: OrderFulfillmentMethod.pickup,
          deliveryFee: Money.zero,
          orderTotal: Money.fromCents(1800),
          depositAmount: Money.fromCents(500),
          status: OrderStatus.confirmed,
          items: [
            OrderItemInput(
              id: 'item-primary',
              productId: 'product-1',
              itemNameSnapshot: 'Mini bolo',
              flavorSnapshot: 'Brigadeiro',
              variationSnapshot: null,
              price: Money.fromCents(900),
              quantity: 2,
              notes: 'Caprichar na finalização',
            ),
          ],
          productionPlans: [
            OrderProductionPlanInput(
              id: 'plan-recipe',
              title: 'Produzir massa branca',
              details: 'Assar e rechear',
              planType: OrderProductionPlanType.recipe,
              recipeNameSnapshot: 'Massa branca',
              itemNameSnapshot: 'Mini bolo',
              quantity: 2,
              notes: 'Sem topper',
              status: OrderProductionPlanStatus.pending,
              dueDate: DateTime(2026, 8, 10),
              sortOrder: 0,
            ),
            OrderProductionPlanInput(
              id: 'plan-packaging',
              title: 'Separar embalagem',
              details: 'Caixa mini bolo • 2 un',
              planType: OrderProductionPlanType.packaging,
              itemNameSnapshot: 'Mini bolo',
              quantity: 2,
              notes: 'Usar caixa branca',
              status: OrderProductionPlanStatus.pending,
              dueDate: DateTime(2026, 8, 10),
              sortOrder: 1,
            ),
          ],
          materialNeeds: [
            OrderMaterialNeedInput(
              id: 'need-ingredient',
              materialType: OrderMaterialType.ingredient,
              linkedEntityId: ingredientId,
              recipeNameSnapshot: 'Massa branca',
              itemNameSnapshot: 'Mini bolo',
              nameSnapshot: 'Farinha',
              unitLabel: 'g',
              requiredQuantity: 300,
              availableQuantity: 500,
              shortageQuantity: 0,
              note: null,
              sortOrder: 0,
            ),
            OrderMaterialNeedInput(
              id: 'need-packaging',
              materialType: OrderMaterialType.packaging,
              linkedEntityId: packagingId,
              itemNameSnapshot: 'Mini bolo',
              nameSnapshot: 'Caixa mini bolo',
              unitLabel: 'un',
              requiredQuantity: 2,
              availableQuantity: 10,
              shortageQuantity: 0,
              note: null,
              sortOrder: 1,
            ),
          ],
        ),
      );

      final tasks = await productionRepository.watchTasks().first;

      expect(tasks, hasLength(2));
      expect(tasks.first.displayItemLabel, 'Mini bolo • Brigadeiro');
      expect(tasks.first.orderId, orderId);

      await database.delete(database.syncQueue).go();

      await productionRepository.updatePlanStatus(
        planId: 'plan-recipe',
        status: OrderProductionPlanStatus.inProduction,
      );

      var ingredient = await ingredientsRepository.getIngredient(ingredientId);
      expect(ingredient, isNotNull);
      expect(ingredient!.currentStockQuantity, 500);

      await productionRepository.updatePlanStatus(
        planId: 'plan-recipe',
        status: OrderProductionPlanStatus.completed,
      );

      ingredient = await ingredientsRepository.getIngredient(ingredientId);
      expect(ingredient, isNotNull);
      expect(ingredient!.currentStockQuantity, 200);

      final ingredientMovements = await database
          .select(database.ingredientStockMovements)
          .get();
      final syncQueueAfterRecipeCompletion = await database
          .select(database.syncQueue)
          .get();
      expect(ingredientMovements, hasLength(1));
      expect(ingredientMovements.single.referenceId, 'plan-recipe');
      expect(
        syncQueueAfterRecipeCompletion.any(
          (item) => item.entityType == 'order' && item.entityId == orderId,
        ),
        isTrue,
      );
      expect(
        syncQueueAfterRecipeCompletion.any(
          (item) =>
              item.entityType == 'ingredient' && item.entityId == ingredientId,
        ),
        isTrue,
      );

      await productionRepository.updatePlanStatus(
        planId: 'plan-recipe',
        status: OrderProductionPlanStatus.completed,
      );

      final ingredientMovementsAfterSecondCompletion = await database
          .select(database.ingredientStockMovements)
          .get();
      expect(ingredientMovementsAfterSecondCompletion, hasLength(1));

      expect(
        () => productionRepository.updatePlanStatus(
          planId: 'plan-recipe',
          status: OrderProductionPlanStatus.pending,
        ),
        throwsStateError,
      );

      await productionRepository.updatePlanStatus(
        planId: 'plan-packaging',
        status: OrderProductionPlanStatus.completed,
      );

      final packagingRow = await database
          .select(database.packaging)
          .getSingle();
      expect(packagingRow.currentStockQuantity, 8);

      final packagingMovements = await database
          .select(database.packagingStockMovements)
          .get();
      final syncQueueAfterPackagingCompletion = await database
          .select(database.syncQueue)
          .get();
      expect(packagingMovements, hasLength(1));
      expect(packagingMovements.single.referenceId, 'plan-packaging');
      expect(
        syncQueueAfterPackagingCompletion.any(
          (item) =>
              item.entityType == 'packaging' && item.entityId == packagingId,
        ),
        isTrue,
      );

      final materialNeeds = await database
          .select(database.orderMaterialNeeds)
          .get();
      expect(
        materialNeeds.where((need) => need.consumedAt != null),
        hasLength(2),
      );
    },
  );
}
