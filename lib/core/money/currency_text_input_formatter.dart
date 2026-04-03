import 'package:flutter/services.dart';

import '../formatters/app_formatters.dart';

class CurrencyTextInputFormatter extends TextInputFormatter {
  const CurrencyTextInputFormatter();

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final digitsOnly = newValue.text.replaceAll(RegExp(r'[^0-9]'), '');

    if (digitsOnly.isEmpty) {
      return const TextEditingValue();
    }

    final cents = int.parse(digitsOnly);
    final formatted = AppFormatters.currencyInputFromCents(cents);

    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}
