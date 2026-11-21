import 'package:batz/data/local/journal.dart';
import 'package:batz/data/server/server_client.dart';
import 'package:batz/data/sync/sync_engine.dart';
import 'package:batz/data/sync/sync_protocol.dart';

/// A server in memory, following the protocol with a journal of its own.
class FakeServer implements SyncTransport {
  FakeServer(this.journal, {this.clock});

  final Journal journal;
  final DateTime Function()? clock;
  final requests = <SyncRequest>[];

  /// What `/healthz` answers.
  Health healthAnswer = Health(version: 'v0.4.0', minAppVersion: '0.1.0', syncProtocol: syncProtocol);

  /// Delays each answer, to observe an exchange in progress.
  Duration delay = Duration.zero;

  var healthCalls = 0;
  var _active = 0;

  /// The most exchanges in progress at the same time.
  var maxActive = 0;

  /// While true, the server cannot be reached.
  var unreachable = false;

  @override
  Future<Health> health() async {
    healthCalls++;
    if (unreachable) throw ServerUnreachableException('off');
    if (failNext case final error?) {
      failNext = null;
      throw error;
    }
    return healthAnswer;
  }

  /// Alters each answer.
  SyncResponse Function(SyncResponse)? alter;

  /// Runs after each answer is computed.
  Future<void> Function()? restore;
  Object? failNext;
  var conflicts = 0;

  @override
  Future<SyncResponse> exchange(SyncRequest request) async {
    requests.add(request);
    maxActive = (++_active) > maxActive ? _active : maxActive;
    try {
      return await _answer(request);
    } finally {
      _active--;
    }
  }

  Future<SyncResponse> _answer(SyncRequest request) async {
    if (delay > Duration.zero) await Future<void>.delayed(delay);
    if (failNext case final error?) {
      failNext = null;
      throw error;
    }
    final int added;
    try {
      added = await journal.integrate(request.page);
    } on JournalGapException {
      conflicts++;
      throw ServerException(409, 'SYNC_STATE_CHANGED', 'state changed');
    }
    final response = SyncResponse(
      serverTime: (clock ?? DateTime.now)(),
      known: await journal.knownState(),
      page: await journal.missingFrom(request.known, limit: request.limit ?? 1000),
      added: added,
    );
    await restore?.call();
    return alter == null ? response : alter!(response);
  }
}
