import 'package:batz/app.dart';
import 'package:batz/domain/calendar_date.dart';
import 'package:batz/domain/ledger/account.dart';
import 'package:batz/domain/modules/monthly_tasks.dart';
import 'package:batz/pages/ledger_cubit.dart';
import 'package:batz/pages/shell.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../domain/ledger/exports_test.dart' show export, line;
import '../../support/services.dart';
import '../accounts/accounts_page_test.dart' show settle;

void main() {
  testWidgets('the monthly follow-up: a list proposed from the home screen, boxes checked by hand or by the imports, '
      'every month on its screen', (tester) async {
    tester.view.physicalSize = const Size(500, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final services = (await tester.runAsync(() => testServices(today: () => CalendarDate(2026, 12, 5))))!;
    addTearDown(() => tester.runAsync(services.database.close));
    await tester.runAsync(() async {
      final ledger = await services.ledger.load();
      await services.ledger.write(
        ledger.createAccount(
          'neon',
          const AccountDraft(name: 'Neon', type: AccountType.privateAccount, importFormat: ImportFormat.neon),
        ),
      );
    });
    await tester.pumpWidget(BatzApp(services: services));
    await settle(tester);

    // No task yet: the home screen leads to the list, which proposes one.
    await tester.tap(find.byKey(const Key('monthlySetUp')));
    await settle(tester);
    await tester.tap(find.byKey(const Key('monthlySuggest')));
    await settle(tester);
    expect(find.text('Importer Neon'), findsOneWidget);
    expect(find.text('Saisir les transactions en espèces'), findsOneWidget);
    expect(find.text('Mettre à jour les dettes'), findsOneWidget);
    expect(find.text('Depuis décembre 2026 · Les imports de Neon'), findsOneWidget);

    // The cash from November on.
    await tester.tap(find.text('Saisir les transactions en espèces'));
    await settle(tester);
    await tester.tap(find.byKey(const Key('monthlyTaskSinceMonth')));
    await settle(tester);
    await tester.tap(find.text('novembre').last);
    await settle(tester);
    await tester.tap(find.byKey(const Key('monthlyTaskSave')));
    await settle(tester);
    expect(find.text('Depuis novembre 2026 · Moi, à la main'), findsOneWidget);
    await tester.tap(find.byType(BackButton));
    await settle(tester);

    // November is to finish: its only task is to do.
    String month() => tester.widget<Text>(find.byKey(const Key('monthlyCardMonth'))).data!;
    expect(month(), 'Novembre 2026 · 0 sur 1');
    final cash = (await tester.runAsync(services.ledger.load))!.monthlyTasks.firstWhere((t) => t.accountId == null);
    await tester.tap(find.byKey(ValueKey('monthly-${cash.id}-2026-11')));
    await settle(tester);
    expect(month(), 'Décembre 2026, en cours · 0 sur 3', reason: 'every past month done');

    // An import of Neon after the end of December checks it.
    await tester.runAsync(() async {
      final ledger = await services.ledger.load();
      await services.ledger.write(
        ledger
            .importStatement(
              'neon',
              export([line(CalendarDate(2026, 12, 2), -500, 'Kiosque')]),
              fingerprint: 'a' * 64,
              closingBalance: 1000,
              today: CalendarDate(2026, 12, 4),
            )
            .modification,
      );
    });
    await tester.runAsync(() => tester.element(find.byType(AppShell)).read<LedgerCubit>().load());
    await settle(tester);
    await tester.tap(find.byKey(const Key('monthlyAll')));
    await settle(tester);
    expect(find.text('Novembre 2026'), findsOneWidget);
    expect(find.text('Terminé'), findsOneWidget);
    expect(find.text("Importé jusqu'au 04.12.2026"), findsOneWidget, reason: 'not yet the end of December');
    final neon = (await tester.runAsync(services.ledger.load))!.monthlyTasks.firstWhere((t) => t.accountId != null);
    final box = tester.widget<CheckboxListTile>(find.byKey(ValueKey('monthly-${neon.id}-2026-12')));
    expect((box.value, box.onChanged != null), (false, true), reason: 'still to do, and the user may check it');
  });
}
