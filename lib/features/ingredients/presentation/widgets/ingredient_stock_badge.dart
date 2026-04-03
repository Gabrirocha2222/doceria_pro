import 'package:flutter/material.dart';

class IngredientStockBadge extends StatelessWidget {
  const IngredientStockBadge({super.key, required this.isLowStock});

  final bool isLowStock;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: isLowStock
            ? theme.colorScheme.errorContainer
            : theme.colorScheme.secondaryContainer,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        isLowStock ? 'Estoque baixo' : 'Estoque ok',
        style: theme.textTheme.labelLarge?.copyWith(
          color: isLowStock
              ? theme.colorScheme.error
              : theme.colorScheme.secondary,
        ),
      ),
    );
  }
}
