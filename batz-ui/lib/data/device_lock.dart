import 'package:local_auth/local_auth.dart';
import 'package:local_auth_android/local_auth_android.dart' show AndroidAuthMessages;

/// What the system dialog says while it asks to unlock.
class UnlockTexts {
  const UnlockTexts({required this.title, required this.reason, required this.cancel});

  final String title;
  final String reason;
  final String cancel;
}

/// What an attempt to unlock gave.
sealed class UnlockOutcome {
  const UnlockOutcome();
}

/// The holder of the device proved who they are: fingerprint, face, or the
/// PIN, pattern or password of the device.
class Unlocked extends UnlockOutcome {
  const Unlocked();
}

/// The device has no screen lock: there is nothing to ask (decision H4 of
/// phase 7).
class NoScreenLock extends UnlockOutcome {
  const NoScreenLock();
}

/// Cancelled or refused: by the user, by the system (the app left the
/// screen), by a timeout, or after too many attempts ([lockedOut]).
class UnlockRefused extends UnlockOutcome {
  const UnlockRefused({this.lockedOut = false});

  final bool lockedOut;
}

/// Anything unexpected: the app stays locked and shows [error].
class UnlockFailed extends UnlockOutcome {
  const UnlockFailed(this.error);

  final Object error;
}

/// The lock of the device, asked through the system dialog (specification,
/// chapter 9: Android only; desktops rely on their operating system).
abstract interface class DeviceLock {
  /// Whether the device has a screen lock or an enrolled biometric.
  Future<bool> hasScreenLock();

  /// Asks the holder of the device to unlock it. Never throws.
  Future<UnlockOutcome> unlock(UnlockTexts texts);
}

/// [DeviceLock] through `local_auth` (docs/decisions.md, step 7.0): the
/// biometric prompt of Android, which falls back to the PIN, pattern or
/// password of the device.
class SystemDeviceLock implements DeviceLock {
  /// [supported] and [authenticate] replace the plugin in tests.
  SystemDeviceLock({Future<bool> Function()? supported, Future<bool> Function(UnlockTexts texts)? authenticate})
    : _supported = supported ?? _auth.isDeviceSupported,
      _authenticate = authenticate ?? _systemDialog;

  static final _auth = LocalAuthentication();

  final Future<bool> Function() _supported;
  final Future<bool> Function(UnlockTexts texts) _authenticate;

  static Future<bool> _systemDialog(UnlockTexts texts) => _auth.authenticate(
    localizedReason: texts.reason,
    authMessages: [AndroidAuthMessages(signInTitle: texts.title, signInHint: '', cancelButton: texts.cancel)],
    // Fingerprint, face or the code of the device (decision H3).
    biometricOnly: false,
    // Opening the app is what the user just asked for: no confirmation
    // button after a recognised face.
    sensitiveTransaction: false,
    // The gate of the app decides what happens when it leaves the screen.
    persistAcrossBackgrounding: false,
  );

  @override
  Future<bool> hasScreenLock() => _supported();

  @override
  Future<UnlockOutcome> unlock(UnlockTexts texts) async {
    try {
      if (!await _supported()) return const NoScreenLock();
      return await _authenticate(texts) ? const Unlocked() : const UnlockRefused();
    } on LocalAuthException catch (e) {
      return switch (e.code) {
        LocalAuthExceptionCode.noCredentialsSet => const NoScreenLock(),
        LocalAuthExceptionCode.userCanceled ||
        LocalAuthExceptionCode.systemCanceled ||
        LocalAuthExceptionCode.timeout ||
        LocalAuthExceptionCode.userRequestedFallback ||
        LocalAuthExceptionCode.authInProgress => const UnlockRefused(),
        LocalAuthExceptionCode.temporaryLockout ||
        LocalAuthExceptionCode.biometricLockout => const UnlockRefused(lockedOut: true),
        // Everything else, codes added later included: the app stays
        // locked and says why.
        _ => UnlockFailed(e),
      };
    } catch (e) {
      return UnlockFailed(e);
    }
  }
}
