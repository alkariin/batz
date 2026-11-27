import 'dart:typed_data';

import 'package:crypto/crypto.dart';

import '../server/certificate.dart';
import '../server/server_client.dart';
import '../server/server_repository.dart';
import 'document_store.dart';

/// Why a document could not be added or found.
enum DocumentError {
  /// No server is paired: documents go through it.
  notPaired,

  /// The server could not be reached.
  unreachable,

  /// The server presents another certificate.
  serverChanged,

  /// The server keeps no documents (before 0.11.0).
  serverTooOld,

  /// Over [Documents.maxBytes].
  tooLarge,
  empty,

  /// Neither on this device nor on the server.
  missing,
}

class DocumentException implements Exception {
  const DocumentException(this.error);

  final DocumentError error;

  @override
  String toString() => 'DocumentException: ${error.name}';
}

/// The transport to the paired server for the documents; [ServerClient] in
/// the app.
typedef DocumentTransportFactory = DocumentTransport Function(Pairing pairing);

/// The files of the documents: sent to the server when they are added,
/// kept in the local copy of every device, downloaded after each
/// synchronisation that went to its end.
class Documents {
  Documents(this.store, this._server, {DocumentTransportFactory? transport}) : _transport = transport ?? _client;

  static DocumentTransport _client(Pairing p) => ServerClient(p.address, pin: p.fingerprint, deviceKey: p.deviceKey);

  /// What the server accepts.
  static const maxBytes = 25 << 20;

  final DocumentStore store;
  final ServerRepository _server;
  final DocumentTransportFactory _transport;

  /// Sends [file] to the server and keeps its copy here; returns its
  /// fingerprint. Refused with a [DocumentException]: no server, a server
  /// unreachable or too old, a file empty or too large.
  Future<String> add(Uint8List file) async {
    if (file.isEmpty) throw const DocumentException(DocumentError.empty);
    if (file.length > maxBytes) throw const DocumentException(DocumentError.tooLarge);
    final fingerprint = sha256.convert(file).toString();
    await _withServer((transport) async {
      if (!(await transport.health()).documents) throw const DocumentException(DocumentError.serverTooOld);
      final kept = await transport.uploadDocument(file);
      if (kept != fingerprint) throw const DocumentException(DocumentError.unreachable);
    });
    await store.save(fingerprint, file);
    return fingerprint;
  }

  /// The file of [fingerprint]: the copy of this device, or else the
  /// server's, then kept here. Refused with a [DocumentException] when
  /// neither has it or the server cannot be reached.
  Future<Uint8List> read(String fingerprint) async {
    if (await store.read(fingerprint) case final file?) return file;
    final file = await _withServer((transport) => transport.document(fingerprint));
    if (file == null || sha256.convert(file).toString() != fingerprint) {
      throw const DocumentException(DocumentError.missing);
    }
    await store.save(fingerprint, file);
    return file;
  }

  /// Downloads the files of [fingerprints] this device does not hold yet;
  /// returns how many. Stops at the first failure: the next
  /// synchronisation tries again.
  Future<int> fetchMissing(Set<String> fingerprints) async {
    final held = await store.fingerprints();
    final missing = fingerprints.difference(held).toList()..sort();
    if (missing.isEmpty) return 0;
    return _withServer((transport) async {
      var fetched = 0;
      for (final fingerprint in missing) {
        final file = await transport.document(fingerprint);
        if (file == null || sha256.convert(file).toString() != fingerprint) continue;
        await store.save(fingerprint, file);
        fetched++;
      }
      return fetched;
    });
  }

  Future<T> _withServer<T>(Future<T> Function(DocumentTransport transport) action) async {
    final pairing = await _server.pairing();
    if (pairing == null) throw const DocumentException(DocumentError.notPaired);
    final transport = _transport(pairing);
    try {
      return await action(transport);
    } on ServerUnreachableException {
      throw const DocumentException(DocumentError.unreachable);
    } on CertificateMismatchException {
      throw const DocumentException(DocumentError.serverChanged);
    } on ServerException catch (e) {
      throw DocumentException(switch (e.code) {
        'DOCUMENT_TOO_LARGE' => DocumentError.tooLarge,
        'DOCUMENT_EMPTY' => DocumentError.empty,
        'NOT_FOUND' => DocumentError.serverTooOld,
        _ => DocumentError.unreachable,
      });
    } finally {
      if (transport case final ServerClient client) client.close();
    }
  }
}
