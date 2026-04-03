import 'package:doceria_pro/app/app.dart';
import 'package:doceria_pro/core/bootstrap/app_bootstrap_state.dart';
import 'package:doceria_pro/core/bootstrap/app_environment.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('shows bottom navigation on compact layouts', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(430, 932);
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(_buildTestApp());
    await tester.pumpAndSettle();

    expect(find.byType(NavigationBar), findsOneWidget);
    expect(find.byType(NavigationRail), findsNothing);
    expect(find.text('Modo offline pronto'), findsOneWidget);
  });

  testWidgets('shows navigation rail on wide layouts', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1440, 960);
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(_buildTestApp());
    await tester.pumpAndSettle();

    expect(find.byType(NavigationRail), findsOneWidget);
    expect(find.byType(NavigationBar), findsNothing);
    expect(find.text('Doceria Pro'), findsOneWidget);
  });
}

Widget _buildTestApp() {
  return ProviderScope(
    overrides: [
      appBootstrapStateProvider.overrideWithValue(
        const AppBootstrapState(
          environment: AppEnvironment(supabaseUrl: '', supabaseAnonKey: ''),
          supabaseStatus: SupabaseStatus.notConfigured,
        ),
      ),
    ],
    child: const DoceriaProApp(),
  );
}
