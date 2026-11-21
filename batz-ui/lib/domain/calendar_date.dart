/// A calendar date: a day, with neither time nor time zone. Stored as
/// `YYYY-MM-DD` text, whose order is the date order.
class CalendarDate implements Comparable<CalendarDate> {
  /// Throws an [ArgumentError] for an impossible date such as 31.2.2026.
  CalendarDate(this.year, this.month, this.day) {
    if (year < 1 || year > 9999) throw ArgumentError.value(year, 'year');
    if (month < 1 || month > 12) throw ArgumentError.value(month, 'month');
    if (day < 1 || day > daysInMonth(year, month)) throw ArgumentError.value(day, 'day');
  }

  /// The calendar date of [dateTime] in its own time zone.
  factory CalendarDate.of(DateTime dateTime) => CalendarDate(dateTime.year, dateTime.month, dateTime.day);

  /// Today, on this device's calendar.
  factory CalendarDate.today() => CalendarDate.of(DateTime.now());

  /// Parses `YYYY-MM-DD`; throws a [FormatException] otherwise.
  factory CalendarDate.parse(String text) {
    final date = tryParse(text);
    if (date == null) throw FormatException('Invalid calendar date', text);
    return date;
  }

  /// Parses `YYYY-MM-DD`, or returns null for anything else.
  static CalendarDate? tryParse(String? text) {
    if (text == null) return null;
    final match = _pattern.firstMatch(text);
    if (match == null) return null;
    final year = int.parse(match.group(1)!), month = int.parse(match.group(2)!), day = int.parse(match.group(3)!);
    if (year < 1 || month < 1 || month > 12 || day < 1 || day > daysInMonth(year, month)) return null;
    return CalendarDate(year, month, day);
  }

  static final _pattern = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$');

  final int year;
  final int month;
  final int day;

  static bool isLeapYear(int year) => year % 4 == 0 && (year % 100 != 0 || year % 400 == 0);

  static int daysInMonth(int year, int month) => switch (month) {
    2 => isLeapYear(year) ? 29 : 28,
    4 || 6 || 9 || 11 => 30,
    _ => 31,
  };

  /// `YYYY-MM-DD`.
  String encode() =>
      '${year.toString().padLeft(4, '0')}-${month.toString().padLeft(2, '0')}-${day.toString().padLeft(2, '0')}';

  /// Midnight UTC of this day, for date pickers and formatting.
  DateTime toDateTime() => DateTime.utc(year, month, day);

  /// The date [days] days later (earlier when negative).
  CalendarDate addDays(int days) => CalendarDate.of(toDateTime().add(Duration(days: days)));

  bool isBefore(CalendarDate other) => compareTo(other) < 0;
  bool isAfter(CalendarDate other) => compareTo(other) > 0;

  @override
  int compareTo(CalendarDate other) {
    if (year != other.year) return year.compareTo(other.year);
    if (month != other.month) return month.compareTo(other.month);
    return day.compareTo(other.day);
  }

  @override
  bool operator ==(Object other) => other is CalendarDate && compareTo(other) == 0;

  @override
  int get hashCode => Object.hash(year, month, day);

  @override
  String toString() => encode();
}
