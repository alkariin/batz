import 'package:batz/data/server/certificate.dart';
import 'package:batz/data/server/server_client.dart';
import 'package:batz/data/server/server_repository.dart';
import 'package:batz/helpers/theme.dart';
import 'package:batz/l10n/app_localizations.dart';
import 'package:batz/pages/server/server_cubit.dart';
import 'package:batz/pages/server/server_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockRepository extends Mock implements ServerRepository {}

final _pairing = Pairing(
  address: Uri.parse('https://192.168.1.95:8443'),
  deviceId: 'me',
  deviceKey: 'key',
  fingerprint: 'AB:CD',
);

ServerDevice _device(String id, String name, {bool current = false, DateTime? revokedAt}) => ServerDevice(
  id: id,
  name: name,
  createdAt: DateTime.utc(2026, 11, 20),
  lastSeenAt: null,
  revokedAt: revokedAt,
  current: current,
);

Future<ServerCubit> _pump(WidgetTester tester, ServerRepository repo) async {
  final cubit = ServerCubit(repo);
  addTearDown(cubit.close);
  await tester.pumpWidget(
    BlocProvider.value(
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
        home: const ServerPage(),
      ),
    ),
  );
  await cubit.load();
  await tester.pumpAndSettle();
  return cubit;
}

void main() {
  setUpAll(() {
    registerFallbackValue(_pairing);
    registerFallbackValue(Uri());
  });

  testWidgets('unpaired: the form sends address, code and name', (tester) async {
    final repo = _MockRepository();
    when(repo.pairing).thenAnswer((_) async => null);
    when(
      () => repo.pair(
        address: any(named: 'address'),
        code: any(named: 'code'),
        deviceName: any(named: 'deviceName'),
      ),
    ).thenThrow(ServerException(401, 'PAIRING_CODE_EXPIRED', ''));
    await _pump(tester, repo);

    await tester.enterText(find.byKey(const Key('server-address')), '192.168.1.95');
    await tester.enterText(find.byKey(const Key('server-code')), 'abcd-1234');
    await tester.enterText(find.byKey(const Key('server-name')), 'Téléphone');
    await tester.tap(find.text('Associer'));
    await tester.pumpAndSettle();

    verify(() => repo.pair(address: Uri.parse('https://192.168.1.95:8443'), code: 'abcd-1234', deviceName: 'Téléphone'))
        .called(1);
    expect(find.text('Ce code a expiré. Demandez-en un nouveau au serveur.'), findsOneWidget);
  });

  testWidgets('paired: status, devices and revocation', (tester) async {
    final repo = _MockRepository();
    when(repo.pairing).thenAnswer((_) async => _pairing);
    when(() => repo.status(any())).thenAnswer(
      (_) async => ServerStatus(
        version: 'v0.1.0',
        minAppVersion: '0.1.0',
        devices: [
          _device('me', 'Ordinateur', current: true),
          _device('p', 'Téléphone'),
          _device('old', 'Ancien', revokedAt: DateTime.utc(2026, 11, 19)),
        ],
      ),
    );
    when(() => repo.revoke(any(), any())).thenAnswer((_) async {});
    await _pump(tester, repo);

    expect(find.text('Associé au serveur'), findsOneWidget);
    expect(find.text('Adresse : 192.168.1.95:8443'), findsOneWidget);
    expect(find.text('Version du serveur : v0.1.0'), findsOneWidget);
    expect(find.text('AB:CD'), findsOneWidget);
    expect(find.text('Ordinateur (cet appareil)'), findsOneWidget);
    expect(find.text('Révoqué le 19.11.2026'), findsOneWidget);
    expect(find.textContaining('trop ancienne'), findsNothing);
    // Only the other, active device can be revoked from here.
    expect(find.text('Révoquer'), findsOneWidget);

    await tester.tap(find.text('Révoquer'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Confirmer'));
    await tester.pumpAndSettle();
    verify(() => repo.revoke(_pairing, 'p')).called(1);
  });

  testWidgets('a server requiring a newer app shows a warning', (tester) async {
    final repo = _MockRepository();
    when(repo.pairing).thenAnswer((_) async => _pairing);
    when(() => repo.status(any()))
        .thenAnswer((_) async => ServerStatus(version: 'v9.0.0', minAppVersion: '9.0.0', devices: []));
    await _pump(tester, repo);
    expect(find.textContaining('au moins la version 9.0.0'), findsOneWidget);
  });

  testWidgets('another certificate: refused, explained, and the pairing can be forgotten', (tester) async {
    final repo = _MockRepository();
    when(repo.pairing).thenAnswer((_) async => _pairing);
    when(() => repo.status(any())).thenThrow(CertificateMismatchException('AB:CD', 'EF:01'));
    when(repo.forget).thenAnswer((_) async {});
    await _pump(tester, repo);

    expect(find.textContaining('autre certificat'), findsOneWidget);
    await tester.tap(find.text('Oublier ce serveur sur cet appareil'));
    await tester.pumpAndSettle();
    verify(repo.forget).called(1);
    expect(find.text('Associer'), findsOneWidget);
  });
}
