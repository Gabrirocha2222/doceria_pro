import 'package:doceria_pro/core/database/app_database.dart';
import 'package:doceria_pro/core/money/money.dart';
import 'package:doceria_pro/features/ingredients/data/ingredients_repository.dart';
import 'package:doceria_pro/features/ingredients/domain/ingredient.dart';
import 'package:doceria_pro/features/ingredients/domain/ingredient_unit.dart';
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
  late ProductsRepository productsRepository;

  setUp(() {
    database = AppDatabase(NativeDatabase.memory());
    ingredientsRepository = IngredientsRepository(database);
    recipesRepository = RecipesRepository(database);
    productsRepository = ProductsRepository(database);
  });

  tearDown(() async {
    await database.close();
  });

  test('saves and reads a recipe with automatic total cost', () async {
    final chocolateId = await ingredientsRepository.saveIngredient(
      IngredientUpsertInput(
        name: 'Chocolate em pó',
        category: 'Secos',
        purchaseUnit: IngredientUnit.kilogram,
        stockUnit: IngredientUnit.gram,
        currentStockQuantity: 2000,
        minimumStockQuantity: 500,
        unitCost: Money.fromCents(4200),
        defaultSupplier: null,
        conversionFactor: 1000,
        notes: null,
      ),
    );
    final creamId = await ingredientsRepository.saveIngredient(
      IngredientUpsertInput(
        name: 'Creme de leite',
        category: 'Laticínios',
        purchaseUnit: IngredientUnit.unit,
        stockUnit: IngredientUnit.unit,
        currentStockQuantity: 10,
        minimumStockQuantity: 2,
        unitCost: Money.fromCents(450),
        defaultSupplier: null,
        conversionFactor: 1,
        notes: null,
      ),
    );

    final recipeId = await recipesRepository.saveRecipe(
      RecipeUpsertInput(
        name: 'Ganache base',
        type: RecipeType.filling,
        yieldAmount: 20,
        yieldUnit: RecipeYieldUnit.portion,
        baseLabel: 'Base de chocolate',
        flavorLabel: 'Ao leite',
        notes: 'Usar em bolos e copinhos.',
        items: [
          RecipeItemInput(
            ingredientId: chocolateId,
            quantity: 300,
            notes: null,
          ),
          RecipeItemInput(
            ingredientId: creamId,
            quantity: 2,
            notes: 'Caixinhas',
          ),
        ],
      ),
    );

    final recipe = await recipesRepository.getRecipe(recipeId);

    expect(recipe, isNotNull);
    expect(recipe!.name, 'Ganache base');
    expect(recipe.displayYield, '20 porções');
    expect(recipe.itemCount, 2);
    expect(recipe.totalCostLabel, 'R\$ 21,60');
    expect(recipe.costPerYieldLabel, 'R\$ 1,08 por porção');
    expect(
      recipe.structureSummary,
      'Base: Base de chocolate • Sabor: Ao leite',
    );
  });

  test('recipes expose linked products for future automation', () async {
    final ingredientId = await ingredientsRepository.saveIngredient(
      IngredientUpsertInput(
        name: 'Leite condensado',
        category: 'Laticínios',
        purchaseUnit: IngredientUnit.unit,
        stockUnit: IngredientUnit.unit,
        currentStockQuantity: 12,
        minimumStockQuantity: 3,
        unitCost: Money.fromCents(650),
        defaultSupplier: null,
        conversionFactor: 1,
        notes: null,
      ),
    );

    final recipeId = await recipesRepository.saveRecipe(
      RecipeUpsertInput(
        name: 'Brigadeiro tradicional',
        type: RecipeType.filling,
        yieldAmount: 25,
        yieldUnit: RecipeYieldUnit.portion,
        baseLabel: null,
        flavorLabel: 'Tradicional',
        notes: null,
        items: [
          RecipeItemInput(ingredientId: ingredientId, quantity: 2, notes: null),
        ],
      ),
    );

    await productsRepository.saveProduct(
      ProductUpsertInput(
        name: 'Bolo de festa',
        category: 'Bolos',
        type: ProductType.simple,
        saleMode: ProductSaleMode.quoteOnly,
        basePrice: Money.fromCents(0),
        notes: null,
        yieldHint: null,
        isActive: true,
        options: const [],
        linkedRecipeIds: [recipeId],
        linkedPackagingIds: const [],
        defaultSuggestedPackagingId: null,
      ),
    );

    final recipe = await recipesRepository.getRecipe(recipeId);

    expect(recipe, isNotNull);
    expect(recipe!.linkedProducts, hasLength(1));
    expect(recipe.linkedProducts.single.productName, 'Bolo de festa');
  });
}
