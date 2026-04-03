import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
import '../../ingredients/application/ingredient_providers.dart';
import '../../products/application/product_providers.dart';
import '../../recipes/application/recipe_providers.dart';
import 'order_smart_review_service.dart';
import '../data/orders_repository.dart';
import '../domain/order.dart';
import '../domain/order_list_filters.dart';
import '../domain/order_status.dart';

final ordersRepositoryProvider = Provider<OrdersRepository>((ref) {
  return OrdersRepository(ref.watch(appDatabaseProvider));
});

final orderSmartReviewServiceProvider = Provider<OrderSmartReviewService>((
  ref,
) {
  return OrderSmartReviewService(
    productsRepository: ref.watch(productsRepositoryProvider),
    recipesRepository: ref.watch(recipesRepositoryProvider),
    ingredientsRepository: ref.watch(ingredientsRepositoryProvider),
  );
});

class OrderListFiltersNotifier extends Notifier<OrderListFilters> {
  @override
  OrderListFilters build() => const OrderListFilters();

  void updateSearchQuery(String value) {
    state = state.copyWith(searchQuery: value);
  }

  void updateStatus(OrderStatus? status) {
    if (status == null) {
      state = state.copyWith(clearStatus: true);
      return;
    }

    state = state.copyWith(status: status);
  }

  void clear() {
    state = const OrderListFilters();
  }
}

final orderListFiltersProvider =
    NotifierProvider<OrderListFiltersNotifier, OrderListFilters>(
      OrderListFiltersNotifier.new,
    );

final ordersProvider = StreamProvider<List<OrderRecord>>((ref) {
  return ref.watch(ordersRepositoryProvider).watchOrders();
});

final filteredOrdersProvider = Provider<AsyncValue<List<OrderRecord>>>((ref) {
  final filters = ref.watch(orderListFiltersProvider);
  final ordersAsync = ref.watch(ordersProvider);

  return ordersAsync.whenData(filters.apply);
});

final groupedOrdersProvider = Provider<AsyncValue<List<OrderDateGroup>>>((ref) {
  final filteredOrdersAsync = ref.watch(filteredOrdersProvider);

  return filteredOrdersAsync.whenData(buildOrderDateGroups);
});

final orderProvider = StreamProvider.autoDispose.family<OrderRecord?, String>((
  ref,
  orderId,
) {
  return ref.watch(ordersRepositoryProvider).watchOrder(orderId);
});
