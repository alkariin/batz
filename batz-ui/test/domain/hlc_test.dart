import 'dart:math';

import 'package:batz/domain/journal/hlc.dart';
import 'package:flutter_test/flutter_test.dart';

const a = 'aaaaaaaa-0000-4000-8000-000000000000';
const b = 'bbbbbbbb-0000-4000-8000-000000000000';

void main() {
  group('Hlc', () {
    test('orders by time, then counter, then device', () {
      expect(Hlc(2, 0, a) > Hlc(1, 9, b), isTrue);
      expect(Hlc(1, 2, a) > Hlc(1, 1, b), isTrue);
      expect(Hlc(1, 1, b) > Hlc(1, 1, a), isTrue, reason: 'the device identifier breaks ties');
      expect(Hlc(1, 1, a) == Hlc(1, 1, a), isTrue);
      expect(Hlc(1, 1, a) == Hlc(1, 1, b), isFalse);
    });

    test('encodes into text that sorts like the timestamps', () {
      final random = Random(42);
      final devices = [a, b, '0', 'f', 'abc-def'];
      final hlcs = [
        for (var i = 0; i < 500; i++)
          Hlc(
            random.nextBool() ? random.nextInt(5) : random.nextInt(1 << 32) * 1000,
            random.nextInt(Hlc.maxCounter + 1),
            devices[random.nextInt(devices.length)],
          ),
      ];
      final byValue = [...hlcs]..sort();
      final byText = [...hlcs]..sort((x, y) => x.encode().compareTo(y.encode()));
      expect(byText, byValue);
      for (final h in hlcs) {
        expect(Hlc.parse(h.encode()), h);
      }
    });

    test('rejects invalid values', () {
      expect(() => Hlc(-1, 0, a), throwsArgumentError);
      expect(() => Hlc(0, Hlc.maxCounter + 1, a), throwsArgumentError);
      expect(() => Hlc(Hlc.maxMillis + 1, 0, a), throwsArgumentError);
      expect(() => Hlc(0, 0, 'Device:1'), throwsArgumentError);
      expect(() => Hlc(0, 0, ''), throwsArgumentError);
      expect(() => Hlc.parse('1:2'), throwsFormatException);
      expect(() => Hlc.parse('00000000000000x:0000:$a'), throwsFormatException);
    });
  });

  group('HlcClock', () {
    test('follows the wall clock', () {
      var wall = 1000;
      final clock = HlcClock(a, now: () => wall);
      expect(clock.tick(), Hlc(1000, 0, a));
      wall = 1005;
      expect(clock.tick(), Hlc(1005, 0, a));
    });

    test('counts events within the same millisecond', () {
      final clock = HlcClock(a, now: () => 1000);
      expect([clock.tick(), clock.tick(), clock.tick()], [Hlc(1000, 0, a), Hlc(1000, 1, a), Hlc(1000, 2, a)]);
    });

    test('never goes backwards when the wall clock does', () {
      var wall = 5000;
      final clock = HlcClock(a, now: () => wall);
      final before = clock.tick();
      wall = 1000; // clock set back
      final after = clock.tick();
      expect(after > before, isTrue);
      expect(after, Hlc(5000, 1, a));
    });

    test('resumes after the last known timestamp', () {
      final clock = HlcClock(a, last: Hlc(9000, 7, b), now: () => 1000);
      expect(clock.tick(), Hlc(9000, 8, a));
    });

    test('moves past an observed timestamp from the future', () {
      final clock = HlcClock(a, now: () => 1000);
      clock.observe(Hlc(50000, 3, b));
      final next = clock.tick();
      expect(next > Hlc(50000, 3, b), isTrue);
      expect(next, Hlc(50000, 4, a));
    });

    test('ignores an observed timestamp from the past', () {
      final clock = HlcClock(a, now: () => 1000);
      clock.observe(Hlc(10, 3, b));
      expect(clock.tick(), Hlc(1000, 0, a));
    });

    test('observing the same millisecond keeps the larger counter', () {
      final clock = HlcClock(a, now: () => 1000);
      clock.tick(); // 1000:0
      clock.observe(Hlc(1000, 9, b));
      expect(clock.tick(), Hlc(1000, 10, a));
      clock.observe(Hlc(1000, 2, b));
      expect(clock.tick(), Hlc(1000, 11, a));
    });

    test('every tick exceeds everything seen, whatever the interleaving', () {
      final random = Random(7);
      var wall = 1000;
      final clock = HlcClock(a, now: () => wall);
      Hlc? highest;
      for (var i = 0; i < 2000; i++) {
        wall += random.nextInt(5) - 2; // jitter, sometimes backwards
        if (random.nextBool()) {
          final remote = Hlc(wall + random.nextInt(50) - 25, random.nextInt(20), b);
          clock.observe(remote);
          if (highest == null || remote > highest) highest = remote;
        } else {
          final t = clock.tick();
          if (highest != null) expect(t > highest, isTrue, reason: '$t after $highest');
          highest = t;
        }
      }
    });

    test('reports counter exhaustion', () {
      final clock = HlcClock(a, last: Hlc(1000, Hlc.maxCounter - 1, a), now: () => 1000);
      expect(clock.tick(), Hlc(1000, Hlc.maxCounter, a));
      expect(clock.tick, throwsA(isA<HlcOverflowException>()));
    });
  });
}
