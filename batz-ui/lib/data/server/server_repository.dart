import 'dart:convert';

import '../../version.dart';
import '../secret_store.dart';
import 'server_client.dart';

/// Secret store key of the pairing.
const pairingSecretKey = 'server_pairing';

/// What this device keeps after pairing, in the system secret store.
class Pairing {
  Pairing({required this.address, required this.deviceId, required this.deviceKey, required this.fingerprint});

  factory Pairing.fromJson(Map<String, dynamic> json) => Pairing(
    address: Uri.parse(json['address'] as String),
    deviceId: json['deviceId'] as String,
    deviceKey: json['deviceKey'] as String,
    fingerprint: json['fingerprint'] as String,
  );

  final Uri address;
  final String deviceId;
  final String deviceKey;

  /// Fingerprint of the server certificate memorised at pairing.
  final String fingerprint;

  Map<String, Object> toJson() => {
    'address': address.toString(),
    'deviceId': deviceId,
    'deviceKey': deviceKey,
    'fingerprint': fingerprint,
  };

  Pairing withAddress(Uri newAddress) =>
      Pairing(address: newAddress, deviceId: deviceId, deviceKey: deviceKey, fingerprint: fingerprint);
}

/// State of the server as seen from this device.
class ServerStatus {
  ServerStatus({required this.version, required this.minAppVersion, required this.devices});

  final String version;
  final String minAppVersion;
  final List<ServerDevice> devices;

  /// False when the server requires a newer app.
  bool get appCompatible => (compareVersions(appVersion, minAppVersion) ?? 0) >= 0;
}

/// Pairs this device with the server and manages the paired devices.
class ServerRepository {
  ServerRepository(this._secrets);

  final SecretStore _secrets;

  Future<Pairing?> pairing() async {
    final raw = await _secrets.read(pairingSecretKey);
    return raw == null ? null : Pairing.fromJson(jsonDecode(raw) as Map<String, dynamic>);
  }

  /// Pairs with the server at [address] using a one-time [code].
  ///
  /// The certificate seen on first contact is pinned at once: the pairing
  /// request itself is only sent to that same certificate, and every later
  /// request refuses any other one.
  Future<Pairing> pair({required Uri address, required String code, required String deviceName}) async {
    String? seen;
    final probe = ServerClient(address, onCertificate: (f) => seen = f);
    try {
      await probe.health();
    } finally {
      probe.close();
    }
    final fingerprint = seen;
    if (fingerprint == null) throw StateError('No certificate seen during pairing');

    final client = ServerClient(address, pin: fingerprint);
    try {
      final result = await client.pair(code: code, name: deviceName);
      final pairing = Pairing(
        address: address,
        deviceId: result.deviceId,
        deviceKey: result.deviceKey,
        fingerprint: fingerprint,
      );
      await _save(pairing);
      return pairing;
    } finally {
      client.close();
    }
  }

  /// Health and device list, through the pinned certificate.
  Future<ServerStatus> status(Pairing pairing) => _with(pairing, (c) async {
    final health = await c.health();
    final devices = await c.devices();
    return ServerStatus(version: health.version, minAppVersion: health.minAppVersion, devices: devices);
  });

  Future<void> revoke(Pairing pairing, String deviceId) => _with(pairing, (c) => c.revoke(deviceId));

  /// Revokes this device on the server, then forgets the pairing.
  Future<void> unpair(Pairing pairing) async {
    await revoke(pairing, pairing.deviceId);
    await forget();
  }

  /// Forgets the pairing on this device only (the server is unreachable, or
  /// already revoked this device).
  Future<void> forget() => _secrets.delete(pairingSecretKey);

  /// Changes the server address (new IP of the same server); the pinned
  /// certificate stays, so another server is still refused.
  Future<Pairing> changeAddress(Pairing pairing, Uri address) async {
    final updated = pairing.withAddress(address);
    await _save(updated);
    return updated;
  }

  Future<void> _save(Pairing pairing) => _secrets.write(pairingSecretKey, jsonEncode(pairing.toJson()));

  Future<T> _with<T>(Pairing pairing, Future<T> Function(ServerClient) action) async {
    final client = ServerClient(pairing.address, pin: pairing.fingerprint, deviceKey: pairing.deviceKey);
    try {
      return await action(client);
    } finally {
      client.close();
    }
  }
}
