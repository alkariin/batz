// The example ledger gives exactly its expected files, the three lines of
// docs/features.md, « Export », included.
import 'dart:convert';
import 'dart:io';

import 'package:batz/domain/export/csv.dart';
import 'package:batz/domain/export/export_schema.dart';
import 'package:batz/domain/export/ledger_export.dart';
import 'package:batz/domain/ledger/ledger.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/csv_reader.dart';
import '../../support/export_example.dart';

/// The expected files. `BATZ_UPDATE_EXPORT=1 flutter test
/// test/domain/export/export_example_test.dart` rewrites them; they are
/// then read again by eye before being committed.
const _expected = 'test/fixtures/export';

void main() {
  final files = exportFiles(exportExampleLedger());

  if (Platform.environment['BATZ_UPDATE_EXPORT'] == '1') {
    Directory(_expected).createSync(recursive: true);
    for (final file in files) {
      File('$_expected/${file.name}').writeAsBytesSync(file.bytes);
    }
  }

  test('the seventeen files, in their order', () {
    expect(files.map((f) => f.name), ExportFiles.all);
  });

  for (final file in files) {
    test('${file.name} is exactly its expected file', () {
      expect(file.bytes, File('$_expected/${file.name}').readAsBytesSync());
    });
  }

  test('the three transactions of the example, as the documentation shows them', () {
    const headers = [
      'Date',
      'Compte',
      'Montant',
      'Texte de la banque',
      'Description',
      'Statut',
      'Type',
      'Catégorie',
      'Début de période',
      'Fin de période',
    ];
    final table = CsvTable(files.firstWhere((f) => f.name == ExportFiles.transactions).bytes);
    final lines = [
      csvLine(headers),
      for (final row in table.rows)
        if (['tx-rent', 'tx-restaurant', 'tx-saving'].contains(row['idTransaction']))
          csvLine([for (final h in headers) row[h]!]),
    ];
    expect(lines.join('\n'), '''
Date;Compte;Montant;Texte de la banque;Description;Statut;Type;Catégorie;Début de période;Fin de période
2026-09-01;Compte privé;-2100.00;;Loyer annuel;validée;dépense;Logement > Loyer;2026-09-01;2027-08-31
2026-09-03;Compte privé;-85.00;"ACHAT; AUBERGE ""DU LAC""";Restaurant;validée;dépense;Quotidien > Restaurant;2026-09-03;2026-09-03
2026-09-05;Compte privé;-500.00;;Vers l'épargne;validée;transfert;;;''');
    // A bank text =A1+1 is written '=A1+1.
    final formula = table.where('idTransaction', 'tx-formula').single;
    expect((formula['Texte de la banque'], formula['Description']), ("'=A1+1", "'=A1+1"));
    expect(utf8.decode(files[6].bytes.sublist(3)), contains(";'=A1+1;'=A1+1;"));
  });

  test('a file without data has its line of headers', () {
    final empty = exportFiles(Ledger());
    for (final file in empty) {
      final table = CsvTable(file.bytes);
      expect(table.headers, ExportHeaders.byFile[file.name]);
      if (file.name != ExportFiles.moduleSettings) expect(table.rows, isEmpty, reason: file.name);
    }
  });
}
