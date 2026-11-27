import 'package:batz/domain/calendar_date.dart';
import 'package:batz/domain/ledger/account.dart';
import 'package:batz/domain/ledger/ledger.dart';
import 'package:batz/domain/ledger/proposal.dart';
import 'package:batz/domain/ledger/rule.dart';
import 'package:batz/domain/ledger/transaction.dart';
import 'package:batz/domain/views/balances.dart';
import 'package:batz/domain/views/year_view.dart';
import 'package:flutter_test/flutter_test.dart';

CalendarDate d(int month, int day) => CalendarDate(2026, month, day);

const _accounts = [
  Account(id: 'pf', name: 'PostFinance', type: AccountType.privateAccount, importFormat: ImportFormat.postfinance),
  Account(id: 'neon', name: 'Neon', type: AccountType.privateAccount, importFormat: ImportFormat.neon),
  Account(id: 'cash', name: 'Espèces', type: AccountType.cash),
];

/// An imported line of [account].
LedgerTransaction line(
  String id,
  String account,
  CalendarDate date,
  int amount, {
  String? to,
  bool validated = false,
  String text = 'Versement',
}) => LedgerTransaction(
  id: id,
  accountId: account,
  date: date,
  amount: amount,
  counterpartAccountId: validated ? to : null,
  status: validated ? TransactionStatus.validated : TransactionStatus.toValidate,
  rawText: text,
  statementId: 'statement-$account',
  statementRank: 0,
);

Ledger ledgerOf(List<LedgerTransaction> transactions, {List<MappingRule> rules = const []}) =>
    Ledger(accounts: _accounts, transactions: transactions, rules: rules);

void main() {
  test('the two lines of a transfer between imported accounts are paired; each counts on its own account only', () {
    final ledger = ledgerOf([
      line('top-up', 'pf', d(3, 1), -50000, to: 'neon', validated: true),
      line('received', 'neon', d(3, 2), 50000),
    ]);
    expect(ledger.transferPairs, {'top-up': 'received', 'received': 'top-up'});
    expect(ledger.proposals['received'], const PairedTransfer('top-up', Classification.transfer('pf')));
    expect(ledger.validationStateOf(ledger.transactions['received']!), ValidationState.proposed);
    expect(ledger.pairedLineOf(ledger.transactions['received']!)?.id, 'top-up');
    expect(ledger.unpairedTransfers, isEmpty);

    final balances = ledger.balances;
    expect(balances.of('pf').movements.map((m) => (m.transaction.id, m.amount)), [('top-up', -50000)]);
    expect(balances.of('neon').movements.map((m) => (m.transaction.id, m.amount)), [('received', 50000)]);
    final view = ledger.views.of(2026, ViewKind.cash);
    expect(view?.unclassified.total ?? 0, 0, reason: 'a transfer is neither an income nor an expense');
  });

  test('without its other side, a transfer arrives on the other account, and is listed', () {
    final ledger = ledgerOf([
      line('top-up', 'pf', d(3, 1), -50000, to: 'neon', validated: true),
      // Eight days later: too late to be its other side.
      line('late', 'neon', d(3, 9), 50000),
      // The wrong amount.
      line('other', 'neon', d(3, 2), 49999),
    ]);
    expect(ledger.transferPairs, isEmpty);
    expect(ledger.unpairedTransfers.map((t) => t.id), ['top-up']);
    expect(
      ledger.balances.of('neon').movements.map((m) => (m.transaction.id, m.amount, m.arrival)),
      containsAll([('top-up', 50000, true)]),
    );
  });

  test('lines are paired by date, each with the closest one', () {
    final ledger = ledgerOf([
      line('a1', 'pf', d(3, 1), -50000, to: 'neon', validated: true),
      line('a2', 'pf', d(3, 5), -50000, to: 'neon', validated: true),
      line('b2', 'neon', d(3, 6), 50000),
      line('b1', 'neon', d(3, 2), 50000),
      // A line of the other account already a transfer elsewhere is not one.
      line('cash', 'neon', d(3, 1), 50000, to: 'cash', validated: true),
    ]);
    expect(ledger.transferPairs, {'a1': 'b1', 'b1': 'a1', 'a2': 'b2', 'b2': 'a2'});
  });

  test('both lines validated as transfers to each other are paired, as are proposals of the rules', () {
    final rules = [
      MappingRule(id: 'r1', year: 2026, lines: ['neon'], targetAccountId: 'neon'),
      // A rule that would send a line of Neon to Neon proposes nothing for it.
      MappingRule(id: 'r2', year: 2026, lines: ['kiosque'], targetAccountId: 'neon'),
    ];
    final ledger = ledgerOf([
      line('top-up', 'pf', d(3, 1), -50000, text: 'Ordre e-banking Neon'),
      line('received', 'neon', d(3, 3), 50000),
      line('kiosk', 'neon', d(3, 4), -500, text: 'Kiosque'),
      line('a', 'pf', d(4, 1), -2000, to: 'neon', validated: true),
      line('b', 'neon', d(4, 1), 2000, to: 'pf', validated: true),
    ], rules: rules);
    expect(ledger.unusableRules, isEmpty, reason: 'a rule may send to a detailed account');
    expect(ledger.proposals['top-up'], isA<Proposed>());
    expect(ledger.transferPairs['top-up'], 'received');
    expect(ledger.transferPairs['a'], 'b');
    expect(ledger.proposals['kiosk'], isA<UnusableRule>());
  });

  test('validating one side validates the other side to validate with it, once', () {
    final rules = [
      MappingRule(id: 'r1', year: 2026, lines: ['neon'], targetAccountId: 'neon'),
    ];
    var ledger = ledgerOf([
      line('top-up', 'pf', d(3, 1), -50000, text: 'Autre texte'),
      line('received', 'neon', d(3, 2), 50000),
    ], rules: rules);
    final changes = ledger
        .validateLine('top-up', const Classification.transfer('neon'), description: 'Neon', note: '')
        .changes;
    expect({
      for (final c in changes) (c.recordId, c.field): c.value,
    }, containsPair(('received', TransactionFields.status), 'validated'));
    expect(
      {for (final c in changes) (c.recordId, c.field): c.value}[('received', TransactionFields.counterpartAccountId)],
      'pf',
    );

    ledger = ledgerOf([
      line('top-up', 'pf', d(3, 1), -50000, text: 'Ordre Neon'),
      line('received', 'neon', d(3, 2), 50000),
    ], rules: rules);
    final modifications = ledger.confirmProposals(['top-up', 'received']);
    final keys = [
      for (final m in modifications)
        for (final c in m.changes) (c.entity, c.recordId, c.field),
    ];
    expect(keys.toSet().length, keys.length, reason: 'no field written twice');
    expect(keys, containsAll([('transaction', 'received', 'status'), ('transaction', 'top-up', 'status')]));
  });
}
