import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/bootstrap/app_bootstrap_state.dart';
import '../../core/responsive/app_breakpoints.dart';
import '../navigation/app_destinations.dart';

class AppShell extends ConsumerWidget {
  const AppShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bootstrapState = ref.watch(appBootstrapStateProvider);
    final width = MediaQuery.sizeOf(context).width;
    final compactLayout = AppBreakpoints.isCompactWidth(width);
    final extendRail = AppBreakpoints.shouldExtendRail(width);

    final content = _ShellContent(
      navigationShell: navigationShell,
      bootstrapState: bootstrapState,
      onOpenBusinessSettings: () {
        _goToBranch(AppDestinations.businessSettingsIndex);
      },
    );

    if (compactLayout) {
      return Scaffold(
        body: SafeArea(bottom: false, child: content),
        bottomNavigationBar: NavigationBar(
          selectedIndex: navigationShell.currentIndex,
          onDestinationSelected: _goToBranch,
          destinations: [
            for (final destination in AppDestinations.values)
              NavigationDestination(
                icon: Icon(destination.icon),
                selectedIcon: Icon(destination.selectedIcon),
                label: destination.label,
              ),
          ],
        ),
      );
    }

    return Scaffold(
      body: SafeArea(
        child: Row(
          children: [
            NavigationRail(
              extended: extendRail,
              selectedIndex: navigationShell.currentIndex,
              onDestinationSelected: _goToBranch,
              useIndicator: true,
              labelType: extendRail ? null : NavigationRailLabelType.all,
              leading: _RailHeader(extended: extendRail),
              destinations: [
                for (final destination in AppDestinations.values)
                  NavigationRailDestination(
                    icon: Icon(destination.icon),
                    selectedIcon: Icon(destination.selectedIcon),
                    label: Text(destination.label),
                  ),
              ],
            ),
            VerticalDivider(
              width: 1,
              thickness: 1,
              color: Theme.of(context).colorScheme.outlineVariant,
            ),
            Expanded(child: content),
          ],
        ),
      ),
    );
  }

  void _goToBranch(int index) {
    navigationShell.goBranch(
      index,
      initialLocation: index == navigationShell.currentIndex,
    );
  }
}

class _ShellContent extends StatelessWidget {
  const _ShellContent({
    required this.navigationShell,
    required this.bootstrapState,
    required this.onOpenBusinessSettings,
  });

  final StatefulNavigationShell navigationShell;
  final AppBootstrapState bootstrapState;
  final VoidCallback onOpenBusinessSettings;

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final horizontalPadding = AppBreakpoints.isCompactWidth(width)
        ? 16.0
        : 24.0;

    return Column(
      children: [
        if (bootstrapState.shouldShowOfflineBanner)
          Padding(
            padding: EdgeInsets.fromLTRB(
              horizontalPadding,
              16,
              horizontalPadding,
              0,
            ),
            child: Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: AppBreakpoints.contentMaxWidth(width),
                ),
                child: _OfflineReadyBanner(
                  bootstrapState: bootstrapState,
                  onOpenBusinessSettings: onOpenBusinessSettings,
                ),
              ),
            ),
          ),
        Expanded(child: navigationShell),
      ],
    );
  }
}

class _RailHeader extends StatelessWidget {
  const _RailHeader({required this.extended});

  final bool extended;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: EdgeInsets.fromLTRB(extended ? 20 : 12, 12, 12, 20),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: theme.colorScheme.primaryContainer,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(Icons.cake_outlined, color: theme.colorScheme.primary),
          ),
          if (extended) ...[
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Doceria Pro', style: theme.textTheme.titleMedium),
                Text('Rotina com leveza', style: theme.textTheme.bodySmall),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _OfflineReadyBanner extends StatelessWidget {
  const _OfflineReadyBanner({
    required this.bootstrapState,
    required this.onOpenBusinessSettings,
  });

  final AppBootstrapState bootstrapState;
  final VoidCallback onOpenBusinessSettings;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.secondaryContainer,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compactLayout = constraints.maxWidth < 640;

          final details = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                bootstrapState.bannerTitle,
                style: theme.textTheme.titleMedium,
              ),
              const SizedBox(height: 4),
              Text(
                bootstrapState.bannerMessage,
                style: theme.textTheme.bodyMedium,
              ),
            ],
          );

          if (compactLayout) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.cloud_off_outlined,
                      color: theme.colorScheme.secondary,
                    ),
                    const SizedBox(width: 12),
                    Expanded(child: details),
                  ],
                ),
                const SizedBox(height: 12),
                FilledButton.tonalIcon(
                  onPressed: onOpenBusinessSettings,
                  icon: const Icon(Icons.tune_rounded),
                  label: const Text('Ver configuração'),
                ),
              ],
            );
          }

          return Row(
            children: [
              Icon(
                Icons.cloud_off_outlined,
                color: theme.colorScheme.secondary,
              ),
              const SizedBox(width: 16),
              Expanded(child: details),
              const SizedBox(width: 16),
              FilledButton.tonalIcon(
                onPressed: onOpenBusinessSettings,
                icon: const Icon(Icons.tune_rounded),
                label: const Text('Ver configuração'),
              ),
            ],
          );
        },
      ),
    );
  }
}
