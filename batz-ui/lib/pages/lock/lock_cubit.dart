import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../data/device_lock.dart';

/// How long the app may leave the screen without locking (decision H3 of
/// phase 7): strictly more than this locks it.
const lockDelay = Duration(seconds: 60);

/// Why the last attempt left the app locked.
enum LockFailure { cancelled, lockedOut, failed }

class AppLockState extends Equatable {
  const AppLockState({
    required this.locked,
    this.unlocking = false,
    this.failure,
    this.error,
    this.noScreenLock = false,
  });

  /// While true, no screen of the app is drawn (principle 5 of phase 7).
  final bool locked;

  /// The system dialog is open.
  final bool unlocking;

  /// Set while [locked], after an attempt that did not unlock.
  final LockFailure? failure;

  /// The text of an unexpected error ([LockFailure.failed]).
  final String? error;

  /// The device has no screen lock: the app is open, and the home screen
  /// says so (decision H4).
  final bool noScreenLock;

  @override
  List<Object?> get props => [locked, unlocking, failure, error, noScreenLock];
}

/// The door in front of the screens (decisions H3 and H4 of phase 7): the
/// app starts locked where the device has a lock to ask, and locks again
/// when it comes back after more than [lockDelay] away. Without a
/// [DeviceLock] (Windows, Ubuntu) there is no lock at all.
class LockCubit extends Cubit<AppLockState> {
  LockCubit(this._lock, {required this._now}) : super(AppLockState(locked: _lock != null));

  final DeviceLock? _lock;
  final DateTime Function() _now;

  /// When the app left the screen, while it was unlocked.
  DateTime? _leftAt;

  /// Whether this device puts the app behind a lock.
  bool get enabled => _lock != null;

  /// Opens the system dialog and applies its outcome. Does nothing when the
  /// app is not locked or a dialog is already open.
  Future<void> unlock(UnlockTexts texts) async {
    final lock = _lock;
    if (lock == null || !state.locked || state.unlocking) return;
    emit(const AppLockState(locked: true, unlocking: true));
    UnlockOutcome outcome;
    try {
      outcome = await lock.unlock(texts);
    } catch (e) {
      outcome = UnlockFailed(e);
    }
    if (isClosed) return;
    emit(switch (outcome) {
      Unlocked() => const AppLockState(locked: false),
      NoScreenLock() => const AppLockState(locked: false, noScreenLock: true),
      UnlockRefused(:final lockedOut) => AppLockState(
        locked: true,
        failure: lockedOut ? LockFailure.lockedOut : LockFailure.cancelled,
      ),
      UnlockFailed(:final error) => AppLockState(locked: true, failure: LockFailure.failed, error: '$error'),
    });
  }

  /// The app leaves the screen: the time is noted, once.
  void left() {
    if (!enabled || state.locked) return;
    _leftAt ??= _now();
  }

  /// The app comes back to the screen. Returns whether the system dialog is
  /// to be opened now: the app is locked and none is open.
  ///
  /// It locks when more than [lockDelay] passed since it left, or when the
  /// clock of the device went back meanwhile. The decision is taken before
  /// the first frame drawn after the return.
  Future<bool> returned() async {
    final lock = _lock;
    if (lock == null) return false;
    if (state.locked) return !state.unlocking;
    final leftAt = _leftAt;
    _leftAt = null;
    if (state.noScreenLock) {
      // Nothing could be asked so far; as soon as the device has a screen
      // lock, the app is behind it. An error is taken as a lock: the
      // dialog will say what is wrong.
      bool hasLock;
      try {
        hasLock = await lock.hasScreenLock();
      } catch (_) {
        hasLock = true;
      }
      if (isClosed || !hasLock) return false;
      emit(const AppLockState(locked: true));
      return true;
    }
    if (leftAt == null) return false;
    final away = _now().difference(leftAt);
    if (!away.isNegative && away <= lockDelay) return false;
    emit(const AppLockState(locked: true));
    return true;
  }
}
