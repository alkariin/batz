import 'dart:math';

import 'package:batz/domain/calendar_date.dart';
import 'package:batz/domain/ledger/account.dart';
import 'package:batz/domain/ledger/category.dart';
import 'package:batz/domain/ledger/ledger.dart';
import 'package:batz/domain/ledger/redistribution.dart';
import 'package:batz/domain/ledger/rule.dart';
import 'package:batz/domain/ledger/share_classification.dart';
import 'package:batz/domain/ledger/transaction.dart';
import 'package:batz/domain/period_model.dart';

/// The years a random ledger has amounts in: trees for 2026 and 2027, none
/// for 2028 and 2029, shown with the copy of 2027.
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
///   months, one as a transfer) or without proposal;
/// - redistribution rules: in 2026, 10 % of « Nourriture » to « Charges »
///   and 25 % of « Salaire » to « Primes », copied in 2027 with 33.33 % of
///   « Assurance ménage » to « Sorties »; a rule between natures that
///   cannot apply;
/// - refunds attached to an expense of either year, one link in five broken;
/// - answers for the shares of 2026 lines in 2027 and later years, some
///   given for another category of origin;
/// - lines whose amount differs from their transaction's, as a merge can
///   leave them.
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
    // One line in fifteen was written by another device with another
    // amount than the transaction's.
    final gap = r.nextInt(15) == 0 ? (amount > 0 ? 1 : -1) * (1 + r.nextInt(500)) : 0;
    lines.add(
      TransactionLine(
        id: '$id-l',
        transactionId: id,
        categoryId: category.id,
        amount: amount + gap,
        periodStart: start,
        periodEnd: end,
      ),
    );
  }
  // Refunds: half of the money that came in to an expense category is
  // attached to an expense of either year; one link in five leads nowhere.
  bool isExpense(String? categoryId) {
    final category = ledgerOfTrees.categories[categoryId];
    return category != null && ledgerOfTrees.trees[category.year]!.natureOf(category.id) == CategoryNature.expense;
  }

  final expenseLines = [
    for (final line in lines)
      if (line.amount < 0 && isExpense(line.categoryId)) line.id,
  ];
  var attached = 0;
  for (final (i, line) in lines.indexed) {
    if (line.amount <= 0 || !isExpense(line.categoryId) || expenseLines.isEmpty || r.nextBool()) continue;
    lines[i] = TransactionLine(
      id: line.id,
      transactionId: line.transactionId,
      categoryId: line.categoryId,
      amount: line.amount,
      periodStart: line.periodStart,
      periodEnd: line.periodEnd,
      refundedLineId: attached++ % 5 == 0 ? 'missing' : expenseLines[r.nextInt(expenseLines.length)],
    );
  }

  RedistributionRule redistribution(String id, int year, String source, String target, int basisPoints) =>
      RedistributionRule(id: id, year: year, sourceId: source, targetId: target, basisPoints: basisPoints);
  final redistributions = [
    redistribution('food-charges', 2026, 'food', 'charges', 1000),
    redistribution('salary-bonus', 2026, 'salary', 'bonus', 2500),
    redistribution('mismatch', 2026, 'insurance', 'salary', 500),
    for (final (id, source, target, bp) in [
      ('food-charges', 'food', 'charges', 1000),
      ('salary-bonus', 'salary', 'bonus', 2500),
    ])
      redistribution(
        copiedRedistributionId(id, 2027),
        2027,
        copiedCategoryId(source, 2027),
        copiedCategoryId(target, 2027),
        bp,
      ),
    redistribution('household-leisure', 2027, 'household', copiedCategoryId('leisure', 2027), 3333),
  ];
  // Answers: « Loisirs » to « Sorties », « Assurances » to « Assurance
  // ménage », for half of the lines concerned; one in four was given for
  // another category and no longer holds.
  final answers = <ShareClassification>[];
  for (final line in lines) {
    final target = switch (line.categoryId) {
      'leisure' => copiedCategoryId('leisure', 2027),
      'insurance' => 'household',
      _ => null,
    };
    if (target == null || r.nextBool()) continue;
    for (final year in [2027, 2028, 2029]) {
      answers.add(
        ShareClassification(
          id: shareClassificationId(line.id, year),
          lineId: line.id,
          year: year,
          categoryId: year == 2027 ? target : copiedCategoryId(target, year),
          originCategoryId: r.nextInt(4) == 0 ? 'food' : line.categoryId!,
        ),
      );
    }
  }

  return Ledger(
    accounts: accounts,
    categories: categories,
    transactions: list,
    lines: lines,
    rules: rules,
    redistributions: redistributions,
    shareClassifications: answers,
  );
}
