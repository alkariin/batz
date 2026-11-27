import 'package:batz/app.dart';
import 'package:batz/data/device_lock.dart';
import 'package:batz/pages/shell.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fake_device_lock.dart';
import '../../support/services.dart';
import '../accounts/accounts_page_test.dart' show tapInList;

final _lockScreen = find.byKey(const Key('lockScreen'));
final _unlockButton = find.byKey(const Key('unlockButton'));

/// Starts the app on a phone: [phone] is its lock, [clock] its time. With
/// no phone, the app runs on a computer.
Future<void> _start(WidgetTester tester, {FakeDeviceLock? phone, FakeClock? clock}) async {
  tester.view.physicalSize = const Size(400, 900);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final services = (await tester.runAsync(() => testServices(deviceLock: phone, now: clock?.call)))!;
  addTearDown(() => tester.runAsync(services.database.close));
  // Each test starts with the app on screen.
  tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
  await tester.pumpWidget(BatzApp(services: services));
  await tester.pumpAndSettle();
}

/// The holder of the phone answers the system dialog.
Future<void> _answer(WidgetTester tester, FakeDeviceLock phone, UnlockOutcome outcome) async {
  phone.answer(outcome);
  await tester.pumpAndSettle();
}

/// The app leaves the screen for [duration], then comes back.
Future<void> _away(WidgetTester tester, FakeClock clock, Duration duration) async {
  for (final state in [AppLifecycleState.inactive, AppLifecycleState.hidden, AppLifecycleState.paused]) {
    tester.binding.handleAppLifecycleStateChanged(state);
  }
  await tester.pump();
  clock.advance(duration);
  for (final state in [AppLifecycleState.hidden, AppLifecycleState.inactive, AppLifecycleState.resumed]) {
    tester.binding.handleAppLifecycleStateChanged(state);
  }
  await tester.pumpAndSettle();
}

void main() {
  late FakeDeviceLock phone;
  late FakeClock clock;

  setUp(() {
    phone = FakeDeviceLock();
    clock = FakeClock(DateTime(2026, 11, 21, 8));
  });

  testWidgets('the app starts locked: none of its screens exists before the phone is unlocked', (tester) async {
    await _start(tester, phone: phone, clock: clock);

    expect(_lockScreen, findsOneWidget);
    expect(find.text("L'app est verrouillée."), findsOneWidget);
    // Not built at all: nothing of the app is in the tree, drawn or not.
    expect(find.byType(AppShell, skipOffstage: false), findsNothing);
    expect(find.byType(Navigator, skipOffstage: false), findsNothing);
    expect(find.text('Accueil', skipOffstage: false), findsNothing);
    // The system dialog opened by itself, once, with its texts.
    expect(phone.asked, hasLength(1));
    expect(phone.asked.single.title, 'Déverrouiller batz');
    expect(phone.asked.single.reason, "Empreinte, visage ou code de l'appareil");
    expect(phone.asked.single.cancel, 'Annuler');
    expect(tester.widget<FilledButton>(_unlockButton).onPressed, isNull, reason: 'the dialog is open');

    await _answer(tester, phone, const Unlocked());
    expect(_lockScreen, findsNothing);
    expect(find.widgetWithText(AppBar, 'Accueil'), findsOneWidget);
    expect(find.byKey(const Key('taskNoScreenLock')), findsNothing);
  });

  testWidgets('a cancelled dialog leaves the app locked, with a button; an error is shown and can be retried', (
    tester,
  ) async {
    await _start(tester, phone: phone, clock: clock);

    await _answer(tester, phone, const UnlockRefused());
    expect(_lockScreen, findsOneWidget);
    expect(find.text('Déverrouillage annulé.'), findsOneWidget);
    expect(find.byType(AppShell, skipOffstage: false), findsNothing);
    expect(phone.dialogOpen, isFalse);

    await tester.tap(find.widgetWithText(FilledButton, 'Déverrouiller'));
    await tester.pump();
    expect(phone.asked, hasLength(2));
    await _answer(tester, phone, const UnlockRefused(lockedOut: true));
    expect(find.text("Trop d'essais : réessayez dans un moment."), findsOneWidget);
    expect(find.byType(AppShell, skipOffstage: false), findsNothing);

    await tester.tap(_unlockButton);
    await tester.pump();
    await _answer(tester, phone, UnlockFailed(StateError('no activity')));
    expect(find.textContaining('Le déverrouillage a échoué :'), findsOneWidget);
    expect(find.textContaining('no activity'), findsOneWidget);
    expect(find.byType(AppShell, skipOffstage: false), findsNothing);

    await tester.tap(find.widgetWithText(FilledButton, 'Réessayer'));
    await tester.pump();
    expect(phone.asked, hasLength(4));
    await _answer(tester, phone, const Unlocked());
    expect(_lockScreen, findsNothing);
    expect(find.widgetWithText(AppBar, 'Accueil'), findsOneWidget);
  });

  testWidgets('back within a minute the app stays open; after more it locks, and the screen and what was being '
      'typed are found again', (tester) async {
    await _start(tester, phone: phone, clock: clock);
    await _answer(tester, phone, const Unlocked());

    // A form, half filled: Plus › Comptes › new account.
    await tester.tap(find.descendant(of: find.byType(NavigationBar), matching: find.text('Plus')));
    await tester.pumpAndSettle();
    await tapInList(tester, find.text('Comptes'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Nouveau compte'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('accountName')), 'Épargne en cours de saisie');
    await tester.pump();

    // 59 then 60 seconds away: no lock.
    await _away(tester, clock, const Duration(seconds: 59));
    expect(_lockScreen, findsNothing);
    await _away(tester, clock, const Duration(seconds: 60));
    expect(_lockScreen, findsNothing);
    expect(phone.asked, hasLength(1));

    // 61 seconds: locked. The screens are kept, but not drawn.
    await _away(tester, clock, const Duration(seconds: 61));
    expect(_lockScreen, findsOneWidget);
    expect(phone.asked, hasLength(2), reason: 'the dialog opened by itself');
    expect(find.text('Épargne en cours de saisie'), findsNothing);
    expect(find.text('Nouveau compte'), findsNothing);
    expect(find.byType(AppShell), findsNothing);
    expect(find.text('Épargne en cours de saisie', skipOffstage: false), findsOneWidget, reason: 'kept off stage');
    expect(
      tester
          .widget<Offstage>(
            find.ancestor(of: find.byType(Navigator, skipOffstage: false), matching: find.byType(Offstage)).last,
          )
          .offstage,
      isTrue,
    );

    // The « back » of Android closes nothing behind the lock.
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(_lockScreen, findsOneWidget);
    expect(find.text('Épargne en cours de saisie', skipOffstage: false), findsOneWidget);

    // Leaving and coming back while locked changes nothing; the dialog is
    // still the same one.
    await _away(tester, clock, const Duration(minutes: 10));
    expect(_lockScreen, findsOneWidget);
    expect(phone.asked, hasLength(2));

    await _answer(tester, phone, const Unlocked());
    expect(_lockScreen, findsNothing);
    expect(find.text('Nouveau compte'), findsOneWidget, reason: 'the same screen');
    expect(find.text('Épargne en cours de saisie'), findsOneWidget, reason: 'what was being typed');

    // Unlocked, « back » closes the form as usual: the guard only holds
    // while the app is locked.
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('Nouveau compte'), findsNothing);
    await tester.tap(find.byTooltip('Nouveau compte'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('accountName')), 'Épargne en cours de saisie');
    await tester.pump();

    // The clock of the phone goes back while the app is away: locked.
    await _away(tester, clock, const Duration(minutes: -30));
    expect(_lockScreen, findsOneWidget);
    expect(find.text('Épargne en cours de saisie'), findsNothing);
    await _answer(tester, phone, const Unlocked());
    expect(find.text('Épargne en cours de saisie'), findsOneWidget);
  });

  testWidgets('a phone without screen lock opens the app, and the home screen says so while it lasts', (tester) async {
    phone.screenLock = false;
    await _start(tester, phone: phone, clock: clock);

    expect(_lockScreen, findsNothing);
    expect(find.widgetWithText(AppBar, 'Accueil'), findsOneWidget);
    expect(find.byKey(const Key('taskNoScreenLock')), findsOneWidget);
    expect(find.text("Ce téléphone n'a pas de verrouillage d'écran"), findsOneWidget);
    expect(phone.asked, isEmpty);

    await _away(tester, clock, const Duration(hours: 2));
    expect(_lockScreen, findsNothing);
    expect(find.byKey(const Key('taskNoScreenLock')), findsOneWidget);

    // A screen lock is set in the settings of Android: the app is behind it
    // when it comes back, and the warning is gone once unlocked.
    phone.screenLock = true;
    await _away(tester, clock, const Duration(seconds: 20));
    expect(_lockScreen, findsOneWidget);
    expect(find.byType(AppShell), findsNothing);
    await _answer(tester, phone, const Unlocked());
    expect(find.widgetWithText(AppBar, 'Accueil'), findsOneWidget);
    expect(find.byKey(const Key('taskNoScreenLock')), findsNothing);
  });

  testWidgets('on a computer there is no lock, whatever the time away', (tester) async {
    await _start(tester, clock: clock);

    expect(_lockScreen, findsNothing);
    expect(find.widgetWithText(AppBar, 'Accueil'), findsOneWidget);
    await _away(tester, clock, const Duration(days: 2));
    expect(_lockScreen, findsNothing);
    expect(find.widgetWithText(AppBar, 'Accueil'), findsOneWidget);
    expect(find.byKey(const Key('taskNoScreenLock')), findsNothing);
  });
}
