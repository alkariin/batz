// The data of the annual view between devices, through a real batz-web: the
// redistribution rules, the refunds attached and the answers given on one
// device reach another, which computes the same views; copying a tree on two
// devices offline gives the same redistribution rules.
import 'package:batz/domain/ledger/category.dart';
import 'package:batz/domain/ledger/redistribution.dart';
import 'package:batz/domain/ledger/refund.dart';
import 'package:batz/domain/ledger/transaction.dart';
import 'package:batz/domain/views/share_operations.dart';
import 'package:batz/domain/views/year_view.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/ledger_fixture.dart';
import 'server_harness.dart';
import 'sync_device.dart';

void main() {
  late LocalServer server;
  late SimDevice a, b;

  setUp(() async {
    server = await LocalServer.start();
    a = await SimDevice.create('A', deviceId: 'aaaaaaaa-0000-4000-8000-000000000000');
    b = await SimDevice.create('B', deviceId: 'bbbbbbbb-0000-4000-8000-000000000000');
    for (final d in [a, b]) {
      await d.pair(server);
    }
    await seedLedger(a.ledger);
    await a.ledger.apply((l) => l.addCategory('cleaning', year: 2026, name: 'Entretien ménage', parentId: 'housing'));
    await a.sync();
    await b.sync();
  });
  tearDown(() async {
    await a.close();
    await b.close();
    await server.stop();
    server.dataDir.deleteSync(recursive: true);
  });

  Future<void> expectSameViews(List<int> years) async {
    final here = await a.ledger.ledger(), there = await b.ledger.ledger();
    for (final year in years) {
      for (final kind in ViewKind.values) {
        final x = here.views.of(year, kind)!, y = there.views.of(year, kind)!;
        expect(y.totals, x.totals, reason: '$kind $year');
        expect(y.toClassify, x.toClassify, reason: '$kind $year');
        expect(
          [for (final line in y.redistributions) (line.rule.id, line.moved)],
          [for (final line in x.redistributions) (line.rule.id, line.moved)],
          reason: '$kind $year',
        );
      }
    }
  }

  test('redistribution rules, attached refunds and answers entered on one device reach the other', () async {
    final h = a.ledger;
    await h.apply(
      (l) => l.createRedistribution(
        'ten',
        const RedistributionDraft(year: 2026, sourceId: 'food', targetId: 'cleaning', basisPoints: 1000),
      ),
    );
    await h.apply(
      (l) => l.recordEntry(
        'visit',
        'visit-line',
        entry(
          category: 'food',
          cents: 30000,
          date: d(2026, 1, 15),
          periodStart: d(2026, 1, 1),
          periodEnd: d(2026, 3, 31),
        ),
      ),
    );
    await h.apply(
      (l) => l.recordEntry(
        'back',
        'back-line',
        EntryDraft(
          accountId: 'cash',
          date: d(2026, 5, 20),
          cents: 12000,
          direction: Direction.inflow,
          categoryId: null,
          refundedLineId: 'visit-line',
        ),
      ),
    );
    // A share in 2027, whose « Nourriture » is renamed: answered.
    await h.apply(
      (l) => l.recordEntry(
        'market',
        'market-line',
        entry(
          category: 'food',
          cents: 120000,
          date: d(2026, 7, 1),
          periodStart: d(2026, 7, 1),
          periodEnd: d(2027, 6, 30),
        ),
      ),
    );
    await h.apply((l) => l.createTree(2027));
    final food2027 = copiedCategoryId('food', 2027);
    await h.apply((l) => l.renameCategory(food2027, 'Alimentation'));
    expect((await h.ledger()).pendingShareCount, 1);
    await h.apply((l) => l.classifyShares(2027, ['market-line'], food2027));

    await a.sync();
    await b.sync();
    final there = await b.ledger.ledger();
    expect(there.redistributions.keys.toSet(), {'ten', copiedRedistributionId('ten', 2027)});
    expect(there.refundsOf(there.transactions['visit']!).map((t) => t.id), ['back']);
    expect(there.netCostOf(there.transactions['visit']!), -18000);
    expect(there.views.answerOf('market-line', 2027)!.categoryId, food2027);
    expect(there.pendingShareCount, 0);
    expect(there.views.of(2026, ViewKind.economic)!.redistributions.single.moved.month(1), -1000 + 400);
    await expectSameViews([2026, 2027]);

    // Detached on B: A follows.
    await b.ledger.apply((l) => l.detachRefund('back'));
    await b.sync();
    await a.sync();
    expect((await a.ledger.ledger()).brokenRefunds, isEmpty);
    expect((await a.ledger.ledger()).refundsOf((await a.ledger.ledger()).transactions['visit']!), isEmpty);
    await expectSameViews([2026, 2027]);
  });

  test('the copy of a tree made on two devices offline gives the same redistribution rules', () async {
    await a.ledger.apply(
      (l) => l.createRedistribution(
        'ten',
        const RedistributionDraft(year: 2026, sourceId: 'food', targetId: 'cleaning', basisPoints: 1000),
      ),
    );
    await a.sync();
    await b.sync();
    // Offline, each records a first payment of 2027.
    for (final (device, id) in [(a, 'x'), (b, 'y')]) {
      final food = (await device.ledger.ledger()).treeOrPreview(2027).named('Nourriture')!.id;
      await device.ledger.apply(
        (l) => l.recordEntry(id, '$id-l', entry(category: food, cents: 5000, date: d(2027, 2, 1))),
      );
    }
    await a.sync();
    await b.sync();
    await a.sync();
    final tables = ['redistributions', 'categories', 'rules'];
    expect(await b.ledger.tables(tables), await a.ledger.tables(tables));
    final ledger = await a.ledger.ledger();
    expect(ledger.redistributionsOf(2027).map((r) => r.id), [copiedRedistributionId('ten', 2027)]);
    expect(ledger.views.of(2027, ViewKind.cash)!.redistributions.single.moved.month(2), -1000);
    await expectSameViews([2026, 2027]);
  });
}
