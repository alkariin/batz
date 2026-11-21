import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../data/server/certificate.dart';
import '../../data/server/import_protocol.dart';
import '../../data/server/server_client.dart';
import '../../data/server/server_repository.dart';
import '../../domain/ledger/ledger.dart';
import '../../domain/ledger/ledger_exception.dart';
import '../../domain/ledger/statement.dart';
import '../ledger_cubit.dart';
import '../sync/sync_cubit.dart';

/// Where the import of a statement stands.
enum ImportStep {
  /// The synchronisation that opens the import is running.
  syncing,

  /// The import cannot start: see [ImportState.syncStatus].
  notReady,

  /// Synchronised: the user picks the account and the file.
  ready,

  /// The file is with the server.
  sending,

  /// The statement is refused: see [ImportState.refusal].
  refused,

  /// The first statement of the account: the user confirms it (H7).
  confirmFirst,

  /// The statement is imported: see [ImportState.result].
  done,
}

/// Why a statement was refused: by the server (its code and check), by the
/// app (a [LedgerException]), or because the server could not be used.
class ImportRefusal extends Equatable {
  const ImportRefusal.server(this.code, {this.check, this.message = ''}) : ledger = null, serverVersion = null;
  const ImportRefusal.ledger(LedgerException this.ledger)
    : code = null,
      check = null,
      message = '',
      serverVersion = null;
  const ImportRefusal.serverTooOld(String this.serverVersion) : code = null, check = null, message = '', ledger = null;
  const ImportRefusal.unreachable() : code = null, check = null, message = '', ledger = null, serverVersion = null;

  final String? code;
  final String? check;
  final String message;
  final LedgerException? ledger;
  final String? serverVersion;

  @override
  List<Object?> get props => [code, check, message, ledger, serverVersion];
}

/// What an import gave.
class ImportResult extends Equatable {
  const ImportResult({required this.statement, required this.lines, required this.proposed, required this.toComplete});

  final Statement statement;
  final int lines;
  final int proposed;
  final int toComplete;

  @override
  List<Object?> get props => [statement, lines, proposed, toComplete];
}

class ImportState extends Equatable {
  const ImportState(this.step, {this.syncStatus, this.refusal, this.pending, this.result});

  final ImportStep step;
  final SyncStatus? syncStatus;
  final ImportRefusal? refusal;

  /// For [ImportStep.confirmFirst]: what the server read.
  final PendingImport? pending;
  final ImportResult? result;

  @override
  List<Object?> get props => [step, syncStatus, refusal, pending, result];
}

/// A statement read by the server, waiting for the user's confirmation.
class PendingImport extends Equatable {
  const PendingImport(this.accountId, this.response);

  final String accountId;
  final ImportResponse response;

  @override
  List<Object?> get props => [accountId, response.fingerprint];
}

/// The transport to the paired server for the import; [ServerClient] in the
/// app.
typedef ImportTransportFactory = ImportTransport Function(Pairing pairing);

/// The import of a statement (step 3.5): it starts with a synchronisation;
/// the server reads and checks the file; the app checks the continuity from
/// its journal (H1) and writes the statement and its lines in one
/// modification, after a confirmation for the first statement of an account
/// (H7).
class ImportCubit extends Cubit<ImportState> {
  ImportCubit({required this._sync, required this._ledger, required this._server, ImportTransportFactory? transport})
    : _transport = transport ?? _client,
      super(const ImportState(ImportStep.syncing));

  static ImportTransport _client(Pairing p) => ServerClient(p.address, pin: p.fingerprint, deviceKey: p.deviceKey);

  final SyncCubit _sync;
  final LedgerCubit _ledger;
  final ServerRepository _server;
  final ImportTransportFactory _transport;

  /// Synchronises first: without a server reached and an exchange gone to
  /// its end, the import does not start, and says why.
  Future<void> start() async {
    emit(const ImportState(ImportStep.syncing));
    await _sync.whenIdle();
    await _sync.sync(manual: true);
    await _sync.whenIdle();
    if (isClosed) return;
    final status = _sync.state.status;
    emit(
      status == SyncStatus.upToDate
          ? const ImportState(ImportStep.ready)
          : ImportState(ImportStep.notReady, syncStatus: status),
    );
  }

  /// Sends [pdf] for the account [accountId], checks it and imports it, or
  /// asks to confirm the first statement of the account.
  Future<void> importFile(String accountId, Uint8List pdf) async {
    // Already imported? The journal says so without asking the server (H1).
    final fingerprint = sha256.convert(pdf).toString();
    if (_ledger.state.ledger.statements.containsKey(statementId(accountId, fingerprint))) {
      emit(
        const ImportState(
          ImportStep.refused,
          refusal: ImportRefusal.ledger(StatementRefusedException(LedgerError.statementAlreadyImported)),
        ),
      );
      return;
    }
    final account = _ledger.state.ledger.accounts[accountId];
    final pairing = await _server.pairing();
    if (pairing == null || account?.importFormat == null) {
      emit(const ImportState(ImportStep.notReady, syncStatus: SyncStatus.notPaired));
      return;
    }
    emit(const ImportState(ImportStep.sending));
    final transport = _transport(pairing);
    final ImportResponse response;
    try {
      final health = await transport.health();
      if (!(health.importFormats?.contains(account!.importFormat!.name) ?? false)) {
        emit(ImportState(ImportStep.refused, refusal: ImportRefusal.serverTooOld(health.version)));
        return;
      }
      response = await transport.importStatement(pdf);
    } on ServerException catch (e) {
      emit(
        ImportState(
          ImportStep.refused,
          refusal: ImportRefusal.server(e.code, check: e.check, message: e.message),
        ),
      );
      return;
    } on ServerUnreachableException {
      emit(const ImportState(ImportStep.refused, refusal: ImportRefusal.unreachable()));
      return;
    } on CertificateMismatchException {
      emit(const ImportState(ImportStep.notReady, syncStatus: SyncStatus.serverChanged));
      return;
    } finally {
      if (transport case final ServerClient client) client.close();
    }
    await _integrate(PendingImport(accountId, response), confirmed: false);
  }

  /// The user confirmed the first statement of the account (H7).
  Future<void> confirmFirst() async {
    final pending = state.pending;
    if (state.step != ImportStep.confirmFirst || pending == null) return;
    await _integrate(pending, confirmed: true);
  }

  /// Back to the choice of a file, after a refusal or an import.
  void again() => emit(const ImportState(ImportStep.ready));

  Future<void> _integrate(PendingImport pending, {required bool confirmed}) async {
    // Checked against the ledger as it is now: it may have changed while the
    // server was reading, or while the user was deciding.
    final StatementImport import;
    try {
      import = _ledger.state.ledger.importStatement(
        pending.accountId,
        pending.response.statement,
        fingerprint: pending.response.fingerprint,
      );
    } on LedgerException catch (e) {
      emit(ImportState(ImportStep.refused, refusal: ImportRefusal.ledger(e)));
      return;
    }
    if (import.first && !confirmed) {
      emit(ImportState(ImportStep.confirmFirst, pending: pending));
      return;
    }
    await _ledger.write(import.modification);
    final ledger = _ledger.state.ledger;
    final lines = ledger.linesOf(import.statementId);
    if (isClosed) return;
    emit(
      ImportState(
        ImportStep.done,
        result: ImportResult(
          statement: ledger.statements[import.statementId]!,
          lines: lines.length,
          proposed: lines.where((t) => ledger.validationStateOf(t) == ValidationState.proposed).length,
          toComplete: lines.where((t) => ledger.validationStateOf(t) == ValidationState.toComplete).length,
        ),
      ),
    );
  }
}
