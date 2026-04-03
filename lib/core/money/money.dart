import 'package:flutter/foundation.dart';

import '../formatters/app_formatters.dart';

@immutable
class Money implements Comparable<Money> {
  const Money._(this.cents);

  factory Money.fromCents(int cents) => Money._(cents);

  factory Money.fromInput(String rawText) {
    final digitsOnly = rawText.replaceAll(RegExp(r'[^0-9]'), '');

    if (digitsOnly.isEmpty) {
      return zero;
    }

    return Money._(int.parse(digitsOnly));
  }

  static const zero = Money._(0);

  final int cents;

  bool get isZero => cents == 0;

  bool get isPositive => cents > 0;

  bool get isNegative => cents < 0;

  String format() => AppFormatters.currencyFromCents(cents);

  String formatInput() => AppFormatters.currencyInputFromCents(cents);

  Money operator +(Money other) => Money._(cents + other.cents);

  Money operator -(Money other) => Money._(cents - other.cents);

  Money multiply(int factor) => Money._(cents * factor);

  Money divide(int divisor) {
    if (divisor <= 0) {
      return zero;
    }

    final rounded = (cents + (divisor ~/ 2)) ~/ divisor;
    return Money._(rounded);
  }

  Money multiplyRatio(int numerator, int denominator) {
    if (denominator <= 0) {
      return zero;
    }

    final rounded = (cents * numerator + (denominator ~/ 2)) ~/ denominator;
    return Money._(rounded);
  }

  @override
  int compareTo(Money other) => cents.compareTo(other.cents);

  @override
  bool operator ==(Object other) => other is Money && other.cents == cents;

  @override
  int get hashCode => cents.hashCode;

  @override
  String toString() => 'Money(cents: $cents)';
}
