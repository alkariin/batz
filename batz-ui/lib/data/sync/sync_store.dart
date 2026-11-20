import 'dart:convert';

import '../../domain/journal/known_state.dart';
import '../local/database.dart';

const _key = 'sync_server';

/// What this device remembers of the server it is paired with: its last known
/// state, to count the modifications waiting to be sent, and the date of the
/// last exchange that went to its end.
class ServerMemory {
  ServerMemory({required this.pairingId, required this.known, this.lastSuccess});

  /// The identifier the server gave this device at pairing: a memory of
  /// another pairing is ignored.
  final String pairingId;
  final KnownState known;
  final DateTime? lastSuccess;
}

/// Keeps the [ServerMemory] in the local state of the database, never
/// synchronised.
class SyncStore {
  SyncStore(this._db);

  final LocalDatabase _db;

  /// The memory of the pairing [pairingId], or null if there is none.
  Future<ServerMemory?> read(String pairingId) async {
    final row = await (_db.select(_db.localState)..where((s) => s.key.equals(_key))).getSingleOrNull();
    if (row == null) return null;
    final json = jsonDecode(row.value) as Map<String, Object?>;
    if (json['pairingId'] != pairingId) return null;
    final last = json['lastSuccess'] as int?;
    return ServerMemory(
      pairingId: pairingId,
      known: KnownState.fromJson(json['known']! as Map<String, Object?>),
      lastSuccess: last == null ? null : DateTime.fromMillisecondsSinceEpoch(last, isUtc: true),
    );
  }

  /// Records the server state seen during an exchange; [at] is set when the
  /// exchange went to its end.
  Future<void> save(String pairingId, KnownState known, {DateTime? at}) async {
    final previous = at ?? (await read(pairingId))?.lastSuccess;
    final value = jsonEncode({
      'pairingId': pairingId,
      'known': known.toJson(),
      'lastSuccess': previous?.toUtc().millisecondsSinceEpoch,
    });
    await _db.into(_db.localState).insertOnConflictUpdate(LocalStateCompanion.insert(key: _key, value: value));
  }

  Future<void> clear() => (_db.delete(_db.localState)..where((s) => s.key.equals(_key))).go();
}
