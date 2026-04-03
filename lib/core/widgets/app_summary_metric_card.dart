import 'package:flutter/material.dart';

class AppSummaryMetricCard extends StatelessWidget {
  const AppSummaryMetricCard({
    super.key,
    required this.label,
    required this.value,
    this.attention = false,
  });

  final String label;
  final String value;
  final bool attention;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: attention
            ? theme.colorScheme.errorContainer
            : theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: theme.textTheme.labelLarge),
          const SizedBox(height: 8),
          Text(value, style: theme.textTheme.headlineSmall),
        ],
      ),
    );
  }
}
