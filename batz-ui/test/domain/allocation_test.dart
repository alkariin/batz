import 'dart:math';

import 'package:batz/domain/allocation.dart';
import 'package:batz/domain/calendar_date.dart';
import 'package:batz/domain/fraction.dart';
import 'package:flutter_test/flutter_test.dart';

CalendarDate d(int year, int month, int day) => CalendarDate(year, month, day);

List<int> cents(List<MonthlyShare> shares) => [for (final s in shares) s.cents];

void main() {
  group('reference examples', () {
    test("2'100 CHF from 1.9.2026 to 31.8.2027: 700 in 2026, 1'400 in 2027", () {
      final shares = allocate(210000, d(2026, 9, 1), d(2027, 8, 31));
      expect(shares, hasLength(12));
      expect(cents(shares), List.filled(12, 17500));
      expect(shares.every((s) => s.weight == Fraction.one), isTrue);
      expect(totalsByYear(shares), {2026: 70000, 2027: 140000});
    });

    test('from 14 March to 13 March of the next year: exactly twelve months', () {
      final weights = monthWeights(d(2026, 3, 14), d(2027, 3, 13));
      expect(weights, hasLength(13));
      expect(weights.first.$2, Fraction(18, 31));
      expect(weights.last.$2, Fraction(13, 31));
      final total = weights.fold(Fraction.zero, (sum, w) => sum + w.$2);
      expect(total, Fraction(12));
      expect(total.isInteger, isTrue);

      // A whole year of 1'200.00 gives 100.00 per complete month.
      final shares = allocate(120000, d(2026, 3, 14), d(2027, 3, 13));
      expect(cents(shares).sublist(1, 12), List.filled(11, 10000));
      expect(cents(shares).reduce((a, b) => a + b), 120000);
    });
  });

  group('rules', () {
    test('a single day takes the whole amount', () {
      final shares = allocate(-4590, d(2026, 7, 14), d(2026, 7, 14));
      expect(shares, [MonthlyShare(const YearMonth(2026, 7), Fraction(1, 31), -4590)]);
    });

    test('a month only partly covered weighs its covered days over its days', () {
      // 16 to 30 April (15 of 30 days) then all of May: weights 1/2 and 1.
      final shares = allocate(30000, d(2026, 4, 16), d(2026, 5, 31));
      expect(shares.map((s) => s.weight), [Fraction(1, 2), Fraction.one]);
      expect(cents(shares), [10000, 20000]);
    });

    test('February of a leap year has 29 days', () {
      final weights = monthWeights(d(2028, 2, 1), d(2028, 2, 28));
      expect(weights.single.$2, Fraction(28, 29));
      // 15 February to 15 March 2028: 15/29 then 15/31.
      final shares = allocate(10000, d(2028, 2, 15), d(2028, 3, 15));
      expect(shares.map((s) => s.weight), [Fraction(15, 29), Fraction(15, 31)]);
      // 10000 × (15/29) / (15/29 + 15/31) = 10000 × 31/60 = 5166.67 → 5167.
      expect(cents(shares), [5167, 4833]);
      expect(monthWeights(d(2026, 2, 1), d(2026, 2, 28)).single.$2, Fraction.one);
    });

    test('1 cent over twelve months goes to the last month', () {
      final shares = allocate(1, d(2026, 1, 1), d(2026, 12, 31));
      expect(cents(shares), [...List.filled(11, 0), 1]);
    });

    test('shares are rounded to the nearest cent, the last one takes the remainder', () {
      // 100.00 over three complete months: 33.33, 33.33, 33.34.
      expect(cents(allocate(10000, d(2026, 4, 1), d(2026, 6, 30))), [3333, 3333, 3334]);
      // Halves are rounded up: 0.05 over two complete months gives 0.03, then
      // 0.02 for the last one.
      expect(cents(allocate(5, d(2026, 4, 1), d(2026, 5, 31))), [3, 2]);
    });

    test('a negative amount gives the exact opposite of the positive one', () {
      final positive = allocate(100001, d(2026, 3, 14), d(2027, 3, 13));
      final negative = allocate(-100001, d(2026, 3, 14), d(2027, 3, 13));
      expect(cents(negative), cents(positive).map((c) => -c).toList());
    });

    test('an end before the start is refused', () {
      expect(() => allocate(100, d(2026, 5, 2), d(2026, 5, 1)), throwsArgumentError);
      expect(() => monthWeights(d(2027, 1, 1), d(2026, 12, 31)), throwsArgumentError);
    });

    test('a zero amount gives zero shares', () {
      expect(cents(allocate(0, d(2026, 1, 10), d(2026, 2, 10))), [0, 0]);
    });
  });

  test('the shares add up to the amount paid, for random amounts and periods', () {
    final random = Random(20261120);
    for (var i = 0; i < 5000; i++) {
      final start = CalendarDate.of(DateTime.utc(2026, 1, 1).add(Duration(days: random.nextInt(3 * 365))));
      final end = CalendarDate.of(start.toDateTime().add(Duration(days: random.nextInt(4 * 365))));
      final magnitude = switch (random.nextInt(4)) {
        0 => random.nextInt(100),
        1 => random.nextInt(100000),
        2 => random.nextInt(1 << 31),
        _ => random.nextInt(1 << 32) * 1000,
      };
      final amount = random.nextBool() ? magnitude : -magnitude;

      final shares = allocate(amount, start, end);
      final reason = '$amount from $start to $end';
      expect(shares.fold(0, (sum, s) => sum + s.cents), amount, reason: reason);
      expect(totalsByYear(shares).values.fold(0, (a, b) => a + b), amount, reason: reason);
      expect(shares.first.month, YearMonth(start.year, start.month), reason: reason);
      expect(shares.last.month, YearMonth(end.year, end.month), reason: reason);
      // Every share but the last is the exact share rounded to the nearest
      // cent: off by half a cent at most.
      final total = shares.fold(Fraction.zero, (sum, s) => sum + s.weight);
      for (final share in shares.take(shares.length - 1)) {
        final exact = Fraction(amount) * share.weight * total.reciprocal;
        expect((Fraction(share.cents) - exact).abs.compareTo(Fraction(1, 2)), lessThanOrEqualTo(0), reason: reason);
      }
      expect(cents(allocate(-amount, start, end)), cents(shares).map((c) => -c).toList(), reason: reason);
    }
  });

  group('CalendarDate', () {
    test('is stored as YYYY-MM-DD text that sorts like the dates', () {
      expect(d(2026, 3, 4).encode(), '2026-03-04');
      expect(CalendarDate.parse('2028-02-29'), d(2028, 2, 29));
      expect(CalendarDate.tryParse('2026-02-29'), isNull);
      expect(CalendarDate.tryParse('2026-3-4'), isNull);
      expect(CalendarDate.tryParse('2026-03-04T00:00'), isNull);
      expect(CalendarDate.tryParse(null), isNull);
      expect(() => d(2026, 13, 1), throwsArgumentError);
      expect(d(2026, 12, 31).isBefore(d(2027, 1, 1)), isTrue);
      expect(d(2026, 12, 31).encode().compareTo(d(2027, 1, 1).encode()), lessThan(0));
    });

    test('ignores the time and time zone of a DateTime', () {
      expect(CalendarDate.of(DateTime(2026, 11, 20, 23, 59)), d(2026, 11, 20));
    });
  });

  group('Fraction', () {
    test('is exact and normalised', () {
      expect(Fraction(2, 4), Fraction(1, 2));
      expect(Fraction(1, -2), Fraction(-1, 2));
      expect(Fraction(1, 3) + Fraction(2, 3), Fraction.one);
      expect(Fraction(2, 3) * Fraction(3, 4), Fraction(1, 2));
      expect(Fraction(1, 2) - Fraction(3, 4), Fraction(-1, 4));
      expect(Fraction(-1, 4).abs, Fraction(1, 4));
      expect(Fraction(-2, 3).reciprocal, Fraction(-3, 2));
      expect(Fraction(1, 3).compareTo(Fraction(1, 2)), lessThan(0));
      expect(() => Fraction(1, 0), throwsArgumentError);
    });
  });
}
