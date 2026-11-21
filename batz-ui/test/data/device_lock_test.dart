import 'dart:io';

import 'package:batz/data/device_lock.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:local_auth_platform_interface/local_auth_platform_interface.dart';

const _texts = UnlockTexts(title: 'Déverrouiller batz', reason: 'Empreinte ou code', cancel: 'Annuler');

/// The lock of a device whose plugin answers as [authenticate] says.
SystemDeviceLock _lock({bool supported = true, required Future<bool> Function(UnlockTexts) authenticate}) =>
    SystemDeviceLock(supported: () async => supported, authenticate: authenticate);

Future<UnlockOutcome> _outcomeOf(LocalAuthExceptionCode code) =>
    _lock(authenticate: (_) async => throw LocalAuthException(code: code)).unlock(_texts);

void main() {
  // The app asks the lock of the device on Android only. The app-facing
  // `local_auth` would add `local_auth_windows` to the Windows build, which
  // never calls it and whose compiler refuses it (docs/decisions.md, « Android lock »).
  test('only the Android half of the lock plugin is built: nothing of it on Windows nor on Ubuntu', () {
    final lock = File('pubspec.lock').readAsStringSync();
    expect(lock, contains('local_auth_android:'));
    expect(lock, contains('local_auth_platform_interface:'));
    for (final other in ['local_auth:', 'local_auth_windows:', 'local_auth_darwin:']) {
      expect(lock, isNot(contains('  $other')), reason: other);
    }
    for (final platform in ['windows', 'linux']) {
      for (final file in ['generated_plugins.cmake', 'generated_plugin_registrant.cc']) {
        expect(
          File('$platform/flutter/$file').readAsStringSync(),
          isNot(contains('local_auth')),
          reason: '$platform/$file',
        );
      }
    }
  });

  test('a recognised fingerprint or code unlocks; the dialog receives the texts', () async {
    UnlockTexts? shown;
    final lock = _lock(
      authenticate: (texts) async {
        shown = texts;
        return true;
      },
    );
    expect(await lock.unlock(_texts), isA<Unlocked>());
    expect(shown, same(_texts));
    expect(await lock.hasScreenLock(), isTrue);
  });

  test('a device without screen lock is not asked: there is nothing to unlock', () async {
    var asked = false;
    final lock = _lock(
      supported: false,
      authenticate: (_) async {
        asked = true;
        return true;
      },
    );
    expect(await lock.unlock(_texts), isA<NoScreenLock>());
    expect(asked, isFalse);
    expect(await lock.hasScreenLock(), isFalse);
    // The screen lock removed between the check and the dialog.
    expect(await _outcomeOf(LocalAuthExceptionCode.noCredentialsSet), isA<NoScreenLock>());
  });

  test('a dialog cancelled by the user, by the system or by a timeout leaves the app locked', () async {
    final refused = await _lock(authenticate: (_) async => false).unlock(_texts);
    expect(refused, isA<UnlockRefused>().having((r) => r.lockedOut, 'lockedOut', isFalse));
    for (final code in [
      LocalAuthExceptionCode.userCanceled,
      LocalAuthExceptionCode.systemCanceled,
      LocalAuthExceptionCode.timeout,
      LocalAuthExceptionCode.userRequestedFallback,
      LocalAuthExceptionCode.authInProgress,
    ]) {
      expect(
        await _outcomeOf(code),
        isA<UnlockRefused>().having((r) => r.lockedOut, 'lockedOut', isFalse),
        reason: code.name,
      );
    }
  });

  test('too many attempts leave the app locked, and say so', () async {
    for (final code in [LocalAuthExceptionCode.temporaryLockout, LocalAuthExceptionCode.biometricLockout]) {
      expect(
        await _outcomeOf(code),
        isA<UnlockRefused>().having((r) => r.lockedOut, 'lockedOut', isTrue),
        reason: code.name,
      );
    }
  });

  test('every other code of the plugin, and any other error, leaves the app locked with the error', () async {
    const handled = {
      LocalAuthExceptionCode.noCredentialsSet,
      LocalAuthExceptionCode.userCanceled,
      LocalAuthExceptionCode.systemCanceled,
      LocalAuthExceptionCode.timeout,
      LocalAuthExceptionCode.userRequestedFallback,
      LocalAuthExceptionCode.authInProgress,
      LocalAuthExceptionCode.temporaryLockout,
      LocalAuthExceptionCode.biometricLockout,
    };
    for (final code in LocalAuthExceptionCode.values.where((c) => !handled.contains(c))) {
      expect(
        await _outcomeOf(code),
        isA<UnlockFailed>().having((f) => '${f.error}', 'error', contains(code.name)),
        reason: code.name,
      );
    }
    // The plugin missing, or anything unexpected below it.
    final missing = await _lock(authenticate: (_) async => throw MissingPluginException('no implementation'))
        .unlock(_texts);
    expect(missing, isA<UnlockFailed>().having((f) => '${f.error}', 'error', contains('no implementation')));
    final broken = await SystemDeviceLock(
      supported: () async => throw StateError('keyguard'),
      authenticate: (_) async => true,
    ).unlock(_texts);
    expect(broken, isA<UnlockFailed>());
  });
}
