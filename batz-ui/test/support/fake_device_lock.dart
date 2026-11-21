import 'dart:async';

import 'package:batz/data/device_lock.dart';

/// A phone for the tests: its screen lock is there or not, and each
/// request to unlock waits for [answer].
class FakeDeviceLock implements DeviceLock {
  FakeDeviceLock({this.screenLock = true});

  /// Whether the phone has a screen lock.
  bool screenLock;

  /// The texts of each system dialog opened, in order.
  final List<UnlockTexts> asked = [];

  Completer<UnlockOutcome>? _dialog;

  /// Whether the system dialog is open.
  bool get dialogOpen => _dialog != null;

  @override
  Future<bool> hasScreenLock() async => screenLock;

  @override
  Future<UnlockOutcome> unlock(UnlockTexts texts) {
    if (!screenLock) return Future.value(const NoScreenLock());
    asked.add(texts);
    final dialog = _dialog = Completer<UnlockOutcome>();
    return dialog.future;
  }

  /// The holder of the phone answers the dialog.
  void answer(UnlockOutcome outcome) {
    final dialog = _dialog!;
    _dialog = null;
    dialog.complete(outcome);
  }
}

/// A clock the tests move.
class FakeClock {
  FakeClock(this.time);

  DateTime time;

  DateTime call() => time;

  void advance(Duration duration) => time = time.add(duration);
}
