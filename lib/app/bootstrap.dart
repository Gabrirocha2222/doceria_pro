import 'package:flutter/widgets.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';

import '../core/bootstrap/app_bootstrap_state.dart';
import '../core/bootstrap/app_environment.dart';
import '../core/bootstrap/supabase_bootstrap.dart';

Future<AppBootstrapState> bootstrap() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('pt_BR');
  Intl.defaultLocale = 'pt_BR';

  return initializeSupabaseBootstrap(const AppEnvironment.fromDartDefines());
}
