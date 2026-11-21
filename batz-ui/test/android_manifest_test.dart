import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  // Debug and profile builds get INTERNET from their own manifests; a release
  // APK without it in the main manifest cannot open any connection.
  test('the release build may use the network', () {
    final manifest = File('android/app/src/main/AndroidManifest.xml').readAsStringSync();
    expect(manifest, contains('<uses-permission android:name="android.permission.INTERNET"/>'));
  });
}
