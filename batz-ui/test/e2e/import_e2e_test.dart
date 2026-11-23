import 'dart:typed_data';

import 'package:batz/data/server/server_client.dart';
import 'package:batz/domain/ledger/account.dart';
import 'package:batz/domain/ledger/category.dart';
import 'package:batz/domain/ledger/ledger_exception.dart';
import 'package:batz/domain/ledger/proposal.dart';
import 'package:batz/domain/ledger/rule.dart';
import 'package:batz/pages/import/import_cubit.dart';
import 'package:batz/pages/ledger_cubit.dart';
import 'package:batz/pages/sync/sync_cubit.dart';
import 'package:batz/domain/views/year_view.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/statements.dart';
import 'server_harness.dart';
import 'sync_device.dart';

final jan = fixtureStatement('2026-01'), feb = fixtureStatement('2026-02'), mar = fixtureStatement('2026-03');
final otherAccount = fixtureStatement('other-account-2026-04');

/// A device with the cubits of the import screen, on the real server.
class ImportingDevice {
  ImportingDevice(this.device) {
    ledger = LedgerCubit(device.ledger.repository);
    sync = SyncCubit(
      server: device.server,
      journal: device.ledger.journal,
      engine: device.engine,
      store: device.store,
      onReceived: ledger.load,
      debounce: const Duration(hours: 1),
      period: const Duration(hours: 1),
    );
    imports = ImportCubit(sync: sync, ledger: ledger, server: device.server);
  }

  final SimDevice device;
  late final LedgerCubit ledger;
  late final SyncCubit sync;
  late final ImportCubit imports;

  Future<void> start() async {
    await ledger.load();
    await imports.start();
  }

  /// Imports [fixture] into `bank`, confirming the first statement.
  Future<ImportState> import(List<int> pdf) async {
    await imports.importFile('bank', Uint8List.fromList(pdf));
    if (imports.state.step == ImportStep.confirmFirst) await imports.confirmFirst();
    return imports.state;
  }

  Future<int> journalLength() async => (await device.ledger.journal.entries()).length;

  Future<void> close() async {
    await imports.close();
    await sync.close();
    await ledger.close();
    await device.close();
  }
}

Future<ImportingDevice> pairedDevice(LocalServer server, String name, {bool createAccount = false}) async {
  final device = await SimDevice.create(name);
  await device.pair(server);
  if (createAccount) {
    await device.ledger.apply(
      (l) => l.createAccount(
        'bank',
        const AccountDraft(
          name: 'PostFinance',
          type: AccountType.privateAccount,
          importFormat: ImportFormat.postfinance,
        ),
      ),
    );
    await device.ledger.apply((l) => l.createTree(2026));
    await device.ledger.apply(
      (l) =>
          l.addCategory('food', year: 2026, name: 'Nourriture', parentId: defaultGroupId(2026, CategoryNature.expense)),
    );
    await device.ledger.apply(
      (l) => l.addCategory('rent', year: 2026, name: 'Loyer', parentId: defaultGroupId(2026, CategoryNature.expense)),
    );
  }
  await device.sync();
  return ImportingDevice(device);
}

void main() {
  test('the fictitious statements are imported through the server, the balances computed are the printed ones; '
      'refused statements change nothing', () async {
    final server = await LocalServer.start();
    addTearDown(server.stop);
    final a = await pairedDevice(server, 'Ordinateur', createAccount: true);
    addTearDown(a.close);
    await a.start();
    expect(a.imports.state.step, ImportStep.ready);

    expect((await a.import(jan.pdf)).step, ImportStep.done);
    expect(a.imports.state.result!.lines, 27);

    Future<void> refused(List<int> pdf, Matcher refusal) async {
      final before = await a.journalLength();
      final state = await a.import(pdf);
      expect(state.step, ImportStep.refused);
      expect(state.refusal, refusal);
      expect(await a.journalLength(), before, reason: 'the journal did not change');
    }

    LedgerError? error(ImportRefusal r) => r.ledger?.error;
    await refused(jan.pdf, isA<ImportRefusal>().having(error, 'error', LedgerError.statementAlreadyImported));
    await refused(mar.pdf, isA<ImportRefusal>().having(error, 'error', LedgerError.statementNotContiguous));
    await refused(
      statementPdf('inconsistent-total'),
      isA<ImportRefusal>().having((r) => (r.code, r.check), 'refusal', ('IMPORT_INCONSISTENT', 'totals')),
    );
    await refused(
      statementPdf('inconsistent-amount'),
      isA<ImportRefusal>().having((r) => (r.code, r.check), 'refusal', ('IMPORT_INCONSISTENT', 'runningBalance')),
    );
    await refused(
      statementPdf('not-a-statement'),
      isA<ImportRefusal>().having((r) => r.code, 'code', 'IMPORT_UNKNOWN_FORMAT'),
    );

    expect((await a.import(feb.pdf)).step, ImportStep.done);
    expect((await a.import(mar.pdf)).step, ImportStep.done);
    await refused(otherAccount.pdf, isA<ImportRefusal>().having(error, 'error', LedgerError.statementOtherAccount));

    // The balance after each line, from the first opening balance, is the
    // one the statements print, wherever they print one.
    final ledger = a.ledger.state.ledger;
    var balance = ledger.statementsOf('bank').first.openingBalance;
    var printed = 0;
    for (final (statement, fixture) in [
      for (final (i, s) in ledger.statementsOf('bank').indexed) (s, [jan, feb, mar][i]),
    ]) {
      expect(statement.fingerprint, fixture.fingerprint);
      for (final (rank, t) in ledger.linesOf(statement.id).indexed) {
        balance += t.amount;
        if (fixture.statement.lines[rank].balance case final expected?) {
          expect(balance, expected);
          printed++;
        }
      }
      expect(balance, statement.closingBalance);
    }
    expect(printed, greaterThan(30));
  });

  test('two devices import the same statement: no line twice after the exchange', () async {
    final server = await LocalServer.start();
    addTearDown(server.stop);
    final a = await pairedDevice(server, 'Ordinateur', createAccount: true);
    addTearDown(a.close);
    final b = await pairedDevice(server, 'Téléphone');
    addTearDown(b.close);
    await a.start();
    await b.start();
    expect((await a.import(jan.pdf)).step, ImportStep.done);
    expect((await b.import(jan.pdf)).step, ImportStep.done, reason: 'B had not received A’s import yet');

    for (final d in [a, b, a]) {
      await d.device.sync();
    }
    expect(await a.device.state(), await b.device.state());
    final ledger = await a.device.ledger.ledger();
    expect(ledger.statements, hasLength(1));
    expect(ledger.transactions.values.where((t) => t.isImported), hasLength(27));
  });

  test(
    'server stopped: lines are validated in bulk and one by one; restarted, another device receives them validated',
    () async {
      final server = await LocalServer.start();
      final a = await pairedDevice(server, 'Ordinateur', createAccount: true);
      addTearDown(a.close);
      final b = await pairedDevice(server, 'Téléphone');
      addTearDown(b.close);
      await a.start();
      expect((await a.import(jan.pdf)).step, ImportStep.done);
      await a.device.sync();
      await b.device.sync();
      expect((await b.device.ledger.ledger()).linesToValidate, hasLength(27));

      await server.stop();
      // Offline, on device A: a rule, its proposals confirmed, a line classified.
      await a.device.ledger.apply(
        (l) => l.createRule('food', const RuleDraft(year: 2026, lines: ['épicerie du coin'], targetCategoryId: 'food')),
      );
      var ledger = await a.device.ledger.ledger();
      for (final m in ledger.confirmProposals([for (final t in ledger.linesToValidate) t.id])) {
        await a.device.ledger.repository.write(m);
      }
      final rent = ledger.linesToValidate.firstWhere((t) => t.rawText!.contains('Gérance'));
      await a.device.ledger.apply(
        (l) => l.classify(rent.id, Classification.category('rent', periodStart: rent.date, periodEnd: rent.date)),
      );
      await expectLater(a.device.sync(), throwsA(isA<ServerUnreachableException>()));
      ledger = await a.device.ledger.ledger();
      expect(ledger.linesToValidate, hasLength(27 - 6));

      // The server comes back (same data, another port here).
      final restarted = await LocalServer.start(dataDir: server.dataDir);
      addTearDown(restarted.stop);
      for (final d in [a, b]) {
        d.device.pairing = await d.device.server.changeAddress(d.device.pairing!, restarted.address);
      }
      await a.device.sync();
      await b.device.sync();
      final there = await b.device.ledger.ledger();
      expect(there.linesToValidate, hasLength(21));
      expect(there.transactions[rent.id]!.line!.categoryId, 'rent');
      expect(there.views.of(2026, ViewKind.cash)!.totals, ledger.views.of(2026, ViewKind.cash)!.totals);
    },
  );

  test('the original PDF is fetched by its fingerprint; a rebuilt server says it has none, without error', () async {
    final server = await LocalServer.start();
    addTearDown(server.stop);
    final a = await pairedDevice(server, 'Ordinateur', createAccount: true);
    addTearDown(a.close);
    await a.start();
    await a.import(jan.pdf);
    final p = a.device.pairing!;
    final client = ServerClient(p.address, pin: p.fingerprint, deviceKey: p.deviceKey);
    addTearDown(client.close);
    expect(await client.statementPdf(jan.fingerprint), jan.pdf);
    expect(await client.statementPdf(feb.fingerprint), isNull, reason: 'never sent');

    final rebuilt = await LocalServer.start();
    addTearDown(rebuilt.stop);
    await a.device.server.forget();
    await a.device.pair(rebuilt);
    final q = a.device.pairing!;
    final other = ServerClient(q.address, pin: q.fingerprint, deviceKey: q.deviceKey);
    addTearDown(other.close);
    expect(await other.statementPdf(jan.fingerprint), isNull);
    expect((await other.health()).importFormats, ['postfinance']);
  });
}

/// The PDF of a statement of the test set.
List<int> statementPdf(String name) => fixtureStatement(name).pdf;
