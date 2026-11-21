import 'package:batz/domain/calendar_date.dart';
import 'package:batz/domain/ids.dart';
import 'package:batz/domain/journal/journal_entry.dart';
import 'package:batz/domain/ledger/account.dart';
import 'package:batz/domain/ledger/category.dart';
import 'package:batz/domain/ledger/ledger.dart';
import 'package:batz/domain/ledger/transaction.dart';
import 'package:batz/domain/modules/salary.dart';

/// The year 2026 of the example of the diagram: « Revenus » holds « Salaire »
/// ([salary] received, 83'856.00 by default) and « Intérêts » (144.00); the
/// top-level groups of expenses « Logement » (24'000.00), « Quotidien »
/// (18'000.00) and « Obligations » (21'000.00, of which « Impôts »
/// 15'000.00). With [sheet], the salary sheet of the example: gross
/// 96'000.00, AVS 5'088.00, AC 1'056.00, LPP 6'000.00.
Future<Ledger> flowExample(
  Future<Ledger> Function(Modification Function(Ledger l) build) apply, {
  int salary = 8385600,
  bool sheet = true,
}) async {
  await apply((l) => l.createAccount('cash', const AccountDraft(name: 'Compte', type: AccountType.privateAccount)));
  await apply((l) => l.createTree(2026));
  final income = defaultGroupId(2026, CategoryNature.income);
  await apply((l) => l.addCategory('salary', year: 2026, name: 'Salaire', parentId: income));
  await apply((l) => l.addCategory('interest', year: 2026, name: 'Intérêts', parentId: income));
  for (final (id, name) in [('housing', 'Logement'), ('daily', 'Quotidien'), ('duties', 'Obligations')]) {
    await apply((l) => l.addCategory(id, year: 2026, name: name, nature: CategoryNature.expense));
  }
  await apply((l) => l.addCategory('rent', year: 2026, name: 'Loyer', parentId: 'housing'));
  await apply((l) => l.addCategory('groceries', year: 2026, name: 'Courses', parentId: 'daily'));
  await apply((l) => l.addCategory('taxes', year: 2026, name: 'Impôts', parentId: 'duties'));
  await apply((l) => l.addCategory('insurance', year: 2026, name: 'Assurances', parentId: 'duties'));
  var ledger = await apply((l) => l.addCategory('spare', year: 2026, name: 'Divers', parentId: 'daily'));
  for (final (id, category, cents, direction) in [
    ('t-salary', 'salary', salary, Direction.inflow),
    ('t-interest', 'interest', 14400, Direction.inflow),
    ('t-rent', 'rent', 2400000, Direction.outflow),
    ('t-groceries', 'groceries', 1800000, Direction.outflow),
    ('t-taxes', 'taxes', 1500000, Direction.outflow),
    ('t-insurance', 'insurance', 600000, Direction.outflow),
  ]) {
    ledger = await apply(
      (l) => l.recordEntry(
        id,
        '$id-line',
        EntryDraft(
          accountId: 'cash',
          date: CalendarDate(2026, 6, 15),
          cents: cents,
          direction: direction,
          categoryId: category,
        ),
      ),
    );
  }
  if (sheet) {
    ledger = await apply(
      (l) => l.saveSalarySheet(
        const SalarySheetDraft(
          year: 2026,
          gross: 9600000,
          net: 8385600,
          deductions: [
            DeductionDraft(label: 'AVS', amount: 508800),
            DeductionDraft(label: 'AC', amount: 105600),
            DeductionDraft(label: 'LPP', amount: 600000),
          ],
        ),
        newId: newId,
      ),
    );
  }
  return ledger;
}
