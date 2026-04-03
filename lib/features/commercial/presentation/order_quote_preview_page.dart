import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:pdf/pdf.dart';
import 'package:printing/printing.dart';

import '../../../app/navigation/app_destinations.dart';
import '../../../core/responsive/app_breakpoints.dart';
import '../../../core/widgets/states/app_error_state.dart';
import '../../../core/widgets/states/app_loading_state.dart';
import '../application/business_brand_settings_providers.dart';
import '../domain/order_quote_pdf_builder.dart';
import '../../orders/application/order_providers.dart';

class OrderQuotePreviewPage extends ConsumerWidget {
  const OrderQuotePreviewPage({super.key, required this.orderId});

  final String orderId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final orderAsync = ref.watch(orderProvider(orderId));
    final brandSettingsAsync = ref.watch(businessBrandSettingsProvider);

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: orderAsync.when(
          loading: () => const Center(
            child: AppLoadingState(message: 'Montando PDF do orçamento...'),
          ),
          error: (error, stackTrace) => Center(
            child: AppErrorState(
              title: 'Não deu para abrir o PDF',
              message: 'Volte para o pedido e tente novamente.',
              actionLabel: 'Voltar para pedidos',
              onAction: () => context.go(AppDestinations.orders.path),
            ),
          ),
          data: (order) {
            if (order == null) {
              return Center(
                child: AppErrorState(
                  title: 'Pedido não encontrado',
                  message:
                      'O pedido não está disponível neste aparelho para gerar o PDF.',
                  actionLabel: 'Voltar para pedidos',
                  onAction: () => context.go(AppDestinations.orders.path),
                ),
              );
            }

            return brandSettingsAsync.when(
              loading: () => const Center(
                child: AppLoadingState(
                  message: 'Carregando identidade comercial...',
                ),
              ),
              error: (error, stackTrace) => Center(
                child: AppErrorState(
                  title: 'Não deu para carregar a identidade comercial',
                  message:
                      'Tente novamente para montar o PDF com sua marca local.',
                  actionLabel: 'Tentar de novo',
                  onAction: () => ref.invalidate(businessBrandSettingsProvider),
                ),
              ),
              data: (brandSettings) {
                final width = MediaQuery.sizeOf(context).width;
                final compactLayout = AppBreakpoints.isCompactWidth(width);
                final horizontalPadding = compactLayout ? 20.0 : 32.0;

                return Column(
                  children: [
                    Padding(
                      padding: EdgeInsets.fromLTRB(
                        horizontalPadding,
                        24,
                        horizontalPadding,
                        16,
                      ),
                      child: Align(
                        alignment: Alignment.topCenter,
                        child: ConstrainedBox(
                          constraints: BoxConstraints(
                            maxWidth: AppBreakpoints.contentMaxWidth(width),
                          ),
                          child: compactLayout
                              ? Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    _QuotePreviewHeader(
                                      orderClientName: order.displayClientName,
                                    ),
                                    const SizedBox(height: 16),
                                    _QuotePreviewActions(orderId: order.id),
                                  ],
                                )
                              : Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Expanded(
                                      child: _QuotePreviewHeader(
                                        orderClientName:
                                            order.displayClientName,
                                      ),
                                    ),
                                    const SizedBox(width: 16),
                                    _QuotePreviewActions(orderId: order.id),
                                  ],
                                ),
                        ),
                      ),
                    ),
                    Expanded(
                      child: Padding(
                        padding: EdgeInsets.fromLTRB(
                          horizontalPadding,
                          0,
                          horizontalPadding,
                          24,
                        ),
                        child: Align(
                          alignment: Alignment.topCenter,
                          child: ConstrainedBox(
                            constraints: BoxConstraints(
                              maxWidth: AppBreakpoints.contentMaxWidth(width),
                            ),
                            child: Card(
                              clipBehavior: Clip.antiAlias,
                              child: PdfPreview(
                                maxPageWidth: 720,
                                canChangeOrientation: false,
                                canChangePageFormat: false,
                                canDebug: false,
                                pdfFileName: OrderQuotePdfBuilder.buildFileName(
                                  order: order,
                                  brandSettings: brandSettings,
                                ),
                                initialPageFormat: PdfPageFormat.a4,
                                build: (format) => OrderQuotePdfBuilder.build(
                                  order: order,
                                  brandSettings: brandSettings,
                                  pageFormat: format,
                                ),
                                loadingWidget: const Center(
                                  child: AppLoadingState(
                                    message: 'Gerando visual do PDF...',
                                  ),
                                ),
                                onError: (context, error) => AppErrorState(
                                  title: 'Não foi possível montar o PDF',
                                  message:
                                      'Tente novamente. Os dados do pedido continuam salvos localmente.',
                                  actionLabel: 'Tentar de novo',
                                  onAction: () {
                                    ref.invalidate(orderProvider(orderId));
                                  },
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              },
            );
          },
        ),
      ),
    );
  }
}

class _QuotePreviewHeader extends StatelessWidget {
  const _QuotePreviewHeader({required this.orderClientName});

  final String orderClientName;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'PDF do orçamento',
          style: Theme.of(context).textTheme.headlineMedium,
        ),
        const SizedBox(height: 8),
        Text(
          'Prévia pronta para salvar, imprimir ou compartilhar o material comercial de $orderClientName.',
          style: Theme.of(context).textTheme.bodyLarge,
        ),
      ],
    );
  }
}

class _QuotePreviewActions extends StatelessWidget {
  const _QuotePreviewActions({required this.orderId});

  final String orderId;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: [
        OutlinedButton.icon(
          onPressed: () => context.pop(),
          icon: const Icon(Icons.arrow_back_rounded),
          label: const Text('Voltar'),
        ),
        FilledButton.tonalIcon(
          onPressed: () => context.push('/business/commercial'),
          icon: const Icon(Icons.palette_outlined),
          label: const Text('Editar marca'),
        ),
      ],
    );
  }
}
