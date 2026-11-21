import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:batz/helpers/theme.dart';
import 'package:flutter_test/flutter_test.dart';

import '../tool/app_icon.dart';

/// The pixels of a PNG written by the tool (8 bits, colour with alpha, no
/// filter), with its side.
(int, Uint8List) _decodePng(List<int> bytes) {
  expect(bytes.sublist(0, 8), pngSignature);
  final data = ByteData.sublistView(Uint8List.fromList(bytes));
  late int size;
  final compressed = BytesBuilder();
  for (var at = 8; at < bytes.length;) {
    final length = data.getUint32(at);
    final type = String.fromCharCodes(bytes.sublist(at + 4, at + 8));
    final body = bytes.sublist(at + 8, at + 8 + length);
    if (type == 'IHDR') {
      size = data.getUint32(at + 8);
      expect(data.getUint32(at + 12), size, reason: 'square');
      expect(body.sublist(8), [8, 6, 0, 0, 0], reason: '8 bits, colour with alpha');
    }
    if (type == 'IDAT') compressed.add(body);
    at += 12 + length;
  }
  final rows = zlib.decode(compressed.takeBytes());
  final pixels = Uint8List(size * size * 4);
  for (var y = 0; y < size; y++) {
    final from = y * (size * 4 + 1);
    expect(rows[from], 0, reason: 'no filter');
    pixels.setRange(y * size * 4, (y + 1) * size * 4, rows, from + 1);
  }
  return (size, pixels);
}

/// The images of an icon file: side and raw bytes, in order.
List<(int, List<int>)> _icoImages(List<int> bytes) {
  final data = ByteData.sublistView(Uint8List.fromList(bytes));
  expect(data.getUint16(2, Endian.little), 1, reason: 'an icon');
  return [
    for (var i = 0; i < data.getUint16(4, Endian.little); i++)
      () {
        final entry = 6 + 16 * i;
        final side = data.getUint8(entry);
        expect(data.getUint8(entry + 1), side);
        expect(data.getUint16(entry + 6, Endian.little), 32, reason: 'bits per pixel');
        final length = data.getUint32(entry + 8, Endian.little);
        final offset = data.getUint32(entry + 12, Endian.little);
        return (side == 0 ? 256 : side, bytes.sublist(offset, offset + length));
      }(),
  ];
}

/// Two PNG files hold the same picture, pixel for pixel.
void _expectSamePixels(List<int> actual, List<int> expected, String reason) {
  final (actualSize, actualPixels) = _decodePng(actual);
  final (expectedSize, expectedPixels) = _decodePng(expected);
  expect(actualSize, expectedSize, reason: reason);
  expect(actualPixels, expectedPixels, reason: reason);
}

List<int> _pixel(Uint8List pixels, int size, double x, double y) {
  final at = ((y * size).floor() * size + (x * size).floor()) * 4;
  return pixels.sublist(at, at + 4);
}

void main() {
  final files = appIconFiles();

  test('the icon files of the repository are the ones the tool writes', () {
    expect(files.keys, [
      'android/app/src/main/res/mipmap-mdpi/ic_launcher.png',
      'android/app/src/main/res/mipmap-hdpi/ic_launcher.png',
      'android/app/src/main/res/mipmap-xhdpi/ic_launcher.png',
      'android/app/src/main/res/mipmap-xxhdpi/ic_launcher.png',
      'android/app/src/main/res/mipmap-xxxhdpi/ic_launcher.png',
      'android/app/src/main/res/mipmap-anydpi-v26/ic_launcher.xml',
      'android/app/src/main/res/drawable/ic_launcher_foreground.xml',
      'android/app/src/main/res/values/ic_launcher_background.xml',
      'windows/runner/resources/app_icon.ico',
      'linux/runner/batz.png',
    ]);
    for (final MapEntry(key: path, value: expected) in files.entries) {
      final file = File(path);
      expect(file.existsSync(), isTrue, reason: '$path is missing: run dart run tool/make_icons.dart');
      final actual = file.readAsBytesSync();
      if (path.endsWith('.xml')) {
        expect(utf8.decode(actual), utf8.decode(expected), reason: path);
        expect(actual.every((byte) => byte < 0x80), isTrue, reason: '$path: plain ASCII');
      } else if (path.endsWith('.png')) {
        // The pixels, not the bytes: the compression may differ from one
        // version of Dart to the next.
        _expectSamePixels(actual, expected, path);
      } else {
        final actualImages = _icoImages(actual), expectedImages = _icoImages(expected);
        expect(actualImages.map((i) => i.$1), icoSizes, reason: path);
        for (final (i, (side, image)) in expectedImages.indexed) {
          if (side == 256) {
            _expectSamePixels(actualImages[i].$2, image, '$path, $side');
          } else {
            expect(actualImages[i].$2, image, reason: '$path, $side');
          }
        }
      }
    }
  });

  test('a white « b » on the green of the app, in a square with round corners', () {
    expect(
      (iconGreen.red, iconGreen.green, iconGreen.blue),
      ((accentColor.r * 255).round(), (accentColor.g * 255).round(), (accentColor.b * 255).round()),
    );
    const size = 192;
    final pixels = iconPixels(size);
    const green = [0x2E, 0x7D, 0x5B, 255], white = [255, 255, 255, 255], nothing = [0, 0, 0, 0];
    // The visible square of the drawing goes from 18 to 90: a point of the
    // drawing is at (its coordinate − 18) ÷ 72 of the icon.
    double at(double unit) => (unit - 18) / 72;
    expect(_pixel(pixels, size, at(41), at(40)), white, reason: 'the stem');
    expect(_pixel(pixels, size, at(66), at(63)), white, reason: 'the right of the bowl');
    expect(_pixel(pixels, size, at(56), at(63)), green, reason: 'the hole of the bowl');
    expect(_pixel(pixels, size, at(60), at(40)), green, reason: 'above the bowl, right of the stem');
    expect(_pixel(pixels, size, at(30), at(54)), green, reason: 'left of the stem');
    expect(_pixel(pixels, size, 0.5, 0.02), green, reason: 'the top edge');
    expect(_pixel(pixels, size, 0.004, 0.004), nothing, reason: 'outside the round corner');
    expect(_pixel(pixels, size, 0.996, 0.996), nothing, reason: 'outside the round corner');
  });

  test('the letter stays inside the circle an Android launcher never cuts', () {
    expect(letterReach(), lessThan(33));
    final foreground = androidForeground();
    expect(foreground, contains('android:viewportWidth="108"'));
    expect(foreground, contains('M41,31 a4,4 0 0 1 4,4 v38 a4,4 0 0 1 -4,4 a4,4 0 0 1 -4,-4 v-38 a4,4 0 0 1 4,-4 z'));
    expect(
      foreground,
      contains('M42,63 a14,14 0 1 0 28,0 a14,14 0 1 0 -28,0 z M50,63 a6,6 0 1 0 12,0 a6,6 0 1 0 -12,0 z'),
    );
    expect(androidBackground(), contains('<color name="ic_launcher_background">#2E7D5B</color>'));
  });

  test('the Android app, the Windows app and the Ubuntu app use these files', () {
    final manifest = File('android/app/src/main/AndroidManifest.xml').readAsStringSync();
    expect(manifest, contains('android:icon="@mipmap/ic_launcher"'));
    expect(File('windows/runner/Runner.rc').readAsStringSync(), contains(r'"resources\\app_icon.ico"'));
    expect(File('linux/CMakeLists.txt').readAsStringSync(), contains('runner/batz.png'));
    expect(File('linux/runner/my_application.cc').readAsStringSync(), contains('"batz.png"'));
  });
}
