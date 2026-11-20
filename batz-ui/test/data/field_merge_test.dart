import 'package:batz/domain/ledger/category.dart';
import 'package:batz/domain/ledger/transaction.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/ledger_fixture.dart';
import '../support/ledger_harness.dart';
import 'categories_sync_test.dart' show deviceA, deviceB;

/// The draft a screen submits for [t]: every field, as it stands, with
/// [note] or [category] replaced.
EntryDraft draftOf(LedgerTransaction t, {String? note, String? category}) => EntryDraft(
  accountId: t.accountId,
  date: t.date,
  cents: t.amount.abs(),
  direction: t.amount < 0 ? Direction.outflow : Direction.inflow,
  categoryId: category ?? t.line!.categoryId!,
  description: t.description,
  note: note ?? t.note,
  periodStart: t.line!.periodStart,
  periodEnd: t.line!.periodEnd,
);

void main() {
  test('a full update writes only the fields it changes, so concurrent edits of other fields survive', () async {
    var wallA = 1000, wallB = 1000;
    final a = await LedgerHarness.open(deviceId: deviceA, now: () => wallA);
    final b = await LedgerHarness.open(deviceId: deviceB, now: () => wallB);
    await seedLedger(a);
    await a.apply((l) => l.recordEntry('t1', 'l1', entry(cents: 4500, description: 'Coop')));
    await b.journal.merge(await a.journal.entries());

    // Offline: A corrects the note, then B changes the category, later.
    wallA = 5000;
    var t1 = (await a.ledger()).transactions['t1']!;
    await a.apply((l) => l.updateEntry('t1', draftOf(t1, note: 'Avec les fruits')));
    final written = (await a.journal.entries()).where((e) => e.hlc.millis == 5000).map((e) => e.field);
    expect(written, ['note'], reason: 'the screen submits every field, only the note changed');

    wallB = 7000;
    t1 = (await b.ledger()).transactions['t1']!;
    await b.apply((l) => l.updateEntry('t1', draftOf(t1, category: 'rent')));

    final fromA = await a.journal.entries(), fromB = await b.journal.entries();
    await a.journal.merge(fromB);
    await b.journal.merge(fromA);

    for (final device in [a, b]) {
      final t = (await device.ledger()).transactions['t1']!;
      expect(t.note, 'Avec les fruits');
      expect(t.line!.categoryId, 'rent');
      expect(t.amount, -4500);
    }
    expect(
      await a.tables(['transactions', 'transaction_lines']),
      await b.tables(['transactions', 'transaction_lines']),
    );
    await a.close();
    await b.close();
  });

  test('a move made on two devices at the same time can detach categories, which can be put back', () async {
    var wallA = 1000, wallB = 1000;
    final a = await LedgerHarness.open(deviceId: deviceA, now: () => wallA);
    final b = await LedgerHarness.open(deviceId: deviceB, now: () => wallB);
    await seedLedger(a);
    await b.journal.merge(await a.journal.entries());

    // Logement and Nourriture are siblings; each device puts one under the
    // other.
    wallA = 5000;
    await a.apply((l) => l.moveCategory('housing', parentId: 'food'));
    wallB = 6000;
    await b.apply((l) => l.moveCategory('food', parentId: 'housing'));
    final fromA = await a.journal.entries(), fromB = await b.journal.entries();
    await a.journal.merge(fromB);
    await b.journal.merge(fromA);

    final ledger = await a.ledger();
    expect(ledger.forest.detachedHeads(2026).map((d) => d.category.id), ['housing', 'food']);
    expect(ledger.forest.detached['rent']!.reason, DetachReason.detachedAncestor);

    wallA = 8000;
    final back = await a.apply(
      (l) => l.moveCategory('housing', parentId: defaultGroupId(2026, CategoryNature.expense)),
    );
    expect(back.forest.detached, isEmpty);
    expect(back.trees[2026]!.byId.keys, containsAll(['housing', 'food', 'rent']));
    await a.close();
    await b.close();
  });
}
