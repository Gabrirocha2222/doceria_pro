import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app_bootstrap_state.dart';
import 'app_environment.dart';

Future<AppBootstrapState> initializeSupabaseBootstrap(
  AppEnvironment environment,
) async {
  if (!environment.hasSupabaseConfig) {
    return AppBootstrapState(
      environment: environment,
      supabaseStatus: SupabaseStatus.notConfigured,
    );
  }

  try {
    await Supabase.initialize(
      url: environment.supabaseUrl,
      anonKey: environment.supabaseAnonKey,
      debug: kDebugMode,
    );

    return AppBootstrapState(
      environment: environment,
      supabaseStatus: SupabaseStatus.ready,
    );
  } catch (error) {
    return AppBootstrapState(
      environment: environment,
      supabaseStatus: SupabaseStatus.failed,
      technicalMessage: error.toString(),
    );
  }
}
