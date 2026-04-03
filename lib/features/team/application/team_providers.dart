import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
import '../data/team_repository.dart';
import '../domain/team.dart';

final teamRepositoryProvider = Provider<TeamRepository>((ref) {
  return TeamRepository(ref.watch(appDatabaseProvider));
});

final teamContextProvider = StreamProvider<TeamContextRecord>((ref) {
  return ref.watch(teamRepositoryProvider).watchTeamContext();
});
