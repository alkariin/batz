/// Swiss formats for amounts and dates: `1'234.50` and `31.12.2026`.
///
/// Amounts are always integer cents: these functions never go through
/// floating point.
library;

const _thousandsSeparator = "'";

/// Formats [cents] as `1'234.50`, with a leading `-` when negative and, if
/// [explicitPlus] is set, a leading `+` when positive.
String formatAmount(int cents, {bool explicitPlus = false}) {
  final negative = cents < 0;
  // Work on the magnitude as a string to also handle the smallest int.
  final digits = cents.toString().replaceFirst('-', '').padLeft(3, '0');
  final whole = digits.substring(0, digits.length - 2);
  final fraction = digits.substring(digits.length - 2);

  final grouped = StringBuffer();
  for (var i = 0; i < whole.length; i++) {
    if (i > 0 && (whole.length - i) % 3 == 0) grouped.write(_thousandsSeparator);
    grouped.write(whole[i]);
  }
  final sign = negative ? '-' : (explicitPlus && cents > 0 ? '+' : '');
  return '$sign$grouped.$fraction';
}

final _amountPattern = RegExp(r'^([+-])?(\d+)(?:[.,](\d{1,2}))?$');

/// Parses an amount typed by the user into cents, or returns null.
///
/// Accepts `1'234.50`, `1’234.5`, `1 234,50`, `-12`, `+3.05`: apostrophes and
/// spaces group thousands, a dot or a comma separates at most two decimals.
int? parseAmount(String input) {
  final compact = input.trim().replaceAll(RegExp(r"['’\s  ]"), '');
  final match = _amountPattern.firstMatch(compact);
  if (match == null) return null;
  final whole = BigInt.parse(match.group(2)!);
  final fraction = int.parse((match.group(3) ?? '0').padRight(2, '0'));
  final cents = whole * BigInt.from(100) + BigInt.from(fraction);
  if (!cents.isValidInt) return null;
  return match.group(1) == '-' ? -cents.toInt() : cents.toInt();
}

/// Formats a calendar date as `31.12.2026`. The time of day is ignored.
String formatDate(DateTime date) {
  String two(int v) => v.toString().padLeft(2, '0');
  return '${two(date.day)}.${two(date.month)}.${date.year.toString().padLeft(4, '0')}';
}

/// Formats the time of day of [date] as `21:04`.
String formatTime(DateTime date) => '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';

final _datePattern = RegExp(r'^(\d{1,2})\.(\d{1,2})\.(\d{4})$');

/// Parses `31.12.2026` (or `1.2.2026`) into a date at midnight UTC, or
/// returns null for anything else, including impossible dates such as
/// `31.02.2026`.
DateTime? parseDate(String input) {
  final match = _datePattern.firstMatch(input.trim());
  if (match == null) return null;
  final day = int.parse(match.group(1)!);
  final month = int.parse(match.group(2)!);
  final year = int.parse(match.group(3)!);
  final date = DateTime.utc(year, month, day);
  if (date.year != year || date.month != month || date.day != day) return null;
  return date;
}

/// Formats a percentage in hundredths of a percent as `10 %`, `33.33 %` or
/// `0.5 %`.
String formatPercent(int basisPoints) {
  final whole = basisPoints ~/ 100, hundredths = basisPoints.abs() % 100;
  final fraction = hundredths == 0 ? '' : '.${hundredths.toString().padLeft(2, '0').replaceFirst(RegExp(r'0$'), '')}';
  return '${basisPoints < 0 && whole == 0 ? '-' : ''}$whole$fraction %';
}

final _percentPattern = RegExp(r'^(\d{1,3})(?:[.,](\d{1,2}))?$');

/// Parses a percentage typed by the user (`10`, `33.33`, `0,5`, with or
/// without `%`) into hundredths of a percent, or returns null; at most two
/// decimals.
int? parsePercent(String input) {
  final match = _percentPattern.firstMatch(input.trim().replaceFirst(RegExp(r'\s*%$'), ''));
  if (match == null) return null;
  return int.parse(match.group(1)!) * 100 + int.parse((match.group(2) ?? '0').padRight(2, '0'));
}

/// Formats [value], a number of 10^-[decimals] percent, with exactly
/// [decimals] decimals: `2.5000 %` (25000, 4), `155.00 %` (15500, 2).
String formatScaledPercent(int value, int decimals) {
  final digits = value.abs().toString().padLeft(decimals + 1, '0');
  final whole = digits.substring(0, digits.length - decimals);
  final fraction = digits.substring(digits.length - decimals);
  return '${value < 0 ? '-' : ''}$whole${decimals == 0 ? '' : '.$fraction'} %';
}

/// Parses a positive number typed with at most [decimals] decimals (`6.5`,
/// `155`, `0,25`, with or without `%`) into units of 10^-[decimals], or
/// returns null.
int? parseScaled(String input, int decimals) {
  final match = RegExp(
    r'^(\d{1,9})(?:[.,](\d{1,'
    '$decimals'
    r'}))?$',
  ).firstMatch(input.trim().replaceFirst(RegExp(r'\s*%$'), '').replaceAll(RegExp(r"['’ ]"), ''));
  if (match == null) return null;
  var value = int.parse(match.group(1)!);
  for (var i = 0; i < decimals; i++) {
    value *= 10;
  }
  return value + int.parse((match.group(2) ?? '0').padRight(decimals, '0'));
}

/// Formats [value], a number of 10^-[decimals], with thousands separators:
/// `4'700` (4700000, 3, trimmed), `0.2596` (2596, 4), `12.88` (1288, 2).
/// With [trim], decimals that are zero are left out.
String formatDecimal(int value, int decimals, {bool trim = false}) {
  final digits = value.abs().toString().padLeft(decimals + 1, '0');
  final whole = digits.substring(0, digits.length - decimals);
  var fraction = digits.substring(digits.length - decimals);
  if (trim) fraction = fraction.replaceFirst(RegExp(r'0+$'), '');
  final grouped = StringBuffer();
  for (var i = 0; i < whole.length; i++) {
    if (i > 0 && (whole.length - i) % 3 == 0) grouped.write(_thousandsSeparator);
    grouped.write(whole[i]);
  }
  return '${value < 0 ? '-' : ''}$grouped${fraction.isEmpty ? '' : '.$fraction'}';
}
