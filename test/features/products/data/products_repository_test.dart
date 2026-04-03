import 'package:doceria_pro/core/database/app_database.dart';
import 'package:doceria_pro/core/money/money.dart';
import 'package:doceria_pro/features/products/data/products_repository.dart';
import 'package:doceria_pro/features/products/domain/product.dart';
import 'package:doceria_pro/features/products/domain/product_option_type.dart';
import 'package:doceria_pro/features/products/domain/product_sale_mode.dart';
import 'package:doceria_pro/features/products/domain/product_type.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase database;
  late ProductsRepository repository;

  setUp(() {
    database = AppDatabase(NativeDatabase.memory());
    repository = ProductsRepository(database);
  });

  tearDown(() async {
    await database.close();
  });

  test('saves and reads a locally persisted product with options', () async {
    final savedId = await repository.saveProduct(
      ProductUpsertInput(
        name: 'Bolo no pote',
        category: 'Doces',
        type: ProductType.perUnit,
        saleMode: ProductSaleMode.fixedPrice,
        basePrice: Money.fromCents(1800),
        notes: 'Venda rápida de balcão.',
        yieldHint: 'Pote de 250 ml',
        isActive: true,
        linkedRecipeIds: const [],
        linkedPackagingIds: const [],
        defaultSuggestedPackagingId: null,
        options: const [
          ProductOptionInput(
            type: ProductOptionType.flavor,
            name: 'Brigadeiro',
          ),
          ProductOptionInput(type: ProductOptionType.variation, name: '250 ml'),
        ],
      ),
    );

    final products = await repository.watchProducts().first;

    expect(products, hasLength(1));
    expect(products.single.id, savedId);
    expect(products.single.name, 'Bolo no pote');
    expect(products.single.displayCategory, 'Doces');
    expect(products.single.type, ProductType.perUnit);
    expect(products.single.saleMode, ProductSaleMode.fixedPrice);
    expect(products.single.basePrice, Money.fromCents(1800));
    expect(products.single.flavors.single.name, 'Brigadeiro');
    expect(products.single.variations.single.name, '250 ml');
  });

  test('updating a product replaces its option structure', () async {
    final savedId = await repository.saveProduct(
      ProductUpsertInput(
        name: 'Caixa de brownie',
        category: 'Kits',
        type: ProductType.kit,
        saleMode: ProductSaleMode.startingAt,
        basePrice: Money.fromCents(4500),
        notes: null,
        yieldHint: '6 unidades',
        isActive: true,
        linkedRecipeIds: const [],
        linkedPackagingIds: const [],
        defaultSuggestedPackagingId: null,
        options: const [
          ProductOptionInput(
            type: ProductOptionType.variation,
            name: '6 unidades',
          ),
        ],
      ),
    );

    await repository.saveProduct(
      ProductUpsertInput(
        id: savedId,
        name: 'Caixa de brownie',
        category: 'Presentes',
        type: ProductType.kit,
        saleMode: ProductSaleMode.quoteOnly,
        basePrice: Money.fromCents(5000),
        notes: 'Montagem sob demanda.',
        yieldHint: '9 unidades',
        isActive: false,
        linkedRecipeIds: const [],
        linkedPackagingIds: const [],
        defaultSuggestedPackagingId: null,
        options: const [
          ProductOptionInput(
            type: ProductOptionType.flavor,
            name: 'Chocolate intenso',
          ),
          ProductOptionInput(
            type: ProductOptionType.variation,
            name: '9 unidades',
          ),
        ],
      ),
    );

    final product = await repository.getProduct(savedId);

    expect(product, isNotNull);
    expect(product!.displayCategory, 'Presentes');
    expect(product.saleMode, ProductSaleMode.quoteOnly);
    expect(product.isActive, isFalse);
    expect(product.flavors.single.name, 'Chocolate intenso');
    expect(product.variations.single.name, '9 unidades');
    expect(product.displayNotes, 'Montagem sob demanda.');
  });

  test('stores linked recipes for later product automation', () async {
    await database
        .into(database.recipes)
        .insert(
          RecipesCompanion.insert(
            id: 'recipe-1',
            name: 'Brigadeiro cremoso',
            type: 'filling',
            yieldAmount: 20,
            yieldUnit: 'portion',
            createdAt: Value(DateTime(2026, 4, 2)),
            updatedAt: Value(DateTime(2026, 4, 2)),
          ),
        );

    final savedId = await repository.saveProduct(
      ProductUpsertInput(
        name: 'Bolo no pote',
        category: 'Doces',
        type: ProductType.perUnit,
        saleMode: ProductSaleMode.fixedPrice,
        basePrice: Money.fromCents(1800),
        notes: null,
        yieldHint: '250 ml',
        isActive: true,
        linkedRecipeIds: const ['recipe-1'],
        linkedPackagingIds: const [],
        defaultSuggestedPackagingId: null,
        options: const [],
      ),
    );

    final product = await repository.getProduct(savedId);

    expect(product, isNotNull);
    expect(product!.linkedRecipes, hasLength(1));
    expect(product.linkedRecipes.single.recipeName, 'Brigadeiro cremoso');
    expect(product.linkedRecipes.single.recipeTypeLabel, 'Recheio');
  });

  test('stores compatible packaging and one default suggestion', () async {
    await database
        .into(database.packaging)
        .insert(
          PackagingCompanion.insert(
            id: 'packaging-1',
            name: 'Caixa kraft P',
            type: 'box',
            costCents: const Value(320),
            currentStockQuantity: const Value(12),
            minimumStockQuantity: const Value(5),
            capacityDescription: const Value('4 brigadeiros'),
            isActive: const Value(true),
            createdAt: Value(DateTime(2026, 4, 2)),
            updatedAt: Value(DateTime(2026, 4, 2)),
          ),
        );
    await database
        .into(database.packaging)
        .insert(
          PackagingCompanion.insert(
            id: 'packaging-2',
            name: 'Sacola branca',
            type: 'bag',
            costCents: const Value(180),
            currentStockQuantity: const Value(40),
            minimumStockQuantity: const Value(10),
            capacityDescription: const Value('Entrega geral'),
            isActive: const Value(true),
            createdAt: Value(DateTime(2026, 4, 2)),
            updatedAt: Value(DateTime(2026, 4, 2)),
          ),
        );

    final savedId = await repository.saveProduct(
      ProductUpsertInput(
        name: 'Caixa de brigadeiro',
        category: 'Doces',
        type: ProductType.kit,
        saleMode: ProductSaleMode.fixedPrice,
        basePrice: Money.fromCents(2800),
        notes: null,
        yieldHint: '4 unidades',
        isActive: true,
        linkedRecipeIds: const [],
        linkedPackagingIds: const ['packaging-1', 'packaging-2'],
        defaultSuggestedPackagingId: 'packaging-1',
        options: const [],
      ),
    );

    final product = await repository.getProduct(savedId);

    expect(product, isNotNull);
    expect(product!.linkedPackagings, hasLength(2));
    expect(product.defaultSuggestedPackaging, isNotNull);
    expect(product.defaultSuggestedPackaging!.packagingName, 'Caixa kraft P');
    expect(
      product.linkedPackagings.where((item) => item.isDefaultSuggested),
      hasLength(1),
    );
  });
}
