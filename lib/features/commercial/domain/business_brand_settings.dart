import '../../../core/formatters/app_formatters.dart';

enum BusinessBrandAccent {
  rose(
    storageValue: 'rose',
    label: 'Rosa clássico',
    primaryColorValue: 0xFF7B5262,
    softColorValue: 0xFFF4E2E9,
    strongColorValue: 0xFF4E2E3A,
  ),
  terracotta(
    storageValue: 'terracotta',
    label: 'Terracota elegante',
    primaryColorValue: 0xFF9B5E4C,
    softColorValue: 0xFFF6E1D7,
    strongColorValue: 0xFF5F372C,
  ),
  sage(
    storageValue: 'sage',
    label: 'Verde delicado',
    primaryColorValue: 0xFF5F7467,
    softColorValue: 0xFFDCE8DF,
    strongColorValue: 0xFF314239,
  ),
  cocoa(
    storageValue: 'cocoa',
    label: 'Cacau refinado',
    primaryColorValue: 0xFF6F564A,
    softColorValue: 0xFFE9DDD6,
    strongColorValue: 0xFF433129,
  );

  const BusinessBrandAccent({
    required this.storageValue,
    required this.label,
    required this.primaryColorValue,
    required this.softColorValue,
    required this.strongColorValue,
  });

  final String storageValue;
  final String label;
  final int primaryColorValue;
  final int softColorValue;
  final int strongColorValue;

  static BusinessBrandAccent fromStorage(String? value) {
    return values.firstWhere(
      (accent) => accent.storageValue == value,
      orElse: () => BusinessBrandAccent.rose,
    );
  }
}

class BusinessBrandSettings {
  const BusinessBrandSettings({
    required this.businessName,
    required this.tagline,
    required this.whatsAppPhone,
    required this.instagramHandle,
    required this.footerMessage,
    required this.accent,
  });

  static const defaultBusinessName = 'Minha doceria';
  static const defaultTagline = 'Orçamentos claros com um toque delicado.';
  static const defaultFooterMessage =
      'Valores e disponibilidade sujeitos à confirmação no momento do pedido.';
  static const defaults = BusinessBrandSettings(
    businessName: defaultBusinessName,
    tagline: defaultTagline,
    whatsAppPhone: '',
    instagramHandle: '',
    footerMessage: defaultFooterMessage,
    accent: BusinessBrandAccent.rose,
  );

  final String businessName;
  final String tagline;
  final String whatsAppPhone;
  final String instagramHandle;
  final String footerMessage;
  final BusinessBrandAccent accent;

  BusinessBrandSettings copyWith({
    String? businessName,
    String? tagline,
    String? whatsAppPhone,
    String? instagramHandle,
    String? footerMessage,
    BusinessBrandAccent? accent,
  }) {
    return BusinessBrandSettings(
      businessName: businessName ?? this.businessName,
      tagline: tagline ?? this.tagline,
      whatsAppPhone: whatsAppPhone ?? this.whatsAppPhone,
      instagramHandle: instagramHandle ?? this.instagramHandle,
      footerMessage: footerMessage ?? this.footerMessage,
      accent: accent ?? this.accent,
    );
  }

  String get displayBusinessName {
    final trimmed = businessName.trim();
    if (trimmed.isEmpty) {
      return defaultBusinessName;
    }

    return trimmed;
  }

  String get displayTagline {
    final trimmed = tagline.trim();
    if (trimmed.isEmpty) {
      return defaultTagline;
    }

    return trimmed;
  }

  String get displayFooterMessage {
    final trimmed = footerMessage.trim();
    if (trimmed.isEmpty) {
      return defaultFooterMessage;
    }

    return trimmed;
  }

  String? get trimmedWhatsAppPhone {
    final trimmed = whatsAppPhone.trim();
    if (trimmed.isEmpty) {
      return null;
    }

    return trimmed;
  }

  String? get formattedWhatsAppPhone {
    final trimmed = trimmedWhatsAppPhone;
    if (trimmed == null) {
      return null;
    }

    return AppFormatters.formatPhone(trimmed);
  }

  String? get normalizedInstagramHandle {
    final trimmed = instagramHandle.trim();
    if (trimmed.isEmpty) {
      return null;
    }

    final withoutPrefix = trimmed.startsWith('@')
        ? trimmed.substring(1)
        : trimmed;
    final normalized = withoutPrefix.trim();

    if (normalized.isEmpty) {
      return null;
    }

    return normalized;
  }

  String? get displayInstagramHandle {
    final normalized = normalizedInstagramHandle;
    if (normalized == null) {
      return null;
    }

    return '@$normalized';
  }

  bool get hasCommercialContact =>
      formattedWhatsAppPhone != null || displayInstagramHandle != null;

  List<String> get contactLines {
    return [
      if (formattedWhatsAppPhone != null)
        'WhatsApp: ${formattedWhatsAppPhone!}',
      if (displayInstagramHandle != null)
        'Instagram: ${displayInstagramHandle!}',
    ];
  }
}
