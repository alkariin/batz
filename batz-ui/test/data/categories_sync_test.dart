import 'package:batz/domain/ledger/category.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/ledger_harness.dart';

const deviceA = 'aaaaaaaa-0000-4000-8000-000000000000';
const deviceB = 'bbbbbbbb-0000-4000-8000-000000000000';

void main() {
  test(
    'two copies of the same tree, made on two devices, give the same records once the journals are merged',
    () async {
      var wallA = 1000, wallB = 1000;
      final a = await LedgerHarness.open(deviceId: deviceA, now: () => wallA);
      final b = await LedgerHarness.open(deviceId: deviceB, now: () => wallB);

      // Device A builds the 2026 tree; device B receives it.
      final expenses = defaultGroupId(2026, CategoryNature.expense);
      await a.apply((l) => l.createTree(2026));
      await a.apply((l) => l.addCategory('housing', year: 2026, name: 'Logement', parentId: expenses));
      await a.apply((l) => l.addCategory('rent', year: 2026, name: 'Loyer', parentId: 'housing'));
      await a.apply((l) => l.addCategory('food', year: 2026, name: 'Nourriture', parentId: expenses));
      await b.journal.merge(await a.journal.entries());

      // Both copy it to 2027, offline, at different times.
      wallA = 5000;
      await a.apply((l) => l.createTree(2027));
      wallB = 7000;
      await b.apply((l) => l.createTree(2027));

      // Synchronisation, both ways.
      final fromA = await a.journal.entries(), fromB = await b.journal.entries();
      await a.journal.merge(fromB);
      await b.journal.merge(fromA);

      final tablesA = await a.tables(['categories']), tablesB = await b.tables(['categories']);
      expect(tablesA, tablesB);
      final rows = tablesA['categories']!;
      expect(rows.where((r) => r['year'] == 2027), hasLength(5), reason: 'one tree, not two');
      expect(rows, hasLength(10));

      final ledger = await a.ledger();
      expect(ledger.trees[2027]!.ordered.map((c) => c.name), [
        'Revenus',
        'Dépenses',
        'Logement',
        'Loyer',
        'Nourriture',
      ]);
      expect((await b.ledger()).trees[2027]!.byId, ledger.trees[2027]!.byId);
      await a.close();
      await b.close();
    },
  );

  test('a category whose parent has not arrived yet appears once it does', () async {
    final a = await LedgerHarness.open(deviceId: deviceA);
    final b = await LedgerHarness.open(deviceId: deviceB);
    await a.apply((l) => l.createTree(2026));
    await a.apply(
      (l) => l.addCategory(
        'housing',
        year: 2026,
        name: 'Logement',
        parentId: defaultGroupId(2026, CategoryNature.expense),
      ),
    );
    await a.apply((l) => l.addCategory('rent', year: 2026, name: 'Loyer', parentId: 'housing'));

    final entries = await a.journal.entries();
    final rentFirst = entries.where((e) => e.recordId == 'rent').toList();
    await b.journal.merge(rentFirst);
    expect((await b.ledger()).categories, isEmpty);
    await b.journal.merge(entries);
    expect((await b.ledger()).categories.keys, containsAll(['housing', 'rent']));
    await a.close();
    await b.close();
  });
}
