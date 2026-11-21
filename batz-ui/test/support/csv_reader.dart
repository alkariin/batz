import 'dart:convert';
import 'dart:typed_data';

/// Reads a CSV file of the export back, written independently of the code
/// that writes it: a byte order mark, then RFC 4180 with semicolons,
/// fields between quotes holding semicolons, doubled quotes and line
/// breaks, every record ended by CR LF.
List<List<String>> readCsv(Uint8List bytes) {
  if (bytes.length < 3 || bytes[0] != 0xEF || bytes[1] != 0xBB || bytes[2] != 0xBF) {
    throw const FormatException('no byte order mark');
  }
  final text = utf8.decode(bytes.sublist(3));
  final records = <List<String>>[];
  var fields = <String>[];
  final field = StringBuffer();
  var i = 0;
  var quoted = false;
  var atFieldStart = true;
  while (i < text.length) {
    final c = text[i];
    if (quoted) {
      if (c == '"') {
        if (i + 1 < text.length && text[i + 1] == '"') {
          field.write('"');
          i += 2;
          continue;
        }
        quoted = false;
        i++;
        if (i < text.length && text[i] != ';' && text[i] != '\r') {
          throw FormatException('text after a closing quote', text, i);
        }
        continue;
      }
      field.write(c);
      i++;
      continue;
    }
    if (c == '"' && atFieldStart) {
      quoted = true;
      atFieldStart = false;
      i++;
    } else if (c == ';') {
      fields.add(field.toString());
      field.clear();
      atFieldStart = true;
      i++;
    } else if (c == '\r') {
      if (i + 1 >= text.length || text[i + 1] != '\n') throw FormatException('CR without LF', text, i);
      fields.add(field.toString());
      field.clear();
      records.add(fields);
      fields = <String>[];
      atFieldStart = true;
      i += 2;
    } else if (c == '\n' || c == '"') {
      throw FormatException('a line break or a quote outside quotes', text, i);
    } else {
      field.write(c);
      atFieldStart = false;
      i++;
    }
  }
  if (quoted) throw const FormatException('unclosed quote');
  if (fields.isNotEmpty || field.isNotEmpty) throw const FormatException('last record without CR LF');
  return records;
}

/// A CSV file read back: its headers, and its rows as maps by header.
class CsvTable {
  CsvTable(Uint8List bytes) : this._(readCsv(bytes));

  CsvTable._(List<List<String>> records) : headers = records.first, rows = _rows(records);

  static List<Map<String, String>> _rows(List<List<String>> records) {
    final headers = records.first;
    return [
      for (final record in records.skip(1))
        if (record.length != headers.length)
          throw FormatException('${record.length} fields for ${headers.length} headers')
        else
          {for (var i = 0; i < headers.length; i++) headers[i]: record[i]},
    ];
  }

  final List<String> headers;
  final List<Map<String, String>> rows;

  /// The rows whose [column] is [value].
  List<Map<String, String>> where(String column, String value) => [
    for (final row in rows)
      if (row[column] == value) row,
  ];
}
