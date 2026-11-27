// « Plus › Réglages › Exporter les données »: saved, then cancelled; the
// journal does not move.
import 'dart:typed_data';

import 'package:archive/archive.dart' show ZipDecoder;
import 'package:batz/app.dart';
import 'package:batz/data/files.dart';
import 'package:batz/domain/calendar_date.dart';
import 'package:batz/domain/export/export_archive.dart';
import 'package:batz/domain/export/export_schema.dart';
import 'package:batz/domain/journal/journal_entry.dart';
import 'package:batz/domain/ledger/account.dart';
import 'package:batz/domain/ledger/category.dart';
import 'package:batz/domain/ledger/ledger.dart';
import 'package:batz/domain/ledger/transaction.dart';
import 'package:batz/services.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/csv_reader.dart';
import '../../support/ledger_fixture.dart' show d, entry;
import '../../support/services.dart';
import '../accounts/accounts_page_test.dart' show settle;

/// The save dialog: saves while [accept], cancels otherwise.
class SaveDialog implements FileAccess {
  bool accept = true;
  final saved = <String, Uint8List>{};
  var asked = 0;

  @override
  Future<PickedFile?> pickStatement() async => null;

  @override
  Future<bool> saveStatement(String fileName, Uint8List bytes) async => false;

  @override
  Future<bool> saveZip(String fileName, Uint8List bytes) async {
    asked++;
    if (accept) saved[fileName] = bytes;
    return accept;
  }

  @override
  Future<PickedFile?> pickDocument() async => null;

  @override
  Future<bool> saveDocument(String fileName, Uint8List bytes) async => false;

  @override
  Future<bool> openDocument(String fileName, Uint8List bytes) async => false;

  @override
  Future<bool> openLink(String url) async => false;
}

void main() {
  testWidgets('the export says what it holds and that it is not encrypted, saves the ZIP, then a cancellation '
      'leaves nothing; the journal does not move', (tester) async {
    tester.view.physicalSize = const Size(400, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final files = SaveDialog();
    final services = (await tester.runAsync(
      () => testServices(files: files, today: () => CalendarDate(2026, 11, 21)),
    ))!;
    addTearDown(() => tester.runAsync(services.database.close));
    await tester.runAsync(() => _seed(services));
    final before = (await tester.runAsync(services.journal.entries))!;

    await tester.pumpWidget(BatzApp(services: services));
    await settle(tester);
    await tester.tap(find.descendant(of: find.byType(NavigationBar), matching: find.text('Plus')));
    await settle(tester);
    await tester.scrollUntilVisible(find.byKey(const Key('moreExport')), 200);
    await tester.tap(find.byKey(const Key('moreExport')));
    await settle(tester);
    expect(find.text('Exporter les données'), findsWidgets);
    expect(
      find.descendant(
        of: find.byKey(const Key('exportNotEncrypted')),
        matching: find.text("Le fichier n'est pas chiffré : quiconque l'ouvre lit vos données. Gardez-le en lieu sûr."),
      ),
      findsOneWidget,
    );
    expect(find.textContaining('comptes, soldes déclarés, relevés, catégories, règles, transactions'), findsOneWidget);

    // Saved: the ZIP of the day, its counts on the screen.
    await tester.tap(find.byKey(const Key('exportButton')));
    await settle(tester);
    expect(files.saved.keys, ['batz-export-2026-11-21.zip']);
    expect(
      tester.widget<Text>(find.byKey(const Key('exportOutcome'))).data,
      'Export enregistré : 21 fichiers CSV et LISEZMOI.txt, 4 transactions.',
    );
    final zip = ZipDecoder().decodeBytes(files.saved.values.single, verify: true);
    expect(zip.files.map((f) => f.name), [...ExportFiles.all, readmeFileName]);
    final transactions = CsvTable(zip.findFile('transactions.csv')!.content);
    expect({for (final row in transactions.rows) row['idTransaction']}, hasLength(4));
    expect(transactions.where('Description', 'Courses').single['Montant'], '-45.00');
    expect(transactions.where('idTransaction', 't2').single['Description'], "'=SOMME(A1)");

    // Cancelled: nothing saved, the screen says so.
    files.accept = false;
    await tester.tap(find.byKey(const Key('exportButton')));
    await settle(tester);
    expect((files.asked, files.saved.length), (2, 1));
    expect(
      tester.widget<Text>(find.byKey(const Key('exportOutcome'))).data,
      "Export annulé : rien n'a été enregistré.",
    );

    // Neither export wrote to the journal.
    final after = (await tester.runAsync(services.journal.entries))!;
    expect(after.map((e) => e.hlc), before.map((e) => e.hlc));
  });
}

Future<void> _seed(AppServices services) async {
  Future<void> apply(Modification Function(Ledger l) build) async =>
      services.ledger.write(build(await services.ledger.load()));
  await apply((l) => l.createAccount('cash', const AccountDraft(name: 'Espèces', type: AccountType.cash)));
  await apply((l) => l.createAccount('savings', const AccountDraft(name: 'Épargne', type: AccountType.savings)));
  await apply((l) => l.createTree(2026));
  final expenses = defaultGroupId(2026, CategoryNature.expense);
  await apply((l) => l.addCategory('food', year: 2026, name: 'Nourriture', parentId: expenses));
  await apply((l) => l.recordEntry('t1', 'l1', entry(date: d(2026, 3, 2), cents: 4500, description: 'Courses')));
  await apply((l) => l.recordEntry('t2', 'l2', entry(date: d(2026, 3, 9), cents: 1200, description: '=SOMME(A1)')));
  await apply((l) => l.recordEntry('t3', 'l3', entry(date: d(2026, 4, 1), cents: 8000, description: 'Restaurant')));
  await apply(
    (l) => l.recordTransfer(
      't4',
      TransferDraft(fromAccountId: 'cash', toAccountId: 'savings', date: d(2026, 4, 2), cents: 10000),
    ),
  );
}
