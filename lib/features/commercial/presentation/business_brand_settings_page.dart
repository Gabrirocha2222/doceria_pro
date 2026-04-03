import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/widgets/app_page_scaffold.dart';
import '../../../core/widgets/states/app_error_state.dart';
import '../../../core/widgets/states/app_loading_state.dart';
import '../application/business_brand_settings_providers.dart';
import '../domain/business_brand_settings.dart';

class BusinessBrandSettingsPage extends ConsumerStatefulWidget {
  const BusinessBrandSettingsPage({super.key});

  static const basePath = '/business/commercial';

  @override
  ConsumerState<BusinessBrandSettingsPage> createState() =>
      _BusinessBrandSettingsPageState();
}

class _BusinessBrandSettingsPageState
    extends ConsumerState<BusinessBrandSettingsPage> {
  final _businessNameController = TextEditingController();
  final _taglineController = TextEditingController();
  final _whatsAppPhoneController = TextEditingController();
  final _instagramController = TextEditingController();
  final _footerMessageController = TextEditingController();

  bool _hasSeededForm = false;
  bool _isSaving = false;
  BusinessBrandAccent _selectedAccent = BusinessBrandSettings.defaults.accent;

  @override
  void initState() {
    super.initState();
    _businessNameController.addListener(_handlePreviewChanged);
    _taglineController.addListener(_handlePreviewChanged);
    _whatsAppPhoneController.addListener(_handlePreviewChanged);
    _instagramController.addListener(_handlePreviewChanged);
    _footerMessageController.addListener(_handlePreviewChanged);
  }

  @override
  void dispose() {
    _businessNameController.dispose();
    _taglineController.dispose();
    _whatsAppPhoneController.dispose();
    _instagramController.dispose();
    _footerMessageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final settingsAsync = ref.watch(businessBrandSettingsProvider);

    return settingsAsync.when(
      loading: () => const AppPageScaffold(
        title: 'Marca e orçamento',
        subtitle: 'Carregando sua identidade comercial local.',
        child: AppLoadingState(message: 'Carregando identidade comercial...'),
      ),
      error: (error, stackTrace) => AppPageScaffold(
        title: 'Marca e orçamento',
        subtitle: 'Não foi possível abrir a identidade comercial agora.',
        child: AppErrorState(
          title: 'Não deu para carregar a identidade comercial',
          message:
              'Tente novamente. Se nada foi salvo ainda, os padrões entram sozinhos assim que a tela abrir.',
          actionLabel: 'Tentar de novo',
          onAction: () => ref.invalidate(businessBrandSettingsProvider),
        ),
      ),
      data: (settings) {
        _seedFormIfNeeded(settings);
        final previewSettings = _currentDraftSettings();

        return AppPageScaffold(
          title: 'Marca e orçamento',
          subtitle:
              'Defina como seu nome, contato e tom visual aparecem no PDF e no resumo compartilhável.',
          trailing: FilledButton.icon(
            onPressed: _isSaving ? null : _save,
            icon: Icon(_isSaving ? Icons.sync_rounded : Icons.save_rounded),
            label: Text(_isSaving ? 'Salvando...' : 'Salvar identidade'),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _BrandPreviewCard(settings: previewSettings),
              const SizedBox(height: 16),
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
                        child: _FormCard(
                          title: 'Como sua marca aparece',
                          subtitle:
                              'Esse bloco entra no topo do PDF e no começo do resumo compartilhado.',
                          child: Column(
                            children: [
                              TextField(
                                controller: _businessNameController,
                                textCapitalization: TextCapitalization.words,
                                decoration: const InputDecoration(
                                  labelText: 'Nome do negócio',
                                  hintText: 'Ex.: Atelier da Ana',
                                ),
                              ),
                              const SizedBox(height: 12),
                              TextField(
                                controller: _taglineController,
                                textCapitalization:
                                    TextCapitalization.sentences,
                                decoration: const InputDecoration(
                                  labelText: 'Frase curta',
                                  hintText:
                                      'Ex.: Doces finos para momentos especiais.',
                                ),
                                maxLines: 2,
                              ),
                            ],
                          ),
                        ),
                      ),
                      SizedBox(
                        width: cardWidth,
                        child: _FormCard(
                          title: 'Contato comercial',
                          subtitle:
                              'Use só o que realmente ajuda a fechar o pedido pelo WhatsApp ou Instagram.',
                          child: Column(
                            children: [
                              TextField(
                                controller: _whatsAppPhoneController,
                                keyboardType: TextInputType.phone,
                                decoration: const InputDecoration(
                                  labelText: 'WhatsApp comercial',
                                  hintText: 'Ex.: 11999999999',
                                ),
                              ),
                              const SizedBox(height: 12),
                              TextField(
                                controller: _instagramController,
                                decoration: const InputDecoration(
                                  labelText: 'Instagram',
                                  hintText: 'Ex.: @atelierdaana',
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      SizedBox(
                        width: constraints.maxWidth,
                        child: _FormCard(
                          title: 'Tom visual',
                          subtitle:
                              'Escolha a cor que vai liderar o cabeçalho e os destaques do PDF.',
                          child: Wrap(
                            spacing: 12,
                            runSpacing: 12,
                            children: [
                              for (final accent in BusinessBrandAccent.values)
                                _AccentChoiceChip(
                                  accent: accent,
                                  selected: accent == _selectedAccent,
                                  onTap: () {
                                    setState(() => _selectedAccent = accent);
                                  },
                                ),
                            ],
                          ),
                        ),
                      ),
                      SizedBox(
                        width: constraints.maxWidth,
                        child: _FormCard(
                          title: 'Mensagem final',
                          subtitle:
                              'Feche o material com uma observação curta e comercial, sem virar contrato pesado.',
                          child: TextField(
                            controller: _footerMessageController,
                            textCapitalization: TextCapitalization.sentences,
                            decoration: const InputDecoration(
                              labelText: 'Rodapé comercial',
                              hintText:
                                  'Ex.: Valores e disponibilidade sujeitos à confirmação.',
                            ),
                            minLines: 3,
                            maxLines: 5,
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }

  void _handlePreviewChanged() {
    if (!mounted) {
      return;
    }

    setState(() {});
  }

  void _seedFormIfNeeded(BusinessBrandSettings settings) {
    if (_hasSeededForm) {
      return;
    }

    _businessNameController.text = settings.businessName;
    _taglineController.text = settings.tagline;
    _whatsAppPhoneController.text = settings.whatsAppPhone;
    _instagramController.text = settings.instagramHandle;
    _footerMessageController.text = settings.footerMessage;
    _selectedAccent = settings.accent;
    _hasSeededForm = true;
  }

  BusinessBrandSettings _currentDraftSettings() {
    return BusinessBrandSettings(
      businessName: _businessNameController.text,
      tagline: _taglineController.text,
      whatsAppPhone: _whatsAppPhoneController.text,
      instagramHandle: _instagramController.text,
      footerMessage: _footerMessageController.text,
      accent: _selectedAccent,
    );
  }

  Future<void> _save() async {
    setState(() => _isSaving = true);

    try {
      await ref
          .read(businessBrandSettingsRepositoryProvider)
          .save(_currentDraftSettings());
      ref.invalidate(businessBrandSettingsProvider);

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Identidade comercial salva neste aparelho.'),
        ),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Não foi possível salvar agora: $error')),
      );
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }
}

class _BrandPreviewCard extends StatelessWidget {
  const _BrandPreviewCard({required this.settings});

  final BusinessBrandSettings settings;

  @override
  Widget build(BuildContext context) {
    final accentColor = Color(settings.accent.primaryColorValue);
    final softColor = Color(settings.accent.softColorValue);
    final strongColor = Color(settings.accent.strongColorValue);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [softColor, Theme.of(context).colorScheme.surface],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(32),
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.86),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              'Prévia da camada comercial',
              style: Theme.of(
                context,
              ).textTheme.labelLarge?.copyWith(color: strongColor),
            ),
          ),
          const SizedBox(height: 18),
          Text(
            settings.displayBusinessName,
            style: Theme.of(
              context,
            ).textTheme.headlineSmall?.copyWith(color: accentColor),
          ),
          const SizedBox(height: 6),
          Text(
            settings.displayTagline,
            style: Theme.of(context).textTheme.bodyLarge,
          ),
          const SizedBox(height: 20),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _PreviewMetric(label: 'Cor', value: settings.accent.label),
              _PreviewMetric(
                label: 'WhatsApp',
                value: settings.formattedWhatsAppPhone ?? 'Não informado',
              ),
              _PreviewMetric(
                label: 'Instagram',
                value: settings.displayInstagramHandle ?? 'Não informado',
              ),
            ],
          ),
          const SizedBox(height: 20),
          Text(
            settings.displayFooterMessage,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ],
      ),
    );
  }
}

class _PreviewMetric extends StatelessWidget {
  const _PreviewMetric({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: Theme.of(context).textTheme.labelLarge),
            const SizedBox(height: 6),
            Text(value, style: Theme.of(context).textTheme.titleMedium),
          ],
        ),
      ),
    );
  }
}

class _FormCard extends StatelessWidget {
  const _FormCard({
    required this.title,
    required this.subtitle,
    required this.child,
  });

  final String title;
  final String subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 6),
            Text(subtitle, style: Theme.of(context).textTheme.bodyMedium),
            const SizedBox(height: 16),
            child,
          ],
        ),
      ),
    );
  }
}

class _AccentChoiceChip extends StatelessWidget {
  const _AccentChoiceChip({
    required this.accent,
    required this.selected,
    required this.onTap,
  });

  final BusinessBrandAccent accent;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final primaryColor = Color(accent.primaryColorValue);
    final softColor = Color(accent.softColorValue);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: onTap,
        child: Ink(
          width: 220,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: softColor,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: selected
                  ? primaryColor
                  : Theme.of(context).colorScheme.outlineVariant,
              width: selected ? 1.6 : 1,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: primaryColor,
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  accent.label,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              if (selected)
                Icon(Icons.check_circle_rounded, color: primaryColor),
            ],
          ),
        ),
      ),
    );
  }
}
