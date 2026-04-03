import 'package:flutter/material.dart';

import '../../domain/product_sale_mode.dart';

class ProductSaleModeBadge extends StatelessWidget {
  const ProductSaleModeBadge({super.key, required this.saleMode});

  final ProductSaleMode saleMode;

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
      child: Text(saleMode.label, style: theme.textTheme.labelLarge),
    );
  }
}
