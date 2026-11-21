import 'calendar_date.dart';

/// How a mapping rule sets the period a payment concerns (specification,
/// 4.5; meanings of decision H6 of phase 3). Without a model, the period is
/// the payment date.
enum PeriodModel {
  /// The calendar month before the month of the payment.
  previousMonth,

  /// The calendar month after the month of the payment.
  nextMonth,

  /// N months from the day of the payment: 14.3.2026, N = 12 gives
  /// 14.3.2026 – 13.3.2027.
  monthsAfter,

  /// N months that end the day before the payment: 14.3.2026, N = 3 gives
  /// 14.12.2025 – 13.3.2026.
  monthsBefore,

  /// 1 January to 31 December of the year of the payment.
  currentYear,

  /// The year before.
  previousYear;

  /// Whether the model takes a number of months.
  bool get takesMonths => this == monthsAfter || this == monthsBefore;
}

/// The longest period a model may cover, in months.
const maxPeriodMonths = 120;

/// The period of a payment on [payment] under [model] (and [months] for the
/// models that take it).
///
/// Month arithmetic clamps to the end of the month: one month after 31
/// January is 28 (or 29) February. So `monthsAfter` ends the day before the
/// same day N months later, clamped (31.1.2026, N = 1: 31.1 – 27.2.2026), and
/// `monthsBefore` starts on the same day N months earlier, clamped
/// (31.5.2026, N = 3: 28.2 – 30.5.2026).
(CalendarDate, CalendarDate) periodFor(PeriodModel? model, CalendarDate payment, {int? months}) {
  CalendarDate monthStart(int year, int month) {
    final (y, m) = _normalise(year, month);
    return CalendarDate(y, m, 1);
  }

  CalendarDate monthEnd(int year, int month) {
    final (y, m) = _normalise(year, month);
    return CalendarDate(y, m, CalendarDate.daysInMonth(y, m));
  }

  final y = payment.year, m = payment.month;
  switch (model) {
    case null:
      return (payment, payment);
    case PeriodModel.previousMonth:
      return (monthStart(y, m - 1), monthEnd(y, m - 1));
    case PeriodModel.nextMonth:
      return (monthStart(y, m + 1), monthEnd(y, m + 1));
    case PeriodModel.monthsAfter:
      return (payment, addMonths(payment, _months(months)).addDays(-1));
    case PeriodModel.monthsBefore:
      return (addMonths(payment, -_months(months)), payment.addDays(-1));
    case PeriodModel.currentYear:
      return (CalendarDate(y, 1, 1), CalendarDate(y, 12, 31));
    case PeriodModel.previousYear:
      return (CalendarDate(y - 1, 1, 1), CalendarDate(y - 1, 12, 31));
  }
}

int _months(int? months) {
  if (months == null || months < 1 || months > maxPeriodMonths) throw ArgumentError.value(months, 'months');
  return months;
}

/// [date] moved by [months] months, its day clamped to the end of the month.
CalendarDate addMonths(CalendarDate date, int months) {
  final (y, m) = _normalise(date.year, date.month + months);
  final day = date.day.clamp(1, CalendarDate.daysInMonth(y, m));
  return CalendarDate(y, m, day);
}

(int, int) _normalise(int year, int month) {
  final index = year * 12 + (month - 1);
  return (index ~/ 12, index % 12 + 1);
}
