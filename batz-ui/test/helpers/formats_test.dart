import 'package:batz/helpers/formats.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('formatAmount', () {
    test('groups thousands with an apostrophe and keeps two decimals', () {
      expect(formatAmount(123450), "1'234.50");
      expect(formatAmount(210000), "2'100.00");
      expect(formatAmount(123456789012), "1'234'567'890.12");
      expect(formatAmount(99999), '999.99');
      expect(formatAmount(100000), "1'000.00");
    });

    test('small amounts', () {
      expect(formatAmount(0), '0.00');
      expect(formatAmount(5), '0.05');
      expect(formatAmount(50), '0.50');
      expect(formatAmount(100), '1.00');
    });

    test('negative amounts', () {
      expect(formatAmount(-5), '-0.05');
      expect(formatAmount(-123450), "-1'234.50");
    });

    test('explicit plus sign', () {
      expect(formatAmount(123450, explicitPlus: true), "+1'234.50");
      expect(formatAmount(0, explicitPlus: true), '0.00');
      expect(formatAmount(-1, explicitPlus: true), '-0.01');
    });

    test('extreme values', () {
      // -2^63 has no positive counterpart in int.
      expect(formatAmount(-9223372036854775808), "-92'233'720'368'547'758.08");
      expect(formatAmount(9223372036854775807), "92'233'720'368'547'758.07");
    });
  });

  group('parseAmount', () {
    test('Swiss and loose inputs', () {
      expect(parseAmount("1'234.50"), 123450);
      expect(parseAmount('1’234.50'), 123450);
      expect(parseAmount('1 234,50'), 123450);
      expect(parseAmount('1234.5'), 123450);
      expect(parseAmount('1234'), 123400);
      expect(parseAmount('  -12.30 '), -1230);
      expect(parseAmount('+3.05'), 305);
      expect(parseAmount('0.01'), 1);
      expect(parseAmount('-0'), 0);
    });

    test('round trip', () {
      for (final cents in [0, 1, -1, 99, 100, 123450, -987654321]) {
        expect(parseAmount(formatAmount(cents)), cents);
      }
    });

    test('rejects malformed input', () {
      for (final input in ['', ' ', 'abc', '1.234', '12.', '.5', '1..2', '1.2.3', '--1', '1-', '12a', '1e3']) {
        expect(parseAmount(input), isNull, reason: input);
      }
    });

    test('rejects amounts beyond int', () {
      expect(parseAmount('92233720368547758.08'), isNull);
      expect(parseAmount('92233720368547758.07'), 9223372036854775807);
    });
  });

  group('formatDate', () {
    test('day.month.year with leading zeros', () {
      expect(formatDate(DateTime(2026, 12, 31)), '31.12.2026');
      expect(formatDate(DateTime(2026, 1, 5)), '05.01.2026');
      expect(formatDate(DateTime.utc(2027, 3, 14, 23, 59)), '14.03.2027');
    });
  });

  group('parseDate', () {
    test('valid dates', () {
      expect(parseDate('31.12.2026'), DateTime.utc(2026, 12, 31));
      expect(parseDate('1.2.2026'), DateTime.utc(2026, 2, 1));
      expect(parseDate(' 29.02.2028 '), DateTime.utc(2028, 2, 29));
    });

    test('impossible or malformed dates', () {
      for (final input in [
        '31.02.2026',
        '29.02.2026',
        '00.01.2026',
        '32.01.2026',
        '01.13.2026',
        '2026-12-31',
        '31.12.26',
        '',
        '31/12/2026',
      ]) {
        expect(parseDate(input), isNull, reason: input);
      }
    });

    test('round trip', () {
      final date = DateTime.utc(2026, 9, 1);
      expect(parseDate(formatDate(date)), date);
    });
  });
}
