import 'package:doceria_pro/features/commercial/data/business_brand_settings_repository.dart';
import 'package:doceria_pro/features/commercial/domain/business_brand_settings.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test(
    'loads default local brand settings when nothing was saved yet',
    () async {
      final repository = BusinessBrandSettingsRepository();

      final settings = await repository.load();

      expect(
        settings.displayBusinessName,
        BusinessBrandSettings.defaultBusinessName,
      );
      expect(settings.displayTagline, BusinessBrandSettings.defaultTagline);
      expect(
        settings.displayFooterMessage,
        BusinessBrandSettings.defaultFooterMessage,
      );
      expect(settings.accent, BusinessBrandAccent.rose);
    },
  );

  test('saves trimmed local commercial identity settings', () async {
    final repository = BusinessBrandSettingsRepository();

    await repository.save(
      const BusinessBrandSettings(
        businessName: '  Atelier da Ana  ',
        tagline: '  Doces finos para momentos especiais.  ',
        whatsAppPhone: ' 11999999999 ',
        instagramHandle: ' @atelierdaana ',
        footerMessage: '  Condições válidas por 3 dias.  ',
        accent: BusinessBrandAccent.sage,
      ),
    );

    final settings = await repository.load();

    expect(settings.displayBusinessName, 'Atelier da Ana');
    expect(settings.displayTagline, 'Doces finos para momentos especiais.');
    expect(settings.formattedWhatsAppPhone, '(11) 99999-9999');
    expect(settings.displayInstagramHandle, '@atelierdaana');
    expect(settings.displayFooterMessage, 'Condições válidas por 3 dias.');
    expect(settings.accent, BusinessBrandAccent.sage);
  });
}
