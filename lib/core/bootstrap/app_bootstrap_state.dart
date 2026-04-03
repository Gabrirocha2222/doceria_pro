import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app_environment.dart';

enum SupabaseStatus { ready, notConfigured, failed }

class AppBootstrapState {
  const AppBootstrapState({
    required this.environment,
    required this.supabaseStatus,
    this.technicalMessage,
  });

  final AppEnvironment environment;
  final SupabaseStatus supabaseStatus;
  final String? technicalMessage;

  bool get shouldShowOfflineBanner => supabaseStatus != SupabaseStatus.ready;

  String get bannerTitle {
    switch (supabaseStatus) {
      case SupabaseStatus.ready:
        return 'Integração online ativa';
      case SupabaseStatus.notConfigured:
        return 'Modo offline pronto';
      case SupabaseStatus.failed:
        return 'Conexão online indisponível';
    }
  }

  String get bannerMessage {
    switch (supabaseStatus) {
      case SupabaseStatus.ready:
        return 'A base local está pronta e a integração remota foi inicializada.';
      case SupabaseStatus.notConfigured:
        return 'O app abriu sem credenciais remotas e continua pronto para uso local.';
      case SupabaseStatus.failed:
        return 'As credenciais foram lidas, mas a inicialização falhou. Você ainda pode seguir no modo local.';
    }
  }

  String get statusLabel {
    switch (supabaseStatus) {
      case SupabaseStatus.ready:
        return 'Online pronto';
      case SupabaseStatus.notConfigured:
        return 'Offline pronto';
      case SupabaseStatus.failed:
        return 'Offline com alerta';
    }
  }
}

final appBootstrapStateProvider = Provider<AppBootstrapState>((ref) {
  return const AppBootstrapState(
    environment: AppEnvironment.fromDartDefines(),
    supabaseStatus: SupabaseStatus.notConfigured,
  );
});
