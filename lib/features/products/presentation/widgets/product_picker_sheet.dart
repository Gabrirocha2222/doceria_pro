import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/product_providers.dart';
import '../../domain/product.dart';
import 'product_sale_mode_badge.dart';
import 'product_state_badge.dart';
import 'product_type_badge.dart';

Future<ProductRecord?> showProductPickerSheet(BuildContext context) {
  return showModalBottomSheet<ProductRecord>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (context) => const _ProductPickerSheet(),
  );
}

class _ProductPickerSheet extends ConsumerStatefulWidget {
  const _ProductPickerSheet();

  @override
  ConsumerState<_ProductPickerSheet> createState() =>
      _ProductPickerSheetState();
}

class _ProductPickerSheetState extends ConsumerState<_ProductPickerSheet> {
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final productsAsync = ref.watch(activeProductsProvider);
    final normalizedQuery = _searchController.text.trim().toLowerCase();

    return Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        12,
        20,
        MediaQuery.viewInsetsOf(context).bottom + 24,
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxHeight: 680),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Escolher produto',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 6),
            Text(
              'Use um produto ativo como base e preserve o retrato do item no pedido.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _searchController,
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(
                hintText: 'Buscar por nome, categoria ou opção',
                prefixIcon: Icon(Icons.search_rounded),
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: productsAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (error, stackTrace) => const Center(
                  child: Text('Não foi possível carregar os produtos agora.'),
                ),
                data: (products) {
                  final filteredProducts = products
                      .where((product) {
                        if (normalizedQuery.isEmpty) {
                          return true;
                        }

                        final searchableFields = [
                          product.name,
                          product.category ?? '',
                          ...product.options.map((option) => option.name),
                        ];

                        return searchableFields.any(
                          (field) =>
                              field.toLowerCase().contains(normalizedQuery),
                        );
                      })
                      .toList(growable: false);

                  if (filteredProducts.isEmpty) {
                    return const Center(
                      child: Text(
                        'Nenhum produto ativo bate com essa busca.',
                        textAlign: TextAlign.center,
                      ),
                    );
                  }

                  return ListView.separated(
                    itemCount: filteredProducts.length,
                    separatorBuilder: (context, index) =>
                        const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final product = filteredProducts[index];

                      return Card(
                        child: InkWell(
                          borderRadius: BorderRadius.circular(28),
                          onTap: () => Navigator.of(context).pop(product),
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            product.name,
                                            style: Theme.of(
                                              context,
                                            ).textTheme.titleMedium,
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            product.displayCategory,
                                            style: Theme.of(
                                              context,
                                            ).textTheme.bodyMedium,
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    ProductStateBadge(
                                      isActive: product.isActive,
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  children: [
                                    ProductTypeBadge(type: product.type),
                                    ProductSaleModeBadge(
                                      saleMode: product.saleMode,
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  product.priceLabel,
                                  style: Theme.of(
                                    context,
                                  ).textTheme.titleMedium,
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
