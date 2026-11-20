import 'package:batz/data/sync/sync_engine.dart';
import 'package:batz/helpers/theme.dart';
import 'package:batz/l10n/app_localizations.dart';
import 'package:batz/pages/sync/sync_card.dart';
import 'package:batz/pages/sync/sync_cubit.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockSyncCubit extends MockCubit<SyncState> implements SyncCubit {}

Future<_MockSyncCubit> _pump(WidgetTester tester, SyncState state) async {
  final cubit = _MockSyncCubit();
  when(() => cubit.state).thenReturn(state);
  when(() => cubit.sync(manual: any(named: 'manual'))).thenAnswer((_) async {});
  await tester.pumpWidget(
    BlocProvider<SyncCubit>.value(
      value: cubit,
      child: MaterialApp(
        theme: buildTheme(Brightness.light),
        locale: const Locale('fr'),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: const Scaffold(body: SyncCard()),
      ),
    ),
  );
  return cubit;
}

void main() {
  testWidgets('up to date: date, pending modifications, and the button', (tester) async {
    final cubit = await _pump(
      tester,
      SyncState(status: SyncStatus.upToDate, lastSync: DateTime(2026, 11, 20, 21, 4), pending: 3),
    );
    expect(find.text('À jour'), findsOneWidget);
    expect(find.text('Dernière synchronisation : 20.11.2026 à 21:04'), findsOneWidget);
    expect(find.text('3 modifications en attente'), findsOneWidget);
    await tester.tap(find.byKey(const Key('syncNow')));
    verify(() => cubit.sync(manual: true)).called(1);
  });

  testWidgets('in progress: the button waits', (tester) async {
    await _pump(tester, const SyncState(status: SyncStatus.syncing));
    expect(find.text('Synchronisation en cours…'), findsOneWidget);
    expect(tester.widget<ButtonStyleButton>(find.byKey(const Key('syncNow'))).onPressed, isNull);
  });

  testWidgets('incompatible versions show the reason', (tester) async {
    await _pump(
      tester,
      const SyncState(
        status: SyncStatus.incompatible,
        incompatibility: Incompatibility.appTooOld,
        minAppVersion: '0.4.0',
        serverVersion: 'v0.4.0',
      ),
    );
    expect(find.text('Versions incompatibles'), findsOneWidget);
    expect(find.textContaining('demande au moins la version 0.4.0'), findsOneWidget);

    await _pump(
      tester,
      const SyncState(
        status: SyncStatus.incompatible,
        incompatibility: Incompatibility.serverTooOld,
        minAppVersion: '0.1.0',
        serverVersion: 'v0.2.0',
      ),
    );
    expect(find.textContaining('le serveur (version v0.2.0) est trop ancien'), findsOneWidget);
  });

  testWidgets('offline, revoked, error, and a clock off by more than five minutes', (tester) async {
    await _pump(tester, const SyncState(status: SyncStatus.offline, pending: 1));
    expect(find.text('Hors ligne'), findsOneWidget);
    expect(find.text('Une modification en attente'), findsOneWidget);
    expect(find.textContaining('échoué'), findsNothing, reason: 'no error message when offline');

    await _pump(tester, const SyncState(status: SyncStatus.revoked));
    expect(find.text('Appareil révoqué'), findsOneWidget);
    expect(find.textContaining('Ses données restent sur cet appareil'), findsOneWidget);

    await _pump(tester, const SyncState(status: SyncStatus.serverChanged, pending: 4));
    expect(find.text('Le serveur a changé'), findsOneWidget);
    expect(find.textContaining('Associez cet appareil de nouveau'), findsOneWidget);
    expect(find.text('4 modifications en attente'), findsOneWidget);
    expect(find.byKey(const Key('syncPairAgain')), findsOneWidget);

    await _pump(tester, const SyncState(status: SyncStatus.error, error: 'boom'));
    expect(find.text('La dernière synchronisation a échoué : boom'), findsOneWidget);

    await _pump(tester, const SyncState(status: SyncStatus.upToDate, clockOffset: Duration(minutes: -8)));
    expect(find.textContaining("s'écarte de 8 minutes"), findsOneWidget);
    await _pump(tester, const SyncState(status: SyncStatus.upToDate, clockOffset: Duration(minutes: 4)));
    expect(find.byKey(const Key('syncClockWarning')), findsNothing);
  });

  testWidgets('first exchange: the question, merge, and replace after confirmation', (tester) async {
    final cubit = await _pump(tester, const SyncState(status: SyncStatus.decisionNeeded, pending: 2));
    when(cubit.merge).thenAnswer((_) async {});
    when(cubit.replace).thenAnswer((_) async {});
    expect(find.text('Premier échange avec le serveur'), findsOneWidget);
    expect(find.textContaining('sans rien en commun'), findsOneWidget);
    expect(find.byKey(const Key('syncNow')), findsNothing);

    await tester.tap(find.byKey(const Key('syncMerge')));
    verify(cubit.merge).called(1);

    await tester.tap(find.byKey(const Key('syncReplace')));
    await tester.pumpAndSettle();
    expect(find.textContaining('sera définitivement perdu'), findsOneWidget);
    await tester.tap(find.text('Annuler'));
    await tester.pumpAndSettle();
    verifyNever(cubit.replace);

    await tester.tap(find.byKey(const Key('syncReplace')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('syncReplaceConfirm')));
    await tester.pumpAndSettle();
    verify(cubit.replace).called(1);
  });
}
