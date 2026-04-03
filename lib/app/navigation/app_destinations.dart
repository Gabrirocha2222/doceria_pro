import 'package:flutter/material.dart';

class AppDestination {
  const AppDestination({
    required this.label,
    required this.path,
    required this.icon,
    required this.selectedIcon,
  });

  final String label;
  final String path;
  final IconData icon;
  final IconData selectedIcon;
}

abstract final class AppDestinations {
  static const dashboard = AppDestination(
    label: 'Painel',
    path: '/',
    icon: Icons.space_dashboard_outlined,
    selectedIcon: Icons.space_dashboard_rounded,
  );

  static const orders = AppDestination(
    label: 'Pedidos',
    path: '/orders',
    icon: Icons.receipt_long_outlined,
    selectedIcon: Icons.receipt_long_rounded,
  );

  static const production = AppDestination(
    label: 'Produção',
    path: '/production',
    icon: Icons.bakery_dining_outlined,
    selectedIcon: Icons.bakery_dining_rounded,
  );

  static const purchases = AppDestination(
    label: 'Compras',
    path: '/purchases',
    icon: Icons.shopping_bag_outlined,
    selectedIcon: Icons.shopping_bag_rounded,
  );

  static const finance = AppDestination(
    label: 'Financeiro',
    path: '/finance',
    icon: Icons.account_balance_wallet_outlined,
    selectedIcon: Icons.account_balance_wallet_rounded,
  );

  static const clients = AppDestination(
    label: 'Clientes',
    path: '/clients',
    icon: Icons.people_outline_rounded,
    selectedIcon: Icons.people_rounded,
  );

  static const businessSettings = AppDestination(
    label: 'Negócio',
    path: '/business',
    icon: Icons.storefront_outlined,
    selectedIcon: Icons.storefront_rounded,
  );

  static const values = [
    dashboard,
    orders,
    production,
    purchases,
    finance,
    clients,
    businessSettings,
  ];

  static const businessSettingsIndex = 6;
}
