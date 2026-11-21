import 'package:batz/domain/calendar_date.dart';
import 'package:batz/domain/journal/journal_entry.dart';
import 'package:batz/domain/ledger/account.dart';
import 'package:batz/domain/ledger/balance.dart';
import 'package:batz/domain/ledger/category.dart';
import 'package:batz/domain/ledger/debt.dart';
import 'package:batz/domain/ledger/ledger.dart';
import 'package:batz/domain/ledger/proposal.dart';
import 'package:batz/domain/ledger/statement.dart';

CalendarDate _d(int year, int month, int day) => CalendarDate(year, month, day);

/// The example of the plan, entered through the operations of the app:
/// the private account is detailed, its statement of 2026 imported then
/// classified.
Future<Ledger> referenceExample(
  Future<Ledger> Function(Modification Function(Ledger l) build) apply, {
  required CalendarDate today,
}) async {
  await apply(
    (l) => l.createAccount(
      'private',
      const AccountDraft(
        name: 'Compte privé',
        type: AccountType.privateAccount,
        importFormat: ImportFormat.postfinance,
      ),
    ),
  );
  await apply((l) => l.createAccount('savings', const AccountDraft(name: 'Épargne', type: AccountType.savings)));
  await apply((l) => l.createAccount('pillar', const AccountDraft(name: '3e pilier', type: AccountType.pillar3)));
  await apply((l) => l.createTree(2026));
  final income = defaultGroupId(2026, CategoryNature.income), expenses = defaultGroupId(2026, CategoryNature.expense);
  await apply((l) => l.addCategory('salary', year: 2026, name: 'Salaire', parentId: income));
  await apply((l) => l.addCategory('rent', year: 2026, name: 'Loyer', parentId: expenses));
  await apply((l) => l.addCategory('food', year: 2026, name: 'Nourriture', parentId: expenses));
  await apply((l) => l.addCategory('restaurant', year: 2026, name: 'Restaurant', parentId: expenses));

  ExtractedLine line(CalendarDate date, int amount, String text) =>
      ExtractedLine(date: date, amount: amount, rawText: text, label: text);
  final lines = [
    line(_d(2026, 1, 15), -705600, 'Versement 3e pilier'),
    line(_d(2026, 1, 25), 6000000, 'Salaire annuel'),
    line(_d(2026, 2, 1), -600000, 'Virement épargne'),
    line(_d(2026, 3, 14), -20000, 'Restaurant pour deux'),
    line(_d(2026, 6, 30), -4570000, 'Courses de l\'année'),
    line(_d(2026, 9, 1), -210000, 'Loyer douze mois'),
    line(_d(2026, 11, 2), -3500, 'Ligne inconnue'),
  ];
  final statement = ExtractedStatement(
    format: 'postfinance',
    iban: 'CH0000000000000000000',
    currency: 'CHF',
    periodStart: _d(2026, 1, 1),
    periodEnd: _d(2026, 12, 31),
    openingBalance: 500000,
    closingBalance: 390900,
    totalCredits: 6000000,
    totalDebits: 6109100,
    lines: lines,
  );
  late StatementImport import;
  await apply((l) => (import = l.importStatement('private', statement, fingerprint: 'f' * 64)).modification);
  String id(int rank) => importedTransactionId(import.statementId, rank);
  Classification category(String id, CalendarDate date, {CalendarDate? end}) =>
      Classification.category(id, periodStart: date, periodEnd: end ?? date);
  await apply((l) => l.classify(id(0), const Classification.transfer('pillar')));
  await apply((l) => l.classify(id(1), category('salary', _d(2026, 1, 25))));
  await apply((l) => l.classify(id(2), const Classification.transfer('savings')));
  await apply((l) => l.classify(id(3), category('restaurant', _d(2026, 3, 14))));
  await apply((l) => l.classify(id(4), category('food', _d(2026, 6, 30))));
  await apply((l) => l.classify(id(5), category('rent', _d(2026, 9, 1), end: _d(2027, 8, 31))));

  await apply((l) => l.declareBalance('savings', _d(2025, 12, 31), 1000000, today: today));
  await apply((l) => l.declareBalance('savings', _d(2026, 12, 31), 1625000, today: today));
  await apply((l) => l.declareBalance('pillar', _d(2026, 6, 30), 710000, today: today));
  return apply(
    (l) => l.createDebt(
      'meal',
      DebtDraft(
        direction: DebtDirection.owedToMe,
        person: 'Alex Modèle',
        amount: 20000,
        basisPoints: 5000,
        eventDate: _d(2026, 3, 14),
      ),
      today: _d(2026, 3, 15),
    ),
  );
}
