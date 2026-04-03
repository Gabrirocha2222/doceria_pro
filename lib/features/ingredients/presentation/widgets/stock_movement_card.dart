import 'package:flutter/material.dart';

import '../../../../core/formatters/app_formatters.dart';
import '../../domain/ingredient_stock_movement.dart';
import '../../domain/ingredient_unit.dart';

class StockMovementCard extends StatelessWidget {
  const StockMovementCard({
    super.key,
    required this.movement,
    required this.stockUnit,
  });

  final IngredientStockMovementRecord movement;
  final IngredientUnit stockUnit;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(movement.reason, style: theme.textTheme.titleMedium),
                    const SizedBox(height: 4),
                    Text(
                      '${movement.movementType.label} • ${AppFormatters.dayMonthYear(movement.createdAt)}',
                      style: theme.textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              _MovementDeltaPill(
                label: movement.formatDelta(stockUnit),
                isIncrease: movement.isIncrease,
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              Text(
                'Antes: ${stockUnit.formatQuantity(movement.previousStockQuantity)}',
              ),
              Text(
                'Depois: ${stockUnit.formatQuantity(movement.resultingStockQuantity)}',
              ),
            ],
          ),
          if (movement.notes?.trim().isNotEmpty == true) ...[
            const SizedBox(height: 12),
            Text(movement.notes!, style: theme.textTheme.bodyMedium),
          ],
        ],
      ),
    );
  }
}

class _MovementDeltaPill extends StatelessWidget {
  const _MovementDeltaPill({required this.label, required this.isIncrease});

  final String label;
  final bool isIncrease;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: isIncrease
            ? theme.colorScheme.secondaryContainer
            : theme.colorScheme.errorContainer,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: theme.textTheme.labelLarge?.copyWith(
          color: isIncrease
              ? theme.colorScheme.secondary
              : theme.colorScheme.error,
        ),
      ),
    );
  }
}
