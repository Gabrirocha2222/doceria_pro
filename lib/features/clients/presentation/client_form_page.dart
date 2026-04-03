import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/navigation/app_destinations.dart';
import '../../../core/formatters/app_formatters.dart';
import '../../../core/widgets/app_page_scaffold.dart';
import '../../../core/widgets/states/app_error_state.dart';
import '../../../core/widgets/states/app_loading_state.dart';
import '../application/client_providers.dart';
import '../domain/client.dart';
import '../domain/client_rating.dart';
import 'widgets/client_rating_badge.dart';

class ClientFormPage extends ConsumerWidget {
  const ClientFormPage({super.key, this.clientId});

  final String? clientId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (clientId == null) {
      return const _ClientFormView();
    }

    final clientAsync = ref.watch(clientProvider(clientId!));

    return clientAsync.when(
      loading: () => const AppPageScaffold(
        title: 'Abrindo cliente',
        subtitle: 'Carregando os dados para edição.',
        child: AppLoadingState(message: 'Carregando cliente...'),
      ),
      error: (error, stackTrace) => AppPageScaffold(
        title: 'Não deu para editar',
        subtitle: 'Algo falhou ao abrir esta cliente.',
        child: AppErrorState(
          title: 'Cliente indisponível',
          message: 'Volte para a lista e tente novamente.',
          actionLabel: 'Voltar para clientes',
          onAction: () => context.go(AppDestinations.clients.path),
        ),
      ),
      data: (client) {
        if (client == null) {
          return AppPageScaffold(
            title: 'Cliente não encontrada',
            subtitle: 'Não existe uma cliente local com esse identificador.',
            child: AppErrorState(
              title: 'Cliente não encontrada',
              message: 'Volte para a lista e escolha um cadastro salvo.',
              actionLabel: 'Voltar para clientes',
              onAction: () => context.go(AppDestinations.clients.path),
            ),
          );
        }

        return _ClientFormView(initialClient: client);
      },
    );
  }
}

class _ClientFormView extends ConsumerStatefulWidget {
  const _ClientFormView({this.initialClient});

  final ClientRecord? initialClient;

  @override
  ConsumerState<_ClientFormView> createState() => _ClientFormViewState();
}

class _ClientFormViewState extends ConsumerState<_ClientFormView> {
  late final TextEditingController _nameController;
  late final TextEditingController _phoneController;
  late final TextEditingController _addressController;
  late final TextEditingController _notesController;
  late ClientRating _rating;
  late final List<_EditableImportantDate> _importantDates;
  bool _isSaving = false;

  bool get _isEditing => widget.initialClient != null;

  @override
  void initState() {
    super.initState();

    final initialClient = widget.initialClient;
    _nameController = TextEditingController(text: initialClient?.name ?? '');
    _phoneController = TextEditingController(text: initialClient?.phone ?? '');
    _addressController = TextEditingController(
      text: initialClient?.address ?? '',
    );
    _notesController = TextEditingController(text: initialClient?.notes ?? '');
    _rating = initialClient?.rating ?? ClientRating.neutral;
    _importantDates = [
      for (final importantDate in initialClient?.importantDates ?? const [])
        _EditableImportantDate(
          label: importantDate.label,
          date: importantDate.date,
        ),
    ];
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    _notesController.dispose();
    for (final importantDate in _importantDates) {
      importantDate.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final title = _isEditing ? 'Editar cliente' : 'Nova cliente';
    final subtitle = _isEditing
        ? 'Ajuste o cadastro em partes pequenas, sem virar uma ficha pesada.'
        : 'Salve o básico primeiro e complemente quando fizer sentido.';

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
                        ? '${AppDestinations.clients.path}/${widget.initialClient!.id}'
                        : AppDestinations.clients.path,
                  ),
            icon: const Icon(Icons.arrow_back_rounded),
            label: Text(_isEditing ? 'Cancelar' : 'Voltar'),
          ),
          FilledButton.icon(
            onPressed: _isSaving ? null : _saveClient,
            icon: _isSaving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2.2),
                  )
                : const Icon(Icons.save_rounded),
            label: Text(_isSaving ? 'Salvando...' : 'Salvar cliente'),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _ClientPreviewCard(
            name: _nameController.text.trim().isEmpty
                ? 'Cliente sem nome definido'
                : _nameController.text.trim(),
            phone: AppFormatters.formatPhone(_phoneController.text),
            rating: _rating,
            nextImportantDate: _firstValidImportantDate,
          ),
          const SizedBox(height: 16),
          _SectionCard(
            title: 'Essencial',
            subtitle: 'Só o que ajuda a reconhecer a cliente rápido.',
            child: Column(
              children: [
                TextField(
                  controller: _nameController,
                  textCapitalization: TextCapitalization.words,
                  onChanged: (_) => setState(() {}),
                  decoration: const InputDecoration(
                    labelText: 'Nome da cliente',
                    hintText: 'Ex.: Mariana Silva',
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _phoneController,
                  keyboardType: TextInputType.phone,
                  onChanged: (_) => setState(() {}),
                  decoration: const InputDecoration(
                    labelText: 'Telefone',
                    hintText: '(11) 99999-9999',
                  ),
                ),
                const SizedBox(height: 16),
                SegmentedButton<ClientRating>(
                  selected: {_rating},
                  showSelectedIcon: false,
                  segments: const [
                    ButtonSegment<ClientRating>(
                      value: ClientRating.like,
                      label: Text('Like'),
                    ),
                    ButtonSegment<ClientRating>(
                      value: ClientRating.neutral,
                      label: Text('Neutro'),
                    ),
                    ButtonSegment<ClientRating>(
                      value: ClientRating.dislike,
                      label: Text('Dislike'),
                    ),
                  ],
                  onSelectionChanged: (selection) {
                    setState(() => _rating = selection.first);
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _SectionCard(
            title: 'Contato e contexto',
            subtitle:
                'Tudo opcional. Guarde só o que realmente ajuda na rotina.',
            child: Column(
              children: [
                TextField(
                  controller: _addressController,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: const InputDecoration(
                    labelText: 'Endereço',
                    hintText: 'Rua, bairro, referência ou observação útil',
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _notesController,
                  minLines: 3,
                  maxLines: 5,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: const InputDecoration(
                    labelText: 'Observações',
                    hintText:
                        'Preferências, combinados ou qualquer contexto que ajude depois.',
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _SectionCard(
            title: 'Datas importantes',
            subtitle: 'Anote datas que fazem diferença no relacionamento.',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (_importantDates.isEmpty)
                  Text(
                    'Nenhuma data importante adicionada ainda.',
                    style: Theme.of(context).textTheme.bodyMedium,
                  )
                else
                  Column(
                    children: [
                      for (
                        var index = 0;
                        index < _importantDates.length;
                        index++
                      ) ...[
                        _ImportantDateEditor(
                          item: _importantDates[index],
                          onPickDate: () => _pickImportantDate(index),
                          onRemove: () => _removeImportantDate(index),
                        ),
                        if (index != _importantDates.length - 1)
                          const SizedBox(height: 12),
                      ],
                    ],
                  ),
                const SizedBox(height: 16),
                FilledButton.tonalIcon(
                  onPressed: _addImportantDate,
                  icon: const Icon(Icons.event_rounded),
                  label: const Text('Adicionar data'),
                ),
                const SizedBox(height: 12),
                Text(
                  'Se uma linha ficar sem título ou sem data, ela não entra no cadastro.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  ClientImportantDateInput? get _firstValidImportantDate {
    for (final importantDate in _importantDates) {
      final input = importantDate.toInput();
      if (input != null) {
        return input;
      }
    }

    return null;
  }

  void _addImportantDate() {
    setState(() {
      _importantDates.add(_EditableImportantDate());
    });
  }

  void _removeImportantDate(int index) {
    setState(() {
      final removedItem = _importantDates.removeAt(index);
      removedItem.dispose();
    });
  }

  Future<void> _pickImportantDate(int index) async {
    final now = DateTime.now();
    final initialDate = _importantDates[index].date ?? now;
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(now.year - 10),
      lastDate: DateTime(now.year + 10),
      locale: const Locale('pt', 'BR'),
    );

    if (pickedDate != null) {
      setState(() {
        _importantDates[index].date = pickedDate;
      });
    }
  }

  Future<void> _saveClient() async {
    if (_nameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Digite pelo menos o nome da cliente.')),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      final clientId = await ref
          .read(clientsRepositoryProvider)
          .saveClient(
            ClientUpsertInput(
              id: widget.initialClient?.id,
              name: _nameController.text,
              phone: _phoneController.text,
              address: _addressController.text,
              notes: _notesController.text,
              rating: _rating,
              importantDates: [
                for (final importantDate in _importantDates)
                  if (importantDate.toInput() != null) importantDate.toInput()!,
              ],
            ),
          );

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _isEditing
                ? 'Cliente atualizada neste aparelho.'
                : 'Cliente salva neste aparelho.',
          ),
        ),
      );
      context.go('${AppDestinations.clients.path}/$clientId');
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
}

class _ClientPreviewCard extends StatelessWidget {
  const _ClientPreviewCard({
    required this.name,
    required this.phone,
    required this.rating,
    required this.nextImportantDate,
  });

  final String name;
  final String phone;
  final ClientRating rating;
  final ClientImportantDateInput? nextImportantDate;

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
              ClientRatingBadge(rating: rating),
              if (nextImportantDate != null)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surface,
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: theme.colorScheme.outlineVariant),
                  ),
                  child: Text(
                    '${nextImportantDate!.label} • ${AppFormatters.dayMonthYear(nextImportantDate!.date)}',
                    style: theme.textTheme.labelLarge,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          Text(name, style: theme.textTheme.headlineSmall),
          const SizedBox(height: 6),
          Text(phone, style: theme.textTheme.bodyLarge),
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
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: theme.textTheme.titleLarge),
            const SizedBox(height: 6),
            Text(subtitle, style: theme.textTheme.bodyMedium),
            const SizedBox(height: 16),
            child,
          ],
        ),
      ),
    );
  }
}

class _ImportantDateEditor extends StatelessWidget {
  const _ImportantDateEditor({
    required this.item,
    required this.onPickDate,
    required this.onRemove,
  });

  final _EditableImportantDate item;
  final Future<void> Function() onPickDate;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        children: [
          TextField(
            controller: item.labelController,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(
              labelText: 'Título da data',
              hintText: 'Ex.: Aniversário, primeira compra',
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              FilledButton.tonalIcon(
                onPressed: onPickDate,
                icon: const Icon(Icons.event_rounded),
                label: Text(
                  item.date == null
                      ? 'Escolher data'
                      : AppFormatters.dayMonthYear(item.date!),
                ),
              ),
              OutlinedButton.icon(
                onPressed: onRemove,
                icon: const Icon(Icons.delete_outline_rounded),
                label: const Text('Remover'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _EditableImportantDate {
  _EditableImportantDate({String? label, this.date})
    : labelController = TextEditingController(text: label ?? '');

  final TextEditingController labelController;
  DateTime? date;

  ClientImportantDateInput? toInput() {
    final trimmedLabel = labelController.text.trim();
    if (trimmedLabel.isEmpty || date == null) {
      return null;
    }

    return ClientImportantDateInput(label: trimmedLabel, date: date!);
  }

  void dispose() {
    labelController.dispose();
  }
}
