import 'package:batz/data/device_lock.dart';
import 'package:batz/pages/lock/lock_cubit.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fake_device_lock.dart';

const _texts = UnlockTexts(title: 'Déverrouiller batz', reason: 'Empreinte ou code', cancel: 'Annuler');

DateTime _at(int hour, int minute, [int second = 0]) => DateTime(2026, 11, 21, hour, minute, second);

/// Lets the answer of a dialog reach the cubit.
Future<void> _settle() => Future<void>.delayed(Duration.zero);

void main() {
  late FakeDeviceLock phone;
  late FakeClock clock;
  late LockCubit lock;

  setUp(() {
    phone = FakeDeviceLock();
    clock = FakeClock(_at(8, 0));
    lock = LockCubit(phone, now: clock.call);
    addTearDown(lock.close);
  });

  /// The app opened and unlocked, as at 08:00:00 in the plan's example.
  Future<void> open() async {
    final unlocking = lock.unlock(_texts);
    phone.answer(const Unlocked());
    await unlocking;
    expect(lock.state.locked, isFalse);
  }

  /// The app leaves the screen at [from] and comes back at [to]; returns
  /// whether the dialog is to be opened.
  Future<bool> away(DateTime from, DateTime to) async {
    clock.time = from;
    lock.left();
    clock.time = to;
    return lock.returned();
  }

  test('the example of the plan, line by line', () async {
    // 08:00:00, the app opens: locked, then the home screen after the
    // fingerprint.
    expect(lock.state, const AppLockState(locked: true));
    final unlocking = lock.unlock(_texts);
    expect(lock.state, const AppLockState(locked: true, unlocking: true));
    expect(phone.asked.single, same(_texts));
    phone.answer(const Unlocked());
    await unlocking;
    expect(lock.state, const AppLockState(locked: false));

    // 08:05:00 → 08:05:59, 59 seconds away: no lock.
    expect(await away(_at(8, 5), _at(8, 5, 59)), isFalse);
    expect(lock.state.locked, isFalse);

    // 08:10:00 → 08:11:00, 60 seconds: no lock.
    expect(await away(_at(8, 10), _at(8, 11)), isFalse);
    expect(lock.state.locked, isFalse);

    // 08:20:00 → 08:21:01, 61 seconds: locked, and the dialog is asked for.
    expect(await away(_at(8, 20), _at(8, 21, 1)), isTrue);
    expect(lock.state, const AppLockState(locked: true));
    await open();

    // 08:30:00 → 08:29:00, the clock of the phone went back: locked.
    expect(await away(_at(8, 30), _at(8, 29)), isTrue);
    expect(lock.state, const AppLockState(locked: true));
    expect(phone.asked, hasLength(2), reason: 'the cubit opens no dialog by itself');
  });

  test('the time is noted when the app leaves, once: a second departure does not move it', () async {
    await open();
    clock.time = _at(9, 0);
    lock.left();
    clock.time = _at(9, 0, 50);
    lock.left();
    clock.time = _at(9, 1, 1);
    expect(await lock.returned(), isTrue, reason: '61 seconds since the first departure');

    // Back and unlocked, the time noted is forgotten: coming back again
    // without leaving locks nothing.
    await open();
    clock.time = _at(12, 0);
    expect(await lock.returned(), isFalse);
    expect(lock.state.locked, isFalse);
  });

  test('a dialog cancelled or refused leaves the app locked; unlocking is asked again', () async {
    var unlocking = lock.unlock(_texts);
    phone.answer(const UnlockRefused());
    await unlocking;
    expect(lock.state, const AppLockState(locked: true, failure: LockFailure.cancelled));

    unlocking = lock.unlock(_texts);
    expect(lock.state, const AppLockState(locked: true, unlocking: true), reason: 'the message is gone');
    phone.answer(const UnlockRefused(lockedOut: true));
    await unlocking;
    expect(lock.state, const AppLockState(locked: true, failure: LockFailure.lockedOut));

    unlocking = lock.unlock(_texts);
    phone.answer(const Unlocked());
    await unlocking;
    expect(lock.state, const AppLockState(locked: false));
    expect(phone.asked, hasLength(3));
  });

  test('an unexpected error leaves the app locked and is shown', () async {
    final unlocking = lock.unlock(_texts);
    phone.answer(UnlockFailed(StateError('no activity')));
    await unlocking;
    expect(lock.state.locked, isTrue);
    expect(lock.state.failure, LockFailure.failed);
    expect(lock.state.error, contains('no activity'));
  });

  test('one dialog at a time; none when the app is unlocked', () async {
    final first = lock.unlock(_texts);
    await lock.unlock(_texts);
    expect(phone.asked, hasLength(1));
    phone.answer(const Unlocked());
    await first;
    await lock.unlock(_texts);
    expect(phone.asked, hasLength(1));
    expect(phone.dialogOpen, isFalse);
  });

  test('back to a locked app: the dialog is asked for, unless one is open', () async {
    // Locked, no dialog (it was cancelled): coming back asks again.
    var unlocking = lock.unlock(_texts);
    phone.answer(const UnlockRefused());
    await unlocking;
    lock.left();
    expect(await lock.returned(), isTrue);
    expect(lock.state.locked, isTrue);

    // The dialog is open (the code of the device is typed on another
    // screen): coming back opens no second one.
    unlocking = lock.unlock(_texts);
    lock.left();
    clock.advance(const Duration(minutes: 5));
    expect(await lock.returned(), isFalse);
    phone.answer(const Unlocked());
    await unlocking;
    expect(lock.state.locked, isFalse);

    // The minutes spent on the dialog were not noted as an absence.
    expect(await lock.returned(), isFalse);
    expect(lock.state.locked, isFalse);
  });

  test('a phone without screen lock opens the app with a warning, until it has one', () async {
    phone.screenLock = false;
    await lock.unlock(_texts);
    expect(lock.state, const AppLockState(locked: false, noScreenLock: true));
    expect(phone.asked, isEmpty, reason: 'no dialog: there is nothing to ask');

    // Hours away, still no screen lock: the app stays open, with its warning.
    expect(await away(_at(9, 0), _at(15, 0)), isFalse);
    expect(lock.state, const AppLockState(locked: false, noScreenLock: true));

    // A screen lock is set: the app is behind it at the next return, even
    // a short one.
    phone.screenLock = true;
    expect(await away(_at(15, 0), _at(15, 0, 10)), isTrue);
    expect(lock.state, const AppLockState(locked: true));
    await open();
    expect(lock.state.noScreenLock, isFalse);

    // The screen lock is removed while the app is away: it locks, then
    // opens with the warning.
    phone.screenLock = false;
    expect(await away(_at(16, 0), _at(16, 5)), isTrue);
    await lock.unlock(_texts);
    expect(lock.state, const AppLockState(locked: false, noScreenLock: true));
  });

  test('a computer has no lock: never locked, whatever the time away', () async {
    final desktop = LockCubit(null, now: clock.call);
    addTearDown(desktop.close);
    expect(desktop.enabled, isFalse);
    expect(desktop.state, const AppLockState(locked: false));
    desktop.left();
    clock.advance(const Duration(days: 3));
    expect(await desktop.returned(), isFalse);
    await desktop.unlock(_texts);
    await _settle();
    expect(desktop.state, const AppLockState(locked: false));
  });
}
