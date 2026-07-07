import 'package:flutter_test/flutter_test.dart';
import 'package:kamaae/utils/currency_formatter.dart';

void main() {
  test('formatPkr uses Rs prefix and whole rupees', () {
    expect(formatPkr(1250), contains('Rs'));
    expect(formatPkr(1250), contains('1,250'));
  });

  test('pkrPrefix is Rs with trailing space', () {
    expect(pkrPrefix, 'Rs ');
  });
}
