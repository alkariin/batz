import 'package:batz/domain/calendar_date.dart';
import 'package:batz/domain/ledger/account.dart';
import 'package:batz/domain/ledger/ledger_exception.dart';
import 'package:batz/domain/ledger/proposal.dart';
import 'package:batz/domain/ledger/statement.dart';
import 'package:batz/domain/ledger/transaction.dart';
import 'package:batz/domain/views/balances.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/ledger_fixture.dart';
import '../../support/ledger_harness.dart';

/// A line of a Neon export, as the server reads it.
ExtractedLine line(CalendarDate date, int amount, String text) =>
    ExtractedLine(date: date, amount: amount, rawText: text, label: text.split('\n').first);

/// An export of the lines [lines], oldest first, as the server answers it.
ExtractedStatement export(List<ExtractedLine> lines) => ExtractedStatement(
  format: 'neon',
  iban: '',
  currency: 'CHF',
  periodStart: lines.first.date,
  periodEnd: lines.last.date,
  lines: lines,
);

/// The lines of the fictitious export of the server's test set.
final early = [
  line(d(2026, 1, 5), -2390, 'Kiosque du Port\n-180.00 DKK'),
  line(d(2026, 2, 20), -4500, 'Boulangerie Fictive'),
  line(d(2026, 3, 2), 50000, 'Titulaire Fictif\nVersement depuis PostFinance'),
  line(d(2026, 3, 10), -850, 'Musée Imaginaire\n-9.00 EUR'),
  line(d(2026, 3, 10), -850, 'Musée Imaginaire\n-9.00 EUR'),
  line(d(2026, 3, 14), -1240, 'Café des Essais'),
];

/// The same export, made later: two lines more.
final later = [
  ...early,
  line(d(2026, 3, 20), -850, 'Musée Imaginaire\n-9.00 EUR'),
  line(d(2026, 3, 25), -3000, 'Librairie Inventée'),
];

void main() {
  late LedgerHarness h;
  setUp(() async {
    h = await LedgerHarness.open();
    await seedLedger(h);
    await h.apply(
      (l) => l.createAccount(
        'neon',
        const AccountDraft(name: 'Neon', type: AccountType.privateAccount, importFormat: ImportFormat.neon),
      ),
    );
  });
  tearDown(() => h.close());

  Future<StatementImport> import(List<ExtractedLine> lines, String fingerprint, int balance, CalendarDate today) async {
    final result = (await h.ledger()).importStatement(
      'neon',
      export(lines),
      fingerprint: fingerprint,
      closingBalance: balance,
      today: today,
    );
    await h.repository.write(result.modification);
    return result;
  }

  Future<StatementRefusedException> refusal(
    List<ExtractedLine> lines,
    String fingerprint, {
    int? balance,
    required CalendarDate today,
  }) async {
    final ledger = await h.ledger();
    late StatementRefusedException refused;
    expect(
      () => balance == null
          ? ledger.previewImport('neon', export(lines), fingerprint: fingerprint, today: today)
          : ledger.importStatement(
              'neon',
              export(lines),
              fingerprint: fingerprint,
              closingBalance: balance,
              today: today,
            ),
      throwsA(isA<StatementRefusedException>().having((e) => refused = e, 'refusal', anything)),
    );
    return refused;
  }

  test('the first export sets the starting balance from the balance typed; identical lines stay two', () async {
    final ledger = await h.ledger();
    final preview = ledger.previewImport('neon', export(early), fingerprint: 'a' * 64, today: d(2026, 3, 15));
    expect((preview.newLines, preview.first, preview.previousClosing), (6, true, null));

    final result = await import(early, 'a' * 64, 120000, d(2026, 3, 15));
    expect(result.first, isTrue);
    final after = await h.ledger();
    final statement = after.statements[result.statementId]!;
    expect((statement.format, statement.iban), ('neon', ''));
    expect(
      (statement.periodStart, statement.periodEnd),
      (d(2026, 1, 5), d(2026, 3, 15)),
      reason: 'to the day of import',
    );
    final sum = early.fold(0, (total, l) => total + l.amount);
    expect((statement.openingBalance, statement.closingBalance), (120000 - sum, 120000));

    final lines = after.linesOf(statement.id);
    expect(lines.map((t) => t.amount), early.map((l) => l.amount));
    expect(lines.map((t) => t.status).toSet(), {TransactionStatus.toValidate});
    expect(lines[3].id, isNot(lines[4].id), reason: 'two identical payments of a day');
    expect(lines[3].id, exportedTransactionId('neon', d(2026, 3, 10), -850, 'Musée Imaginaire\n-9.00 EUR', 0));
    expect(lines[4].id, exportedTransactionId('neon', d(2026, 3, 10), -850, 'Musée Imaginaire\n-9.00 EUR', 1));
    expect(lines[0].description, 'Kiosque du Port');

    // The account enters the wealth the day before its first line.
    final balances = after.balances.of('neon');
    expect(balances.balanceAt(d(2026, 1, 4)), 120000 - sum);
    expect(balances.balanceAt(d(2026, 3, 15)), 120000);
  });

  test('a later export of the year brings only its new lines, if they lead to the balance typed', () async {
    await import(early, 'a' * 64, 120000, d(2026, 3, 15));
    var ledger = await h.ledger();
    final preview = ledger.previewImport('neon', export(later), fingerprint: 'b' * 64, today: d(2026, 3, 29));
    expect((preview.newLines, preview.first, preview.previousClosing), (2, false, 120000));

    final refused = await refusal(later, 'b' * 64, balance: 116000, today: d(2026, 3, 29));
    expect(refused.error, LedgerError.statementBalanceMismatch);
    expect((refused.foundBalance, refused.expectedBalance, refused.count), (116000, 116150, 2));

    final result = await import(later, 'b' * 64, 116150, d(2026, 3, 29));
    expect(result.first, isFalse);
    ledger = await h.ledger();
    final statement = ledger.statements[result.statementId]!;
    expect((statement.periodStart, statement.periodEnd), (d(2026, 3, 16), d(2026, 3, 29)));
    expect((statement.openingBalance, statement.closingBalance), (120000, 116150));
    expect(ledger.linesOf(statement.id).map((t) => (t.date, t.amount)), [
      (d(2026, 3, 20), -850),
      (d(2026, 3, 25), -3000),
    ]);
    expect(ledger.transactions.values.where((t) => t.accountId == 'neon'), hasLength(8), reason: 'nothing twice');
    expect(ledger.balances.of('neon').balanceAt(d(2026, 3, 29)), 116150);

    // A line booked late, dated within an earlier import, is new too.
    final backdated = [...later, line(d(2026, 3, 12), -500, 'Kiosque du Port')];
    final last = await h.ledger();
    expect(last.previewImport('neon', export(backdated), fingerprint: 'c' * 64, today: d(2026, 4, 2)).newLines, 1);
  });

  test('refusals: the same file, no new line, an import the same day, lines before the first import', () async {
    await import(early, 'a' * 64, 120000, d(2026, 3, 15));
    expect((await refusal(early, 'a' * 64, today: d(2026, 3, 20))).error, LedgerError.statementAlreadyImported);
    expect((await refusal(early, 'f' * 64, today: d(2026, 3, 20))).error, LedgerError.statementNoNewLines);
    expect((await refusal(later, 'b' * 64, today: d(2026, 3, 15))).error, LedgerError.statementImportedToday);

    final before = await refusal(
      [line(d(2025, 12, 30), -100, 'Kiosque du Port'), ...later],
      'b' * 64,
      today: d(2026, 3, 29),
    );
    expect(before.error, LedgerError.statementLinesBeforeFirst);
    expect((before.foundStart, before.expectedStart), (d(2025, 12, 30), d(2026, 1, 5)));

    final pdf = (await h.ledger());
    expect(
      () => pdf.importStatement('bank', export(early), fingerprint: 'e' * 64, closingBalance: 0, today: d(2026, 3, 29)),
      throwsA(isA<StatementRefusedException>().having((e) => e.error, 'error', LedgerError.statementOtherFormat)),
    );
    expect(
      () => pdf.importStatement('neon', export(later), fingerprint: 'b' * 64, today: d(2026, 3, 29)),
      throwsA(isA<StatementRefusedException>().having((e) => e.error, 'error', LedgerError.statementBalanceRequired)),
    );
  });

  test('the latest import deleted, a newer export brings its lines back, reset', () async {
    await import(early, 'a' * 64, 120000, d(2026, 3, 15));
    final second = await import(later, 'b' * 64, 116150, d(2026, 3, 29));
    var ledger = await h.ledger();
    final museum = ledger.linesOf(second.statementId).first;
    await h.apply(
      (l) => l.classify(museum.id, Classification.category('food', periodStart: museum.date, periodEnd: museum.date)),
    );
    await h.apply((l) => l.deleteLastStatement(second.statementId));
    ledger = await h.ledger();
    expect(ledger.transactions.containsKey(museum.id), isFalse);

    final again = [...later, line(d(2026, 3, 30), -1000, 'Café des Essais')];
    final third = await import(again, 'c' * 64, 115150, d(2026, 3, 31));
    ledger = await h.ledger();
    final back = ledger.transactions[museum.id]!;
    expect(
      (back.status, back.statementId, back.lines.isEmpty),
      (TransactionStatus.toValidate, third.statementId, true),
    );
    expect(ledger.linesOf(third.statementId), hasLength(3));
  });
}
