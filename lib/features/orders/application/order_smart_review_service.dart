import '../../../core/money/money.dart';
import '../../ingredients/data/ingredients_repository.dart';
import '../../products/data/products_repository.dart';
import '../../products/domain/product.dart';
import '../../recipes/data/recipes_repository.dart';
import '../../recipes/domain/recipe_cost_calculator.dart';
import '../domain/order.dart';
import '../domain/order_fulfillment_method.dart';

class OrderSmartReviewRequest {
  const OrderSmartReviewRequest({
    required this.clientId,
    required this.clientNameSnapshot,
    required this.eventDate,
    required this.fulfillmentMethod,
    required this.productId,
    required this.quantity,
    required this.deliveryFee,
    required this.salePriceOverride,
    required this.depositAmount,
    required this.notes,
    required this.referencePhotoPath,
  });

  final String? clientId;
  final String? clientNameSnapshot;
  final DateTime? eventDate;
  final OrderFulfillmentMethod? fulfillmentMethod;
  final String? productId;
  final int quantity;
  final Money deliveryFee;
  final Money salePriceOverride;
  final Money depositAmount;
  final String? notes;
  final String? referencePhotoPath;
}

class OrderSmartReviewResult {
  const OrderSmartReviewResult({
    required this.product,
    required this.primaryItem,
    required this.estimatedCost,
    required this.suggestedSalePrice,
    required this.selectedSalePrice,
    required this.orderTotal,
    required this.predictedProfit,
    required this.suggestedPackaging,
    required this.limitations,
    required this.productionPlans,
    required this.materialNeeds,
    required this.receivableEntries,
  });

  final ProductRecord? product;
  final OrderItemInput primaryItem;
  final Money estimatedCost;
  final Money suggestedSalePrice;
  final Money selectedSalePrice;
  final Money orderTotal;
  final Money predictedProfit;
  final ProductLinkedPackagingRecord? suggestedPackaging;
  final List<String> limitations;
  final List<OrderProductionPlanInput> productionPlans;
  final List<OrderMaterialNeedInput> materialNeeds;
  final List<OrderReceivableEntryInput> receivableEntries;

  bool get hasProduct => product != null;

  bool get hasSuggestedPackaging => suggestedPackaging != null;

  bool get hasLimitations => limitations.isNotEmpty;

  List<OrderMaterialNeedInput> get shortages => materialNeeds
      .where((need) => need.shortageQuantity > 0)
      .toList(growable: false);

  String get smartReviewSummary {
    if (limitations.isEmpty) {
      return 'Pedido revisado com dados locais de produto, custo e materiais.';
    }

    return limitations.join(' ');
  }

  String get depositStateLabel {
    if (depositAmount.isZero) {
      return 'Sem sinal';
    }
    if (orderTotal.isPositive && depositAmount.cents >= orderTotal.cents) {
      return 'Sinal coberto';
    }

    return 'Sinal parcial';
  }

  Money get depositAmount {
    if (receivableEntries.isEmpty) {
      return Money.zero;
    }

    final receivedEntry = receivableEntries.firstWhere(
      (entry) => entry.status == OrderReceivableStatus.received,
      orElse: () => const OrderReceivableEntryInput(
        description: '',
        amount: Money.zero,
        dueDate: null,
        status: OrderReceivableStatus.pending,
      ),
    );
    return receivedEntry.amount;
  }

  String? get suggestedPackagingNameSnapshot =>
      suggestedPackaging?.packagingName;

  String? get suggestedPackagingId => suggestedPackaging?.packagingId;
}

class OrderSmartReviewService {
  OrderSmartReviewService({
    required ProductsRepository productsRepository,
    required RecipesRepository recipesRepository,
    required IngredientsRepository ingredientsRepository,
  }) : _productsRepository = productsRepository,
       _recipesRepository = recipesRepository,
       _ingredientsRepository = ingredientsRepository;

  final ProductsRepository _productsRepository;
  final RecipesRepository _recipesRepository;
  final IngredientsRepository _ingredientsRepository;

  Future<OrderSmartReviewResult> buildReview(
    OrderSmartReviewRequest request,
  ) async {
    final limitations = <String>[];
    final normalizedQuantity = request.quantity <= 0 ? 1 : request.quantity;
    final product = request.productId == null
        ? null
        : await _productsRepository.getProduct(request.productId!);

    if (request.productId != null && product == null) {
      limitations.add(
        'O produto ligado a este pedido não foi encontrado. O pedido continua salvo pelo retrato local.',
      );
    }

    final primaryItem = OrderItemInput(
      productId: product?.id,
      itemNameSnapshot: product?.name ?? 'Item do pedido',
      flavorSnapshot: null,
      variationSnapshot: null,
      price: _resolveUnitPrice(product, normalizedQuantity, request),
      quantity: normalizedQuantity,
      notes: null,
    );

    final materialNeeds = <OrderMaterialNeedInput>[];
    final productionPlans = <OrderProductionPlanInput>[];
    var estimatedCost = Money.zero;

    if (product != null) {
      productionPlans.add(
        OrderProductionPlanInput(
          title: 'Organizar produção de ${product.name}',
          details: _buildProductionDetails(
            quantity: normalizedQuantity,
            fulfillmentMethod: request.fulfillmentMethod,
          ),
          planType: OrderProductionPlanType.order,
          itemNameSnapshot: product.name,
          quantity: normalizedQuantity,
          notes: request.notes,
          status: OrderProductionPlanStatus.pending,
          dueDate: request.eventDate,
          sortOrder: productionPlans.length,
        ),
      );

      final recipeResult = await _buildRecipeNeeds(
        product: product,
        quantity: normalizedQuantity,
        eventDate: request.eventDate,
      );
      estimatedCost += recipeResult.estimatedCost;
      materialNeeds.addAll(recipeResult.materialNeeds);
      productionPlans.addAll(recipeResult.productionPlans);
      limitations.addAll(recipeResult.limitations);

      final packaging =
          product.defaultSuggestedPackaging ??
          (product.linkedPackagings.isEmpty
              ? null
              : product.linkedPackagings.first);
      if (packaging != null) {
        estimatedCost += packaging.cost.multiply(normalizedQuantity);
        materialNeeds.add(
          OrderMaterialNeedInput(
            materialType: OrderMaterialType.packaging,
            linkedEntityId: packaging.packagingId,
            itemNameSnapshot: product.name,
            nameSnapshot: packaging.packagingName,
            unitLabel: 'un',
            requiredQuantity: normalizedQuantity,
            availableQuantity: packaging.currentStockQuantity,
            shortageQuantity:
                normalizedQuantity > packaging.currentStockQuantity
                ? normalizedQuantity - packaging.currentStockQuantity
                : 0,
            note: packaging.capacityDescription,
            sortOrder: materialNeeds.length,
          ),
        );
        productionPlans.add(
          OrderProductionPlanInput(
            title: 'Separar embalagem sugerida',
            details: '${packaging.packagingName} • $normalizedQuantity un',
            planType: OrderProductionPlanType.packaging,
            itemNameSnapshot: product.name,
            quantity: normalizedQuantity,
            notes: packaging.capacityDescription,
            status: OrderProductionPlanStatus.pending,
            dueDate: request.eventDate,
            sortOrder: productionPlans.length,
          ),
        );
      } else {
        limitations.add(
          'Este produto ainda não tem embalagem sugerida cadastrada, então a previsão não inclui embalagem.',
        );
      }
    } else {
      limitations.add(
        'Sem produto ligado, a previsão automática de custo e materiais fica limitada.',
      );
    }

    final suggestedSalePrice = _resolveSuggestedSalePrice(
      product: product,
      estimatedCost: estimatedCost,
      quantity: normalizedQuantity,
    );
    final selectedSalePrice = request.salePriceOverride.isPositive
        ? request.salePriceOverride
        : suggestedSalePrice;
    final orderTotal = selectedSalePrice + request.deliveryFee;
    final predictedProfit = orderTotal - estimatedCost;
    final receivableEntries = _buildReceivableEntries(
      orderTotal: orderTotal,
      depositAmount: request.depositAmount,
      eventDate: request.eventDate,
    );

    if (selectedSalePrice.isZero) {
      limitations.add(
        'Ainda não foi possível sugerir um valor de venda consistente. Revise o produto ou digite o valor manualmente.',
      );
    }

    return OrderSmartReviewResult(
      product: product,
      primaryItem: primaryItem.copyWith(
        price: selectedSalePrice.isPositive
            ? selectedSalePrice.divide(normalizedQuantity)
            : primaryItem.price,
      ),
      estimatedCost: estimatedCost,
      suggestedSalePrice: suggestedSalePrice,
      selectedSalePrice: selectedSalePrice,
      orderTotal: orderTotal,
      predictedProfit: predictedProfit,
      suggestedPackaging:
          product?.defaultSuggestedPackaging ??
          (product?.linkedPackagings.isEmpty ?? true
              ? null
              : product!.linkedPackagings.first),
      limitations: limitations.toSet().toList(growable: false),
      productionPlans: productionPlans
          .asMap()
          .entries
          .map((entry) => entry.value.copyWith(sortOrder: entry.key))
          .toList(growable: false),
      materialNeeds: materialNeeds
          .asMap()
          .entries
          .map((entry) => entry.value.copyWith(sortOrder: entry.key))
          .toList(growable: false),
      receivableEntries: receivableEntries,
    );
  }

  Money _resolveUnitPrice(
    ProductRecord? product,
    int quantity,
    OrderSmartReviewRequest request,
  ) {
    if (request.salePriceOverride.isPositive) {
      return request.salePriceOverride.divide(quantity);
    }
    if (product != null && product.basePrice.isPositive) {
      return product.basePrice;
    }

    return Money.zero;
  }

  Money _resolveSuggestedSalePrice({
    required ProductRecord? product,
    required Money estimatedCost,
    required int quantity,
  }) {
    if (product != null && product.basePrice.isPositive) {
      return product.basePrice.multiply(quantity);
    }

    if (estimatedCost.isPositive) {
      return estimatedCost.multiplyRatio(18, 10);
    }

    return Money.zero;
  }

  Future<_RecipeNeedsResult> _buildRecipeNeeds({
    required ProductRecord product,
    required int quantity,
    required DateTime? eventDate,
  }) async {
    final materialNeedsByKey = <String, OrderMaterialNeedInput>{};
    final productionPlans = <OrderProductionPlanInput>[];
    final limitations = <String>[];
    var estimatedCost = Money.zero;

    if (product.linkedRecipes.isEmpty) {
      limitations.add(
        'Este produto ainda não tem receita ligada, então o custo estimado fica parcial.',
      );
      return _RecipeNeedsResult(
        estimatedCost: estimatedCost,
        materialNeeds: const [],
        productionPlans: const [],
        limitations: limitations,
      );
    }

    for (final linkedRecipe in product.linkedRecipes) {
      final recipe = await _recipesRepository.getRecipe(linkedRecipe.recipeId);
      if (recipe == null) {
        limitations.add(
          'A receita ${linkedRecipe.recipeName} não foi encontrada e ficou fora do cálculo.',
        );
        continue;
      }

      productionPlans.add(
        OrderProductionPlanInput(
          title: 'Produzir ${recipe.name}',
          details: '${recipe.displayYield} de base para $quantity un do pedido',
          planType: OrderProductionPlanType.recipe,
          recipeNameSnapshot: recipe.name,
          itemNameSnapshot: product.name,
          quantity: quantity,
          notes: recipe.structureSummary,
          status: OrderProductionPlanStatus.pending,
          dueDate: eventDate,
          sortOrder: productionPlans.length,
        ),
      );

      for (final item in recipe.items) {
        final ingredient = await _ingredientsRepository.getIngredient(
          item.ingredientId,
        );
        final requiredQuantity = _ceilMultiplyDivide(
          item.quantity,
          quantity,
          recipe.yieldAmount,
        );

        if (ingredient == null) {
          limitations.add(
            'O ingrediente ${item.ingredientNameSnapshot} não foi encontrado, então parte da previsão pode ficar incompleta.',
          );
          materialNeedsByKey['${recipe.id}:${item.ingredientId}'] =
              OrderMaterialNeedInput(
                materialType: OrderMaterialType.ingredient,
                linkedEntityId: item.ingredientId,
                recipeNameSnapshot: recipe.name,
                itemNameSnapshot: product.name,
                nameSnapshot: item.ingredientNameSnapshot,
                unitLabel: item.stockUnit.shortLabel,
                requiredQuantity: requiredQuantity,
                availableQuantity: 0,
                shortageQuantity: requiredQuantity,
                note: 'Cadastro do ingrediente indisponível',
                sortOrder: materialNeedsByKey.length,
              );
          continue;
        }

        estimatedCost += RecipeCostCalculator.calculateLineCost(
          ingredient: ingredient,
          quantityInStockUnit: requiredQuantity,
        );

        final materialNeedKey = '${recipe.id}:${ingredient.id}';
        final existing = materialNeedsByKey[materialNeedKey];
        final totalRequired =
            (existing?.requiredQuantity ?? 0) + requiredQuantity;
        final availableQuantity = ingredient.currentStockQuantity;
        final shortageQuantity = totalRequired > availableQuantity
            ? totalRequired - availableQuantity
            : 0;

        materialNeedsByKey[materialNeedKey] = OrderMaterialNeedInput(
          materialType: OrderMaterialType.ingredient,
          linkedEntityId: ingredient.id,
          recipeNameSnapshot: recipe.name,
          itemNameSnapshot: product.name,
          nameSnapshot: ingredient.name,
          unitLabel: ingredient.stockUnit.shortLabel,
          requiredQuantity: totalRequired,
          availableQuantity: availableQuantity,
          shortageQuantity: shortageQuantity,
          note: ingredient.isLowStock
              ? 'O estoque já está no limite mínimo.'
              : null,
          sortOrder: existing?.sortOrder ?? materialNeedsByKey.length,
        );
      }
    }

    return _RecipeNeedsResult(
      estimatedCost: estimatedCost,
      materialNeeds: materialNeedsByKey.values.toList(growable: false),
      productionPlans: productionPlans,
      limitations: limitations,
    );
  }

  List<OrderReceivableEntryInput> _buildReceivableEntries({
    required Money orderTotal,
    required Money depositAmount,
    required DateTime? eventDate,
  }) {
    if (orderTotal.isZero) {
      return const [];
    }

    if (depositAmount.isZero) {
      return [
        OrderReceivableEntryInput(
          description: 'Pedido confirmado',
          amount: orderTotal,
          dueDate: eventDate,
          status: OrderReceivableStatus.pending,
        ),
      ];
    }

    final entries = <OrderReceivableEntryInput>[
      OrderReceivableEntryInput(
        description: 'Sinal do pedido',
        amount: depositAmount,
        dueDate: eventDate,
        status: OrderReceivableStatus.received,
      ),
    ];
    final remainingAmount = orderTotal - depositAmount;
    if (remainingAmount.isPositive) {
      entries.add(
        OrderReceivableEntryInput(
          description: 'Saldo restante do pedido',
          amount: remainingAmount,
          dueDate: eventDate,
          status: OrderReceivableStatus.pending,
        ),
      );
    }

    return entries;
  }

  String _buildProductionDetails({
    required int quantity,
    required OrderFulfillmentMethod? fulfillmentMethod,
  }) {
    final segments = <String>[
      '$quantity ${quantity == 1 ? 'unidade' : 'unidades'}',
      if (fulfillmentMethod != null) fulfillmentMethod.label,
    ];

    return segments.join(' • ');
  }

  int _ceilMultiplyDivide(int left, int right, int divisor) {
    if (left <= 0 || right <= 0 || divisor <= 0) {
      return 0;
    }

    return (left * right + divisor - 1) ~/ divisor;
  }
}

class _RecipeNeedsResult {
  const _RecipeNeedsResult({
    required this.estimatedCost,
    required this.materialNeeds,
    required this.productionPlans,
    required this.limitations,
  });

  final Money estimatedCost;
  final List<OrderMaterialNeedInput> materialNeeds;
  final List<OrderProductionPlanInput> productionPlans;
  final List<String> limitations;
}

extension on OrderItemInput {
  OrderItemInput copyWith({
    String? id,
    String? productId,
    String? itemNameSnapshot,
    String? flavorSnapshot,
    String? variationSnapshot,
    Money? price,
    int? quantity,
    String? notes,
  }) {
    return OrderItemInput(
      id: id ?? this.id,
      productId: productId ?? this.productId,
      itemNameSnapshot: itemNameSnapshot ?? this.itemNameSnapshot,
      flavorSnapshot: flavorSnapshot ?? this.flavorSnapshot,
      variationSnapshot: variationSnapshot ?? this.variationSnapshot,
      price: price ?? this.price,
      quantity: quantity ?? this.quantity,
      notes: notes ?? this.notes,
    );
  }
}

extension on OrderProductionPlanInput {
  OrderProductionPlanInput copyWith({
    String? id,
    String? title,
    String? details,
    OrderProductionPlanType? planType,
    String? recipeNameSnapshot,
    String? itemNameSnapshot,
    int? quantity,
    String? notes,
    OrderProductionPlanStatus? status,
    DateTime? dueDate,
    DateTime? completedAt,
    int? sortOrder,
  }) {
    return OrderProductionPlanInput(
      id: id ?? this.id,
      title: title ?? this.title,
      details: details ?? this.details,
      planType: planType ?? this.planType,
      recipeNameSnapshot: recipeNameSnapshot ?? this.recipeNameSnapshot,
      itemNameSnapshot: itemNameSnapshot ?? this.itemNameSnapshot,
      quantity: quantity ?? this.quantity,
      notes: notes ?? this.notes,
      status: status ?? this.status,
      dueDate: dueDate ?? this.dueDate,
      completedAt: completedAt ?? this.completedAt,
      sortOrder: sortOrder ?? this.sortOrder,
    );
  }
}

extension on OrderMaterialNeedInput {
  OrderMaterialNeedInput copyWith({
    String? id,
    OrderMaterialType? materialType,
    String? linkedEntityId,
    String? recipeNameSnapshot,
    String? itemNameSnapshot,
    String? nameSnapshot,
    String? unitLabel,
    int? requiredQuantity,
    int? availableQuantity,
    int? shortageQuantity,
    String? note,
    DateTime? consumedAt,
    String? consumedByPlanId,
    int? sortOrder,
  }) {
    return OrderMaterialNeedInput(
      id: id ?? this.id,
      materialType: materialType ?? this.materialType,
      linkedEntityId: linkedEntityId ?? this.linkedEntityId,
      recipeNameSnapshot: recipeNameSnapshot ?? this.recipeNameSnapshot,
      itemNameSnapshot: itemNameSnapshot ?? this.itemNameSnapshot,
      nameSnapshot: nameSnapshot ?? this.nameSnapshot,
      unitLabel: unitLabel ?? this.unitLabel,
      requiredQuantity: requiredQuantity ?? this.requiredQuantity,
      availableQuantity: availableQuantity ?? this.availableQuantity,
      shortageQuantity: shortageQuantity ?? this.shortageQuantity,
      note: note ?? this.note,
      consumedAt: consumedAt ?? this.consumedAt,
      consumedByPlanId: consumedByPlanId ?? this.consumedByPlanId,
      sortOrder: sortOrder ?? this.sortOrder,
    );
  }
}
