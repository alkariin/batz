import 'package:batz/domain/calendar_date.dart';
import 'package:batz/domain/journal/journal_entry.dart';
import 'package:batz/domain/ledger/ledger.dart';
import 'package:batz/domain/ledger/ledger_exception.dart';
import 'package:batz/domain/modules/subscriptions.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/ledger_fixture.dart';
import '../../support/ledger_harness.dart';
import '../../support/module_checks.dart';

Matcher throwsLedger(LedgerError error) => throwsA(isA<LedgerException>().having((e) => e.error, 'error', error));

TrancheDraft tranche(int cents, TrancheFrequency frequency, CalendarDate start, [CalendarDate? end]) =>
    TrancheDraft(amount: cents, frequency: frequency, start: start, end: end);

/// The reference example: « Streaming » at 12.90 a month from 1.3.2025 to
/// 31.12.2025, then 14.90 from 1.1.2026; « Assurance vélo » at 95.00 a year
/// from 1.6.2024; « Salle de sport », ended on 30.9.2025.
Future<Ledger> subscriptionExample(Future<Ledger> Function(Modification Function(Ledger l) build) apply) async {
  await apply(
    (l) => l.createSubscription(
      'streaming',
      'streaming-1',
      name: 'Streaming',
      first: tranche(1290, TrancheFrequency.monthly, d(2025, 3, 1)),
    ),
  );
  await apply((l) => l.addTranche('streaming', 'streaming-2', tranche(1490, TrancheFrequency.monthly, d(2026, 1, 1))));
  await apply(
    (l) => l.createSubscription(
      'bike',
      'bike-1',
      name: 'Assurance vélo',
      first: tranche(9500, TrancheFrequency.yearly, d(2024, 6, 1)),
    ),
  );
  return apply(
    (l) => l.createSubscription(
      'gym',
      'gym-1',
      name: 'Salle de sport',
      note: 'Résilié',
      first: tranche(6900, TrancheFrequency.monthly, d(2024, 10, 1), d(2025, 9, 30)),
    ),
  );
}

void main() {
  late LedgerHarness h;
  setUp(() async => h = await LedgerHarness.open());
  tearDown(() => h.close());

  test('the example seen on 21.11.2026: 22.82 a month and 273.80 a year; the gym ended', () async {
    final ledger = await subscriptionExample(h.apply);
    final at = ledger.subscriptionsAt(d(2026, 11, 21));
    expect(
      [
        for (final s in at.inState(SubscriptionState.current))
          (s.name, s.trancheAt(at.date)!.monthlyCost, s.trancheAt(at.date)!.yearlyCost),
      ],
      [('Assurance vélo', 792, 9500), ('Streaming', 1490, 17880)],
    );
    expect((at.monthlyTotal, at.yearlyTotal), (2282, 27380));
    expect(at.inState(SubscriptionState.ended).map((s) => s.name), ['Salle de sport']);
    expect(at.inState(SubscriptionState.upcoming), isEmpty);
    final streaming = ledger.modules.subscriptions['streaming']!;
    expect(streaming.tranches.map((t) => (t.start, t.end)), [(d(2025, 3, 1), d(2025, 12, 31)), (d(2026, 1, 1), null)]);
  });

  test('a change of price is a new tranche, which closes the previous one the day before; a resumption after an '
      'end; a subscription to come', () async {
    await subscriptionExample(h.apply);
    var ledger = await h.apply(
      (l) => l.addTranche('streaming', 'streaming-3', tranche(1690, TrancheFrequency.monthly, d(2027, 2, 1))),
    );
    final streaming = ledger.modules.subscriptions['streaming']!;
    expect(streaming.tranches[1].end, d(2027, 1, 31));
    expect(streaming.trancheAt(d(2027, 2, 1))!.amount, 1690);
    ledger = await h.apply((l) => l.addTranche('gym', 'gym-2', tranche(7500, TrancheFrequency.monthly, d(2026, 9, 1))));
    final gym = ledger.modules.subscriptions['gym']!;
    expect(gym.tranches.first.end, d(2025, 9, 30), reason: 'already ended: kept');
    expect(gym.stateAt(d(2026, 11, 21)), SubscriptionState.current);
    expect(gym.stateAt(d(2026, 1, 1)), SubscriptionState.upcoming);
    expect(ledger.subscriptionsAt(d(2026, 11, 21)).monthlyTotal, 1490 + 792 + 7500);
  });

  test('each refusal has its reason: no name, an amount of zero or less, an end before the start, a tranche '
      'overlapping another', () async {
    final ledger = await subscriptionExample(h.apply);
    expect(
      () =>
          ledger.createSubscription('x', 'x1', name: ' ', first: tranche(100, TrancheFrequency.monthly, d(2026, 1, 1))),
      throwsLedger(LedgerError.nameRequired),
    );
    expect(
      () => ledger.createSubscription('x', 'x1', name: 'X', first: tranche(0, TrancheFrequency.monthly, d(2026, 1, 1))),
      throwsLedger(LedgerError.amountRequired),
    );
    expect(
      () => ledger.createSubscription(
        'x',
        'x1',
        name: 'X',
        first: tranche(100, TrancheFrequency.monthly, d(2026, 1, 2), d(2026, 1, 1)),
      ),
      throwsLedger(LedgerError.trancheEndBeforeStart),
    );
    expect(
      () => ledger.addTranche('streaming', 'x', tranche(100, TrancheFrequency.monthly, d(2025, 6, 1), d(2025, 8, 31))),
      throwsLedger(LedgerError.trancheOverlap),
    );
    expect(
      () => ledger.addTranche('gym', 'x', tranche(100, TrancheFrequency.monthly, d(2024, 1, 1))),
      throwsLedger(LedgerError.trancheOverlap),
      reason: 'open-ended, it would cover the ended tranche',
    );
    expect(
      () => ledger.updateTranche('streaming-1', tranche(1290, TrancheFrequency.monthly, d(2025, 3, 1), d(2026, 1, 15))),
      throwsLedger(LedgerError.trancheOverlap),
    );
    expect(
      () => ledger.addTranche('gone', 'x', tranche(100, TrancheFrequency.monthly, d(2026, 1, 1))),
      throwsLedger(LedgerError.unknownSubscription),
    );
  });

  test(
    'two tranches left overlapping by a merge: the one that started last applies, and the overlap is signalled',
    () async {
      var wallA = 1000, wallB = 1000;
      final a = await LedgerHarness.open(deviceId: 'aaaaaaaa-0000-4000-8000-000000000000', now: () => wallA);
      final b = await LedgerHarness.open(deviceId: 'bbbbbbbb-0000-4000-8000-000000000000', now: () => wallB);
      addTearDown(a.close);
      addTearDown(b.close);
      await a.apply(
        (l) => l.createSubscription(
          's',
          's1',
          name: 'Journal',
          first: tranche(2000, TrancheFrequency.monthly, d(2025, 1, 1), d(2026, 12, 31)),
        ),
      );
      await b.journal.merge(await a.journal.entries());
      wallA = 5000;
      await a.apply((l) => l.addTranche('s', 'from-a', tranche(2500, TrancheFrequency.monthly, d(2027, 1, 1))));
      wallB = 7000;
      await b.apply((l) => l.updateTranche('s1', tranche(2000, TrancheFrequency.monthly, d(2025, 1, 1))));
      final fromA = await a.journal.entries(), fromB = await b.journal.entries();
      await a.journal.merge(fromB);
      await b.journal.merge(fromA);
      final subscription = (await a.ledger()).modules.subscriptions['s']!;
      expect(subscription.hasOverlap, isTrue);
      expect(subscription.trancheAt(d(2027, 3, 1))!.id, 'from-a');
      expect(subscription.trancheAt(d(2026, 3, 1))!.id, 's1');
      expect(
        await a.tables(['subscriptions', 'subscription_tranches']),
        await b.tables(['subscriptions', 'subscription_tranches']),
      );
    },
  );

  test('a subscription is modified, its tranches modified and deleted, then it is deleted with them', () async {
    await subscriptionExample(h.apply);
    var ledger = await h.apply(
      (l) => l.updateSubscription('bike', name: 'Assurance vélo électrique', note: 'Police 12'),
    );
    expect(
      (ledger.modules.subscriptions['bike']!.name, ledger.modules.subscriptions['bike']!.note),
      ('Assurance vélo électrique', 'Police 12'),
    );
    ledger = await h.apply((l) => l.updateTranche('bike-1', tranche(12000, TrancheFrequency.yearly, d(2024, 6, 1))));
    expect(ledger.subscriptionsAt(d(2026, 11, 21)).monthlyTotal, 1490 + 1000);
    ledger = await h.apply((l) => l.deleteTranche('streaming-1'));
    expect(ledger.modules.subscriptions['streaming']!.tranches, hasLength(1));
    ledger = await h.apply((l) => l.deleteSubscription('streaming'));
    expect(ledger.modules.subscriptions.keys.toSet(), {'bike', 'gym'});
  });

  test('subscriptions change neither the annual views nor the wealth', () async {
    final today = d(2026, 11, 21);
    await seedLedger(h);
    await h.apply((l) => l.recordEntry('a', 'la', entry(cents: 1290, date: d(2026, 3, 1))));
    final before = accountsAndViews(await h.ledger(), today);
    await subscriptionExample(h.apply);
    expect(accountsAndViews(await h.ledger(), today), before);
  });
}
