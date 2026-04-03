import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../../core/database/app_database.dart';
import '../../../core/money/money.dart';
import '../../../core/sync/sync_definitions.dart';
import '../../packaging/domain/packaging_type.dart';
import '../../recipes/domain/recipe_type.dart';
import '../../recipes/domain/recipe_yield_unit.dart';
import '../../sync/data/local_sync_support.dart';
import '../domain/product.dart';
import '../domain/product_option_type.dart';
import '../domain/product_sale_mode.dart';
import '../domain/product_type.dart';

class ProductsRepository {
  ProductsRepository(this._database);

  final AppDatabase _database;
  final Uuid _uuid = const Uuid();

  Stream<List<ProductRecord>> watchProducts() {
    final query = _database.select(_database.products)
      ..orderBy([
        (table) =>
            OrderingTerm(expression: table.isActive, mode: OrderingMode.desc),
        (table) => OrderingTerm(
          expression: table.name.lower(),
          mode: OrderingMode.asc,
        ),
      ]);

    return query.watch().asyncMap(_mapProductList);
  }

  Stream<ProductRecord?> watchProduct(String productId) {
    final query = _database.select(_database.products)
      ..where((table) => table.id.equals(productId));

    return query.watchSingleOrNull().asyncMap((row) async {
      if (row == null) {
        return null;
      }

      final options = await _loadOptions(productId);
      final linkedRecipes = await _loadLinkedRecipes(productId);
      final linkedPackagings = await _loadLinkedPackagings(productId);
      return _mapProductRecord(row, options, linkedRecipes, linkedPackagings);
    });
  }

  Future<ProductRecord?> getProduct(String productId) async {
    final row = await (_database.select(
      _database.products,
    )..where((table) => table.id.equals(productId))).getSingleOrNull();

    if (row == null) {
      return null;
    }

    final options = await _loadOptions(productId);
    final linkedRecipes = await _loadLinkedRecipes(productId);
    final linkedPackagings = await _loadLinkedPackagings(productId);
    return _mapProductRecord(row, options, linkedRecipes, linkedPackagings);
  }

  Future<String> saveProduct(ProductUpsertInput input) async {
    final trimmedName = input.name.trim();
    if (trimmedName.isEmpty) {
      throw ArgumentError('Product name is required.');
    }

    if (input.basePrice.cents < 0) {
      throw ArgumentError('Product base price must be positive.');
    }

    final productId = input.id ?? _uuid.v4();
    final now = DateTime.now();
    final normalizedOptions = input.options
        .where((option) => option.name.trim().isNotEmpty)
        .toList(growable: false);
    final normalizedRecipeIds = input.linkedRecipeIds
        .map((recipeId) => recipeId.trim())
        .where((recipeId) => recipeId.isNotEmpty)
        .toSet()
        .toList(growable: false);
    final normalizedPackagingIds = input.linkedPackagingIds
        .map((packagingId) => packagingId.trim())
        .where((packagingId) => packagingId.isNotEmpty)
        .toSet()
        .toList(growable: false);
    final trimmedDefaultPackagingId = input.defaultSuggestedPackagingId?.trim();
    final defaultSuggestedPackagingId =
        trimmedDefaultPackagingId == null || trimmedDefaultPackagingId.isEmpty
        ? null
        : trimmedDefaultPackagingId;

    if (defaultSuggestedPackagingId != null &&
        !normalizedPackagingIds.contains(defaultSuggestedPackagingId)) {
      throw ArgumentError(
        'Default suggested packaging must also be compatible with the product.',
      );
    }

    await _database.transaction(() async {
      if (input.id == null) {
        await _database
            .into(_database.products)
            .insert(
              ProductsCompanion.insert(
                id: productId,
                name: trimmedName,
                category: Value(_trimToNull(input.category)),
                type: input.type.databaseValue,
                saleMode: input.saleMode.databaseValue,
                basePriceCents: Value(input.basePrice.cents),
                notes: Value(_trimToNull(input.notes)),
                yieldHint: Value(_trimToNull(input.yieldHint)),
                isActive: Value(input.isActive),
                createdAt: Value(now),
                updatedAt: Value(now),
              ),
            );
      } else {
        await (_database.update(
          _database.products,
        )..where((table) => table.id.equals(productId))).write(
          ProductsCompanion(
            name: Value(trimmedName),
            category: Value(_trimToNull(input.category)),
            type: Value(input.type.databaseValue),
            saleMode: Value(input.saleMode.databaseValue),
            basePriceCents: Value(input.basePrice.cents),
            notes: Value(_trimToNull(input.notes)),
            yieldHint: Value(_trimToNull(input.yieldHint)),
            isActive: Value(input.isActive),
            updatedAt: Value(now),
          ),
        );
      }

      await (_database.delete(
        _database.productOptions,
      )..where((table) => table.productId.equals(productId))).go();
      await (_database.delete(
        _database.productRecipeLinks,
      )..where((table) => table.productId.equals(productId))).go();
      await (_database.delete(
        _database.productPackagingLinks,
      )..where((table) => table.productId.equals(productId))).go();

      for (var index = 0; index < normalizedOptions.length; index++) {
        final option = normalizedOptions[index];
        await _database
            .into(_database.productOptions)
            .insert(
              ProductOptionsCompanion.insert(
                id: _uuid.v4(),
                productId: productId,
                type: option.type.databaseValue,
                name: option.name.trim(),
                isActive: Value(option.isActive),
                sortOrder: Value(index),
              ),
            );
      }

      for (var index = 0; index < normalizedRecipeIds.length; index++) {
        await _database
            .into(_database.productRecipeLinks)
            .insert(
              ProductRecipeLinksCompanion.insert(
                id: _uuid.v4(),
                productId: productId,
                recipeId: normalizedRecipeIds[index],
                sortOrder: Value(index),
              ),
            );
      }

      for (var index = 0; index < normalizedPackagingIds.length; index++) {
        final packagingId = normalizedPackagingIds[index];

        await _database
            .into(_database.productPackagingLinks)
            .insert(
              ProductPackagingLinksCompanion.insert(
                id: _uuid.v4(),
                productId: productId,
                packagingId: packagingId,
                isDefaultSuggested: Value(
                  packagingId == defaultSuggestedPackagingId,
                ),
                sortOrder: Value(index),
              ),
            );
      }

      await LocalSyncSupport.markEntityChanged(
        database: _database,
        entityType: RootSyncEntityType.product,
        entityId: productId,
        updatedAt: now,
      );
    });

    return productId;
  }

  Future<List<ProductRecord>> _mapProductList(List<Product> rows) async {
    if (rows.isEmpty) {
      return const [];
    }

    final productIds = rows.map((row) => row.id).toList(growable: false);
    final optionsByProductId = await _loadOptionsByProductIds(productIds);
    final recipesByProductId = await _loadLinkedRecipesByProductIds(productIds);
    final packagingByProductId = await _loadLinkedPackagingsByProductIds(
      productIds,
    );

    return rows
        .map(
          (row) => _mapProductRecord(
            row,
            optionsByProductId[row.id] ?? const [],
            recipesByProductId[row.id] ?? const [],
            packagingByProductId[row.id] ?? const [],
          ),
        )
        .toList(growable: false);
  }

  Future<List<ProductOptionRecord>> _loadOptions(String productId) async {
    final rows =
        await (_database.select(_database.productOptions)
              ..where((table) => table.productId.equals(productId))
              ..orderBy([(table) => OrderingTerm(expression: table.sortOrder)]))
            .get();

    return rows.map(_mapProductOptionRecord).toList(growable: false);
  }

  Future<Map<String, List<ProductOptionRecord>>> _loadOptionsByProductIds(
    List<String> productIds,
  ) async {
    final rows =
        await (_database.select(_database.productOptions)
              ..where((table) => table.productId.isIn(productIds))
              ..orderBy([(table) => OrderingTerm(expression: table.sortOrder)]))
            .get();

    final result = <String, List<ProductOptionRecord>>{};
    for (final row in rows) {
      result
          .putIfAbsent(row.productId, () => [])
          .add(_mapProductOptionRecord(row));
    }

    return result;
  }

  Future<List<ProductLinkedRecipeRecord>> _loadLinkedRecipes(
    String productId,
  ) async {
    final rows =
        await (_database.select(_database.productRecipeLinks).join([
                innerJoin(
                  _database.recipes,
                  _database.recipes.id.equalsExp(
                    _database.productRecipeLinks.recipeId,
                  ),
                ),
              ])
              ..where(_database.productRecipeLinks.productId.equals(productId))
              ..orderBy([
                OrderingTerm(
                  expression: _database.productRecipeLinks.sortOrder,
                ),
              ]))
            .get();

    return rows.map(_mapLinkedRecipeRecord).toList(growable: false);
  }

  Future<Map<String, List<ProductLinkedRecipeRecord>>>
  _loadLinkedRecipesByProductIds(List<String> productIds) async {
    final rows =
        await (_database.select(_database.productRecipeLinks).join([
                innerJoin(
                  _database.recipes,
                  _database.recipes.id.equalsExp(
                    _database.productRecipeLinks.recipeId,
                  ),
                ),
              ])
              ..where(_database.productRecipeLinks.productId.isIn(productIds))
              ..orderBy([
                OrderingTerm(
                  expression: _database.productRecipeLinks.sortOrder,
                ),
              ]))
            .get();

    final result = <String, List<ProductLinkedRecipeRecord>>{};
    for (final row in rows) {
      final link = row.readTable(_database.productRecipeLinks);
      result
          .putIfAbsent(link.productId, () => [])
          .add(_mapLinkedRecipeRecord(row));
    }

    return result;
  }

  Future<List<ProductLinkedPackagingRecord>> _loadLinkedPackagings(
    String productId,
  ) async {
    final rows =
        await (_database.select(_database.productPackagingLinks).join([
                innerJoin(
                  _database.packaging,
                  _database.packaging.id.equalsExp(
                    _database.productPackagingLinks.packagingId,
                  ),
                ),
              ])
              ..where(
                _database.productPackagingLinks.productId.equals(productId),
              )
              ..orderBy([
                OrderingTerm(
                  expression: _database.productPackagingLinks.sortOrder,
                ),
              ]))
            .get();

    return rows.map(_mapLinkedPackagingRecord).toList(growable: false);
  }

  Future<Map<String, List<ProductLinkedPackagingRecord>>>
  _loadLinkedPackagingsByProductIds(List<String> productIds) async {
    final rows =
        await (_database.select(_database.productPackagingLinks).join([
                innerJoin(
                  _database.packaging,
                  _database.packaging.id.equalsExp(
                    _database.productPackagingLinks.packagingId,
                  ),
                ),
              ])
              ..where(
                _database.productPackagingLinks.productId.isIn(productIds),
              )
              ..orderBy([
                OrderingTerm(
                  expression: _database.productPackagingLinks.sortOrder,
                ),
              ]))
            .get();

    final result = <String, List<ProductLinkedPackagingRecord>>{};
    for (final row in rows) {
      final link = row.readTable(_database.productPackagingLinks);
      result
          .putIfAbsent(link.productId, () => [])
          .add(_mapLinkedPackagingRecord(row));
    }

    return result;
  }

  ProductRecord _mapProductRecord(
    Product row,
    List<ProductOptionRecord> options,
    List<ProductLinkedRecipeRecord> linkedRecipes,
    List<ProductLinkedPackagingRecord> linkedPackagings,
  ) {
    return ProductRecord(
      id: row.id,
      name: row.name,
      category: row.category,
      type: ProductType.fromDatabase(row.type),
      saleMode: ProductSaleMode.fromDatabase(row.saleMode),
      basePrice: Money.fromCents(row.basePriceCents),
      notes: row.notes,
      yieldHint: row.yieldHint,
      isActive: row.isActive,
      createdAt: row.createdAt,
      updatedAt: row.updatedAt,
      options: options,
      linkedRecipes: linkedRecipes,
      linkedPackagings: linkedPackagings,
    );
  }

  ProductOptionRecord _mapProductOptionRecord(ProductOption row) {
    return ProductOptionRecord(
      id: row.id,
      productId: row.productId,
      type: ProductOptionType.fromDatabase(row.type),
      name: row.name,
      isActive: row.isActive,
      sortOrder: row.sortOrder,
    );
  }

  ProductLinkedRecipeRecord _mapLinkedRecipeRecord(TypedResult row) {
    final recipe = row.readTable(_database.recipes);

    return ProductLinkedRecipeRecord(
      recipeId: recipe.id,
      recipeName: recipe.name,
      recipeTypeLabel: RecipeType.fromDatabase(recipe.type).label,
      recipeYieldLabel: RecipeYieldUnit.fromDatabase(
        recipe.yieldUnit,
      ).formatAmount(recipe.yieldAmount),
    );
  }

  ProductLinkedPackagingRecord _mapLinkedPackagingRecord(TypedResult row) {
    final link = row.readTable(_database.productPackagingLinks);
    final packaging = row.readTable(_database.packaging);

    return ProductLinkedPackagingRecord(
      packagingId: packaging.id,
      packagingName: packaging.name,
      packagingTypeLabel: PackagingType.fromDatabase(packaging.type).label,
      capacityDescription: packaging.capacityDescription,
      cost: Money.fromCents(packaging.costCents),
      currentStockQuantity: packaging.currentStockQuantity,
      minimumStockQuantity: packaging.minimumStockQuantity,
      isDefaultSuggested: link.isDefaultSuggested,
    );
  }

  String? _trimToNull(String? value) {
    final trimmed = value?.trim();
    if (trimmed == null || trimmed.isEmpty) {
      return null;
    }

    return trimmed;
  }
}
