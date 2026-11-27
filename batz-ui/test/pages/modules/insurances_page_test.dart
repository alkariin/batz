import 'dart:convert';
import 'dart:typed_data';

import 'package:batz/app.dart';
import 'package:batz/data/files.dart';
import 'package:batz/data/secret_store.dart';
import 'package:batz/data/server/server_repository.dart';
import 'package:batz/domain/calendar_date.dart';
import 'package:batz/domain/modules/insurances.dart';
import 'package:batz/services.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fake_documents.dart';
import '../../support/services.dart';
import '../accounts/accounts_page_test.dart' show settle, tapInList;
import '../sync/sync_cubit_test.dart' show pairing;

/// The system dialogs: a file to pick, and what was opened or saved.
class _Files implements FileAccess {
  final picks = <PickedFile>[];
  final opened = <String, Uint8List>{};
  final links = <String>[];

  @override
  Future<PickedFile?> pickDocument() async => picks.isEmpty ? null : picks.removeAt(0);

  @override
  Future<bool> openDocument(String fileName, Uint8List bytes) async {
    opened[fileName] = bytes;
    return true;
  }

  @override
  Future<bool> openLink(String url) async {
    links.add(url);
    return true;
  }

  @override
  Future<bool> saveDocument(String fileName, Uint8List bytes) async => true;

  @override
  Future<PickedFile?> pickStatement() async => null;

  @override
  Future<bool> saveStatement(String fileName, Uint8List bytes) async => false;

  @override
  Future<bool> saveZip(String fileName, Uint8List bytes) async => false;
}

void main() {
  testWidgets('an insurance: its tranche in force with a document sent to the server and a link; an earlier '
      'tranche shown on demand', (tester) async {
    tester.view.physicalSize = const Size(500, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final server = FakeDocumentServer();
    final files = _Files();
    final secrets = MemorySecretStore()..values[pairingSecretKey] = jsonEncode(pairing.toJson());
    final AppServices services = (await tester.runAsync(
      () => testServices(
        secrets: secrets,
        documentTransport: (_) => server,
        files: files,
        today: () => CalendarDate(2026, 11, 27),
      ),
    ))!;
    addTearDown(() => tester.runAsync(services.database.close));
    await tester.pumpWidget(BatzApp(services: services));
    await settle(tester);

    await tester.tap(find.descendant(of: find.byType(NavigationBar), matching: find.text('Plus')));
    await settle(tester);
    await tapInList(tester, find.byKey(const Key('moreInsurances')));
    await settle(tester);
    expect(find.text('Aucune assurance. Ajoutez-en une avec le bouton +.'), findsOneWidget);

    // An insurance since 1.1.2025, then a new tranche from 1.1.2026.
    await tester.tap(find.byKey(const Key('insuranceNew')));
    await settle(tester);
    await tester.enterText(find.byKey(const Key('insuranceName')), 'Maladie');
    await tester.enterText(find.byKey(const Key('insuranceStart')), '01.01.2025');
    await tester.tap(find.byKey(const Key('insuranceCreate')));
    await settle(tester);
    expect(find.text('Du 01.01.2025'), findsOneWidget);
    await tester.tap(find.byKey(const Key('insuranceTrancheNew')));
    await settle(tester);
    await tester.enterText(find.byKey(const Key('trancheStart')), '01.01.2026');
    await tester.tap(find.byKey(const Key('trancheSave')));
    await settle(tester);
    expect(find.text('Du 01.01.2026'), findsOneWidget);
    expect(find.text('Du 01.01.2025 au 31.12.2025'), findsNothing, reason: 'the other tranches are folded');
    await tester.tap(find.byKey(const Key('insuranceOthers')));
    await settle(tester);
    expect(find.text('Du 01.01.2025 au 31.12.2025'), findsOneWidget);
    await tester.tap(find.byKey(const Key('insuranceOthers')));
    await settle(tester);

    // A document: sent to the server, kept here, opened.
    final ledger = (await tester.runAsync(services.ledger.load))!;
    final active = ledger.insurances.single.activeAt(CalendarDate(2026, 11, 27))!;
    final pdf = Uint8List.fromList(utf8.encode('%PDF-1.7 police fictive 2026'));
    files.picks.add(PickedFile('Police 2026.pdf', pdf));
    await tester.tap(find.byKey(ValueKey('documentAdd-${active.id}')));
    await settle(tester);
    expect(tester.widget<TextField>(find.byKey(const Key('documentName'))).controller!.text, 'Police 2026');
    await tester.tap(find.text('Police'));
    await tester.tap(find.byKey(const Key('documentSave')));
    await settle(tester);
    expect(server.uploads, 1);
    final document = (await tester.runAsync(services.ledger.load))!.insurances.single
        .activeAt(CalendarDate(2026, 11, 27))!
        .documents
        .single;
    expect(
      (document.kind, document.name, document.size, document.mediaType),
      (InsuranceDocumentKind.policy, 'Police 2026', pdf.length, 'application/pdf'),
    );
    expect(find.text('Police · 1 Ko'), findsOneWidget);
    server.unreachable = true;
    await tester.tap(find.byKey(ValueKey('document-${document.id}')));
    await settle(tester);
    expect(files.opened['Police 2026.pdf'], pdf, reason: 'opened from the copy of the device, offline');

    // A link and a note.
    await tester.tap(find.byKey(ValueKey('linkAdd-${active.id}')));
    await settle(tester);
    await tester.enterText(find.byKey(const Key('linkLabel')), 'Espace client');
    await tester.enterText(find.byKey(const Key('linkUrl')), 'https://assurance.example/client');
    await tester.tap(find.byKey(const Key('linkSave')));
    await settle(tester);
    await tester.tap(find.text('Espace client'));
    await settle(tester);
    expect(files.links, ['https://assurance.example/client']);
    await tester.tap(find.byTooltip('Modifier la note'));
    await settle(tester);
    await tester.enterText(find.byKey(const Key('textDialogField')), 'Franchise 300');
    await tester.tap(find.byKey(const Key('textDialogSave')));
    await settle(tester);
    expect(find.text('Franchise 300'), findsOneWidget);

    // The list shows the tranche in force.
    await tester.tap(find.byType(BackButton));
    await settle(tester);
    expect(find.text('En cours depuis le 01.01.2026 · un document'), findsOneWidget);
  });
}
