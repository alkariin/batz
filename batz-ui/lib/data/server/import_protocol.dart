import '../../domain/calendar_date.dart';
import '../../domain/ledger/statement.dart';

/// What the server answers to `POST /api/v1/imports` (docs/api.md):
/// the fingerprint of the file and the statement it read.
class ImportResponse {
  ImportResponse({required this.fingerprint, required this.statement});

  factory ImportResponse.fromJson(Object? json) {
    final map = _map(json, 'response');
    return ImportResponse(
      fingerprint: _string(map, 'fingerprint'),
      statement: extractedStatementFromJson(map['statement']),
    );
  }

  final String fingerprint;
  final ExtractedStatement statement;
}

/// Reads the statement of an import answer; a malformed one throws a
/// [FormatException].
ExtractedStatement extractedStatementFromJson(Object? json) {
  final map = _map(json, 'statement');
  final lines = map['lines'];
  if (lines is! List) throw const FormatException('statement: lines missing');
  return ExtractedStatement(
    format: _string(map, 'format'),
    iban: _string(map, 'iban'),
    currency: _string(map, 'currency'),
    periodStart: _date(map, 'periodStart'),
    periodEnd: _date(map, 'periodEnd'),
    openingBalance: _int(map, 'openingBalance'),
    closingBalance: _int(map, 'closingBalance'),
    totalCredits: _int(map, 'totalCredits'),
    totalDebits: _int(map, 'totalDebits'),
    lines: [
      for (final line in lines)
        () {
          final m = _map(line, 'line');
          final balance = m['balance'];
          if (balance != null && balance is! int) throw const FormatException('line: balance is not an integer');
          return ExtractedLine(
            date: _date(m, 'date'),
            amount: _int(m, 'amount'),
            rawText: _string(m, 'rawText'),
            label: _string(m, 'label'),
            balance: balance as int?,
          );
        }(),
    ],
  );
}

Map<String, Object?> _map(Object? json, String what) {
  if (json is! Map<String, Object?>) throw FormatException('$what is not an object');
  return json;
}

String _string(Map<String, Object?> map, String key) {
  final value = map[key];
  if (value is! String) throw FormatException('$key is not a string');
  return value;
}

int _int(Map<String, Object?> map, String key) {
  final value = map[key];
  if (value is! int) throw FormatException('$key is not an integer');
  return value;
}

CalendarDate _date(Map<String, Object?> map, String key) {
  final date = CalendarDate.tryParse(map[key] is String ? map[key]! as String : null);
  if (date == null) throw FormatException('$key is not a date');
  return date;
}
