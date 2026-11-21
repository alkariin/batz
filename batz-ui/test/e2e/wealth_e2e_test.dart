// The data of phase 5 between devices, through a real batz-web: declared
// balances and debts entered on one device reach another, which computes
// the same balances and the same open debts; two devices declaring the same
// account the same day write one balance.
import 'package:batz/domain/calendar_date.dart';
import 'package:batz/domain/ledger/account.dart';
import 'package:batz/domain/ledger/balance.dart';
import 'package:batz/domain/ledger/debt.dart';
import 'package:batz/domain/views/balances.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/ledger_fixture.dart';
import 'server_harness.dart';
import 'sync_device.dart';

final today = CalendarDate(2026, 11, 21);

void main() {
  late LocalServer server;
  late SimDevice a, b;
  var wallA = DateTime.utc(2026, 11, 21, 10).millisecondsSinceEpoch, wallB = wallA;

  setUp(() async {
    server = await LocalServer.start();
    a = await SimDevice.create('A', deviceId: 'aaaaaaaa-0000-4000-8000-000000000000', now: () => wallA);
    b = await SimDevice.create('B', deviceId: 'bbbbbbbb-0000-4000-8000-000000000000', now: () => wallB);
    for (final d in [a, b]) {
      await d.pair(server);
    }
    await seedLedger(a.ledger);
    await a.ledger.apply(
      (l) => l.createAccount('savings', const AccountDraft(name: 'Épargne', type: AccountType.savings)),
    );
    await a.sync();
    await b.sync();
  });
  tearDown(() async {
    await a.close();
    await b.close();
    await server.stop();
    server.dataDir.deleteSync(recursive: true);
  });

  test('balances declared on one device reach the other, which computes the same balances', () async {
    await a.ledger.apply((l) => l.declareBalance('savings', d(2025, 12, 31), 1000000, today: today));
    await a.ledger.apply(
      (l) => l.recordTransfer('in', transfer(from: 'private', to: 'savings', cents: 50000, date: d(2026, 3, 15))),
    );
    await a.ledger.apply((l) => l.declareBalance('savings', d(2026, 6, 30), 1080000, today: today));
    await a.sync();
    await b.sync();
    final there = (await b.ledger.ledger()).balances.of('savings');
    expect(there.points.map((p) => (p.date, p.amount)), [(d(2025, 12, 31), 1000000), (d(2026, 6, 30), 1080000)]);
    expect((there.balanceAt(d(2026, 4, 1)), there.variationAt(1)), (1050000, 30000));

    // Deleted on B: A follows.
    await b.ledger.apply((l) => l.deleteBalance(balanceId('savings', d(2026, 6, 30))));
    await b.sync();
    await a.sync();
    expect((await a.ledger.ledger()).balances.of('savings').balanceAt(today), 1050000);
    expect(await a.ledger.tables(['balances']), await b.ledger.tables(['balances']));
  });

  test('debts entered, split and checked on one device reach the other, with the same open debts', () async {
    await a.ledger.apply(
      (l) => l.createDebt(
        'meal',
        DebtDraft(
          direction: DebtDirection.owedToMe,
          person: 'Alex Modèle',
          amount: 20000,
          basisPoints: 5000,
          eventDate: d(2026, 3, 1),
          description: 'Restaurant',
        ),
        today: d(2026, 3, 2),
      ),
    );
    await a.ledger.apply(
      (l) => l.createDebt(
        'loan',
        const DebtDraft(direction: DebtDirection.iOwe, person: 'Camille Exemple', amount: 50000),
        today: d(2026, 4, 1),
      ),
    );
    await a.ledger.apply((l) => l.splitDebt('meal', 'meal-2', 4000));
    await a.ledger.apply((l) => l.checkDebt('meal-2', receivedDate: d(2026, 5, 1), today: d(2026, 5, 3)));
    await a.sync();
    await b.sync();
    final here = await a.ledger.ledger(), there = await b.ledger.ledger();
    expect(there.debts, here.debts);
    expect({for (final debt in there.debts.values) debt.id: debt.total}, {'meal': 4000, 'meal-2': 6000, 'loan': 50000});
    for (final date in [d(2026, 2, 28), d(2026, 3, 1), d(2026, 4, 30), d(2026, 5, 1), today]) {
      expect(there.openDebtsAt(date), here.openDebtsAt(date), reason: '$date');
    }
    expect(there.openDebtsAt(today), 4000 - 50000);

    // Unchecked on B: A follows.
    await b.ledger.apply((l) => l.uncheckDebt('meal-2'));
    await b.sync();
    await a.sync();
    expect((await a.ledger.ledger()).openDebtsAt(today), 10000 - 50000);
    expect(await a.ledger.tables(['debts']), await b.ledger.tables(['debts']));
  });

  test('two devices declaring the same account the same day offline write one balance, the latest', () async {
    wallA += 1000;
    await a.ledger.apply((l) => l.declareBalance('savings', d(2026, 6, 30), 100000, today: today));
    wallB += 2000;
    await b.ledger.apply((l) => l.declareBalance('savings', d(2026, 6, 30), 120000, today: today));
    await a.sync();
    await b.sync();
    await a.sync();
    for (final device in [a, b]) {
      final ledger = await device.ledger.ledger();
      expect(ledger.declaredBalances.values.map((v) => (v.id, v.amount)), [
        (balanceId('savings', d(2026, 6, 30)), 120000),
      ], reason: device.name);
    }
    expect(await a.ledger.tables(['balances']), await b.ledger.tables(['balances']));
  });
}
