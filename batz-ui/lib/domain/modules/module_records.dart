import 'salary.dart';
import 'settings.dart';

/// What the user entered in the modules (phase 6), as read from the derived
/// tables: everything else a module shows is computed when its screen opens
/// (principles 2 and 8 of phase 6).
class ModuleRecords {
  ModuleRecords({
    Iterable<ModuleSetting> settings = const [],
    Iterable<SalarySheet> salarySheets = const [],
    Iterable<SalaryDeduction> salaryDeductions = const [],
  }) : settings = {for (final s in settings) s.module: s},
       salarySheets = _sheets(salarySheets, salaryDeductions);

  /// The sheets by year, each with its deductions; a deduction whose sheet
  /// is missing is left out (rule 2 of phase 1).
  static Map<int, SalarySheet> _sheets(Iterable<SalarySheet> sheets, Iterable<SalaryDeduction> deductions) {
    final bySheet = <String, List<SalaryDeduction>>{};
    for (final d in deductions) {
      (bySheet[d.sheetId] ??= []).add(d);
    }
    return {
      for (final s in sheets) s.year: s.withDeductions([...s.deductions, ...?bySheet[s.id]]),
    };
  }

  static final empty = ModuleRecords();

  /// The category named for each module, when the user named one.
  final Map<ModuleKind, ModuleSetting> settings;

  /// The salary sheets, by year.
  final Map<int, SalarySheet> salarySheets;
}
