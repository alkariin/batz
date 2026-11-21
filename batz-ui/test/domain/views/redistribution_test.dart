import 'package:batz/domain/journal/journal_entry.dart';
import 'package:batz/domain/ledger/category.dart';
import 'package:batz/domain/ledger/ledger_exception.dart';
import 'package:batz/domain/ledger/redistribution.dart';
import 'package:batz/domain/ledger/rule.dart';
import 'package:batz/domain/ledger/statement.dart';
import 'package:batz/domain/period_model.dart';
import 'package:batz/domain/views/year_view.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/ledger_fixture.dart';
import '../../support/ledger_harness.dart';
import '../../support/statements.dart';

final expenses = defaultGroupId(2026, CategoryNature.expense);
final income = defaultGroupId(2026, CategoryNature.income);

RedistributionDraft draft(String source, String target, int basisPoints, {int year = 2026}) =>
    RedistributionDraft(year: year, sourceId: source, targetId: target, basisPoints: basisPoints);

LedgerError? refusal(void Function() build) {
  try {
    build();
  } on LedgerException catch (e) {
    return e.error;
  }
  return null;
}

/// Writes a rule as it can arrive from another device: without any check.
Modification raw(String id, String source, String target, int basisPoints, {int year = 2026}) =>
    Modification.set(RedistributionFields.entity, id, {
      RedistributionFields.year: year,
      RedistributionFields.sourceCategoryId: source,
      RedistributionFields.targetCategoryId: target,
      RedistributionFields.basisPoints: basisPoints,
    });

void main() {
  late LedgerHarness h;

  /// 2026: Revenus > Salaire, Primes; Dépenses > Logement > Loyer,
  /// Entretien ménage; Dépenses > Nourriture.
  setUp(() async {
    h = await LedgerHarness.open();
    await seedLedger(h);
    await h.apply((l) => l.addCategory('cleaning', year: 2026, name: 'Entretien ménage', parentId: 'housing'));
    await h.apply((l) => l.addCategory('bonus', year: 2026, name: 'Primes', parentId: income));
  });
  tearDown(() => h.close());

  test('rounding: to the cent, halves away from zero', () {
    expect(redistributedCents(-34567, 1000), -3457);
    expect(redistributedCents(34565, 1000), 3457);
    expect(redistributedCents(-34565, 1000), -3457);
    expect(redistributedCents(10000, 3333), 3333);
    expect(redistributedCents(1, 5000), 1);
    expect(redistributedCents(1, 4999), 0);
    expect(redistributedCents(-12345, fullBasisPoints), -12345);
    expect(redistributedCents(0, 1000), 0);
  });

  test('10 % of « Nourriture » appears in « Entretien ménage », month by month, on a line of its own on each side; '
      '345.67 gives 34.57; the common group and the expenses do not change', () async {
    await h.apply((l) => l.recordEntry('march', 'l1', entry(cents: 34567, date: d(2026, 3, 10))));
    await h.apply((l) => l.recordEntry('april', 'l2', entry(cents: 20000, date: d(2026, 4, 2))));
    await h.apply((l) => l.recordEntry('soap', 'l3', entry(category: 'cleaning', cents: 1500, date: d(2026, 4, 3))));
    // Over two months: two shares in the economic view.
    await h.apply(
      (l) => l.recordEntry(
        'market',
        'l4',
        entry(cents: 6001, date: d(2026, 6, 30), periodStart: d(2026, 6, 1), periodEnd: d(2026, 7, 31)),
      ),
    );
    final before = (await h.ledger()).views;
    await h.apply((l) => l.createRedistribution('ten', draft('food', 'cleaning', 1000)));
    final ledger = await h.ledger();

    for (final kind in ViewKind.values) {
      final view = ledger.views.of(2026, kind)!, without = before.of(2026, kind)!;
      final line = view.redistributions.single;
      expect(line.rule.id, 'ten');
      expect(line.moved.month(3), -3457, reason: '345.67 gives 34.57');
      expect(line.moved.month(4), -2000);
      expect(line.moved.total, line.moved.months.fold(0, (a, b) => a + b));
      // The source and the target keep their own amounts; the lines are
      // apart, of opposite signs.
      expect(view.categories['food'], without.categories['food']);
      expect(view.categories['cleaning'], without.categories['cleaning']);
      expect(view.redistributedOf('food'), -line.moved);
      expect(view.redistributedOf('cleaning'), line.moved);
      // « Logement » holds the target only: it grows; « Dépenses » holds
      // both: unchanged, as the expenses and the savings.
      expect(view.categories['housing'], without.categories['housing']! + line.moved);
      expect(view.categories[expenses], without.categories[expenses]);
      expect((view.expenses, view.income, view.savings), (without.expenses, without.income, without.savings));
    }
    final cash = ledger.views.of(2026, ViewKind.cash)!.redistributions.single.moved;
    final economic = ledger.views.of(2026, ViewKind.economic)!.redistributions.single.moved;
    expect((cash.month(6), cash.month(7)), (-600, 0), reason: '60.01 paid in June');
    expect((economic.month(6), economic.month(7)), (-300, -300), reason: 'shares of 30.01 and 30.00, each rounded');
  });

  test('several rules from one source: each takes its percentage of the amount before any redistribution', () async {
    await h.apply((l) => l.recordEntry('a', 'l1', entry(cents: 10000, date: d(2026, 1, 5))));
    await h.apply((l) => l.createRedistribution('r1', draft('food', 'cleaning', 1000)));
    await h.apply((l) => l.createRedistribution('r2', draft('food', 'rent', 2000)));
    await h.apply((l) => l.createRedistribution('r3', draft('salary', 'bonus', 5000)));
    final view = (await h.ledger()).views.of(2026, ViewKind.cash)!;
    expect(view.redistributions.map((r) => (r.rule.id, r.moved.month(1))), [
      ('r1', -1000),
      ('r2', -2000),
      ('r3', 0),
    ], reason: 'by source name, then target name');
    expect(view.categories['food']!.month(1), -10000);
    expect((view.categories['food']! + view.redistributedOf('food')).month(1), -7000);
    expect(view.categories['housing']!.month(1), -3000);
    expect(view.expenses.month(1), -10000);
    expect(view.inapplicable, isEmpty);
  });

  test('the base of a rule is what the source shows: proposed lines and shares from another year', () async {
    // A line to validate, proposed in « Nourriture » for the next month.
    final january = fixtureStatement('2026-01');
    await h.repository.write(
      (await h.ledger()).importStatement('bank', january.statement, fingerprint: january.fingerprint).modification,
    );
    await h.apply(
      (l) => l.createRule(
        'groceries',
        const RuleDraft(
          year: 2026,
          keywords: ['épicerie du coin'],
          targetCategoryId: 'food',
          periodModel: PeriodModel.nextMonth,
        ),
      ),
    );
    await h.apply((l) => l.createRedistribution('ten', draft('food', 'cleaning', 1000)));
    // A share of 2026 falls in 2027, whose tree is the copy, rules included.
    await h.apply(
      (l) => l.recordEntry(
        'b',
        'l2',
        entry(cents: 240000, date: d(2026, 12, 1), periodStart: d(2026, 12, 1), periodEnd: d(2027, 11, 30)),
      ),
    );
    await h.apply((l) => l.createTree(2027));
    final ledger = await h.ledger();
    final groceries = ledger
        .linesOf(statementId('bank', january.fingerprint))
        .where((t) => t.rawText!.contains('Épicerie du Coin'))
        .fold(0, (a, t) => a + t.amount);
    final economic2026 = ledger.views.of(2026, ViewKind.economic)!;
    expect(economic2026.redistributions.single.moved.month(2), redistributedCents(groceries, 1000));
    final economic2027 = ledger.views.of(2027, ViewKind.economic)!;
    final copy = economic2027.redistributions.single;
    expect(copy.rule.id, copiedRedistributionId('ten', 2027));
    expect(copy.moved.month(1), -2000, reason: '10 % of the share of 200.00 paid in 2026');
  });

  test('a year to come shows the rules its copy will receive', () async {
    await h.apply((l) => l.createRedistribution('ten', draft('food', 'cleaning', 1000)));
    await h.apply(
      (l) => l.recordEntry(
        'b',
        'l2',
        entry(cents: 120000, date: d(2026, 1, 1), periodStart: d(2028, 1, 1), periodEnd: d(2028, 12, 31)),
      ),
    );
    final ledger = await h.ledger();
    final rules = ledger.redistributionsOf(2028);
    expect(rules.single.id, copiedRedistributionId('ten', 2028));
    expect(
      (rules.single.sourceId, rules.single.targetId),
      (copiedCategoryId('food', 2028), copiedCategoryId('cleaning', 2028)),
    );
    final view = ledger.views.of(2028, ViewKind.economic)!;
    expect(view.isPreview, isTrue);
    expect(view.redistributions.single.moved.months, List.filled(12, -1000));
  });

  group('refused rules', () {
    test('each refusal has its reason', () async {
      await h.apply((l) => l.createRedistribution('ten', draft('food', 'cleaning', 1000)));
      final ledger = await h.ledger();
      final cases = {
        LedgerError.noTree: draft('food', 'cleaning', 1000, year: 2030),
        LedgerError.redistributionSameCategory: draft('rent', 'rent', 1000),
        LedgerError.redistributionNotLeaf: draft('housing', 'rent', 1000),
        LedgerError.redistributionNatureMismatch: draft('rent', 'salary', 1000),
        LedgerError.redistributionPercentInvalid: draft('rent', 'cleaning', 0),
        LedgerError.redistributionDuplicate: draft('food', 'cleaning', 500),
        LedgerError.redistributionTargetIsSource: draft('rent', 'food', 1000),
        LedgerError.redistributionSourceIsTarget: draft('cleaning', 'rent', 1000),
      };
      for (final MapEntry(key: error, value: d) in cases.entries) {
        expect(refusal(() => ledger.createRedistribution('new', d)), error, reason: error.name);
      }
      expect(
        refusal(() => ledger.createRedistribution('new', draft('salary', 'bonus', fullBasisPoints + 1))),
        LedgerError.redistributionPercentInvalid,
      );
      expect(
        refusal(() => ledger.createRedistribution('new', draft(income, 'bonus', 1000))),
        LedgerError.redistributionNotLeaf,
      );
      // Over 100 % from one source, with the total.
      try {
        ledger.createRedistribution('new', draft('food', 'rent', 9001));
        fail('refused');
      } on LedgerException catch (e) {
        expect((e.error, e.count), (LedgerError.redistributionOverHundred, 10001));
      }
      expect(refusal(() => ledger.createRedistribution('new', draft('food', 'rent', 9000))), isNull);
      expect(refusal(() => ledger.createRedistribution('new', draft('salary', 'bonus', 1))), isNull);
      // A modification is checked against the other rules only.
      expect(refusal(() => ledger.updateRedistribution('ten', draft('food', 'cleaning', fullBasisPoints))), isNull);
      expect(
        refusal(() => ledger.updateRedistribution('ten', draft('food', 'cleaning', 1000, year: 2027))),
        LedgerError.unknownRedistribution,
      );
      expect(refusal(() => ledger.deleteRedistribution('none')), LedgerError.unknownRedistribution);
    });

    test('a category used by a rule cannot be deleted, with the number of rules', () async {
      await h.apply((l) => l.createRedistribution('r1', draft('food', 'cleaning', 1000)));
      await h.apply((l) => l.createRedistribution('r2', draft('rent', 'cleaning', 1000)));
      final ledger = await h.ledger();
      try {
        ledger.removeCategory('cleaning');
        fail('refused');
      } on LedgerException catch (e) {
        expect((e.error, e.count), (LedgerError.categoryUsedByRedistributions, 2));
      }
      await h.apply((l) => l.deleteRedistribution('r1'));
      await h.apply((l) => l.deleteRedistribution('r2'));
      await h.apply((l) => l.removeCategory('cleaning'));
    });
  });

  group('a rule that became inapplicable does not apply and is listed', () {
    Future<void> check(RedistributionProblem problem, List<String> ids) async {
      final ledger = await h.ledger();
      expect(ledger.inapplicableRedistributions.map((i) => (i.rule.id, i.problem)).toSet(), {
        for (final id in ids) (id, problem),
      }, reason: problem.name);
      for (final kind in ViewKind.values) {
        final view = ledger.views.of(2026, kind)!;
        expect(view.redistributions.where((r) => ids.contains(r.rule.id)), isEmpty, reason: problem.name);
        expect(view.inapplicable.map((i) => i.rule.id).toSet(), ids.toSet());
      }
    }

    setUp(() async {
      await h.apply((l) => l.recordEntry('a', 'l1', entry(cents: 10000, date: d(2026, 1, 5))));
      await h.apply((l) => l.recordEntry('b', 'l2', entry(category: 'rent', cents: 10000, date: d(2026, 1, 5))));
    });

    test('source or target deleted on another device', () async {
      await h.apply((l) => l.createRedistribution('r', draft('food', 'cleaning', 1000)));
      await h.repository.write(Modification.delete(CategoryFields.entity, 'cleaning'));
      await check(RedistributionProblem.targetMissing, ['r']);
      await h.repository.write(Modification.delete(CategoryFields.entity, 'food'));
      await check(RedistributionProblem.sourceMissing, ['r']);
    });

    test('target that became a group, or detached', () async {
      await h.apply((l) => l.createRedistribution('r', draft('food', 'cleaning', 1000)));
      await h.apply((l) => l.addCategory('soap', year: 2026, name: 'Savon', parentId: 'cleaning'));
      await check(RedistributionProblem.targetNotLeaf, ['r']);
      await h.apply((l) => l.removeCategory('soap'));
      await h.repository.write(Modification.set(CategoryFields.entity, 'cleaning', {CategoryFields.parentId: 'gone'}));
      await check(RedistributionProblem.targetMissing, ['r']);
    });

    test('natures that differ after a move', () async {
      await h.apply((l) => l.createRedistribution('r', draft('food', 'cleaning', 1000)));
      await h.apply((l) => l.moveCategory('cleaning', parentId: income));
      await check(RedistributionProblem.natureMismatch, ['r']);
    });

    test('same category or percentage out of range, written on another device', () async {
      await h.apply((l) => l.createRedistribution('r', draft('food', 'cleaning', 1000)));
      await h.repository.write(
        Modification.set(RedistributionFields.entity, 'r', {RedistributionFields.targetCategoryId: 'food'}),
      );
      await check(RedistributionProblem.sameCategory, ['r']);
      await h.repository.write(raw('r', 'food', 'cleaning', 0));
      await check(RedistributionProblem.percentInvalid, ['r']);
    });

    test('after a merge, more than 100 % from a source: every rule of that source is left aside', () async {
      await h.repository.write(raw('r1', 'food', 'cleaning', 6000));
      await h.repository.write(raw('r2', 'food', 'rent', 5000));
      await h.apply((l) => l.createRedistribution('other', draft('salary', 'bonus', 1000)));
      await check(RedistributionProblem.overHundred, ['r1', 'r2']);
      expect((await h.ledger()).views.of(2026, ViewKind.cash)!.redistributions.single.rule.id, 'other');
    });

    test('after a merge, a target that is also a source: the rules in cause are left aside', () async {
      await h.repository.write(raw('r1', 'food', 'cleaning', 1000));
      await h.repository.write(raw('r2', 'cleaning', 'rent', 1000));
      await check(RedistributionProblem.chain, ['r1', 'r2']);
    });
  });

  test('the rules follow the copy of the tree; two devices copying it offline write the same rules', () async {
    await h.apply((l) => l.createRedistribution('ten', draft('food', 'cleaning', 1000)));
    final other = await LedgerHarness.open(deviceId: 'bbbbbbbb-0000-4000-8000-000000000000');
    addTearDown(other.close);
    await other.journal.merge(await h.journal.entries());
    // Offline, each records the first payment of 2027: each copies the tree.
    Future<void> pay(LedgerHarness device, String id) async {
      final food = (await device.ledger()).treeOrPreview(2027).named('Nourriture')!.id;
      await device.apply((l) => l.recordEntry(id, '$id-l', entry(category: food, cents: 1000, date: d(2027, 1, 4))));
    }

    await pay(h, 'x');
    await pay(other, 'y');
    await other.journal.merge(await h.journal.entries());
    await h.journal.merge(await other.journal.entries());
    final tables = ['redistributions', 'categories'];
    expect(await h.tables(tables), await other.tables(tables));
    final ledger = await h.ledger();
    final copy = ledger.redistributions[copiedRedistributionId('ten', 2027)]!;
    expect(
      (copy.year, copy.sourceId, copy.targetId, copy.basisPoints),
      (2027, copiedCategoryId('food', 2027), copiedCategoryId('cleaning', 2027), 1000),
    );
    expect(ledger.redistributions, hasLength(2));
    expect(ledger.views.of(2027, ViewKind.cash)!.redistributions.single.moved.month(1), -200);
  });
}
