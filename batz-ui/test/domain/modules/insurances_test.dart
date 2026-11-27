import 'package:batz/domain/calendar_date.dart';
import 'package:batz/domain/ledger/ledger_exception.dart';
import 'package:batz/domain/modules/insurances.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/ledger_harness.dart';

Matcher refusedWith(LedgerError error) => throwsA(isA<LedgerException>().having((e) => e.error, 'error', error));

final _fingerprint = 'ab' * 32;

void main() {
  late LedgerHarness h;
  setUp(() async => h = await LedgerHarness.open());
  tearDown(() => h.close());

  test('an insurance and its tranches: a new tranche closes the open one; the active one covers today', () async {
    await h.apply(
      (l) => l.createInsurance(
        'health',
        't24',
        name: ' Maladie ',
        first: InsuranceTrancheDraft(start: d(2024, 1, 1)),
      ),
    );
    var ledger = await h.apply(
      (l) => l.addInsuranceTranche('health', 't26', InsuranceTrancheDraft(start: d(2026, 1, 1), note: 'Franchise 300')),
    );
    final health = ledger.insurances.single;
    expect(health.name, 'Maladie');
    expect(health.tranches.map((t) => (t.id, t.start, t.end, t.note)), [
      ('t24', d(2024, 1, 1), d(2025, 12, 31), ''),
      ('t26', d(2026, 1, 1), null, 'Franchise 300'),
    ]);
    expect(health.activeAt(d(2026, 11, 27))?.id, 't26');
    expect(health.activeAt(d(2025, 6, 1))?.id, 't24');
    expect(health.activeAt(d(2023, 6, 1)), isNull);

    expect(
      () => ledger.addInsuranceTranche('health', 'x', InsuranceTrancheDraft(start: d(2025, 6, 1))),
      refusedWith(LedgerError.trancheOverlap),
    );
    expect(
      () => ledger.updateInsuranceTranche('t26', InsuranceTrancheDraft(start: d(2026, 1, 1), end: d(2025, 1, 1))),
      refusedWith(LedgerError.trancheEndBeforeStart),
    );
    expect(
      () => ledger.createInsurance(
        'x',
        'y',
        name: ' ',
        first: InsuranceTrancheDraft(start: d(2026, 1, 1)),
      ),
      refusedWith(LedgerError.nameRequired),
    );
    ledger = await h.apply((l) => l.renameInsurance('health', 'Assurance maladie'));
    expect(ledger.insurances.single.name, 'Assurance maladie');
  });

  test('documents and links of a tranche; deleting a tranche or an insurance deletes what it holds', () async {
    await h.apply(
      (l) => l.createInsurance(
        'car',
        't1',
        name: 'Voiture',
        first: InsuranceTrancheDraft(start: d(2026, 3, 1)),
      ),
    );
    await h.apply(
      (l) => l.addInsuranceDocument(
        't1',
        'policy',
        InsuranceDocumentDraft(
          kind: InsuranceDocumentKind.policy,
          name: 'Police 2026',
          fingerprint: _fingerprint,
          size: 120000,
          mediaType: 'application/pdf',
        ),
      ),
    );
    await h.apply(
      (l) => l.addInsuranceDocument(
        't1',
        'contract',
        InsuranceDocumentDraft(
          kind: InsuranceDocumentKind.contract,
          name: 'Contrat',
          fingerprint: 'cd' * 32,
          size: 5,
          mediaType: 'image/jpeg',
        ),
      ),
    );
    await h.apply((l) => l.addInsuranceLink('t1', 'portal', label: '', url: ' https://assurance.example/client '));
    var ledger = await h.ledger();
    final tranche = ledger.insurances.single.tranches.single;
    expect(tranche.documents.map((d) => d.id), ['contract', 'policy'], reason: 'contract, policy, other');
    expect(tranche.links.single.label, 'https://assurance.example/client', reason: 'the address as label');
    expect(ledger.insuranceFingerprints, {_fingerprint, 'cd' * 32});

    expect(
      () => ledger.addInsuranceLink('t1', 'x', label: 'Portail', url: 'assurance.example'),
      refusedWith(LedgerError.insuranceLinkInvalid),
    );
    expect(
      () => ledger.addInsuranceDocument(
        't1',
        'x',
        const InsuranceDocumentDraft(
          kind: InsuranceDocumentKind.other,
          name: 'Scan',
          fingerprint: 'not one',
          size: 3,
          mediaType: 'image/png',
        ),
      ),
      refusedWith(LedgerError.insuranceDocumentInvalid),
    );

    ledger = await h.apply(
      (l) => l.updateInsuranceDocument('policy', kind: InsuranceDocumentKind.other, name: 'Avenant'),
    );
    expect(ledger.insurances.single.tranches.single.documents.last.name, 'Avenant');
    ledger = await h.apply((l) => l.deleteInsuranceTranche('t1'));
    expect(ledger.insurances.single.tranches, isEmpty);
    final rows = await h.tables(['insurance_documents', 'insurance_links']);
    expect([for (final rows in rows.values) ...rows].every((row) => row['deleted'] == 1), isTrue);

    ledger = await h.apply((l) => l.deleteInsurance('car'));
    expect(ledger.insurances, isEmpty);
  });

  test('a link is an address a browser opens', () {
    expect(isInsuranceLink('https://assurance.example/a?b=c'), isTrue);
    expect(isInsuranceLink('http://192.168.1.1'), isTrue);
    for (final bad in ['assurance.example', 'ftp://x.example', 'https://', 'javascript:alert(1)', '']) {
      expect(isInsuranceLink(bad), isFalse, reason: bad);
    }
  });
}

CalendarDate d(int year, int month, int day) => CalendarDate(year, month, day);
