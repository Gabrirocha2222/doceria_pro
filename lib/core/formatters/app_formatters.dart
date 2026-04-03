import 'package:intl/intl.dart';

abstract final class AppFormatters {
  static final NumberFormat _wholeNumberFormatter = NumberFormat.decimalPattern(
    'pt_BR',
  );
  static final DateFormat _shortDateFormatter = DateFormat('dd/MM', 'pt_BR');
  static final DateFormat _longDateFormatter = DateFormat(
    "d 'de' MMMM",
    'pt_BR',
  );
  static final DateFormat _dayMonthYearFormatter = DateFormat(
    'dd/MM/yyyy',
    'pt_BR',
  );
  static final DateFormat _weekdayDateFormatter = DateFormat(
    "EEEE, d 'de' MMMM",
    'pt_BR',
  );

  static String currencyFromCents(int cents) {
    final absoluteCents = cents.abs();
    final wholeUnits = absoluteCents ~/ 100;
    final centsPart = absoluteCents % 100;
    final prefix = cents < 0 ? '-R\$ ' : 'R\$ ';
    final wholeText = _wholeNumberFormatter.format(wholeUnits);
    final centsText = centsPart.toString().padLeft(2, '0');

    return '$prefix$wholeText,$centsText';
  }

  static String currencyInputFromCents(int cents) {
    final absoluteCents = cents.abs();
    final wholeUnits = absoluteCents ~/ 100;
    final centsPart = absoluteCents % 100;
    final wholeText = _wholeNumberFormatter.format(wholeUnits);
    final centsText = centsPart.toString().padLeft(2, '0');

    return '$wholeText,$centsText';
  }

  static String shortDate(DateTime date) => _shortDateFormatter.format(date);

  static String longDate(DateTime date) => _longDateFormatter.format(date);

  static String dayMonthYear(DateTime date) =>
      _dayMonthYearFormatter.format(date);

  static String weekdayAndDate(DateTime date) =>
      _weekdayDateFormatter.format(date);

  static String wholeNumber(int value) => _wholeNumberFormatter.format(value);

  static String formatPhone(String? phone) {
    final raw = phone?.trim();
    if (raw == null || raw.isEmpty) {
      return 'Sem telefone';
    }

    final digitsOnly = raw.replaceAll(RegExp(r'[^0-9]'), '');
    if (digitsOnly.length == 11) {
      return '(${digitsOnly.substring(0, 2)}) ${digitsOnly.substring(2, 7)}-${digitsOnly.substring(7)}';
    }
    if (digitsOnly.length == 10) {
      return '(${digitsOnly.substring(0, 2)}) ${digitsOnly.substring(2, 6)}-${digitsOnly.substring(6)}';
    }

    return raw;
  }
}
