import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../data/local/journal.dart';
import '../../data/server/server_client.dart';
import '../../data/server/server_repository.dart';
import '../../data/sync/sync_engine.dart';
import '../../data/sync/sync_store.dart';
import '../../domain/journal/known_state.dart';

/// Where the synchronisation stands, as the home and server screens show it.
enum SyncStatus {
  /// No server is paired: the data stay on this device.
  notPaired,

  /// Paired, but no exchange has gone to its end yet.
  neverSynced,

  /// An exchange is in progress.
  syncing,

  /// The last exchange went to its end.
  upToDate,

  /// The server could not be reached: no error message (decision H2).
  offline,

  /// The server revoked this device: exchanges stop (decision H6).
  revoked,

  /// This app and the server cannot exchange; see [SyncState.incompatibility].
  incompatible,

  /// First exchange: the device and the server hold unrelated data; the user
  /// chooses to merge them or to replace the device's (decision H1).
  decisionNeeded,

  /// Anything else; see [SyncState.error].
  error,
}

class SyncState extends Equatable {
  const SyncState({
    this.status = SyncStatus.notPaired,
    this.lastSync,
    this.pending = 0,
    this.incompatibility,
    this.serverVersion,
    this.minAppVersion,
    this.clockOffset,
    this.error,
  });

  /// Beyond this, the clock of the device is reported as wrong (decision H5).
  static const clockTolerance = Duration(minutes: 5);

  final SyncStatus status;

  /// The end of the last exchange that went to its end.
  final DateTime? lastSync;

  /// Modifications this device holds that the server did not have at the last
  /// exchange.
  final int pending;

  final Incompatibility? incompatibility;
  final String? serverVersion;
  final String? minAppVersion;

  /// The server's clock minus this device's, at the last exchange.
  final Duration? clockOffset;

  /// What went wrong, for the error status.
  final String? error;

  bool get clockWarning => clockOffset != null && clockOffset!.abs() > clockTolerance;

  SyncState copyWith({SyncStatus? status, int? pending}) => SyncState(
    status: status ?? this.status,
    lastSync: lastSync,
    pending: pending ?? this.pending,
    incompatibility: incompatibility,
    serverVersion: serverVersion,
    minAppVersion: minAppVersion,
    clockOffset: clockOffset,
    error: error,
  );

  @override
  List<Object?> get props => [
    status,
    lastSync,
    pending,
    incompatibility,
    serverVersion,
    minAppVersion,
    clockOffset,
    error,
  ];
}

/// The transport to the paired server; [ServerClient] in the app.
typedef TransportFactory = SyncTransport Function(Pairing pairing);

/// Runs the synchronisation (decision H2): at start, when the app comes back
/// to the foreground, a few seconds after a modification, every five minutes
/// while the app is shown, and on demand. One exchange at a time.
class SyncCubit extends Cubit<SyncState> {
  SyncCubit({
    required this._server,
    required this._journal,
    required this._engine,
    required this._store,
    TransportFactory? transport,
    this._onReceived,
    this.debounce = const Duration(seconds: 3),
    this.period = const Duration(minutes: 5),
  }) : _transport = transport ?? _client,
       super(const SyncState());

  static SyncTransport _client(Pairing p) => ServerClient(p.address, pin: p.fingerprint, deviceKey: p.deviceKey);

  final ServerRepository _server;
  final Journal _journal;
  final SyncEngine _engine;
  final SyncStore _store;
  final TransportFactory _transport;

  /// Reloads the screens after an exchange that received entries.
  final Future<void> Function()? _onReceived;

  /// Delay between a modification and the exchange that sends it.
  final Duration debounce;

  /// Interval of the exchanges while the app is shown.
  final Duration period;

  /// Statuses in which automatic exchanges stop until the user acts.
  static const _stopped = {SyncStatus.revoked, SyncStatus.incompatible, SyncStatus.decisionNeeded};

  Future<void>? _running;
  var _again = false;
  Timer? _debounceTimer;
  Timer? _periodic;
  StreamSubscription<void>? _writes;

  /// At start: shows what is known without the server, then exchanges.
  Future<void> start() async {
    _writes ??= _journal.localWrites.listen((_) => localChanged());
    await _show();
    _startPeriodic();
    await sync();
  }

  /// Runs an exchange, unless one is in progress, in which case another one
  /// follows it. Automatic exchanges ([manual] false) are skipped while the
  /// device is revoked or incompatible.
  Future<void> sync({bool manual = false}) {
    if (_running case final running?) {
      _again = true;
      return running;
    }
    final run = _run(manual: manual).whenComplete(() {
      _running = null;
      if (_again && !isClosed) {
        _again = false;
        unawaited(sync());
      }
    });
    return _running = run;
  }

  /// The answer to the question of the first exchange: merge the data of
  /// the device with the server's.
  Future<void> merge() => _exclusive(() => _run(manual: true, merge: true));

  /// Replaces the data of this device by the server's (decision H1), after
  /// the user confirmed: the modifications not sent yet are lost.
  Future<void> replace() => _exclusive(() => _run(manual: true, replace: true));

  Future<void> _exclusive(Future<void> Function() action) async {
    // After the exchange in progress, and the one it may schedule.
    for (var running = _running; running != null; running = _running) {
      await running;
    }
    final run = action().whenComplete(() => _running = null);
    _running = run;
    return run;
  }

  /// A modification was written on this device.
  Future<void> localChanged() async {
    await _updatePending();
    _debounceTimer?.cancel();
    _debounceTimer = Timer(debounce, () => unawaited(sync()));
  }

  /// The app came back to the foreground.
  Future<void> resumed() {
    _startPeriodic();
    return sync();
  }

  /// The app left the foreground: no periodic exchange until it comes back.
  void paused() {
    _periodic?.cancel();
    _periodic = null;
  }

  /// The pairing was created or forgotten: starts afresh.
  Future<void> pairingChanged() async {
    await _show(reset: true);
    await sync(manual: true);
  }

  void _startPeriodic() {
    _periodic?.cancel();
    _periodic = Timer.periodic(period, (_) => unawaited(sync()));
  }

  /// Shows the status known without the server.
  Future<void> _show({bool reset = false}) async {
    final pairing = await _server.pairing();
    if (isClosed) return;
    if (pairing == null) {
      emit(const SyncState());
      return;
    }
    final memory = await _store.read(pairing.deviceId);
    final pending = await _journal.pendingFor(memory?.known ?? KnownState.empty);
    if (isClosed) return;
    final keep = !reset && state.status != SyncStatus.notPaired;
    emit(
      keep
          ? state.copyWith(pending: pending)
          : SyncState(
              status: memory?.lastSuccess == null ? SyncStatus.neverSynced : SyncStatus.upToDate,
              lastSync: memory?.lastSuccess,
              pending: pending,
            ),
    );
  }

  Future<void> _updatePending() async {
    final pairing = await _server.pairing();
    if (pairing == null || isClosed) return;
    final memory = await _store.read(pairing.deviceId);
    final pending = await _journal.pendingFor(memory?.known ?? KnownState.empty);
    if (!isClosed) emit(state.copyWith(pending: pending));
  }

  Future<void> _run({required bool manual, bool merge = false, bool replace = false}) async {
    final pairing = await _server.pairing();
    if (isClosed) return;
    if (pairing == null) {
      emit(const SyncState());
      return;
    }
    if (!manual && _stopped.contains(state.status)) return;
    emit(state.copyWith(status: SyncStatus.syncing));
    final transport = _transport(pairing);
    try {
      final report = replace
          ? await _engine.replace(transport, pairingId: pairing.deviceId)
          : await _engine.run(transport, pairingId: pairing.deviceId, merge: merge);
      final memory = await _store.read(pairing.deviceId);
      final pending = await _journal.pendingFor(memory?.known ?? KnownState.empty);
      if (isClosed) return;
      emit(
        SyncState(
          status: SyncStatus.upToDate,
          lastSync: memory?.lastSuccess,
          pending: pending,
          clockOffset: report.clockOffset,
        ),
      );
      if (report.receivedEntries > 0 || report.replaced) await _onReceived?.call();
    } catch (error) {
      final memory = await _store.read(pairing.deviceId);
      final pending = await _journal.pendingFor(memory?.known ?? KnownState.empty);
      if (isClosed) return;
      emit(_failed(error, lastSync: memory?.lastSuccess, pending: pending));
    } finally {
      if (transport case final ServerClient client) client.close();
    }
  }

  SyncState _failed(Object error, {required DateTime? lastSync, required int pending}) {
    SyncState status(SyncStatus s, {String? detail}) =>
        SyncState(status: s, lastSync: lastSync, pending: pending, clockOffset: state.clockOffset, error: detail);
    return switch (error) {
      ServerUnreachableException() => status(SyncStatus.offline),
      ServerException(code: 'DEVICE_REVOKED') => status(SyncStatus.revoked),
      UnrelatedDataException() => status(SyncStatus.decisionNeeded),
      SyncIncompatibleException(:final reason, :final serverVersion, :final minAppVersion) => SyncState(
        status: SyncStatus.incompatible,
        lastSync: lastSync,
        pending: pending,
        clockOffset: state.clockOffset,
        incompatibility: reason,
        serverVersion: serverVersion,
        minAppVersion: minAppVersion,
      ),
      _ => status(SyncStatus.error, detail: '$error'),
    };
  }

  @override
  Future<void> close() async {
    _debounceTimer?.cancel();
    _periodic?.cancel();
    await _writes?.cancel();
    return super.close();
  }
}
