import 'package:batz/app.dart';
import 'package:batz/domain/calendar_date.dart';
import 'package:batz/domain/journal/journal_entry.dart';
import 'package:batz/domain/ledger/account.dart';
import 'package:batz/domain/ledger/ledger.dart';
import 'package:batz/domain/ledger/proposal.dart';
import 'package:batz/services.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../domain/ledger/exports_test.dart' show export, line;
import '../../support/services.dart';
import '../../support/statements.dart';
import '../accounts/accounts_page_test.dart' show settle;

void main() {
  final january = fixtureStatement('2026-01');
  late AppServices services;

  Future<Ledger> ledger(WidgetTester tester) async => (await tester.runAsync(services.ledger.load))!;

  Future<void> write(WidgetTester tester, Modification Function(Ledger l) build) =>
      tester.runAsync(() async => services.ledger.write(build(await services.ledger.load())));

  testWidgets('a top-up from PostFinance to Neon: the line of Neon is proposed as its other side; a transfer '
      'without it is a task after ten days', (tester) async {
    tester.view.physicalSize = const Size(500, 1100);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    services = (await tester.runAsync(() => testServices(today: () => CalendarDate(2026, 2, 20))))!;
    addTearDown(() => tester.runAsync(services.database.close));
    await write(
      tester,
      (l) => l.createAccount(
        'bank',
        const AccountDraft(
          name: 'PostFinance',
          type: AccountType.privateAccount,
          importFormat: ImportFormat.postfinance,
        ),
      ),
    );
    await write(
      tester,
      (l) => l.createAccount(
        'neon',
        const AccountDraft(name: 'Neon', type: AccountType.privateAccount, importFormat: ImportFormat.neon),
      ),
    );
    await write(tester, (l) => l.createTree(2026));
    await write(
      tester,
      (l) => l.importStatement('bank', january.statement, fingerprint: january.fingerprint).modification,
    );
    // Two lines of January sent to Neon: one arrives there, the other not.
    final out = [
      for (final t in (await ledger(tester)).linesToValidate)
        if (t.amount < 0) t,
    ];
    final topUp = out[0], lost = out.firstWhere((t) => t.amount != topUp.amount && t.date.day > 3);
    for (final t in [topUp, lost]) {
      await write(tester, (l) => l.classify(t.id, const Classification.transfer('neon')));
    }
    final received = line(topUp.date.addDays(1), -topUp.amount, 'Titulaire Fictif\nVersement');
    await write(
      tester,
      (l) => l
          .importStatement(
            'neon',
            export([received]),
            fingerprint: 'a' * 64,
            closingBalance: received.amount,
            today: CalendarDate(2026, 2, 1),
          )
          .modification,
    );

    await tester.pumpWidget(BatzApp(services: services));
    await settle(tester);
    expect(find.byKey(const Key('taskUnpairedTransfers')), findsOneWidget);
    expect(find.text('Un transfert entre comptes importés sans son autre côté'), findsOneWidget);

    await tester.tap(find.byKey(const Key('taskLinesToValidate')));
    await settle(tester);
    await tester.tap(find.byKey(const Key('tabProposed')));
    await settle(tester);
    final neonLine = (await ledger(tester)).transactions.values.firstWhere((t) => t.accountId == 'neon');
    expect(
      find.descendant(
        of: find.byKey(ValueKey('proposed-${neonLine.id}')),
        matching: find.textContaining('Autre côté du transfert du ${DateFieldText.of(topUp.date)} sur PostFinance'),
      ),
      findsOneWidget,
    );
    await tester.tap(find.byKey(ValueKey('confirmProposal-${neonLine.id}')));
    await settle(tester);
    final validated = (await ledger(tester)).transactions[neonLine.id]!;
    expect((validated.isValidated, validated.counterpartAccountId), (true, 'bank'));
    await tester.tap(find.byType(BackButton));
    await settle(tester);

    // The task lists the top-up whose line is not on Neon.
    await tester.tap(find.byKey(const Key('taskUnpairedTransfers')));
    await settle(tester);
    expect(find.byKey(ValueKey('unpaired-${lost.id}')), findsOneWidget);
    expect(find.byKey(ValueKey('unpaired-${topUp.id}')), findsNothing);
    await tester.tap(find.byKey(ValueKey('unpaired-${lost.id}')));
    await settle(tester);
    expect(find.byKey(const Key('pairedMissing')), findsOneWidget);
    await tester.tap(find.byType(BackButton).last);
    await settle(tester);
    await tester.tap(find.byType(BackButton).last);
    await settle(tester);

    // The detail of the top-up shows its other side.
    final detail = (await ledger(tester)).pairedLineOf((await ledger(tester)).transactions[topUp.id]!);
    expect(detail?.id, neonLine.id);
  });
}

/// The dates as the screens write them.
abstract final class DateFieldText {
  static String of(CalendarDate date) =>
      '${date.day.toString().padLeft(2, '0')}.${date.month.toString().padLeft(2, '0')}.${date.year}';
}
