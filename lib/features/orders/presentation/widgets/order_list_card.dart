import 'package:flutter/material.dart';

import '../../../../core/formatters/app_formatters.dart';
import '../../domain/order.dart';
import 'order_status_badge.dart';

class OrderListCard extends StatelessWidget {
  const OrderListCard({super.key, required this.order, required this.onTap});

  final OrderRecord order;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(28),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              LayoutBuilder(
                builder: (context, constraints) {
                  final compactLayout = constraints.maxWidth < 640;

                  final titleColumn = Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        order.displayClientName,
                        style: theme.textTheme.titleLarge,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        _buildSecondaryText(order),
                        style: theme.textTheme.bodyMedium,
                      ),
                    ],
                  );

                  final badges = Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      OrderStatusBadge(status: order.status),
                      if (order.isDraft) const IncompleteOrderBadge(),
                    ],
                  );

                  if (compactLayout) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        titleColumn,
                        const SizedBox(height: 12),
                        badges,
                      ],
                    );
                  }

                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: titleColumn),
                      const SizedBox(width: 16),
                      badges,
                    ],
                  );
                },
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  if (order.itemCount > 0)
                    _MetricPill(
                      label: 'Quantidade',
                      value: order.itemCount.toString(),
                    ),
                  _MetricPill(label: 'Total', value: order.orderTotal.format()),
                  _MetricPill(
                    label: 'Entrou',
                    value: order.receivedAmount.format(),
                  ),
                  _MetricPill(
                    label: 'Restante',
                    value: order.remainingAmount.format(),
                  ),
                  if (order.predictedProfit.isPositive)
                    _MetricPill(
                      label: 'Lucro previsto',
                      value: order.predictedProfit.format(),
                    ),
                ],
              ),
              if (order.notes != null && order.notes!.trim().isNotEmpty) ...[
                const SizedBox(height: 16),
                Text(
                  order.notes!,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyMedium,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  String _buildSecondaryText(OrderRecord order) {
    final segments = <String>[
      if (order.fulfillmentMethod != null) order.fulfillmentMethod!.label,
      'Atualizado em ${AppFormatters.dayMonthYear(order.updatedAt)}',
    ];

    return segments.join(' • ');
  }
}

class _MetricPill extends StatelessWidget {
  const _MetricPill({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label, style: theme.textTheme.labelMedium),
          const SizedBox(height: 4),
          Text(value, style: theme.textTheme.titleMedium),
        ],
      ),
    );
  }
}
