/// Random operations of the app, those of every phase, used by the
/// convergence test and the test of the export.
library;

import 'dart:math';

import 'package:batz/domain/calendar_date.dart';
import 'package:batz/domain/journal/journal_entry.dart';
import 'package:batz/domain/ledger/account.dart';
import 'package:batz/domain/ledger/balance.dart';
import 'package:batz/domain/ledger/category.dart';
import 'package:batz/domain/ledger/debt.dart';
import 'package:batz/domain/ledger/ledger.dart';
import 'package:batz/domain/ledger/ledger_exception.dart';
import 'package:batz/domain/ledger/redistribution.dart';
import 'package:batz/domain/ledger/refund.dart';
import 'package:batz/domain/ledger/transaction.dart';
import 'package:batz/domain/modules/electricity.dart';
import 'package:batz/domain/modules/salary.dart';
import 'package:batz/domain/modules/settings.dart';
import 'package:batz/domain/modules/subscriptions.dart';
import 'package:batz/domain/modules/taxes.dart';
import 'package:batz/domain/modules/vacations.dart';
import 'package:batz/domain/views/share_operations.dart';
import 'package:batz/domain/views/year_view.dart';

const _names = ['Loyer', 'Nourriture', 'Impôts', 'Vacances', 'Salaire', 'Électricité', 'Divers', 'Logement'];
const _accountNames = ['Espèces', 'UBS', 'Épargne', 'Carte', 'Dettes'];

T _pick<T>(Random r, List<T> list) => list[r.nextInt(list.length)];

/// A random operation of the app on [l], or null when there is nothing to
/// do it on. The domain may refuse it ([LedgerException]).
Modification? randomOperation(Ledger l, Random r, String id) {
  final active = l.accounts.values.where((a) => !a.archived).toList();
  final manual = active.where((a) => !a.isDetailed && a.type != AccountType.debts).toList();
  final year = 2026 + r.nextInt(2);
  final categories = l.categories.values.toList();
  final entries = l.transactions.values.where((t) => !t.isTransfer && t.line != null).toList();
  CalendarDate date() => CalendarDate(year, 1 + r.nextInt(12), 1 + r.nextInt(28));

  // The operations of phase 4, now and then.
  if (r.nextInt(100) < 12) return _phase4Operation(l, r, id, year);
  // The operations of phase 5, now and then.
  if (r.nextInt(100) < 10) return _phase5Operation(l, r, id);
  // The operations of phase 6, now and then.
  if (r.nextInt(100) < 10) return _phase6Operation(l, r, id);

  // Weighted: mostly entries and their corrections, like real use.
  final roll = r.nextInt(100);
  final kind = [5, 10, 20, 28, 36, 40, 65, 65, 85, 90, 95, 100].indexWhere((limit) => roll < limit);
  switch (kind) {
    case 0:
      final type = _pick(r, AccountType.values);
      return l.createAccount(
        'acc-$id',
        AccountDraft(
          name: _pick(r, _accountNames),
          type: type,
          importFormat: r.nextInt(6) == 0 ? ImportFormat.postfinance : null,
        ),
      );
    case 1:
      return l.createTree(year);
    case 2:
      final parents = l.trees[year]?.ordered ?? const <Category>[];
      if (parents.isEmpty) return null;
      return l.addCategory('cat-$id', year: year, name: _pick(r, _names), parentId: _pick(r, parents).id);
    case 3:
      if (categories.isEmpty) return null;
      return l.renameCategory(_pick(r, categories).id, '${_pick(r, _names)} ${r.nextInt(3)}');
    case 4:
      if (categories.isEmpty) return null;
      final moved = _pick(r, categories);
      final targets = l.trees[moved.year]!.ordered.where((c) => c.id != moved.id).toList();
      if (targets.isEmpty || r.nextInt(4) == 0) {
        return l.moveCategory(moved.id, nature: _pick(r, CategoryNature.values));
      }
      return l.moveCategory(moved.id, parentId: _pick(r, targets).id);
    case 5:
      if (categories.isEmpty) return null;
      return l.removeCategory(_pick(r, categories).id);
    case 6 || 7:
      if (manual.isEmpty) return null;
      final assignable = l.treeOrPreview(year).assignable;
      if (assignable.isEmpty) return null;
      return l.recordEntry(
        'tx-$id',
        'ln-$id',
        EntryDraft(
          accountId: _pick(r, manual).id,
          date: date(),
          cents: 1 + r.nextInt(100000),
          direction: _pick(r, Direction.values),
          categoryId: _pick(r, assignable).id,
          description: 'op $id',
          periodStart: r.nextInt(4) == 0 ? CalendarDate(year, 1, 1) : null,
          periodEnd: r.nextInt(4) == 0 ? CalendarDate(year + 1, 6, 30) : null,
        ),
      );
    case 8:
      if (entries.isEmpty) return null;
      final t = _pick(r, entries);
      final assignable = l.treeOrPreview(t.date.year).assignable;
      final line = t.line!;
      return l.updateEntry(
        t.id,
        EntryDraft(
          accountId: t.accountId,
          date: t.date,
          cents: r.nextBool() ? t.amount.abs() : 1 + r.nextInt(100000),
          direction: t.amount < 0 ? Direction.outflow : Direction.inflow,
          categoryId: r.nextBool() || assignable.isEmpty ? line.categoryId ?? '' : _pick(r, assignable).id,
          description: t.description,
          note: r.nextBool() ? t.note : 'note $id',
          periodStart: line.periodStart,
          periodEnd: line.periodEnd,
        ),
      );
    case 9:
      if (active.length < 2) return null;
      return l.recordTransfer(
        'tx-$id',
        TransferDraft(
          fromAccountId: _pick(r, active).id,
          toAccountId: _pick(r, active).id,
          date: date(),
          cents: 1 + r.nextInt(50000),
        ),
      );
    case 10:
      if (l.transactions.isEmpty) return null;
      return l.deleteTransaction(_pick(r, l.transactions.keys.toList()));
    default:
      if (l.accounts.isEmpty) return null;
      final account = _pick(r, l.accounts.values.toList());
      return r.nextBool()
          ? l.removeAccount(account.id).modification
          : l.updateAccount(account.id, AccountDraft.of(account).copyWithArchived(!account.archived));
  }
}

/// The operations of phase 4: redistribution rules, refunds attached and
/// detached, answers to the shares to classify.
Modification? _phase4Operation(Ledger l, Random r, String id, int year) {
  final roll = r.nextInt(3);
  if (roll == 0) return _refundOperation(l, r);
  if (roll == 1) return _answerOperation(l, r);
  final existing = l.redistributionsOf(year).where((rule) => l.redistributions.containsKey(rule.id)).toList();
  if (existing.isNotEmpty && r.nextInt(3) == 0) {
    final rule = _pick(r, existing);
    if (r.nextBool()) return l.deleteRedistribution(rule.id);
    return l.updateRedistribution(
      rule.id,
      RedistributionDraft(
        year: year,
        sourceId: rule.sourceId,
        targetId: rule.targetId,
        basisPoints: 1 + r.nextInt(6000),
      ),
    );
  }
  final leaves = l.trees[year]?.assignable ?? const <Category>[];
  if (leaves.length < 2) return null;
  return l.createRedistribution(
    'red-$id',
    RedistributionDraft(
      year: year,
      sourceId: _pick(r, leaves).id,
      targetId: _pick(r, leaves).id,
      basisPoints: 1 + r.nextInt(6000),
    ),
  );
}

Modification? _answerOperation(Ledger l, Random r) {
  final pending = l.views.pendingShares;
  if (pending.isEmpty) return null;
  final group = _pick(r, pending);
  final tree = l.views.treeOf(group.year)!;
  final candidates = [
    for (final c in tree.assignable)
      if (tree.natureOf(c.id) == group.nature) c,
  ];
  if (candidates.isEmpty) return null;
  final lines = r.nextBool() ? group.shares.map((s) => s.lineId) : [_pick(r, group.shares).lineId];
  return l.classifyShares(group.year, lines, _pick(r, candidates).id);
}

Modification? _refundOperation(Ledger l, Random r) {
  final inflows = l.transactions.values.where((t) => t.amount > 0 && !t.isTransfer).toList();
  if (inflows.isEmpty) return null;
  final refund = _pick(r, inflows);
  if (refund.line?.refundedLineId != null && r.nextInt(3) == 0) return l.detachRefund(refund.id);
  final expenses = [
    for (final t in l.transactions.values)
      if (t.line != null && l.isExpenseLine(t, t.line!)) t.line!.id,
  ];
  if (expenses.isEmpty) return null;
  return l.attachRefund(refund.id, _pick(r, expenses));
}

/// The operations of phase 5: declared balances, declared, modified and
/// deleted, on any account (the detailed account, a debts account and a
/// date to come are refused); debts, created, modified, checked and
/// unchecked, split and deleted.
Modification? _phase5Operation(Ledger l, Random r, String id) {
  final today = CalendarDate(2026, 11, 20);
  CalendarDate date() => CalendarDate(2025 + r.nextInt(2), 1 + r.nextInt(12), 1 + r.nextInt(28));
  int amount() => r.nextInt(2000000) - 500000;
  if (r.nextBool()) return _debtOperation(l, r, id, today, date);
  final declared = l.declaredBalances.values.toList()..sort((a, b) => a.id.compareTo(b.id));
  if (declared.isNotEmpty && r.nextInt(3) == 0) {
    final balance = _pick(r, declared);
    if (r.nextBool()) return l.deleteBalance(balance.id);
    return l.updateBalance(balance.id, r.nextBool() ? balance.date : date(), amount(), today: today);
  }
  if (l.accounts.isEmpty) return null;
  return l.declareBalance(_pick(r, l.accounts.keys.toList()..sort()), date(), amount(), today: today);
}

Modification? _debtOperation(Ledger l, Random r, String id, CalendarDate today, CalendarDate Function() date) {
  final debts = l.debts.keys.toList()..sort();
  DebtDraft draft() => DebtDraft(
    direction: _pick(r, DebtDirection.values),
    person: _pick(r, ['Alex', 'Camille', 'Dominique', '']),
    amount: r.nextInt(100000),
    basisPoints: r.nextInt(4) == 0 ? 1 + r.nextInt(10000) : 10000,
    eventDate: r.nextBool() ? date() : null,
    receivedDate: r.nextInt(3) == 0 ? date() : null,
    description: 'dette $id',
    repaid: r.nextInt(4) == 0,
  );
  if (debts.isEmpty || r.nextInt(3) == 0) return l.createDebt('debt-$id', draft(), today: today);
  final debt = _pick(r, debts);
  return switch (r.nextInt(5)) {
    0 => l.updateDebt(debt, draft(), today: today),
    1 => l.checkDebt(debt, receivedDate: r.nextBool() ? date() : null, today: today),
    2 => l.uncheckDebt(debt),
    3 => l.splitDebt(debt, 'debt-$id', 1 + r.nextInt(l.debts[debt]!.total + 1)),
    _ => l.deleteDebt(debt),
  };
}

/// The operations of phase 6: the settings and the entries of the modules.
Modification? _phase6Operation(Ledger l, Random r, String id) {
  final year = 2025 + r.nextInt(3);
  CalendarDate date() => CalendarDate(year, 1 + r.nextInt(12), 1 + r.nextInt(28));
  switch (r.nextInt(6)) {
    case 0:
      return l.setModuleCategory(_pick(r, ModuleKind.values), _pick(r, _names));
    case 1:
      final sheet = l.salarySheet(year);
      if (sheet != null && r.nextInt(4) == 0) return l.deleteSalarySheet(year);
      return l.saveSalarySheet(
        SalarySheetDraft(
          year: year,
          gross: r.nextInt(10000000),
          net: r.nextInt(8000000),
          deductions: [
            for (final d in sheet?.deductions ?? const <SalaryDeduction>[])
              if (r.nextInt(4) > 0) DeductionDraft(id: d.id, label: d.label, amount: r.nextInt(500000)),
            if (r.nextBool()) DeductionDraft(label: _pick(r, ['AVS', 'AC', 'LPP']), amount: r.nextInt(500000)),
          ],
        ),
        newId: () => 'ded-$id-${r.nextInt(1 << 30)}',
      );
    case 2:
      if (l.taxYears.contains(year) && r.nextInt(4) == 0) return l.deleteTaxYear(year);
      return l.saveTaxYear(
        TaxYearDraft(
          year: year,
          taxableWealth: r.nextBool() ? r.nextInt(50000000) : null,
          marginalRate: r.nextInt(12000),
          lines: {
            for (final tax in TaxKind.values)
              if (r.nextBool())
                tax: TaxLineDraft(
                  base: r.nextInt(9000000),
                  baseRate: r.nextInt(1100000),
                  coefficient: r.nextInt(20000),
                ),
          },
        ),
      );
    case 3:
      final trips = l.vacations.trips;
      final sheets = l.modules.tripSheets.keys.toList()..sort();
      if (sheets.isNotEmpty && r.nextInt(4) == 0) return l.deleteTripSheet(_pick(r, sheets));
      if (trips.isEmpty || r.nextInt(3) == 0) {
        return l.saveManualTrip(
          'trip-$id',
          place: 'Lieu',
          date: r.nextBool() ? date() : null,
          amount: r.nextInt(100000),
          days: r.nextInt(10),
        );
      }
      return l.saveTrip(
        _pick(r, trips),
        place: _pick(r, ['Rome', 'Paris', '']),
        days: r.nextInt(15),
        amount: r.nextBool() ? r.nextInt(100000) : null,
      );
    case 4:
      final lines = [
        for (final line in l.views.lines)
          if (line.origin != null) line.ownLineId,
      ]..sort();
      if (lines.isEmpty) return null;
      final line = _pick(r, lines);
      if (l.modules.electricityReadings.containsKey(line) && r.nextInt(3) == 0) return l.setElectricity(line, null);
      return l.setElectricity(line, r.nextInt(3000000) - 100000);
    default:
      final subscriptions = l.modules.subscriptions.values.toList()..sort((a, b) => a.id.compareTo(b.id));
      TrancheDraft tranche() => TrancheDraft(
        amount: r.nextInt(5000),
        frequency: _pick(r, TrancheFrequency.values),
        start: date(),
        end: r.nextBool() ? CalendarDate(2027, 12, 31) : null,
      );
      if (subscriptions.isEmpty || r.nextInt(3) == 0) {
        return l.createSubscription(
          'sub-$id',
          'tr-$id',
          name: _pick(r, ['Streaming', 'Journal', '']),
          first: tranche(),
        );
      }
      final subscription = _pick(r, subscriptions);
      return switch (r.nextInt(4)) {
        0 => l.addTranche(subscription.id, 'tr-$id', tranche()),
        1 when subscription.tranches.isNotEmpty => l.updateTranche(_pick(r, subscription.tranches).id, tranche()),
        2 when subscription.tranches.isNotEmpty => l.deleteTranche(_pick(r, subscription.tranches).id),
        _ => l.deleteSubscription(subscription.id),
      };
  }
}

extension on AccountDraft {
  AccountDraft copyWithArchived(bool archived) =>
      AccountDraft(name: name, type: type, importFormat: importFormat, archived: archived);
}
