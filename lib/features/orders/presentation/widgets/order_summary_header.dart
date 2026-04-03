import 'package:flutter/material.dart';

import '../../../../core/money/money.dart';
import '../../domain/order_status.dart';
import 'order_status_badge.dart';

class OrderSummaryHeader extends StatelessWidget {
  const OrderSummaryHeader({
    super.key,
    required this.title,
    required this.subtitle,
    required this.status,
    required this.totalAmount,
    this.middleAmountLabel = 'Entrou',
    required this.depositAmount,
    required this.remainingAmount,
    required this.isDraft,
  });

  final String title;
  final String subtitle;
  final OrderStatus status;
  final Money totalAmount;
  final String middleAmountLabel;
  final Money depositAmount;
  final Money remainingAmount;
  final bool isDraft;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(32),
        gradient: LinearGradient(
          colors: [
            theme.colorScheme.primaryContainer,
            theme.colorScheme.surface,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              OrderStatusBadge(status: status),
              if (isDraft) const IncompleteOrderBadge(),
            ],
          ),
          const SizedBox(height: 16),
          Text(title, style: theme.textTheme.headlineSmall),
          const SizedBox(height: 6),
          Text(subtitle, style: theme.textTheme.bodyLarge),
          const SizedBox(height: 20),
          LayoutBuilder(
            builder: (context, constraints) {
              final compactLayout = constraints.maxWidth < 720;
              final itemWidth = compactLayout
                  ? constraints.maxWidth
                  : (constraints.maxWidth - 24) / 3;

              return Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  SizedBox(
                    width: itemWidth,
                    child: _AmountCard(label: 'Total', amount: totalAmount),
                  ),
                  SizedBox(
                    width: itemWidth,
                    child: _AmountCard(
                      label: middleAmountLabel,
                      amount: depositAmount,
                    ),
                  ),
                  SizedBox(
                    width: itemWidth,
                    child: _AmountCard(
                      label: 'Restante',
                      amount: remainingAmount,
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _AmountCard extends StatelessWidget {
  const _AmountCard({required this.label, required this.amount});

  final String label;
  final Money amount;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: theme.textTheme.labelLarge),
          const SizedBox(height: 8),
          Text(amount.format(), style: theme.textTheme.titleLarge),
        ],
      ),
    );
  }
}
