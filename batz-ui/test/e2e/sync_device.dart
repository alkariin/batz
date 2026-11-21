import 'package:batz/data/local/derived_tables.dart';
import 'package:batz/data/secret_store.dart';
import 'package:batz/data/server/server_client.dart';
import 'package:batz/data/server/server_repository.dart';
import 'package:batz/data/sync/sync_engine.dart';
import 'package:batz/data/sync/sync_protocol.dart';
import 'package:batz/data/sync/sync_store.dart';

import '../support/ledger_harness.dart';
import 'server_harness.dart';

/// A simulated device: the app's real database, journal and ledger in
/// memory, its own secret store, and the sync engine, paired with a real
/// server.
class SimDevice {
  SimDevice._(this.name, this.ledger, this.engine, this.store);

  static Future<SimDevice> create(
    String name, {
    String? deviceId,
    int Function()? now,
    int pageSize = 500,
    int requestedPageSize = 1000,
  }) async {
    final ledger = await LedgerHarness.open(deviceId: deviceId, now: now);
    final store = SyncStore(ledger.db);
    return SimDevice._(
      name,
      ledger,
      SyncEngine(ledger.journal, store, pageSize: pageSize, requestedPageSize: requestedPageSize),
      store,
    );
  }

  final String name;
  final LedgerHarness ledger;
  final SyncEngine engine;
  final SyncStore store;
  final secrets = MemorySecretStore();
  late final server = ServerRepository(secrets);
  Pairing? pairing;

  Future<void> pair(LocalServer s) async {
    pairing = await server.pair(address: s.address, code: (await s.pairingCode()).code, deviceName: name);
  }

  /// One exchange to its end; [wrap] can put a transport in between.
  Future<SyncReport> sync({SyncTransport Function(SyncTransport client)? wrap, bool merge = false}) =>
      _with((t, id) => engine.run(wrap == null ? t : wrap(t), pairingId: id, merge: merge));

  /// Replaces the data of this device by the server's.
  Future<SyncReport> replace() => _with((t, id) => engine.replace(t, pairingId: id));

  Future<SyncReport> _with(Future<SyncReport> Function(SyncTransport transport, String pairingId) action) async {
    final p = pairing!;
    final client = ServerClient(p.address, pin: p.fingerprint, deviceKey: p.deviceKey);
    try {
      return await action(client, p.deviceId);
    } finally {
      client.close();
    }
  }

  /// Every derived row, deleted ones included, every journal entry and every
  /// field version: two devices that converged hold the same.
  Future<Map<String, Object>> state() async => {
    ...await ledger.tables([for (final t in appDerivedTables) t.table]),
    'journal': [for (final e in await ledger.journal.entries()) '${e.hlc} ${e.change}'],
    'field_versions': [
      for (final row
          in await ledger.db.customSelect('SELECT * FROM field_versions ORDER BY entity, record_id, field').get())
        row.data,
    ],
  };

  Future<void> close() => ledger.close();
}

/// Lets the [failAt]th call fail as if the network was cut: before the
/// request reaches the server, or, with [afterServer], once the server has
/// integrated it but before the answer arrives.
class CutTransport implements SyncTransport {
  CutTransport(this._inner, {required this.failAt, this.afterServer = false});

  final SyncTransport _inner;
  final int failAt;
  final bool afterServer;
  var calls = 0;

  @override
  Future<Health> health() => _inner.health();

  @override
  Future<SyncResponse> exchange(SyncRequest request) async {
    if (++calls == failAt) {
      if (afterServer) await _inner.exchange(request);
      throw ServerUnreachableException('cut');
    }
    return _inner.exchange(request);
  }
}
