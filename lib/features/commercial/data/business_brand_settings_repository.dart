import 'package:shared_preferences/shared_preferences.dart';

import '../domain/business_brand_settings.dart';

class BusinessBrandSettingsRepository {
  static const _businessNameKey = 'commercial.business_name';
  static const _taglineKey = 'commercial.tagline';
  static const _whatsAppPhoneKey = 'commercial.whatsapp_phone';
  static const _instagramHandleKey = 'commercial.instagram_handle';
  static const _footerMessageKey = 'commercial.footer_message';
  static const _accentKey = 'commercial.accent';

  Future<BusinessBrandSettings> load() async {
    final preferences = await SharedPreferences.getInstance();

    return BusinessBrandSettings(
      businessName:
          preferences.getString(_businessNameKey) ??
          BusinessBrandSettings.defaults.businessName,
      tagline:
          preferences.getString(_taglineKey) ??
          BusinessBrandSettings.defaults.tagline,
      whatsAppPhone: preferences.getString(_whatsAppPhoneKey) ?? '',
      instagramHandle: preferences.getString(_instagramHandleKey) ?? '',
      footerMessage:
          preferences.getString(_footerMessageKey) ??
          BusinessBrandSettings.defaults.footerMessage,
      accent: BusinessBrandAccent.fromStorage(
        preferences.getString(_accentKey),
      ),
    );
  }

  Future<void> save(BusinessBrandSettings settings) async {
    final preferences = await SharedPreferences.getInstance();

    await preferences.setString(_businessNameKey, settings.businessName.trim());
    await preferences.setString(_taglineKey, settings.tagline.trim());
    await _writeOptionalString(
      preferences,
      key: _whatsAppPhoneKey,
      value: settings.whatsAppPhone,
    );
    await _writeOptionalString(
      preferences,
      key: _instagramHandleKey,
      value: settings.instagramHandle,
    );
    await preferences.setString(
      _footerMessageKey,
      settings.footerMessage.trim(),
    );
    await preferences.setString(_accentKey, settings.accent.storageValue);
  }

  Future<void> _writeOptionalString(
    SharedPreferences preferences, {
    required String key,
    required String value,
  }) async {
    final trimmed = value.trim();
    if (trimmed.isEmpty) {
      await preferences.remove(key);
      return;
    }

    await preferences.setString(key, trimmed);
  }
}
