import 'dart:convert';
import 'dart:typed_data';

import 'package:batz/data/documents/document_store.dart';
import 'package:batz/data/documents/documents.dart';
import 'package:batz/data/local/database.dart';
import 'package:batz/data/secret_store.dart';
import 'package:batz/data/server/server_repository.dart';
import 'package:crypto/crypto.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import '../pages/sync/sync_cubit_test.dart' show pairing;
import '../support/fake_documents.dart';

Matcher refusedWith(DocumentError error) => throwsA(isA<DocumentException>().having((e) => e.error, 'error', error));

void main() {
  late LocalDatabase db;
  late FakeDocumentServer server;
  late MemorySecretStore secrets;
  late Documents documents;

  setUp(() {
    db = LocalDatabase(NativeDatabase.memory());
    server = FakeDocumentServer();
    secrets = MemorySecretStore()..values[pairingSecretKey] = jsonEncode(pairing.toJson());
    documents = Documents(DocumentStore(db), ServerRepository(secrets), transport: (_) => server);
  });
  tearDown(() => db.close());

  final policy = Uint8List.fromList(utf8.encode('%PDF-1.7 police fictive'));
  final policyFingerprint = sha256.convert(policy).toString();

  test('a document added goes to the server and stays on the device, readable offline', () async {
    expect(await documents.add(policy), policyFingerprint);
    expect(server.held.keys, [policyFingerprint]);
    server.unreachable = true;
    expect(await documents.read(policyFingerprint), policy);
    expect(server.downloads, 0);
  });

  test('another device downloads what it misses after a synchronisation, once', () async {
    server.held[policyFingerprint] = policy;
    final other = Uint8List.fromList([1, 2, 3]);
    final otherFingerprint = sha256.convert(other).toString();
    server.held[otherFingerprint] = other;
    expect(await documents.fetchMissing({policyFingerprint, otherFingerprint, 'ef' * 32}), 2);
    expect(await documents.store.fingerprints(), {policyFingerprint, otherFingerprint});
    expect(await documents.fetchMissing({policyFingerprint, otherFingerprint}), 0);
    expect(server.downloads, 3, reason: 'the one the server lacks too');

    // A file missing here is fetched when opened.
    final late = Uint8List.fromList([9]);
    server.held[sha256.convert(late).toString()] = late;
    expect(await documents.read(sha256.convert(late).toString()), late);
  });

  test('refusals: no server, unreachable, too old, too large, empty, missing everywhere', () async {
    await expectLater(documents.add(Uint8List(0)), refusedWith(DocumentError.empty));
    await expectLater(documents.add(Uint8List(Documents.maxBytes + 1)), refusedWith(DocumentError.tooLarge));
    server.documents = false;
    await expectLater(documents.add(policy), refusedWith(DocumentError.serverTooOld));
    server
      ..documents = true
      ..unreachable = true;
    await expectLater(documents.add(policy), refusedWith(DocumentError.unreachable));
    expect(await documents.store.fingerprints(), isEmpty, reason: 'nothing kept when the server did not take it');
    server.unreachable = false;
    await expectLater(documents.read('ef' * 32), refusedWith(DocumentError.missing));
    secrets.values.remove(pairingSecretKey);
    await expectLater(documents.add(policy), refusedWith(DocumentError.notPaired));
  });
}
