import 'package:doceria_pro/core/bootstrap/app_bootstrap_state.dart';
import 'package:doceria_pro/core/bootstrap/app_environment.dart';
import 'package:doceria_pro/core/money/money.dart';
import 'package:doceria_pro/features/dashboard/application/dashboard_providers.dart';
import 'package:doceria_pro/features/dashboard/domain/dashboard.dart';
import 'package:doceria_pro/features/dashboard/presentation/dashboard_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/date_symbol_data_local.dart';

void main() {
  setUpAll(() async {
    await initializeDateFormatting('pt_BR');
  });

  testWidgets('dashboard keeps the new order action visible and routes cards', (
    tester,
  ) async {
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (context, state) => ProviderScope(
            overrides: [
              appBootstrapStateProvider.overrideWithValue(
                const AppBootstrapState(
                  environment: AppEnvironment(
                    supabaseUrl: '',
                    supabaseAnonKey: '',
                  ),
                  supabaseStatus: SupabaseStatus.notConfigured,
                ),
              ),
              dashboardSnapshotProvider.overrideWith(
                (ref) => AsyncValue.data(_sampleSnapshot),
              ),
            ],
            child: const Material(child: DashboardPage()),
          ),
        ),
        GoRoute(
          path: '/orders',
          builder: (context, state) =>
              const Material(child: Center(child: Text('Pedidos destino'))),
          routes: [
            GoRoute(
              path: 'new',
              builder: (context, state) => const Material(
                child: Center(child: Text('Novo pedido destino')),
              ),
            ),
          ],
        ),
        GoRoute(
          path: '/production',
          builder: (context, state) =>
              const Material(child: Center(child: Text('Produção destino'))),
        ),
        GoRoute(
          path: '/purchases',
          builder: (context, state) =>
              const Material(child: Center(child: Text('Compras destino'))),
          routes: [
            GoRoute(
              path: 'stock',
              builder: (context, state) =>
                  const Material(child: Center(child: Text('Estoque destino'))),
            ),
          ],
        ),
        GoRoute(
          path: '/finance',
          builder: (context, state) =>
              const Material(child: Center(child: Text('Financeiro destino'))),
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(
      MaterialApp.router(
        routerConfig: router,
        debugShowCheckedModeBanner: false,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('+ Novo pedido'), findsOneWidget);
    expect(find.text('Pedidos da semana'), findsOneWidget);

    await tester.tap(find.text('Pedidos da semana'));
    await tester.pumpAndSettle();

    expect(find.text('Pedidos destino'), findsOneWidget);

    router.go('/');
    await tester.pumpAndSettle();

    await tester.tap(find.text('+ Novo pedido'));
    await tester.pumpAndSettle();

    expect(find.text('Novo pedido destino'), findsOneWidget);
  });
}

final _sampleSnapshot = DashboardSnapshot(
  greetingTitle: 'Bom dia',
  greetingSubtitle: 'Resumo pronto',
  attentionSummary: 'Hoje você tem três frentes principais.',
  summaryCards: [
    DashboardSummaryCardData(
      title: 'Pedidos da semana',
      value: '3',
      caption: '3 pedidos programados até domingo.',
      destination: DashboardDestination.orders,
    ),
    DashboardSummaryCardData(
      title: 'Lucro previsto',
      value: 'R\$ 320,00',
      caption: 'Previsão somada dos pedidos ativos dos próximos dias.',
      destination: DashboardDestination.finance,
    ),
    DashboardSummaryCardData(
      title: 'Falta receber',
      value: 'R\$ 180,00',
      caption: '2 cobranças pendentes até o fim da semana.',
      destination: DashboardDestination.finance,
    ),
    DashboardSummaryCardData(
      title: 'Materiais baixos',
      value: '2',
      caption: '1 item pede compra agora.',
      destination: DashboardDestination.stock,
    ),
  ],
  actions: [
    DashboardActionItem(
      title: 'Produção de hoje',
      subtitle: 'Tudo que vence hoje está concentrado no fluxo de produção.',
      valueLabel: '2 tarefas',
      destination: DashboardDestination.production,
    ),
    DashboardActionItem(
      title: 'Entregas e retiradas',
      subtitle: '2 pedidos precisam ser acompanhados hoje.',
      valueLabel: '2 pedidos',
      destination: DashboardDestination.orders,
    ),
    DashboardActionItem(
      title: 'Sinais pendentes',
      subtitle: 'Vale cobrar antes de confirmar a produção e a entrega.',
      valueLabel: '1 pedido',
      destination: DashboardDestination.finance,
    ),
    DashboardActionItem(
      title: 'Itens para comprar',
      subtitle: 'A checklist já mostra só o que realmente está faltando.',
      valueLabel: '1 item',
      destination: DashboardDestination.purchases,
    ),
  ],
  weekAgenda: [
    DashboardAgendaEntry(
      label: 'Hoje',
      subtitle: 'Amanda • Bianca',
      orderCount: 2,
      totalAmount: Money.fromCents(42000),
      destination: DashboardDestination.orders,
    ),
  ],
  alerts: [
    DashboardAlertItem(
      priority: DashboardAlertPriority.high,
      title: 'Produção atrasada',
      message: '1 tarefa já passou do prazo e pede revisão agora.',
      destination: DashboardDestination.production,
    ),
  ],
  financeSummary: DashboardFinanceSummary(
    cashInToday: Money.fromCents(5000),
    cashOutToday: Money.fromCents(1200),
    pendingReceivables: Money.fromCents(18000),
    preparedExpenses: Money.fromCents(3500),
    netToday: Money.fromCents(3800),
  ),
);
