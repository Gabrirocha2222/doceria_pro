import 'dart:convert';

import 'package:doceria_pro/core/money/money.dart';
import 'package:doceria_pro/features/commercial/domain/business_brand_settings.dart';
import 'package:doceria_pro/features/commercial/domain/order_quote_pdf_builder.dart';
import 'package:doceria_pro/features/commercial/domain/order_share_text_builder.dart';
import 'package:doceria_pro/features/orders/domain/order.dart';
import 'package:doceria_pro/features/orders/domain/order_fulfillment_method.dart';
import 'package:doceria_pro/features/orders/domain/order_status.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

void main() {
  setUpAll(() async {
    await initializeDateFormatting('pt_BR');
  });

  final brandSettings = const BusinessBrandSettings(
    businessName: 'Atelier da Ana',
    tagline: 'Doces finos para momentos especiais.',
    whatsAppPhone: '11999999999',
    instagramHandle: '@atelierdaana',
    footerMessage: 'Condições válidas por 3 dias.',
    accent: BusinessBrandAccent.terracotta,
  );

  final order = OrderRecord(
    id: 'order-1',
    clientNameSnapshot: 'Amanda',
    eventDate: DateTime(2026, 5, 10),
    fulfillmentMethod: OrderFulfillmentMethod.delivery,
    deliveryFee: Money.fromCents(1500),
    notes: 'Topo floral em tons claros.',
    estimatedCost: Money.fromCents(12000),
    suggestedSalePrice: Money.fromCents(26000),
    predictedProfit: Money.fromCents(12500),
    suggestedPackagingNameSnapshot: 'Caixa premium',
    orderTotal: Money.fromCents(27500),
    depositAmount: Money.fromCents(8000),
    status: OrderStatus.budget,
    createdAt: DateTime(2026, 4, 2),
    updatedAt: DateTime(2026, 4, 3),
    items: [
      OrderItemRecord(
        id: 'item-1',
        orderId: 'order-1',
        productId: 'product-1',
        itemNameSnapshot: 'Bolo buttercream',
        flavorSnapshot: 'Baunilha com morango',
        variationSnapshot: '20 cm',
        price: Money.fromCents(26000),
        quantity: 1,
        notes: null,
        sortOrder: 0,
      ),
    ],
  );

  test('builds a WhatsApp-friendly order summary with brand identity', () {
    final text = OrderShareTextBuilder.build(
      order: order,
      brandSettings: brandSettings,
    );

    expect(text, contains('*Atelier da Ana*'));
    expect(text, contains('*Orçamento para Amanda*'));
    expect(text, contains('Data: 10/05/2026'));
    expect(text, contains('Atendimento: Entrega'));
    expect(text, contains('Caixa premium'));
    expect(text, contains('Total: R\$ 275,00'));
    expect(text, contains('Entrega: R\$ 15,00'));
    expect(text, contains('Observações'));
    expect(text, contains('WhatsApp: (11) 99999-9999'));
    expect(text, contains('Instagram: @atelierdaana'));
  });

  test('builds a non-empty PDF quote document', () async {
    final pdfBytes = await OrderQuotePdfBuilder.build(
      order: order,
      brandSettings: brandSettings,
    );

    expect(pdfBytes, isNotEmpty);
    expect(utf8.decode(pdfBytes.take(5).toList()), '%PDF-');
    expect(
      OrderQuotePdfBuilder.buildFileName(
        order: order,
        brandSettings: brandSettings,
      ),
      'atelier-da-ana_orcamento_amanda_2026-05-10.pdf',
    );
  });
}
