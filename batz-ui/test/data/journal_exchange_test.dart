import 'dart:math';

import 'package:batz/data/local/journal.dart';
import 'package:batz/domain/journal/hlc.dart';
import 'package:batz/domain/journal/journal_entry.dart';
import 'package:batz/domain/journal/known_state.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/journal_harness.dart';

const me = '11111111-0000-4000-8000-000000000000';
const other = '22222222-0000-4000-8000-000000000000';
const third = '33333333-0000-4000-8000-000000000000';

/// [size] entries sharing one timestamp: one modification of [device].
List<JournalEntry> modification(int millis, String device, int size) => [
  for (var i = 0; i < size; i++)
    entry(millis, 0, device, 'n$millis', ['title', 'amount', 'done'][i % 3], i % 3 == 0 ? 'x$i' : i),
];

void main() {
  test('the known state holds the latest timestamp of each origin', () async {
    final h = await Harness.open(now: () => 5000, deviceId: me);
    expect(await h.journal.knownState(), KnownState.empty);
    await h.journal.write(Modification.set('note', 'n1', {'title': 'a'}));
    await h.journal.merge([...modification(1000, other, 2), ...modification(3000, other, 1)]);
    expect(await h.journal.knownState(), KnownState({me: Hlc(5000, 0, me), other: Hlc(3000, 0, other)}));
    await h.close();
  });

  group('missing entries', () {
    late Harness h;
    setUp(() async {
      h = await Harness.open(deviceId: me);
      await h.journal.merge([
        ...modification(1000, me, 3),
        ...modification(2000, other, 2),
        ...modification(3000, me, 3),
        ...modification(4000, third, 1),
      ]);
    });
    tearDown(() => h.close());

    test('everything for a copy that holds nothing, oldest first', () async {
      final page = await h.journal.missingFrom(KnownState.empty);
      expect(page.entries.map((e) => e.hlc.millis), [1000, 1000, 1000, 2000, 2000, 3000, 3000, 3000, 4000]);
      expect(page.more, isFalse);
      expect(page.since, KnownState.empty);
    });

    test('only what comes after the known timestamp of each origin, and every origin it lacks', () async {
      final known = KnownState({me: Hlc(1000, 0, me), other: Hlc(2000, 0, other)});
      final page = await h.journal.missingFrom(known);
      expect(page.entries.map((e) => (e.hlc.millis, e.deviceId)).toSet(), {(3000, me), (4000, third)});
      expect(page.since, KnownState({me: Hlc(1000, 0, me)}), reason: 'what the page continues from');
      expect(await h.journal.pendingFor(known), 2, reason: 'two modifications');
      expect(await h.journal.pendingFor(await h.journal.knownState()), 0);
    });

    test('a page never cuts a modification, and a large one goes whole', () async {
      final sizes = <int>[];
      var known = KnownState.empty;
      for (var i = 0; i < 10; i++) {
        final page = await h.journal.missingFrom(known, limit: 2);
        if (page.entries.isNotEmpty) sizes.add(page.entries.length);
        known = known.plus(page.entries);
        if (!page.more) break;
      }
      expect(sizes, [3, 2, 3, 1]);
      expect(known, await h.journal.knownState());
    });

    test('a page stops at its byte budget', () async {
      final page = await h.journal.missingFrom(KnownState.empty, maxBytes: 300);
      expect(page.entries.map((e) => e.hlc.millis).toSet(), {1000});
      expect(page.more, isTrue);
    });
  });

  group('integration', () {
    test('a page is integrated in one operation; replaying it adds nothing', () async {
      final h = await Harness.open(deviceId: me);
      final page = JournalPage([...modification(1000, other, 3), ...modification(2000, other, 2)]);
      expect(await h.journal.integrate(page), 5);
      expect(await h.journal.integrate(page), 0);
      expect(await h.journal.entries(), hasLength(5));
      await h.close();
    });

    test('a page that continues from more than is held is refused, nothing written', () async {
      final h = await Harness.open(deviceId: me);
      await h.journal.integrate(JournalPage(modification(1000, other, 1)));
      final gap = JournalPage(modification(3000, other, 1), since: KnownState({other: Hlc(2000, 0, other)}));
      await expectLater(h.journal.integrate(gap), throwsA(isA<JournalGapException>()));
      expect(await h.journal.entries(), hasLength(1));

      final fine = JournalPage(modification(3000, other, 1), since: KnownState({other: Hlc(1000, 0, other)}));
      expect(await h.journal.integrate(fine), 1);
      await h.close();
    });

    test('a failure half-way leaves nothing of the page', () async {
      final h = await Harness.open(deviceId: me);
      await h.db.customStatement(
        'CREATE TRIGGER boom BEFORE INSERT ON notes WHEN NEW.id = \'n2000\' '
        "BEGIN SELECT RAISE(ABORT, 'boom'); END",
      );
      final page = JournalPage([...modification(1000, other, 2), ...modification(2000, other, 2)]);
      await expectLater(h.journal.integrate(page), throwsA(anything));
      expect(await h.journal.entries(), isEmpty);
      expect(await h.allRows(), isEmpty);
      await h.close();
    });
  });

  test(
    'copies that exchange pages in random sizes and orders converge, each holding a prefix of every origin',
    () async {
      final random = Random(20261120);
      for (var round = 0; round < 10; round++) {
        final copies = [
          for (final id in [me, other, third]) await Harness.open(deviceId: id),
        ];
        for (var step = 0; step < 40; step++) {
          final a = copies[random.nextInt(3)];
          if (random.nextBool()) {
            await a.journal.write(
              Modification.set('note', 'n${random.nextInt(4)}', {
                'title': 't$step',
                if (random.nextBool()) 'amount': random.nextInt(100),
              }),
            );
          } else {
            final b = copies[random.nextInt(3)];
            final page = await a.journal.missingFrom(await b.journal.knownState(), limit: 1 + random.nextInt(4));
            await b.journal.integrate(page);
            await _checkPrefixes(copies);
          }
        }
        // Pages until nothing is left to exchange.
        for (var pass = 0; pass < 2; pass++) {
          for (final a in copies) {
            for (final b in copies) {
              while (true) {
                final page = await a.journal.missingFrom(await b.journal.knownState(), limit: 3);
                await b.journal.integrate(page);
                if (!page.more) break;
              }
            }
          }
        }
        final notes = await copies.first.notes();
        final known = await copies.first.journal.knownState();
        for (final c in copies) {
          expect(await c.notes(), notes, reason: 'round $round');
          expect(await c.journal.knownState(), known);
        }
        for (final c in copies) {
          await c.close();
        }
      }
    },
  );
}

/// Every copy holds, for each origin, exactly that origin's own entries up to
/// its known timestamp: a prefix, without a gap.
Future<void> _checkPrefixes(List<Harness> copies) async {
  final own = {for (final c in copies) c.journal.deviceId: await c.journal.entries()};
  for (final c in copies) {
    final known = await c.journal.knownState();
    final held = (await c.journal.entries()).map((e) => '${e.hlc} ${e.change}').toSet();
    for (final MapEntry(key: origin, value: entries) in own.entries) {
      final expected = {
        for (final e in entries)
          if (e.deviceId == origin && known.holds(e.hlc)) '${e.hlc} ${e.change}',
      };
      final actual = held.where((s) => s.contains(':$origin ')).toSet();
      expect(actual, expected, reason: '${c.journal.deviceId} holds a prefix of $origin');
    }
  }
}
