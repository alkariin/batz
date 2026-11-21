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

  group('scaled percentages (phase 6)', () {
    test('format with a fixed number of decimals', () {
      expect(formatScaledPercent(25000, 4), '2.5000 %');
      expect(formatScaledPercent(100750, 4), '10.0750 %');
      expect(formatScaledPercent(3875, 4), '0.3875 %');
      expect(formatScaledPercent(15500, 2), '155.00 %');
      expect(formatScaledPercent(1566, 2), '15.66 %');
      expect(formatScaledPercent(5, 2), '0.05 %');
    });

    test('parse at most the decimals allowed', () {
      expect(parseScaled('2.5', 4), 25000);
      expect(parseScaled('6,5 %', 4), 65000);
      expect(parseScaled('0.0001', 4), 1);
      expect(parseScaled('0.00001', 4), isNull);
      expect(parseScaled('155', 2), 15500);
      expect(parseScaled('79.5', 2), 7950);
      expect(parseScaled('-3', 2), isNull);
      expect(parseScaled('abc', 2), isNull);
      expect(parseScaled("4'700", 3), 4700000, reason: 'kWh in Wh');
    });

    test('decimals with thousands separators', () {
      expect(formatDecimal(4700000, 3, trim: true), "4'700");
      expect(formatDecimal(1234567, 3, trim: true), "1'234.567");
      expect(formatDecimal(2596, 4), '0.2596');
      expect(formatDecimal(2500, 4), '0.2500');
      expect(formatDecimal(1288, 2), '12.88');
    });
  });
}
