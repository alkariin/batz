/// Version of this app, kept equal to `version` in pubspec.yaml (a test
/// checks it). The server tells the oldest app version it accepts.
const appVersion = '0.6.0';

/// Compares two versions such as `0.1.0`, `v1.2` or `v0.1.0-3-gabc1234`
/// (anything after the numbers is ignored). Returns null if either cannot be
/// read, for instance a server built locally that reports `dev`.
int? compareVersions(String a, String b) {
  final x = _parse(a), y = _parse(b);
  if (x == null || y == null) return null;
  for (var i = 0; i < 3; i++) {
    if (x[i] != y[i]) return x[i].compareTo(y[i]);
  }
  return 0;
}

List<int>? _parse(String version) {
  final match = RegExp(r'^v?(\d+)(?:\.(\d+))?(?:\.(\d+))?').firstMatch(version.trim());
  if (match == null) return null;
  return [for (var i = 1; i <= 3; i++) int.parse(match.group(i) ?? '0')];
}
