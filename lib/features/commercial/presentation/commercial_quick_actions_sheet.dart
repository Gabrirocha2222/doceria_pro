import 'package:flutter/material.dart';

enum OrderCommercialAction { pdfQuote, whatsappSummary, brandSettings }

class CommercialQuickActionsSheet extends StatelessWidget {
  const CommercialQuickActionsSheet({super.key});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Camada comercial',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 6),
            Text(
              'Escolha como quer apresentar este pedido: PDF elegante, resumo para WhatsApp ou ajuste da identidade da marca.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 16),
            _CommercialActionCard(
              icon: Icons.picture_as_pdf_outlined,
              title: 'Gerar PDF do orçamento',
              message:
                  'Abra uma prévia pronta para salvar, imprimir ou compartilhar.',
              onTap: () =>
                  Navigator.of(context).pop(OrderCommercialAction.pdfQuote),
            ),
            const SizedBox(height: 12),
            _CommercialActionCard(
              icon: Icons.chat_bubble_outline_rounded,
              title: 'Resumo para WhatsApp',
              message:
                  'Monte um texto curto e comercial para enviar direto no compartilhamento do aparelho.',
              onTap: () => Navigator.of(
                context,
              ).pop(OrderCommercialAction.whatsappSummary),
            ),
            const SizedBox(height: 12),
            _CommercialActionCard(
              icon: Icons.palette_outlined,
              title: 'Ajustar identidade',
              message:
                  'Defina nome do negócio, contato e a cor que sai nos materiais comerciais.',
              onTap: () => Navigator.of(
                context,
              ).pop(OrderCommercialAction.brandSettings),
            ),
          ],
        ),
      ),
    );
  }
}

class _CommercialActionCard extends StatelessWidget {
  const _CommercialActionCard({
    required this.icon,
    required this.title,
    required this.message,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String message;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(28),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: theme.colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(icon, color: theme.colorScheme.primary),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: theme.textTheme.titleMedium),
                    const SizedBox(height: 6),
                    Text(message, style: theme.textTheme.bodyMedium),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Icon(
                Icons.arrow_forward_ios_rounded,
                size: 18,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
