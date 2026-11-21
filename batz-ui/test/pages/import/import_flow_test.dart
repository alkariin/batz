import 'dart:convert';
import 'dart:typed_data';

import 'package:batz/app.dart';
import 'package:batz/data/files.dart';
import 'package:batz/data/secret_store.dart';
import 'package:batz/data/server/import_protocol.dart';
import 'package:batz/data/server/server_client.dart';
import 'package:batz/data/server/server_repository.dart';
import 'package:batz/data/sync/sync_protocol.dart';
import 'package:batz/domain/ledger/account.dart';
import 'package:batz/services.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fake_server.dart';
import '../../support/ledger_harness.dart';
import '../../support/services.dart';
import '../../support/statements.dart';
import '../accounts/accounts_page_test.dart' show settle;
import '../sync/sync_cubit_test.dart' show pairing;

/// The import routes of a server, in memory, answering with the server's
/// own extraction of the test set.
class FakeImportServer implements ImportTransport {
  final byFingerprint = <String, FixtureStatement>{};
  final refusals = <String, (String, String?)>{};

  /// The files the server holds, for `statementPdf`.
  final held = <String, Uint8List>{};
  var importCalls = 0;
  var formats = ['postfinance'];

  void know(FixtureStatement f) => byFingerprint[f.fingerprint] = f;

  @override
  Future<Health> health() async =>
      Health(version: 'v0.4.0', minAppVersion: '0.1.0', syncProtocol: syncProtocol, importFormats: formats);

  @override
  Future<ImportResponse> importStatement(Uint8List pdf) async {
    importCalls++;
    final fingerprint = sha256.convert(pdf).toString();
    if (refusals[fingerprint] case (final code, final check)) {
      throw ServerException(422, code, 'refused', check: check);
    }
    final f = byFingerprint[fingerprint]!;
    held[fingerprint] = pdf;
    return ImportResponse(fingerprint: fingerprint, statement: f.statement);
  }

  @override
  Future<Uint8List?> statementPdf(String fingerprint) async => held[fingerprint];
}

class FakeFiles implements FileAccess {
  final queue = <PickedFile>[];
  final saved = <String, Uint8List>{};

  void pick(FixtureStatement f) => queue.add(PickedFile('${f.name}.pdf', Uint8List.fromList(f.pdf)));

  @override
  Future<PickedFile?> pickPdf() async => queue.isEmpty ? null : queue.removeAt(0);

  @override
  Future<bool> savePdf(String fileName, Uint8List bytes) async {
    saved[fileName] = bytes;
    return true;
  }

  @override
  Future<bool> saveZip(String fileName, Uint8List bytes) async {
    saved[fileName] = bytes;
    return true;
  }
}

void main() {
  final jan = fixtureStatement('2026-01'), feb = fixtureStatement('2026-02'), mar = fixtureStatement('2026-03');
  final inconsistentPdf = Uint8List.fromList(utf8.encode('%PDF-1.4 inconsistent totals'));

  late FakeServer sync;
  late FakeImportServer imports;
  late FakeFiles files;
  late AppServices services;

  Future<void> open(WidgetTester tester) async {
    tester.view.physicalSize = const Size(500, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final serverSide = (await tester.runAsync(
      () => LedgerHarness.open(deviceId: '22222222-0000-4000-8000-000000000000'),
    ))!;
    addTearDown(() => tester.runAsync(serverSide.close));
    sync = FakeServer(serverSide.journal);
    imports = FakeImportServer()
      ..know(jan)
      ..know(feb)
      ..know(mar);
    imports.refusals[sha256.convert(inconsistentPdf).toString()] = ('IMPORT_INCONSISTENT', 'totals');
    files = FakeFiles();
    final secrets = MemorySecretStore()..values[pairingSecretKey] = jsonEncode(pairing.toJson());
    services = (await tester.runAsync(
      () => testServices(secrets: secrets, syncTransport: (_) => sync, importTransport: (_) => imports, files: files),
    ))!;
    addTearDown(() => tester.runAsync(services.database.close));
    await tester.runAsync(() async {
      final ledger = await services.ledger.load();
      await services.ledger.write(
        ledger.createAccount(
          'bank',
          const AccountDraft(
            name: 'PostFinance',
            type: AccountType.privateAccount,
            importFormat: ImportFormat.postfinance,
          ),
        ),
      );
    });
    await tester.pumpWidget(BatzApp(services: services));
    await settle(tester);
    await tester.tap(find.descendant(of: find.byType(NavigationBar), matching: find.text('Transactions')));
    await settle(tester);
  }

  Future<void> choose(WidgetTester tester) async {
    await tester.tap(find.byKey(const Key('importChoose')));
    await settle(tester);
  }

  testWidgets('a statement is imported after a synchronisation, the first one confirmed; refusals give their reason', (
    tester,
  ) async {
    await open(tester);
    await tester.tap(find.byKey(const Key('importStatement')));
    await settle(tester);
    expect(find.byKey(const Key('importChoose')), findsOneWidget);
    expect(sync.requests, isNotEmpty, reason: 'the import starts with a synchronisation');

    // The first statement of the account is confirmed (H7).
    files.pick(jan);
    await choose(tester);
    expect(find.text('Premier relevé de ce compte'), findsOneWidget);
    expect(find.textContaining("2'345.67"), findsOneWidget);
    await tester.tap(find.text('Importer'));
    await settle(tester);
    expect(
      tester.widget<Text>(find.byKey(const Key('importResult'))).data,
      'Du 01.01.2026 au 31.01.2026\n27 lignes : 0 proposée, 27 à compléter.',
    );

    // Already imported: refused from the journal, the server not asked (H1).
    final calls = imports.importCalls;
    files.pick(jan);
    await choose(tester);
    expect(tester.widget<Text>(find.byKey(const Key('importRefusal'))).data, 'Ce relevé est déjà importé.');
    expect(imports.importCalls, calls);

    // A month skipped: refused with what was expected.
    files.pick(mar);
    await choose(tester);
    expect(
      tester.widget<Text>(find.byKey(const Key('importRefusal'))).data,
      startsWith('Ce relevé ne suit pas le précédent : il commence le 01.03.2026'),
    );

    // Refused by the server, with the check in cause.
    files.queue.add(PickedFile('broken.pdf', inconsistentPdf));
    await choose(tester);
    expect(
      tester.widget<Text>(find.byKey(const Key('importRefusal'))).data,
      'Relevé incohérent, rien n\'est importé : les totaux imprimés des crédits ou des débits ne correspondent pas aux mouvements.',
    );

    // The next month: no confirmation.
    files.pick(feb);
    await choose(tester);
    expect(find.text('Premier relevé de ce compte'), findsNothing);
    expect(tester.widget<Text>(find.byKey(const Key('importResult'))).data, contains('21 lignes'));

    // The statements of the account; the original PDF; the last one deleted.
    await tester.tap(find.text('Relevés du compte'));
    await settle(tester);
    expect(find.text('01.02.2026 – 28.02.2026'), findsOneWidget);
    expect(find.text('01.01.2026 – 31.01.2026'), findsOneWidget);
    expect(find.textContaining('27 lignes'), findsOneWidget);

    final ledger = (await tester.runAsync(services.ledger.load))!;
    final janStatement = ledger.statementsOf('bank').first;
    final febStatement = ledger.statementsOf('bank').last;

    await tester.tap(find.byKey(ValueKey('statementMenu-${janStatement.id}')));
    await settle(tester);
    expect(find.text('Supprimer le dernier relevé'), findsNothing, reason: 'only the last one');
    await tester.tap(find.text("Enregistrer le PDF d'origine"));
    await settle(tester);
    expect(files.saved['releve-2026-01-01-2026-01-31.pdf'], jan.pdf);
    expect(find.text('PDF enregistré.'), findsOneWidget);

    // A rebuilt server no longer has the file: said without error.
    imports.held.clear();
    await tester.tap(find.byKey(ValueKey('statementMenu-${janStatement.id}')));
    await settle(tester);
    await tester.tap(find.text("Enregistrer le PDF d'origine"));
    await settle(tester);
    expect(find.text("Le serveur n'a plus ce PDF : il a sans doute été reconstruit depuis l'import."), findsOneWidget);

    await tester.tap(find.byKey(ValueKey('statementMenu-${febStatement.id}')));
    await settle(tester);
    await tester.tap(find.text('Supprimer le dernier relevé'));
    await settle(tester);
    expect(find.textContaining('et ses 21 lignes'), findsOneWidget);
    await tester.tap(find.text('Supprimer'));
    await settle(tester);
    expect(find.text('Relevé supprimé.'), findsOneWidget);
    expect(find.text('01.02.2026 – 28.02.2026'), findsNothing);
    expect((await tester.runAsync(services.ledger.load))!.statementsOf('bank'), hasLength(1));
  });

  testWidgets('without a synchronisation gone to its end, the import does not start and says so', (tester) async {
    await open(tester);
    sync.unreachable = true;
    await tester.tap(find.byKey(const Key('importStatement')));
    await settle(tester);
    expect(
      tester.widget<Text>(find.byKey(const Key('importNotReady'))).data,
      "L'import commence par une synchronisation aboutie. Elle n'a pas abouti : Hors ligne",
    );
    expect(find.byKey(const Key('importChoose')), findsNothing);

    sync.unreachable = false;
    await tester.tap(find.text('Réessayer'));
    await settle(tester);
    expect(find.byKey(const Key('importChoose')), findsOneWidget);
  });

  testWidgets('a server too old to import says so', (tester) async {
    await open(tester);
    imports.formats = const [];
    await tester.tap(find.byKey(const Key('importStatement')));
    await settle(tester);
    files.pick(jan);
    await choose(tester);
    expect(
      tester.widget<Text>(find.byKey(const Key('importRefusal'))).data,
      'Le serveur (version v0.4.0) est trop ancien pour importer des relevés : installez la version 0.4.0 ou une suivante.',
    );
  });
}
