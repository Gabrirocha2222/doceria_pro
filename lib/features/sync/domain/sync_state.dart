import '../../../core/bootstrap/app_bootstrap_state.dart';
import '../../../core/formatters/app_formatters.dart';
import '../../../core/sync/sync_definitions.dart';
import '../../team/domain/team.dart';

class RemoteEntitySnapshot {
  const RemoteEntitySnapshot({
    required this.teamId,
    required this.entityType,
    required this.entityId,
    required this.payload,
    required this.updatedAt,
    required this.updatedByMemberId,
    this.deletedAt,
    this.payloadSchema = 1,
  });

  final String teamId;
  final RootSyncEntityType entityType;
  final String entityId;
  final Map<String, Object?> payload;
  final DateTime updatedAt;
  final String updatedByMemberId;
  final DateTime? deletedAt;
  final int payloadSchema;
}

class SyncRunResult {
  const SyncRunResult({
    required this.pushedCount,
    required this.pulledCount,
    required this.skippedCount,
    required this.isRemoteConfigured,
    required this.hadError,
    this.errorMessage,
  });

  final int pushedCount;
  final int pulledCount;
  final int skippedCount;
  final bool isRemoteConfigured;
  final bool hadError;
  final String? errorMessage;
}

class SyncOverview {
  const SyncOverview({
    required this.bootstrapState,
    required this.teamContext,
    required this.pendingChangesCount,
    required this.lastStatus,
    required this.lastAttemptAt,
    required this.lastSuccessfulPushAt,
    required this.lastSuccessfulPullAt,
    required this.lastError,
    required this.isSyncing,
  });

  final AppBootstrapState bootstrapState;
  final TeamContextRecord teamContext;
  final int pendingChangesCount;
  final SyncRunStatus lastStatus;
  final DateTime? lastAttemptAt;
  final DateTime? lastSuccessfulPushAt;
  final DateTime? lastSuccessfulPullAt;
  final String? lastError;
  final bool isSyncing;

  bool get canSyncNow => bootstrapState.supabaseStatus == SupabaseStatus.ready;

  String get statusLabel {
    if (isSyncing) {
      return 'Sincronizando agora';
    }

    if (!canSyncNow) {
      return 'Offline pronto';
    }

    switch (lastStatus) {
      case SyncRunStatus.idle:
        return pendingChangesCount > 0
            ? 'Pronto para sincronizar'
            : 'Em dia com a nuvem';
      case SyncRunStatus.syncing:
        return 'Sincronizando agora';
      case SyncRunStatus.success:
        return pendingChangesCount > 0
            ? 'Parte já enviada'
            : 'Em dia com a nuvem';
      case SyncRunStatus.failed:
        return 'Falha na sincronização';
    }
  }

  String get helperText {
    if (!canSyncNow) {
      return pendingChangesCount > 0
          ? '$pendingChangesCount alteração(ões) continuam guardadas no aparelho e entram na fila quando a integração remota estiver pronta.'
          : 'O app segue funcionando no aparelho mesmo sem configuração remota.';
    }

    if (isSyncing) {
      return 'Enviando mudanças locais e buscando novidades da equipe.';
    }

    if (lastStatus == SyncRunStatus.failed) {
      final trimmedError = lastError?.trim();
      if (trimmedError != null && trimmedError.isNotEmpty) {
        return 'A última tentativa falhou: $trimmedError';
      }

      return 'A última tentativa falhou. As mudanças continuam na fila local.';
    }

    if (pendingChangesCount > 0) {
      return '$pendingChangesCount alteração(ões) aguardam envio para a base remota.';
    }

    if (lastSuccessfulPullAt != null) {
      return 'Última atualização remota em ${AppFormatters.dayMonthYear(lastSuccessfulPullAt!)}.';
    }

    return 'A integração remota está pronta para receber e trazer mudanças.';
  }
}
