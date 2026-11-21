/// The icon of the app (decision H8 of phase 7): a white « b » on the green
/// of the app. One drawing, described below in the units of an Android
/// adaptive icon (a square of 108), from which every icon file is made:
/// `dart run tool/make_icons.dart` writes them, and
/// `test/app_icon_test.dart` checks that the files of the repository are
/// the ones this code gives.
///
/// Pure Dart, no package: the pixels are computed here, the same on every
/// machine.
library;

import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

/// The side of the drawing, in its own units.
const iconGrid = 108.0;

/// The part of the drawing an Android launcher always shows, and the part
/// the other icons show: the square of 72 in the middle.
const _visibleFrom = 18.0;
const _visibleSide = 72.0;

/// The green of the app (`accentColor` in `lib/helpers/theme.dart`), as
/// red, green, blue.
const iconGreen = (red: 0x2E, green: 0x7D, blue: 0x5B);

/// The stem of the « b »: a bar with round ends.
const _stem = (left: 37.0, top: 31.0, right: 45.0, bottom: 77.0, radius: 4.0);

/// The bowl of the « b »: a ring, as thick as the stem, resting on its foot.
const _bowl = (x: 56.0, y: 63.0, outer: 14.0, inner: 6.0);

/// The corners of the green square of the icons that are not adaptive, in
/// units of the drawing.
const _corner = 14.0;

bool _inRoundedRect(double x, double y, double left, double top, double right, double bottom, double radius) {
  if (x < left || x > right || y < top || y > bottom) return false;
  final cx = x < left + radius ? left + radius : (x > right - radius ? right - radius : x);
  final cy = y < top + radius ? top + radius : (y > bottom - radius ? bottom - radius : y);
  final dx = x - cx, dy = y - cy;
  return dx * dx + dy * dy <= radius * radius;
}

/// Whether the point of the drawing is in the letter.
bool inLetter(double x, double y) {
  if (_inRoundedRect(x, y, _stem.left, _stem.top, _stem.right, _stem.bottom, _stem.radius)) return true;
  final dx = x - _bowl.x, dy = y - _bowl.y;
  final d2 = dx * dx + dy * dy;
  return d2 <= _bowl.outer * _bowl.outer && d2 >= _bowl.inner * _bowl.inner;
}

/// Whether the point of the drawing is on the green square with round
/// corners of the icons that are not adaptive.
bool _inSquare(double x, double y) =>
    _inRoundedRect(x, y, _visibleFrom, _visibleFrom, _visibleFrom + _visibleSide, _visibleFrom + _visibleSide, _corner);

/// The icon as [size] × [size] pixels, four bytes each (red, green, blue,
/// alpha, not premultiplied): the visible square of the drawing, the letter
/// in white on the green square, transparent outside its round corners.
/// Each pixel is the average of 8 × 8 points.
Uint8List iconPixels(int size) {
  const samples = 8;
  final pixels = Uint8List(size * size * 4);
  final step = _visibleSide / size;
  for (var py = 0; py < size; py++) {
    for (var px = 0; px < size; px++) {
      var square = 0, letter = 0;
      for (var sy = 0; sy < samples; sy++) {
        final y = _visibleFrom + (py + (sy + 0.5) / samples) * step;
        for (var sx = 0; sx < samples; sx++) {
          final x = _visibleFrom + (px + (sx + 0.5) / samples) * step;
          if (!_inSquare(x, y)) continue;
          square++;
          if (inLetter(x, y)) letter++;
        }
      }
      final at = (py * size + px) * 4;
      if (square == 0) continue;
      int mix(int green) => ((green * (square - letter) + 255 * letter) / square).round();
      pixels[at] = mix(iconGreen.red);
      pixels[at + 1] = mix(iconGreen.green);
      pixels[at + 2] = mix(iconGreen.blue);
      pixels[at + 3] = (255 * square / (samples * samples)).round();
    }
  }
  return pixels;
}

// ------------------------------------------------------------------- PNG

final List<int> _crcTable = List<int>.generate(256, (n) {
  var c = n;
  for (var k = 0; k < 8; k++) {
    c = c.isOdd ? 0xEDB88320 ^ (c >> 1) : c >> 1;
  }
  return c;
});

int _crc32(List<int> bytes) {
  var c = 0xFFFFFFFF;
  for (final b in bytes) {
    c = _crcTable[(c ^ b) & 0xFF] ^ (c >> 8);
  }
  return c ^ 0xFFFFFFFF;
}

Uint8List _u32(int value) => Uint8List(4)..buffer.asByteData().setUint32(0, value);

List<int> _chunk(String type, List<int> data) {
  final body = [...type.codeUnits, ...data];
  return [..._u32(data.length), ...body, ..._u32(_crc32(body))];
}

const pngSignature = [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A];

/// [pixels] (red, green, blue, alpha) as a PNG file of [size] × [size].
Uint8List encodePng(int size, Uint8List pixels) {
  final rows = BytesBuilder();
  for (var y = 0; y < size; y++) {
    rows.addByte(0); // no filter
    rows.add(Uint8List.sublistView(pixels, y * size * 4, (y + 1) * size * 4));
  }
  return Uint8List.fromList([
    ...pngSignature,
    // 8 bits per channel, colour with alpha.
    ..._chunk('IHDR', [..._u32(size), ..._u32(size), 8, 6, 0, 0, 0]),
    ..._chunk('IDAT', zlib.encode(rows.takeBytes())),
    ..._chunk('IEND', const []),
  ]);
}

// ------------------------------------------------------------------- ICO

/// The sizes of the Windows icon: the largest as a PNG, the others as
/// bitmaps, as Windows expects them.
const icoSizes = [256, 48, 32, 24, 16];

/// A bitmap of an icon file: 32 bits per pixel, bottom row first, blue
/// first, followed by its mask of one bit per pixel (all visible: the
/// alpha channel decides).
Uint8List _icoBitmap(int size, Uint8List pixels) {
  final maskRow = ((size + 31) ~/ 32) * 4;
  final out = ByteData(40 + size * size * 4 + maskRow * size);
  out
    ..setUint32(0, 40, Endian.little) // header size
    ..setInt32(4, size, Endian.little)
    ..setInt32(8, size * 2, Endian.little) // image and mask
    ..setUint16(12, 1, Endian.little) // planes
    ..setUint16(14, 32, Endian.little) // bits per pixel
    ..setUint32(20, size * size * 4 + maskRow * size, Endian.little);
  var at = 40;
  for (var y = size - 1; y >= 0; y--) {
    for (var x = 0; x < size; x++) {
      final from = (y * size + x) * 4;
      out
        ..setUint8(at, pixels[from + 2])
        ..setUint8(at + 1, pixels[from + 1])
        ..setUint8(at + 2, pixels[from])
        ..setUint8(at + 3, pixels[from + 3]);
      at += 4;
    }
  }
  return out.buffer.asUint8List();
}

/// The Windows icon file: one image per size of [icoSizes].
Uint8List encodeIco() {
  final images = [
    for (final size in icoSizes) size == 256 ? encodePng(size, iconPixels(size)) : _icoBitmap(size, iconPixels(size)),
  ];
  final header = ByteData(6 + 16 * images.length)
    ..setUint16(2, 1, Endian.little) // an icon
    ..setUint16(4, images.length, Endian.little);
  var offset = header.lengthInBytes;
  for (final (i, image) in images.indexed) {
    final entry = 6 + 16 * i;
    header
      ..setUint8(entry, icoSizes[i] == 256 ? 0 : icoSizes[i])
      ..setUint8(entry + 1, icoSizes[i] == 256 ? 0 : icoSizes[i])
      ..setUint16(entry + 4, 1, Endian.little) // planes
      ..setUint16(entry + 6, 32, Endian.little) // bits per pixel
      ..setUint32(entry + 8, image.length, Endian.little)
      ..setUint32(entry + 12, offset, Endian.little);
    offset += image.length;
  }
  return Uint8List.fromList([...header.buffer.asUint8List(), for (final image in images) ...image]);
}

// --------------------------------------------------------------- Android

String _n(double value) => value == value.roundToDouble() ? value.toInt().toString() : value.toString();

/// The letter as an Android vector drawable, on the whole drawing: the
/// foreground of the adaptive icon, and its single-colour layer.
String androidForeground() {
  final s = _stem, b = _bowl;
  final r = _n(s.radius);
  final straight = _n(s.bottom - s.top - 2 * s.radius);
  // The flat part of each end: none when the ends are half circles.
  final flat = s.right - s.left - 2 * s.radius;
  final (across, back) = flat > 0 ? ('h${_n(flat)} ', 'h-${_n(flat)} ') : ('', '');
  final stem =
      'M${_n(s.left + s.radius)},${_n(s.top)} '
      '${across}a$r,$r 0 0 1 $r,$r v$straight a$r,$r 0 0 1 -$r,$r '
      '${back}a$r,$r 0 0 1 -$r,-$r v-$straight a$r,$r 0 0 1 $r,-$r z';
  String circle(double radius) {
    final d = _n(radius), w = _n(2 * radius);
    return 'M${_n(b.x - radius)},${_n(b.y)} a$d,$d 0 1 0 $w,0 a$d,$d 0 1 0 -$w,0 z';
  }

  return '''<?xml version="1.0" encoding="utf-8"?>
<!-- Written by tool/make_icons.dart: the letter of the app icon. -->
<vector xmlns:android="http://schemas.android.com/apk/res/android"
    android:width="108dp"
    android:height="108dp"
    android:viewportWidth="${_n(iconGrid)}"
    android:viewportHeight="${_n(iconGrid)}">
    <path
        android:fillColor="#FFFFFFFF"
        android:pathData="$stem" />
    <path
        android:fillColor="#FFFFFFFF"
        android:fillType="evenOdd"
        android:pathData="${circle(b.outer)} ${circle(b.inner)}" />
</vector>
''';
}

String _hex(int value) => value.toRadixString(16).padLeft(2, '0').toUpperCase();

/// The green behind the letter, as an Android colour.
String androidBackground() =>
    '''<?xml version="1.0" encoding="utf-8"?>
<!-- Written by tool/make_icons.dart: the green of the app icon. -->
<resources>
    <color name="ic_launcher_background">#${_hex(iconGreen.red)}${_hex(iconGreen.green)}${_hex(iconGreen.blue)}</color>
</resources>
''';

/// The adaptive icon of Android 8 and later: the letter on the green, and
/// the letter alone for the icons Android 13 colours itself.
const androidAdaptiveIcon = '''<?xml version="1.0" encoding="utf-8"?>
<!-- Written by tool/make_icons.dart. -->
<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android">
    <background android:drawable="@color/ic_launcher_background" />
    <foreground android:drawable="@drawable/ic_launcher_foreground" />
    <monochrome android:drawable="@drawable/ic_launcher_foreground" />
</adaptive-icon>
''';

/// The sizes of the icon of Android 7, by screen density.
const androidLegacySizes = {'mdpi': 48, 'hdpi': 72, 'xhdpi': 96, 'xxhdpi': 144, 'xxxhdpi': 192};

/// The size of the icon of the Ubuntu app, beside its executable.
const linuxIconSize = 256;

// ----------------------------------------------------------------- files

/// Every icon file of the app, by its path from `batz-ui/`.
Map<String, List<int>> appIconFiles() {
  const res = 'android/app/src/main/res';
  return {
    for (final MapEntry(key: density, value: size) in androidLegacySizes.entries)
      '$res/mipmap-$density/ic_launcher.png': encodePng(size, iconPixels(size)),
    '$res/mipmap-anydpi-v26/ic_launcher.xml': utf8.encode(androidAdaptiveIcon),
    '$res/drawable/ic_launcher_foreground.xml': utf8.encode(androidForeground()),
    '$res/values/ic_launcher_background.xml': utf8.encode(androidBackground()),
    'windows/runner/resources/app_icon.ico': encodeIco(),
    'linux/runner/batz.png': encodePng(linuxIconSize, iconPixels(linuxIconSize)),
  };
}

/// The largest distance from the middle of the drawing to a point of the
/// letter: it must stay inside the circle of 33 an Android launcher never
/// cuts.
double letterReach() {
  var reach = 0.0;
  for (var y = 0.0; y <= iconGrid; y += 0.25) {
    for (var x = 0.0; x <= iconGrid; x += 0.25) {
      if (inLetter(x, y)) reach = math.max(reach, math.sqrt(math.pow(x - 54, 2) + math.pow(y - 54, 2)));
    }
  }
  return reach;
}
