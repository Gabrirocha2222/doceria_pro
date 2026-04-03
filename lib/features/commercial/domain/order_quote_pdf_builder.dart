import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../../core/formatters/app_formatters.dart';
import '../../orders/domain/order.dart';
import '../../orders/domain/order_status.dart';
import 'business_brand_settings.dart';

abstract final class OrderQuotePdfBuilder {
  static Future<Uint8List> build({
    required OrderRecord order,
    required BusinessBrandSettings brandSettings,
    PdfPageFormat pageFormat = PdfPageFormat.a4,
  }) async {
    final accent = PdfColor.fromInt(brandSettings.accent.primaryColorValue);
    final softAccent = PdfColor.fromInt(brandSettings.accent.softColorValue);
    final strongAccent = PdfColor.fromInt(
      brandSettings.accent.strongColorValue,
    );
    final document = pw.Document(
      title: _documentTitle(order),
      author: brandSettings.displayBusinessName,
      subject: 'Orçamento comercial',
    );

    document.addPage(
      pw.MultiPage(
        pageFormat: pageFormat,
        margin: const pw.EdgeInsets.all(28),
        build: (context) {
          return [
            _buildHeader(
              order: order,
              brandSettings: brandSettings,
              accent: accent,
              softAccent: softAccent,
            ),
            pw.SizedBox(height: 20),
            _buildSummaryCards(
              order: order,
              strongAccent: strongAccent,
              softAccent: softAccent,
            ),
            pw.SizedBox(height: 18),
            _buildItemsSection(
              order: order,
              strongAccent: strongAccent,
              softAccent: softAccent,
            ),
            pw.SizedBox(height: 18),
            _buildTotalsSection(
              order: order,
              strongAccent: strongAccent,
              softAccent: softAccent,
            ),
            if (order.notes?.trim().isNotEmpty ?? false) ...[
              pw.SizedBox(height: 18),
              _buildNotesSection(
                notes: order.notes!.trim(),
                strongAccent: strongAccent,
                softAccent: softAccent,
              ),
            ],
            pw.SizedBox(height: 18),
            _buildFooter(
              brandSettings: brandSettings,
              accent: accent,
              softAccent: softAccent,
            ),
          ];
        },
      ),
    );

    return document.save();
  }

  static String buildFileName({
    required OrderRecord order,
    required BusinessBrandSettings brandSettings,
  }) {
    final clientSlug = _slugify(order.displayClientName);
    final businessSlug = _slugify(brandSettings.displayBusinessName);
    final dateLabel = order.eventDate == null
        ? 'sem-data'
        : '${order.eventDate!.year}-${order.eventDate!.month.toString().padLeft(2, '0')}-${order.eventDate!.day.toString().padLeft(2, '0')}';

    return '${businessSlug}_orcamento_${clientSlug}_$dateLabel.pdf';
  }

  static pw.Widget _buildHeader({
    required OrderRecord order,
    required BusinessBrandSettings brandSettings,
    required PdfColor accent,
    required PdfColor softAccent,
  }) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(22),
      decoration: pw.BoxDecoration(
        color: softAccent,
        borderRadius: pw.BorderRadius.circular(24),
      ),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Expanded(
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  _pdfSafeText(brandSettings.displayBusinessName),
                  style: pw.TextStyle(
                    color: accent,
                    fontSize: 22,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.SizedBox(height: 6),
                pw.Text(
                  _pdfSafeText(brandSettings.displayTagline),
                  style: const pw.TextStyle(
                    fontSize: 11,
                    color: PdfColors.grey800,
                  ),
                ),
              ],
            ),
          ),
          pw.SizedBox(width: 24),
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.end,
            children: [
              pw.Text(
                _documentTitle(order),
                style: pw.TextStyle(
                  color: accent,
                  fontSize: 18,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.SizedBox(height: 4),
              pw.Text(
                'Atualizado em ${AppFormatters.dayMonthYear(order.updatedAt)}',
                style: const pw.TextStyle(
                  fontSize: 10,
                  color: PdfColors.grey700,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  static pw.Widget _buildSummaryCards({
    required OrderRecord order,
    required PdfColor strongAccent,
    required PdfColor softAccent,
  }) {
    final cards = [
      ('Cliente', order.displayClientName),
      (
        'Data',
        order.eventDate == null
            ? 'A combinar'
            : AppFormatters.dayMonthYear(order.eventDate!),
      ),
      ('Atendimento', order.fulfillmentMethod?.label ?? 'A definir'),
      ('Status', order.status.label),
    ];

    return pw.Wrap(
      spacing: 12,
      runSpacing: 12,
      children: [
        for (final card in cards)
          pw.Container(
            width: 245,
            padding: const pw.EdgeInsets.all(16),
            decoration: pw.BoxDecoration(
              color: PdfColors.white,
              borderRadius: pw.BorderRadius.circular(18),
              border: pw.Border.all(color: softAccent, width: 1.2),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  card.$1,
                  style: pw.TextStyle(
                    color: strongAccent,
                    fontSize: 10,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.SizedBox(height: 6),
                pw.Text(card.$2, style: const pw.TextStyle(fontSize: 12)),
              ],
            ),
          ),
      ],
    );
  }

  static pw.Widget _buildItemsSection({
    required OrderRecord order,
    required PdfColor strongAccent,
    required PdfColor softAccent,
  }) {
    final rows = order.items.isEmpty
        ? [
            const ['--', 'Itens em definição', '--', '--'],
          ]
        : [
            for (final item in order.items)
              [
                item.displayQuantity,
                _pdfSafeText(item.displayName),
                item.price.format(),
                item.lineTotal.format(),
              ],
          ];

    return _buildSectionContainer(
      title: 'Itens do orçamento',
      strongAccent: strongAccent,
      child: pw.TableHelper.fromTextArray(
        headers: const ['Qtd.', 'Descrição', 'Valor unit.', 'Subtotal'],
        data: rows,
        headerStyle: pw.TextStyle(
          color: PdfColors.white,
          fontWeight: pw.FontWeight.bold,
          fontSize: 10,
        ),
        headerDecoration: pw.BoxDecoration(
          color: strongAccent,
          borderRadius: const pw.BorderRadius.vertical(
            top: pw.Radius.circular(12),
          ),
        ),
        cellStyle: const pw.TextStyle(fontSize: 10.5),
        cellPadding: const pw.EdgeInsets.symmetric(
          horizontal: 10,
          vertical: 12,
        ),
        rowDecoration: pw.BoxDecoration(
          border: pw.Border(
            bottom: pw.BorderSide(color: softAccent, width: 0.8),
          ),
        ),
        columnWidths: {
          0: const pw.FixedColumnWidth(44),
          1: const pw.FlexColumnWidth(3),
          2: const pw.FlexColumnWidth(1.2),
          3: const pw.FlexColumnWidth(1.2),
        },
        cellAlignments: {
          0: pw.Alignment.centerLeft,
          1: pw.Alignment.centerLeft,
          2: pw.Alignment.centerRight,
          3: pw.Alignment.centerRight,
        },
      ),
    );
  }

  static pw.Widget _buildTotalsSection({
    required OrderRecord order,
    required PdfColor strongAccent,
    required PdfColor softAccent,
  }) {
    final rows = <(String, String)>[
      ('Soma dos itens', order.itemsTotal.format()),
      if (order.deliveryFee.isPositive) ('Entrega', order.deliveryFee.format()),
      ('Total', order.orderTotal.format()),
      ('Entrou', order.receivedAmount.format()),
      ('Restante', order.remainingAmount.format()),
    ];

    return _buildSectionContainer(
      title: 'Valores',
      strongAccent: strongAccent,
      child: pw.Column(
        children: [
          for (var index = 0; index < rows.length; index++) ...[
            pw.Row(
              children: [
                pw.Expanded(child: pw.Text(rows[index].$1)),
                pw.SizedBox(width: 12),
                pw.Text(
                  rows[index].$2,
                  style: pw.TextStyle(
                    color: index == rows.length - 3
                        ? strongAccent
                        : PdfColors.black,
                    fontWeight: index == rows.length - 3
                        ? pw.FontWeight.bold
                        : pw.FontWeight.normal,
                  ),
                ),
              ],
            ),
            if (index != rows.length - 1) ...[
              pw.SizedBox(height: 10),
              pw.Divider(color: softAccent, height: 1),
              pw.SizedBox(height: 10),
            ],
          ],
        ],
      ),
    );
  }

  static pw.Widget _buildNotesSection({
    required String notes,
    required PdfColor strongAccent,
    required PdfColor softAccent,
  }) {
    return _buildSectionContainer(
      title: 'Observações',
      strongAccent: strongAccent,
      child: pw.Text(
        _pdfSafeText(notes),
        style: const pw.TextStyle(fontSize: 11),
      ),
    );
  }

  static pw.Widget _buildFooter({
    required BusinessBrandSettings brandSettings,
    required PdfColor accent,
    required PdfColor softAccent,
  }) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(18),
      decoration: pw.BoxDecoration(
        color: softAccent,
        borderRadius: pw.BorderRadius.circular(18),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            _pdfSafeText(brandSettings.displayFooterMessage),
            style: const pw.TextStyle(fontSize: 10.5),
          ),
          if (brandSettings.hasCommercialContact) ...[
            pw.SizedBox(height: 10),
            for (final line in brandSettings.contactLines)
              pw.Padding(
                padding: const pw.EdgeInsets.only(bottom: 4),
                child: pw.Text(
                  _pdfSafeText(line),
                  style: pw.TextStyle(
                    color: accent,
                    fontSize: 10.5,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
              ),
          ],
        ],
      ),
    );
  }

  static pw.Widget _buildSectionContainer({
    required String title,
    required PdfColor strongAccent,
    required pw.Widget child,
  }) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(18),
      decoration: pw.BoxDecoration(
        color: PdfColors.white,
        borderRadius: pw.BorderRadius.circular(18),
        border: pw.Border.all(color: PdfColors.grey300),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            title,
            style: pw.TextStyle(
              color: strongAccent,
              fontSize: 13,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
          pw.SizedBox(height: 12),
          child,
        ],
      ),
    );
  }

  static String _documentTitle(OrderRecord order) {
    return switch (order.status) {
      OrderStatus.budget || OrderStatus.awaitingDeposit => 'Orçamento',
      _ => 'Resumo comercial do pedido',
    };
  }

  static String _slugify(String value) {
    const replacements = {
      'a': ['á', 'à', 'â', 'ã', 'ä'],
      'e': ['é', 'è', 'ê', 'ë'],
      'i': ['í', 'ì', 'î', 'ï'],
      'o': ['ó', 'ò', 'ô', 'õ', 'ö'],
      'u': ['ú', 'ù', 'û', 'ü'],
      'c': ['ç'],
    };

    var normalized = value.toLowerCase().trim();
    replacements.forEach((replacement, accents) {
      for (final accent in accents) {
        normalized = normalized.replaceAll(accent, replacement);
      }
    });

    normalized = normalized.replaceAll(RegExp(r'[^a-z0-9]+'), '-');
    normalized = normalized.replaceAll(RegExp(r'-{2,}'), '-');
    normalized = normalized.replaceAll(RegExp(r'^-|-$'), '');

    if (normalized.isEmpty) {
      return 'pedido';
    }

    return normalized;
  }

  static String _pdfSafeText(String value) {
    return value.replaceAll('•', ' - ');
  }
}
