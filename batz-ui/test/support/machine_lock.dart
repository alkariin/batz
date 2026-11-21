import 'dart:io';

/// Keeps the performance measurements of the app apart from the other test
/// files (step 4.7 of phase 4).
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
}
