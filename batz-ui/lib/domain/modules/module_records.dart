import 'settings.dart';

/// What the user entered in the modules (phase 6), as read from the derived
/// tables: everything else a module shows is computed when its screen opens
/// (principles 2 and 8 of phase 6).
class ModuleRecords {
  ModuleRecords({Iterable<ModuleSetting> settings = const []}) : settings = {for (final s in settings) s.module: s};

  static final empty = ModuleRecords();

  /// The category named for each module, when the user named one.
  final Map<ModuleKind, ModuleSetting> settings;
}
