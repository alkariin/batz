/// The category each module reads: one name per module, the same for every
/// year, looked up in the tree of each year as names are compared between
/// years.
library;

import 'package:equatable/equatable.dart';

import '../ids.dart';
import '../journal/journal_entry.dart';
import '../ledger/category.dart';
import '../ledger/ledger.dart';
import '../ledger/ledger_exception.dart';
import '../views/year_view.dart';

/// The modules linked to a category.
enum ModuleKind { salary, taxes, vacations, electricity }

/// The names used while the user has chosen none.
const defaultModuleCategoryNames = {
  ModuleKind.salary: 'Salaire',
  ModuleKind.taxes: 'Impôts',
  ModuleKind.vacations: 'Vacances',
  ModuleKind.electricity: 'Électricité',
};

/// Journal entity and fields of the setting of a module.
abstract final class ModuleSettingFields {
  static const entity = 'moduleSetting';
  static const module = 'module';
  static const categoryName = 'categoryName';
}

class ModuleSetting extends Equatable {
  const ModuleSetting({required this.id, required this.module, required this.categoryName});

  final String id;
  final ModuleKind module;
  final String categoryName;

  @override
  List<Object?> get props => [id, module, categoryName];
}

/// Identifier of the setting of [module]: computed, so that two devices
/// naming the category write one record.
String moduleSettingId(ModuleKind module) => derivedId('module-setting/${module.name}');

/// The settings of the modules and their operations.
extension ModuleSettingOperations on Ledger {
  /// The name of the category [module] reads: the one chosen, or its
  /// default name.
  String moduleCategoryName(ModuleKind module) =>
      modules.settings[module]?.categoryName ?? defaultModuleCategoryNames[module]!;

  /// The category [module] reads in [year]: the category of its name in the
  /// tree the year is shown with (a group included, with everything below
  /// it), or null when the tree has no such name, or the year no tree.
  Category? moduleCategory(ModuleKind module, int year) => views.treeOf(year)?.named(moduleCategoryName(module));

  /// Names the category [module] reads. Refused when the name is empty.
  Modification setModuleCategory(ModuleKind module, String name) {
    if (name.trim().isEmpty) throw const LedgerException(LedgerError.moduleCategoryRequired);
    return Modification.set(ModuleSettingFields.entity, moduleSettingId(module), {
      ModuleSettingFields.module: module.name,
      ModuleSettingFields.categoryName: name.trim(),
    });
  }
}
