import 'dart:io';

/// Keeps the performance measurements of the app apart from the other test
/// files.
///
/// `flutter test` runs test files in concurrent processes; the end-to-end
/// files build batz-web and run its servers, the others render screens. On
/// the development machine (8 processors) a reload measured among them took
/// up to 2 s instead of 100 ms. Every test file holds this lock shared while
/// it runs (`test/flutter_test_config.dart`); a performance measurement holds
/// it exclusive, so it waits until it is the only test file running, and the
/// files that start meanwhile wait for it. Nothing is skipped: every test
/// runs, every measurement is checked against its limit.
///
/// The lock is an advisory lock on a file of the temporary directory, owned
/// by the process. Every change goes through one queue.
///
/// Once the lock is exclusive, the processes of the files that just released
/// it may still be ending, and the runner may still be starting the next
/// ones: on Linux, the measurement also waits until the processors are
/// quiet.
abstract final class MachineLock {
  static final _path = '${Directory.systemTemp.path}/batz-test-machine.lock';
  static RandomAccessFile? _shared;
  static var _holders = 0;
  static Future<void> _queue = Future.value();

  static Future<T> _serial<T>(Future<T> Function() operation) {
    final result = _queue.then((_) => operation());
    _queue = result.then((_) {}, onError: (Object _) {});
    return result;
  }

  /// Taken by a test file when it starts.
  static Future<void> acquireShared() => _serial(() async {
    if (_holders++ > 0) return;
    final file = await File(_path).open(mode: FileMode.append);
    await file.lock(FileLock.blockingShared);
    _shared = file;
  });

  /// Released by a test file when it ends.
  static Future<void> releaseShared() => _serial(() async {
    if (_holders == 0 || --_holders > 0) return;
    await _drop();
  });

  static Future<void> _drop() async {
    final file = _shared;
    _shared = null;
    await file?.unlock();
    await file?.close();
  }

  /// Runs [body] while no other test file runs. The shared hold of this
  /// file is set aside meanwhile, then taken back.
  static Future<T> exclusive<T>(Future<T> Function() body) => _serial(() async {
    final held = _holders;
    if (held > 0) {
      _holders = 0;
      await _drop();
    }
    final file = await File(_path).open(mode: FileMode.append);
    try {
      await file.lock(FileLock.blockingExclusive);
      try {
        await _quiet();
        return await body();
      } finally {
        await file.unlock();
      }
    } finally {
      await file.close();
      if (held > 0) {
        final shared = await File(_path).open(mode: FileMode.append);
        await shared.lock(FileLock.blockingShared);
        _shared = shared;
        _holders = held;
      }
    }
  });

  /// Waits until two samples in a row, 200 ms each, show the processors busy
  /// less than 10 % of the time, and at most 20 seconds. Only on Linux,
  /// where `/proc/stat` gives the time spent by all processors.
  static Future<void> _quiet() async {
    final stat = File('/proc/stat');
    if (!Platform.isLinux || !stat.existsSync()) return;
    (int, int) sample() {
      final fields = stat.readAsLinesSync().first.split(RegExp(r'\s+')).skip(1).take(8).map(int.parse).toList();
      final idle = fields[3] + fields[4];
      return (fields.fold(0, (a, b) => a + b), idle);
    }

    final watch = Stopwatch()..start();
    var quiet = 0;
    var (total, idle) = sample();
    while (quiet < 2 && watch.elapsed < const Duration(seconds: 20)) {
      await Future<void>.delayed(const Duration(milliseconds: 200));
      final (nextTotal, nextIdle) = sample();
      final busy = nextTotal == total ? 0.0 : 1 - (nextIdle - idle) / (nextTotal - total);
      quiet = busy < 0.10 ? quiet + 1 : 0;
      (total, idle) = (nextTotal, nextIdle);
    }
    // ignore: avoid_print
    print('machine quiet after ${watch.elapsedMilliseconds} ms');
  }
}
