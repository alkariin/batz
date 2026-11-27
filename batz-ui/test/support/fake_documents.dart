import 'dart:typed_data';

import 'package:batz/data/server/server_client.dart';
import 'package:batz/data/sync/sync_protocol.dart';
import 'package:crypto/crypto.dart';

/// The document routes of a server, in memory.
class FakeDocumentServer implements DocumentTransport {
  final held = <String, Uint8List>{};
  var documents = true;
  var unreachable = false;
  var uploads = 0;
  var downloads = 0;

  void _reach() {
    if (unreachable) throw ServerUnreachableException('offline');
  }

  @override
  Future<Health> health() async {
    _reach();
    return Health(
      version: 'v0.11.0',
      minAppVersion: '0.11.0',
      syncProtocol: syncProtocol,
      importFormats: const ['postfinance', 'neon'],
      documents: documents,
    );
  }

  @override
  Future<String> uploadDocument(Uint8List file) async {
    _reach();
    uploads++;
    final fingerprint = sha256.convert(file).toString();
    held[fingerprint] = file;
    return fingerprint;
  }

  @override
  Future<Uint8List?> document(String fingerprint) async {
    _reach();
    downloads++;
    return held[fingerprint];
  }
}
