import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../collaboration/collaboration_definitions.dart';
import '../sync/sync_definitions.dart';

part 'app_database.g.dart';

enum SyncOperation {
  upsert('upsert'),
  delete('delete');

  const SyncOperation(this.value);

  final String value;
}

mixin TeamScopedTable on Table {
  TextColumn get teamId =>
      text().withDefault(const Constant(DefaultCollaborationIds.teamId))();

  TextColumn get updatedByMemberId =>
      text().withDefault(const Constant(DefaultCollaborationIds.memberId))();
}

mixin SyncTrackedTable on Table {
  TextColumn get syncStatus => text().withDefault(const Constant('pending'))();

  DateTimeColumn get lastSyncedAt => dateTime().nullable()();

  TextColumn get syncError => text().nullable()();

  DateTimeColumn get deletedAt => dateTime().nullable()();
}

class SyncQueue extends Table {
  @override
  String get tableName => 'sync_queue';

  TextColumn get id => text()();

  TextColumn get entityType => text()();

  TextColumn get entityId => text()();

  TextColumn get operation => text()();

  TextColumn get payloadJson => text().nullable()();

  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  IntColumn get retryCount => integer().withDefault(const Constant(0))();

  DateTimeColumn get lastAttemptAt => dateTime().nullable()();

  TextColumn get lastError => text().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

class LocalTeams extends Table {
  @override
  String get tableName => 'local_teams';

  TextColumn get id => text()();

  TextColumn get name => text()();

  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

class LocalTeamMembers extends Table {
  @override
  String get tableName => 'local_team_members';

  TextColumn get id => text()();

  TextColumn get teamId => text()();

  TextColumn get displayName => text()();

  TextColumn get role => text()();

  TextColumn get remoteAuthUserId => text().nullable()();

  BoolColumn get isCurrentDeviceMember =>
      boolean().withDefault(const Constant(false))();

  BoolColumn get isActive => boolean().withDefault(const Constant(true))();

  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

class SyncStateRecords extends Table {
  @override
  String get tableName => 'sync_state_records';

  TextColumn get id => text()();

  TextColumn get status => text().withDefault(const Constant('idle'))();

  DateTimeColumn get lastAttemptAt => dateTime().nullable()();

  DateTimeColumn get lastSuccessfulPushAt => dateTime().nullable()();

  DateTimeColumn get lastSuccessfulPullAt => dateTime().nullable()();

  TextColumn get lastError => text().nullable()();

  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

class Orders extends Table with TeamScopedTable, SyncTrackedTable {
  @override
  String get tableName => 'orders';

  TextColumn get id => text()();

  TextColumn get clientId => text().nullable()();

  TextColumn get clientNameSnapshot => text().nullable()();

  DateTimeColumn get eventDate => dateTime().nullable()();

  TextColumn get fulfillmentMethod => text().nullable()();

  IntColumn get deliveryFeeCents => integer().withDefault(const Constant(0))();

  TextColumn get referencePhotoPath => text().nullable()();

  TextColumn get notes => text().nullable()();

  IntColumn get estimatedCostCents =>
      integer().withDefault(const Constant(0))();

  IntColumn get suggestedSalePriceCents =>
      integer().withDefault(const Constant(0))();

  IntColumn get predictedProfitCents =>
      integer().withDefault(const Constant(0))();

  TextColumn get suggestedPackagingId => text().nullable()();

  TextColumn get suggestedPackagingNameSnapshot => text().nullable()();

  TextColumn get smartReviewSummary => text().nullable()();

  IntColumn get orderTotalCents => integer().withDefault(const Constant(0))();

  IntColumn get depositAmountCents =>
      integer().withDefault(const Constant(0))();

  TextColumn get status => text()();

  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

class Clients extends Table with TeamScopedTable, SyncTrackedTable {
  @override
  String get tableName => 'clients';

  TextColumn get id => text()();

  TextColumn get name => text()();

  TextColumn get phone => text().nullable()();

  TextColumn get address => text().nullable()();

  TextColumn get notes => text().nullable()();

  TextColumn get rating => text()();

  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

class ClientImportantDates extends Table {
  @override
  String get tableName => 'client_important_dates';

  TextColumn get id => text()();

  TextColumn get clientId => text()();

  TextColumn get label => text()();

  DateTimeColumn get date => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

class MonthlyPlans extends Table with TeamScopedTable, SyncTrackedTable {
  @override
  String get tableName => 'monthly_plans';

  TextColumn get id => text()();

  TextColumn get clientId => text()();

  TextColumn get clientNameSnapshot => text()();

  TextColumn get title => text()();

  TextColumn get templateProductId => text().nullable()();

  TextColumn get templateProductNameSnapshot => text().nullable()();

  DateTimeColumn get startDate => dateTime()();

  TextColumn get recurrenceType =>
      text().withDefault(const Constant('monthly'))();

  IntColumn get numberOfMonths => integer().withDefault(const Constant(1))();

  IntColumn get contractedQuantity =>
      integer().withDefault(const Constant(1))();

  TextColumn get notes => text().nullable()();

  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

class MonthlyPlanItems extends Table {
  @override
  String get tableName => 'monthly_plan_items';

  TextColumn get id => text()();

  TextColumn get monthlyPlanId => text()();

  TextColumn get linkedProductId => text().nullable()();

  TextColumn get itemNameSnapshot => text()();

  TextColumn get flavorSnapshot => text().nullable()();

  TextColumn get variationSnapshot => text().nullable()();

  IntColumn get unitPriceCents => integer().withDefault(const Constant(0))();

  IntColumn get quantity => integer().withDefault(const Constant(1))();

  TextColumn get notes => text().nullable()();

  IntColumn get sortOrder => integer().withDefault(const Constant(0))();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

class MonthlyPlanOccurrences extends Table {
  @override
  String get tableName => 'monthly_plan_occurrences';

  TextColumn get id => text()();

  TextColumn get monthlyPlanId => text()();

  IntColumn get occurrenceIndex => integer()();

  DateTimeColumn get scheduledDate => dateTime()();

  TextColumn get status => text().withDefault(const Constant('planned'))();

  TextColumn get generatedOrderId => text().nullable()();

  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

class Products extends Table with TeamScopedTable, SyncTrackedTable {
  @override
  String get tableName => 'products';

  TextColumn get id => text()();

  TextColumn get name => text()();

  TextColumn get category => text().nullable()();

  TextColumn get type => text()();

  TextColumn get saleMode => text()();

  IntColumn get basePriceCents => integer().withDefault(const Constant(0))();

  TextColumn get notes => text().nullable()();

  TextColumn get yieldHint => text().nullable()();

  BoolColumn get isActive => boolean().withDefault(const Constant(true))();

  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

class ProductOptions extends Table {
  @override
  String get tableName => 'product_options';

  TextColumn get id => text()();

  TextColumn get productId => text()();

  TextColumn get type => text()();

  TextColumn get name => text()();

  BoolColumn get isActive => boolean().withDefault(const Constant(true))();

  IntColumn get sortOrder => integer().withDefault(const Constant(0))();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

class OrderItems extends Table {
  @override
  String get tableName => 'order_items';

  TextColumn get id => text()();

  TextColumn get orderId => text()();

  TextColumn get productId => text().nullable()();

  TextColumn get itemNameSnapshot => text()();

  TextColumn get flavorSnapshot => text().nullable()();

  TextColumn get variationSnapshot => text().nullable()();

  IntColumn get priceCents => integer().withDefault(const Constant(0))();

  IntColumn get quantity => integer().withDefault(const Constant(1))();

  TextColumn get notes => text().nullable()();

  IntColumn get sortOrder => integer().withDefault(const Constant(0))();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

class OrderProductionPlans extends Table {
  @override
  String get tableName => 'order_production_plans';

  TextColumn get id => text()();

  TextColumn get orderId => text()();

  TextColumn get title => text()();

  TextColumn get details => text().nullable()();

  TextColumn get planType => text().withDefault(const Constant('order'))();

  TextColumn get recipeNameSnapshot => text().nullable()();

  TextColumn get itemNameSnapshot => text().nullable()();

  IntColumn get quantity => integer().withDefault(const Constant(1))();

  TextColumn get notes => text().nullable()();

  TextColumn get status => text()();

  DateTimeColumn get dueDate => dateTime().nullable()();

  DateTimeColumn get completedAt => dateTime().nullable()();

  IntColumn get sortOrder => integer().withDefault(const Constant(0))();

  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

class OrderMaterialNeeds extends Table {
  @override
  String get tableName => 'order_material_needs';

  TextColumn get id => text()();

  TextColumn get orderId => text()();

  TextColumn get materialType => text()();

  TextColumn get linkedEntityId => text().nullable()();

  TextColumn get recipeNameSnapshot => text().nullable()();

  TextColumn get itemNameSnapshot => text().nullable()();

  TextColumn get nameSnapshot => text()();

  TextColumn get unitLabel => text()();

  IntColumn get requiredQuantity => integer()();

  IntColumn get availableQuantity => integer().withDefault(const Constant(0))();

  IntColumn get shortageQuantity => integer().withDefault(const Constant(0))();

  TextColumn get note => text().nullable()();

  DateTimeColumn get consumedAt => dateTime().nullable()();

  TextColumn get consumedByPlanId => text().nullable()();

  IntColumn get sortOrder => integer().withDefault(const Constant(0))();

  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

class PackagingStockMovements extends Table {
  @override
  String get tableName => 'packaging_stock_movements';

  TextColumn get id => text()();

  TextColumn get packagingId => text()();

  TextColumn get movementType => text()();

  IntColumn get quantityDelta => integer()();

  IntColumn get previousStockQuantity => integer()();

  IntColumn get resultingStockQuantity => integer()();

  TextColumn get reason => text()();

  TextColumn get notes => text().nullable()();

  TextColumn get referenceType => text().nullable()();

  TextColumn get referenceId => text().nullable()();

  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

class OrderReceivableEntries extends Table {
  @override
  String get tableName => 'order_receivable_entries';

  TextColumn get id => text()();

  TextColumn get orderId => text()();

  TextColumn get description => text()();

  IntColumn get amountCents => integer().withDefault(const Constant(0))();

  DateTimeColumn get dueDate => dateTime().nullable()();

  TextColumn get status => text()();

  DateTimeColumn get receivedAt => dateTime().nullable()();

  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

class Ingredients extends Table with TeamScopedTable, SyncTrackedTable {
  @override
  String get tableName => 'ingredients';

  TextColumn get id => text()();

  TextColumn get name => text()();

  TextColumn get category => text().nullable()();

  TextColumn get purchaseUnit => text()();

  TextColumn get stockUnit => text()();

  IntColumn get currentStockQuantity =>
      integer().withDefault(const Constant(0))();

  IntColumn get minimumStockQuantity =>
      integer().withDefault(const Constant(0))();

  IntColumn get unitCostCents => integer().withDefault(const Constant(0))();

  TextColumn get defaultSupplier => text().nullable()();

  IntColumn get conversionFactor => integer().withDefault(const Constant(1))();

  TextColumn get notes => text().nullable()();

  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

class Suppliers extends Table with TeamScopedTable, SyncTrackedTable {
  @override
  String get tableName => 'suppliers';

  TextColumn get id => text()();

  TextColumn get name => text()();

  TextColumn get contact => text().nullable()();

  TextColumn get notes => text().nullable()();

  IntColumn get leadTimeDays => integer().nullable()();

  BoolColumn get isActive => boolean().withDefault(const Constant(true))();

  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

class IngredientSupplierLinks extends Table {
  @override
  String get tableName => 'ingredient_supplier_links';

  TextColumn get id => text()();

  TextColumn get ingredientId => text()();

  TextColumn get supplierId => text()();

  BoolColumn get isDefaultPreferred =>
      boolean().withDefault(const Constant(false))();

  IntColumn get sortOrder => integer().withDefault(const Constant(0))();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

class SupplierItemPrices extends Table {
  @override
  String get tableName => 'supplier_item_prices';

  TextColumn get id => text()();

  TextColumn get supplierId => text()();

  TextColumn get itemType => text()();

  TextColumn get linkedItemId => text()();

  TextColumn get itemNameSnapshot => text()();

  TextColumn get unitLabelSnapshot => text().nullable()();

  IntColumn get priceCents => integer().withDefault(const Constant(0))();

  TextColumn get notes => text().nullable()();

  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

class PurchaseEntries extends Table {
  @override
  String get tableName => 'purchase_entries';

  TextColumn get id => text()();

  TextColumn get materialType => text()();

  TextColumn get linkedEntityId => text().nullable()();

  TextColumn get nameSnapshot => text()();

  TextColumn get purchaseUnitLabel => text()();

  TextColumn get stockUnitLabel => text()();

  IntColumn get purchaseQuantity => integer().withDefault(const Constant(1))();

  IntColumn get stockQuantityAdded =>
      integer().withDefault(const Constant(0))();

  TextColumn get supplierId => text().nullable()();

  TextColumn get supplierNameSnapshot => text().nullable()();

  IntColumn get totalPriceCents => integer().withDefault(const Constant(0))();

  TextColumn get note => text().nullable()();

  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

class PurchaseExpenseEntries extends Table {
  @override
  String get tableName => 'purchase_expense_entries';

  TextColumn get id => text()();

  TextColumn get purchaseEntryId => text()();

  TextColumn get description => text()();

  TextColumn get supplierId => text().nullable()();

  TextColumn get supplierNameSnapshot => text().nullable()();

  IntColumn get amountCents => integer().withDefault(const Constant(0))();

  TextColumn get status => text()();

  DateTimeColumn get paidAt => dateTime().nullable()();

  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

class FinanceManualEntries extends Table
    with TeamScopedTable, SyncTrackedTable {
  @override
  String get tableName => 'finance_manual_entries';

  TextColumn get id => text()();

  TextColumn get entryType => text()();

  TextColumn get description => text()();

  IntColumn get amountCents => integer().withDefault(const Constant(0))();

  DateTimeColumn get entryDate => dateTime()();

  TextColumn get category => text().nullable()();

  TextColumn get notes => text().nullable()();

  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

class IngredientStockMovements extends Table {
  @override
  String get tableName => 'ingredient_stock_movements';

  TextColumn get id => text()();

  TextColumn get ingredientId => text()();

  TextColumn get movementType => text()();

  IntColumn get quantityDelta => integer()();

  IntColumn get previousStockQuantity => integer()();

  IntColumn get resultingStockQuantity => integer()();

  TextColumn get reason => text()();

  TextColumn get notes => text().nullable()();

  TextColumn get referenceType => text().nullable()();

  TextColumn get referenceId => text().nullable()();

  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

class Recipes extends Table with TeamScopedTable, SyncTrackedTable {
  @override
  String get tableName => 'recipes';

  TextColumn get id => text()();

  TextColumn get name => text()();

  TextColumn get type => text()();

  IntColumn get yieldAmount => integer()();

  TextColumn get yieldUnit => text()();

  TextColumn get baseLabel => text().nullable()();

  TextColumn get flavorLabel => text().nullable()();

  TextColumn get notes => text().nullable()();

  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

class RecipeItems extends Table {
  @override
  String get tableName => 'recipe_items';

  TextColumn get id => text()();

  TextColumn get recipeId => text()();

  TextColumn get ingredientId => text()();

  TextColumn get ingredientNameSnapshot => text()();

  TextColumn get stockUnitSnapshot => text()();

  IntColumn get quantity => integer()();

  TextColumn get notes => text().nullable()();

  IntColumn get sortOrder => integer().withDefault(const Constant(0))();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

class ProductRecipeLinks extends Table {
  @override
  String get tableName => 'product_recipe_links';

  TextColumn get id => text()();

  TextColumn get productId => text()();

  TextColumn get recipeId => text()();

  IntColumn get sortOrder => integer().withDefault(const Constant(0))();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

class Packaging extends Table with TeamScopedTable, SyncTrackedTable {
  @override
  String get tableName => 'packaging';

  TextColumn get id => text()();

  TextColumn get name => text()();

  TextColumn get type => text()();

  IntColumn get costCents => integer().withDefault(const Constant(0))();

  IntColumn get currentStockQuantity =>
      integer().withDefault(const Constant(0))();

  IntColumn get minimumStockQuantity =>
      integer().withDefault(const Constant(0))();

  TextColumn get capacityDescription => text().nullable()();

  TextColumn get notes => text().nullable()();

  BoolColumn get isActive => boolean().withDefault(const Constant(true))();

  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

class ProductPackagingLinks extends Table {
  @override
  String get tableName => 'product_packaging_links';

  TextColumn get id => text()();

  TextColumn get productId => text()();

  TextColumn get packagingId => text()();

  BoolColumn get isDefaultSuggested =>
      boolean().withDefault(const Constant(false))();

  IntColumn get sortOrder => integer().withDefault(const Constant(0))();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

@DriftDatabase(
  tables: [
    SyncQueue,
    LocalTeams,
    LocalTeamMembers,
    SyncStateRecords,
    Orders,
    Clients,
    ClientImportantDates,
    MonthlyPlans,
    MonthlyPlanItems,
    MonthlyPlanOccurrences,
    Products,
    ProductOptions,
    OrderItems,
    OrderProductionPlans,
    OrderMaterialNeeds,
    OrderReceivableEntries,
    PackagingStockMovements,
    Ingredients,
    Suppliers,
    IngredientSupplierLinks,
    SupplierItemPrices,
    PurchaseEntries,
    PurchaseExpenseEntries,
    FinanceManualEntries,
    IngredientStockMovements,
    Recipes,
    RecipeItems,
    ProductRecipeLinks,
    Packaging,
    ProductPackagingLinks,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase([QueryExecutor? executor])
    : super(
        executor ??
            driftDatabase(
              name: 'doceria_pro',
              web: DriftWebOptions(
                sqlite3Wasm: Uri.parse('sqlite3.wasm'),
                driftWorker: Uri.parse('drift_worker.js'),
              ),
              native: const DriftNativeOptions(shareAcrossIsolates: true),
            ),
      );

  final Uuid _uuid = const Uuid();

  @override
  int get schemaVersion => 14;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (migrator) async {
      await migrator.createAll();
      await _seedLocalDefaults();
    },
    onUpgrade: (migrator, from, to) async {
      if (from < 2) {
        await migrator.createTable(orders);
      }
      if (from < 3) {
        await migrator.createTable(clients);
        await migrator.createTable(clientImportantDates);
        if (from >= 2) {
          await migrator.addColumn(orders, orders.clientId);
        }
      }
      if (from < 4) {
        await migrator.createTable(products);
        await migrator.createTable(productOptions);
        await migrator.createTable(orderItems);
      }
      if (from < 5) {
        await migrator.createTable(ingredients);
        await migrator.createTable(ingredientStockMovements);
      }
      if (from < 6) {
        await migrator.createTable(recipes);
        await migrator.createTable(recipeItems);
        await migrator.createTable(productRecipeLinks);
      }
      if (from < 7) {
        await migrator.createTable(packaging);
        await migrator.createTable(productPackagingLinks);
      }
      if (from < 8) {
        await migrator.addColumn(orders, orders.referencePhotoPath);
        await migrator.addColumn(orders, orders.estimatedCostCents);
        await migrator.addColumn(orders, orders.suggestedSalePriceCents);
        await migrator.addColumn(orders, orders.predictedProfitCents);
        await migrator.addColumn(orders, orders.suggestedPackagingId);
        await migrator.addColumn(orders, orders.suggestedPackagingNameSnapshot);
        await migrator.addColumn(orders, orders.smartReviewSummary);
        await migrator.addColumn(orderItems, orderItems.quantity);
        await migrator.createTable(orderProductionPlans);
        await migrator.createTable(orderMaterialNeeds);
        await migrator.createTable(orderReceivableEntries);
      }
      if (from < 9) {
        await migrator.addColumn(
          orderProductionPlans,
          orderProductionPlans.planType,
        );
        await migrator.addColumn(
          orderProductionPlans,
          orderProductionPlans.recipeNameSnapshot,
        );
        await migrator.addColumn(
          orderProductionPlans,
          orderProductionPlans.itemNameSnapshot,
        );
        await migrator.addColumn(
          orderProductionPlans,
          orderProductionPlans.quantity,
        );
        await migrator.addColumn(
          orderProductionPlans,
          orderProductionPlans.notes,
        );
        await migrator.addColumn(
          orderProductionPlans,
          orderProductionPlans.completedAt,
        );
        await migrator.addColumn(
          orderMaterialNeeds,
          orderMaterialNeeds.recipeNameSnapshot,
        );
        await migrator.addColumn(
          orderMaterialNeeds,
          orderMaterialNeeds.itemNameSnapshot,
        );
        await migrator.addColumn(
          orderMaterialNeeds,
          orderMaterialNeeds.consumedAt,
        );
        await migrator.addColumn(
          orderMaterialNeeds,
          orderMaterialNeeds.consumedByPlanId,
        );
        await migrator.createTable(packagingStockMovements);
      }
      if (from < 10) {
        await migrator.createTable(suppliers);
        await migrator.createTable(ingredientSupplierLinks);
        await migrator.createTable(supplierItemPrices);
      }
      if (from < 11) {
        await migrator.createTable(purchaseEntries);
        await migrator.createTable(purchaseExpenseEntries);
      }
      if (from < 12) {
        await migrator.addColumn(
          orderReceivableEntries,
          orderReceivableEntries.receivedAt,
        );
        await migrator.addColumn(
          purchaseExpenseEntries,
          purchaseExpenseEntries.paidAt,
        );
        await migrator.createTable(financeManualEntries);
        await customStatement('''
          UPDATE order_receivable_entries
          SET received_at = created_at
          WHERE status = 'received' AND received_at IS NULL
        ''');
        await customStatement('''
          UPDATE purchase_expense_entries
          SET paid_at = created_at
          WHERE status = 'paid' AND paid_at IS NULL
        ''');
      }
      if (from < 13) {
        await migrator.createTable(monthlyPlans);
        await migrator.createTable(monthlyPlanItems);
        await migrator.createTable(monthlyPlanOccurrences);
      }
      if (from < 14) {
        await migrator.createTable(localTeams);
        await migrator.createTable(localTeamMembers);
        await migrator.createTable(syncStateRecords);

        await migrator.addColumn(orders, orders.teamId);
        await migrator.addColumn(orders, orders.updatedByMemberId);
        await migrator.addColumn(orders, orders.syncStatus);
        await migrator.addColumn(orders, orders.lastSyncedAt);
        await migrator.addColumn(orders, orders.syncError);
        await migrator.addColumn(orders, orders.deletedAt);

        await migrator.addColumn(clients, clients.teamId);
        await migrator.addColumn(clients, clients.updatedByMemberId);
        await migrator.addColumn(clients, clients.syncStatus);
        await migrator.addColumn(clients, clients.lastSyncedAt);
        await migrator.addColumn(clients, clients.syncError);
        await migrator.addColumn(clients, clients.deletedAt);

        await migrator.addColumn(monthlyPlans, monthlyPlans.teamId);
        await migrator.addColumn(monthlyPlans, monthlyPlans.updatedByMemberId);
        await migrator.addColumn(monthlyPlans, monthlyPlans.syncStatus);
        await migrator.addColumn(monthlyPlans, monthlyPlans.lastSyncedAt);
        await migrator.addColumn(monthlyPlans, monthlyPlans.syncError);
        await migrator.addColumn(monthlyPlans, monthlyPlans.deletedAt);

        await migrator.addColumn(products, products.teamId);
        await migrator.addColumn(products, products.updatedByMemberId);
        await migrator.addColumn(products, products.syncStatus);
        await migrator.addColumn(products, products.lastSyncedAt);
        await migrator.addColumn(products, products.syncError);
        await migrator.addColumn(products, products.deletedAt);

        await migrator.addColumn(ingredients, ingredients.teamId);
        await migrator.addColumn(ingredients, ingredients.updatedByMemberId);
        await migrator.addColumn(ingredients, ingredients.syncStatus);
        await migrator.addColumn(ingredients, ingredients.lastSyncedAt);
        await migrator.addColumn(ingredients, ingredients.syncError);
        await migrator.addColumn(ingredients, ingredients.deletedAt);

        await migrator.addColumn(recipes, recipes.teamId);
        await migrator.addColumn(recipes, recipes.updatedByMemberId);
        await migrator.addColumn(recipes, recipes.syncStatus);
        await migrator.addColumn(recipes, recipes.lastSyncedAt);
        await migrator.addColumn(recipes, recipes.syncError);
        await migrator.addColumn(recipes, recipes.deletedAt);

        await migrator.addColumn(packaging, packaging.teamId);
        await migrator.addColumn(packaging, packaging.updatedByMemberId);
        await migrator.addColumn(packaging, packaging.syncStatus);
        await migrator.addColumn(packaging, packaging.lastSyncedAt);
        await migrator.addColumn(packaging, packaging.syncError);
        await migrator.addColumn(packaging, packaging.deletedAt);

        await migrator.addColumn(suppliers, suppliers.teamId);
        await migrator.addColumn(suppliers, suppliers.updatedByMemberId);
        await migrator.addColumn(suppliers, suppliers.syncStatus);
        await migrator.addColumn(suppliers, suppliers.lastSyncedAt);
        await migrator.addColumn(suppliers, suppliers.syncError);
        await migrator.addColumn(suppliers, suppliers.deletedAt);

        await migrator.addColumn(
          financeManualEntries,
          financeManualEntries.teamId,
        );
        await migrator.addColumn(
          financeManualEntries,
          financeManualEntries.updatedByMemberId,
        );
        await migrator.addColumn(
          financeManualEntries,
          financeManualEntries.syncStatus,
        );
        await migrator.addColumn(
          financeManualEntries,
          financeManualEntries.lastSyncedAt,
        );
        await migrator.addColumn(
          financeManualEntries,
          financeManualEntries.syncError,
        );
        await migrator.addColumn(
          financeManualEntries,
          financeManualEntries.deletedAt,
        );

        await _seedLocalDefaults();
      }
    },
  );

  Future<void> enqueueSyncTask({
    required String entityType,
    required String entityId,
    required SyncOperation operation,
    String? payloadJson,
  }) async {
    await (delete(syncQueue)..where(
          (table) =>
              table.entityType.equals(entityType) &
              table.entityId.equals(entityId),
        ))
        .go();

    await into(syncQueue).insert(
      SyncQueueCompanion.insert(
        id: _uuid.v4(),
        entityType: entityType,
        entityId: entityId,
        operation: operation.value,
        payloadJson: Value(payloadJson),
      ),
    );
  }

  Future<void> upsertSyncStateRecord({
    required SyncRunStatus status,
    Value<DateTime?> lastAttemptAt = const Value.absent(),
    Value<DateTime?> lastSuccessfulPushAt = const Value.absent(),
    Value<DateTime?> lastSuccessfulPullAt = const Value.absent(),
    Value<String?> lastError = const Value.absent(),
  }) async {
    final now = DateTime.now();
    await into(syncStateRecords).insertOnConflictUpdate(
      SyncStateRecordsCompanion(
        id: const Value(DefaultCollaborationIds.syncStateId),
        status: Value(status.databaseValue),
        lastAttemptAt: lastAttemptAt,
        lastSuccessfulPushAt: lastSuccessfulPushAt,
        lastSuccessfulPullAt: lastSuccessfulPullAt,
        lastError: lastError,
        updatedAt: Value(now),
      ),
    );
  }

  Future<void> _seedLocalDefaults() async {
    final now = DateTime.now();
    await into(localTeams).insertOnConflictUpdate(
      LocalTeamsCompanion.insert(
        id: DefaultCollaborationIds.teamId,
        name: 'Equipe principal',
        createdAt: Value(now),
        updatedAt: Value(now),
      ),
    );
    await into(localTeamMembers).insertOnConflictUpdate(
      LocalTeamMembersCompanion.insert(
        id: DefaultCollaborationIds.memberId,
        teamId: DefaultCollaborationIds.teamId,
        displayName: 'Proprietária deste aparelho',
        role: TeamRole.owner.databaseValue,
        remoteAuthUserId: const Value(null),
        isCurrentDeviceMember: const Value(true),
        isActive: const Value(true),
        createdAt: Value(now),
        updatedAt: Value(now),
      ),
    );
    await into(syncStateRecords).insertOnConflictUpdate(
      SyncStateRecordsCompanion(
        id: const Value(DefaultCollaborationIds.syncStateId),
        status: Value(SyncRunStatus.idle.databaseValue),
        updatedAt: Value(now),
      ),
    );
  }
}

final appDatabaseProvider = Provider<AppDatabase>((ref) {
  final database = AppDatabase();
  ref.onDispose(database.close);
  return database;
});
