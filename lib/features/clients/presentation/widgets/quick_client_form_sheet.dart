import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/client_providers.dart';
import '../../domain/client.dart';
import '../../domain/client_rating.dart';

Future<ClientRecord?> showQuickClientFormSheet(BuildContext context) {
  return showModalBottomSheet<ClientRecord>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (context) => const _QuickClientFormSheet(),
  );
}

class _QuickClientFormSheet extends ConsumerStatefulWidget {
  const _QuickClientFormSheet();

  @override
  ConsumerState<_QuickClientFormSheet> createState() =>
      _QuickClientFormSheetState();
}

class _QuickClientFormSheetState extends ConsumerState<_QuickClientFormSheet> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  bool _isSaving = false;

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        12,
        20,
        MediaQuery.viewInsetsOf(context).bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Cliente rápida', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 6),
          Text(
            'Salve o essencial agora e complete o restante depois, sem sair do pedido.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _nameController,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(
              labelText: 'Nome da cliente',
              hintText: 'Ex.: Mariana Silva',
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _phoneController,
            keyboardType: TextInputType.phone,
            decoration: const InputDecoration(
              labelText: 'Telefone',
              hintText: '(11) 99999-9999',
            ),
          ),
          const SizedBox(height: 20),
          Align(
            alignment: Alignment.centerRight,
            child: Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                OutlinedButton(
                  onPressed: _isSaving
                      ? null
                      : () => Navigator.of(context).pop(),
                  child: const Text('Cancelar'),
                ),
                FilledButton.icon(
                  onPressed: _isSaving ? null : _saveClient,
                  icon: _isSaving
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2.0),
                        )
                      : const Icon(Icons.person_add_alt_1_rounded),
                  label: const Text('Salvar cliente'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
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
      final repository = ref.read(clientsRepositoryProvider);
      final clientId = await repository.saveClient(
        ClientUpsertInput(
          name: _nameController.text,
          phone: _phoneController.text,
          address: null,
          notes: null,
          rating: ClientRating.neutral,
          importantDates: const [],
        ),
      );
      final client = await repository.getClient(clientId);

      if (!mounted) {
        return;
      }

      Navigator.of(context).pop(client);
    } catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Não foi possível salvar a cliente: $error')),
      );
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }
}
