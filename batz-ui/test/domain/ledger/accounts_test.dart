import 'package:batz/domain/journal/journal_entry.dart';
import 'package:batz/domain/ledger/account.dart';
import 'package:batz/domain/ledger/ledger.dart';
import 'package:batz/domain/ledger/ledger_exception.dart';
import 'package:flutter_test/flutter_test.dart';

Matcher refusedWith(LedgerError error) => throwsA(isA<LedgerException>().having((e) => e.error, 'error', error));

const _bank = Account(
  id: 'bank',
  name: 'PostFinance',
  type: AccountType.privateAccount,
  importFormat: ImportFormat.postfinance,
);
const _cash = Account(id: 'cash', name: 'Espèces', type: AccountType.cash);

Map<String, Object?> fields(Modification m) => {for (final c in m.changes) c.field: c.value};

void main() {
  test('an account is created with all its fields', () {
    final m = Ledger.empty.createAccount('a1', const AccountDraft(name: '  Espèces ', type: AccountType.cash));
    expect(m.changes.map((c) => (c.entity, c.recordId)).toSet(), {('account', 'a1')});
    expect(fields(m), {'name': 'Espèces', 'type': 'cash', 'importFormat': null, 'archived': false, 'declared': false});
  });

  test('the name is required', () {
    expect(
      () => Ledger.empty.createAccount('a1', const AccountDraft(name: '  ', type: AccountType.cash)),
      refusedWith(LedgerError.nameRequired),
    );
  });

  test('an account is detailed if and only if import is enabled', () {
    expect(_bank.isDetailed, isTrue);
    expect(_cash.isDetailed, isFalse);
  });

  test('a second detailed account is refused, on creation and on modification', () {
    final ledger = Ledger(accounts: [_bank, _cash]);
    const detailed = AccountDraft(
      name: 'UBS',
      type: AccountType.privateAccount,
      importFormat: ImportFormat.postfinance,
    );
    expect(() => ledger.createAccount('a3', detailed), refusedWith(LedgerError.secondDetailedAccount));
    expect(
      () => ledger.updateAccount(
        'cash',
        const AccountDraft(name: 'Espèces', type: AccountType.cash, importFormat: ImportFormat.postfinance),
      ),
      refusedWith(LedgerError.secondDetailedAccount),
    );
    // The detailed account itself can still be modified, and an archived
    // detailed account still counts.
    expect(fields(ledger.updateAccount('bank', AccountDraft.of(_bank)))['importFormat'], 'postfinance');
    final archived = Ledger(
      accounts: [
        const Account(
          id: 'bank',
          name: 'Old',
          type: AccountType.privateAccount,
          importFormat: ImportFormat.postfinance,
          archived: true,
        ),
      ],
    );
    expect(() => archived.createAccount('a3', detailed), refusedWith(LedgerError.secondDetailedAccount));
  });

  test('an unused account is deleted', () {
    final removal = Ledger(accounts: [_cash]).removeAccount('cash');
    expect(removal.archives, isFalse);
    expect(removal.modification.changes.single.field, deletedField);
  });

  test('an unknown account cannot be modified or removed', () {
    expect(() => Ledger.empty.updateAccount('x', AccountDraft.of(_cash)), refusedWith(LedgerError.unknownAccount));
    expect(() => Ledger.empty.removeAccount('x'), refusedWith(LedgerError.unknownAccount));
  });

  test('until the user moves one, accounts are sorted by type then name, archived ones last', () {
    final ledger = Ledger(
      accounts: [
        const Account(id: '1', name: 'zèbre', type: AccountType.other),
        const Account(id: '2', name: 'Ancien', type: AccountType.other, archived: true),
        const Account(id: '3', name: 'Banque', type: AccountType.other),
        const Account(id: '4', name: 'Tirelire', type: AccountType.savings),
      ],
    );
    expect(ledger.sortedAccounts.map((a) => a.id), ['4', '3', '1', '2']);
  });

  test('an account moves up or down among the active ones, or among the archived ones; every account of the '
      'list gets its position', () {
    var ledger = Ledger(
      accounts: [
        const Account(id: 'a', name: 'A', type: AccountType.privateAccount),
        const Account(id: 'b', name: 'B', type: AccountType.savings),
        const Account(id: 'c', name: 'C', type: AccountType.cash),
        const Account(id: 'old', name: 'Old', type: AccountType.other, archived: true),
      ],
    );
    Ledger apply(Modification m) {
      final byId = {for (final a in ledger.accounts.values) a.id: a};
      for (final change in m.changes) {
        expect((change.entity, change.field), (AccountFields.entity, AccountFields.position));
        final a = byId[change.recordId]!;
        byId[a.id] = Account(
          id: a.id,
          name: a.name,
          type: a.type,
          archived: a.archived,
          position: change.value! as int,
        );
      }
      return Ledger(accounts: byId.values);
    }

    expect(ledger.reorderAccount('a', -1), isNull, reason: 'already first');
    expect(ledger.reorderAccount('old', 1), isNull, reason: 'alone among the archived ones');
    final move = ledger.reorderAccount('c', -1)!;
    expect({for (final c in move.changes) c.recordId: c.value}, {'a': 0, 'c': 1, 'b': 2});
    ledger = apply(move);
    expect(ledger.sortedAccounts.map((a) => a.id), ['a', 'c', 'b', 'old']);
    ledger = apply(ledger.reorderAccount('a', 1)!);
    expect(ledger.sortedAccounts.map((a) => a.id), ['c', 'a', 'b', 'old']);
    expect(ledger.reorderAccount('b', 1), isNull, reason: 'already last of the active ones');
    // A new account has no position: it comes after the others.
    ledger = Ledger(
      accounts: [
        ...ledger.accounts.values,
        const Account(id: 'new', name: '0', type: AccountType.privateAccount),
      ],
    );
    expect(ledger.sortedAccounts.map((a) => a.id), ['c', 'a', 'b', 'new', 'old']);
    expect(() => ledger.reorderAccount('x', 1), refusedWith(LedgerError.unknownAccount));
  });

  test('the form writes whether the account is declared in the tax return, never its position', () {
    final ledger = Ledger(
      accounts: [const Account(id: 'a', name: 'A', type: AccountType.savings, position: 3)],
    );
    final m = ledger.updateAccount('a', const AccountDraft(name: 'A', type: AccountType.savings, declared: true));
    expect(fields(m)[AccountFields.declared], isTrue);
    expect(fields(m).containsKey(AccountFields.position), isFalse);
  });
}
