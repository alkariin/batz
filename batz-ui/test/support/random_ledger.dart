import 'dart:math';

import 'package:batz/domain/calendar_date.dart';
import 'package:batz/domain/ledger/account.dart';
import 'package:batz/domain/ledger/category.dart';
import 'package:batz/domain/ledger/ledger.dart';
import 'package:batz/domain/ledger/rule.dart';
import 'package:batz/domain/ledger/transaction.dart';
import 'package:batz/domain/period_model.dart';

/// The years a random ledger has amounts in: trees for 2026 and 2027, none
/// for 2028 and 2029, shown with the copy of 2027 (decision H6).
const randomYears = [2026, 2027, 2028, 2029];

/// A ledger drawn at random from [r], built in memory as the repository
/// would read it, with what the year views must cope with:
///
/// - two trees: 2026, and 2027 its copy where « Loisirs » became
///   « Sorties », « Assurances » became a group and « Impôts » was added;
/// - manual expenses and incomes over periods from one day to three years,
///   between 1.1.2026 and 31.12.2029;
/// - transfers; validated lines without category or in a category gone;
/// - imported lines to validate, proposed by rules (some over twelve
///   months, one as a transfer) or without proposal.
Ledger randomLedger(Random r, {int transactions = 300}) {
  final categories = <Category>[];
  void add(String id, int year, String name, String? parent, {CategoryNature? nature, int position = 0}) =>
      categories.add(Category(id: id, year: year, name: name, parentId: parent, nature: nature, position: position));

  for (final year in [2026, 2027]) {
    String id(String base) => year == 2026 ? base : copiedCategoryId(base, 2027);
    final income = defaultGroupId(2026, CategoryNature.income), expenses = defaultGroupId(2026, CategoryNature.expense);
    add(id(income), year, 'Revenus', null, nature: CategoryNature.income);
    add(id(expenses), year, 'Dépenses', null, nature: CategoryNature.expense, position: 1);
    add(id('salary'), year, 'Salaire', id(income));
    add(id('bonus'), year, 'Primes', id(income), position: 1);
    add(id('housing'), year, 'Logement', id(expenses));
    add(id('rent'), year, 'Loyer', id('housing'));
    add(id('charges'), year, 'Charges', id('housing'), position: 1);
    add(id('food'), year, 'Nourriture', id(expenses), position: 1);
    add(id('insurance'), year, 'Assurances', id(expenses), position: 2);
    add(id('leisure'), year, year == 2026 ? 'Loisirs' : 'Sorties', id(expenses), position: 3);
  }
  add('household', 2027, 'Assurance ménage', copiedCategoryId('insurance', 2027));
  add('taxes', 2027, 'Impôts', copiedCategoryId(defaultGroupId(2026, CategoryNature.expense), 2027), position: 4);

  final ledgerOfTrees = Ledger(categories: categories);
  final accounts = [
    const Account(
      id: 'bank',
      name: 'PostFinance',
      type: AccountType.privateAccount,
      importFormat: ImportFormat.postfinance,
    ),
    const Account(id: 'cash', name: 'Espèces', type: AccountType.cash),
    const Account(id: 'savings', name: 'Épargne', type: AccountType.savings),
  ];
  final rules = [
    MappingRule(id: 'r-food', year: 2026, keywords: ['épicerie'], targetCategoryId: 'food'),
    MappingRule(
      id: 'r-insurance',
      year: 2026,
      keywords: ['assurance'],
      targetCategoryId: 'insurance',
      periodModel: PeriodModel.monthsAfter,
      periodMonths: 12,
    ),
    MappingRule(id: 'r-savings', year: 2026, keywords: ['épargne'], targetAccountId: 'savings'),
    MappingRule(
      id: 'r-leisure',
      year: 2027,
      keywords: ['cinéma'],
      targetCategoryId: copiedCategoryId('leisure', 2027),
      periodModel: PeriodModel.nextMonth,
    ),
  ];

  final list = <LedgerTransaction>[];
  final lines = <TransactionLine>[];
  CalendarDate day(int year) => CalendarDate(year, 1 + r.nextInt(12), 1 + r.nextInt(28));
  final last = CalendarDate(2029, 12, 31);
  for (var i = 0; i < transactions; i++) {
    final id = 't$i';
    final date = day(2026 + r.nextInt(2));
    final roll = r.nextInt(100);
    if (roll < 10) {
      list.add(
        LedgerTransaction(
          id: id,
          accountId: 'cash',
          date: date,
          amount: -(1 + r.nextInt(50000)),
          counterpartAccountId: 'savings',
        ),
      );
      continue;
    }
    if (roll < 25) {
      // An imported line to validate: proposed by a rule, or not.
      final text = [
        'Épicerie du Coin',
        'Assurance Fictive',
        'Compte épargne',
        'Cinéma Inventé',
        'Kiosque',
      ][r.nextInt(5)];
      list.add(
        LedgerTransaction(
          id: id,
          accountId: 'bank',
          date: date,
          amount: (r.nextInt(10) == 0 ? 1 : -1) * (1 + r.nextInt(80000)),
          status: TransactionStatus.toValidate,
          rawText: 'ACHAT\n$text\nFictiville',
          statementId: 's${date.year}',
          statementRank: i,
        ),
      );
      continue;
    }
    if (roll < 28) {
      // Validated without a line, or with a line without category or in a
      // category gone: unclassified.
      final amount = -(1 + r.nextInt(9000));
      list.add(LedgerTransaction(id: id, accountId: 'cash', date: date, amount: amount));
      if (r.nextBool()) {
        lines.add(
          TransactionLine(
            id: '$id-l',
            transactionId: id,
            categoryId: r.nextBool() ? null : 'gone',
            amount: amount,
            periodStart: date,
            periodEnd: date,
          ),
        );
      }
      continue;
    }
    final tree = ledgerOfTrees.trees[date.year]!;
    final category = tree.assignable[r.nextInt(tree.assignable.length)];
    final income = tree.natureOf(category.id) == CategoryNature.income;
    final cents = 1 + r.nextInt(r.nextInt(5) == 0 ? 500000 : 20000);
    final amount = (income != (r.nextInt(8) == 0)) ? cents : -cents;
    var start = date, end = date;
    if (r.nextInt(3) == 0) {
      start = date.addDays(-r.nextInt(200));
      if (start.year < 2026) start = CalendarDate(2026, 1, 1);
      end = start.addDays(r.nextInt(3 * 365));
      if (end.isAfter(last)) end = last;
    }
    list.add(LedgerTransaction(id: id, accountId: 'cash', date: date, amount: amount));
    lines.add(
      TransactionLine(
        id: '$id-l',
        transactionId: id,
        categoryId: category.id,
        amount: amount,
        periodStart: start,
        periodEnd: end,
      ),
    );
  }
  return Ledger(accounts: accounts, categories: categories, transactions: list, lines: lines, rules: rules);
}
