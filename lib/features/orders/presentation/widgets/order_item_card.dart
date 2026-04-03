import 'package:flutter/material.dart';

import '../../domain/order.dart';

class OrderItemCard extends StatelessWidget {
  const OrderItemCard({
    super.key,
    required this.item,
    this.trailing,
    this.showLinkedBadge = true,
  });

  final OrderItemRecord item;
  final Widget? trailing;
  final bool showLinkedBadge;

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
                    Text(item.displayName, style: theme.textTheme.titleMedium),
                    const SizedBox(height: 6),
                    Text(
                      '${item.displayQuantity} • ${item.price.format()} cada • ${item.lineTotal.format()} no total',
                      style: theme.textTheme.bodyLarge,
                    ),
                  ],
                ),
              ),
              if (trailing != null) ...[const SizedBox(width: 12), trailing!],
            ],
          ),
          if (showLinkedBadge || item.notes?.trim().isNotEmpty == true) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (showLinkedBadge)
                  _ItemMetaBadge(
                    text: item.productId == null
                        ? 'Manual'
                        : 'Ligado a produto',
                  ),
                if (item.notes?.trim().isNotEmpty == true)
                  _ItemMetaBadge(text: item.notes!.trim()),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _ItemMetaBadge extends StatelessWidget {
  const _ItemMetaBadge({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Text(text, style: theme.textTheme.labelLarge),
    );
  }
}

extension OrderItemDraftMapper on OrderItemInput {
  OrderItemRecord toRecord({required String orderId, required int sortOrder}) {
    return OrderItemRecord(
      id: id ?? 'draft-$sortOrder',
      orderId: orderId,
      productId: productId,
      itemNameSnapshot: itemNameSnapshot,
      flavorSnapshot: flavorSnapshot,
      variationSnapshot: variationSnapshot,
      price: price,
      quantity: quantity,
      notes: notes,
      sortOrder: sortOrder,
    );
  }
}
