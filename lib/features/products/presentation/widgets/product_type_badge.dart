import 'package:flutter/material.dart';

import '../../domain/product_type.dart';

class ProductTypeBadge extends StatelessWidget {
  const ProductTypeBadge({super.key, required this.type});

  final ProductType type;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = switch (type) {
      ProductType.simple => (
        background: theme.colorScheme.primaryContainer,
        foreground: theme.colorScheme.primary,
      ),
      ProductType.perUnit => (
        background: theme.colorScheme.secondaryContainer,
        foreground: theme.colorScheme.secondary,
      ),
      ProductType.perWeight => (
        background: theme.colorScheme.tertiaryContainer,
        foreground: theme.colorScheme.tertiary,
      ),
      ProductType.kit => (
        background: theme.colorScheme.surfaceContainerHighest,
        foreground: theme.colorScheme.onSurface,
      ),
      ProductType.monthlyPlan => (
        background: theme.colorScheme.surfaceContainerLow,
        foreground: theme.colorScheme.onSurface,
      ),
      ProductType.outsourced => (
        background: theme.colorScheme.errorContainer,
        foreground: theme.colorScheme.error,
      ),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: palette.background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        type.label,
        style: theme.textTheme.labelLarge?.copyWith(color: palette.foreground),
      ),
    );
  }
}
