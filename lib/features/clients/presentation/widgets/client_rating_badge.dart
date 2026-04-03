import 'package:flutter/material.dart';

import '../../domain/client_rating.dart';

class ClientRatingBadge extends StatelessWidget {
  const ClientRatingBadge({super.key, required this.rating});

  final ClientRating rating;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = switch (rating) {
      ClientRating.like => (
        background: theme.colorScheme.tertiaryContainer,
        foreground: theme.colorScheme.tertiary,
      ),
      ClientRating.neutral => (
        background: theme.colorScheme.surfaceContainerLow,
        foreground: theme.colorScheme.onSurface,
      ),
      ClientRating.dislike => (
        background: theme.colorScheme.errorContainer,
        foreground: theme.colorScheme.error,
      ),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: palette.background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        rating.label,
        style: theme.textTheme.labelLarge?.copyWith(color: palette.foreground),
      ),
    );
  }
}
