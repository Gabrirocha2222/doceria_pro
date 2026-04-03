import '../../../core/formatters/app_formatters.dart';
import '../../orders/domain/order.dart';
import '../../orders/domain/order_status.dart';
import 'business_brand_settings.dart';

abstract final class OrderShareTextBuilder {
  static String build({
    required OrderRecord order,
    required BusinessBrandSettings brandSettings,
  }) {
    final buffer = StringBuffer()
      ..writeln('*${brandSettings.displayBusinessName}*')
      ..writeln(brandSettings.displayTagline)
      ..writeln()
      ..writeln('*${_titleForOrder(order)}*')
      ..writeln(_subtitleForOrder(order))
      ..writeln();

    final summaryRows = <String>[
      'Cliente: ${order.displayClientName}',
      'Status: ${order.status.label}',
      'Data: ${order.eventDate == null ? 'A combinar' : AppFormatters.dayMonthYear(order.eventDate!)}',
      'Atendimento: ${order.fulfillmentMethod?.label ?? 'A definir'}',
    ];

    for (final row in summaryRows) {
      buffer.writeln(row);
    }

    if (order.displaySuggestedPackagingName != 'Sem sugestão automática') {
      buffer.writeln(
        'Embalagem sugerida: ${order.displaySuggestedPackagingName}',
      );
    }

    buffer
      ..writeln()
      ..writeln('*Itens*');

    if (order.items.isEmpty) {
      buffer.writeln('- Itens ainda em definição.');
    } else {
      for (final item in order.items) {
        final valueLabel = item.quantity > 1
            ? '${item.displayQuantity} ${item.displayName} • ${item.price.format()} cada • ${item.lineTotal.format()}'
            : '${item.displayQuantity} ${item.displayName} • ${item.lineTotal.format()}';
        buffer.writeln('- $valueLabel');
      }
    }

    buffer
      ..writeln()
      ..writeln('*Valores*')
      ..writeln('Total: ${order.orderTotal.format()}');

    if (order.deliveryFee.isPositive) {
      buffer.writeln('Entrega: ${order.deliveryFee.format()}');
    }
    if (order.receivedAmount.isPositive) {
      buffer.writeln('Entrada registrada: ${order.receivedAmount.format()}');
    }
    if (order.remainingAmount.isPositive) {
      buffer.writeln('Restante: ${order.remainingAmount.format()}');
    }

    final trimmedNotes = order.notes?.trim();
    if (trimmedNotes != null && trimmedNotes.isNotEmpty) {
      buffer
        ..writeln()
        ..writeln('*Observações*')
        ..writeln(trimmedNotes);
    }

    buffer
      ..writeln()
      ..writeln(brandSettings.displayFooterMessage);

    if (brandSettings.hasCommercialContact) {
      buffer.writeln();
      for (final line in brandSettings.contactLines) {
        buffer.writeln(line);
      }
    }

    return buffer.toString().trimRight();
  }

  static String _titleForOrder(OrderRecord order) {
    final title = switch (order.status) {
      OrderStatus.budget || OrderStatus.awaitingDeposit => 'Orçamento',
      _ => 'Resumo do pedido',
    };

    return '$title para ${order.displayClientName}';
  }

  static String _subtitleForOrder(OrderRecord order) {
    if (order.items.isEmpty) {
      return 'Segue uma prévia comercial para alinharmos os próximos detalhes.';
    }

    return 'Segue um resumo claro para você conferir os itens e os valores.';
  }
}
