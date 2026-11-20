import 'package:batz/data/server/certificate.dart';
import 'package:batz/data/server/server_client.dart';
import 'package:batz/version.dart';
import 'package:flutter_test/flutter_test.dart';

import 'dart:io';

void main() {
  test('server addresses', () {
    expect(parseServerAddress('192.168.1.95'), Uri.parse('https://192.168.1.95:8443'));
    expect(parseServerAddress(' 192.168.1.95:9443 '), Uri.parse('https://192.168.1.95:9443'));
    expect(parseServerAddress('https://nas.local/'), Uri.parse('https://nas.local:8443'));
    expect(parseServerAddress('[::1]:8443'), Uri.parse('https://[::1]:8443'));
    for (final bad in ['', 'http://192.168.1.95', 'not an address/', '192.168.1.95/api', 'a@b:1', 'host?x=1']) {
      expect(parseServerAddress(bad), isNull, reason: bad);
    }
  });

  test('fingerprints use the server format', () {
    expect(
      fingerprintOf([]),
      'E3:B0:C4:42:98:FC:1C:14:9A:FB:F4:C8:99:6F:B9:24:27:AE:41:E4:64:9B:93:4C:A4:95:99:1B:78:52:B8:55',
    );
  });

  test('version comparison', () {
    expect(compareVersions('0.1.0', '0.1.0'), 0);
    expect(compareVersions('0.1.0', 'v0.2'), -1);
    expect(compareVersions('1.0.0', '0.9.9'), 1);
    expect(compareVersions('0.1.0', 'v0.1.0-3-gabc1234'), 0);
    expect(compareVersions('0.1.0', 'dev'), isNull);
  });

  test('appVersion matches pubspec.yaml', () {
    final version = RegExp(r'^version: (\S+)\+', multiLine: true).firstMatch(File('pubspec.yaml').readAsStringSync())!;
    expect(appVersion, version.group(1));
  });
}
