import 'package:batz/domain/calendar_date.dart';
import 'package:batz/domain/ledger/account.dart';
import 'package:batz/domain/ledger/balance.dart';
import 'package:batz/domain/ledger/category.dart';
import 'package:batz/domain/ledger/debt.dart';
import 'package:batz/domain/ledger/ledger.dart';
import 'package:batz/domain/ledger/redistribution.dart';
import 'package:batz/domain/ledger/rule.dart';
import 'package:batz/domain/ledger/share_classification.dart';
import 'package:batz/domain/ledger/statement.dart';
import 'package:batz/domain/ledger/transaction.dart';
import 'package:batz/domain/modules/electricity.dart';
import 'package:batz/domain/modules/module_records.dart';
import 'package:batz/domain/modules/salary.dart';
import 'package:batz/domain/modules/settings.dart';
import 'package:batz/domain/modules/subscriptions.dart';
import 'package:batz/domain/modules/taxes.dart';
import 'package:batz/domain/modules/vacations.dart';

CalendarDate _d(int year, int month, int day) => CalendarDate(year, month, day);

/// The example ledger of the export: every sort of data, invented, with the
/// three transactions of the example in docs/features.md. Its files are
/// `test/fixtures/export/*.csv`.
Ledger exportExampleLedger() {
  LedgerTransaction tx(
    String id,
    CalendarDate date,
    int amount, {
    String account = 'acc-private',
    String description = '',
    String note = '',
    String? rawText,
    String? statementId,
    int? statementRank,
    String? counterpart,
    TransactionStatus status = TransactionStatus.validated,
  }) => LedgerTransaction(
    id: id,
    accountId: account,
    date: date,
    amount: amount,
    description: description,
    note: note,
    rawText: rawText,
    statementId: statementId,
    statementRank: statementRank,
    counterpartAccountId: counterpart,
    status: status,
  );

  TransactionLine line(
    String id,
    String transaction,
    String category,
    int amount,
    CalendarDate start, [
    CalendarDate? end,
    String? refunded,
  ]) => TransactionLine(
    id: id,
    transactionId: transaction,
    categoryId: category,
    amount: amount,
    periodStart: start,
    periodEnd: end ?? start,
    refundedLineId: refunded,
  );

  return Ledger(
    accounts: const [
      Account(
        id: 'acc-private',
        name: 'Compte privé',
        type: AccountType.privateAccount,
        importFormat: ImportFormat.postfinance,
      ),
      Account(id: 'acc-savings', name: 'Épargne', type: AccountType.savings),
      Account(id: 'acc-old', name: 'Ancien compte', type: AccountType.other, archived: true),
      Account(id: 'acc-debts', name: 'Dettes', type: AccountType.debts),
    ],
    balances: [
      DeclaredBalance(id: 'bal-1', accountId: 'acc-savings', date: _d(2025, 12, 31), amount: 1000000),
      DeclaredBalance(id: 'bal-2', accountId: 'acc-savings', date: _d(2026, 12, 31), amount: 1500000),
      DeclaredBalance(id: 'bal-3', accountId: 'acc-old', date: _d(2026, 1, 31), amount: 0),
    ],
    statements: [
      Statement(
        id: 'st-september',
        accountId: 'acc-private',
        format: 'postfinance',
        iban: 'CH0000000000000000000',
        periodStart: _d(2026, 9, 1),
        periodEnd: _d(2026, 9, 30),
        openingBalance: 500000,
        closingBalance: 490300,
        fingerprint: 'a' * 64,
      ),
    ],
    categories: [
      const Category(id: 'g-income', year: 2026, name: 'Revenus', nature: CategoryNature.income),
      const Category(id: 'cat-salary', year: 2026, name: 'Salaire', parentId: 'g-income'),
      const Category(id: 'g-housing', year: 2026, name: 'Logement', nature: CategoryNature.expense, position: 1),
      const Category(id: 'cat-rent', year: 2026, name: 'Loyer', parentId: 'g-housing'),
      const Category(id: 'cat-power', year: 2026, name: 'Électricité', parentId: 'g-housing', position: 1),
      const Category(id: 'g-daily', year: 2026, name: 'Quotidien', nature: CategoryNature.expense, position: 2),
      const Category(id: 'cat-restaurant', year: 2026, name: 'Restaurant', parentId: 'g-daily'),
      const Category(id: 'cat-vacations', year: 2026, name: 'Vacances', parentId: 'g-daily', position: 1),
      const Category(id: 'cat-taxes', year: 2026, name: 'Impôts', parentId: 'g-daily', position: 2),
      const Category(id: 'cat-lost', year: 2026, name: 'Ancienne catégorie', parentId: 'cat-gone'),
      const Category(id: 'g-housing-2027', year: 2027, name: 'Logement', nature: CategoryNature.expense),
      const Category(id: 'cat-rent-2027', year: 2027, name: 'Loyer', parentId: 'g-housing-2027'),
    ],
    rules: [
      MappingRule(
        id: 'rule-restaurant',
        year: 2026,
        lines: const [r'AUBERGE ET re:du\s+lac', 'restaurant du port'],
        targetCategoryId: 'cat-restaurant',
      ),
      MappingRule(id: 'rule-saving', year: 2026, lines: const ['=VIREMENT'], targetAccountId: 'acc-savings'),
      MappingRule(id: 'rule-rent', year: 2026, lines: const ['LOYER'], targetCategoryId: 'cat-rent'),
    ],
    redistributions: const [
      RedistributionRule(
        id: 'red-restaurant',
        year: 2026,
        sourceId: 'cat-restaurant',
        targetId: 'cat-vacations',
        basisPoints: 2500,
      ),
    ],
    transactions: [
      tx('tx-power', _d(2026, 4, 30), -24000, description: 'Électricité T1'),
      tx('tx-flight', _d(2026, 6, 1), -35000, description: "Billet d'avion"),
      tx('tx-hotel', _d(2026, 7, 15), -90000, description: 'Hôtel'),
      tx('tx-rent', _d(2026, 9, 1), -210000, description: 'Loyer annuel'),
      tx(
        'tx-restaurant',
        _d(2026, 9, 3),
        -8500,
        description: 'Restaurant',
        rawText: 'ACHAT; AUBERGE "DU LAC"',
        statementId: 'st-september',
        statementRank: 0,
      ),
      tx('tx-saving', _d(2026, 9, 5), -50000, description: "Vers l'épargne", counterpart: 'acc-savings'),
      tx(
        'tx-formula',
        _d(2026, 9, 10),
        -1200,
        description: '=A1+1',
        rawText: '=A1+1',
        statementId: 'st-september',
        statementRank: 1,
        status: TransactionStatus.toValidate,
      ),
      tx('tx-refund', _d(2026, 9, 20), 2000, description: 'Remboursement repas'),
      tx('tx-salary', _d(2026, 9, 25), 700000, description: 'Salaire septembre', note: '+ prime\nversée en octobre'),
    ],
    lines: [
      line('ln-power', 'tx-power', 'cat-power', -24000, _d(2026, 1, 1), _d(2026, 3, 31)),
      line('ln-flight', 'tx-flight', 'cat-vacations', -35000, _d(2026, 7, 10)),
      line('ln-hotel', 'tx-hotel', 'cat-vacations', -90000, _d(2026, 7, 10), _d(2026, 7, 17)),
      line('ln-rent', 'tx-rent', 'cat-rent', -210000, _d(2026, 9, 1), _d(2027, 8, 31)),
      line('ln-restaurant', 'tx-restaurant', 'cat-restaurant', -8500, _d(2026, 9, 3)),
      line('ln-refund', 'tx-refund', 'cat-restaurant', 2000, _d(2026, 9, 20), null, 'ln-restaurant'),
      line('ln-salary', 'tx-salary', 'cat-salary', 700000, _d(2026, 9, 25)),
    ],
    shareClassifications: const [
      ShareClassification(
        id: 'share-rent-2027',
        lineId: 'ln-rent',
        year: 2027,
        categoryId: 'cat-rent-2027',
        originCategoryId: 'cat-rent',
      ),
    ],
    debts: [
      Debt(
        id: 'debt-meal',
        direction: DebtDirection.owedToMe,
        person: 'Alex Modèle',
        amount: 20000,
        basisPoints: 5000,
        eventDate: _d(2026, 3, 14),
        description: 'Repas; "chez Léa"',
        enteredOn: _d(2026, 3, 15),
      ),
      Debt(
        id: 'debt-loan',
        direction: DebtDirection.iOwe,
        person: 'Sam Exemple',
        amount: 15000,
        basisPoints: 10000,
        eventDate: _d(2026, 4, 1),
        invoiceDate: _d(2026, 4, 1),
        requestDate: _d(2026, 4, 10),
        receivedDate: _d(2026, 5, 2),
        repaid: true,
        enteredOn: _d(2026, 4, 1),
        checkedOn: _d(2026, 5, 2),
      ),
    ],
    modules: ModuleRecords(
      settings: const [ModuleSetting(id: 'set-vacations', module: ModuleKind.vacations, categoryName: 'Vacances')],
      salarySheets: [SalarySheet(id: 'sheet-2026', year: 2026, gross: 9600000, net: 8505600)],
      salaryDeductions: const [
        SalaryDeduction(id: 'ded-avs', sheetId: 'sheet-2026', label: 'AVS', amount: 508800, rank: 0),
        SalaryDeduction(id: 'ded-ac', sheetId: 'sheet-2026', label: 'AC', amount: 105600, rank: 1),
        SalaryDeduction(id: 'ded-lpp', sheetId: 'sheet-2026', label: 'LPP', amount: 480000, rank: 2),
      ],
      taxYears: const [TaxYear(id: 'tax-2026', year: 2026, taxableWealth: 5000000, marginalRate: 2500)],
      taxLines: const [
        TaxLine(id: 'tax-2026-federal', year: 2026, tax: TaxKind.federalIncome, base: 8000000, baseRate: 25000),
        TaxLine(
          id: 'tax-2026-cantonal',
          year: 2026,
          tax: TaxKind.cantonalIncome,
          base: 8000000,
          baseRate: 60000,
          coefficient: 15500,
        ),
        TaxLine(id: 'tax-2026-communal', year: 2026, tax: TaxKind.communalIncome, base: 8000000),
        TaxLine(id: 'tax-2026-wealth', year: 2026, tax: TaxKind.cantonalWealth, baseRate: 3000, coefficient: 15500),
      ],
      tripSheets: [
        const TripSheet(id: 'trip-lisbon', lineId: 'ln-flight', place: 'Lisbonne', days: 8, amount: 120000),
        const TripSheet(id: 'trip-extra', lineId: 'ln-hotel', place: 'Lisbonne (hôtel)'),
        const TripSheet(id: 'trip-orphan', lineId: 'ln-gone', place: 'Annulé', days: 3),
        TripSheet(id: 'trip-manual', place: 'Gruyère', days: 2, date: _d(2026, 9, 12), amount: 30000),
        const TripSheet(id: 'trip-incomplete', place: 'À compléter'),
      ],
      electricityReadings: const [
        ElectricityReading(id: 'kwh-power', lineId: 'ln-power', wh: 950500),
        ElectricityReading(id: 'kwh-gone', lineId: 'ln-gone', wh: 100000),
      ],
      subscriptions: [
        Subscription(id: 'sub-music', name: 'Musique', note: 'Formule famille'),
        Subscription(id: 'sub-paper', name: '=Journal'),
        Subscription(id: 'sub-empty', name: 'Sans tranche'),
      ],
      tranches: [
        Tranche(
          id: 'tr-music-1',
          subscriptionId: 'sub-music',
          amount: 1295,
          frequency: TrancheFrequency.monthly,
          start: _d(2026, 1, 1),
          end: _d(2026, 8, 31),
        ),
        Tranche(
          id: 'tr-music-2',
          subscriptionId: 'sub-music',
          amount: 1495,
          frequency: TrancheFrequency.monthly,
          start: _d(2026, 9, 1),
        ),
        Tranche(
          id: 'tr-paper',
          subscriptionId: 'sub-paper',
          amount: 24000,
          frequency: TrancheFrequency.yearly,
          start: _d(2026, 1, 1),
          end: _d(2026, 12, 31),
        ),
      ],
    ),
  );
}
