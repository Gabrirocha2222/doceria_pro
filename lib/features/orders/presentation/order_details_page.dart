import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';

import '../../../app/navigation/app_destinations.dart';
import '../../../core/formatters/app_formatters.dart';
import '../../../core/widgets/app_page_scaffold.dart';
import '../../../core/widgets/states/app_empty_state.dart';
import '../../../core/widgets/states/app_error_state.dart';
import '../../../core/widgets/states/app_loading_state.dart';
import '../../commercial/application/business_brand_settings_providers.dart';
import '../../commercial/domain/business_brand_settings.dart';
import '../../commercial/domain/order_share_text_builder.dart';
import '../../commercial/presentation/business_brand_settings_page.dart';
import '../../commercial/presentation/commercial_quick_actions_sheet.dart';
import '../application/order_providers.dart';
import '../domain/order.dart';
import '../domain/order_status.dart';
import 'widgets/order_item_card.dart';
import 'widgets/order_summary_header.dart';

class OrderDetailsPage extends ConsumerWidget {
  const OrderDetailsPage({super.key, required this.orderId});

  final String orderId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final orderAsync = ref.watch(orderProvider(orderId));

    return orderAsync.when(
      loading: () => const AppPageScaffold(
        title: 'Carregando pedido',
        subtitle: 'Separando resumo, materiais e financeiro.',
        child: AppLoadingState(message: 'Carregando pedido...'),
      ),
      error: (error, stackTrace) => AppPageScaffold(
        title: 'Pedido indisponível',
        subtitle: 'Não foi possível abrir este pedido agora.',
        child: AppErrorState(
          title: 'Não deu para abrir o pedido',
          message: 'Tente voltar para a lista e abrir novamente.',
          actionLabel: 'Voltar para pedidos',
          onAction: () => context.go(AppDestinations.orders.path),
        ),
      ),
      data: (order) {
        if (order == null) {
          return AppPageScaffold(
            title: 'Pedido não encontrado',
            subtitle:
                'Talvez ele tenha sido removido ou ainda não exista neste aparelho.',
            child: AppErrorState(
              title: 'Pedido não encontrado',
              message:
                  'Volte para a lista e confira os pedidos salvos localmente.',
              actionLabel: 'Voltar para pedidos',
              onAction: () => context.go(AppDestinations.orders.path),
            ),
          );
        }

        return AppPageScaffold(
          title: 'Detalhes do pedido',
          subtitle:
              'Resumo claro do pedido, com produção, materiais e financeiro no mesmo lugar.',
          trailing: Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              OutlinedButton.icon(
                onPressed: () => context.go(AppDestinations.orders.path),
                icon: const Icon(Icons.arrow_back_rounded),
                label: const Text('Voltar'),
              ),
              if (order.clientId != null)
                FilledButton.tonalIcon(
                  onPressed: () => context.push(
                    '${AppDestinations.clients.path}/${order.clientId!}',
                  ),
                  icon: const Icon(Icons.person_outline_rounded),
                  label: const Text('Ver cliente'),
                ),
              FilledButton.tonalIcon(
                onPressed: () => _openCommercialActions(context, ref, order),
                icon: const Icon(Icons.ios_share_rounded),
                label: const Text('Compartilhar'),
              ),
              FilledButton.tonalIcon(
                onPressed: () => context.push(
                  '${AppDestinations.orders.path}/${order.id}/edit',
                ),
                icon: const Icon(Icons.edit_rounded),
                label: const Text('Editar'),
              ),
            ],
          ),
          child: _OrderDetailsContent(order: order),
        );
      },
    );
  }

  Future<void> _openCommercialActions(
    BuildContext context,
    WidgetRef ref,
    OrderRecord order,
  ) async {
    final action = await showModalBottomSheet<OrderCommercialAction>(
      context: context,
      builder: (context) => const CommercialQuickActionsSheet(),
    );

    if (!context.mounted || action == null) {
      return;
    }

    switch (action) {
      case OrderCommercialAction.pdfQuote:
        context.push('${AppDestinations.orders.path}/${order.id}/quote');
      case OrderCommercialAction.whatsappSummary:
        await _shareWhatsAppSummary(context, ref, order);
      case OrderCommercialAction.brandSettings:
        context.push(BusinessBrandSettingsPage.basePath);
    }
  }

  Future<void> _shareWhatsAppSummary(
    BuildContext context,
    WidgetRef ref,
    OrderRecord order,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    final brandSettings = await ref
        .read(businessBrandSettingsProvider.future)
        .catchError((error, stackTrace) => BusinessBrandSettings.defaults);
    final text = OrderShareTextBuilder.build(
      order: order,
      brandSettings: brandSettings,
    );

    try {
      final result = await SharePlus.instance.share(
        ShareParams(
          title: 'Resumo comercial',
          subject: _shareSubject(order),
          text: text,
        ),
      );

      if (!context.mounted) {
        return;
      }

      if (result.status == ShareResultStatus.unavailable) {
        await Clipboard.setData(ClipboardData(text: text));
        if (!context.mounted) {
          return;
        }

        messenger.showSnackBar(
          const SnackBar(
            content: Text(
              'Compartilhamento indisponível aqui. O resumo foi copiado.',
            ),
          ),
        );
      }
    } catch (_) {
      await Clipboard.setData(ClipboardData(text: text));
      if (!context.mounted) {
        return;
      }

      messenger.showSnackBar(
        const SnackBar(
          content: Text(
            'Não deu para abrir o compartilhamento. O resumo foi copiado.',
          ),
        ),
      );
    }
  }

  String _shareSubject(OrderRecord order) {
    final baseLabel = switch (order.status) {
      OrderStatus.budget || OrderStatus.awaitingDeposit => 'Orçamento',
      _ => 'Resumo do pedido',
    };

    return '$baseLabel - ${order.displayClientName}';
  }
}

class _OrderDetailsContent extends StatefulWidget {
  const _OrderDetailsContent({required this.order});

  final OrderRecord order;

  @override
  State<_OrderDetailsContent> createState() => _OrderDetailsContentState();
}

class _OrderDetailsContentState extends State<_OrderDetailsContent>
    with SingleTickerProviderStateMixin {
  static const _tabs = [
    _OrderDetailsTab(label: 'Resumo'),
    _OrderDetailsTab(label: 'Produção'),
    _OrderDetailsTab(label: 'Materiais'),
    _OrderDetailsTab(label: 'Financeiro'),
    _OrderDetailsTab(label: 'Observações'),
  ];

  int _selectedTabIndex = 0;

  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _tabs.length, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final order = widget.order;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        OrderSummaryHeader(
          title: order.displayClientName,
          subtitle: _buildHeaderSubtitle(order),
          status: order.status,
          totalAmount: order.orderTotal,
          middleAmountLabel: 'Entrou',
          depositAmount: order.receivedAmount,
          remainingAmount: order.remainingAmount,
          isDraft: order.isDraft,
        ),
        const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: TabBar(
              controller: _tabController,
              isScrollable: true,
              dividerColor: Colors.transparent,
              tabs: [for (final tab in _tabs) Tab(text: tab.label)],
              onTap: (index) => setState(() => _selectedTabIndex = index),
            ),
          ),
        ),
        const SizedBox(height: 16),
        switch (_selectedTabIndex) {
          0 => _OrderSummaryTab(order: order),
          1 => _OrderProductionTab(order: order),
          2 => _OrderMaterialsTab(order: order),
          3 => _OrderFinanceTab(order: order),
          _ => _OrderNotesTab(order: order),
        },
      ],
    );
  }

  String _buildHeaderSubtitle(OrderRecord order) {
    final segments = <String>[
      if (order.eventDate != null) AppFormatters.dayMonthYear(order.eventDate!),
      if (order.fulfillmentMethod != null) order.fulfillmentMethod!.label,
      if (order.itemCount > 0)
        '${order.itemCount} ${order.itemCount == 1 ? 'unidade' : 'unidades'}',
    ];

    return segments.join(' • ');
  }
}

class _OrderDetailsTab {
  const _OrderDetailsTab({required this.label});

  final String label;
}

class _OrderSummaryTab extends StatelessWidget {
  const _OrderSummaryTab({required this.order});

  final OrderRecord order;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        LayoutBuilder(
          builder: (context, constraints) {
            final compactLayout = constraints.maxWidth < 760;
            final cardWidth = compactLayout
                ? constraints.maxWidth
                : (constraints.maxWidth - 12) / 2;

            return Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                SizedBox(
                  width: cardWidth,
                  child: _DetailsCard(
                    title: 'Resumo operacional',
                    rows: [
                      _DetailsRow(
                        label: 'Data',
                        value: order.eventDate == null
                            ? 'Sem data definida'
                            : AppFormatters.dayMonthYear(order.eventDate!),
                      ),
                      _DetailsRow(
                        label: 'Atendimento',
                        value: order.fulfillmentMethod?.label ?? 'Não definido',
                      ),
                      _DetailsRow(
                        label: 'Embalagem sugerida',
                        value: order.displaySuggestedPackagingName,
                      ),
                      _DetailsRow(
                        label: 'Atualização',
                        value: AppFormatters.dayMonthYear(order.updatedAt),
                      ),
                    ],
                  ),
                ),
                SizedBox(
                  width: cardWidth,
                  child: _DetailsCard(
                    title: 'Leitura inteligente',
                    rows: [
                      _DetailsRow(
                        label: 'Custo estimado',
                        value: order.estimatedCost.format(),
                      ),
                      _DetailsRow(
                        label: 'Venda sugerida',
                        value: order.suggestedSalePrice.format(),
                      ),
                      _DetailsRow(
                        label: 'Lucro previsto',
                        value: order.predictedProfit.format(),
                      ),
                      _DetailsRow(
                        label: 'Estado do sinal',
                        value: order.depositStateLabel,
                      ),
                    ],
                  ),
                ),
                SizedBox(
                  width: constraints.maxWidth,
                  child: _DetailsCard(
                    title: 'Resumo automático',
                    rows: [
                      _DetailsRow(
                        label: 'Leitura',
                        value: order.displaySmartReviewSummary,
                      ),
                    ],
                  ),
                ),
                SizedBox(
                  width: constraints.maxWidth,
                  child: _OrderItemsCard(order: order),
                ),
              ],
            );
          },
        ),
      ],
    );
  }
}

class _OrderProductionTab extends StatelessWidget {
  const _OrderProductionTab({required this.order});

  final OrderRecord order;

  @override
  Widget build(BuildContext context) {
    if (order.productionPlans.isEmpty) {
      return const AppEmptyState(
        icon: Icons.task_alt_rounded,
        title: 'Nada gerado para produção ainda',
        message:
            'Quando o pedido for confirmado com revisão inteligente, os próximos passos de produção aparecem aqui.',
      );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Planos de produção',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 6),
            Text(
              'Uma leitura simples do que precisa ser organizado para este pedido.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 16),
            for (
              var index = 0;
              index < order.productionPlans.length;
              index++
            ) ...[
              _ProductionPlanTile(plan: order.productionPlans[index]),
              if (index != order.productionPlans.length - 1)
                const SizedBox(height: 12),
            ],
          ],
        ),
      ),
    );
  }
}

class _OrderMaterialsTab extends StatelessWidget {
  const _OrderMaterialsTab({required this.order});

  final OrderRecord order;

  @override
  Widget build(BuildContext context) {
    if (order.materialNeeds.isEmpty) {
      return const AppEmptyState(
        icon: Icons.inventory_2_outlined,
        title: 'Nenhum material previsto ainda',
        message:
            'Os materiais aparecem aqui quando o pedido é confirmado com produto e vínculos suficientes.',
      );
    }

    final shortages = order.materialNeeds
        .where((need) => need.hasShortage)
        .length;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Materiais', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 6),
            Text(
              shortages == 0
                  ? 'Sem falta prevista no momento.'
                  : '$shortages ${shortages == 1 ? 'alerta de falta encontrado' : 'alertas de falta encontrados'} para este pedido.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 16),
            for (
              var index = 0;
              index < order.materialNeeds.length;
              index++
            ) ...[
              _MaterialNeedRecordTile(need: order.materialNeeds[index]),
              if (index != order.materialNeeds.length - 1)
                const SizedBox(height: 12),
            ],
          ],
        ),
      ),
    );
  }
}

class _OrderFinanceTab extends StatelessWidget {
  const _OrderFinanceTab({required this.order});

  final OrderRecord order;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        LayoutBuilder(
          builder: (context, constraints) {
            final compactLayout = constraints.maxWidth < 760;
            final cardWidth = compactLayout
                ? constraints.maxWidth
                : (constraints.maxWidth - 12) / 2;

            return Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                SizedBox(
                  width: cardWidth,
                  child: _DetailsCard(
                    title: 'Financeiro do pedido',
                    rows: [
                      _DetailsRow(
                        label: 'Taxa de entrega',
                        value: order.deliveryFee.format(),
                      ),
                      _DetailsRow(
                        label: 'Total',
                        value: order.orderTotal.format(),
                      ),
                      _DetailsRow(
                        label: 'Entrou',
                        value: order.receivedAmount.format(),
                      ),
                      _DetailsRow(
                        label: 'Restante',
                        value: order.remainingAmount.format(),
                      ),
                    ],
                  ),
                ),
                SizedBox(
                  width: cardWidth,
                  child: _DetailsCard(
                    title: 'Margem prevista',
                    rows: [
                      _DetailsRow(
                        label: 'Custo estimado',
                        value: order.estimatedCost.format(),
                      ),
                      _DetailsRow(
                        label: 'Venda sugerida',
                        value: order.suggestedSalePrice.format(),
                      ),
                      _DetailsRow(
                        label: 'Lucro previsto',
                        value: order.predictedProfit.format(),
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
        const SizedBox(height: 16),
        if (order.receivableEntries.isEmpty)
          const AppEmptyState(
            icon: Icons.payments_outlined,
            title: 'Nenhum lançamento interno ainda',
            message:
                'Quando o pedido é confirmado, o fluxo cria os lançamentos financeiros locais para os próximos módulos.',
          )
        else
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Lançamentos internos',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 16),
                  for (
                    var index = 0;
                    index < order.receivableEntries.length;
                    index++
                  ) ...[
                    _ReceivableEntryTile(entry: order.receivableEntries[index]),
                    if (index != order.receivableEntries.length - 1)
                      const SizedBox(height: 12),
                  ],
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class _OrderNotesTab extends StatelessWidget {
  const _OrderNotesTab({required this.order});

  final OrderRecord order;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _DetailsCard(
          title: 'Observações',
          rows: [
            _DetailsRow(
              label: 'Anotações',
              value: order.notes?.trim().isNotEmpty ?? false
                  ? order.notes!.trim()
                  : 'Nenhuma observação registrada ainda.',
            ),
            _DetailsRow(
              label: 'Foto de referência',
              value: order.displayReferencePhotoPath,
            ),
            _DetailsRow(
              label: 'Leitura automática',
              value: order.displaySmartReviewSummary,
            ),
          ],
        ),
      ],
    );
  }
}

class _OrderItemsCard extends StatelessWidget {
  const _OrderItemsCard({required this.order});

  final OrderRecord order;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Itens do pedido',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 6),
            Text(
              order.items.isEmpty
                  ? 'Nenhum item foi registrado neste pedido.'
                  : 'Os itens abaixo preservam o retrato salvo no momento da confirmação.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            if (order.items.isNotEmpty) ...[
              const SizedBox(height: 16),
              for (var index = 0; index < order.items.length; index++) ...[
                OrderItemCard(item: order.items[index], showLinkedBadge: true),
                if (index != order.items.length - 1) const SizedBox(height: 12),
              ],
              const SizedBox(height: 16),
              _DetailsRowWidget(
                row: _DetailsRow(
                  label: 'Soma dos itens',
                  value: order.itemsTotal.format(),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _DetailsCard extends StatelessWidget {
  const _DetailsCard({required this.title, required this.rows});

  final String title;
  final List<_DetailsRow> rows;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: theme.textTheme.titleLarge),
            const SizedBox(height: 16),
            for (var index = 0; index < rows.length; index++) ...[
              _DetailsRowWidget(row: rows[index]),
              if (index != rows.length - 1) const SizedBox(height: 14),
            ],
          ],
        ),
      ),
    );
  }
}

class _DetailsRow {
  const _DetailsRow({required this.label, required this.value});

  final String label;
  final String value;
}

class _DetailsRowWidget extends StatelessWidget {
  const _DetailsRowWidget({required this.row});

  final _DetailsRow row;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: Text(row.label, style: theme.textTheme.bodyMedium)),
        const SizedBox(width: 12),
        Flexible(
          child: Text(
            row.value,
            textAlign: TextAlign.end,
            style: theme.textTheme.titleMedium,
          ),
        ),
      ],
    );
  }
}

class _ProductionPlanTile extends StatelessWidget {
  const _ProductionPlanTile({required this.plan});

  final OrderProductionPlanRecord plan;

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
          Text(plan.title, style: theme.textTheme.titleMedium),
          const SizedBox(height: 6),
          Text(plan.displayDetails, style: theme.textTheme.bodyMedium),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _InfoPill(label: plan.status.label),
              if (plan.dueDate != null)
                _InfoPill(label: AppFormatters.dayMonthYear(plan.dueDate!)),
            ],
          ),
        ],
      ),
    );
  }
}

class _MaterialNeedRecordTile extends StatelessWidget {
  const _MaterialNeedRecordTile({required this.need});

  final OrderMaterialNeedRecord need;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: need.hasShortage
            ? theme.colorScheme.errorContainer
            : theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  need.nameSnapshot,
                  style: theme.textTheme.titleMedium,
                ),
              ),
              const SizedBox(width: 12),
              _InfoPill(label: need.materialType.label),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Precisa de ${need.displayRequiredQuantity} • disponível ${need.displayAvailableQuantity}',
            style: theme.textTheme.bodyMedium,
          ),
          if (need.hasShortage) ...[
            const SizedBox(height: 8),
            Text(
              'Falta prevista: ${need.displayShortageQuantity}',
              style: theme.textTheme.titleSmall,
            ),
          ],
          if (need.note?.trim().isNotEmpty ?? false) ...[
            const SizedBox(height: 8),
            Text(need.displayNote, style: theme.textTheme.bodySmall),
          ],
        ],
      ),
    );
  }
}

class _ReceivableEntryTile extends StatelessWidget {
  const _ReceivableEntryTile({required this.entry});

  final OrderReceivableEntryRecord entry;

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
          Text(entry.description, style: theme.textTheme.titleMedium),
          const SizedBox(height: 6),
          Text(entry.amount.format(), style: theme.textTheme.titleLarge),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _InfoPill(label: entry.status.label),
              if (entry.dueDate != null)
                _InfoPill(label: AppFormatters.dayMonthYear(entry.dueDate!)),
            ],
          ),
        ],
      ),
    );
  }
}

class _InfoPill extends StatelessWidget {
  const _InfoPill({required this.label});

  final String label;

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
      child: Text(label, style: theme.textTheme.labelLarge),
    );
  }
}
