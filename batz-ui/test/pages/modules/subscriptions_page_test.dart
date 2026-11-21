import 'package:batz/app.dart';
import 'package:batz/domain/calendar_date.dart';
import 'package:batz/domain/modules/subscriptions.dart';
import 'package:batz/services.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../domain/modules/subscriptions_test.dart' show subscriptionExample;
import '../../support/services.dart';
import '../accounts/accounts_page_test.dart' show settle;

void main() {
  late AppServices services;

  String text(WidgetTester tester, String key) => tester.widget<Text>(find.byKey(ValueKey(key))).data!;

  testWidgets('the subscriptions of the example: current first, 22.82 a month and 273.80 a year; a price change '
      'closes the previous tranche; an overlapping tranche is refused; a new subscription', (tester) async {
    tester.view.physicalSize = const Size(400, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    services = (await tester.runAsync(() => testServices(today: () => CalendarDate(2026, 11, 21))))!;
    addTearDown(() => tester.runAsync(services.database.close));
    await tester.runAsync(
      () => subscriptionExample((build) async {
        await services.ledger.write(build(await services.ledger.load()));
        return services.ledger.load();
      }),
    );
    await tester.pumpWidget(BatzApp(services: services));
    await settle(tester);
    await tester.tap(find.descendant(of: find.byType(NavigationBar), matching: find.text('Plus')));
    await settle(tester);
    await tester.tap(find.byKey(const Key('moreSubscriptions')));
    await settle(tester);
    expect((text(tester, 'subscriptionsMonthly'), text(tester, 'subscriptionsYearly')), ('22.82', '273.80'));
    final order = [
      for (final key in ['bike', 'streaming', 'gym']) tester.getTopLeft(find.byKey(ValueKey('subscription-$key'))).dy,
    ];
    expect(order, orderedEquals([...order]..sort()), reason: 'current, then ended');
    expect(find.text('Terminés'), findsOneWidget);
    expect(text(tester, 'subscriptionInfo-streaming'), contains('14.90 par mois · 178.80 par an'));

    // A new price from 1.12.2026: the tranche before ends on 30.11.
    await tester.tap(find.byKey(const ValueKey('subscription-streaming')));
    await settle(tester);
    await tester.tap(find.byKey(const Key('trancheAdd')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('trancheAmount')), '16.90');
    await tester.enterText(find.byKey(const Key('trancheStart')), '01.12.2026');
    await tester.tap(find.byKey(const Key('trancheSave')));
    await settle(tester);
    expect(find.text("14.90 par mois · dès le 01.01.2026 jusqu'au 30.11.2026"), findsOneWidget);
    expect(find.text('16.90 par mois · dès le 01.12.2026'), findsOneWidget);

    // A tranche over an existing one is refused, with its reason.
    await tester.tap(find.byKey(const Key('trancheAdd')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('trancheAmount')), '5');
    await tester.enterText(find.byKey(const Key('trancheStart')), '01.06.2025');
    await tester.enterText(find.byKey(const Key('trancheEnd')), '31.07.2025');
    await tester.tap(find.byKey(const Key('trancheSave')));
    await settle(tester);
    expect(find.text("Cette tranche chevauche une autre tranche de l'abonnement."), findsOneWidget);
    await tester.tap(find.byType(BackButton));
    await settle(tester);

    // A new subscription, yearly.
    await tester.tap(find.byKey(const Key('subscriptionNew')));
    await settle(tester);
    await tester.enterText(find.byKey(const Key('subscriptionName')), 'Journal');
    await tester.tap(find.byKey(const Key('subscriptionSave')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('trancheAmount')), '240');
    await tester.tap(find.text('Annuel'));
    await tester.enterText(find.byKey(const Key('trancheStart')), '01.01.2026');
    await tester.tap(find.byKey(const Key('trancheSave')));
    await settle(tester);
    expect((text(tester, 'subscriptionsMonthly'), text(tester, 'subscriptionsYearly')), ('42.82', '513.80'));
    final at = (await tester.runAsync(services.ledger.load))!.subscriptionsAt(CalendarDate(2026, 11, 21));
    expect(at.inState(SubscriptionState.current).map((s) => s.name), ['Assurance vélo', 'Journal', 'Streaming']);
  });
}
