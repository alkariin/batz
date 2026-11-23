import 'package:batz/data/ledger/ledger_repository.dart';
import 'package:batz/domain/calendar_date.dart';
import 'package:batz/domain/journal/journal_entry.dart';
import 'package:batz/domain/ledger/account.dart';
import 'package:batz/domain/ledger/balance.dart';
import 'package:batz/domain/ledger/category.dart';
import 'package:batz/domain/ledger/debt.dart';
import 'package:batz/domain/ledger/redistribution.dart';
import 'package:batz/domain/ledger/rule.dart';
import 'package:batz/domain/ledger/share_classification.dart';
import 'package:batz/domain/ledger/statement.dart';
import 'package:batz/domain/ledger/transaction.dart';
import 'package:batz/domain/modules/electricity.dart';
import 'package:batz/domain/modules/salary.dart';
import 'package:batz/domain/modules/subscriptions.dart';
import 'package:batz/domain/modules/taxes.dart';
import 'package:batz/domain/modules/vacations.dart';

/// The data of a heavy user over five years (2026 to 2030), invented: what
/// the performance tests load.
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
/// - In the last year, « Poste 7.4 » is named « Divers »: the shares of the
///   year before that fall in it are to classify, half of them answered.
/// - The wealth: 12 accounts, 100 balances declared on ten of them, every
///   six months from 31.12.2025, and 200 debts over the five years, half
///   of them repaid.
/// - The modules: a group « Modules » with « Vacances », « Électricité »
///   and « Impôts »; 300 vacation lines in cash, one in four over a week,
///   one in ten with a sheet; 60 monthly electricity invoices with their
///   kWh; a salary sheet and a fiscal year for each year; 40 subscriptions
///   of 3 tranches.
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
  static const debts = 200;

  /// The accounts with declared balances, ten balances each.
  static const declaredAccounts = [
    'cash',
    'savings',
    'savings2',
    'pillar3a',
    'pillar3b',
    'pillar2',
    'investments',
    'vehicle',
    'deposit',
    'other',
  ];

  static const lastYear = firstYear + years - 1;

  static const vacationLines = 300;
  static const electricityInvoices = 60;
  static const subscriptions = 40;

  static int get transactions =>
      years * 12 * linesPerStatement + manualEntries + refunds + vacationLines + electricityInvoices;

  static const vacations = 'cat-vacations';
  static const electricity = 'cat-power';
  static const taxes = 'cat-taxes';

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
      ('savings2', 'Épargne vacances', AccountType.savings, null),
      ('pillar3a', '3e pilier A', AccountType.pillar3, null),
      ('pillar3b', '3e pilier B', AccountType.pillar3, null),
      ('pillar2', '2e pilier', AccountType.pillar2, null),
      ('investments', 'Titres', AccountType.investments, null),
      ('vehicle', 'Voiture', AccountType.vehicle, null),
      ('deposit', 'Garantie de loyer', AccountType.rentDeposit, null),
      ('debts', 'Dettes', AccountType.debts, null),
      ('other', 'Autre', AccountType.other, null),
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
      ('group-modules', 'Modules', expenses, null, groups),
      (vacations, 'Vacances', 'group-modules', null, 0),
      (electricity, 'Électricité', 'group-modules', null, 1),
      (taxes, 'Impôts', 'group-modules', null, 2),
    ];
    final rules = <(String, List<String>, String)>[
      ('rule-salary', ['Employeur Exemple'], salary),
      for (var s = 0; s < shopsWithRule; s++) ('rule-shop-$s', [shopName(s)], shopCategory(s)),
    ];
    for (var year = firstYear; year < firstYear + years; year++) {
      for (final (id, name, parent, nature, position) in tree) {
        set(CategoryFields.entity, categoryIn(id, year), {
          CategoryFields.year: year,
          CategoryFields.name: id == leaf(groups - 1, 4) && year == lastYear ? 'Divers' : name,
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
          RuleFields.lines: encodeRuleLines([legacyRuleLine(keywords)]),
          RuleFields.targetCategoryId: categoryIn(target, year),
          RuleFields.targetAccountId: null,
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
        final (periodStart, periodEnd) = rank % 20 == 5 ? yearFrom(date) : (date, date);
        if (category == leaf(groups - 1, 4) && periodEnd.year == lastYear && year < lastYear && rank % 40 == 5) {
          set(ShareClassificationFields.entity, shareClassificationId('$id-line', lastYear), {
            ShareClassificationFields.lineId: '$id-line',
            ShareClassificationFields.year: lastYear,
            ShareClassificationFields.categoryId: categoryIn(leaf(groups - 1, 4), lastYear),
            ShareClassificationFields.originCategoryId: categoryIn(category, year),
          });
        }
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
      final (periodStart, periodEnd) = i % 10 == 3 ? yearFrom(date) : (date, date);
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

    // Balances declared every six months on ten accounts.
    for (final (index, account) in declaredAccounts.indexed) {
      for (var i = 0; i < 10; i++) {
        final date = i.isEven ? CalendarDate(firstYear - 1 + i ~/ 2, 12, 31) : CalendarDate(firstYear + i ~/ 2, 6, 30);
        set(BalanceFields.entity, balanceId(account, date), {
          BalanceFields.accountId: account,
          BalanceFields.date: date.encode(),
          BalanceFields.amount: 100000 * (index + 1) + 1234 * i,
          deletedField: false,
        });
      }
    }

    // Debts over the five years, half of them repaid.
    for (var i = 0; i < debts; i++) {
      final year = firstYear + i % years;
      final event = CalendarDate(year, 1 + i % 12, 1 + i % 28);
      final repaid = i.isEven;
      set(DebtFields.entity, 'debt-$i', {
        DebtFields.direction: (i % 3 == 0 ? DebtDirection.iOwe : DebtDirection.owedToMe).name,
        DebtFields.person: 'Personne ${i % 20}',
        DebtFields.amount: 1000 + i * 77 % 50000,
        DebtFields.basisPoints: i % 4 == 0 ? 5000 : 10000,
        DebtFields.eventDate: event.encode(),
        DebtFields.invoiceDate: null,
        DebtFields.requestDate: null,
        DebtFields.receivedDate: repaid ? event.addDays(30).encode() : null,
        DebtFields.description: 'Dette $i',
        DebtFields.repaid: repaid,
        DebtFields.enteredOn: event.encode(),
        DebtFields.checkedOn: repaid ? event.addDays(31).encode() : null,
      });
    }

    // The modules: vacation lines, electricity invoices and their kWh.
    void entry(String id, CalendarDate date, int amount, String category, CalendarDate start, CalendarDate end) {
      set(TransactionFields.entity, id, {
        TransactionFields.accountId: 'cash',
        TransactionFields.date: date.encode(),
        TransactionFields.amount: amount,
        TransactionFields.description: id,
        TransactionFields.note: '',
        TransactionFields.status: TransactionStatus.validated.name,
        TransactionFields.counterpartAccountId: null,
      });
      set(LineFields.entity, '$id-line', {
        LineFields.transactionId: id,
        LineFields.categoryId: categoryIn(category, date.year),
        LineFields.amount: amount,
        LineFields.periodStart: start.encode(),
        LineFields.periodEnd: end.encode(),
      });
    }

    for (var i = 0; i < vacationLines; i++) {
      final date = CalendarDate(firstYear + i % years, 1 + i ~/ years % 12, 1 + i % 28);
      entry('trip-$i', date, -(2000 + i * 91 % 50000), vacations, date, i % 4 == 0 ? date.addDays(6) : date);
      if (i % 10 == 0) {
        set(TripSheetFields.entity, tripSheetId('trip-$i-line'), {
          TripSheetFields.lineId: 'trip-$i-line',
          TripSheetFields.place: 'Lieu $i',
          TripSheetFields.days: 1 + i % 14,
          TripSheetFields.date: null,
          TripSheetFields.amount: null,
          deletedField: false,
        });
      }
    }
    for (var i = 0; i < electricityInvoices; i++) {
      final year = firstYear + i ~/ 12, month = i % 12 + 1;
      final start = CalendarDate(year, month, 1),
          end = CalendarDate(year, month, CalendarDate.daysInMonth(year, month));
      entry('power-$i', end.addDays(15), -(5000 + i * 37 % 3000), electricity, start, end);
      set(ElectricityReadingFields.entity, electricityReadingId('power-$i-line'), {
        ElectricityReadingFields.lineId: 'power-$i-line',
        ElectricityReadingFields.wh: 150000 + i * 1000,
        deletedField: false,
      });
    }

    // A salary sheet and a fiscal year per year.
    for (var year = firstYear; year < firstYear + years; year++) {
      set(SalarySheetFields.entity, salarySheetId(year), {
        SalarySheetFields.year: year,
        SalarySheetFields.gross: 9600000,
        SalarySheetFields.net: 8385600,
        deletedField: false,
      });
      for (final (rank, (label, amount)) in [('AVS', 508800), ('AC', 105600), ('LPP', 600000)].indexed) {
        set(SalaryDeductionFields.entity, 'deduction-$year-$rank', {
          SalaryDeductionFields.sheetId: salarySheetId(year),
          SalaryDeductionFields.label: label,
          SalaryDeductionFields.amount: amount,
          SalaryDeductionFields.rank: rank,
        });
      }
      set(TaxYearFields.entity, taxYearId(year), {
        TaxYearFields.year: year,
        TaxYearFields.taxableWealth: 20000000,
        TaxYearFields.marginalRate: 3150,
        deletedField: false,
      });
      for (final tax in TaxKind.values) {
        set(TaxLineFields.entity, taxLineId(year, tax), {
          TaxLineFields.year: year,
          TaxLineFields.tax: tax.name,
          TaxLineFields.base: tax.onWealth ? null : 7800000,
          TaxLineFields.baseRate: 65000,
          TaxLineFields.coefficient: 15500,
          deletedField: false,
        });
      }
    }

    // Subscriptions of three tranches each.
    for (var i = 0; i < subscriptions; i++) {
      set(SubscriptionFields.entity, 'subscription-$i', {
        SubscriptionFields.name: 'Abonnement $i',
        SubscriptionFields.note: '',
      });
      for (var t = 0; t < 3; t++) {
        final start = CalendarDate(firstYear + t, 1 + i % 12, 1);
        set(TrancheFields.entity, 'tranche-$i-$t', {
          TrancheFields.subscriptionId: 'subscription-$i',
          TrancheFields.amount: 990 + i * 10 + t * 100,
          TrancheFields.frequency: (i.isEven ? TrancheFrequency.monthly : TrancheFrequency.yearly).name,
          TrancheFields.start: start.encode(),
          TrancheFields.end: t == 2 ? null : CalendarDate(firstYear + t + 1, 1 + i % 12, 1).addDays(-1).encode(),
        });
      }
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

/// Twelve months from [date]: to the day before the same day a year later.
(CalendarDate, CalendarDate) yearFrom(CalendarDate date) {
  final day = date.day.clamp(1, CalendarDate.daysInMonth(date.year + 1, date.month));
  return (date, CalendarDate(date.year + 1, date.month, day).addDays(-1));
}
