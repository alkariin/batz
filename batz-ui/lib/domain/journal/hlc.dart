/// Hybrid logical clock (Kulkarni et al.): orders the changes made on several
/// devices whose wall clocks are not synchronised.
///
/// A timestamp is the wall time in milliseconds, a counter that orders events
/// within the same millisecond or while the wall clock lags behind, and the
/// identifier of the device that produced it, which breaks the remaining ties.
library;

final _deviceIdPattern = RegExp(r'^[0-9a-f-]{1,64}$');

/// A point in hybrid logical time. Two timestamps of different devices are
/// never equal: the device identifier decides when time and counter tie.
class Hlc implements Comparable<Hlc> {
  Hlc(this.millis, this.counter, this.deviceId) {
    if (millis < 0 || millis > maxMillis) throw ArgumentError.value(millis, 'millis');
    if (counter < 0 || counter > maxCounter) throw ArgumentError.value(counter, 'counter');
    if (!_deviceIdPattern.hasMatch(deviceId)) throw ArgumentError.value(deviceId, 'deviceId');
  }

  /// Parses the output of [encode].
  factory Hlc.parse(String encoded) {
    final parts = encoded.split(':');
    if (parts.length != 3 || parts[0].length != _millisDigits || parts[1].length != _counterDigits) {
      throw FormatException('Invalid HLC', encoded);
    }
    final millis = int.tryParse(parts[0]);
    final counter = int.tryParse(parts[1], radix: 16);
    if (millis == null || counter == null) throw FormatException('Invalid HLC', encoded);
    return Hlc(millis, counter, parts[2]);
  }

  static const _millisDigits = 15;
  static const _counterDigits = 4;

  /// Largest wall time representable with 15 digits (year 33658).
  static const maxMillis = 999999999999999;
  static const maxCounter = 0xffff;

  final int millis;
  final int counter;

  /// Lower-case hexadecimal digits and dashes only, so that the encoded form
  /// sorts the same way in Dart and in SQLite.
  final String deviceId;

  /// Fixed-width text whose lexicographic order is the order of [compareTo],
  /// e.g. `001763647200000:0000:3f2c1a9e-…`. The database sorts and compares
  /// timestamps in this form.
  String encode() =>
      '${millis.toString().padLeft(_millisDigits, '0')}:'
      '${counter.toRadixString(16).padLeft(_counterDigits, '0')}:$deviceId';

  @override
  int compareTo(Hlc other) {
    if (millis != other.millis) return millis.compareTo(other.millis);
    if (counter != other.counter) return counter.compareTo(other.counter);
    return deviceId.compareTo(other.deviceId);
  }

  bool operator >(Hlc other) => compareTo(other) > 0;

  @override
  bool operator ==(Object other) => other is Hlc && compareTo(other) == 0;

  @override
  int get hashCode => Object.hash(millis, counter, deviceId);

  @override
  String toString() => encode();
}

/// The clock of one device. It never goes backwards, even if the wall clock
/// does, and it moves past every timestamp it has observed.
class HlcClock {
  /// [last] is the greatest timestamp already used or observed, typically
  /// read back from the journal at start-up; [now] returns the wall time in
  /// milliseconds since the epoch.
  HlcClock(this.deviceId, {Hlc? last, int Function()? now})
    : _now = now ?? _wallClock,
      _millis = last?.millis ?? 0,
      _counter = last?.counter ?? 0 {
    Hlc(0, 0, deviceId); // validates the identifier
  }

  static int _wallClock() => DateTime.now().millisecondsSinceEpoch;

  final String deviceId;
  final int Function() _now;
  int _millis;
  int _counter;

  /// Returns a timestamp for a local event, greater than every timestamp
  /// returned or observed before.
  Hlc tick() {
    final wall = _now();
    if (wall > _millis) {
      _millis = wall;
      _counter = 0;
    } else {
      _increment();
    }
    return Hlc(_millis, _counter, deviceId);
  }

  /// Takes a timestamp received from another device into account, so that the
  /// next [tick] is greater than it.
  void observe(Hlc remote) {
    if (remote.millis > _millis || (remote.millis == _millis && remote.counter > _counter)) {
      _millis = remote.millis;
      _counter = remote.counter;
    }
  }

  /// Moves one step forward. When the counter is full (more than 65536
  /// events within one millisecond, or a wall clock lagging behind a
  /// timestamp seen from a device whose clock runs ahead), the clock moves to
  /// the next millisecond instead of failing: the logical time then runs
  /// slightly ahead of the wall clock until the wall clock catches up, and
  /// writes are never blocked.
  void _increment() {
    if (_counter == Hlc.maxCounter) {
      _millis++;
      _counter = 0;
    } else {
      _counter++;
    }
  }
}
