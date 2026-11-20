import '../../domain/journal/known_state.dart';
import '../../version.dart';
import '../local/journal.dart';
import '../server/server_client.dart';
import 'sync_protocol.dart';
import 'sync_store.dart';

/// How the engine reaches the server; [ServerClient] in the app.
abstract interface class SyncTransport {
  Future<SyncResponse> exchange(SyncRequest request);
}

/// What an exchange did.
class SyncReport {
  SyncReport({
    required this.sentEntries,
    required this.receivedEntries,
    required this.calls,
    required this.serverTime,
    required this.clockOffset,
  });

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
  /// throws (server unreachable, refused, ...) or [SyncProtocolException];
  /// whatever was integrated before stays.
  Future<SyncReport> run(SyncTransport transport, {required String pairingId}) async {
    KnownState? server;
    var more = true;
    var sent = 0, received = 0, calls = 0, restarts = 0;
    late DateTime serverTime;
    late Duration offset;
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
        response = await transport.exchange(
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
      final ended = _now();
      serverTime = response.serverTime;
      offset = response.serverTime.difference(started.add(ended.difference(started) ~/ 2));
      if (response.page.isEmpty && response.page.more) {
        throw SyncProtocolException('the server announced more entries but sent none');
      }

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
      serverTime: serverTime,
      clockOffset: offset,
    );
  }
}
