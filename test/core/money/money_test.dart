import 'package:doceria_pro/core/money/money.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('money keeps arithmetic in integer cents', () {
    final total = Money.fromCents(1590) + Money.fromCents(410);

    expect(total.cents, 2000);
    expect(total.format(), 'R\$ 20,00');
  });

  test('money subtraction preserves negative values safely', () {
    final balance = Money.fromCents(500) - Money.fromCents(1200);

    expect(balance.cents, -700);
    expect(balance.format(), '-R\$ 7,00');
  });

  test('money parses formatted input without doubles', () {
    final total = Money.fromInput('1.234,56');

    expect(total.cents, 123456);
    expect(total.format(), 'R\$ 1.234,56');
    expect(total.formatInput(), '1.234,56');
  });
}
