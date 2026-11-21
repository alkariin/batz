import 'package:batz/data/ledger/ledger_repository.dart';
import 'package:batz/domain/calendar_date.dart';
import 'package:batz/domain/journal/journal_entry.dart';
import 'package:batz/domain/ledger/account.dart';
import 'package:batz/domain/ledger/category.dart';
import 'package:batz/domain/ledger/redistribution.dart';
import 'package:batz/domain/ledger/rule.dart';
import 'package:batz/domain/ledger/statement.dart';
import 'package:batz/domain/ledger/transaction.dart';
import 'package:batz/domain/period_model.dart';

/// The data of a heavy user over five years (2026 to 2030), invented: what
/// the performance tests load (step 4.0 of phase 4).
///
/// - Accounts: `bank` (detailed), `cash`, `savings`.
/// - One tree per year, each the copy of the year before: « Revenus » with
///   two categories, « Dépenses » with 8 groups of 5 categories.
/// - 40 mapping rules per year, 200 in all, and 4 redistribution rules per
///   year, copied with the trees.
/// - 60 monthly statements of 160 lines (9 600 imported transactions): a
///   salary and 159 purchases from 60 shops, 39 of which have a rule. Every
///   line is validated except those of the last statement, which are to
///   validate; one purchase in 20 concerns twelve months.
/// - 300 manual expenses on `cash`, one in 10 over twelve months, and 100
///   refunds attached to imported purchases.
///
/// The records are written as the operations of the app write them, field
/// by field, without going through the checks of each operation: importing
/// 60 statements one by one would take most of the test.
class LargeLedger {
  static const firstYear = 2026;
  static const years = 5;
  static const linesPerStatement = 160;
  static const manualEntries = 300;
  static const refunds = 100;
  static const shops = 60;
  static const shopsWithRule = 39;
  static const groups = 8;
  static const categoriesPerGroup = 5;

  static int get transactions => years * 12 * linesPerStatement + manualEntries + refunds;

  /// The identifier in [year] of the category [id] of the first year.
  static String categoryIn(String id, int year) {
    var current = id;
    for (var y = firstYear + 1; y <= year; y++) {
      current = copiedCategoryId(current, y);
    }
    return current;
  }

  static String leaf(int group, int index) => 'cat-$group-$index';
  static const salary = 'cat-salary';
  static const otherIncome = 'cat-other-income';

  /// The category of the purchases from [shop].
  static String shopCategory(int shop) => leaf(shop % groups, shop ~/ groups % categoriesPerGroup);

  static String shopName(int shop) => 'Shop${shop.toString().padLeft(4, '0')}';

  /// Every change, in modifications the journal accepts.
  static List<Modification> modifications() {
    final changes = <FieldChange>[];
    void set(String entity, String id, Map<String, Object?> fields) {
      for (final field in fields.entries) {
        changes.add(FieldChange(entity, id, field.key, field.value));
      }
    }

    for (final (id, name, type, format) in [
      ('bank', 'PostFinance', AccountType.privateAccount, ImportFormat.postfinance),
      ('cash', 'Espèces', AccountType.cash, null),
      ('savings', 'Épargne', AccountType.savings, null),
    ]) {
      set(AccountFields.entity, id, {
        AccountFields.name: name,
        AccountFields.type: type.name,
        AccountFields.importFormat: format?.name,
        AccountFields.archived: false,
      });
    }

    // The tree of the first year, then its copies.
    final income = defaultGroupId(firstYear, CategoryNature.income);
    final expenses = defaultGroupId(firstYear, CategoryNature.expense);
    final tree = <(String, String, String?, CategoryNature?, int)>[
      (income, 'Revenus', null, CategoryNature.income, 0),
      (salary, 'Salaire', income, null, 0),
      (otherIncome, 'Autres revenus', income, null, 1),
      (expenses, 'Dépenses', null, CategoryNature.expense, 1),
      for (var g = 0; g < groups; g++) ...[
        ('group-$g', 'Groupe $g', expenses, null, g),
        for (var c = 0; c < categoriesPerGroup; c++) (leaf(g, c), 'Poste $g.$c', 'group-$g', null, c),
      ],
    ];
    final rules = <(String, List<String>, String)>[
      ('rule-salary', ['Employeur Exemple'], salary),
      for (var s = 0; s < shopsWithRule; s++) ('rule-shop-$s', [shopName(s)], shopCategory(s)),
    ];
    for (var year = firstYear; year < firstYear + years; year++) {
      for (final (id, name, parent, nature, position) in tree) {
        set(CategoryFields.entity, categoryIn(id, year), {
          CategoryFields.year: year,
          CategoryFields.name: name,
          CategoryFields.parentId: parent == null ? null : categoryIn(parent, year),
          CategoryFields.nature: nature?.name,
          CategoryFields.position: position,
        });
      }
      for (var g = 0; g < 4; g++) {
        var ruleId = 'redistribution-$g';
        for (var y = firstYear + 1; y <= year; y++) {
          ruleId = copiedRedistributionId(ruleId, y);
        }
        set(RedistributionFields.entity, ruleId, {
          RedistributionFields.year: year,
          RedistributionFields.sourceCategoryId: categoryIn(leaf(g, 0), year),
          RedistributionFields.targetCategoryId: categoryIn(leaf(g, 1), year),
          RedistributionFields.basisPoints: 1000 * (g + 1),
        });
      }
      for (final (id, keywords, target) in rules) {
        var ruleId = id;
        for (var y = firstYear + 1; y <= year; y++) {
          ruleId = copiedRuleId(ruleId, y);
        }
        set(RuleFields.entity, ruleId, {
          RuleFields.year: year,
          RuleFields.keywords: encodeKeywords(keywords),
          RuleFields.targetCategoryId: categoryIn(target, year),
          RuleFields.targetAccountId: null,
          RuleFields.periodModel: null,
          RuleFields.periodMonths: null,
        });
      }
    }

    // Statements, imported then validated.
    var balance = 2000000;
    final months = years * 12;
    for (var m = 0; m < months; m++) {
      final year = firstYear + m ~/ 12, month = m % 12 + 1;
      final start = CalendarDate(year, month, 1);
      final end = CalendarDate(year, month, CalendarDate.daysInMonth(year, month));
      final fingerprint = m.toRadixString(16).padLeft(64, '0');
      final statement = statementId('bank', fingerprint);
      final last = m == months - 1;
      final opening = balance;
      for (var rank = 0; rank < linesPerStatement; rank++) {
        final date = CalendarDate(year, month, 1 + rank % 28);
        final shop = (rank * 7 + m) % shops;
        final isSalary = rank == 0;
        final amount = isSalary ? 650000 : -(1000 + rank * 37 % 9000);
        final raw = isSalary
            ? "CRÉDIT\nDONNEUR D'ORDRE:\nEmployeur Exemple SA\nSalaire ${month.toString().padLeft(2, '0')}.$year"
            : 'ACHAT/SERVICE DU ${date.day.toString().padLeft(2, '0')}.${month.toString().padLeft(2, '0')}.$year\n'
                  'CARTE NO XXXX0000\n${shopName(shop)}\nFictiville';
        final id = importedTransactionId(statement, rank);
        balance += amount;
        set(TransactionFields.entity, id, {
          TransactionFields.accountId: 'bank',
          TransactionFields.date: date.encode(),
          TransactionFields.amount: amount,
          TransactionFields.rawText: raw,
          TransactionFields.description: isSalary ? 'Employeur Exemple SA' : '${shopName(shop)} Fictiville',
          TransactionFields.status: (last ? TransactionStatus.toValidate : TransactionStatus.validated).name,
          TransactionFields.statementId: statement,
          TransactionFields.statementRank: rank,
        });
        if (last) continue;
        final category = isSalary ? salary : (shop < shopsWithRule ? shopCategory(shop) : leaf(groups - 1, 4));
        final (periodStart, periodEnd) = rank % 20 == 5
            ? periodFor(PeriodModel.monthsAfter, date, months: 12)
            : (date, date);
        set(LineFields.entity, '$id-line', {
          LineFields.transactionId: id,
          LineFields.categoryId: categoryIn(category, year),
          LineFields.amount: amount,
          LineFields.periodStart: periodStart.encode(),
          LineFields.periodEnd: periodEnd.encode(),
        });
      }
      set(StatementFields.entity, statement, {
        StatementFields.accountId: 'bank',
        StatementFields.format: ImportFormat.postfinance.name,
        StatementFields.iban: 'CH0000000000000000000',
        StatementFields.periodStart: start.encode(),
        StatementFields.periodEnd: end.encode(),
        StatementFields.openingBalance: opening,
        StatementFields.closingBalance: balance,
        StatementFields.fingerprint: fingerprint,
      });
    }

    // Manual expenses in cash.
    for (var i = 0; i < manualEntries; i++) {
      final year = firstYear + i % years;
      final date = CalendarDate(year, 1 + i % 12, 1 + i % 28);
      final (periodStart, periodEnd) = i % 10 == 3
          ? periodFor(PeriodModel.monthsAfter, date, months: 12)
          : (date, date);
      final amount = -(500 + i * 113 % 20000);
      set(TransactionFields.entity, 'manual-$i', {
        TransactionFields.accountId: 'cash',
        TransactionFields.date: date.encode(),
        TransactionFields.amount: amount,
        TransactionFields.description: 'Dépense $i',
        TransactionFields.note: '',
        TransactionFields.status: TransactionStatus.validated.name,
        TransactionFields.counterpartAccountId: null,
      });
      set(LineFields.entity, 'manual-$i-line', {
        LineFields.transactionId: 'manual-$i',
        LineFields.categoryId: categoryIn(leaf(i % groups, i % categoriesPerGroup), year),
        LineFields.amount: amount,
        LineFields.periodStart: periodStart.encode(),
        LineFields.periodEnd: periodEnd.encode(),
      });
    }

    // Refunds attached to purchases of the statements already validated.
    for (var i = 0; i < refunds; i++) {
      final m = i % (months - 1), year = firstYear + m ~/ 12;
      final purchase = importedTransactionId(statementId('bank', m.toRadixString(16).padLeft(64, '0')), 1 + i);
      final date = CalendarDate(year, m % 12 + 1, 28);
      set(TransactionFields.entity, 'refund-$i', {
        TransactionFields.accountId: 'cash',
        TransactionFields.date: date.encode(),
        TransactionFields.amount: 500,
        TransactionFields.description: 'Remboursement $i',
        TransactionFields.note: '',
        TransactionFields.status: TransactionStatus.validated.name,
        TransactionFields.counterpartAccountId: null,
      });
      set(LineFields.entity, 'refund-$i-line', {
        LineFields.transactionId: 'refund-$i',
        LineFields.categoryId: categoryIn(leaf(groups - 1, 4), year),
        LineFields.amount: 500,
        LineFields.periodStart: date.encode(),
        LineFields.periodEnd: date.encode(),
        LineFields.refundedLineId: '$purchase-line',
      });
    }

    // Whole records in each modification, as the app writes them.
    final modifications = <Modification>[];
    var current = <FieldChange>[];
    String? record;
    for (final change in changes) {
      final key = '${change.entity}/${change.recordId}';
      if (current.length >= maxModificationChanges - 20 && key != record) {
        modifications.add(Modification(current));
        current = [];
      }
      current.add(change);
      record = key;
    }
    if (current.isNotEmpty) modifications.add(Modification(current));
    return modifications;
  }

  /// Writes every modification to [repository].
  static Future<void> write(LedgerRepository repository) async {
    for (final modification in modifications()) {
      await repository.write(modification);
    }
  }
}
