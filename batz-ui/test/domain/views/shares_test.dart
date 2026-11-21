import 'package:batz/domain/journal/journal_entry.dart';
import 'package:batz/domain/ledger/category.dart';
import 'package:batz/domain/ledger/ledger.dart';
import 'package:batz/domain/ledger/ledger_exception.dart';
import 'package:batz/domain/ledger/rule.dart';
import 'package:batz/domain/ledger/share_classification.dart';
import 'package:batz/domain/ledger/statement.dart';
import 'package:batz/domain/ledger/transaction.dart';
import 'package:batz/domain/period_model.dart';
import 'package:batz/domain/views/share_operations.dart';
import 'package:batz/domain/views/year_view.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/ledger_fixture.dart';
import '../../support/ledger_harness.dart';
import '../../support/statements.dart';
import '../../support/view_checks.dart';

LedgerError? refusal(void Function() build) {
  try {
    build();
  } on LedgerException catch (e) {
    return e.error;
  }
  return null;
}

final food2027 = copiedCategoryId('food', 2027);
final rent2027 = copiedCategoryId('rent', 2027);

void main() {
  late LedgerHarness h;

  /// 2026 as seeded; 2027 its copy, where « Nourriture » became
  /// « Alimentation ». A food expense of 1'200 for 1.7.2026 – 30.6.2027.
  setUp(() async {
    h = await LedgerHarness.open();
    await seedLedger(h);
    await h.apply((l) => l.createTree(2027));
    await h.apply((l) => l.renameCategory(food2027, 'Alimentation'));
    await h.apply(
      (l) => l.recordEntry(
        'market',
        'l1',
        entry(
          category: 'food',
          cents: 120000,
          date: d(2026, 7, 1),
          periodStart: d(2026, 7, 1),
          periodEnd: d(2027, 6, 30),
        ),
      ),
    );
  });
  tearDown(() => h.close());

  YearView economic(Ledger l, int year) => l.views.of(year, ViewKind.economic)!;

  test('a share carried without a category of the same name is « À classer », counts in its nature and makes a task; '
      'the answer classifies it and stays', () async {
    var ledger = await h.ledger();
    var view = economic(ledger, 2027);
    expect(view.toClassify[CategoryNature.expense]!.months.sublist(0, 6), List.filled(6, -10000));
    expect(view.expenses.total, -60000);
    final group = ledger.views.pendingShares.single;
    expect((group.origin.id, group.originYear, group.year, group.nature), ('food', 2026, 2027, CategoryNature.expense));
    expect(group.shares.map((s) => (s.lineId, s.transaction.id, s.economic, s.cash)), [('l1', 'market', -60000, 0)]);
    expect(ledger.pendingShareCount, 1);
    expect(ledger.views.answerOf('l1', 2027), isNull);

    await h.apply((l) => l.classifyShares(2027, ['l1'], food2027));
    // Reloaded from the database: the answer is kept.
    ledger = await h.ledger();
    view = economic(ledger, 2027);
    expect(view.toClassify[CategoryNature.expense]!.total, 0);
    expect(view.totalOf(food2027), -60000);
    expect(ledger.views.pendingShares, isEmpty);
    expect(ledger.pendingShareCount, 0);
    final answer = ledger.views.answerOf('l1', 2027)!;
    expect(
      (answer.id, answer.categoryId, answer.originCategoryId),
      (shareClassificationId('l1', 2027), food2027, 'food'),
    );
    expect(economic(ledger, 2026).totalOf('food'), -60000, reason: 'the payment year keeps its own category');
    checkViews(ledger, reason: 'answered');
  });

  test(
    'renaming in the year concerned: an answer follows its category; a counterpart by name needs no answer',
    () async {
      await h.apply((l) => l.classifyShares(2027, ['l1'], food2027));
      await h.apply((l) => l.renameCategory(food2027, 'Courses'));
      var ledger = await h.ledger();
      expect(economic(ledger, 2027).totalOf(food2027), -60000, reason: 'the answer names a category, not a name');

      // Without the answer, a category renamed to the same name is found by
      // its name.
      await h.repository.write(
        Modification.delete(ShareClassificationFields.entity, shareClassificationId('l1', 2027)),
      );
      expect((await h.ledger()).views.pendingShares, hasLength(1));
      await h.apply((l) => l.renameCategory(food2027, 'nourriture'));
      ledger = await h.ledger();
      expect(ledger.views.pendingShares, isEmpty);
      expect(economic(ledger, 2027).totalOf(food2027), -60000);
    },
  );

  test('a category of the same name that became a group: the question is asked', () async {
    await h.apply((l) => l.renameCategory(food2027, 'Nourriture'));
    expect((await h.ledger()).views.pendingShares, isEmpty);
    await h.apply((l) => l.addCategory('fresh', year: 2027, name: 'Produits frais', parentId: food2027));
    final ledger = await h.ledger();
    expect(ledger.views.pendingShares.single.year, 2027);
    expect(refusal(() => ledger.classifyShares(2027, ['l1'], food2027)), LedgerError.categoryNotAssignable);
    await h.apply((l) => l.classifyShares(2027, ['l1'], 'fresh'));
    expect(economic(await h.ledger(), 2027).totalOf(food2027), -60000, reason: 'in « Produits frais », below it');
  });

  group('an answer that no longer holds: the question comes back', () {
    setUp(() => h.apply((l) => l.classifyShares(2027, ['l1'], rent2027)));

    test('the category chosen is deleted or becomes a group', () async {
      expect((await h.ledger()).views.pendingShares, isEmpty);
      await h.apply((l) => l.addCategory('heating', year: 2027, name: 'Chauffage', parentId: rent2027));
      expect((await h.ledger()).views.pendingShares.single.shares.single.lineId, 'l1');
      await h.apply((l) => l.removeCategory('heating'));
      expect((await h.ledger()).views.pendingShares, isEmpty);
      await h.apply((l) => l.removeCategory(rent2027));
      final ledger = await h.ledger();
      expect(ledger.views.pendingShares, hasLength(1));
      expect(economic(ledger, 2027).toClassify[CategoryNature.expense]!.total, -60000);
    });

    test('the line changes category: the answer was given for the other one', () async {
      await h.apply(
        (l) =>
            l.addCategory('misc', year: 2026, name: 'Divers', parentId: defaultGroupId(2026, CategoryNature.expense)),
      );
      await h.apply(
        (l) => l.updateEntry(
          'market',
          entry(
            category: 'misc',
            cents: 120000,
            date: d(2026, 7, 1),
            periodStart: d(2026, 7, 1),
            periodEnd: d(2027, 6, 30),
          ),
        ),
      );
      final ledger = await h.ledger();
      expect(ledger.views.answerOf('l1', 2027), isNull);
      expect(ledger.views.pendingShares.single.origin.id, 'misc');
    });
  });

  test('one answer for a group, then one line answered otherwise', () async {
    await h.apply(
      (l) => l.recordEntry(
        'bakery',
        'l2',
        entry(
          category: 'food',
          cents: 24000,
          date: d(2026, 12, 1),
          periodStart: d(2026, 12, 1),
          periodEnd: d(2027, 1, 31),
        ),
      ),
    );
    var ledger = await h.ledger();
    final group = ledger.views.pendingShares.single;
    expect(group.shares.map((s) => (s.lineId, s.economic)), [('l1', -60000), ('l2', -12000)]);
    await h.apply((l) => l.classifyShares(2027, group.shares.map((s) => s.lineId), food2027));
    await h.apply((l) => l.classifyShares(2027, ['l2'], rent2027));
    ledger = await h.ledger();
    final view = economic(ledger, 2027);
    expect((view.totalOf(food2027), view.totalOf(rent2027)), (-60000, -12000));
  });

  test('refusals: another nature, a group, a year before the first tree, an unknown line', () async {
    final ledger = await h.ledger();
    expect(
      refusal(() => ledger.classifyShares(2027, ['l1'], copiedCategoryId('salary', 2027))),
      LedgerError.shareNatureMismatch,
    );
    expect(
      refusal(() => ledger.classifyShares(2027, ['l1'], copiedCategoryId('housing', 2027))),
      LedgerError.categoryNotAssignable,
    );
    expect(refusal(() => ledger.classifyShares(2025, ['l1'], 'food')), LedgerError.noTree);
    expect(refusal(() => ledger.classifyShares(2027, ['none'], food2027)), LedgerError.unknownTransaction);
    expect(refusal(() => ledger.classifyShares(2027, const [], food2027)), LedgerError.unknownTransaction);
  });

  test('answering for a year whose tree is still the copy to come writes the tree in the same modification', () async {
    await h.apply(
      (l) => l.recordEntry(
        'long',
        'l3',
        entry(
          category: 'food',
          cents: 36000,
          date: d(2026, 1, 1),
          periodStart: d(2028, 1, 1),
          periodEnd: d(2028, 12, 31),
        ),
      ),
    );
    var ledger = await h.ledger();
    expect(ledger.trees.containsKey(2028), isFalse);
    final group = ledger.views.pendingShares.firstWhere((g) => g.year == 2028);
    expect(group.shares.single.lineId, 'l3', reason: '2028 copies 2027, where « Nourriture » is « Alimentation »');
    final food2028 = copiedCategoryId(food2027, 2028);
    expect(ledger.views.treeOf(2028)!.byId[food2028]!.name, 'Alimentation');
    final modification = ledger.classifyShares(2028, ['l3'], food2028);
    expect(modification.changes.where((c) => c.entity == CategoryFields.entity), isNotEmpty);
    await h.repository.write(modification);
    ledger = await h.ledger();
    expect(ledger.trees.containsKey(2028), isTrue);
    expect(economic(ledger, 2028).totalOf(food2028), -36000);
  });

  test('the shares of an attached refund follow those of its expense, answers included', () async {
    await h.apply(
      (l) => l.recordEntry(
        'back',
        'l4',
        EntryDraft(
          accountId: 'cash',
          date: d(2026, 8, 1),
          cents: 12000,
          direction: Direction.inflow,
          categoryId: null,
          refundedLineId: 'l1',
        ),
      ),
    );
    var ledger = await h.ledger();
    expect(ledger.views.pendingShares.single.shares.single.economic, -60000 + 6000);
    await h.apply((l) => l.classifyShares(2027, ['l1'], food2027));
    ledger = await h.ledger();
    expect(economic(ledger, 2027).totalOf(food2027), -54000);

    // A refund paid in 2027 of an expense whose category has no
    // counterpart there: a question in the cash-flow view.
    await h.apply((l) => l.recordEntry('fish', 'l5', entry(category: 'food', cents: 8000, date: d(2026, 11, 5))));
    await h.apply(
      (l) => l.recordEntry(
        'fish-back',
        'l6',
        EntryDraft(
          accountId: 'cash',
          date: d(2027, 1, 5),
          cents: 3000,
          direction: Direction.inflow,
          categoryId: null,
          refundedLineId: 'l5',
        ),
      ),
    );
    ledger = await h.ledger();
    final share = ledger.views.pendingShares.single.shares.single;
    expect((share.lineId, share.transaction.id, share.economic, share.cash), ('l5', 'fish', 0, 3000));
    expect(ledger.views.of(2027, ViewKind.cash)!.toClassify[CategoryNature.expense]!.month(1), 3000);
    await h.apply((l) => l.classifyShares(2027, ['l5'], food2027));
    expect((await h.ledger()).views.of(2027, ViewKind.cash)!.totalOf(food2027), 3000);
  });

  test('a line to validate asks too, under the identifier its line will have; validated, the answer holds', () async {
    final january = fixtureStatement('2026-01');
    await h.repository.write(
      (await h.ledger()).importStatement('bank', january.statement, fingerprint: january.fingerprint).modification,
    );
    await h.apply(
      (l) => l.createRule(
        'insurance',
        const RuleDraft(
          year: 2026,
          keywords: ['assurance fictive'],
          targetCategoryId: 'food',
          periodModel: PeriodModel.monthsAfter,
          periodMonths: 12,
        ),
      ),
    );
    var ledger = await h.ledger();
    final insurance = ledger
        .linesOf(statementId('bank', january.fingerprint))
        .singleWhere((t) => t.rawText!.contains('Assurance Fictive'));
    final lineId = Ledger.fallbackLineId(insurance.id);
    expect(ledger.views.pendingShares.single.shares.map((s) => s.lineId), containsAll(['l1', lineId]));
    await h.apply((l) => l.classifyShares(2027, [lineId], food2027));
    final proposal = (await h.ledger()).proposalOf(insurance)!;
    await h.apply((l) => l.classify(insurance.id, proposal));
    ledger = await h.ledger();
    expect(ledger.transactions[insurance.id]!.line!.id, lineId);
    expect(ledger.views.answerOf(lineId, 2027), isNotNull);
    expect(ledger.views.pendingShares.single.shares.map((s) => s.lineId), ['l1']);
  });

  test('two devices answering the same question write the same record: one answer wins on both', () async {
    final other = await LedgerHarness.open(deviceId: 'bbbbbbbb-0000-4000-8000-000000000000');
    addTearDown(other.close);
    await other.journal.merge(await h.journal.entries());
    await h.apply((l) => l.classifyShares(2027, ['l1'], food2027));
    await other.apply((l) => l.classifyShares(2027, ['l1'], rent2027));
    await other.journal.merge(await h.journal.entries());
    await h.journal.merge(await other.journal.entries());
    expect(await h.tables(['share_classifications']), await other.tables(['share_classifications']));
    final here = await h.ledger(), there = await other.ledger();
    expect(here.shareClassifications, hasLength(1));
    expect(here.views.answerOf('l1', 2027), there.views.answerOf('l1', 2027));
    expect(economic(here, 2027).totals, economic(there, 2027).totals);
  });
}
