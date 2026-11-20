import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../data/server/certificate.dart';
import '../../data/server/server_client.dart';
import '../../data/server/server_repository.dart';

/// Why the last server action failed, in terms the screen can explain.
enum ServerProblem {
  invalidAddress,
  unreachable,
  certificateMismatch,
  codeInvalid,
  codeExpired,
  codeUsed,
  nameInvalid,
  deviceRevoked,
  other,
}

ServerProblem problemOf(Object error) => switch (error) {
  CertificateMismatchException() => ServerProblem.certificateMismatch,
  ServerUnreachableException() => ServerProblem.unreachable,
  ServerException(code: 'PAIRING_CODE_INVALID') => ServerProblem.codeInvalid,
  ServerException(code: 'PAIRING_CODE_EXPIRED') => ServerProblem.codeExpired,
  ServerException(code: 'PAIRING_CODE_USED') => ServerProblem.codeUsed,
  ServerException(code: 'DEVICE_NAME_INVALID') => ServerProblem.nameInvalid,
  ServerException(code: 'DEVICE_REVOKED') => ServerProblem.deviceRevoked,
  _ => ServerProblem.other,
};

class ServerState extends Equatable {
  const ServerState({this.loading = true, this.busy = false, this.pairing, this.status, this.problem});

  /// Reading the stored pairing.
  final bool loading;

  /// An action is in progress.
  final bool busy;
  final Pairing? pairing;

  /// Last status fetched from the server; null if not fetched or failed.
  final ServerStatus? status;
  final ServerProblem? problem;

  bool get paired => pairing != null;

  ServerState copyWith({bool? loading, bool? busy, Pairing? pairing, ServerStatus? status, ServerProblem? problem}) =>
      ServerState(
        loading: loading ?? this.loading,
        busy: busy ?? this.busy,
        pairing: pairing ?? this.pairing,
        status: status ?? this.status,
        problem: problem,
      );

  @override
  List<Object?> get props => [loading, busy, pairing?.deviceId, pairing?.address, status, problem];
}

class ServerCubit extends Cubit<ServerState> {
  ServerCubit(this._repository) : super(const ServerState());

  final ServerRepository _repository;

  Future<void> load() async {
    final pairing = await _repository.pairing();
    emit(ServerState(loading: false, pairing: pairing));
    if (pairing != null) await refresh();
  }

  Future<void> refresh() async {
    final pairing = state.pairing;
    if (pairing == null) return;
    emit(state.copyWith(busy: true));
    try {
      final status = await _repository.status(pairing);
      emit(ServerState(loading: false, pairing: pairing, status: status));
    } catch (e) {
      emit(ServerState(loading: false, pairing: pairing, problem: problemOf(e)));
    }
  }

  Future<void> pair({required String address, required String code, required String deviceName}) async {
    final uri = parseServerAddress(address);
    if (uri == null) {
      emit(state.copyWith(problem: ServerProblem.invalidAddress));
      return;
    }
    emit(state.copyWith(busy: true));
    try {
      final pairing = await _repository.pair(address: uri, code: code, deviceName: deviceName);
      emit(ServerState(loading: false, pairing: pairing));
      await refresh();
    } catch (e) {
      emit(const ServerState(loading: false).copyWith(problem: problemOf(e)));
    }
  }

  Future<void> revoke(String deviceId) async {
    final pairing = state.pairing;
    if (pairing == null) return;
    emit(state.copyWith(busy: true, status: state.status));
    try {
      await _repository.revoke(pairing, deviceId);
      await refresh();
    } catch (e) {
      emit(state.copyWith(busy: false, problem: problemOf(e)));
    }
  }

  /// Revokes this device on the server and forgets the pairing.
  Future<void> unpair() async {
    final pairing = state.pairing;
    if (pairing == null) return;
    emit(state.copyWith(busy: true, status: state.status));
    try {
      await _repository.unpair(pairing);
      emit(const ServerState(loading: false));
    } catch (e) {
      emit(state.copyWith(busy: false, problem: problemOf(e)));
    }
  }

  /// Forgets the pairing on this device only.
  Future<void> forget() async {
    await _repository.forget();
    emit(const ServerState(loading: false));
  }
}
