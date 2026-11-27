// On data drawn at random by the operations of the app, every record that
// is not deleted is found in its file with its values, and a deleted one is
// not.
import 'dart:convert';
import 'dart:math';

import 'package:batz/data/local/derived_tables.dart';
import 'package:batz/domain/export/export_schema.dart';
import 'package:batz/domain/export/ledger_export.dart';
import 'package:batz/domain/calendar_date.dart';
import 'package:batz/domain/ledger/ledger_exception.dart';
import 'package:batz/domain/ledger/proposal.dart';
import 'package:batz/domain/ledger/rule.dart';
import 'package:batz/domain/ledger/statement.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/csv_reader.dart';
import '../../support/ledger_fixture.dart' show seedLedger;
import '../../support/ledger_harness.dart';
import '../../support/random_operations.dart';

/// What [column] must show for the stored [raw] value, computed here apart
/// from the code of the export.
String expectedCell(ExportColumn column, Object? raw) {
  String scaledBy(int value, int decimals) {
    final factor = pow(10, decimals).toInt();
    final sign = value < 0 ? '-' : '';
    final fraction = (value.abs() % factor).toString().padLeft(decimals, '0');
    return '$sign${value.abs() ~/ factor}.$fraction';
  }

  String text(String value) => RegExp('^[=+\\-@]').hasMatch(value) ? "'$value" : value;
  if (raw == null) return column.kind == ExportKind.flag ? 'non' : '';
  return switch (column.kind) {
    ExportKind.text => text(raw as String),
    ExportKind.id || ExportKind.date => raw as String,
    ExportKind.amount || ExportKind.percent => scaledBy(raw as int, 2),
    ExportKind.rate => scaledBy(raw as int, 4),
    ExportKind.kwh => scaledBy(raw as int, 3).replaceFirst(RegExp(r'\.?0+$'), ''),
    ExportKind.flag => raw == 1 ? 'oui' : 'non',
    ExportKind.integer => '$raw',
    ExportKind.label => column.labels![raw as String]!,
    ExportKind.ruleLines => text((jsonDecode(raw as String) as List).join('\n')),
  };
}

/// Bank texts that a spreadsheet or a CSV file could misread.
const _bankTexts = [
  'ACHAT; AUBERGE "DU LAC"',
  '=A1+1',
  "VIREMENT\nDONNEUR D'ORDRE: CAISSE",
  '-REMISE ACHAT',
  '@CAISSE',
  'ACHAT MAGASIN',
];

/// A statement of the detailed account, rules (one deleted) and some of
/// its lines classified: what random operations do not do.
Future<void> _importAndRules(LedgerHarness h, Random r) async {
  final lines = [
    for (var i = 0; i < 12; i++)
      ExtractedLine(
        date: CalendarDate(2026, 1, 2 + i),
        amount: r.nextInt(20000) - 12000,
        rawText: _bankTexts[i % _bankTexts.length],
        label: 'Ligne $i',
      ),
  ];
  final credits = lines.where((l) => l.amount > 0).fold(0, (sum, l) => sum + l.amount);
  final debits = lines.where((l) => l.amount < 0).fold(0, (sum, l) => sum - l.amount);
  late String statementId;
  await h.apply((l) {
    final import = l.importStatement(
      'bank',
      ExtractedStatement(
        format: 'postfinance',
        iban: 'CH0000000000000000000',
        currency: 'CHF',
        periodStart: CalendarDate(2026, 1, 1),
        periodEnd: CalendarDate(2026, 1, 31),
        openingBalance: 100000,
        closingBalance: 100000 + credits - debits,
        totalCredits: credits,
        totalDebits: debits,
        lines: lines,
      ),
      fingerprint: 'e' * 64,
    );
    statementId = import.statementId;
    return import.modification;
  });
  await h.apply(
    (l) => l.createRule(
      'rule-a',
      const RuleDraft(year: 2026, lines: ['-REMISE ET achat', 'magasin du coin'], targetCategoryId: 'food'),
    ),
  );
  await h.apply(
    (l) => l.createRule('rule-b', const RuleDraft(year: 2026, lines: ['@caisse'], targetAccountId: 'cash')),
  );
  await h.apply(
    (l) => l.createRule('rule-c', const RuleDraft(year: 2026, lines: ['magasin'], targetCategoryId: 'rent')),
  );
  await h.apply((l) => l.deleteRule('rule-c'));
  for (final rank in [0, 1, 2]) {
    final date = CalendarDate(2026, 1, 2 + rank);
    await h.apply(
      (l) => l.classify(
        importedTransactionId(statementId, rank),
        Classification.category('food', periodStart: date, periodEnd: date),
      ),
    );
  }
}

void main() {
  for (final seed in [1, 2, 3, 4, 5]) {
    test('every record not deleted is in its file with its values, a deleted one is not (seed $seed)', () async {
      final r = Random(seed);
      var clock = DateTime.utc(2026, 11, 21).millisecondsSinceEpoch;
      final h = await LedgerHarness.open(now: () => clock += 1000);
      addTearDown(h.close);
      await seedLedger(h);
      await _importAndRules(h, r);
      var applied = 0;
      for (var step = 0; step < 400; step++) {
        try {
          final m = randomOperation(await h.ledger(), r, 's$seed-$step');
          if (m == null) continue;
          await h.repository.write(m);
          applied++;
        } on LedgerException {
          // Refused by the domain: nothing written.
        }
      }
      expect(applied, greaterThan(150));

      final files = {for (final f in exportFiles(await h.ledger())) f.name: CsvTable(f.bytes)};
      final tables = {for (final t in appDerivedTables) t.entity: t};
      final rows = await h.tables([for (final t in appDerivedTables) t.table]);
      final seen = <String, int>{};
      var deleted = 0;
      for (final MapEntry(key: entity, value: exported) in exportSchema.entries) {
        final table = tables[entity]!;
        final file = files[exported.file]!;
        for (final record in rows[table.table]!) {
          final id = record['id']! as String;
          final found = file.where(exported.idColumn, id);
          if (record['deleted'] == 1) {
            deleted++;
            expect(found, isEmpty, reason: 'deleted $entity $id in ${exported.file}');
            continue;
          }
          expect(found, isNotEmpty, reason: '$entity $id missing from ${exported.file}');
          seen[entity] = (seen[entity] ?? 0) + 1;
          for (final MapEntry(key: field, value: column) in exported.fields.entries) {
            final raw = record[table.columns[field]!.name];
            if (raw == null && column.absentShowsComputed) continue;
            for (final row in found) {
              expect(row[column.header], expectedCell(column, raw), reason: '$entity $id, $field');
            }
          }
        }
      }
      // The data drawn reaches every entity, deleted records included.
      expect(
        seen.keys.toSet(),
        containsAll(['account', 'category', 'transaction', 'transactionLine', 'statement', 'rule']),
      );
      expect(seen.length, greaterThanOrEqualTo(17), reason: 'entities met: ${seen.keys}');
      expect(deleted, greaterThan(0));

      // No row stands for a record that is not there, except the trips the
      // screen groups and the modules without a setting.
      for (final MapEntry(key: entity, value: exported) in exportSchema.entries) {
        final ids = {
          for (final record in rows[tables[entity]!.table]!)
            if (record['deleted'] == 0) record['id'],
        };
        final file = files[exported.file]!;
        final mayBeEmpty = {
          ExportFiles.trips,
          ExportFiles.moduleSettings,
          ExportFiles.transactions,
        }.contains(exported.file);
        for (final row in file.rows) {
          final value = row[exported.idColumn]!;
          if (value.isEmpty && mayBeEmpty) continue;
          // A subscription or an insurance without tranche, a task without
          // box: one row.
          if ({ExportFiles.subscriptions, ExportFiles.monthlyTasks, ExportFiles.insurances}.contains(exported.file) &&
              exported.idColumn == 'id' &&
              value.isEmpty) {
            continue;
          }
          expect(ids, contains(value), reason: '${exported.file}: $value is no $entity');
        }
      }
    });
  }
}
