import 'dart:typed_data';

import 'package:batz/data/documents/document_store.dart';
import 'package:batz/data/documents/documents.dart';
import 'package:batz/domain/calendar_date.dart';
import 'package:batz/domain/modules/insurances.dart';
import 'package:flutter_test/flutter_test.dart';

import 'server_harness.dart';
import 'sync_device.dart';

void main() {
  test('a document added on one device reaches the server, then the other device after its exchange', () async {
    final server = await LocalServer.start();
    addTearDown(server.stop);
    final phone = await SimDevice.create('Téléphone'), laptop = await SimDevice.create('Ordinateur');
    addTearDown(phone.close);
    addTearDown(laptop.close);
    await phone.pair(server);
    await laptop.pair(server);
    final phoneDocuments = Documents(DocumentStore(phone.ledger.db), phone.server);
    final laptopDocuments = Documents(DocumentStore(laptop.ledger.db), laptop.server);

    final scan = Uint8List.fromList(List.generate(300000, (i) => i * 7 % 251));
    final fingerprint = await phoneDocuments.add(scan);
    await phone.ledger.apply(
      (l) => l.createInsurance(
        'car',
        't1',
        name: 'Voiture',
        first: InsuranceTrancheDraft(start: CalendarDate(2026, 1, 1)),
      ),
    );
    await phone.ledger.apply(
      (l) => l.addInsuranceDocument(
        't1',
        'scan',
        InsuranceDocumentDraft(
          kind: InsuranceDocumentKind.contract,
          name: 'Contrat',
          fingerprint: fingerprint,
          size: scan.length,
          mediaType: 'image/jpeg',
        ),
      ),
    );
    await phone.sync();
    await laptop.sync();

    final ledger = await laptop.ledger.ledger();
    expect(ledger.insuranceFingerprints, {fingerprint});
    expect(await laptopDocuments.fetchMissing(ledger.insuranceFingerprints), 1);
    expect(await laptopDocuments.store.read(fingerprint), scan);
    expect(await laptopDocuments.fetchMissing(ledger.insuranceFingerprints), 0);
  });
}
