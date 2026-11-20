import 'package:batz/domain/journal/hlc.dart';
import 'package:batz/domain/journal/journal_entry.dart';
import 'package:batz/domain/ledger/account.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/ledger_harness.dart';

const other = '22222222-0000-4000-8000-000000000000';

JournalEntry remote(int millis, String entity, String id, String field, Object? value) =>
    JournalEntry(Hlc(millis, 0, other), FieldChange(entity, id, field, value));

void main() {
  test('accounts are written through the journal and read back', () async {
    final h = await LedgerHarness.open();
    final ledger = await h.apply(
      (l) => l.createAccount('a1', const AccountDraft(name: 'Espèces', type: AccountType.cash)),
    );
    expect(ledger.accounts['a1'], const Account(id: 'a1', name: 'Espèces', type: AccountType.cash));
    expect(await h.journal.entries(), hasLength(4));
    await h.close();
  });

  test('an incomplete account, or one with an unknown value, is ignored without error', () async {
    final h = await LedgerHarness.open();
    await h.journal.merge([
      remote(1000, 'account', 'only-name', 'name', 'Sans type'),
      remote(1000, 'account', 'future-type', 'name', 'Crypto'),
      remote(1000, 'account', 'future-type', 'type', 'crypto'),
      remote(1000, 'account', 'future-format', 'name', 'UBS'),
      remote(1000, 'account', 'future-format', 'type', 'privateAccount'),
      remote(1000, 'account', 'future-format', 'importFormat', 'ubs'),
      remote(1000, 'account', 'complete', 'name', 'Épargne'),
      remote(1000, 'account', 'complete', 'type', 'savings'),
    ]);
    final ledger = await h.ledger();
    expect(ledger.accounts.keys, ['complete']);
    expect(ledger.accounts['complete']!.archived, isFalse);

    // The missing field arrives later: the account appears.
    await h.journal.merge([remote(2000, 'account', 'only-name', 'type', 'other')]);
    expect((await h.ledger()).accounts.keys, containsAll(['complete', 'only-name']));
    await h.close();
  });

  test('a deleted account disappears', () async {
    final h = await LedgerHarness.open();
    await h.apply((l) => l.createAccount('a1', const AccountDraft(name: 'Espèces', type: AccountType.cash)));
    final ledger = await h.apply((l) => l.removeAccount('a1').modification);
    expect(ledger.accounts, isEmpty);
    await h.close();
  });
}
