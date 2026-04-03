import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/business_settings/presentation/business_settings_page.dart';
import '../../features/clients/presentation/client_details_page.dart';
import '../../features/clients/presentation/client_form_page.dart';
import '../../features/clients/presentation/clients_page.dart';
import '../../features/commercial/presentation/business_brand_settings_page.dart';
import '../../features/commercial/presentation/order_quote_preview_page.dart';
import '../../features/cost_benefit/presentation/cost_benefit_comparator_page.dart';
import '../../features/dashboard/presentation/dashboard_page.dart';
import '../../features/finance/presentation/finance_page.dart';
import '../../features/monthly_plans/presentation/monthly_plan_details_page.dart';
import '../../features/monthly_plans/presentation/monthly_plan_form_page.dart';
import '../../features/monthly_plans/presentation/monthly_plans_page.dart';
import '../../features/orders/presentation/order_details_page.dart';
import '../../features/orders/presentation/order_form_page.dart';
import '../../features/orders/presentation/orders_page.dart';
import '../../features/packaging/presentation/packaging_details_page.dart';
import '../../features/packaging/presentation/packaging_form_page.dart';
import '../../features/packaging/presentation/packaging_page.dart';
import '../../features/production/presentation/production_page.dart';
import '../../features/ingredients/presentation/ingredient_details_page.dart';
import '../../features/ingredients/presentation/ingredient_form_page.dart';
import '../../features/ingredients/presentation/ingredient_stock_adjustment_page.dart';
import '../../features/ingredients/presentation/ingredients_page.dart';
import '../../features/products/presentation/product_details_page.dart';
import '../../features/products/presentation/product_form_page.dart';
import '../../features/products/presentation/products_page.dart';
import '../../features/purchases/presentation/purchases_page.dart';
import '../../features/recipes/presentation/recipe_details_page.dart';
import '../../features/recipes/presentation/recipe_form_page.dart';
import '../../features/recipes/presentation/recipes_page.dart';
import '../../features/suppliers/presentation/supplier_details_page.dart';
import '../../features/suppliers/presentation/supplier_form_page.dart';
import '../../features/suppliers/presentation/suppliers_page.dart';
import '../shell/app_shell.dart';
import 'app_destinations.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  final router = GoRouter(
    initialLocation: AppDestinations.dashboard.path,
    routes: [
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) {
          return AppShell(navigationShell: navigationShell);
        },
        branches: [
          _branch(AppDestinations.dashboard.path, const DashboardPage()),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppDestinations.orders.path,
                pageBuilder: (context, state) =>
                    const NoTransitionPage<void>(child: OrdersPage()),
                routes: [
                  GoRoute(
                    path: 'new',
                    pageBuilder: (context, state) =>
                        const NoTransitionPage<void>(child: OrderFormPage()),
                  ),
                  GoRoute(
                    path: ':orderId',
                    pageBuilder: (context, state) => NoTransitionPage<void>(
                      child: OrderDetailsPage(
                        orderId: state.pathParameters['orderId']!,
                      ),
                    ),
                    routes: [
                      GoRoute(
                        path: 'edit',
                        pageBuilder: (context, state) => NoTransitionPage<void>(
                          child: OrderFormPage(
                            orderId: state.pathParameters['orderId']!,
                          ),
                        ),
                      ),
                      GoRoute(
                        path: 'quote',
                        pageBuilder: (context, state) => NoTransitionPage<void>(
                          child: OrderQuotePreviewPage(
                            orderId: state.pathParameters['orderId']!,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
          _branch(AppDestinations.production.path, const ProductionPage()),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppDestinations.purchases.path,
                pageBuilder: (context, state) =>
                    const NoTransitionPage<void>(child: PurchasesPage()),
                routes: [
                  GoRoute(
                    path: 'comparator',
                    pageBuilder: (context, state) => NoTransitionPage<void>(
                      child: CostBenefitComparatorPage(
                        ingredientId: state.uri.queryParameters['ingredientId'],
                      ),
                    ),
                  ),
                  GoRoute(
                    path: 'stock',
                    pageBuilder: (context, state) =>
                        const NoTransitionPage<void>(child: IngredientsPage()),
                    routes: [
                      GoRoute(
                        path: 'new',
                        pageBuilder: (context, state) =>
                            NoTransitionPage<void>(child: IngredientFormPage()),
                      ),
                      GoRoute(
                        path: ':ingredientId',
                        pageBuilder: (context, state) => NoTransitionPage<void>(
                          child: IngredientDetailsPage(
                            ingredientId: state.pathParameters['ingredientId']!,
                          ),
                        ),
                        routes: [
                          GoRoute(
                            path: 'edit',
                            pageBuilder: (context, state) =>
                                NoTransitionPage<void>(
                                  child: IngredientFormPage(
                                    ingredientId:
                                        state.pathParameters['ingredientId']!,
                                  ),
                                ),
                          ),
                          GoRoute(
                            path: 'adjust',
                            pageBuilder: (context, state) =>
                                NoTransitionPage<void>(
                                  child: IngredientStockAdjustmentPage(
                                    ingredientId:
                                        state.pathParameters['ingredientId']!,
                                  ),
                                ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
          _branch(AppDestinations.finance.path, const FinancePage()),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppDestinations.clients.path,
                pageBuilder: (context, state) =>
                    const NoTransitionPage<void>(child: ClientsPage()),
                routes: [
                  GoRoute(
                    path: 'monthly-plans',
                    pageBuilder: (context, state) =>
                        const NoTransitionPage<void>(child: MonthlyPlansPage()),
                    routes: [
                      GoRoute(
                        path: 'new',
                        pageBuilder: (context, state) => NoTransitionPage<void>(
                          child: MonthlyPlanFormPage(
                            initialClientId:
                                state.uri.queryParameters['clientId'],
                            initialClientName:
                                state.uri.queryParameters['clientName'],
                          ),
                        ),
                      ),
                      GoRoute(
                        path: ':monthlyPlanId',
                        pageBuilder: (context, state) => NoTransitionPage<void>(
                          child: MonthlyPlanDetailsPage(
                            monthlyPlanId:
                                state.pathParameters['monthlyPlanId']!,
                          ),
                        ),
                        routes: [
                          GoRoute(
                            path: 'edit',
                            pageBuilder: (context, state) =>
                                NoTransitionPage<void>(
                                  child: MonthlyPlanFormPage(
                                    monthlyPlanId:
                                        state.pathParameters['monthlyPlanId']!,
                                  ),
                                ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  GoRoute(
                    path: 'new',
                    pageBuilder: (context, state) =>
                        const NoTransitionPage<void>(child: ClientFormPage()),
                  ),
                  GoRoute(
                    path: ':clientId',
                    pageBuilder: (context, state) => NoTransitionPage<void>(
                      child: ClientDetailsPage(
                        clientId: state.pathParameters['clientId']!,
                      ),
                    ),
                    routes: [
                      GoRoute(
                        path: 'edit',
                        pageBuilder: (context, state) => NoTransitionPage<void>(
                          child: ClientFormPage(
                            clientId: state.pathParameters['clientId']!,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppDestinations.businessSettings.path,
                pageBuilder: (context, state) =>
                    const NoTransitionPage<void>(child: BusinessSettingsPage()),
                routes: [
                  GoRoute(
                    path: 'commercial',
                    pageBuilder: (context, state) =>
                        const NoTransitionPage<void>(
                          child: BusinessBrandSettingsPage(),
                        ),
                  ),
                  GoRoute(
                    path: 'packaging',
                    pageBuilder: (context, state) =>
                        const NoTransitionPage<void>(child: PackagingPage()),
                    routes: [
                      GoRoute(
                        path: 'low-stock',
                        pageBuilder: (context, state) =>
                            const NoTransitionPage<void>(
                              child: PackagingLowStockPage(),
                            ),
                      ),
                      GoRoute(
                        path: 'new',
                        pageBuilder: (context, state) =>
                            const NoTransitionPage<void>(
                              child: PackagingFormPage(),
                            ),
                      ),
                      GoRoute(
                        path: ':packagingId',
                        pageBuilder: (context, state) => NoTransitionPage<void>(
                          child: PackagingDetailsPage(
                            packagingId: state.pathParameters['packagingId']!,
                          ),
                        ),
                        routes: [
                          GoRoute(
                            path: 'edit',
                            pageBuilder: (context, state) =>
                                NoTransitionPage<void>(
                                  child: PackagingFormPage(
                                    packagingId:
                                        state.pathParameters['packagingId']!,
                                  ),
                                ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  GoRoute(
                    path: 'suppliers',
                    pageBuilder: (context, state) =>
                        const NoTransitionPage<void>(child: SuppliersPage()),
                    routes: [
                      GoRoute(
                        path: 'new',
                        pageBuilder: (context, state) =>
                            const NoTransitionPage<void>(
                              child: SupplierFormPage(),
                            ),
                      ),
                      GoRoute(
                        path: ':supplierId',
                        pageBuilder: (context, state) => NoTransitionPage<void>(
                          child: SupplierDetailsPage(
                            supplierId: state.pathParameters['supplierId']!,
                          ),
                        ),
                        routes: [
                          GoRoute(
                            path: 'edit',
                            pageBuilder: (context, state) =>
                                NoTransitionPage<void>(
                                  child: SupplierFormPage(
                                    supplierId:
                                        state.pathParameters['supplierId']!,
                                  ),
                                ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  GoRoute(
                    path: 'recipes',
                    pageBuilder: (context, state) =>
                        const NoTransitionPage<void>(child: RecipesPage()),
                    routes: [
                      GoRoute(
                        path: 'new',
                        pageBuilder: (context, state) =>
                            const NoTransitionPage<void>(
                              child: RecipeFormPage(),
                            ),
                      ),
                      GoRoute(
                        path: ':recipeId',
                        pageBuilder: (context, state) => NoTransitionPage<void>(
                          child: RecipeDetailsPage(
                            recipeId: state.pathParameters['recipeId']!,
                          ),
                        ),
                        routes: [
                          GoRoute(
                            path: 'edit',
                            pageBuilder: (context, state) =>
                                NoTransitionPage<void>(
                                  child: RecipeFormPage(
                                    recipeId: state.pathParameters['recipeId']!,
                                  ),
                                ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  GoRoute(
                    path: 'products',
                    pageBuilder: (context, state) =>
                        const NoTransitionPage<void>(child: ProductsPage()),
                    routes: [
                      GoRoute(
                        path: 'new',
                        pageBuilder: (context, state) =>
                            const NoTransitionPage<void>(
                              child: ProductFormPage(),
                            ),
                      ),
                      GoRoute(
                        path: ':productId',
                        pageBuilder: (context, state) => NoTransitionPage<void>(
                          child: ProductDetailsPage(
                            productId: state.pathParameters['productId']!,
                          ),
                        ),
                        routes: [
                          GoRoute(
                            path: 'edit',
                            pageBuilder: (context, state) =>
                                NoTransitionPage<void>(
                                  child: ProductFormPage(
                                    productId:
                                        state.pathParameters['productId']!,
                                  ),
                                ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    ],
  );

  ref.onDispose(router.dispose);
  return router;
});

StatefulShellBranch _branch(String path, Widget child) {
  return StatefulShellBranch(
    routes: [
      GoRoute(
        path: path,
        pageBuilder: (context, state) => NoTransitionPage<void>(child: child),
      ),
    ],
  );
}
