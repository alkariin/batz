import '../../domain/journal/known_state.dart';
import '../../version.dart';
import '../local/journal.dart';
import '../server/server_client.dart';
import 'sync_protocol.dart';
import 'sync_store.dart';

/// How the engine reaches the server; [ServerClient] in the app.
abstract interface class SyncTransport {
  Future<Health> health();
  Future<SyncResponse> exchange(SyncRequest request);
}

/// Why this app and the server cannot exchange.
enum Incompatibility {
  /// The server requires a newer app.
  appTooOld,

  /// The server predates the exchange protocol of this app.
  serverTooOld,
}

/// The exchange is refused because the versions are incompatible; nothing
/// was exchanged.
class SyncIncompatibleException implements Exception {
  SyncIncompatibleException(this.reason, {required this.serverVersion, required this.minAppVersion});

  final Incompatibility reason;
  final String serverVersion;

  /// The oldest app version the server accepts.
  final String minAppVersion;

  @override
  String toString() => 'SyncIncompatibleException: ${reason.name} (server $serverVersion, app $appVersion)';
}

/// Checks that this app and the server described by [health] can exchange:
/// the server must not require a newer app, and must speak this app's
/// exchange protocol.
void checkCompatibility(Health health) {
  Never refuse(Incompatibility reason) =>
      throw SyncIncompatibleException(reason, serverVersion: health.version, minAppVersion: health.minAppVersion);
  if ((compareVersions(appVersion, health.minAppVersion) ?? 0) < 0) refuse(Incompatibility.appTooOld);
  final protocol = health.syncProtocol;
  if (protocol == null || protocol < syncProtocol) refuse(Incompatibility.serverTooOld);
  if (protocol > syncProtocol) refuse(Incompatibility.appTooOld);
}

/// The first exchange of a device that holds data with a server that holds
/// others, with no origin in common: the user chooses between merging the
/// two and replacing the device's data by the server's (decision H1 of
/// phase 2). Nothing was exchanged.
class UnrelatedDataException implements Exception {
  @override
  String toString() => 'UnrelatedDataException: the device and the server hold unrelated data';
}

/// What an exchange did.
class SyncReport {
  SyncReport({
    required this.sentEntries,
    required this.receivedEntries,
    required this.calls,
    required this.serverTime,
    required this.clockOffset,
    this.replaced = false,
  });

  /// The data of the device were replaced by the server's.
  final bool replaced;

  /// Entries of this device that were new to the server.
  final int sentEntries;

  /// Entries received that were new to this device: when there are any, the
  /// screens reload.
  final int receivedEntries;

  /// Calls made to the server.
  final int calls;

  final DateTime serverTime;

  /// The server's clock minus this device's, measured at the last call.
  final Duration clockOffset;
}

/// Exchanges the journal with the server (batz-web/docs/sync.md).
///
/// One mechanism, with no cursor: each call carries this device's known
/// state and a page of what the server lacks according to the server state
/// received at the previous call; the answer carries the server state and a
/// page of what this device lacks. Every page is integrated in one operation,
/// so an exchange cut at any point resumes at the next one, without loss or
/// duplicate. A new device, an empty server or a server restored from an old
/// copy are ordinary exchanges.
class SyncEngine {
  SyncEngine(
    this._journal,
    this._store, {
    this.pageSize = 500,
    this.maxPageBytes = 4 << 20,
    this.requestedPageSize = 1000,
    DateTime Function()? now,
  }) : _now = now ?? DateTime.now;

  final Journal _journal;
  final SyncStore _store;
  final DateTime Function() _now;

  /// Size of the pages sent, in entries and bytes.
  final int pageSize;
  final int maxPageBytes;

  /// Size of the pages asked from the server.
  final int requestedPageSize;

  /// Calls after which an exchange that never ends is a protocol error.
  static const maxCalls = 100000;

  /// How many times an exchange starts again when the server state changed
  /// under it (`SYNC_STATE_CHANGED`).
  static const maxRestarts = 3;

  /// Runs one exchange to its end with the server reached through
  /// [transport], for the pairing [pairingId]. Throws what the transport
  /// throws (server unreachable, refused, ...), [SyncIncompatibleException]
  /// or [SyncProtocolException]; whatever was integrated before stays.
  ///
  /// When the device and the server both hold data without any origin in
  /// common, it throws [UnrelatedDataException] before exchanging anything,
  /// unless [merge] says to merge them.
  Future<SyncReport> run(SyncTransport transport, {required String pairingId, bool merge = false}) async {
    final health = await transport.health();
    checkCompatibility(health);
    return _exchange(transport, health, pairingId: pairingId, checkRelated: !merge);
  }

  /// Replaces the data of this device by the server's, then exchanges as
  /// usual (decision H1 of phase 2). The device takes a new journal
  /// identifier. Nothing is erased unless the server answered first.
  Future<SyncReport> replace(SyncTransport transport, {required String pairingId}) async {
    final health = await transport.health();
    checkCompatibility(health);
    // Asked as a device that holds nothing: the server sends from scratch.
    final started = _now();
    final response = await _call(
      transport,
      health,
      SyncRequest(appVersion: appVersion, known: KnownState.empty, page: JournalPage.empty, limit: requestedPageSize),
    );
    final received = await _journal.replaceWith(response.page);
    await _store.save(pairingId, response.known);
    final report = await _exchange(
      transport,
      health,
      pairingId: pairingId,
      checkRelated: false,
      from: (response, _offset(response, started, _now())),
    );
    return SyncReport(
      sentEntries: report.sentEntries,
      receivedEntries: received + report.receivedEntries,
      calls: report.calls + 1,
      serverTime: report.serverTime,
      clockOffset: report.clockOffset,
      replaced: true,
    );
  }

  /// The exchange loop. [from] is an answer already integrated, to continue
  /// from.
  Future<SyncReport> _exchange(
    SyncTransport transport,
    Health health, {
    required String pairingId,
    required bool checkRelated,
    (SyncResponse, Duration)? from,
  }) async {
    KnownState? server = from?.$1.known;
    var more = from?.$1.page.more ?? true;
    var sent = 0, received = 0, calls = 0, restarts = 0;
    var serverTime = from?.$1.serverTime;
    var offset = from?.$2;
    while (true) {
      final outgoing = server == null
          ? JournalPage.empty
          : await _journal.missingFrom(server, limit: pageSize, maxBytes: maxPageBytes);
      if (server != null && outgoing.isEmpty && !more) break;
      if (++calls > maxCalls) throw SyncProtocolException('the exchange does not end');

      final known = await _journal.knownState();
      final started = _now();
      final SyncResponse response;
      try {
        response = await _call(
          transport,
          health,
          SyncRequest(appVersion: appVersion, known: known, page: outgoing, limit: requestedPageSize),
        );
      } on ServerException catch (e) {
        if (e.code != 'SYNC_STATE_CHANGED' || ++restarts > maxRestarts) rethrow;
        // The server no longer holds what the page continued from: start
        // again from its current state.
        server = null;
        more = true;
        continue;
      }
      serverTime = response.serverTime;
      offset = _offset(response, started, _now());
      if (response.page.isEmpty && response.page.more) {
        throw SyncProtocolException('the server announced more entries but sent none');
      }
      if (checkRelated && server == null && _unrelated(known, response.known)) throw UnrelatedDataException();

      try {
        received += await _journal.integrate(response.page);
      } on JournalGapException catch (e) {
        throw SyncProtocolException('$e');
      }
      sent += response.added;
      server = response.known;
      more = response.page.more;
      await _store.save(pairingId, server);
    }
    await _store.save(pairingId, server, at: _now());
    return SyncReport(
      sentEntries: sent,
      receivedEntries: received,
      calls: calls,
      serverTime: serverTime!,
      clockOffset: offset!,
    );
  }

  /// Both hold data, and no origin is common to them: they never exchanged.
  static bool _unrelated(KnownState device, KnownState server) =>
      device.latest.isNotEmpty && server.latest.isNotEmpty && device.origins.intersection(server.origins).isEmpty;

  static Duration _offset(SyncResponse response, DateTime started, DateTime ended) =>
      response.serverTime.difference(started.add(ended.difference(started) ~/ 2));

  /// One call; the server's own refusals of incompatible versions become
  /// [SyncIncompatibleException].
  Future<SyncResponse> _call(SyncTransport transport, Health health, SyncRequest request) async {
    try {
      return await transport.exchange(request);
    } on ServerException catch (e) {
      final refused = switch (e.code) {
        'APP_VERSION_UNSUPPORTED' => Incompatibility.appTooOld,
        'SYNC_PROTOCOL_UNSUPPORTED' || 'NOT_FOUND' => Incompatibility.serverTooOld,
        _ => null,
      };
      if (refused == null) rethrow;
      throw SyncIncompatibleException(refused, serverVersion: health.version, minAppVersion: health.minAppVersion);
    }
  }
}
