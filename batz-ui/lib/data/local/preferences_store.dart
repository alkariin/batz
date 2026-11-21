import '../../domain/views/year_view.dart';
import 'database.dart';

const _viewKindKey = 'year_view_kind';

/// Choices made on this device that are neither data nor synchronised: they
/// live in the local state of the database.
class PreferencesStore {
  PreferencesStore(this._db);

  final LocalDatabase _db;

  /// The view the « Année » screen opens on: the economic view the first
  /// time, then the last one chosen on this device (decision H7).
  Future<ViewKind> viewKind() async {
    final row = await (_db.select(_db.localState)..where((s) => s.key.equals(_viewKindKey))).getSingleOrNull();
    return ViewKind.values.where((k) => k.name == row?.value).firstOrNull ?? ViewKind.economic;
  }

  Future<void> setViewKind(ViewKind kind) =>
      _db.into(_db.localState).insertOnConflictUpdate(LocalStateCompanion.insert(key: _viewKindKey, value: kind.name));
}
