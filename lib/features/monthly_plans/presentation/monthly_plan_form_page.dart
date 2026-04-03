import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/navigation/app_destinations.dart';
import '../../../core/formatters/app_formatters.dart';
import '../../../core/money/currency_text_input_formatter.dart';
import '../../../core/money/money.dart';
import '../../../core/widgets/app_page_scaffold.dart';
import '../../../core/widgets/states/app_error_state.dart';
import '../../../core/widgets/states/app_loading_state.dart';
import '../../clients/presentation/widgets/client_picker_sheet.dart';
import '../../monthly_plans/application/monthly_plan_providers.dart';
import '../../monthly_plans/domain/monthly_plan.dart';
import '../../products/domain/product.dart';
import '../../products/presentation/widgets/product_picker_sheet.dart';

class MonthlyPlanFormPage extends ConsumerWidget {
  const MonthlyPlanFormPage({
    super.key,
    this.monthlyPlanId,
    this.initialClientId,
    this.initialClientName,
  });

  final String? monthlyPlanId;
  final String? initialClientId;
  final String? initialClientName;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (monthlyPlanId == null) {
      return _MonthlyPlanFormView(
        initialClientId: initialClientId,
        initialClientName: initialClientName,
      );
    }

    final monthlyPlanAsync = ref.watch(monthlyPlanProvider(monthlyPlanId!));

    return monthlyPlanAsync.when(
      loading: () => const AppPageScaffold(
        title: 'Abrindo mesversário',
        subtitle: 'Carregando os dados para edição.',
        child: AppLoadingState(message: 'Carregando plano mensal...'),
      ),
      error: (error, stackTrace) => AppPageScaffold(
        title: 'Não deu para editar',
        subtitle: 'Algo falhou ao abrir este plano mensal.',
        child: AppErrorState(
          title: 'Mesversário indisponível',
          message: 'Volte para a lista e tente novamente.',
          actionLabel: 'Voltar para mesversários',
          onAction: () =>
              context.go('${AppDestinations.clients.path}/monthly-plans'),
        ),
      ),
      data: (monthlyPlan) {
        if (monthlyPlan == null) {
          return AppPageScaffold(
            title: 'Mesversário não encontrado',
            subtitle: 'Não existe um plano local com esse identificador.',
            child: AppErrorState(
              title: 'Mesversário não encontrado',
              message: 'Volte para a lista e escolha um plano salvo.',
              actionLabel: 'Voltar para mesversários',
              onAction: () =>
                  context.go('${AppDestinations.clients.path}/monthly-plans'),
            ),
          );
        }

        return _MonthlyPlanFormView(initialPlan: monthlyPlan);
      },
    );
  }
}

class _MonthlyPlanFormView extends ConsumerStatefulWidget {
  const _MonthlyPlanFormView({
    this.initialPlan,
    this.initialClientId,
    this.initialClientName,
  });

  final MonthlyPlanRecord? initialPlan;
  final String? initialClientId;
  final String? initialClientName;

  @override
  ConsumerState<_MonthlyPlanFormView> createState() =>
      _MonthlyPlanFormViewState();
}

class _MonthlyPlanFormViewState extends ConsumerState<_MonthlyPlanFormView> {
  late final TextEditingController _titleController;
  late final TextEditingController _numberOfMonthsController;
  late final TextEditingController _contractedQuantityController;
  late final TextEditingController _notesController;
  late DateTime _startDate;
  late final List<_EditableMonthlyPlanItem> _items;
  late String? _selectedClientId;
  late String? _selectedClientName;
  late String? _templateProductId;
  late String? _templateProductName;
  bool _isSaving = false;

  bool get _isEditing => widget.initialPlan != null;

  @override
  void initState() {
    super.initState();
    final initialPlan = widget.initialPlan;
    final initialClientName =
        initialPlan?.clientNameSnapshot ?? widget.initialClientName ?? '';
    _selectedClientId = initialPlan?.clientId ?? widget.initialClientId;
    _selectedClientName = initialClientName.trim().isEmpty
        ? null
        : initialClientName.trim();
    _templateProductId = initialPlan?.templateProductId;
    _templateProductName = initialPlan?.templateProductNameSnapshot;
    _titleController = TextEditingController(
      text:
          initialPlan?.title ??
          ((widget.initialClientName?.trim().isNotEmpty ?? false)
              ? 'Mesversário de ${widget.initialClientName!.trim()}'
              : ''),
    );
    _numberOfMonthsController = TextEditingController(
      text: (initialPlan?.numberOfMonths ?? 12).toString(),
    );
    _contractedQuantityController = TextEditingController(
      text: (initialPlan?.contractedQuantity ?? 12).toString(),
    );
    _notesController = TextEditingController(text: initialPlan?.notes ?? '');
    _startDate = initialPlan?.startDate ?? _normalizeDate(DateTime.now());
    _items = [
      for (final item in initialPlan?.items ?? const <MonthlyPlanItemRecord>[])
        _EditableMonthlyPlanItem(
          linkedProductId: item.linkedProductId,
          linkedProductName: item.itemNameSnapshot,
          itemName: item.itemNameSnapshot,
          flavor: item.flavorSnapshot,
          variation: item.variationSnapshot,
          quantity: item.quantity.toString(),
          unitPrice: item.unitPrice.formatInput(),
          notes: item.notes,
        ),
    ];
  }

  @override
  void dispose() {
    _titleController.dispose();
    _numberOfMonthsController.dispose();
    _contractedQuantityController.dispose();
    _notesController.dispose();
    for (final item in _items) {
      item.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final title = _isEditing ? 'Editar mesversário' : 'Novo mesversário';
    final subtitle = _isEditing
        ? 'Ajuste cliente, recorrência e modelo mensal sem bagunçar os pedidos já gerados.'
        : 'Monte a base recorrente uma vez e deixe o histórico mensal organizado daqui para frente.';
    final previewDates = buildMonthlyPlanScheduleDates(
      startDate: _startDate,
      numberOfMonths: _parsedNumberOfMonths,
    );
    final estimatedMonthlyTotal = _estimatedMonthlyTotal;
    final contractedGreaterThanMonths =
        _parsedContractedQuantity > _parsedNumberOfMonths;

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
                        ? '${AppDestinations.clients.path}/monthly-plans/${widget.initialPlan!.id}'
                        : '${AppDestinations.clients.path}/monthly-plans',
                  ),
            icon: const Icon(Icons.arrow_back_rounded),
            label: Text(_isEditing ? 'Cancelar' : 'Voltar'),
          ),
          FilledButton.icon(
            onPressed: _isSaving ? null : _saveMonthlyPlan,
            icon: _isSaving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2.2),
                  )
                : const Icon(Icons.save_rounded),
            label: Text(_isSaving ? 'Salvando...' : 'Salvar mesversário'),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _PreviewCard(
            title: _titleController.text.trim().isEmpty
                ? 'Mesversário sem nome definido'
                : _titleController.text.trim(),
            clientName: _selectedClientName ?? 'Cliente ainda não escolhida',
            startDate: _startDate,
            numberOfMonths: _parsedNumberOfMonths,
            contractedQuantity: _parsedContractedQuantity,
            estimatedMonthlyTotal: estimatedMonthlyTotal,
            previewDates: previewDates.take(3).toList(growable: false),
          ),
          const SizedBox(height: 16),
          _SectionCard(
            title: 'Cliente e modelo base',
            subtitle:
                'Primeiro defina para quem é o plano e, se fizer sentido, use um produto como referência comercial.',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _SelectionTile(
                  icon: Icons.people_alt_outlined,
                  title: 'Cliente',
                  value: _selectedClientName ?? 'Nenhuma cliente escolhida',
                  actionLabel: _selectedClientId == null
                      ? 'Escolher cliente'
                      : 'Trocar cliente',
                  onAction: _chooseClient,
                ),
                const SizedBox(height: 12),
                _SelectionTile(
                  icon: Icons.inventory_2_outlined,
                  title: 'Modelo base opcional',
                  value: _templateProductName ?? 'Sem modelo base',
                  actionLabel: _templateProductId == null
                      ? 'Escolher produto'
                      : 'Trocar produto',
                  onAction: _chooseTemplateProduct,
                  secondaryActionLabel: _templateProductId == null
                      ? null
                      : 'Remover',
                  onSecondaryAction: _clearTemplateProduct,
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _titleController,
                  textCapitalization: TextCapitalization.words,
                  onChanged: (_) => setState(() {}),
                  decoration: const InputDecoration(
                    labelText: 'Nome do plano',
                    hintText: 'Ex.: Mesversário da Helena',
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _SectionCard(
            title: 'Recorrência',
            subtitle:
                'A recorrência é mensal. Aqui você define o primeiro mês, o horizonte total e o saldo contratado atual.',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    FilledButton.tonalIcon(
                      onPressed: _pickStartDate,
                      icon: const Icon(Icons.calendar_today_outlined),
                      label: Text(
                        'Primeiro mês: ${AppFormatters.dayMonthYear(_startDate)}',
                      ),
                    ),
                    const _StaticInfoChip(
                      icon: Icons.autorenew_rounded,
                      label: 'Recorrência mensal',
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final compactLayout = constraints.maxWidth < 760;
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
                            controller: _numberOfMonthsController,
                            keyboardType: TextInputType.number,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                            ],
                            onChanged: (_) => setState(() {}),
                            decoration: const InputDecoration(
                              labelText: 'Número de meses',
                              hintText: 'Ex.: 12',
                            ),
                          ),
                        ),
                        SizedBox(
                          width: fieldWidth,
                          child: TextField(
                            controller: _contractedQuantityController,
                            keyboardType: TextInputType.number,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                            ],
                            onChanged: (_) => setState(() {}),
                            decoration: const InputDecoration(
                              labelText: 'Quantidade contratada',
                              hintText: 'Ex.: 12',
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 12),
                Text(
                  'Você pode prever mais meses do que o saldo contratado atual. O app só libera geração dentro do saldo disponível.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                if (contractedGreaterThanMonths) ...[
                  const SizedBox(height: 12),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.errorContainer,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      'A quantidade contratada não pode ser maior que o número de meses previstos.',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 16),
          _SectionCard(
            title: 'Modelo mensal do pedido',
            subtitle:
                'Esses itens viram a base dos próximos rascunhos. Use produtos como atalho quando isso ajudar.',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (_items.isEmpty)
                  Text(
                    'Nenhum item adicionado ainda. Selecione um produto base ou monte o modelo manualmente.',
                    style: Theme.of(context).textTheme.bodyMedium,
                  )
                else
                  Column(
                    children: [
                      for (var index = 0; index < _items.length; index++) ...[
                        _MonthlyPlanItemEditor(
                          item: _items[index],
                          onChooseProduct: () => _chooseItemProduct(index),
                          onClearProduct: () => _clearItemProduct(index),
                          onChanged: () => setState(() {}),
                          onRemove: () => _removeItem(index),
                        ),
                        if (index != _items.length - 1)
                          const SizedBox(height: 12),
                      ],
                    ],
                  ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    FilledButton.tonalIcon(
                      onPressed: _addEmptyItem,
                      icon: const Icon(Icons.add_rounded),
                      label: const Text('Adicionar item manual'),
                    ),
                    OutlinedButton.icon(
                      onPressed: _addItemFromProduct,
                      icon: const Icon(Icons.inventory_2_outlined),
                      label: const Text('Usar produto como item'),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _SectionCard(
            title: 'Prévia do impacto futuro',
            subtitle:
                'Antes de salvar, confira como os próximos meses ficam organizados com base nessa recorrência.',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    _PreviewMetric(
                      label: 'Total previsto por mês',
                      value: estimatedMonthlyTotal.format(),
                    ),
                    _PreviewMetric(
                      label: 'Itens por mês',
                      value: _estimatedItemCount.toString(),
                    ),
                    _PreviewMetric(
                      label: 'Saldo inicial',
                      value: _parsedContractedQuantity.toString(),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                for (
                  var index = 0;
                  index < previewDates.length && index < 4;
                  index++
                ) ...[
                  _PreviewDateTile(index: index + 1, date: previewDates[index]),
                  if (index != 3 && index != previewDates.length - 1)
                    const SizedBox(height: 10),
                ],
              ],
            ),
          ),
          const SizedBox(height: 16),
          _SectionCard(
            title: 'Observações do plano',
            subtitle:
                'Deixe aqui combinados úteis para quando o rascunho for gerado mais adiante.',
            child: TextField(
              controller: _notesController,
              minLines: 3,
              maxLines: 5,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Observações',
                hintText:
                    'Ex.: confirmar tema uma semana antes, ajustar topo com foto atual.',
              ),
            ),
          ),
        ],
      ),
    );
  }

  int get _parsedNumberOfMonths =>
      int.tryParse(_numberOfMonthsController.text.trim()) ?? 1;

  int get _parsedContractedQuantity =>
      int.tryParse(_contractedQuantityController.text.trim()) ?? 1;

  Money get _estimatedMonthlyTotal {
    var total = Money.zero;
    for (final item in _items) {
      total += item.lineTotal;
    }

    return total;
  }

  int get _estimatedItemCount {
    var total = 0;
    for (final item in _items) {
      total += item.quantity;
    }

    return total;
  }

  Future<void> _chooseClient() async {
    final client = await showClientPickerSheet(context);
    if (client == null || !mounted) {
      return;
    }

    setState(() {
      _selectedClientId = client.id;
      _selectedClientName = client.name;
      if (_titleController.text.trim().isEmpty) {
        _titleController.text = 'Mesversário de ${client.name}';
      }
    });
  }

  Future<void> _chooseTemplateProduct() async {
    final product = await showProductPickerSheet(context);
    if (product == null || !mounted) {
      return;
    }

    setState(() {
      _templateProductId = product.id;
      _templateProductName = product.name;
      if (_items.isEmpty) {
        _items.add(_EditableMonthlyPlanItem.fromProduct(product));
      }
    });
  }

  Future<void> _addItemFromProduct() async {
    final product = await showProductPickerSheet(context);
    if (product == null || !mounted) {
      return;
    }

    setState(() {
      _items.add(_EditableMonthlyPlanItem.fromProduct(product));
    });
  }

  void _clearTemplateProduct() {
    setState(() {
      _templateProductId = null;
      _templateProductName = null;
    });
  }

  void _addEmptyItem() {
    setState(() {
      _items.add(_EditableMonthlyPlanItem());
    });
  }

  Future<void> _chooseItemProduct(int index) async {
    final product = await showProductPickerSheet(context);
    if (product == null || !mounted) {
      return;
    }

    setState(() {
      _items[index].applyProduct(product);
    });
  }

  void _clearItemProduct(int index) {
    setState(() {
      _items[index].clearLinkedProduct();
    });
  }

  void _removeItem(int index) {
    setState(() {
      final removedItem = _items.removeAt(index);
      removedItem.dispose();
    });
  }

  Future<void> _pickStartDate() async {
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: _startDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
      helpText: 'Escolher primeiro mês',
    );
    if (pickedDate == null || !mounted) {
      return;
    }

    setState(() {
      _startDate = _normalizeDate(pickedDate);
    });
  }

  Future<void> _saveMonthlyPlan() async {
    final selectedClientId = _selectedClientId?.trim();
    final selectedClientName = _selectedClientName?.trim();
    if (selectedClientId == null || selectedClientId.isEmpty) {
      _showMessage('Escolha a cliente antes de salvar o mesversário.');
      return;
    }
    if (selectedClientName == null || selectedClientName.isEmpty) {
      _showMessage('A cliente escolhida precisa ter um nome válido.');
      return;
    }

    final title = _titleController.text.trim();
    if (title.isEmpty) {
      _showMessage('Dê um nome para o plano antes de salvar.');
      return;
    }

    final numberOfMonths = _parsedNumberOfMonths;
    final contractedQuantity = _parsedContractedQuantity;
    if (numberOfMonths <= 0) {
      _showMessage('Informe um número de meses maior que zero.');
      return;
    }
    if (contractedQuantity <= 0) {
      _showMessage('Informe uma quantidade contratada maior que zero.');
      return;
    }
    if (contractedQuantity > numberOfMonths) {
      _showMessage(
        'A quantidade contratada não pode ser maior que o número de meses.',
      );
      return;
    }

    final itemInputs = _items
        .map((item) => item.toInput())
        .whereType<MonthlyPlanItemInput>()
        .toList(growable: false);
    if (itemInputs.isEmpty) {
      _showMessage('Adicione pelo menos um item ao modelo mensal.');
      return;
    }

    setState(() => _isSaving = true);

    try {
      final savedId = await ref
          .read(monthlyPlansRepositoryProvider)
          .saveMonthlyPlan(
            MonthlyPlanUpsertInput(
              id: widget.initialPlan?.id,
              clientId: selectedClientId,
              clientNameSnapshot: selectedClientName,
              title: title,
              templateProductId: _templateProductId,
              templateProductNameSnapshot: _templateProductName,
              startDate: _startDate,
              numberOfMonths: numberOfMonths,
              contractedQuantity: contractedQuantity,
              notes: _notesController.text,
              items: itemInputs,
            ),
          );

      if (!mounted) {
        return;
      }

      context.go('${AppDestinations.clients.path}/monthly-plans/$savedId');
    } catch (_) {
      if (!mounted) {
        return;
      }

      _showMessage('Não foi possível salvar o mesversário agora.');
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  DateTime _normalizeDate(DateTime date) {
    return DateTime(date.year, date.month, date.day);
  }
}

class _PreviewCard extends StatelessWidget {
  const _PreviewCard({
    required this.title,
    required this.clientName,
    required this.startDate,
    required this.numberOfMonths,
    required this.contractedQuantity,
    required this.estimatedMonthlyTotal,
    required this.previewDates,
  });

  final String title;
  final String clientName;
  final DateTime startDate;
  final int numberOfMonths;
  final int contractedQuantity;
  final Money estimatedMonthlyTotal;
  final List<DateTime> previewDates;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(32),
        gradient: LinearGradient(
          colors: [
            theme.colorScheme.primaryContainer,
            theme.colorScheme.surface,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _StaticInfoChip(
                icon: Icons.people_alt_outlined,
                label: clientName,
              ),
              _StaticInfoChip(
                icon: Icons.calendar_today_outlined,
                label: AppFormatters.dayMonthYear(startDate),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(title, style: theme.textTheme.headlineSmall),
          const SizedBox(height: 6),
          Text(
            'Prévia rápida do fluxo mensal antes de salvar.',
            style: theme.textTheme.bodyLarge,
          ),
          const SizedBox(height: 20),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _PreviewMetric(
                label: 'Meses previstos',
                value: numberOfMonths.toString(),
              ),
              _PreviewMetric(
                label: 'Saldo contratado',
                value: contractedQuantity.toString(),
              ),
              _PreviewMetric(
                label: 'Total por mês',
                value: estimatedMonthlyTotal.format(),
              ),
            ],
          ),
          if (previewDates.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text(
              'Primeiros meses previstos',
              style: theme.textTheme.labelLarge,
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final date in previewDates)
                  _StaticInfoChip(
                    icon: Icons.event_repeat_rounded,
                    label: AppFormatters.dayMonthYear(date),
                  ),
              ],
            ),
          ],
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
            const SizedBox(height: 8),
            Text(subtitle, style: Theme.of(context).textTheme.bodyMedium),
            const SizedBox(height: 16),
            child,
          ],
        ),
      ),
    );
  }
}

class _SelectionTile extends StatelessWidget {
  const _SelectionTile({
    required this.icon,
    required this.title,
    required this.value,
    required this.actionLabel,
    required this.onAction,
    this.secondaryActionLabel,
    this.onSecondaryAction,
  });

  final IconData icon;
  final String title;
  final String value;
  final String actionLabel;
  final VoidCallback onAction;
  final String? secondaryActionLabel;
  final VoidCallback? onSecondaryAction;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: theme.colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(icon, color: theme.colorScheme.primary),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: theme.textTheme.titleMedium),
                    const SizedBox(height: 4),
                    Text(value, style: theme.textTheme.bodyMedium),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              FilledButton.tonalIcon(
                onPressed: onAction,
                icon: const Icon(Icons.edit_note_rounded),
                label: Text(actionLabel),
              ),
              if (secondaryActionLabel != null && onSecondaryAction != null)
                TextButton(
                  onPressed: onSecondaryAction,
                  child: Text(secondaryActionLabel!),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StaticInfoChip extends StatelessWidget {
  const _StaticInfoChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: theme.colorScheme.primary),
          const SizedBox(width: 8),
          Text(label, style: theme.textTheme.labelLarge),
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
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(height: 6),
          Text(value, style: Theme.of(context).textTheme.titleLarge),
        ],
      ),
    );
  }
}

class _PreviewDateTile extends StatelessWidget {
  const _PreviewDateTile({required this.index, required this.date});

  final int index;
  final DateTime date;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      child: Text(
        'Mês ${index.toString().padLeft(2, '0')} • ${AppFormatters.dayMonthYear(date)}',
        style: Theme.of(context).textTheme.bodyMedium,
      ),
    );
  }
}

class _MonthlyPlanItemEditor extends StatelessWidget {
  const _MonthlyPlanItemEditor({
    required this.item,
    required this.onChooseProduct,
    required this.onClearProduct,
    required this.onChanged,
    required this.onRemove,
  });

  final _EditableMonthlyPlanItem item;
  final VoidCallback onChooseProduct;
  final VoidCallback onClearProduct;
  final VoidCallback onChanged;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              FilledButton.tonalIcon(
                onPressed: onChooseProduct,
                icon: const Icon(Icons.inventory_2_outlined),
                label: Text(
                  item.linkedProductId == null
                      ? 'Usar produto'
                      : 'Trocar produto',
                ),
              ),
              if (item.linkedProductId != null)
                TextButton(
                  onPressed: onClearProduct,
                  child: const Text('Remover vínculo'),
                ),
              TextButton(
                onPressed: onRemove,
                child: const Text('Remover item'),
              ),
            ],
          ),
          if (item.linkedProductName?.trim().isNotEmpty ?? false) ...[
            const SizedBox(height: 8),
            Text(
              'Produto base: ${item.linkedProductName!}',
              style: theme.textTheme.bodySmall,
            ),
          ],
          const SizedBox(height: 16),
          TextField(
            controller: item.itemNameController,
            textCapitalization: TextCapitalization.words,
            onChanged: (_) => onChanged(),
            decoration: const InputDecoration(
              labelText: 'Nome do item',
              hintText: 'Ex.: Mini bolo do mês',
            ),
          ),
          const SizedBox(height: 12),
          LayoutBuilder(
            builder: (context, constraints) {
              final compactLayout = constraints.maxWidth < 760;
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
                      controller: item.flavorController,
                      textCapitalization: TextCapitalization.words,
                      onChanged: (_) => onChanged(),
                      decoration: const InputDecoration(
                        labelText: 'Sabor',
                        hintText: 'Opcional',
                      ),
                    ),
                  ),
                  SizedBox(
                    width: fieldWidth,
                    child: TextField(
                      controller: item.variationController,
                      textCapitalization: TextCapitalization.words,
                      onChanged: (_) => onChanged(),
                      decoration: const InputDecoration(
                        labelText: 'Variação',
                        hintText: 'Ex.: 15 cm, 20 unidades',
                      ),
                    ),
                  ),
                  SizedBox(
                    width: fieldWidth,
                    child: TextField(
                      controller: item.quantityController,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      onChanged: (_) => onChanged(),
                      decoration: const InputDecoration(
                        labelText: 'Quantidade',
                        hintText: '1',
                      ),
                    ),
                  ),
                  SizedBox(
                    width: fieldWidth,
                    child: TextField(
                      controller: item.unitPriceController,
                      keyboardType: TextInputType.number,
                      inputFormatters: const [CurrencyTextInputFormatter()],
                      onChanged: (_) => onChanged(),
                      decoration: const InputDecoration(
                        labelText: 'Preço unitário',
                        hintText: '0,00',
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 12),
          TextField(
            controller: item.notesController,
            minLines: 2,
            maxLines: 3,
            textCapitalization: TextCapitalization.sentences,
            onChanged: (_) => onChanged(),
            decoration: const InputDecoration(
              labelText: 'Observação do item',
              hintText: 'Opcional',
            ),
          ),
        ],
      ),
    );
  }
}

class _EditableMonthlyPlanItem {
  _EditableMonthlyPlanItem({
    this.linkedProductId,
    this.linkedProductName,
    String? itemName,
    String? flavor,
    String? variation,
    String? quantity,
    String? unitPrice,
    String? notes,
  }) : itemNameController = TextEditingController(text: itemName ?? ''),
       flavorController = TextEditingController(text: flavor ?? ''),
       variationController = TextEditingController(text: variation ?? ''),
       quantityController = TextEditingController(text: quantity ?? '1'),
       unitPriceController = TextEditingController(text: unitPrice ?? ''),
       notesController = TextEditingController(text: notes ?? '');

  factory _EditableMonthlyPlanItem.fromProduct(ProductRecord product) {
    return _EditableMonthlyPlanItem(
      linkedProductId: product.id,
      linkedProductName: product.name,
      itemName: product.name,
      quantity: '1',
      unitPrice: product.basePrice.isZero
          ? ''
          : product.basePrice.formatInput(),
    );
  }

  String? linkedProductId;
  String? linkedProductName;
  final TextEditingController itemNameController;
  final TextEditingController flavorController;
  final TextEditingController variationController;
  final TextEditingController quantityController;
  final TextEditingController unitPriceController;
  final TextEditingController notesController;

  int get quantity => int.tryParse(quantityController.text.trim()) ?? 1;

  Money get lineTotal {
    final unitPrice = Money.fromInput(unitPriceController.text);
    return unitPrice.multiply(quantity <= 0 ? 1 : quantity);
  }

  void applyProduct(ProductRecord product) {
    linkedProductId = product.id;
    linkedProductName = product.name;
    itemNameController.text = product.name;
    if (Money.fromInput(unitPriceController.text).isZero &&
        product.basePrice.isPositive) {
      unitPriceController.text = product.basePrice.formatInput();
    }
  }

  void clearLinkedProduct() {
    linkedProductId = null;
    linkedProductName = null;
  }

  MonthlyPlanItemInput? toInput() {
    final itemName = itemNameController.text.trim();
    if (itemName.isEmpty) {
      return null;
    }

    final normalizedQuantity = quantity <= 0 ? 1 : quantity;

    return MonthlyPlanItemInput(
      linkedProductId: linkedProductId,
      itemNameSnapshot: itemName,
      flavorSnapshot: _trimToNull(flavorController.text),
      variationSnapshot: _trimToNull(variationController.text),
      unitPrice: Money.fromInput(unitPriceController.text),
      quantity: normalizedQuantity,
      notes: _trimToNull(notesController.text),
    );
  }

  void dispose() {
    itemNameController.dispose();
    flavorController.dispose();
    variationController.dispose();
    quantityController.dispose();
    unitPriceController.dispose();
    notesController.dispose();
  }

  String? _trimToNull(String value) {
    final trimmedValue = value.trim();
    if (trimmedValue.isEmpty) {
      return null;
    }

    return trimmedValue;
  }
}
