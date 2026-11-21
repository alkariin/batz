// Writes every icon file of the app from the drawing of `app_icon.dart`.
// Run from `batz-ui/`:
//
//     dart run tool/make_icons.dart
//
// The files are committed; `test/app_icon_test.dart` fails when they are
// not the ones this tool writes.
// ignore_for_file: avoid_print
import 'dart:io';

import 'app_icon.dart';

void main() {
  if (!File('pubspec.yaml').existsSync()) {
    stderr.writeln('Run this from batz-ui/.');
    exit(2);
  }
  for (final MapEntry(key: path, value: bytes) in appIconFiles().entries) {
    File(path)
      ..parent.createSync(recursive: true)
      ..writeAsBytesSync(bytes);
    print('$path  ${bytes.length} bytes');
  }
}
