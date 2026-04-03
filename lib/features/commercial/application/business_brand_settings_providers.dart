import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/business_brand_settings_repository.dart';
import '../domain/business_brand_settings.dart';

final businessBrandSettingsRepositoryProvider =
    Provider<BusinessBrandSettingsRepository>((ref) {
      return BusinessBrandSettingsRepository();
    });

final businessBrandSettingsProvider = FutureProvider<BusinessBrandSettings>((
  ref,
) async {
  return ref.watch(businessBrandSettingsRepositoryProvider).load();
});
