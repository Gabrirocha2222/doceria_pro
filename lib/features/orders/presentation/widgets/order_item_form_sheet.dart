import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/money/currency_text_input_formatter.dart';
import '../../../../core/money/money.dart';
import '../../../products/application/product_providers.dart';
import '../../../products/domain/product.dart';
import '../../../products/presentation/widgets/product_picker_sheet.dart';
import '../../../products/presentation/widgets/product_sale_mode_badge.dart';
import '../../../products/presentation/widgets/product_type_badge.dart';
import '../../domain/order.dart';

Future<OrderItemInput?> showOrderItemFormSheet(
  BuildContext context, {
  OrderItemInput? initialItem,
}) {
  return showModalBottomSheet<OrderItemInput>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (context) => _OrderItemFormSheet(initialItem: initialItem),
  );
}

class _OrderItemFormSheet extends ConsumerStatefulWidget {
  const _OrderItemFormSheet({this.initialItem});

  final OrderItemInput? initialItem;

  @override
  ConsumerState<_OrderItemFormSheet> createState() =>
      _OrderItemFormSheetState();
}

class _OrderItemFormSheetState extends ConsumerState<_OrderItemFormSheet> {
  static const _currencyFormatter = CurrencyTextInputFormatter();

  late final TextEditingController _nameController;
  late final TextEditingController _priceController;
  late final TextEditingController _quantityController;
  late final TextEditingController _notesController;
  String? _selectedProductId;
  String? _selectedFlavor;
  String? _selectedVariation;

  @override
  void initState() {
    super.initState();
    final initialItem = widget.initialItem;
    _nameController = TextEditingController(
      text: initialItem?.itemNameSnapshot ?? '',
    );
    _priceController = TextEditingController(
      text: initialItem == null || initialItem.price.isZero
          ? ''
          : initialItem.price.formatInput(),
    );
    _quantityController = TextEditingController(
      text: (initialItem?.quantity ?? 1).toString(),
    );
    _notesController = TextEditingController(text: initialItem?.notes ?? '');
    _selectedProductId = initialItem?.productId;
    _selectedFlavor = initialItem?.flavorSnapshot;
    _selectedVariation = initialItem?.variationSnapshot;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _priceController.dispose();
    _quantityController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final productAsync = _selectedProductId == null
        ? null
        : ref.watch(productProvider(_selectedProductId!));
    final linkedProduct = productAsync?.asData?.value;
    final availableFlavors =
        linkedProduct?.flavors ?? const <ProductOptionRecord>[];
    final availableVariations =
        linkedProduct?.variations ?? const <ProductOptionRecord>[];
    final selectedFlavorValue =
        availableFlavors.any((option) => option.name == _selectedFlavor)
        ? _selectedFlavor
        : null;
    final selectedVariationValue =
        availableVariations.any((option) => option.name == _selectedVariation)
        ? _selectedVariation
        : null;

    return Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        12,
        20,
        MediaQuery.viewInsetsOf(context).bottom + 24,
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxHeight: 760),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                widget.initialItem == null ? 'Novo item' : 'Editar item',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 6),
              Text(
                'Você pode ligar um produto ou registrar um item manual e ainda preservar o retrato salvo no pedido.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 16),
              _ProductLinkCard(
                productAsync: productAsync,
                onChooseProduct: _chooseProduct,
                onClearProduct: _selectedProductId == null
                    ? null
                    : () => setState(() {
                        _selectedProductId = null;
                        _selectedFlavor = null;
                        _selectedVariation = null;
                      }),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _nameController,
                textCapitalization: TextCapitalization.words,
                decoration: InputDecoration(
                  labelText: _selectedProductId == null
                      ? 'Nome do item'
                      : 'Nome salvo no pedido',
                  hintText: 'Ex.: Bolo no pote',
                  helperText: _selectedProductId == null
                      ? 'Use esse campo para itens manuais ou para ajustar o retrato do item.'
                      : 'Você pode ajustar este nome sem alterar o cadastro do produto.',
                ),
              ),
              if (availableFlavors.isNotEmpty) ...[
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  key: ValueKey(
                    'flavor-$selectedFlavorValue-${availableFlavors.length}',
                  ),
                  initialValue: selectedFlavorValue,
                  items: [
                    const DropdownMenuItem<String>(
                      value: null,
                      child: Text('Sem sabor definido'),
                    ),
                    for (final option in availableFlavors)
                      DropdownMenuItem<String>(
                        value: option.name,
                        child: Text(option.name),
                      ),
                  ],
                  onChanged: (value) => setState(() => _selectedFlavor = value),
                  decoration: const InputDecoration(labelText: 'Sabor'),
                ),
              ],
              if (availableVariations.isNotEmpty) ...[
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  key: ValueKey(
                    'variation-$selectedVariationValue-${availableVariations.length}',
                  ),
                  initialValue: selectedVariationValue,
                  items: [
                    const DropdownMenuItem<String>(
                      value: null,
                      child: Text('Sem variação definida'),
                    ),
                    for (final option in availableVariations)
                      DropdownMenuItem<String>(
                        value: option.name,
                        child: Text(option.name),
                      ),
                  ],
                  onChanged: (value) =>
                      setState(() => _selectedVariation = value),
                  decoration: const InputDecoration(labelText: 'Variação'),
                ),
              ],
              const SizedBox(height: 16),
              TextField(
                controller: _priceController,
                keyboardType: TextInputType.number,
                inputFormatters: const <TextInputFormatter>[_currencyFormatter],
                decoration: const InputDecoration(
                  labelText: 'Preço do item',
                  prefixText: 'R\$ ',
                  hintText: '0,00',
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _quantityController,
                keyboardType: TextInputType.number,
                inputFormatters: <TextInputFormatter>[
                  FilteringTextInputFormatter.digitsOnly,
                ],
                decoration: const InputDecoration(
                  labelText: 'Quantidade',
                  hintText: '1',
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _notesController,
                minLines: 2,
                maxLines: 4,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  labelText: 'Observação do item',
                  hintText: 'Ex.: topper separado, embalagem especial',
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
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Cancelar'),
                    ),
                    FilledButton.icon(
                      onPressed: _saveItem,
                      icon: const Icon(Icons.save_rounded),
                      label: const Text('Salvar item'),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _chooseProduct() async {
    final product = await showProductPickerSheet(context);
    if (!mounted || product == null) {
      return;
    }

    setState(() {
      _selectedProductId = product.id;
      _nameController.text = product.name;
      if (_priceController.text.trim().isEmpty) {
        _priceController.text = product.basePrice.formatInput();
      }
      _selectedFlavor = null;
      _selectedVariation = null;
    });
  }

  void _saveItem() {
    if (_nameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Digite pelo menos o nome do item.')),
      );
      return;
    }

    final quantity = int.tryParse(_quantityController.text.trim()) ?? 1;
    if (quantity <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Use uma quantidade maior que zero.')),
      );
      return;
    }

    Navigator.of(context).pop(
      OrderItemInput(
        id: widget.initialItem?.id,
        productId: _selectedProductId,
        itemNameSnapshot: _nameController.text.trim(),
        flavorSnapshot: _selectedFlavor,
        variationSnapshot: _selectedVariation,
        price: Money.fromInput(_priceController.text),
        quantity: quantity,
        notes: _notesController.text.trim().isEmpty
            ? null
            : _notesController.text.trim(),
      ),
    );
  }
}

class _ProductLinkCard extends StatelessWidget {
  const _ProductLinkCard({
    required this.productAsync,
    required this.onChooseProduct,
    required this.onClearProduct,
  });

  final AsyncValue<ProductRecord?>? productAsync;
  final Future<void> Function() onChooseProduct;
  final VoidCallback? onClearProduct;

  @override
  Widget build(BuildContext context) {
    final linkedProduct = productAsync?.asData?.value;

    if (productAsync == null) {
      return _BaseLinkCard(
        icon: Icons.inventory_2_outlined,
        title: 'Item manual',
        message:
            'Você pode seguir só com o nome e o preço do item ou ligar um produto para puxar a base comercial.',
        footer: Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            FilledButton.tonalIcon(
              onPressed: onChooseProduct,
              icon: const Icon(Icons.add_box_outlined),
              label: const Text('Escolher produto'),
            ),
          ],
        ),
      );
    }

    if (productAsync?.isLoading ?? false) {
      return const _BaseLinkCard(
        icon: Icons.sync_rounded,
        title: 'Carregando produto',
        message: 'Buscando os detalhes do produto vinculado.',
        footer: Padding(
          padding: EdgeInsets.only(top: 16),
          child: LinearProgressIndicator(),
        ),
      );
    }

    if ((productAsync?.hasError ?? false) || linkedProduct == null) {
      return _BaseLinkCard(
        icon: Icons.inventory_2_outlined,
        title: 'Produto vinculado indisponível',
        message:
            'O item continua salvo pelo nome e preço do pedido, mas o cadastro do produto não está disponível agora.',
        footer: Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            FilledButton.tonalIcon(
              onPressed: onChooseProduct,
              icon: const Icon(Icons.swap_horiz_rounded),
              label: const Text('Trocar produto'),
            ),
            OutlinedButton.icon(
              onPressed: onClearProduct,
              icon: const Icon(Icons.link_off_rounded),
              label: const Text('Seguir manual'),
            ),
          ],
        ),
      );
    }

    return _BaseLinkCard(
      icon: Icons.verified_rounded,
      title: linkedProduct.name,
      message: linkedProduct.priceLabel,
      footer: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              ProductTypeBadge(type: linkedProduct.type),
              ProductSaleModeBadge(saleMode: linkedProduct.saleMode),
            ],
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              FilledButton.tonalIcon(
                onPressed: onChooseProduct,
                icon: const Icon(Icons.swap_horiz_rounded),
                label: const Text('Trocar produto'),
              ),
              OutlinedButton.icon(
                onPressed: onClearProduct,
                icon: const Icon(Icons.link_off_rounded),
                label: const Text('Remover vínculo'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _BaseLinkCard extends StatelessWidget {
  const _BaseLinkCard({
    required this.icon,
    required this.title,
    required this.message,
    this.footer,
  });

  final IconData icon;
  final String title;
  final String message;
  final Widget? footer;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final footerItems = footer == null ? null : <Widget>[footer!];

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
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
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surface,
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
                    Text(message, style: theme.textTheme.bodyMedium),
                  ],
                ),
              ),
            ],
          ),
          ...?footerItems,
        ],
      ),
    );
  }
}
