/// Spreading a payment over the months of the period it concerns
/// (specification, 4.2, "Répartition").
library;

import 'calendar_date.dart';
import 'fraction.dart';

/// A month, as a year and a month number.
class YearMonth implements Comparable<YearMonth> {
  const YearMonth(this.year, this.month);

  final int year;
  final int month;

  int get days => CalendarDate.daysInMonth(year, month);

  YearMonth get next => month == 12 ? YearMonth(year + 1, 1) : YearMonth(year, month + 1);

  @override
  int compareTo(YearMonth other) => year != other.year ? year.compareTo(other.year) : month.compareTo(other.month);

  @override
  bool operator ==(Object other) => other is YearMonth && other.year == year && other.month == month;

  @override
  int get hashCode => Object.hash(year, month);

  @override
  String toString() => '$year-${month.toString().padLeft(2, '0')}';
}

/// The part of an amount that falls in one month.
class MonthlyShare {
  const MonthlyShare(this.month, this.weight, this.cents);

  final YearMonth month;

  /// Days of the month covered by the period, divided by the days of the
  /// month: 1 for a complete month.
  final Fraction weight;

  /// The share, in cents.
  final int cents;

  @override
  bool operator ==(Object other) =>
      other is MonthlyShare && other.month == month && other.weight == weight && other.cents == cents;

  @override
  int get hashCode => Object.hash(month, weight, cents);

  @override
  String toString() => '$month: $cents ($weight)';
}

/// The weight of every month of the period from [start] to [end], both
/// included: 1 for a complete month, the covered days divided by the days of
/// the month for a month only partly covered.
List<(YearMonth, Fraction)> monthWeights(CalendarDate start, CalendarDate end) {
  if (end.isBefore(start)) throw ArgumentError('The period ends ($end) before it starts ($start)');
  final weights = <(YearMonth, Fraction)>[];
  final last = YearMonth(end.year, end.month);
  for (var month = YearMonth(start.year, start.month); month.compareTo(last) <= 0; month = month.next) {
    final firstDay = month == YearMonth(start.year, start.month) ? start.day : 1;
    final lastDay = month == last ? end.day : month.days;
    weights.add((month, Fraction(lastDay - firstDay + 1, month.days)));
  }
  return weights;
}

/// Splits [cents] over the months of the period from [start] to [end], both
/// included, in proportion to the weight of each month.
///
/// Each share is rounded to the nearest cent (halves away from zero) and the
/// last month receives what remains, so the shares always add up to [cents].
/// A negative amount gives exactly the opposite of the shares of the positive
/// amount. Throws an [ArgumentError] if [end] is before [start].
List<MonthlyShare> allocate(int cents, CalendarDate start, CalendarDate end) {
  final weights = monthWeights(start, end);
  if (cents < 0) {
    return [for (final share in allocate(-cents, start, end)) MonthlyShare(share.month, share.weight, -share.cents)];
  }
  final total = weights.fold(Fraction.zero, (sum, w) => sum + w.$2);
  final amount = BigInt.from(cents);
  final shares = <MonthlyShare>[];
  var allocated = 0;
  for (var i = 0; i < weights.length; i++) {
    final (month, weight) = weights[i];
    final int share;
    if (i == weights.length - 1) {
      share = cents - allocated;
    } else {
      // amount × weight ÷ total, rounded half up: amount is not negative here.
      final numerator = amount * weight.numerator * total.denominator;
      final denominator = weight.denominator * total.numerator;
      share = ((numerator * BigInt.two + denominator) ~/ (denominator * BigInt.two)).toInt();
    }
    allocated += share;
    shares.add(MonthlyShare(month, weight, share));
  }
  return shares;
}

/// The sum of [shares] per calendar year, years in increasing order.
Map<int, int> totalsByYear(Iterable<MonthlyShare> shares) {
  final totals = <int, int>{};
  for (final share in shares) {
    totals[share.month.year] = (totals[share.month.year] ?? 0) + share.cents;
  }
  return Map.fromEntries(totals.entries.toList()..sort((a, b) => a.key.compareTo(b.key)));
}
