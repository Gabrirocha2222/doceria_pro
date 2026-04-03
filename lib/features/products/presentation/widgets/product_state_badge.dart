import 'package:flutter/material.dart';

class ProductStateBadge extends StatelessWidget {
  const ProductStateBadge({super.key, required this.isActive});

  final bool isActive;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: isActive
            ? theme.colorScheme.secondaryContainer
            : theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        isActive ? 'Ativo' : 'Inativo',
        style: theme.textTheme.labelLarge?.copyWith(
          color: isActive
              ? theme.colorScheme.secondary
              : theme.colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}
