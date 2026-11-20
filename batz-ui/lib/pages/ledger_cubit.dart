import 'package:flutter_bloc/flutter_bloc.dart';

import '../data/ledger/ledger_repository.dart';
import '../domain/journal/journal_entry.dart';
import '../domain/ledger/ledger.dart';

class LedgerState {
  const LedgerState(this.ledger, {this.loaded = false});

  final Ledger ledger;
  final bool loaded;
}

/// Holds the current [Ledger] for every page. Pages compute a modification
/// from `state.ledger` with the domain rules, which throw a
/// `LedgerException` when they refuse it, then hand it to [write].
class LedgerCubit extends Cubit<LedgerState> {
  LedgerCubit(this._repository) : super(LedgerState(Ledger.empty));

  final LedgerRepository _repository;

  Future<void> load() async => emit(LedgerState(await _repository.load(), loaded: true));

  Future<void> write(Modification modification) async {
    await _repository.write(modification);
    await load();
  }
}
