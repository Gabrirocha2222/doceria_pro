import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/navigation/app_destinations.dart';
import '../../../core/money/currency_text_input_formatter.dart';
import '../../../core/money/money.dart';
import '../../../core/widgets/app_page_scaffold.dart';
import '../../../core/widgets/states/app_error_state.dart';
import '../../../core/widgets/states/app_loading_state.dart';
import '../application/packaging_providers.dart';
import '../domain/packaging.dart';
import '../domain/packaging_type.dart';
import 'widgets/packaging_stock_badge.dart';

class PackagingFormPage extends ConsumerWidget {
  const PackagingFormPage({super.key, this.packagingId});

  final String? packagingId;

  static final basePath = '${AppDestinations.businessSettings.path}/packaging';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (packagingId == null) {
      return const _PackagingFormView();
    }

    final packagingAsync = ref.watch(packagingProvider(packagingId!));

    return packagingAsync.when(
      loading: () => const AppPageScaffold(
        title: 'Abrindo embalagem',
        subtitle: 'Carregando os dados para edição.',
        child: AppLoadingState(message: 'Carregando embalagem...'),
      ),
      error: (error, stackTrace) => AppPageScaffold(
        title: 'Não deu para editar',
        subtitle: 'Algo falhou ao abrir esta embalagem.',
        child: AppErrorState(
          title: 'Embalagem indisponível',
          message: 'Volte para a lista e tente novamente.',
          actionLabel: 'Voltar para embalagens',
          onAction: () => context.go(basePath),
        ),
      ),
      data: (item) {
        if (item == null) {
          return AppPageScaffold(
            title: 'Embalagem não encontrada',
            subtitle: 'Não existe uma embalagem local com esse identificador.',
            child: AppErrorState(
              title: 'Embalagem não encontrada',
              message: 'Volte para a lista e escolha um cadastro salvo.',
              actionLabel: 'Voltar para embalagens',
              onAction: () => context.go(basePath),
            ),
          );
        }

        return _PackagingFormView(initialItem: item);
      },
    );
  }
}

class _PackagingFormView extends ConsumerStatefulWidget {
  const _PackagingFormView({this.initialItem});

  final PackagingRecord? initialItem;

  @override
  ConsumerState<_PackagingFormView> createState() => _PackagingFormViewState();
}

class _PackagingFormViewState extends ConsumerState<_PackagingFormView> {
  static const _currencyFormatter = CurrencyTextInputFormatter();

  late final TextEditingController _nameController;
  late final TextEditingController _costController;
  late final TextEditingController _stockController;
  late final TextEditingController _minimumStockController;
  late final TextEditingController _capacityController;
  late final TextEditingController _notesController;
  late PackagingType _type;
  late bool _isActive;
  bool _isSaving = false;

  bool get _isEditing => widget.initialItem != null;

  Money get _cost => Money.fromInput(_costController.text);

  int get _stockQuantity => int.tryParse(_stockController.text) ?? 0;

  int get _minimumStockQuantity =>
      int.tryParse(_minimumStockController.text) ?? 0;

  bool get _isLowStockPreview =>
      _minimumStockQuantity > 0 && _stockQuantity <= _minimumStockQuantity;

  @override
  void initState() {
    super.initState();

    final initialItem = widget.initialItem;
    _nameController = TextEditingController(text: initialItem?.name ?? '')
      ..addListener(_handleFormChanged);
    _costController = TextEditingController(
      text: initialItem == null || initialItem.cost.isZero
          ? ''
          : initialItem.cost.formatInput(),
    )..addListener(_handleFormChanged);
    _stockController = TextEditingController(
      text: initialItem == null
          ? ''
          : initialItem.currentStockQuantity.toString(),
    )..addListener(_handleFormChanged);
    _minimumStockController = TextEditingController(
      text: initialItem == null
          ? ''
          : initialItem.minimumStockQuantity.toString(),
    )..addListener(_handleFormChanged);
    _capacityController = TextEditingController(
      text: initialItem?.capacityDescription ?? '',
    )..addListener(_handleFormChanged);
    _notesController = TextEditingController(text: initialItem?.notes ?? '')
      ..addListener(_handleFormChanged);
    _type = initialItem?.type ?? PackagingType.box;
    _isActive = initialItem?.isActive ?? true;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _costController.dispose();
    _stockController.dispose();
    _minimumStockController.dispose();
    _capacityController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final title = _isEditing ? 'Editar embalagem' : 'Nova embalagem';
    final subtitle = _isEditing
        ? 'Ajuste a base da embalagem em blocos curtos e sem fricção.'
        : 'Cadastre o essencial primeiro: nome, tipo, custo e saldo.';

    return AppPageScaffold(
      title: title,
      subtitle: subtitle,
      trailing: Wrap(
        spacing: 12,
        runSpacing: 12,
        children: [
          OutlinedButton.icon(
            onPressed: _isSaving
                ? null
                : () => context.go(
                    _isEditing
                        ? '${PackagingFormPage.basePath}/${widget.initialItem!.id}'
                        : PackagingFormPage.basePath,
                  ),
            icon: const Icon(Icons.arrow_back_rounded),
            label: Text(_isEditing ? 'Cancelar' : 'Voltar'),
          ),
          FilledButton.icon(
            onPressed: _isSaving ? null : _savePackaging,
            icon: _isSaving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2.2),
                  )
                : const Icon(Icons.save_rounded),
            label: Text(_isSaving ? 'Salvando...' : 'Salvar embalagem'),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _PackagingPreviewCard(
            name: _nameController.text.trim().isEmpty
                ? 'Embalagem sem nome definido'
                : _nameController.text.trim(),
            type: _type,
            costText: _cost.format(),
            stockText: '$_stockQuantity un',
            isLowStock: _isLowStockPreview,
            isActive: _isActive,
          ),
          const SizedBox(height: 16),
          _SectionCard(
            title: 'Essencial',
            subtitle:
                'Deixe claro qual embalagem é e para o que ela serve sem transformar isso em cadastro longo.',
            child: Column(
              children: [
                TextField(
                  controller: _nameController,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(
                    labelText: 'Nome da embalagem',
                    hintText: 'Ex.: Caixa kraft P',
                  ),
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    for (final type in PackagingType.values)
                      _TypeChoiceCard(
                        type: type,
                        selected: _type == type,
                        onTap: () => setState(() => _type = type),
                      ),
                  ],
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _capacityController,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: const InputDecoration(
                    labelText: 'Capacidade ou descrição',
                    hintText: 'Ex.: 4 brigadeiros, pote 250 ml, bolo de 15 cm',
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _SectionCard(
            title: 'Custo e estoque',
            subtitle:
                'Registre o custo unitário e o saldo atual para a reposição ficar mais clara depois.',
            child: LayoutBuilder(
              builder: (context, constraints) {
                final compactLayout = constraints.maxWidth < 720;
                final fieldWidth = compactLayout
                    ? constraints.maxWidth
                    : (constraints.maxWidth - 12) / 2;

                return Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    SizedBox(
                      width: fieldWidth,
                      child: TextField(
                        controller: _costController,
                        keyboardType: TextInputType.number,
                        inputFormatters: const <TextInputFormatter>[
                          _currencyFormatter,
                        ],
                        decoration: const InputDecoration(
                          labelText: 'Custo unitário',
                          prefixText: 'R\$ ',
                          hintText: '0,00',
                        ),
                      ),
                    ),
                    SizedBox(
                      width: fieldWidth,
                      child: TextField(
                        controller: _stockController,
                        keyboardType: TextInputType.number,
                        inputFormatters: <TextInputFormatter>[
                          FilteringTextInputFormatter.digitsOnly,
                        ],
                        decoration: const InputDecoration(
                          labelText: 'Estoque atual',
                          hintText: '0',
                        ),
                      ),
                    ),
                    SizedBox(
                      width: fieldWidth,
                      child: TextField(
                        controller: _minimumStockController,
                        keyboardType: TextInputType.number,
                        inputFormatters: <TextInputFormatter>[
                          FilteringTextInputFormatter.digitsOnly,
                        ],
                        decoration: const InputDecoration(
                          labelText: 'Estoque mínimo',
                          hintText: '0',
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
          const SizedBox(height: 16),
          _SectionCard(
            title: 'Observações e status',
            subtitle:
                'Guarde só o que ajuda a lembrar uso, acabamento ou compra.',
            child: Column(
              children: [
                TextField(
                  controller: _notesController,
                  minLines: 3,
                  maxLines: 5,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: const InputDecoration(
                    labelText: 'Observações',
                    hintText: 'Opcional',
                  ),
                ),
                const SizedBox(height: 16),
                SwitchListTile.adaptive(
                  contentPadding: EdgeInsets.zero,
                  value: _isActive,
                  title: const Text('Embalagem ativa'),
                  subtitle: Text(
                    _isActive
                        ? 'Ela continua disponível para vincular a produtos.'
                        : 'Ela sai das escolhas rápidas, mas continua salva.',
                  ),
                  onChanged: (value) => setState(() => _isActive = value),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _savePackaging() async {
    if (_nameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Digite pelo menos o nome da embalagem.')),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      final packagingId = await ref
          .read(packagingRepositoryProvider)
          .savePackaging(
            PackagingUpsertInput(
              id: widget.initialItem?.id,
              name: _nameController.text,
              type: _type,
              cost: _cost,
              currentStockQuantity: _stockQuantity,
              minimumStockQuantity: _minimumStockQuantity,
              capacityDescription: _capacityController.text,
              notes: _notesController.text,
              isActive: _isActive,
            ),
          );

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _isEditing
                ? 'Embalagem atualizada neste aparelho.'
                : 'Embalagem salva neste aparelho.',
          ),
        ),
      );
      context.go('${PackagingFormPage.basePath}/$packagingId');
    } catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Não foi possível salvar: $error')),
      );
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  void _handleFormChanged() {
    setState(() {});
  }
}

class _PackagingPreviewCard extends StatelessWidget {
  const _PackagingPreviewCard({
    required this.name,
    required this.type,
    required this.costText,
    required this.stockText,
    required this.isLowStock,
    required this.isActive,
  });

  final String name;
  final PackagingType type;
  final String costText;
  final String stockText;
  final bool isLowStock;
  final bool isActive;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(32),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              PackagingStockBadge(isLowStock: isLowStock),
              _InlineBadge(label: type.label),
              if (!isActive)
                const _InlineBadge(
                  label: 'Inativa',
                  tone: _InlineBadgeTone.warning,
                ),
            ],
          ),
          const SizedBox(height: 16),
          Text(name, style: theme.textTheme.headlineSmall),
          const SizedBox(height: 16),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _HeroMetric(label: 'Custo', value: costText),
              _HeroMetric(label: 'Estoque', value: stockText),
            ],
          ),
        ],
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({
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

class _TypeChoiceCard extends StatelessWidget {
  const _TypeChoiceCard({
    required this.type,
    required this.selected,
    required this.onTap,
  });

  final PackagingType type;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return InkWell(
      borderRadius: BorderRadius.circular(24),
      onTap: onTap,
      child: Ink(
        width: 160,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: selected
              ? theme.colorScheme.primaryContainer
              : theme.colorScheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: selected
                ? theme.colorScheme.primary
                : theme.colorScheme.outlineVariant,
          ),
        ),
        child: Text(type.label, style: theme.textTheme.titleMedium),
      ),
    );
  }
}

class _HeroMetric extends StatelessWidget {
  const _HeroMetric({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: theme.textTheme.labelLarge),
          const SizedBox(height: 6),
          Text(value, style: theme.textTheme.titleLarge),
        ],
      ),
    );
  }
}

enum _InlineBadgeTone { neutral, warning }

class _InlineBadge extends StatelessWidget {
  const _InlineBadge({
    required this.label,
    this.tone = _InlineBadgeTone.neutral,
  });

  final String label;
  final _InlineBadgeTone tone;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final backgroundColor = tone == _InlineBadgeTone.warning
        ? theme.colorScheme.errorContainer
        : theme.colorScheme.tertiaryContainer;
    final foregroundColor = tone == _InlineBadgeTone.warning
        ? theme.colorScheme.onErrorContainer
        : theme.colorScheme.onTertiaryContainer;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: theme.textTheme.labelLarge?.copyWith(color: foregroundColor),
      ),
    );
  }
}
