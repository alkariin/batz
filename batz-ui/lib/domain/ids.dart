import 'dart:math';

final _random = Random.secure();

/// A random UUID v4 in lower case, e.g. `3f2c1a9e-8b7d-4c6e-9f10-2a3b4c5d6e7f`.
///
/// Records are identified on the device that creates them (specification,
/// chapter 5), so creation works offline without temporary identifiers.
String newId() {
  final bytes = List<int>.generate(16, (_) => _random.nextInt(256));
  bytes[6] = (bytes[6] & 0x0f) | 0x40;
  bytes[8] = (bytes[8] & 0x3f) | 0x80;
  final hex = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-${hex.substring(12, 16)}-'
      '${hex.substring(16, 20)}-${hex.substring(20)}';
}
