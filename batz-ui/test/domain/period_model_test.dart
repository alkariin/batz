import 'package:batz/domain/allocation.dart';
import 'package:batz/domain/calendar_date.dart';
import 'package:batz/domain/fraction.dart';
import 'package:batz/domain/period_model.dart';
import 'package:flutter_test/flutter_test.dart';

CalendarDate d(int y, int m, int day) => CalendarDate(y, m, day);

String period(PeriodModel? model, CalendarDate payment, {int? months}) {
  final (start, end) = periodFor(model, payment, months: months);
  String f(CalendarDate c) => '${c.day}.${c.month}.${c.year}';
  return '${f(start)} – ${f(end)}';
}

void main() {
  // The table of decision H6, for a payment on 14 March 2026.
  group('decision H6, payment on 14.3.2026', () {
    final payment = d(2026, 3, 14);
    test('without model: the payment date', () => expect(period(null, payment), '14.3.2026 – 14.3.2026'));
    test('previous month', () => expect(period(PeriodModel.previousMonth, payment), '1.2.2026 – 28.2.2026'));
    test('next month', () => expect(period(PeriodModel.nextMonth, payment), '1.4.2026 – 30.4.2026'));
    test('12 months after the payment', () {
      expect(period(PeriodModel.monthsAfter, payment, months: 12), '14.3.2026 – 13.3.2027');
    });
    test('3 months before the payment', () {
      expect(period(PeriodModel.monthsBefore, payment, months: 3), '14.12.2025 – 13.3.2026');
    });
    test('current calendar year', () => expect(period(PeriodModel.currentYear, payment), '1.1.2026 – 31.12.2026'));
    test('previous calendar year', () => expect(period(PeriodModel.previousYear, payment), '1.1.2025 – 31.12.2025'));
  });

  group('ends of months and of years', () {
    test('the month before January is December of the year before', () {
      expect(period(PeriodModel.previousMonth, d(2026, 1, 31)), '1.12.2025 – 31.12.2025');
    });
    test('the month after December is January of the year after', () {
      expect(period(PeriodModel.nextMonth, d(2026, 12, 1)), '1.1.2027 – 31.1.2027');
    });
    test('the month after a 31 January is February, whole', () {
      expect(period(PeriodModel.nextMonth, d(2026, 1, 31)), '1.2.2026 – 28.2.2026');
    });
    test('N months after a 31st end the day before the same day N months later, clamped', () {
      expect(period(PeriodModel.monthsAfter, d(2026, 1, 31), months: 1), '31.1.2026 – 27.2.2026');
      expect(period(PeriodModel.monthsAfter, d(2026, 3, 31), months: 1), '31.3.2026 – 29.4.2026');
      expect(period(PeriodModel.monthsAfter, d(2026, 8, 31), months: 6), '31.8.2026 – 27.2.2027');
    });
    test('N months before a 31st start on the same day N months earlier, clamped', () {
      expect(period(PeriodModel.monthsBefore, d(2026, 5, 31), months: 3), '28.2.2026 – 30.5.2026');
      expect(period(PeriodModel.monthsBefore, d(2026, 3, 1), months: 1), '1.2.2026 – 28.2.2026');
    });
    test('across years', () {
      expect(period(PeriodModel.monthsAfter, d(2026, 11, 15), months: 3), '15.11.2026 – 14.2.2027');
      expect(period(PeriodModel.monthsBefore, d(2026, 1, 1), months: 1), '1.12.2025 – 31.12.2025');
    });
  });

  group('leap years', () {
    test('the month before March of a leap year ends on 29 February', () {
      expect(period(PeriodModel.previousMonth, d(2028, 3, 14)), '1.2.2028 – 29.2.2028');
    });
    test('the month after January of a leap year', () {
      expect(period(PeriodModel.nextMonth, d(2028, 1, 31)), '1.2.2028 – 29.2.2028');
    });
    test('12 months from 29 February end on 27 February of the next year (28 February clamped, minus a day)', () {
      expect(period(PeriodModel.monthsAfter, d(2028, 2, 29), months: 12), '29.2.2028 – 27.2.2029');
    });
    test('12 months from 1 March of the year before a leap year include 29 February', () {
      expect(period(PeriodModel.monthsAfter, d(2027, 3, 1), months: 12), '1.3.2027 – 29.2.2028');
    });
    test('1 month after 31 January of a leap year ends on 28 February', () {
      expect(period(PeriodModel.monthsAfter, d(2028, 1, 31), months: 1), '31.1.2028 – 28.2.2028');
    });
    test('the year of a payment of 29 February', () {
      expect(period(PeriodModel.currentYear, d(2028, 2, 29)), '1.1.2028 – 31.12.2028');
      expect(period(PeriodModel.previousYear, d(2028, 2, 29)), '1.1.2027 – 31.12.2027');
    });
  });

  test('12 months after the payment weigh exactly twelve months, in a leap year too', () {
    for (final payment in [d(2026, 3, 14), d(2027, 3, 1), d(2028, 1, 10)]) {
      final (start, end) = periodFor(PeriodModel.monthsAfter, payment, months: 12);
      final weights = monthWeights(start, end);
      expect(weights.fold(Fraction.zero, (a, w) => a + w.$2), Fraction(12), reason: '$payment');
    }
  });

  test('a number of months is required, from 1 to 120', () {
    for (final months in [null, 0, 121]) {
      expect(() => periodFor(PeriodModel.monthsAfter, d(2026, 3, 14), months: months), throwsArgumentError);
    }
    expect(PeriodModel.monthsAfter.takesMonths && PeriodModel.monthsBefore.takesMonths, isTrue);
    expect(PeriodModel.values.where((m) => m.takesMonths), hasLength(2));
  });

  test('adding months clamps the day', () {
    expect(addMonths(d(2026, 1, 31), 1), d(2026, 2, 28));
    expect(addMonths(d(2026, 1, 31), -2), d(2025, 11, 30));
    expect(addMonths(d(2026, 12, 15), 1), d(2027, 1, 15));
    expect(addMonths(d(2026, 1, 15), -13), d(2024, 12, 15));
  });
}
