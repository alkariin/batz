import 'electricity.dart';
import 'monthly_tasks.dart';
import 'salary.dart';
import 'settings.dart';
import 'subscriptions.dart';
import 'taxes.dart';
import 'vacations.dart';

/// What the user entered in the modules, as read from the derived tables:
/// everything else a module shows is computed when its screen opens.
class ModuleRecords {
  ModuleRecords({
    Iterable<ModuleSetting> settings = const [],
    Iterable<SalarySheet> salarySheets = const [],
    Iterable<SalaryDeduction> salaryDeductions = const [],
    Iterable<TaxYear> taxYears = const [],
    Iterable<TaxLine> taxLines = const [],
    Iterable<TripSheet> tripSheets = const [],
    Iterable<ElectricityReading> electricityReadings = const [],
    Iterable<Subscription> subscriptions = const [],
    Iterable<Tranche> tranches = const [],
    Iterable<MonthlyTask> monthlyTasks = const [],
    Iterable<MonthlyCheck> monthlyChecks = const [],
  }) : subscriptions = _subscriptions(subscriptions, tranches),
       monthlyTasks = {for (final t in monthlyTasks) t.id: t},
       monthlyChecks = {for (final c in monthlyChecks) c.id: c},
       tripSheets = {for (final t in tripSheets) t.id: t},
       electricityReadings = {for (final r in electricityReadings) r.lineId: r},
       settings = {for (final s in settings) s.module: s},
       salarySheets = _sheets(salarySheets, salaryDeductions),
       taxYears = {for (final t in taxYears) t.year: t},
       taxLines = _taxLines(taxLines);

  /// The subscriptions by identifier, each with its tranches; a tranche
  /// whose subscription is missing is left out.
  static Map<String, Subscription> _subscriptions(Iterable<Subscription> subscriptions, Iterable<Tranche> tranches) {
    final bySubscription = <String, List<Tranche>>{};
    for (final t in tranches) {
      (bySubscription[t.subscriptionId] ??= []).add(t);
    }
    return {
      for (final s in subscriptions) s.id: s.withTranches([...s.tranches, ...?bySubscription[s.id]]),
    };
  }

  static Map<int, Map<TaxKind, TaxLine>> _taxLines(Iterable<TaxLine> lines) {
    final result = <int, Map<TaxKind, TaxLine>>{};
    for (final line in lines) {
      (result[line.year] ??= {})[line.tax] = line;
    }
    return result;
  }

  /// The sheets by year, each with its deductions; a deduction whose sheet
  /// is missing is left out.
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

  /// The subscriptions and their tranches, by identifier.
  final Map<String, Subscription> subscriptions;

  /// The tasks of the monthly follow-up, and the boxes the user checked or
  /// unchecked, by identifier.
  final Map<String, MonthlyTask> monthlyTasks;
  final Map<String, MonthlyCheck> monthlyChecks;
}
