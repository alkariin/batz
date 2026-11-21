import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// What the Android app declares for every build, the released one
/// included: the main manifest, its activity and its themes. The debug and
/// profile manifests only add to it.
void main() {
  final manifest = File('android/app/src/main/AndroidManifest.xml').readAsStringSync();

  // Debug and profile builds get INTERNET from their own manifests; a release
  // APK without it in the main manifest cannot open any connection.
  test('the release build may use the network', () {
    expect(manifest, contains('<uses-permission android:name="android.permission.INTERNET"/>'));
  });

  // What the lock asks of the Android app (docs/decisions.md, « Android lock »;
  // README of local_auth_android, « Setup »).
  group('the release build has what the lock needs', () {
    test('the permission to ask for a fingerprint, a face or the code of the device', () {
      expect(manifest, contains('<uses-permission android:name="android.permission.USE_BIOMETRIC"/>'));
    });

    test('an activity that is a FragmentActivity, the one the manifest starts', () {
      final activity = File('android/app/src/main/kotlin/dev/batz/app/MainActivity.kt').readAsStringSync();
      expect(activity, contains('import io.flutter.embedding.android.FlutterFragmentActivity'));
      expect(activity, contains('class MainActivity : FlutterFragmentActivity()'));
      expect(activity, isNot(contains('io.flutter.embedding.android.FlutterActivity')));
      expect(manifest, contains('android:name=".MainActivity"'));
    });

    test('themes with an AppCompat parent, by day and by night', () {
      for (final folder in ['values', 'values-night']) {
        final styles = File('android/app/src/main/res/$folder/styles.xml').readAsStringSync();
        final parents = RegExp(r'<style name="(\w+)" parent="([^"]+)"')
            .allMatches(styles)
            .map((m) => (m.group(1)!, m.group(2)!))
            .toList();
        expect(parents.map((p) => p.$1), ['LaunchTheme', 'NormalTheme'], reason: folder);
        for (final (name, parent) in parents) {
          expect(parent, startsWith('Theme.AppCompat.'), reason: '$name in $folder');
          expect(parent, endsWith('NoActionBar'), reason: '$name in $folder');
        }
      }
      expect(manifest, contains('android:theme="@style/LaunchTheme"'));
      expect(manifest, contains('android:resource="@style/NormalTheme"'));
    });
  });

  // Decision H5 of phase 7: no picture of the last screen in the list of
  // recent apps, from Android 13 on.
  test('the list of recent apps gets no picture of the last screen', () {
    final activity = File('android/app/src/main/kotlin/dev/batz/app/MainActivity.kt').readAsStringSync();
    expect(activity, contains('Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU'));
    expect(activity, contains('setRecentsScreenshotEnabled(false)'));
    // Screenshots stay possible: the window is not marked secure.
    expect(activity, isNot(contains('FLAG_SECURE')));
  });
}
