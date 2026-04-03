import 'package:flutter/material.dart';

class PackagingStockBadge extends StatelessWidget {
  const PackagingStockBadge({super.key, required this.isLowStock});

  final bool isLowStock;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final backgroundColor = isLowStock
        ? theme.colorScheme.errorContainer
        : theme.colorScheme.secondaryContainer;
    final foregroundColor = isLowStock
        ? theme.colorScheme.onErrorContainer
        : theme.colorScheme.onSecondaryContainer;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        isLowStock ? 'Estoque baixo' : 'Estoque ok',
        style: theme.textTheme.labelLarge?.copyWith(color: foregroundColor),
      ),
    );
  }
}
