import 'package:flutter/material.dart';

import '../../domain/order_status.dart';

class OrderStatusBadge extends StatelessWidget {
  const OrderStatusBadge({super.key, required this.status});

  final OrderStatus status;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = switch (status) {
      OrderStatus.budget => (
        background: theme.colorScheme.primaryContainer,
        foreground: theme.colorScheme.primary,
      ),
      OrderStatus.awaitingDeposit => (
        background: theme.colorScheme.secondaryContainer,
        foreground: theme.colorScheme.secondary,
      ),
      OrderStatus.confirmed => (
        background: theme.colorScheme.tertiaryContainer,
        foreground: theme.colorScheme.tertiary,
      ),
      OrderStatus.inProduction => (
        background: theme.colorScheme.primaryContainer,
        foreground: theme.colorScheme.primary,
      ),
      OrderStatus.ready => (
        background: theme.colorScheme.surfaceContainerLow,
        foreground: theme.colorScheme.onSurface,
      ),
      OrderStatus.delivered => (
        background: theme.colorScheme.tertiaryContainer,
        foreground: theme.colorScheme.tertiary,
      ),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: palette.background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        status.label,
        style: theme.textTheme.labelLarge?.copyWith(color: palette.foreground),
      ),
    );
  }
}

class IncompleteOrderBadge extends StatelessWidget {
  const IncompleteOrderBadge({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Text('Incompleto', style: theme.textTheme.labelLarge),
    );
  }
}
