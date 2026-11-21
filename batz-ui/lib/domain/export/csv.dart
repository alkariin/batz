/// The CSV format of the export (decision H2 of phase 7): UTF-8 with a byte
/// order mark, semicolons, CR LF, values written from integers (principle 4).
library;

import 'dart:convert';
import 'dart:typed_data';

import '../calendar_date.dart';

/// A value of a cell, written by [csvCell]. Null is an empty cell.
sealed class Cell {
  const Cell();
}

/// Text entered by the user or read from the bank: one that starts with
/// `=`, `+`, `-` or `@` gets an apostrophe in front, so that a spreadsheet
/// does not take it for a formula.
final class TextCell extends Cell {
  const TextCell(this.text);
  final String text;
}

/// Text written by the app (a label, a path, an identifier): as it is.
final class PlainCell extends Cell {
  const PlainCell(this.text);
  final String text;
}

/// An amount in cents: `1234.50`, `-85.00`, `0.00`.
final class AmountCell extends Cell {
  const AmountCell(this.cents);
  final int cents;
}

/// A percentage in hundredths of a percent: `50.00`.
final class PercentCell extends Cell {
  const PercentCell(this.hundredths);
  final int hundredths;
}

/// A tax rate in ten-thousandths of a percent: `2.5000`.
final class RateCell extends Cell {
  const RateCell(this.tenThousandths);
  final int tenThousandths;
}

/// Energy in Wh, written in kWh without trailing zeros: `1900`, `1900.5`.
final class KwhCell extends Cell {
  const KwhCell(this.wh);
  final int wh;
}

final class DateCell extends Cell {
  const DateCell(this.date);
  final CalendarDate date;
}

/// `oui` or `non`.
final class FlagCell extends Cell {
  const FlagCell(this.value);
  final bool value;
}

final class IntCell extends Cell {
  const IntCell(this.value);
  final int value;
}

/// The characters that make a spreadsheet read a text as a formula.
const formulaStarts = {'=', '+', '-', '@'};

/// The text of [cell] in a CSV file, before quoting.
String csvCell(Cell? cell) => switch (cell) {
  null => '',
  TextCell(:final text) => text.isNotEmpty && formulaStarts.contains(text[0]) ? "'$text" : text,
  PlainCell(:final text) => text,
  AmountCell(:final cents) => scaled(cents, 2),
  PercentCell(:final hundredths) => scaled(hundredths, 2),
  RateCell(:final tenThousandths) => scaled(tenThousandths, 4),
  KwhCell(:final wh) => _trimmed(scaled(wh, 3)),
  DateCell(:final date) => date.encode(),
  FlagCell(:final value) => value ? 'oui' : 'non',
  IntCell(:final value) => '$value',
};

/// [value] divided by 10^[decimals], with exactly [decimals] decimals and a
/// decimal point: no floating point, no thousands separator.
String scaled(int value, int decimals) {
  final negative = value < 0;
  final digits = value.abs().toString().padLeft(decimals + 1, '0');
  final whole = digits.substring(0, digits.length - decimals);
  final fraction = digits.substring(digits.length - decimals);
  return '${negative ? '-' : ''}$whole.$fraction';
}

String _trimmed(String decimal) {
  var end = decimal.length;
  while (decimal[end - 1] == '0') {
    end--;
  }
  if (decimal[end - 1] == '.') end--;
  return decimal.substring(0, end);
}

/// [text] as a field: between quotes when it holds a semicolon, a quote or
/// a line break, its quotes doubled.
String csvField(String text) {
  if (!text.contains(RegExp('[;"\r\n]'))) return text;
  return '"${text.replaceAll('"', '""')}"';
}

/// The line of [fields], without its line ending.
String csvLine(Iterable<String> fields) => fields.map(csvField).join(';');

const _byteOrderMark = [0xEF, 0xBB, 0xBF];

/// The bytes of a CSV file: the byte order mark, [headers], then each row,
/// every line ended by CR LF.
Uint8List csvBytes(List<String> headers, Iterable<List<Cell?>> rows) {
  final buffer = StringBuffer()
    ..write(csvLine(headers))
    ..write('\r\n');
  for (final row in rows) {
    if (row.length != headers.length) {
      throw ArgumentError('a row of ${row.length} cells for ${headers.length} headers');
    }
    buffer
      ..write(csvLine(row.map(csvCell)))
      ..write('\r\n');
  }
  return Uint8List.fromList([..._byteOrderMark, ...utf8.encode(buffer.toString())]);
}
