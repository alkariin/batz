import 'electricity.dart';
import 'salary.dart';
import 'settings.dart';
import 'taxes.dart';
import 'vacations.dart';

/// What the user entered in the modules (phase 6), as read from the derived
/// tables: everything else a module shows is computed when its screen opens
/// (principles 2 and 8 of phase 6).
class ModuleRecords {
  ModuleRecords({
    Iterable<ModuleSetting> settings = const [],
    Iterable<SalarySheet> salarySheets = const [],
    Iterable<SalaryDeduction> salaryDeductions = const [],
    Iterable<TaxYear> taxYears = const [],
    Iterable<TaxLine> taxLines = const [],
    Iterable<TripSheet> tripSheets = const [],
    Iterable<ElectricityReading> electricityReadings = const [],
  }) : tripSheets = {for (final t in tripSheets) t.id: t},
       electricityReadings = {for (final r in electricityReadings) r.lineId: r},
       settings = {for (final s in settings) s.module: s},
       salarySheets = _sheets(salarySheets, salaryDeductions),
       taxYears = {for (final t in taxYears) t.year: t},
       taxLines = _taxLines(taxLines);

  static Map<int, Map<TaxKind, TaxLine>> _taxLines(Iterable<TaxLine> lines) {
    final result = <int, Map<TaxKind, TaxLine>>{};
    for (final line in lines) {
      (result[line.year] ??= {})[line.tax] = line;
    }
    return result;
  }

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

  /// The fiscal years, by year, and their lines by year and tax.
  final Map<int, TaxYear> taxYears;
  final Map<int, Map<TaxKind, TaxLine>> taxLines;

  /// The sheets of the trips and the manual lines, by identifier.
  final Map<String, TripSheet> tripSheets;

  /// The energy entered for the lines, by line.
  final Map<String, ElectricityReading> electricityReadings;
}
