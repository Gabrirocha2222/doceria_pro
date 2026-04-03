import 'package:doceria_pro/core/database/app_database.dart';
import 'package:doceria_pro/core/money/money.dart';
import 'package:doceria_pro/features/packaging/data/packaging_repository.dart';
import 'package:doceria_pro/features/packaging/domain/packaging.dart';
import 'package:doceria_pro/features/packaging/domain/packaging_type.dart';
import 'package:doceria_pro/features/products/data/products_repository.dart';
import 'package:doceria_pro/features/products/domain/product.dart';
import 'package:doceria_pro/features/products/domain/product_sale_mode.dart';
import 'package:doceria_pro/features/products/domain/product_type.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase database;
  late PackagingRepository packagingRepository;
  late ProductsRepository productsRepository;

  setUp(() {
    database = AppDatabase(NativeDatabase.memory());
    packagingRepository = PackagingRepository(database);
    productsRepository = ProductsRepository(database);
  });

  tearDown(() async {
    await database.close();
  });

  test('saves and reads a locally persisted packaging item', () async {
    final savedId = await packagingRepository.savePackaging(
      PackagingUpsertInput(
        name: 'Caixa premium',
        type: PackagingType.box,
        cost: Money.fromCents(450),
        currentStockQuantity: 20,
        minimumStockQuantity: 6,
        capacityDescription: '6 doces finos',
        notes: 'Usar em kits presenteáveis.',
        isActive: true,
      ),
    );

    final items = await packagingRepository.watchPackaging().first;

    expect(items, hasLength(1));
    expect(items.single.id, savedId);
    expect(items.single.name, 'Caixa premium');
    expect(items.single.type, PackagingType.box);
    expect(items.single.displayCost, 'R\$ 4,50');
    expect(items.single.displayStock, '20 un');
    expect(items.single.displayMinimumStock, '6 un');
    expect(items.single.displayCapacityDescription, '6 doces finos');
    expect(items.single.isLowStock, isFalse);
  });

  test(
    'packaging detail shows compatible products and default usage',
    () async {
      final packagingId = await packagingRepository.savePackaging(
        PackagingUpsertInput(
          name: 'Pote 250 ml',
          type: PackagingType.pot,
          cost: Money.fromCents(220),
          currentStockQuantity: 8,
          minimumStockQuantity: 10,
          capacityDescription: 'Bolo no pote',
          notes: null,
          isActive: true,
        ),
      );

      await productsRepository.saveProduct(
        ProductUpsertInput(
          name: 'Bolo no pote',
          category: 'Doces',
          type: ProductType.perUnit,
          saleMode: ProductSaleMode.fixedPrice,
          basePrice: Money.fromCents(1800),
          notes: null,
          yieldHint: '250 ml',
          isActive: true,
          options: const [],
          linkedRecipeIds: const [],
          linkedPackagingIds: [packagingId],
          defaultSuggestedPackagingId: packagingId,
        ),
      );

      final item = await packagingRepository.getPackagingItem(packagingId);

      expect(item, isNotNull);
      expect(item!.isLowStock, isTrue);
      expect(item.linkedProducts, hasLength(1));
      expect(item.linkedProducts.single.productName, 'Bolo no pote');
      expect(item.linkedProducts.single.isDefaultSuggested, isTrue);
    },
  );
}
