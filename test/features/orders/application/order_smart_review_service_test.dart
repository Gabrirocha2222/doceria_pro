import 'package:doceria_pro/core/database/app_database.dart';
import 'package:doceria_pro/core/money/money.dart';
import 'package:doceria_pro/features/ingredients/data/ingredients_repository.dart';
import 'package:doceria_pro/features/ingredients/domain/ingredient.dart';
import 'package:doceria_pro/features/ingredients/domain/ingredient_unit.dart';
import 'package:doceria_pro/features/orders/application/order_smart_review_service.dart';
import 'package:doceria_pro/features/orders/domain/order.dart';
import 'package:doceria_pro/features/orders/domain/order_fulfillment_method.dart';
import 'package:doceria_pro/features/packaging/data/packaging_repository.dart';
import 'package:doceria_pro/features/packaging/domain/packaging.dart';
import 'package:doceria_pro/features/packaging/domain/packaging_type.dart';
import 'package:doceria_pro/features/products/data/products_repository.dart';
import 'package:doceria_pro/features/products/domain/product.dart';
import 'package:doceria_pro/features/products/domain/product_sale_mode.dart';
import 'package:doceria_pro/features/products/domain/product_type.dart';
import 'package:doceria_pro/features/recipes/data/recipes_repository.dart';
import 'package:doceria_pro/features/recipes/domain/recipe.dart';
import 'package:doceria_pro/features/recipes/domain/recipe_type.dart';
import 'package:doceria_pro/features/recipes/domain/recipe_yield_unit.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase database;
  late IngredientsRepository ingredientsRepository;
  late RecipesRepository recipesRepository;
  late PackagingRepository packagingRepository;
  late ProductsRepository productsRepository;
  late OrderSmartReviewService service;

  setUp(() {
    database = AppDatabase(NativeDatabase.memory());
    ingredientsRepository = IngredientsRepository(database);
    recipesRepository = RecipesRepository(database);
    packagingRepository = PackagingRepository(database);
    productsRepository = ProductsRepository(database);
    service = OrderSmartReviewService(
      productsRepository: productsRepository,
      recipesRepository: recipesRepository,
      ingredientsRepository: ingredientsRepository,
    );
  });

  tearDown(() async {
    await database.close();
  });

  test(
    'builds a smart review with cost, shortages and downstream entries',
    () async {
      final flourId = await ingredientsRepository.saveIngredient(
        IngredientUpsertInput(
          name: 'Farinha',
          category: 'Secos',
          purchaseUnit: IngredientUnit.kilogram,
          stockUnit: IngredientUnit.gram,
          currentStockQuantity: 100,
          minimumStockQuantity: 80,
          unitCost: Money.fromCents(1000),
          defaultSupplier: null,
          conversionFactor: 1000,
          notes: null,
        ),
      );
      final eggId = await ingredientsRepository.saveIngredient(
        IngredientUpsertInput(
          name: 'Ovos',
          category: 'Frescos',
          purchaseUnit: IngredientUnit.unit,
          stockUnit: IngredientUnit.unit,
          currentStockQuantity: 12,
          minimumStockQuantity: 4,
          unitCost: Money.fromCents(80),
          defaultSupplier: null,
          conversionFactor: 1,
          notes: null,
        ),
      );

      final recipeId = await recipesRepository.saveRecipe(
        RecipeUpsertInput(
          name: 'Massa branca',
          type: RecipeType.base,
          yieldAmount: 10,
          yieldUnit: RecipeYieldUnit.portion,
          baseLabel: 'Massa leve',
          flavorLabel: null,
          notes: null,
          items: [
            RecipeItemInput(ingredientId: flourId, quantity: 300, notes: null),
            RecipeItemInput(ingredientId: eggId, quantity: 2, notes: null),
          ],
        ),
      );

      final packagingId = await packagingRepository.savePackaging(
        PackagingUpsertInput(
          name: 'Caixa de bolo PP',
          type: PackagingType.box,
          cost: Money.fromCents(50),
          currentStockQuantity: 3,
          minimumStockQuantity: 1,
          capacityDescription: 'Serve 1 bolo pequeno',
          notes: null,
          isActive: true,
        ),
      );

      final productId = await productsRepository.saveProduct(
        ProductUpsertInput(
          name: 'Mini bolo',
          category: 'Bolos',
          type: ProductType.perUnit,
          saleMode: ProductSaleMode.fixedPrice,
          basePrice: Money.fromCents(300),
          notes: null,
          yieldHint: '1 unidade',
          isActive: true,
          options: const [],
          linkedRecipeIds: [recipeId],
          linkedPackagingIds: [packagingId],
          defaultSuggestedPackagingId: packagingId,
        ),
      );

      final review = await service.buildReview(
        OrderSmartReviewRequest(
          clientId: 'client-1',
          clientNameSnapshot: 'Amanda',
          eventDate: DateTime(2026, 8, 10),
          fulfillmentMethod: OrderFulfillmentMethod.pickup,
          productId: productId,
          quantity: 5,
          deliveryFee: Money.zero,
          salePriceOverride: Money.zero,
          depositAmount: Money.fromCents(300),
          notes: 'Sem topper',
          referencePhotoPath: '/tmp/bolo.jpg',
        ),
      );

      expect(review.product, isNotNull);
      expect(review.estimatedCost.cents, 480);
      expect(review.suggestedSalePrice.cents, 1500);
      expect(review.orderTotal.cents, 1500);
      expect(review.predictedProfit.cents, 1020);
      expect(review.suggestedPackagingNameSnapshot, 'Caixa de bolo PP');
      expect(review.primaryItem.quantity, 5);
      expect(review.materialNeeds, hasLength(3));
      expect(review.shortages, hasLength(2));
      expect(
        review.shortages.map((need) => need.nameSnapshot),
        containsAll(<String>['Farinha', 'Caixa de bolo PP']),
      );
      expect(review.productionPlans, hasLength(3));
      expect(review.receivableEntries, hasLength(2));
      expect(
        review.receivableEntries.first.status,
        OrderReceivableStatus.received,
      );
      expect(review.receivableEntries.last.amount.cents, 1200);
      expect(review.hasLimitations, isFalse);
    },
  );

  test(
    'falls back gracefully when the product has no smart links yet',
    () async {
      final productId = await productsRepository.saveProduct(
        ProductUpsertInput(
          name: 'Caixa surpresa',
          category: 'Presentes',
          type: ProductType.kit,
          saleMode: ProductSaleMode.quoteOnly,
          basePrice: Money.zero,
          notes: null,
          yieldHint: null,
          isActive: true,
          options: const [],
          linkedRecipeIds: const [],
          linkedPackagingIds: const [],
          defaultSuggestedPackagingId: null,
        ),
      );

      final review = await service.buildReview(
        OrderSmartReviewRequest(
          clientId: null,
          clientNameSnapshot: 'Bianca',
          eventDate: DateTime(2026, 9, 1),
          fulfillmentMethod: OrderFulfillmentMethod.delivery,
          productId: productId,
          quantity: 2,
          deliveryFee: Money.fromCents(700),
          salePriceOverride: Money.zero,
          depositAmount: Money.zero,
          notes: null,
          referencePhotoPath: null,
        ),
      );

      expect(review.estimatedCost, Money.zero);
      expect(review.suggestedSalePrice, Money.zero);
      expect(review.orderTotal.cents, 700);
      expect(review.limitations, isNotEmpty);
      expect(review.materialNeeds, isEmpty);
      expect(review.receivableEntries.single.amount.cents, 700);
    },
  );
}
