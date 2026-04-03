import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/widgets/app_page_scaffold.dart';
import '../../../core/widgets/states/app_error_state.dart';
import '../../../core/widgets/states/app_loading_state.dart';
import '../application/supplier_providers.dart';
import '../domain/supplier.dart';
import 'suppliers_page.dart';

class SupplierFormPage extends ConsumerWidget {
  const SupplierFormPage({super.key, this.supplierId});

  final String? supplierId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (supplierId == null) {
      return const _SupplierFormView();
    }

    final supplierAsync = ref.watch(supplierProvider(supplierId!));

    return supplierAsync.when(
      loading: () => const AppPageScaffold(
        title: 'Abrindo fornecedora',
        subtitle: 'Carregando os dados para edição.',
        child: AppLoadingState(message: 'Carregando fornecedora...'),
      ),
      error: (error, stackTrace) => AppPageScaffold(
        title: 'Não deu para editar',
        subtitle: 'Algo falhou ao abrir esta fornecedora.',
        child: AppErrorState(
          title: 'Fornecedora indisponível',
          message: 'Volte para a lista e tente novamente.',
          actionLabel: 'Voltar para fornecedoras',
          onAction: () => context.go(SuppliersPage.basePath),
        ),
      ),
      data: (supplier) {
        if (supplier == null) {
          return AppPageScaffold(
            title: 'Fornecedora não encontrada',
            subtitle: 'Não existe um cadastro local com esse identificador.',
            child: AppErrorState(
              title: 'Fornecedora não encontrada',
              message: 'Volte para a lista e escolha um cadastro salvo.',
              actionLabel: 'Voltar para fornecedoras',
              onAction: () => context.go(SuppliersPage.basePath),
            ),
          );
        }

        return _SupplierFormView(initialSupplier: supplier);
      },
    );
  }
}

class _SupplierFormView extends ConsumerStatefulWidget {
  const _SupplierFormView({this.initialSupplier});

  final SupplierRecord? initialSupplier;

  @override
  ConsumerState<_SupplierFormView> createState() => _SupplierFormViewState();
}

class _SupplierFormViewState extends ConsumerState<_SupplierFormView> {
  late final TextEditingController _nameController;
  late final TextEditingController _contactController;
  late final TextEditingController _leadTimeController;
  late final TextEditingController _notesController;
  late bool _isActive;
  bool _isSaving = false;

  bool get _isEditing => widget.initialSupplier != null;

  int? get _leadTimeDays {
    final rawValue = _leadTimeController.text.trim();
    if (rawValue.isEmpty) {
      return null;
    }

    return int.tryParse(rawValue);
  }

  @override
  void initState() {
    super.initState();

    final initialSupplier = widget.initialSupplier;
    _nameController = TextEditingController(text: initialSupplier?.name ?? '')
      ..addListener(_handleFormChanged);
    _contactController = TextEditingController(
      text: initialSupplier?.contact ?? '',
    )..addListener(_handleFormChanged);
    _leadTimeController = TextEditingController(
      text: initialSupplier?.leadTimeDays?.toString() ?? '',
    )..addListener(_handleFormChanged);
    _notesController = TextEditingController(text: initialSupplier?.notes ?? '')
      ..addListener(_handleFormChanged);
    _isActive = initialSupplier?.isActive ?? true;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _contactController.dispose();
    _leadTimeController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final title = _isEditing ? 'Editar fornecedora' : 'Nova fornecedora';
    final subtitle = _isEditing
        ? 'Ajuste o contato e o ritmo de compra sem complicar sua rotina.'
        : 'Cadastre só o necessário para lembrar onde comprar com menos atrito.';

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
                        ? '${SuppliersPage.basePath}/${widget.initialSupplier!.id}'
                        : SuppliersPage.basePath,
                  ),
            icon: const Icon(Icons.arrow_back_rounded),
            label: Text(_isEditing ? 'Cancelar' : 'Voltar'),
          ),
          FilledButton.icon(
            onPressed: _isSaving ? null : _saveSupplier,
            icon: _isSaving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2.2),
                  )
                : const Icon(Icons.save_rounded),
            label: Text(_isSaving ? 'Salvando...' : 'Salvar fornecedora'),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SupplierPreviewCard(
            name: _nameController.text.trim().isEmpty
                ? 'Fornecedora sem nome definido'
                : _nameController.text.trim(),
            contact: _contactController.text.trim(),
            leadTimeDays: _leadTimeDays,
            isActive: _isActive,
          ),
          const SizedBox(height: 16),
          _SectionCard(
            title: 'Essencial',
            subtitle:
                'Guarde o nome e o melhor jeito de falar com essa fornecedora.',
            child: Column(
              children: [
                TextField(
                  controller: _nameController,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(
                    labelText: 'Nome da fornecedora',
                    hintText: 'Ex.: Casa dos Insumos',
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _contactController,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: const InputDecoration(
                    labelText: 'Contato',
                    hintText:
                        'WhatsApp, telefone, Instagram ou pessoa de referência',
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _SectionCard(
            title: 'Compra real',
            subtitle:
                'Registre o prazo médio e se essa opção continua valendo hoje.',
            child: Column(
              children: [
                TextField(
                  controller: _leadTimeController,
                  keyboardType: TextInputType.number,
                  inputFormatters: <TextInputFormatter>[
                    FilteringTextInputFormatter.digitsOnly,
                  ],
                  decoration: const InputDecoration(
                    labelText: 'Prazo médio em dias',
                    hintText: 'Ex.: 2',
                  ),
                ),
                const SizedBox(height: 16),
                SwitchListTile.adaptive(
                  contentPadding: EdgeInsets.zero,
                  value: _isActive,
                  title: const Text('Fornecedora ativa'),
                  subtitle: Text(
                    _isActive
                        ? 'Ela continua disponível para compras futuras.'
                        : 'Ela fica salva, mas sai do foco principal.',
                  ),
                  onChanged: (value) {
                    setState(() => _isActive = value);
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _SectionCard(
            title: 'Observações',
            subtitle:
                'Anote só o que realmente ajuda quando chegar a hora de comprar.',
            child: TextField(
              controller: _notesController,
              minLines: 3,
              maxLines: 5,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Observações',
                hintText:
                    'Ex.: melhor dia para pedir, pedido mínimo, atendimento mais rápido',
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _saveSupplier() async {
    if (_nameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Digite pelo menos o nome da fornecedora.'),
        ),
      );
      return;
    }

    if (_leadTimeController.text.trim().isNotEmpty && _leadTimeDays == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Revise o prazo médio antes de salvar.')),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      final supplierId = await ref
          .read(suppliersRepositoryProvider)
          .saveSupplier(
            SupplierUpsertInput(
              id: widget.initialSupplier?.id,
              name: _nameController.text,
              contact: _contactController.text,
              notes: _notesController.text,
              leadTimeDays: _leadTimeDays,
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
                ? 'Fornecedora atualizada neste aparelho.'
                : 'Fornecedora salva neste aparelho.',
          ),
        ),
      );
      context.go('${SuppliersPage.basePath}/$supplierId');
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

class _SupplierPreviewCard extends StatelessWidget {
  const _SupplierPreviewCard({
    required this.name,
    required this.contact,
    required this.leadTimeDays,
    required this.isActive,
  });

  final String name;
  final String contact;
  final int? leadTimeDays;
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
          _StatusBadge(isActive: isActive),
          const SizedBox(height: 16),
          Text(name, style: theme.textTheme.headlineSmall),
          const SizedBox(height: 6),
          Text(
            contact.trim().isEmpty ? 'Sem contato definido' : contact.trim(),
            style: theme.textTheme.bodyLarge,
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _PreviewMetric(
                label: 'Prazo médio',
                value: leadTimeDays == null
                    ? 'Sem prazo'
                    : '${leadTimeDays!} ${leadTimeDays == 1 ? 'dia' : 'dias'}',
              ),
            ],
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

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.isActive});

  final bool isActive;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: isActive
            ? theme.colorScheme.secondaryContainer
            : theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Text(
        isActive ? 'Ativa' : 'Inativa',
        style: theme.textTheme.labelLarge,
      ),
    );
  }
}
