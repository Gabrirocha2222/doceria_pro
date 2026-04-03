import 'package:flutter/material.dart';

import '../../domain/recipe_type.dart';

class RecipeTypeBadge extends StatelessWidget {
  const RecipeTypeBadge({super.key, required this.type});

  final RecipeType type;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: theme.colorScheme.secondaryContainer,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        type.label,
        style: theme.textTheme.labelLarge?.copyWith(
          color: theme.colorScheme.onSecondaryContainer,
        ),
      ),
    );
  }
}
