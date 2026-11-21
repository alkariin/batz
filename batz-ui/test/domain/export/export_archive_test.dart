// The ZIP of the export: the seventeen CSV files and LISEZMOI.txt, its dated
// name, read back by the library and by another tool (step 7.2 of phase 7).
import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:batz/domain/calendar_date.dart';
import 'package:batz/domain/export/export_archive.dart';
import 'package:batz/domain/export/export_schema.dart';
import 'package:batz/domain/export/ledger_export.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/export_example.dart';

void main() {
  final ledger = exportExampleLedger();
  final archive = buildExportArchive(ledger, date: CalendarDate(2026, 11, 21), appVersion: '0.8.0-alpha');

  test('a dated name, the number of files and of transactions', () {
    expect(archive.fileName, 'batz-export-2026-11-21.zip');
    expect(exportFileName(CalendarDate(2027, 1, 5)), 'batz-export-2027-01-05.zip');
    expect((archive.csvFiles, archive.transactions), (17, 9));
  });

  test('the library reads it back: the seventeen CSV files then LISEZMOI.txt, each as written', () {
    final decoded = ZipDecoder().decodeBytes(archive.bytes, verify: true);
    expect(decoded.files.map((f) => f.name), [...ExportFiles.all, readmeFileName]);
    final files = exportFiles(ledger);
    for (final file in files) {
      expect(decoded.findFile(file.name)!.content, file.bytes, reason: file.name);
    }
  });

  test('LISEZMOI.txt: date, version, files and their rows, format, not encrypted', () {
    final bytes = ZipDecoder().decodeBytes(archive.bytes).findFile(readmeFileName)!.content;
    expect(bytes.sublist(0, 3), [0xEF, 0xBB, 0xBF]);
    final text = utf8.decode(bytes.sublist(3));
    expect(text, isNot(contains(RegExp('[^\r]\n'))), reason: 'CR LF everywhere');
    final lines = text.split('\r\n');
    expect(lines, containsAll(["Date de l'export : 2026-11-21", "Version de l'app : 0.8.0-alpha", 'Transactions : 9']));
    for (final (name, rows) in [
      ('comptes.csv', 4),
      ('transactions.csv', 9),
      ('voyages.csv', 5),
      ('reglages-modules.csv', 4),
      ('impots.csv', 4),
    ]) {
      expect(lines.where((l) => RegExp('^  ${RegExp.escape(name)} +$rows\$').hasMatch(l)), hasLength(1), reason: name);
    }
    expect(lines.where((l) => RegExp(r'^  \S+\.csv +\d+$').hasMatch(l)), hasLength(17));
    expect(text, contains("n'est pas chiffré"));
    expect(text, contains('séparateur point-virgule'));
    expect(text, contains('1234.50'));
    expect(text, contains('2026-12-31'));
    expect(text, contains('=, +, - ou @'));
  });

  test('unzip -t reads it back without error, and lists eighteen files', () async {
    final dir = Directory.systemTemp.createTempSync('batz-zip');
    addTearDown(() => dir.deleteSync(recursive: true));
    final file = File('${dir.path}/${archive.fileName}')..writeAsBytesSync(archive.bytes);
    final check = await Process.run('unzip', ['-t', file.path]);
    expect(check.exitCode, 0, reason: '${check.stdout}${check.stderr}');
    expect(check.stdout as String, contains('No errors detected'));
    for (final name in [...ExportFiles.all, readmeFileName]) {
      expect(check.stdout as String, contains('testing: $name '), reason: name);
    }
    final list = await Process.run('unzip', ['-Z1', file.path]);
    expect((list.stdout as String).trim().split('\n'), [...ExportFiles.all, readmeFileName]);
  });
}
