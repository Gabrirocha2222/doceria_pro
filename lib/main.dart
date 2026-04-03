import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/app.dart';
import 'app/bootstrap.dart';
import 'core/bootstrap/app_bootstrap_state.dart';

Future<void> main() async {
  final bootstrapState = await bootstrap();

  runApp(
    ProviderScope(
      overrides: [appBootstrapStateProvider.overrideWithValue(bootstrapState)],
      child: const DoceriaProApp(),
    ),
  );
}
