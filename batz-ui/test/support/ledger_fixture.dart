import 'package:batz/domain/calendar_date.dart';
import 'package:batz/domain/ledger/account.dart';
import 'package:batz/domain/ledger/category.dart';
import 'package:batz/domain/ledger/transaction.dart';

import 'ledger_harness.dart';

/// Accounts: `bank` (detailed), `private` (a second private account, not
/// detailed), `cash`, `debts`. 2026 tree: Revenus > Salaire; Dépenses >
/// Logement > Loyer, Dépenses > Nourriture.
Future<void> seedLedger(LedgerHarness h) async {
  await h.apply(
    (l) => l.createAccount(
      'bank',
      const AccountDraft(name: 'PostFinance', type: AccountType.privateAccount, importFormat: ImportFormat.postfinance),
    ),
  );
  await h.apply((l) => l.createAccount('private', const AccountDraft(name: 'UBS', type: AccountType.privateAccount)));
  await h.apply((l) => l.createAccount('cash', const AccountDraft(name: 'Espèces', type: AccountType.cash)));
  await h.apply((l) => l.createAccount('debts', const AccountDraft(name: 'Dettes', type: AccountType.debts)));
  await h.apply((l) => l.createTree(2026));
  await h.apply(
    (l) => l.addCategory('salary', year: 2026, name: 'Salaire', parentId: defaultGroupId(2026, CategoryNature.income)),
  );
  final expenses = defaultGroupId(2026, CategoryNature.expense);
  await h.apply((l) => l.addCategory('housing', year: 2026, name: 'Logement', parentId: expenses));
  await h.apply((l) => l.addCategory('rent', year: 2026, name: 'Loyer', parentId: 'housing'));
  await h.apply((l) => l.addCategory('food', year: 2026, name: 'Nourriture', parentId: expenses));
}

CalendarDate d(int year, int month, int day) => CalendarDate(year, month, day);

EntryDraft entry({
  String account = 'cash',
  CalendarDate? date,
  int cents = 1000,
  Direction direction = Direction.outflow,
  String category = 'food',
  String description = '',
  CalendarDate? periodStart,
  CalendarDate? periodEnd,
}) => EntryDraft(
  accountId: account,
  date: date ?? d(2026, 5, 10),
  cents: cents,
  direction: direction,
  categoryId: category,
  description: description,
  periodStart: periodStart,
  periodEnd: periodEnd,
);

TransferDraft transfer({String from = 'private', String to = 'cash', int cents = 30000, CalendarDate? date}) =>
    TransferDraft(fromAccountId: from, toAccountId: to, date: date ?? d(2026, 5, 12), cents: cents);
