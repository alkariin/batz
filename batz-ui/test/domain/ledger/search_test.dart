import 'package:batz/domain/calendar_date.dart';
import 'package:batz/domain/ledger/ledger.dart';
import 'package:batz/domain/ledger/proposal.dart';
import 'package:batz/domain/ledger/rule.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/ledger_fixture.dart';
import '../../support/ledger_harness.dart';
import '../../support/statements.dart';

void main() {
  late LedgerHarness h;
  final january = fixtureStatement('2026-01');

  setUp(() async {
    h = await LedgerHarness.open();
    await seedLedger(h);
    await h.apply(
      (l) => l.recordEntry(
        'rent-cash',
        'rent-cash-line',
        entry(category: 'rent', cents: 5000, description: 'Loyer garage'),
      ),
    );
    await h.apply(
      (l) => l.recordEntry(
        'food-2027',
        'food-2027-line',
        entry(date: d(2027, 2, 3), category: l.treeOrPreview(2027).named('Nourriture')!.id),
      ),
    );
    await h.repository.write(
      (await h.ledger()).importStatement('bank', january.statement, fingerprint: january.fingerprint).modification,
    );
    await h.apply(
      (l) => l.createRule('food', const RuleDraft(year: 2026, lines: ['épicerie du coin'], targetCategoryId: 'food')),
    );
  });
  tearDown(() => h.close());

  Future<List<String>> search(TransactionQuery q) async => [for (final t in (await h.ledger()).search(q)) t.id];

  test('every word is required, in the description, the bank text, the category, the accounts or the amount', () async {
    final ledger = await h.ledger();
    expect(await search(const TransactionQuery(text: 'GERANCE   imaginaire')), hasLength(1));
    expect(
      await search(const TransactionQuery(text: 'carte no xxxx0000 boulangerie')),
      hasLength(3),
      reason: 'the raw text is searched',
    );
    expect(await search(const TransactionQuery(text: 'garage')), ['rent-cash']);
    expect(await search(const TransactionQuery(text: 'loyer')), ['rent-cash'], reason: 'by category name');
    expect(await search(const TransactionQuery(text: '1650.00')), hasLength(1), reason: 'by amount');
    expect(
      await search(const TransactionQuery(text: 'espèces')),
      containsAll(['rent-cash', 'food-2027']),
      reason: 'by account',
    );
    expect((await search(const TransactionQuery())).length, ledger.transactions.length);
  });

  test('filters by account, year, month, category (unclassified too) and status', () async {
    final ledger = await h.ledger();
    expect(await search(const TransactionQuery(accountId: 'bank')), hasLength(27));
    expect(await search(const TransactionQuery(year: 2027)), ['food-2027']);
    expect(await search(const TransactionQuery(year: 2026, month: 5)), ['rent-cash']);
    expect(await search(const TransactionQuery(month: 1)), hasLength(27));
    expect(
      await search(const TransactionQuery(categoryName: 'nourriture')),
      hasLength(5 + 1),
      reason: 'proposed lines and 2027 by name',
    );
    expect(await search(const TransactionQuery(categoryName: 'Loyer')), ['rent-cash']);
    final unclassified = await search(const TransactionQuery(categoryName: ''));
    expect(unclassified, hasLength(27 - 5));
    expect(await search(const TransactionQuery(status: StatusFilter.toValidate)), hasLength(27));
    expect(await search(const TransactionQuery(status: StatusFilter.proposed)), hasLength(5));
    expect(await search(const TransactionQuery(status: StatusFilter.toComplete)), hasLength(22));
    expect(
      await search(const TransactionQuery(status: StatusFilter.validated)),
      unorderedEquals(['rent-cash', 'food-2027']),
    );
    expect(ledger.categoryNamesForFilter, ['Loyer', 'Nourriture', 'Salaire']);
  });

  test('a line validated with its description and note, in one modification', () async {
    final line = (await h.ledger()).linesToValidate.first;
    final before = (await h.journal.entries()).length;
    await h.apply(
      (l) => l.validateLine(
        line.id,
        Classification.category('rent', periodStart: CalendarDate(2026, 1, 1), periodEnd: CalendarDate(2026, 1, 31)),
        description: 'Loyer',
        note: 'Janvier',
      ),
    );
    final entries = (await h.journal.entries()).skip(before).toList();
    expect(entries.map((e) => e.hlc).toSet(), hasLength(1), reason: 'one modification');
    final t = (await h.ledger()).transactions[line.id]!;
    expect((t.description, t.note, t.line!.categoryId, t.isValidated), ('Loyer', 'Janvier', 'rent', true));
    expect(await search(const TransactionQuery(text: 'janvier')), [line.id], reason: 'by note');
  });
}
