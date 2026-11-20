// End-to-end: the app's server code against a real batz-web process, over
import 'dart:io';

// HTTPS with certificate pinning.
import 'package:batz/data/secret_store.dart';
import 'package:batz/data/server/certificate.dart';
import 'package:batz/data/server/server_client.dart';
import 'package:batz/data/server/server_repository.dart';
import 'package:batz/pages/server/server_cubit.dart';
import 'package:flutter_test/flutter_test.dart';

import 'server_harness.dart';

Matcher serverError(String code, [int status = 401]) =>
    isA<ServerException>().having((e) => e.code, 'code', code).having((e) => e.status, 'status', status);

void main() {
  late LocalServer server;

  setUp(() async => server = await LocalServer.start());
  tearDown(() async {
    await server.stop();
    server.dataDir.deleteSync(recursive: true);
  });

  test('a valid code pairs the device and pins the server certificate', () async {
    final secrets = MemorySecretStore();
    final repo = ServerRepository(secrets);
    final issued = await server.pairingCode();

    final pairing = await repo.pair(address: server.address, code: issued.code, deviceName: 'Téléphone');
    expect(pairing.fingerprint, issued.fingerprint, reason: 'the app pins what the server administrator sees');
    expect(secrets.values.keys, [pairingSecretKey], reason: 'key and fingerprint are kept in the secret store');

    final stored = (await ServerRepository(secrets).pairing())!;
    expect(stored.deviceKey, pairing.deviceKey);
    final status = await repo.status(stored);
    expect(status.version, 'v0.1.0-e2e');
    expect(status.appCompatible, isTrue);
    expect(status.devices.single.name, 'Téléphone');
    expect(status.devices.single.current, isTrue);
  });

  test('an expired, already used or wrong code is refused', () async {
    final secrets = MemorySecretStore();
    final repo = ServerRepository(secrets);

    final used = await server.pairingCode();
    await ServerRepository(MemorySecretStore()).pair(address: server.address, code: used.code, deviceName: 'First');
    await expectLater(
      repo.pair(address: server.address, code: used.code, deviceName: 'Second'),
      throwsA(serverError('PAIRING_CODE_USED')),
    );

    await expectLater(
      repo.pair(address: server.address, code: 'ZZZZ-ZZZZ', deviceName: 'Second'),
      throwsA(serverError('PAIRING_CODE_INVALID')),
    );

    final short = await server.pairingCode(ttl: '1s');
    await Future<void>.delayed(const Duration(milliseconds: 1200));
    await expectLater(
      repo.pair(address: server.address, code: short.code, deviceName: 'Second'),
      throwsA(serverError('PAIRING_CODE_EXPIRED')),
    );

    expect(secrets.values, isEmpty, reason: 'nothing is kept after a refused pairing');
  });

  test('a request without a key is refused', () async {
    final fingerprint = (await server.pairingCode()).fingerprint;
    final client = ServerClient(server.address, pin: fingerprint);
    addTearDown(client.close);
    await expectLater(client.devices(), throwsA(serverError('DEVICE_KEY_MISSING')));
    await expectLater(
      ServerClient(server.address, pin: fingerprint, deviceKey: 'forged').devices(),
      throwsA(serverError('DEVICE_KEY_INVALID')),
    );
  });

  test('a device revoked from another one is refused', () async {
    final phone = ServerRepository(MemorySecretStore());
    final laptop = ServerRepository(MemorySecretStore());
    final phonePairing = await phone.pair(
      address: server.address,
      code: (await server.pairingCode()).code,
      deviceName: 'Phone',
    );
    final laptopPairing = await laptop.pair(
      address: server.address,
      code: (await server.pairingCode()).code,
      deviceName: 'Laptop',
    );

    await laptop.revoke(laptopPairing, phonePairing.deviceId);
    await expectLater(phone.status(phonePairing), throwsA(serverError('DEVICE_REVOKED')));

    final devices = (await laptop.status(laptopPairing)).devices;
    expect(devices.firstWhere((d) => d.id == phonePairing.deviceId).revoked, isTrue);
  });

  test('unpairing revokes this device and forgets the pairing', () async {
    final secrets = MemorySecretStore();
    final repo = ServerRepository(secrets);
    final pairing = await repo.pair(
      address: server.address,
      code: (await server.pairingCode()).code,
      deviceName: 'Laptop',
    );
    await repo.unpair(pairing);
    expect(await repo.pairing(), isNull);
    await expectLater(repo.status(pairing), throwsA(serverError('DEVICE_REVOKED')));
  });

  test('a server presenting another certificate is refused', () async {
    final repo = ServerRepository(MemorySecretStore());
    final pairing = await repo.pair(
      address: server.address,
      code: (await server.pairingCode()).code,
      deviceName: 'Phone',
    );

    // Same software, same API, its own certificate: e.g. another machine that
    // took over the server's IP address.
    final impostor = await LocalServer.start();
    addTearDown(() async {
      await impostor.stop();
      impostor.dataDir.deleteSync(recursive: true);
    });
    final moved = await repo.changeAddress(pairing, impostor.address);
    await expectLater(repo.status(moved), throwsA(isA<CertificateMismatchException>()));
    await expectLater(repo.revoke(moved, 'anything'), throwsA(isA<CertificateMismatchException>()));

    // The genuine server is still accepted.
    final back = await repo.changeAddress(moved, server.address);
    expect((await repo.status(back)).devices, hasLength(1));
  });

  test('a server whose certificate was replaced is refused', () async {
    final repo = ServerRepository(MemorySecretStore());
    final pairing = await repo.pair(
      address: server.address,
      code: (await server.pairingCode()).code,
      deviceName: 'Phone',
    );
    await server.stop();
    Directory('${server.dataDir.path}/tls').deleteSync(recursive: true);
    server = await LocalServer.start(dataDir: server.dataDir);
    final moved = await repo.changeAddress(pairing, server.address);
    await expectLater(repo.status(moved), throwsA(isA<CertificateMismatchException>()));
  });

  test('the server screen logic: pairing, status, then a refused code', () async {
    final cubit = ServerCubit(ServerRepository(MemorySecretStore()));
    addTearDown(cubit.close);
    await cubit.load();
    expect(cubit.state.paired, isFalse);

    await cubit.pair(address: '127.0.0.1:${server.port}', code: 'ZZZZ-ZZZZ', deviceName: 'Phone');
    expect(cubit.state.problem, ServerProblem.codeInvalid);
    expect(cubit.state.paired, isFalse);

    await cubit.pair(address: 'not an address/', code: 'x', deviceName: 'Phone');
    expect(cubit.state.problem, ServerProblem.invalidAddress);

    final code = (await server.pairingCode()).code;
    await cubit.pair(address: '127.0.0.1:${server.port}', code: code.toLowerCase(), deviceName: 'Phone');
    expect(cubit.state.paired, isTrue);
    expect(cubit.state.problem, isNull);
    expect(cubit.state.status!.devices.single.current, isTrue);

    await server.stop();
    await cubit.refresh();
    expect(cubit.state.problem, ServerProblem.unreachable);
    expect(cubit.state.paired, isTrue, reason: 'an unreachable server does not unpair');
    server = await LocalServer.start(dataDir: server.dataDir);
  });
}
