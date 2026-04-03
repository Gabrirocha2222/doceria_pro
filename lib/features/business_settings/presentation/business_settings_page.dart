import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/navigation/app_destinations.dart';
import '../../../core/bootstrap/app_bootstrap_state.dart';
import '../../../core/formatters/app_formatters.dart';
import '../../../core/widgets/app_page_scaffold.dart';
import '../../commercial/presentation/business_brand_settings_page.dart';
import '../../sync/application/sync_providers.dart';

class BusinessSettingsPage extends ConsumerWidget {
  const BusinessSettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bootstrapState = ref.watch(appBootstrapStateProvider);
    final theme = Theme.of(context);

    return AppPageScaffold(
      title: 'Negócio',
      subtitle:
          'Aqui ficam o estado atual da base, orientações de integração e os pontos globais do app.',
      trailing: Wrap(
        spacing: 12,
        runSpacing: 12,
        children: [
          FilledButton.tonalIcon(
            onPressed: () => context.push(BusinessBrandSettingsPage.basePath),
            icon: const Icon(Icons.palette_outlined),
            label: const Text('Marca e orçamento'),
          ),
          FilledButton.tonalIcon(
            onPressed: () => context.push(
              '${AppDestinations.businessSettings.path}/suppliers',
            ),
            icon: const Icon(Icons.local_shipping_rounded),
            label: const Text('Fornecedoras'),
          ),
          FilledButton.tonalIcon(
            onPressed: () => context.push(
              '${AppDestinations.businessSettings.path}/packaging',
            ),
            icon: const Icon(Icons.inventory_2_rounded),
            label: const Text('Embalagens'),
          ),
          FilledButton.tonalIcon(
            onPressed: () => context.push(
              '${AppDestinations.businessSettings.path}/products',
            ),
            icon: const Icon(Icons.inventory_2_outlined),
            label: const Text('Produtos'),
          ),
          FilledButton.tonalIcon(
            onPressed: () => context.push(
              '${AppDestinations.businessSettings.path}/recipes',
            ),
            icon: const Icon(Icons.menu_book_rounded),
            label: const Text('Receitas'),
          ),
        ],
      ),
      child: Column(
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 52,
                        height: 52,
                        decoration: BoxDecoration(
                          color: theme.colorScheme.primaryContainer,
                          borderRadius: BorderRadius.circular(18),
                        ),
                        child: Icon(
                          Icons.storefront_rounded,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Estado atual do app',
                              style: theme.textTheme.titleLarge,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              bootstrapState.statusLabel,
                              style: theme.textTheme.bodyLarge,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Text(
                    bootstrapState.bannerMessage,
                    style: theme.textTheme.bodyMedium,
                  ),
                  if (bootstrapState.technicalMessage != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      'Detalhe técnico: ${bootstrapState.technicalMessage}',
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          const _SyncOverviewCard(),
          const SizedBox(height: 16),
          LayoutBuilder(
            builder: (context, constraints) {
              final compactLayout = constraints.maxWidth < 720;
              final cardWidth = compactLayout
                  ? constraints.maxWidth
                  : (constraints.maxWidth - 12) / 2;

              return Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  SizedBox(
                    width: cardWidth,
                    child: _ActionInfoCard(
                      icon: Icons.picture_as_pdf_outlined,
                      title: 'Marca, PDF e resumo compartilhável',
                      message:
                          'Defina nome do negócio, contato e o tom visual que saem no PDF de orçamento e no resumo pronto para WhatsApp.',
                      actionLabel: 'Abrir camada comercial',
                      onAction: () =>
                          context.push(BusinessBrandSettingsPage.basePath),
                    ),
                  ),
                  SizedBox(
                    width: cardWidth,
                    child: _ActionInfoCard(
                      icon: Icons.local_shipping_rounded,
                      title: 'Fornecedoras e último preço',
                      message:
                          'Guarde contato, prazo médio e preços recentes para ingredientes e embalagens sem montar uma suíte de compras pesada.',
                      actionLabel: 'Abrir fornecedoras',
                      onAction: () => context.push(
                        '${AppDestinations.businessSettings.path}/suppliers',
                      ),
                    ),
                  ),
                  SizedBox(
                    width: cardWidth,
                    child: _ActionInfoCard(
                      icon: Icons.inventory_2_rounded,
                      title: 'Embalagens e sugestão padrão',
                      message:
                          'Cadastre embalagem, acompanhe custo e estoque e deixe produtos com opções compatíveis para sugerir depois.',
                      actionLabel: 'Abrir embalagens',
                      onAction: () => context.push(
                        '${AppDestinations.businessSettings.path}/packaging',
                      ),
                    ),
                  ),
                  SizedBox(
                    width: cardWidth,
                    child: _ActionInfoCard(
                      icon: Icons.menu_book_rounded,
                      title: 'Receitas e custo automático',
                      message:
                          'Monte receitas com ingredientes do estoque, rendimento e custo por base para apoiar preço e produto.',
                      actionLabel: 'Abrir receitas',
                      onAction: () => context.push(
                        '${AppDestinations.businessSettings.path}/recipes',
                      ),
                    ),
                  ),
                  SizedBox(
                    width: cardWidth,
                    child: _ActionInfoCard(
                      icon: Icons.inventory_2_outlined,
                      title: 'Produtos e tipos de venda',
                      message:
                          'Cadastre a base comercial do catálogo, com sabores, variações e preço inicial para usar em pedidos.',
                      actionLabel: 'Abrir produtos',
                      onAction: () => context.push(
                        '${AppDestinations.businessSettings.path}/products',
                      ),
                    ),
                  ),
                  SizedBox(
                    width: cardWidth,
                    child: const _SettingsInfoCard(
                      icon: Icons.cloud_sync_outlined,
                      title: 'Integração Supabase',
                      message:
                          'Quando você quiser ativar recursos remotos, inicie o app com os `--dart-define` de `SUPABASE_URL` e `SUPABASE_ANON_KEY`.',
                    ),
                  ),
                  SizedBox(
                    width: cardWidth,
                    child: const _SettingsInfoCard(
                      icon: Icons.storage_rounded,
                      title: 'Base local',
                      message:
                          'A fundação local já inclui o banco Drift e a fila mínima de sync para crescer sem depender da nuvem.',
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

class _SyncOverviewCard extends ConsumerWidget {
  const _SyncOverviewCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final overviewAsync = ref.watch(syncOverviewProvider);
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: overviewAsync.when(
          data: (overview) => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: theme.colorScheme.secondaryContainer,
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Icon(
                      overview.canSyncNow
                          ? Icons.cloud_sync_outlined
                          : Icons.cloud_off_outlined,
                      color: theme.colorScheme.secondary,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Equipe e sincronização',
                          style: theme.textTheme.titleLarge,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          overview.statusLabel,
                          style: theme.textTheme.bodyLarge,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          overview.helperText,
                          style: theme.textTheme.bodyMedium,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _StatusChip(
                    label: overview.teamContext.team.name,
                    icon: Icons.groups_rounded,
                  ),
                  _StatusChip(
                    label: overview.teamContext.currentMember.role.label,
                    icon: Icons.badge_outlined,
                  ),
                  _StatusChip(
                    label:
                        '${overview.pendingChangesCount} alteração(ões) pendente(s)',
                    icon: Icons.pending_actions_rounded,
                  ),
                ],
              ),
              if (overview.lastAttemptAt != null ||
                  overview.lastSuccessfulPushAt != null ||
                  overview.lastSuccessfulPullAt != null) ...[
                const SizedBox(height: 16),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    if (overview.lastAttemptAt != null)
                      _InfoLine(
                        label: 'Última tentativa',
                        value: AppFormatters.dayMonthYear(
                          overview.lastAttemptAt!,
                        ),
                      ),
                    if (overview.lastSuccessfulPushAt != null)
                      _InfoLine(
                        label: 'Último envio',
                        value: AppFormatters.dayMonthYear(
                          overview.lastSuccessfulPushAt!,
                        ),
                      ),
                    if (overview.lastSuccessfulPullAt != null)
                      _InfoLine(
                        label: 'Última leitura remota',
                        value: AppFormatters.dayMonthYear(
                          overview.lastSuccessfulPullAt!,
                        ),
                      ),
                  ],
                ),
              ],
              const SizedBox(height: 20),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  FilledButton.icon(
                    onPressed: overview.canSyncNow && !overview.isSyncing
                        ? () => _runSync(context, ref)
                        : null,
                    icon: const Icon(Icons.sync_rounded),
                    label: Text(
                      overview.isSyncing
                          ? 'Sincronizando...'
                          : 'Sincronizar agora',
                    ),
                  ),
                  if (!overview.canSyncNow)
                    OutlinedButton.icon(
                      onPressed: null,
                      icon: const Icon(Icons.cloud_off_outlined),
                      label: const Text('Modo local ativo'),
                    ),
                ],
              ),
            ],
          ),
          loading: () => const SizedBox(
            height: 120,
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (error, stackTrace) => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Equipe e sincronização', style: theme.textTheme.titleLarge),
              const SizedBox(height: 8),
              Text(
                'Não foi possível ler o estado local da sincronização.',
                style: theme.textTheme.bodyMedium,
              ),
              const SizedBox(height: 8),
              Text(error.toString(), style: theme.textTheme.bodySmall),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _runSync(BuildContext context, WidgetRef ref) async {
    final messenger = ScaffoldMessenger.of(context);

    try {
      final result = await ref
          .read(syncControllerProvider.notifier)
          .runSyncNow();
      if (!context.mounted) {
        return;
      }

      final message = result.hadError
          ? 'A sincronização terminou com alerta. ${result.errorMessage ?? 'Confira os detalhes acima.'}'
          : 'Sincronização concluída. ${result.pushedCount} envio(s), ${result.pulledCount} atualização(ões) recebida(s) e ${result.skippedCount} item(ns) mantido(s) localmente.';
      messenger.showSnackBar(SnackBar(content: Text(message)));
    } catch (error) {
      if (!context.mounted) {
        return;
      }

      messenger.showSnackBar(
        SnackBar(content: Text('Não foi possível sincronizar agora: $error')),
      );
    }
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.label, required this.icon});

  final String label;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Chip(avatar: Icon(icon, size: 18), label: Text(label));
  }
}

class _InfoLine extends StatelessWidget {
  const _InfoLine({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: theme.textTheme.labelMedium),
          const SizedBox(height: 4),
          Text(value, style: theme.textTheme.bodyMedium),
        ],
      ),
    );
  }
}

class _SettingsInfoCard extends StatelessWidget {
  const _SettingsInfoCard({
    required this.icon,
    required this.title,
    required this.message,
  });

  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: theme.colorScheme.secondary),
            const SizedBox(height: 16),
            Text(title, style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(message, style: theme.textTheme.bodyMedium),
          ],
        ),
      ),
    );
  }
}

class _ActionInfoCard extends StatelessWidget {
  const _ActionInfoCard({
    required this.icon,
    required this.title,
    required this.message,
    required this.actionLabel,
    required this.onAction,
  });

  final IconData icon;
  final String title;
  final String message;
  final String actionLabel;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: theme.colorScheme.secondary),
            const SizedBox(height: 16),
            Text(title, style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(message, style: theme.textTheme.bodyMedium),
            const SizedBox(height: 16),
            FilledButton.tonalIcon(
              onPressed: onAction,
              icon: const Icon(Icons.open_in_new_rounded),
              label: Text(actionLabel),
            ),
          ],
        ),
      ),
    );
  }
}
