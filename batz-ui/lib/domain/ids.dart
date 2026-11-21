import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';

final _random = Random.secure();

/// A random UUID v4 in lower case, e.g. `3f2c1a9e-8b7d-4c6e-9f10-2a3b4c5d6e7f`.
///
/// Records are identified on the device that creates them, so creation
/// works offline without temporary identifiers.
String newId() {
  final bytes = List<int>.generate(16, (_) => _random.nextInt(256));
  bytes[6] = (bytes[6] & 0x0f) | 0x40;
  bytes[8] = (bytes[8] & 0x3f) | 0x80;
  final hex = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-${hex.substring(12, 16)}-'
      '${hex.substring(16, 20)}-${hex.substring(20)}';
}

/// A name-based UUID (version 5 layout) from a SHA-256 digest of [name].
///
/// Records that two devices may create offline from the same source (a copy
/// of a tree, the lines of an imported statement) get identifiers computed
/// this way, so that both devices write the same records instead of two.
String derivedId(String name) {
  final bytes = sha256.convert(utf8.encode('batz/$name')).bytes.sublist(0, 16);
  bytes[6] = (bytes[6] & 0x0f) | 0x50;
  bytes[8] = (bytes[8] & 0x3f) | 0x80;
  final hex = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-${hex.substring(12, 16)}-'
      '${hex.substring(16, 20)}-${hex.substring(20)}';
}
