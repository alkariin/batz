// The format of the files of the export (decision H2 of phase 7).
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:batz/domain/calendar_date.dart';
import 'package:batz/domain/export/csv.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/csv_reader.dart';

void main() {
  test('amounts, percentages, rates and kWh are written from their integers', () {
    expect(csvCell(const AmountCell(123450)), '1234.50');
    expect(csvCell(const AmountCell(-8500)), '-85.00');
    expect(csvCell(const AmountCell(0)), '0.00');
    expect(csvCell(const AmountCell(-5)), '-0.05');
    expect(csvCell(const AmountCell(100000000000)), '1000000000.00', reason: 'no thousands separator');
    expect(csvCell(const PercentCell(5000)), '50.00');
    expect(csvCell(const PercentCell(3333)), '33.33');
    expect(csvCell(const RateCell(25000)), '2.5000');
    expect(csvCell(const RateCell(7)), '0.0007');
    expect(csvCell(const KwhCell(1900000)), '1900');
    expect(csvCell(const KwhCell(1900500)), '1900.5');
    expect(csvCell(const KwhCell(1900050)), '1900.05');
    expect(csvCell(const KwhCell(1900005)), '1900.005');
    expect(csvCell(const KwhCell(0)), '0');
  });

  test('dates, yes and no, integers and absent values', () {
    expect(csvCell(DateCell(CalendarDate(2026, 12, 31))), '2026-12-31');
    expect(csvCell(DateCell(CalendarDate(2026, 1, 5))), '2026-01-05');
    expect(csvCell(const FlagCell(true)), 'oui');
    expect(csvCell(const FlagCell(false)), 'non');
    expect(csvCell(const IntCell(2026)), '2026');
    expect(csvCell(null), '');
  });

  test('a text that starts with =, +, - or @ gets an apostrophe; a negative amount stays a number', () {
    expect(csvCell(const TextCell('=A1+1')), "'=A1+1");
    expect(csvCell(const TextCell('+41 79 000 00 00')), "'+41 79 000 00 00");
    expect(csvCell(const TextCell('-50 % sur tout')), "'-50 % sur tout");
    expect(csvCell(const TextCell('@home')), "'@home");
    expect(csvCell(const TextCell('Loyer = 2100')), 'Loyer = 2100');
    expect(csvCell(const TextCell('')), '');
    expect(csvCell(const AmountCell(-8500)), '-85.00');
    expect(csvCell(const PlainCell('-x')), '-x', reason: 'text written by the app is kept as it is');
  });

  test('semicolons, quotes and line breaks are quoted, quotes doubled', () {
    expect(csvField('ACHAT; AUBERGE "DU LAC"'), '"ACHAT; AUBERGE ""DU LAC"""');
    expect(csvField('deux\nlignes'), '"deux\nlignes"');
    expect(csvField('retour\r'), '"retour\r"');
    expect(csvField("Vers l'épargne"), "Vers l'épargne");
    expect(csvField(''), '');
  });

  test('a file: byte order mark, headers, CR LF after every line', () {
    final bytes = csvBytes(
      ['Date', 'Montant', 'Texte'],
      [
        [DateCell(CalendarDate(2026, 9, 3)), const AmountCell(-8500), const TextCell('ACHAT; AUBERGE "DU LAC"')],
        [DateCell(CalendarDate(2026, 9, 5)), const AmountCell(-50000), null],
      ],
    );
    expect(bytes.sublist(0, 3), [0xEF, 0xBB, 0xBF]);
    expect(
      utf8.decode(bytes.sublist(3)),
      'Date;Montant;Texte\r\n'
      '2026-09-03;-85.00;"ACHAT; AUBERGE ""DU LAC"""\r\n'
      '2026-09-05;-500.00;\r\n',
    );
    expect(utf8.decode(csvBytes(['A', 'B'], const []).sublist(3)), 'A;B\r\n', reason: 'headers alone');
  });

  test('a row of the wrong width is refused', () {
    expect(
      () => csvBytes(
        ['A', 'B'],
        [
          const [IntCell(1)],
        ],
      ),
      throwsArgumentError,
    );
  });

  // Texts drawn at random from the characters that matter, read back by a
  // CSV reader of the tests and by the csv module of Python.
  final r = Random(7);
  const alphabet = ['a', 'é', 'Ü', '€', ';', '"', '\n', '\r\n', ' ', '=', '+', '-', '@', "'", ',', '.', '1', '\t'];
  String randomText() => [for (var i = r.nextInt(12); i > 0; i--) alphabet[r.nextInt(alphabet.length)]].join();
  Cell? randomCell() => switch (r.nextInt(9)) {
    0 => null,
    1 => AmountCell(r.nextInt(2000000) - 1000000),
    2 => PercentCell(r.nextInt(10001)),
    3 => RateCell(r.nextInt(1000000)),
    4 => KwhCell(r.nextInt(5000000)),
    5 => DateCell(CalendarDate(2020 + r.nextInt(10), 1 + r.nextInt(12), 1 + r.nextInt(28))),
    6 => FlagCell(r.nextBool()),
    7 => IntCell(r.nextInt(3000)),
    _ => TextCell(randomText()),
  };
  final headers = ['Texte', 'Valeur', 'Autre ; colonne', 'Guillemet "'];
  final rows = [
    for (var i = 0; i < 300; i++) [TextCell(randomText()), randomCell(), randomCell(), randomCell()],
  ];
  final written = [
    headers,
    for (final row in rows) [for (final cell in row) csvCell(cell)],
  ];
  final bytes = csvBytes(headers, rows);

  test('read back by a CSV reader, every file gives back the values written', () {
    expect(readCsv(bytes), written);
  });

  test('read back by the csv module of Python, the same values', () async {
    final dir = Directory.systemTemp.createTempSync('batz-csv');
    addTearDown(() => dir.deleteSync(recursive: true));
    final file = File('${dir.path}/file.csv')..writeAsBytesSync(bytes);
    final script =
        'import csv, json, sys\n'
        "with open(sys.argv[1], newline='', encoding='utf-8-sig') as f:\n"
        "    print(json.dumps(list(csv.reader(f, delimiter=';', strict=True))))\n";
    final result = await Process.run('python3', ['-I', '-c', script, file.path], stdoutEncoding: utf8);
    expect(result.exitCode, 0, reason: '${result.stderr}');
    expect(jsonDecode(result.stdout as String), written);
  });
}
