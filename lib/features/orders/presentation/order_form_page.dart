import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/navigation/app_destinations.dart';
import '../../../core/formatters/app_formatters.dart';
import '../../../core/money/currency_text_input_formatter.dart';
import '../../../core/money/money.dart';
import '../../../core/responsive/app_breakpoints.dart';
import '../../../core/widgets/app_page_scaffold.dart';
import '../../../core/widgets/states/app_error_state.dart';
import '../../../core/widgets/states/app_loading_state.dart';
import '../../clients/application/client_providers.dart';
import '../../clients/domain/client.dart';
import '../../clients/presentation/widgets/client_picker_sheet.dart';
import '../../clients/presentation/widgets/quick_client_form_sheet.dart';
import '../../products/application/product_providers.dart';
import '../../products/domain/product.dart';
import '../../products/presentation/widgets/product_picker_sheet.dart';
import '../application/order_providers.dart';
import '../application/order_smart_review_service.dart';
import '../domain/order.dart';
import '../domain/order_fulfillment_method.dart';
import '../domain/order_status.dart';
import 'widgets/order_summary_header.dart';

class OrderFormPage extends ConsumerWidget {
  const OrderFormPage({super.key, this.orderId});

  final String? orderId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (orderId == null) {
      return const _OrderFormView();
    }

    final orderAsync = ref.watch(orderProvider(orderId!));

    return orderAsync.when(
      loading: () => const AppPageScaffold(
        title: 'Abrindo pedido',
        subtitle: 'Carregando os dados para editar com calma.',
        child: AppLoadingState(message: 'Carregando pedido...'),
      ),
      error: (error, stackTrace) => AppPageScaffold(
        title: 'Não deu para abrir',
        subtitle: 'Algo falhou ao carregar este pedido.',
        child: AppErrorState(
          title: 'Pedido indisponível',
          message: 'Volte para a lista e tente abrir novamente.',
          actionLabel: 'Voltar para pedidos',
          onAction: () => context.go(AppDestinations.orders.path),
        ),
      ),
      data: (order) {
        if (order == null) {
          return AppPageScaffold(
            title: 'Pedido não encontrado',
            subtitle: 'Não existe um pedido local com esse identificador.',
            child: AppErrorState(
              title: 'Pedido não encontrado',
              message: 'Volte para a lista e escolha um pedido salvo.',
              actionLabel: 'Voltar para pedidos',
              onAction: () => context.go(AppDestinations.orders.path),
            ),
          );
        }

        return _OrderFormView(initialOrder: order);
      },
    );
  }
}

class _OrderFormView extends ConsumerStatefulWidget {
  const _OrderFormView({this.initialOrder});

  final OrderRecord? initialOrder;

  @override
  ConsumerState<_OrderFormView> createState() => _OrderFormViewState();
}

class _OrderFormViewState extends ConsumerState<_OrderFormView> {
  static const _currencyFormatter = CurrencyTextInputFormatter();
  static const _wizardSteps = <_WizardStep>[
    _WizardStep(
      title: 'Pedido rápido',
      subtitle: 'Só o essencial para começar',
    ),
    _WizardStep(
      title: 'Revisão inteligente',
      subtitle: 'Custo, materiais e margem prevista',
    ),
    _WizardStep(
      title: 'Confirmar pedido',
      subtitle: 'Gerar produção, materiais e financeiro',
    ),
  ];

  late final TextEditingController _clientNameController;
  late final TextEditingController _quantityController;
  late final TextEditingController _deliveryFeeController;
  late final TextEditingController _salePriceOverrideController;
  late final TextEditingController _depositController;
  late final TextEditingController _notesController;
  late final TextEditingController _referencePhotoPathController;

  late final List<OrderItemInput> _legacyAdditionalItems;
  String? _selectedClientId;
  String? _selectedProductId;
  DateTime? _eventDate;
  OrderFulfillmentMethod? _fulfillmentMethod;
  late OrderStatus _status;
  bool _statusWasPickedManually = false;
  bool _isSaving = false;
  bool _isRefreshingReview = false;
  bool _reviewDirty = true;
  int _currentStep = 0;
  int _reviewToken = 0;
  Timer? _reviewDebounce;
  OrderSmartReviewResult? _smartReview;
  String? _reviewErrorMessage;

  bool get _isEditing => widget.initialOrder != null;

  int get _quantity {
    final parsed = int.tryParse(_quantityController.text.trim());
    if (parsed == null || parsed <= 0) {
      return 1;
    }

    return parsed;
  }

  Money get _deliveryFee =>
      _fulfillmentMethod == OrderFulfillmentMethod.delivery
      ? Money.fromInput(_deliveryFeeController.text)
      : Money.zero;

  Money get _salePriceOverride =>
      Money.fromInput(_salePriceOverrideController.text);

  Money get _depositAmount => Money.fromInput(_depositController.text);

  Money get _previewOrderTotal =>
      _smartReview?.orderTotal ?? (_salePriceOverride + _deliveryFee);

  Money get _previewRemainingAmount {
    if (_previewOrderTotal.cents <= _depositAmount.cents) {
      return Money.zero;
    }

    return _previewOrderTotal - _depositAmount;
  }

  bool get _hasEssentialStepReady =>
      _clientNameController.text.trim().isNotEmpty &&
      _selectedProductId != null &&
      _eventDate != null &&
      _fulfillmentMethod != null;

  bool get _hasInvalidDeposit =>
      _previewOrderTotal.cents > 0 &&
      _depositAmount.cents > _previewOrderTotal.cents;

  bool get _hasLegacyExtraItems => _legacyAdditionalItems.isNotEmpty;

  @override
  void initState() {
    super.initState();
    final initialOrder = widget.initialOrder;
    final initialPrimaryItem = initialOrder?.items.isNotEmpty == true
        ? initialOrder!.items.first
        : null;
    final initialSalePrice = initialOrder == null
        ? Money.zero
        : initialOrder.orderTotal - initialOrder.deliveryFee;
    final shouldKeepOverride =
        initialOrder != null &&
        (initialOrder.suggestedSalePrice.isZero ||
            initialSalePrice.cents != initialOrder.suggestedSalePrice.cents);

    _clientNameController = TextEditingController(
      text: initialOrder?.clientNameSnapshot ?? '',
    );
    _quantityController = TextEditingController(
      text: initialPrimaryItem?.quantity.toString() ?? '1',
    );
    _deliveryFeeController = TextEditingController(
      text: initialOrder == null || initialOrder.deliveryFee.isZero
          ? ''
          : initialOrder.deliveryFee.formatInput(),
    );
    _salePriceOverrideController = TextEditingController(
      text: shouldKeepOverride && initialSalePrice.isPositive
          ? initialSalePrice.formatInput()
          : '',
    );
    _depositController = TextEditingController(
      text: initialOrder == null || initialOrder.depositAmount.isZero
          ? ''
          : initialOrder.depositAmount.formatInput(),
    );
    _notesController = TextEditingController(text: initialOrder?.notes ?? '');
    _referencePhotoPathController = TextEditingController(
      text: initialOrder?.referencePhotoPath ?? '',
    );
    _legacyAdditionalItems = [
      for (final item
          in initialOrder?.items.skip(1) ?? const <OrderItemRecord>[])
        OrderItemInput(
          id: item.id,
          productId: item.productId,
          itemNameSnapshot: item.itemNameSnapshot,
          flavorSnapshot: item.flavorSnapshot,
          variationSnapshot: item.variationSnapshot,
          price: item.price,
          quantity: item.quantity,
          notes: item.notes,
        ),
    ];

    _selectedClientId = initialOrder?.clientId;
    _selectedProductId = initialPrimaryItem?.productId;
    _eventDate = initialOrder?.eventDate;
    _fulfillmentMethod = initialOrder?.fulfillmentMethod;
    _status = initialOrder?.status ?? OrderStatus.budget;
    _statusWasPickedManually = initialOrder != null;

    _clientNameController.addListener(_handleBasicFieldChanged);
    _quantityController.addListener(_handleReviewInputChanged);
    _deliveryFeeController.addListener(_handleReviewInputChanged);
    _salePriceOverrideController.addListener(_handleReviewInputChanged);
    _depositController.addListener(_handleReviewInputChanged);

    if (_selectedProductId != null &&
        _clientNameController.text.trim().isNotEmpty &&
        _eventDate != null &&
        _fulfillmentMethod != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        unawaited(_refreshSmartReview(forceVisibleLoading: false));
      });
    }
  }

  @override
  void dispose() {
    _reviewDebounce?.cancel();
    _clientNameController.dispose();
    _quantityController.dispose();
    _deliveryFeeController.dispose();
    _salePriceOverrideController.dispose();
    _depositController.dispose();
    _notesController.dispose();
    _referencePhotoPathController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final selectedClientAsync = _selectedClientId == null
        ? null
        : ref.watch(clientProvider(_selectedClientId!));
    final selectedProductAsync = _selectedProductId == null
        ? null
        : ref.watch(productProvider(_selectedProductId!));
    final selectedProduct = selectedProductAsync?.asData?.value;
    final title = _isEditing ? 'Editar pedido' : 'Novo pedido';
    final subtitle = _isEditing
        ? 'Revise o pedido em três etapas e confirme com previsões locais.'
        : 'Salve primeiro o essencial e confirme com uma revisão mais inteligente.';

    return AppPageScaffold(
      title: title,
      subtitle: subtitle,
      trailing: Wrap(
        spacing: 12,
        runSpacing: 12,
        children: [
          OutlinedButton.icon(
            onPressed: _isSaving ? null : _goBack,
            icon: const Icon(Icons.arrow_back_rounded),
            label: Text(_isEditing ? 'Cancelar' : 'Voltar'),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          OrderSummaryHeader(
            title: _clientNameController.text.trim().isEmpty
                ? 'Pedido sem cliente definido'
                : _clientNameController.text.trim(),
            subtitle: _buildSummarySubtitle(selectedProduct),
            status: _status,
            totalAmount: _previewOrderTotal,
            middleAmountLabel: 'Sinal',
            depositAmount: _depositAmount,
            remainingAmount: _previewRemainingAmount,
            isDraft: !_hasEssentialStepReady || _previewOrderTotal.isZero,
          ),
          const SizedBox(height: 16),
          _OrderWizardStepIndicator(
            steps: _wizardSteps,
            currentStep: _currentStep,
          ),
          const SizedBox(height: 16),
          if (_hasLegacyExtraItems)
            const Padding(
              padding: EdgeInsets.only(bottom: 16),
              child: _InlineInfoBanner(
                icon: Icons.layers_outlined,
                title: 'Pedido com itens extras preservados',
                message:
                    'Este pedido já tinha itens adicionais do formato anterior. Eles serão mantidos ao confirmar, sem entrar na previsão automática desta tela.',
              ),
            ),
          if (_currentStep == 0)
            _buildQuickOrderStep(
              context,
              selectedClientAsync: selectedClientAsync,
              selectedProductAsync: selectedProductAsync,
            )
          else if (_currentStep == 1)
            _buildSmartReviewStep(context, selectedProduct)
          else
            _buildConfirmStep(context, selectedProduct),
          const SizedBox(height: 20),
          _OrderFlowActions(
            currentStep: _currentStep,
            isSaving: _isSaving,
            isRefreshingReview: _isRefreshingReview,
            onBack: _currentStep == 0
                ? null
                : () => setState(() => _currentStep -= 1),
            onPrimary: _isSaving
                ? null
                : () async {
                    if (_currentStep == 0) {
                      await _goToSmartReview();
                      return;
                    }
                    if (_currentStep == 1) {
                      await _goToConfirmStep();
                      return;
                    }

                    await _confirmOrder();
                  },
          ),
        ],
      ),
    );
  }

  Widget _buildQuickOrderStep(
    BuildContext context, {
    required AsyncValue<ClientRecord?>? selectedClientAsync,
    required AsyncValue<ProductRecord?>? selectedProductAsync,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionCard(
          title: 'Cliente e data',
          subtitle:
              'Registre primeiro quem é a cliente e para quando o pedido precisa ficar pronto.',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _ClientLinkSection(
                linkedClientAsync: selectedClientAsync,
                linkedClientId: _selectedClientId,
                onChooseExistingClient: _pickExistingClient,
                onQuickCreateClient: _quickCreateClient,
                onClearLinkedClient: _selectedClientId == null
                    ? null
                    : () {
                        setState(() => _selectedClientId = null);
                        _markReviewDirty();
                      },
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _clientNameController,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                  labelText: 'Nome da cliente',
                  hintText: 'Ex.: Mariana Silva',
                  helperText:
                      'Você pode usar só o nome agora. O cadastro completo continua opcional.',
                ),
              ),
              const SizedBox(height: 16),
              _DatePickerRow(
                selectedDate: _eventDate,
                onSelectDate: _pickDate,
                onClearDate: _eventDate == null
                    ? null
                    : () {
                        setState(() => _eventDate = null);
                        _markReviewDirty();
                      },
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        _SectionCard(
          title: 'Produto e quantidade',
          subtitle:
              'Escolha o produto base para o cálculo inteligente e ajuste a quantidade do jeito mais direto possível.',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _ProductQuickLinkCard(
                productAsync: selectedProductAsync,
                onChooseProduct: _pickProduct,
                onClearProduct: _selectedProductId == null
                    ? null
                    : () {
                        setState(() => _selectedProductId = null);
                        _markReviewDirty();
                      },
              ),
              const SizedBox(height: 16),
              LayoutBuilder(
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
                          controller: _quantityController,
                          keyboardType: TextInputType.number,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                          ],
                          decoration: const InputDecoration(
                            labelText: 'Quantidade',
                            hintText: '1',
                            helperText:
                                'A previsão usa esta quantidade como base.',
                          ),
                        ),
                      ),
                      SizedBox(
                        width: fieldWidth,
                        child: _QuantityShortcutRow(
                          quantity: _quantity,
                          onDecrease: () => _adjustQuantity(-1),
                          onIncrease: () => _adjustQuantity(1),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        _SectionCard(
          title: 'Entrega ou retirada',
          subtitle:
              'Defina como a saída vai acontecer. A taxa entra só quando fizer sentido.',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SegmentedButton<OrderFulfillmentMethod>(
                emptySelectionAllowed: true,
                showSelectedIcon: false,
                selected: _fulfillmentMethod == null
                    ? const {}
                    : {_fulfillmentMethod!},
                segments: const [
                  ButtonSegment<OrderFulfillmentMethod>(
                    value: OrderFulfillmentMethod.pickup,
                    icon: Icon(Icons.store_mall_directory_outlined),
                    label: Text('Retirada'),
                  ),
                  ButtonSegment<OrderFulfillmentMethod>(
                    value: OrderFulfillmentMethod.delivery,
                    icon: Icon(Icons.local_shipping_outlined),
                    label: Text('Entrega'),
                  ),
                ],
                onSelectionChanged: (selection) {
                  setState(() {
                    _fulfillmentMethod = selection.isEmpty
                        ? null
                        : selection.first;
                    if (_fulfillmentMethod != OrderFulfillmentMethod.delivery) {
                      _deliveryFeeController.clear();
                    }
                  });
                  _markReviewDirty();
                },
              ),
              const SizedBox(height: 16),
              if (_fulfillmentMethod == OrderFulfillmentMethod.delivery)
                TextField(
                  controller: _deliveryFeeController,
                  keyboardType: TextInputType.number,
                  inputFormatters: const [_currencyFormatter],
                  decoration: const InputDecoration(
                    labelText: 'Taxa de entrega',
                    prefixText: 'R\$ ',
                    hintText: '0,00',
                  ),
                )
              else
                Text(
                  _fulfillmentMethod == OrderFulfillmentMethod.pickup
                      ? 'Sem taxa de entrega porque o pedido está marcado como retirada.'
                      : 'Você pode definir isso agora para a revisão já prever o valor total.',
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSmartReviewStep(BuildContext context, ProductRecord? product) {
    if (_isRefreshingReview && _smartReview == null) {
      return const _SectionCard(
        title: 'Revisão inteligente',
        subtitle: 'Montando custo, materiais e sugestão de embalagem.',
        child: AppLoadingState(message: 'Preparando revisão...'),
      );
    }

    if (_reviewErrorMessage != null && _smartReview == null) {
      return _SectionCard(
        title: 'Revisão inteligente',
        subtitle: 'Não foi possível montar a revisão agora.',
        child: AppErrorState(
          title: 'Revisão indisponível',
          message: _reviewErrorMessage!,
          actionLabel: 'Tentar de novo',
          onAction: () => unawaited(_refreshSmartReview()),
        ),
      );
    }

    final review = _smartReview;
    if (review == null) {
      return const _SectionCard(
        title: 'Revisão inteligente',
        subtitle: 'Complete o pedido rápido para gerar a previsão local.',
        child: Text('Ainda faltam dados para montar a revisão.'),
      );
    }

    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (review.hasLimitations)
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: _InlineInfoBanner(
              icon: Icons.info_outline_rounded,
              title: 'Leitura parcial, mas útil',
              message: review.smartReviewSummary,
            ),
          ),
        _SectionCard(
          title: 'Resumo inteligente',
          subtitle:
              'Aqui entram custo, margem prevista e o que já vale separar antes de confirmar.',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              LayoutBuilder(
                builder: (context, constraints) {
                  final compactLayout = AppBreakpoints.isCompactWidth(
                    constraints.maxWidth,
                  );
                  final itemWidth = compactLayout
                      ? constraints.maxWidth
                      : (constraints.maxWidth - 24) / 3;

                  return Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      SizedBox(
                        width: itemWidth,
                        child: _SmartMetricCard(
                          label: 'Custo estimado',
                          value: review.estimatedCost.format(),
                        ),
                      ),
                      SizedBox(
                        width: itemWidth,
                        child: _SmartMetricCard(
                          label: 'Venda sugerida',
                          value: review.suggestedSalePrice.format(),
                        ),
                      ),
                      SizedBox(
                        width: itemWidth,
                        child: _SmartMetricCard(
                          label: 'Lucro previsto',
                          value: review.predictedProfit.format(),
                          tone: review.predictedProfit.isNegative
                              ? _MetricTone.attention
                              : _MetricTone.defaultTone,
                        ),
                      ),
                      SizedBox(
                        width: itemWidth,
                        child: _SmartMetricCard(
                          label: 'Embalagem sugerida',
                          value:
                              review.suggestedPackagingNameSnapshot ??
                              'Sem sugestão',
                        ),
                      ),
                      SizedBox(
                        width: itemWidth,
                        child: _SmartMetricCard(
                          label: 'Faltas encontradas',
                          value: review.shortages.length.toString(),
                          tone: review.shortages.isEmpty
                              ? _MetricTone.defaultTone
                              : _MetricTone.attention,
                        ),
                      ),
                      SizedBox(
                        width: itemWidth,
                        child: _SmartMetricCard(
                          label: 'Estado do sinal',
                          value: review.depositStateLabel,
                        ),
                      ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 16),
              Text(
                product == null
                    ? 'Sem produto carregado'
                    : '${product.name} • $_quantity ${_quantity == 1 ? 'unidade' : 'unidades'}',
                style: theme.textTheme.titleMedium,
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        _SectionCard(
          title: 'Ajustes rápidos',
          subtitle:
              'Se precisar, ajuste só o que muda a leitura comercial do pedido.',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              LayoutBuilder(
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
                          controller: _salePriceOverrideController,
                          keyboardType: TextInputType.number,
                          inputFormatters: const [_currencyFormatter],
                          decoration: InputDecoration(
                            labelText: 'Ajustar valor de venda',
                            prefixText: 'R\$ ',
                            hintText: '0,00',
                            helperText:
                                'Em branco, usamos ${review.suggestedSalePrice.format()} como base.',
                          ),
                        ),
                      ),
                      SizedBox(
                        width: fieldWidth,
                        child: TextField(
                          controller: _depositController,
                          keyboardType: TextInputType.number,
                          inputFormatters: const [_currencyFormatter],
                          decoration: InputDecoration(
                            labelText: 'Sinal combinado',
                            prefixText: 'R\$ ',
                            hintText: '0,00',
                            errorText: _hasInvalidDeposit
                                ? 'O sinal não pode passar do total.'
                                : null,
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _referencePhotoPathController,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(
                  labelText: 'Caminho local da foto de referência',
                  hintText: '/home/gabriel/imagens/bolo-aniversario.jpg',
                  helperText:
                      'Guarde só o caminho local por enquanto. O envio em nuvem fica para depois.',
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _notesController,
                minLines: 3,
                maxLines: 5,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  labelText: 'Observações do pedido',
                  hintText: 'Combinações, preferências ou limites importantes.',
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        _SectionCard(
          title: 'Materiais e alertas',
          subtitle:
              'Veja o que já pode faltar antes de confirmar e o que a produção precisa enxergar.',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (review.materialNeeds.isEmpty)
                const Text(
                  'Nenhum material foi sugerido automaticamente ainda.',
                )
              else
                Column(
                  children: [
                    for (
                      var index = 0;
                      index < review.materialNeeds.length;
                      index++
                    ) ...[
                      _MaterialNeedTile(need: review.materialNeeds[index]),
                      if (index != review.materialNeeds.length - 1)
                        const SizedBox(height: 12),
                    ],
                  ],
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildConfirmStep(BuildContext context, ProductRecord? product) {
    final review = _smartReview;
    if (review == null) {
      return const _SectionCard(
        title: 'Confirmação',
        subtitle: 'A revisão precisa estar pronta antes de confirmar.',
        child: Text('Volte para a etapa anterior e gere a revisão.'),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionCard(
          title: 'Pedido pronto para confirmar',
          subtitle:
              'Você confirma o pedido e o app já guarda os registros internos para os próximos módulos.',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _ConfirmSummaryRow(
                label: 'Cliente',
                value: _clientNameController.text.trim(),
              ),
              const SizedBox(height: 12),
              _ConfirmSummaryRow(
                label: 'Data',
                value: _eventDate == null
                    ? 'Sem data'
                    : AppFormatters.dayMonthYear(_eventDate!),
              ),
              const SizedBox(height: 12),
              _ConfirmSummaryRow(
                label: 'Produto',
                value: product?.name ?? review.primaryItem.itemNameSnapshot,
              ),
              const SizedBox(height: 12),
              _ConfirmSummaryRow(
                label: 'Quantidade',
                value:
                    '${review.primaryItem.quantity} ${review.primaryItem.quantity == 1 ? 'unidade' : 'unidades'}',
              ),
              const SizedBox(height: 12),
              _ConfirmSummaryRow(
                label: 'Atendimento',
                value: _fulfillmentMethod?.label ?? 'Não definido',
              ),
              const SizedBox(height: 12),
              _ConfirmSummaryRow(
                label: 'Valor final do pedido',
                value: review.orderTotal.format(),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        _SectionCard(
          title: 'O que será gerado agora',
          subtitle:
              'Tudo fica salvo localmente para alimentar Produção, Materiais e Financeiro depois.',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _GeneratedRecordPill(
                label: 'Planos de produção',
                count: review.productionPlans.length,
              ),
              const SizedBox(height: 12),
              _GeneratedRecordPill(
                label: 'Necessidades de material',
                count: review.materialNeeds.length,
              ),
              const SizedBox(height: 12),
              _GeneratedRecordPill(
                label: 'Lançamentos financeiros',
                count: review.receivableEntries.length,
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        _SectionCard(
          title: 'Status do pedido',
          subtitle:
              'Escolha o status que mais faz sentido agora. O padrão acompanha o sinal quando você não mexe.',
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final status in OrderStatus.values)
                ChoiceChip(
                  label: Text(status.label),
                  selected: _status == status,
                  onSelected: (_) {
                    setState(() {
                      _status = status;
                      _statusWasPickedManually = true;
                    });
                  },
                ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _goToSmartReview() async {
    if (!_hasEssentialStepReady) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Preencha cliente, data, produto e entrega/retirada para seguir.',
          ),
        ),
      );
      return;
    }

    final success = await _refreshSmartReview();
    if (!mounted || !success) {
      return;
    }

    setState(() => _currentStep = 1);
  }

  Future<void> _goToConfirmStep() async {
    if (_hasInvalidDeposit) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Revise o sinal antes de continuar.')),
      );
      return;
    }

    final success = await _refreshSmartReview();
    if (!mounted || !success) {
      return;
    }

    setState(() => _currentStep = 2);
  }

  Future<void> _confirmOrder() async {
    if (_hasInvalidDeposit) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Revise o sinal antes de confirmar.')),
      );
      return;
    }

    final success = await _refreshSmartReview();
    if (!mounted || !success || _smartReview == null) {
      return;
    }

    setState(() => _isSaving = true);

    try {
      String? normalizedClientId = _selectedClientId;
      if (normalizedClientId != null) {
        final linkedClient = await ref
            .read(clientsRepositoryProvider)
            .getClient(normalizedClientId);
        if (linkedClient == null) {
          normalizedClientId = null;
        }
      }

      final review = _smartReview!;
      final savedOrderId = await ref
          .read(ordersRepositoryProvider)
          .saveOrder(
            OrderUpsertInput(
              id: widget.initialOrder?.id,
              clientId: normalizedClientId,
              clientNameSnapshot: _clientNameController.text.trim(),
              eventDate: _eventDate,
              fulfillmentMethod: _fulfillmentMethod,
              deliveryFee: _deliveryFee,
              referencePhotoPath: _referencePhotoPathController.text.trim(),
              notes: _notesController.text.trim(),
              estimatedCost: review.estimatedCost,
              suggestedSalePrice: review.suggestedSalePrice,
              predictedProfit: review.predictedProfit,
              suggestedPackagingId: review.suggestedPackagingId,
              suggestedPackagingNameSnapshot:
                  review.suggestedPackagingNameSnapshot,
              smartReviewSummary: review.smartReviewSummary,
              orderTotal: review.orderTotal,
              depositAmount: _depositAmount,
              status: _status,
              items: [review.primaryItem, ..._legacyAdditionalItems],
              productionPlans: review.productionPlans,
              materialNeeds: review.materialNeeds,
              receivableEntries: review.receivableEntries,
            ),
          );

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _isEditing
                ? 'Pedido confirmado com revisão atualizada neste aparelho.'
                : 'Pedido confirmado e preparado para os próximos módulos.',
          ),
        ),
      );
      context.go('${AppDestinations.orders.path}/$savedOrderId');
    } catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Não foi possível confirmar: $error')),
      );
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: _eventDate ?? now,
      firstDate: DateTime(now.year - 2),
      lastDate: DateTime(now.year + 5),
      locale: const Locale('pt', 'BR'),
    );

    if (pickedDate == null || !mounted) {
      return;
    }

    setState(() => _eventDate = pickedDate);
    _markReviewDirty();
  }

  Future<void> _pickExistingClient() async {
    final selectedClient = await showClientPickerSheet(context);
    if (!mounted || selectedClient == null) {
      return;
    }

    setState(() {
      _selectedClientId = selectedClient.id;
      _clientNameController.text = selectedClient.name;
    });
    _markReviewDirty();
  }

  Future<void> _quickCreateClient() async {
    final createdClient = await showQuickClientFormSheet(context);
    if (!mounted || createdClient == null) {
      return;
    }

    setState(() {
      _selectedClientId = createdClient.id;
      _clientNameController.text = createdClient.name;
    });
    _markReviewDirty();

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Cliente criada e ligada ao pedido.')),
    );
  }

  Future<void> _pickProduct() async {
    final product = await showProductPickerSheet(context);
    if (!mounted || product == null) {
      return;
    }

    setState(() {
      _selectedProductId = product.id;
      _reviewErrorMessage = null;
    });
    _markReviewDirty();
  }

  void _adjustQuantity(int delta) {
    final nextValue = (_quantity + delta).clamp(1, 9999);
    _quantityController.text = nextValue.toString();
    _markReviewDirty();
  }

  void _handleBasicFieldChanged() {
    setState(() {});
  }

  void _handleReviewInputChanged() {
    setState(() {});
    _markReviewDirty();
  }

  void _markReviewDirty() {
    _reviewDirty = true;
    if (_currentStep > 0) {
      _scheduleReviewRefresh();
    }
  }

  void _scheduleReviewRefresh() {
    _reviewDebounce?.cancel();
    _reviewDebounce = Timer(const Duration(milliseconds: 250), () {
      if (!mounted) {
        return;
      }

      unawaited(_refreshSmartReview(forceVisibleLoading: false));
    });
  }

  Future<bool> _refreshSmartReview({bool forceVisibleLoading = true}) async {
    if (!_reviewDirty && _smartReview != null) {
      return true;
    }

    if (!_hasEssentialStepReady) {
      setState(() {
        _smartReview = null;
        _reviewErrorMessage = null;
        _isRefreshingReview = false;
      });
      return false;
    }

    final token = ++_reviewToken;
    if (forceVisibleLoading || _smartReview == null) {
      setState(() => _isRefreshingReview = true);
    }

    try {
      final review = await ref
          .read(orderSmartReviewServiceProvider)
          .buildReview(
            OrderSmartReviewRequest(
              clientId: _selectedClientId,
              clientNameSnapshot: _clientNameController.text.trim(),
              eventDate: _eventDate,
              fulfillmentMethod: _fulfillmentMethod,
              productId: _selectedProductId,
              quantity: _quantity,
              deliveryFee: _deliveryFee,
              salePriceOverride: _salePriceOverride,
              depositAmount: _depositAmount,
              notes: _notesController.text.trim(),
              referencePhotoPath: _referencePhotoPathController.text.trim(),
            ),
          );

      if (!mounted || token != _reviewToken) {
        return false;
      }

      setState(() {
        _smartReview = review;
        _reviewErrorMessage = null;
        _isRefreshingReview = false;
        _reviewDirty = false;
        if (!_statusWasPickedManually) {
          if (_depositAmount.isPositive) {
            _status = OrderStatus.confirmed;
          } else if (review.orderTotal.isPositive) {
            _status = OrderStatus.awaitingDeposit;
          } else {
            _status = OrderStatus.budget;
          }
        }
      });
      return true;
    } catch (error) {
      if (!mounted || token != _reviewToken) {
        return false;
      }

      setState(() {
        _reviewErrorMessage = error.toString();
        _isRefreshingReview = false;
      });
      return false;
    }
  }

  void _goBack() {
    if (_isEditing) {
      context.go('${AppDestinations.orders.path}/${widget.initialOrder!.id}');
      return;
    }

    context.go(AppDestinations.orders.path);
  }

  String _buildSummarySubtitle(ProductRecord? selectedProduct) {
    final segments = <String>[
      if (_eventDate != null) AppFormatters.dayMonthYear(_eventDate!),
      if (_fulfillmentMethod != null) _fulfillmentMethod!.label,
      if (selectedProduct != null) selectedProduct.name,
      if (_smartReview != null)
        '$_quantity ${_quantity == 1 ? 'unidade' : 'unidades'}',
      if (_smartReview == null) 'Fluxo guiado em 3 etapas',
    ];

    return segments.join(' • ');
  }
}

class _WizardStep {
  const _WizardStep({required this.title, required this.subtitle});

  final String title;
  final String subtitle;
}

class _OrderWizardStepIndicator extends StatelessWidget {
  const _OrderWizardStepIndicator({
    required this.steps,
    required this.currentStep,
  });

  final List<_WizardStep> steps;
  final int currentStep;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compactLayout = AppBreakpoints.isCompactWidth(
          constraints.maxWidth,
        );
        final itemWidth = compactLayout
            ? constraints.maxWidth
            : (constraints.maxWidth - 24) / 3;

        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            for (var index = 0; index < steps.length; index++)
              SizedBox(
                width: itemWidth,
                child: _WizardStepCard(
                  index: index,
                  step: steps[index],
                  isCurrent: index == currentStep,
                  isComplete: index < currentStep,
                ),
              ),
          ],
        );
      },
    );
  }
}

class _WizardStepCard extends StatelessWidget {
  const _WizardStepCard({
    required this.index,
    required this.step,
    required this.isCurrent,
    required this.isComplete,
  });

  final int index;
  final _WizardStep step;
  final bool isCurrent;
  final bool isComplete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    const stepIcons = [
      Icons.looks_one_rounded,
      Icons.looks_two_rounded,
      Icons.looks_3_rounded,
    ];
    final backgroundColor = isCurrent
        ? colorScheme.primaryContainer
        : colorScheme.surfaceContainerLow;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isCurrent ? colorScheme.primary : colorScheme.outlineVariant,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 16,
                backgroundColor: isComplete
                    ? colorScheme.primary
                    : colorScheme.surface,
                child: Icon(
                  isComplete ? Icons.check_rounded : stepIcons[index],
                  size: 18,
                  color: isComplete
                      ? colorScheme.onPrimary
                      : colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(step.title, style: theme.textTheme.titleMedium),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(step.subtitle, style: theme.textTheme.bodyMedium),
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

class _InlineInfoBanner extends StatelessWidget {
  const _InlineInfoBanner({
    required this.icon,
    required this.title,
    required this.message,
  });

  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.secondaryContainer,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: theme.colorScheme.onSecondaryContainer),
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
    );
  }
}

class _ClientLinkSection extends StatelessWidget {
  const _ClientLinkSection({
    required this.linkedClientAsync,
    required this.linkedClientId,
    required this.onChooseExistingClient,
    required this.onQuickCreateClient,
    required this.onClearLinkedClient,
  });

  final AsyncValue<ClientRecord?>? linkedClientAsync;
  final String? linkedClientId;
  final Future<void> Function() onChooseExistingClient;
  final Future<void> Function() onQuickCreateClient;
  final VoidCallback? onClearLinkedClient;

  @override
  Widget build(BuildContext context) {
    final linkedClient = linkedClientAsync?.asData?.value;
    final theme = Theme.of(context);

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
          Text(
            linkedClientId == null
                ? 'Cliente ainda não vinculada'
                : linkedClient?.name ?? 'Cliente vinculada',
            style: theme.textTheme.titleMedium,
          ),
          const SizedBox(height: 6),
          Text(
            linkedClientId == null
                ? 'Você pode escolher uma cliente existente ou criar uma rápida sem sair do fluxo.'
                : (linkedClient == null
                      ? 'O retrato do pedido continua local, mesmo sem abrir o cadastro agora.'
                      : '${linkedClient.displayPhone} • ${linkedClient.rating.label}'),
            style: theme.textTheme.bodyMedium,
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              FilledButton.tonalIcon(
                onPressed: onChooseExistingClient,
                icon: const Icon(Icons.people_outline_rounded),
                label: Text(
                  linkedClientId == null
                      ? 'Escolher cliente'
                      : 'Trocar cliente',
                ),
              ),
              OutlinedButton.icon(
                onPressed: onQuickCreateClient,
                icon: const Icon(Icons.person_add_alt_rounded),
                label: const Text('Criar rápida'),
              ),
              if (linkedClientId != null)
                OutlinedButton.icon(
                  onPressed: onClearLinkedClient,
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

class _ProductQuickLinkCard extends StatelessWidget {
  const _ProductQuickLinkCard({
    required this.productAsync,
    required this.onChooseProduct,
    required this.onClearProduct,
  });

  final AsyncValue<ProductRecord?>? productAsync;
  final Future<void> Function() onChooseProduct;
  final VoidCallback? onClearProduct;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final product = productAsync?.asData?.value;

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
          Text(
            product?.name ?? 'Produto ainda não escolhido',
            style: theme.textTheme.titleMedium,
          ),
          const SizedBox(height: 6),
          Text(
            product == null
                ? 'Escolha um produto para puxar preço base, receitas e sugestão de embalagem quando houver.'
                : '${product.displayCategory} • ${product.priceLabel}',
            style: theme.textTheme.bodyMedium,
          ),
          if (product != null) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _SmallPill(
                  label:
                      '${product.linkedRecipes.length} ${product.linkedRecipes.length == 1 ? 'receita ligada' : 'receitas ligadas'}',
                ),
                _SmallPill(
                  label:
                      '${product.linkedPackagings.length} ${product.linkedPackagings.length == 1 ? 'embalagem compatível' : 'embalagens compatíveis'}',
                ),
              ],
            ),
          ],
          const SizedBox(height: 16),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              FilledButton.tonalIcon(
                onPressed: onChooseProduct,
                icon: const Icon(Icons.inventory_2_outlined),
                label: Text(
                  product == null ? 'Escolher produto' : 'Trocar produto',
                ),
              ),
              if (product != null)
                OutlinedButton.icon(
                  onPressed: onClearProduct,
                  icon: const Icon(Icons.link_off_rounded),
                  label: const Text('Limpar'),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _QuantityShortcutRow extends StatelessWidget {
  const _QuantityShortcutRow({
    required this.quantity,
    required this.onDecrease,
    required this.onIncrease,
  });

  final int quantity;
  final VoidCallback onDecrease;
  final VoidCallback onIncrease;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          IconButton.filledTonal(
            onPressed: onDecrease,
            icon: const Icon(Icons.remove_rounded),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              '$quantity ${quantity == 1 ? 'unidade' : 'unidades'}',
              textAlign: TextAlign.center,
              style: theme.textTheme.titleMedium,
            ),
          ),
          const SizedBox(width: 12),
          IconButton.filledTonal(
            onPressed: onIncrease,
            icon: const Icon(Icons.add_rounded),
          ),
        ],
      ),
    );
  }
}

class _DatePickerRow extends StatelessWidget {
  const _DatePickerRow({
    required this.selectedDate,
    required this.onSelectDate,
    required this.onClearDate,
  });

  final DateTime? selectedDate;
  final Future<void> Function() onSelectDate;
  final VoidCallback? onClearDate;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        FilledButton.tonalIcon(
          onPressed: onSelectDate,
          icon: const Icon(Icons.calendar_today_outlined),
          label: Text(
            selectedDate == null
                ? 'Escolher data'
                : AppFormatters.dayMonthYear(selectedDate!),
          ),
        ),
        if (selectedDate != null)
          OutlinedButton.icon(
            onPressed: onClearDate,
            icon: const Icon(Icons.close_rounded),
            label: const Text('Limpar'),
          ),
      ],
    );
  }
}

enum _MetricTone { defaultTone, attention }

class _SmartMetricCard extends StatelessWidget {
  const _SmartMetricCard({
    required this.label,
    required this.value,
    this.tone = _MetricTone.defaultTone,
  });

  final String label;
  final String value;
  final _MetricTone tone;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final backgroundColor = tone == _MetricTone.attention
        ? theme.colorScheme.errorContainer
        : theme.colorScheme.surfaceContainerLow;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: theme.textTheme.labelLarge),
          const SizedBox(height: 8),
          Text(value, style: theme.textTheme.titleLarge),
        ],
      ),
    );
  }
}

class _MaterialNeedTile extends StatelessWidget {
  const _MaterialNeedTile({required this.need});

  final OrderMaterialNeedInput need;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: need.shortageQuantity > 0
            ? theme.colorScheme.errorContainer
            : theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  need.nameSnapshot,
                  style: theme.textTheme.titleMedium,
                ),
              ),
              const SizedBox(width: 12),
              _SmallPill(label: need.materialType.label),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Precisa de ${need.requiredQuantity} ${need.unitLabel} • disponível ${need.availableQuantity} ${need.unitLabel}',
            style: theme.textTheme.bodyMedium,
          ),
          if (need.shortageQuantity > 0) ...[
            const SizedBox(height: 8),
            Text(
              'Falta prevista: ${need.shortageQuantity} ${need.unitLabel}',
              style: theme.textTheme.titleSmall,
            ),
          ],
          if (need.note?.trim().isNotEmpty ?? false) ...[
            const SizedBox(height: 8),
            Text(need.note!.trim(), style: theme.textTheme.bodySmall),
          ],
        ],
      ),
    );
  }
}

class _ConfirmSummaryRow extends StatelessWidget {
  const _ConfirmSummaryRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: Text(label, style: theme.textTheme.bodyMedium)),
        const SizedBox(width: 12),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.end,
            style: theme.textTheme.titleMedium,
          ),
        ),
      ],
    );
  }
}

class _GeneratedRecordPill extends StatelessWidget {
  const _GeneratedRecordPill({required this.label, required this.count});

  final String label;
  final int count;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          Expanded(child: Text(label, style: theme.textTheme.titleMedium)),
          Text(count.toString(), style: theme.textTheme.headlineSmall),
        ],
      ),
    );
  }
}

class _SmallPill extends StatelessWidget {
  const _SmallPill({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Text(label, style: theme.textTheme.labelLarge),
    );
  }
}

class _OrderFlowActions extends StatelessWidget {
  const _OrderFlowActions({
    required this.currentStep,
    required this.isSaving,
    required this.isRefreshingReview,
    required this.onBack,
    required this.onPrimary,
  });

  final int currentStep;
  final bool isSaving;
  final bool isRefreshingReview;
  final VoidCallback? onBack;
  final Future<void> Function()? onPrimary;

  @override
  Widget build(BuildContext context) {
    final primaryLabel = switch (currentStep) {
      0 => 'Ver revisão',
      1 => 'Ir para confirmação',
      _ => 'Confirmar pedido',
    };

    return Align(
      alignment: Alignment.centerRight,
      child: Wrap(
        spacing: 12,
        runSpacing: 12,
        children: [
          if (onBack != null)
            OutlinedButton.icon(
              onPressed: isSaving ? null : onBack,
              icon: const Icon(Icons.arrow_back_rounded),
              label: const Text('Voltar etapa'),
            ),
          FilledButton.icon(
            onPressed: isSaving || onPrimary == null
                ? null
                : () => unawaited(onPrimary!()),
            icon: isSaving || isRefreshingReview
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2.2),
                  )
                : Icon(
                    currentStep == 2
                        ? Icons.task_alt_rounded
                        : Icons.arrow_forward_rounded,
                  ),
            label: Text(
              isSaving
                  ? 'Salvando...'
                  : isRefreshingReview && currentStep < 2
                  ? 'Atualizando...'
                  : primaryLabel,
            ),
          ),
        ],
      ),
    );
  }
}
