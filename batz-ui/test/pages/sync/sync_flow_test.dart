import 'dart:convert';

import 'package:batz/app.dart';
import 'package:batz/data/secret_store.dart';
import 'package:batz/data/server/server_repository.dart';
import 'package:batz/domain/ledger/account.dart';
import 'package:batz/services.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fake_server.dart';
import '../../support/ledger_harness.dart';
import '../../support/services.dart';
import '../accounts/accounts_page_test.dart' show createAccount, openAccounts, settle;
import 'sync_cubit_test.dart' show pairing;

void main() {
  testWidgets('the app exchanges at start, reloads its screens, counts what waits and sends it on demand', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    // Another device created an account; the server holds it.
    final other = (await tester.runAsync(() => LedgerHarness.open(deviceId: '22222222-0000-4000-8000-000000000000')))!;
    addTearDown(() => tester.runAsync(other.close));
    await tester.runAsync(
      () => other.apply((l) => l.createAccount('cash', const AccountDraft(name: 'Espèces', type: AccountType.cash))),
    );
    final fake = FakeServer(other.journal);
    final secrets = MemorySecretStore()..values[pairingSecretKey] = jsonEncode(pairing.toJson());
    final services = (await tester.runAsync(() => testServices(secrets: secrets, syncTransport: (_) => fake)))!;
    addTearDown(() => tester.runAsync(services.database.close));

    await tester.pumpWidget(BatzApp(services: services));
    await settle(tester);
    expect(find.text('À jour'), findsOneWidget);
    expect(find.text('Aucune modification en attente'), findsOneWidget);
    expect(find.textContaining('Dernière synchronisation'), findsOneWidget);

    await openAccounts(tester);
    expect(find.text('Espèces'), findsNWidgets(2), reason: 'received and shown: name and type');

    // The server goes away; the modification made meanwhile waits.
    fake.unreachable = true;
    await createAccount(tester, 'UBS');
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    await tester.tap(find.descendant(of: find.byType(NavigationBar), matching: find.text('Accueil')));
    await settle(tester);
    expect(find.text('Une modification en attente'), findsOneWidget);
    await tester.tap(find.byKey(const Key('syncNow')));
    await settle(tester);
    expect(find.text('Hors ligne'), findsOneWidget);
    expect(find.text('Une modification en attente'), findsOneWidget);

    fake.unreachable = false;
    await tester.tap(find.byKey(const Key('syncNow')));
    await settle(tester);
    expect(find.text('À jour'), findsOneWidget);
    expect(find.text('Aucune modification en attente'), findsOneWidget);
    final onServer = (await tester.runAsync(other.journal.entries))!;
    expect(onServer.where((e) => e.field == 'name').map((e) => e.value), containsAll(['Espèces', 'UBS']));
  });

  testWidgets('without a server, the home screen says so and offers pairing', (tester) async {
    tester.view.physicalSize = const Size(400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final AppServices services = (await tester.runAsync(testServices))!;
    addTearDown(() => tester.runAsync(services.database.close));
    await tester.pumpWidget(BatzApp(services: services));
    await settle(tester);
    expect(find.textContaining("n'est associé à aucun serveur"), findsOneWidget);
    await tester.tap(find.text('Associer un serveur'));
    await tester.pumpAndSettle();
    expect(find.text("Code d'association"), findsOneWidget);
  });
}
