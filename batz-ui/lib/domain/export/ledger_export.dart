/// The files of an export: everything entered or imported, as it is today,
/// one CSV file per subject. The export only reads the ledger and sorts
/// every file by an order of its own data, so that two synchronised devices
/// write the same files.
library;

import 'dart:typed_data';

import '../calendar_date.dart';
import '../ledger/category.dart';
import '../ledger/ledger.dart';
import '../ledger/transaction.dart';
import '../modules/settings.dart';
import '../modules/subscriptions.dart';
import '../modules/taxes.dart';
import '../modules/vacations.dart';
import 'csv.dart';
import 'export_schema.dart';

/// One CSV file of the export.
class ExportFile {
  ExportFile(this.name, this.headers, this.rows);

  final String name;
  final List<String> headers;
  final List<List<Cell?>> rows;

  late final Uint8List bytes = csvBytes(headers, rows);
}

/// The headers of each file, in their order: what is read first, then the
/// identifiers at the end.
abstract final class ExportHeaders {
  static const accounts = ['Nom', 'Type', "Format d'import", 'Archivé', 'id'];
  static const balances = ['Compte', 'Date', 'Montant', 'id', 'idCompte'];
  static const statements = [
    'Compte',
    'Format',
    'IBAN',
    'Début de période',
    'Fin de période',
    'Solde initial',
    'Solde final',
    'Empreinte du fichier',
    'id',
    'idCompte',
  ];
  static const categories = ['Année', 'Chemin', 'Nom', 'Nature', 'Groupe parent', 'Position', 'id', 'idParent'];
  static const rules = [
    'Année',
    'Lignes',
    'Catégorie cible',
    'Compte cible',
    'id',
    'idCatégorieCible',
    'idCompteCible',
  ];
  static const redistributions = [
    'Année',
    'Catégorie source',
    'Catégorie cible',
    'Pourcentage',
    'Montant fixe',
    'id',
    'idCatégorieSource',
    'idCatégorieCible',
  ];
  static const transactions = [
    'Date',
    'Compte',
    'Montant',
    'Texte de la banque',
    'Description',
    'Note',
    'Statut',
    'Type',
    'Catégorie',
    'Début de période',
    'Fin de période',
    'Montant de la ligne',
    'Compte de contrepartie',
    'Relevé',
    'Rang dans le relevé',
    'Dépense remboursée',
    'idTransaction',
    'idLigne',
    'idCompte',
    'idCatégorie',
    'idCompteContrepartie',
    'idRelevé',
    'idLigneRemboursée',
  ];
  static const shares = [
    'Date de paiement',
    'Description',
    'Montant',
    'Année',
    'Catégorie choisie',
    "Catégorie d'origine",
    'id',
    'idLigne',
    'idTransaction',
    'idCatégorieChoisie',
    'idCatégorieOrigine',
  ];
  static const debts = [
    'Sens',
    'Personne',
    'Montant',
    'Pourcentage',
    'Total',
    "Date de l'événement",
    'Date de la facture',
    'Date de la demande',
    'Date de réception',
    'Description',
    'Remboursée',
    'Saisie le',
    'Cochée le',
    'id',
  ];
  static const salarySheets = ['Année', 'Brut', 'Net', 'id'];
  static const salaryDeductions = ['Année', 'Rang', 'Libellé', 'Montant', 'id', 'idFiche'];
  static const taxYears = ['Année', 'Fortune imposable', 'TMI', 'id'];
  static const taxLines = ['Année', 'Impôt', 'Base', 'Taux de base', 'Coefficient', 'Montant', 'id'];
  static const trips = [
    'Année',
    'Date',
    'Lieu',
    'Jours',
    'Montant',
    'Date automatique',
    'Montant automatique',
    'Date remplacée',
    'Montant remplacé',
    'Nombre de transactions',
    'Ligne manuelle',
    'Remarque',
    'id',
    'idLigne',
  ];
  static const electricity = [
    'Date de paiement',
    'Description',
    'Début de période',
    'Fin de période',
    'Montant',
    'kWh',
    'id',
    'idLigne',
    'idTransaction',
  ];
  static const subscriptions = ['Abonnement', 'Note', 'Montant', 'Fréquence', 'Début', 'Fin', 'id', 'idAbonnement'];
  static const moduleSettings = ['Module', 'Nom de la catégorie liée', 'Nom choisi', 'id'];

  static const byFile = {
    ExportFiles.accounts: accounts,
    ExportFiles.balances: balances,
    ExportFiles.statements: statements,
    ExportFiles.categories: categories,
    ExportFiles.rules: rules,
    ExportFiles.redistributions: redistributions,
    ExportFiles.transactions: transactions,
    ExportFiles.shares: shares,
    ExportFiles.debts: debts,
    ExportFiles.salarySheets: salarySheets,
    ExportFiles.salaryDeductions: salaryDeductions,
    ExportFiles.taxYears: taxYears,
    ExportFiles.taxLines: taxLines,
    ExportFiles.trips: trips,
    ExportFiles.electricity: electricity,
    ExportFiles.subscriptions: subscriptions,
    ExportFiles.moduleSettings: moduleSettings,
  };
}

/// The seventeen CSV files of an export of [ledger], in the order of
/// [ExportFiles.all].
List<ExportFile> exportFiles(Ledger ledger) => _Exporter(ledger).files();

/// A transaction and the line an identifier names: its own line, or for a
/// transaction without line, the identifier its line will get once
/// validated (what the modules and the answers attach to).
typedef _LineOwner = ({LedgerTransaction transaction, TransactionLine? line});

class _Exporter {
  _Exporter(this.ledger);

  final Ledger ledger;

  List<ExportFile> files() => [
    _file(ExportFiles.accounts, _accounts()),
    _file(ExportFiles.balances, _balances()),
    _file(ExportFiles.statements, _statements()),
    _file(ExportFiles.categories, _categories()),
    _file(ExportFiles.rules, _rules()),
    _file(ExportFiles.redistributions, _redistributions()),
    _file(ExportFiles.transactions, _transactions()),
    _file(ExportFiles.shares, _shares()),
    _file(ExportFiles.debts, _debts()),
    _file(ExportFiles.salarySheets, _salarySheets()),
    _file(ExportFiles.salaryDeductions, _salaryDeductions()),
    _file(ExportFiles.taxYears, _taxYears()),
    _file(ExportFiles.taxLines, _taxLines()),
    _file(ExportFiles.trips, _trips()),
    _file(ExportFiles.electricity, _electricity()),
    _file(ExportFiles.subscriptions, _subscriptions()),
    _file(ExportFiles.moduleSettings, _moduleSettings()),
  ];

  ExportFile _file(String name, List<List<Cell?>> rows) => ExportFile(name, ExportHeaders.byFile[name]!, rows);

  // ---------------------------------------------------------------- helpers

  /// Every category, those of the trees and the detached ones.
  late final Map<String, Category> _allCategories = {
    ...ledger.categories,
    for (final d in ledger.forest.detached.values) d.category.id: d.category,
  };

  /// « Logement > Loyer »: the names from the top-level group down to the
  /// category, as far as its parents can be followed.
  late final Map<String, String> _paths = {for (final id in _allCategories.keys) id: _path(id)};

  String _path(String id) {
    final names = <String>[];
    final seen = <String>{};
    for (var current = _allCategories[id]; current != null && seen.add(current.id); current = _parentOf(current)) {
      names.add(current.name);
    }
    return names.reversed.join(' > ');
  }

  Category? _parentOf(Category category) => category.parentId == null ? null : _allCategories[category.parentId];

  Cell? _categoryPath(String? id) => id == null ? null : PlainCell(_paths[id] ?? '');

  Cell? _accountName(String? id) {
    if (id == null) return null;
    final account = ledger.accounts[id];
    return account == null ? null : TextCell(account.name);
  }

  late final Map<String, _LineOwner> _owners = () {
    final owners = <String, _LineOwner>{};
    for (final t in ledger.transactions.values) {
      if (t.lines.isEmpty) owners[Ledger.fallbackLineId(t.id)] = (transaction: t, line: null);
    }
    for (final t in ledger.transactions.values) {
      for (final line in t.lines) {
        owners[line.id] = (transaction: t, line: line);
      }
    }
    return owners;
  }();

  static Cell? _id(String? id) => id == null ? null : PlainCell(id);
  static Cell? _date(CalendarDate? date) => date == null ? null : DateCell(date);
  static Cell? _amount(int? cents) => cents == null ? null : AmountCell(cents);
  static Cell? _int(int? value) => value == null ? null : IntCell(value);

  /// Sorting by several keys, each compared in turn; null comes last.
  static int _compare(List<Comparable<Object>?> a, List<Comparable<Object>?> b) {
    for (var i = 0; i < a.length; i++) {
      final (x, y) = (a[i], b[i]);
      if (x == null && y == null) continue;
      if (x == null) return 1;
      if (y == null) return -1;
      final byKey = x.compareTo(y);
      if (byKey != 0) return byKey;
    }
    return 0;
  }

  /// The order of accounts: by name, then identifier.
  List<Comparable<Object>?> _accountKey(String accountId) => [
    ledger.accounts[accountId]?.name.toLowerCase(),
    ledger.accounts[accountId]?.name,
    accountId,
  ];

  // ------------------------------------------------------------------ files

  List<List<Cell?>> _accounts() {
    final accounts = ledger.accounts.values.toList()..sort((a, b) => _compare(_accountKey(a.id), _accountKey(b.id)));
    return [
      for (final a in accounts)
        [
          TextCell(a.name),
          PlainCell(ExportLabels.accountTypes[a.type]!),
          a.importFormat == null ? null : PlainCell(ExportLabels.importFormats[a.importFormat]!),
          FlagCell(a.archived),
          PlainCell(a.id),
        ],
    ];
  }

  List<List<Cell?>> _balances() {
    final balances = ledger.declaredBalances.values.toList()
      ..sort(
        (a, b) => _compare([..._accountKey(a.accountId), a.date, a.id], [..._accountKey(b.accountId), b.date, b.id]),
      );
    return [
      for (final b in balances)
        [_accountName(b.accountId), DateCell(b.date), AmountCell(b.amount), PlainCell(b.id), PlainCell(b.accountId)],
    ];
  }

  List<List<Cell?>> _statements() {
    final statements = ledger.statements.values.toList()
      ..sort(
        (a, b) => _compare(
          [..._accountKey(a.accountId), a.periodStart, a.id],
          [..._accountKey(b.accountId), b.periodStart, b.id],
        ),
      );
    return [
      for (final s in statements)
        [
          _accountName(s.accountId),
          PlainCell(ExportLabels.byName(ExportLabels.importFormats)[s.format] ?? s.format),
          TextCell(s.iban),
          DateCell(s.periodStart),
          DateCell(s.periodEnd),
          AmountCell(s.openingBalance),
          AmountCell(s.closingBalance),
          PlainCell(s.fingerprint),
          PlainCell(s.id),
          PlainCell(s.accountId),
        ],
    ];
  }

  List<List<Cell?>> _categories() {
    final ordered = <Category>[
      for (final year in ledger.yearsWithTree) ...ledger.trees[year]!.ordered,
      ...(ledger.forest.detached.values.map((d) => d.category).toList()
        ..sort((a, b) => _compare([a.year, _paths[a.id], a.id], [b.year, _paths[b.id], b.id]))),
    ];
    return [
      for (final c in ordered)
        [
          IntCell(c.year),
          PlainCell(_paths[c.id]!),
          TextCell(c.name),
          c.nature == null ? null : PlainCell(ExportLabels.natures[c.nature]!),
          c.parentId == null ? null : TextCell(_allCategories[c.parentId]?.name ?? ''),
          IntCell(c.position),
          PlainCell(c.id),
          _id(c.parentId),
        ],
    ];
  }

  List<List<Cell?>> _rules() {
    final rules = ledger.rules.values.toList()
      ..sort((a, b) => _compare([a.year, a.lines.join('\n'), a.id], [b.year, b.lines.join('\n'), b.id]));
    return [
      for (final r in rules)
        [
          IntCell(r.year),
          TextCell(r.lines.join('\n')),
          _categoryPath(r.targetCategoryId),
          _accountName(r.targetAccountId),
          PlainCell(r.id),
          _id(r.targetCategoryId),
          _id(r.targetAccountId),
        ],
    ];
  }

  List<List<Cell?>> _redistributions() {
    final rules = ledger.redistributions.values.toList()
      ..sort(
        (a, b) => _compare(
          [a.year, _paths[a.sourceId], _paths[a.targetId], a.id],
          [b.year, _paths[b.sourceId], _paths[b.targetId], b.id],
        ),
      );
    return [
      for (final r in rules)
        [
          IntCell(r.year),
          _categoryPath(r.sourceId),
          _categoryPath(r.targetId),
          r.basisPoints == null ? null : PercentCell(r.basisPoints!),
          r.amount == null ? null : AmountCell(r.amount!),
          PlainCell(r.id),
          PlainCell(r.sourceId),
          PlainCell(r.targetId),
        ],
    ];
  }

  /// One row per line of a transaction; a transaction without line has one
  /// row, without category nor period.
  List<List<Cell?>> _transactions() {
    final transactions = ledger.transactions.values.toList()..sort((a, b) => _compare([a.date, a.id], [b.date, b.id]));
    final rows = <List<Cell?>>[];
    for (final t in transactions) {
      final kind = t.isValidated ? ledger.kindOf(t) : null;
      final statement = t.statementId == null ? null : ledger.statements[t.statementId];
      for (final line in t.lines.isEmpty ? const <TransactionLine?>[null] : t.lines) {
        final refunded = line?.refundedLineId == null ? null : _owners[line!.refundedLineId];
        rows.add([
          DateCell(t.date),
          _accountName(t.accountId),
          AmountCell(t.amount),
          t.rawText == null ? null : TextCell(t.rawText!),
          TextCell(t.description),
          TextCell(t.note),
          PlainCell(ExportLabels.statuses[t.status]!),
          kind == null ? null : PlainCell(ExportLabels.kinds[kind]!),
          _categoryPath(line?.categoryId),
          _date(line?.periodStart),
          _date(line?.periodEnd),
          _amount(line?.amount),
          _accountName(t.counterpartAccountId),
          statement == null
              ? null
              : PlainCell('du ${statement.periodStart.encode()} au ${statement.periodEnd.encode()}'),
          _int(t.statementRank),
          refunded == null
              ? null
              : TextCell('${refunded.transaction.date.encode()} ${refunded.transaction.description}'.trim()),
          PlainCell(t.id),
          _id(line?.id),
          PlainCell(t.accountId),
          _id(line?.categoryId),
          _id(t.counterpartAccountId),
          _id(t.statementId),
          _id(line?.refundedLineId),
        ]);
      }
    }
    return rows;
  }

  List<List<Cell?>> _shares() {
    final answers = ledger.shareClassifications.values.toList()
      ..sort((a, b) {
        final (x, y) = (_owners[a.lineId]?.transaction, _owners[b.lineId]?.transaction);
        return _compare([a.year, x?.date, a.lineId, a.id], [b.year, y?.date, b.lineId, b.id]);
      });
    return [
      for (final a in answers)
        () {
          final t = _owners[a.lineId]?.transaction;
          return [
            _date(t?.date),
            t == null ? null : TextCell(t.description),
            _amount(t?.amount),
            IntCell(a.year),
            _categoryPath(a.categoryId),
            _categoryPath(a.originCategoryId),
            PlainCell(a.id),
            PlainCell(a.lineId),
            _id(t?.id),
            PlainCell(a.categoryId),
            PlainCell(a.originCategoryId),
          ];
        }(),
    ];
  }

  List<List<Cell?>> _debts() {
    final debts = ledger.debts.values.toList()
      ..sort(
        (a, b) => _compare(
          [a.eventDate ?? a.enteredOn, a.person.toLowerCase(), a.id],
          [b.eventDate ?? b.enteredOn, b.person.toLowerCase(), b.id],
        ),
      );
    return [
      for (final d in debts)
        [
          PlainCell(ExportLabels.debtDirections[d.direction]!),
          TextCell(d.person),
          AmountCell(d.amount),
          PercentCell(d.basisPoints),
          AmountCell(d.total),
          _date(d.eventDate),
          _date(d.invoiceDate),
          _date(d.requestDate),
          _date(d.receivedDate),
          TextCell(d.description),
          FlagCell(d.repaid),
          DateCell(d.enteredOn),
          _date(d.checkedOn),
          PlainCell(d.id),
        ],
    ];
  }

  List<List<Cell?>> _salarySheets() {
    final sheets = ledger.modules.salarySheets.values.toList()
      ..sort((a, b) => _compare([a.year, a.id], [b.year, b.id]));
    return [
      for (final s in sheets) [IntCell(s.year), AmountCell(s.gross), AmountCell(s.net), PlainCell(s.id)],
    ];
  }

  List<List<Cell?>> _salaryDeductions() {
    final rows = [
      for (final s in ledger.modules.salarySheets.values)
        for (final d in s.deductions) (s.year, d),
    ]..sort((a, b) => _compare([a.$1, a.$2.rank, a.$2.id], [b.$1, b.$2.rank, b.$2.id]));
    return [
      for (final (year, d) in rows)
        [
          IntCell(year),
          IntCell(d.rank),
          TextCell(d.label),
          AmountCell(d.amount),
          PlainCell(d.id),
          PlainCell(d.sheetId),
        ],
    ];
  }

  List<List<Cell?>> _taxYears() {
    final years = ledger.modules.taxYears.values.toList()..sort((a, b) => _compare([a.year, a.id], [b.year, b.id]));
    return [
      for (final y in years)
        [
          IntCell(y.year),
          _amount(y.taxableWealth),
          y.marginalRate == null ? null : PercentCell(y.marginalRate!),
          PlainCell(y.id),
        ],
    ];
  }

  /// The amount of a line is computed as the taxes screen does; none while
  /// the line lacks its base or its rate.
  List<List<Cell?>> _taxLines() {
    final lines = [for (final byTax in ledger.modules.taxLines.values) ...byTax.values]
      ..sort((a, b) => _compare([a.year, a.tax.index, a.id], [b.year, b.tax.index, b.id]));
    return [
      for (final l in lines)
        () {
          final base = l.tax.onWealth ? ledger.modules.taxYears[l.year]?.taxableWealth : l.base;
          final amount = base == null || l.baseRate == null
              ? null
              : taxAmount(base, l.baseRate!, l.coefficient ?? fullCoefficient);
          return [
            IntCell(l.year),
            PlainCell(ExportLabels.taxes[l.tax]!),
            _amount(l.base),
            l.baseRate == null ? null : RateCell(l.baseRate!),
            l.coefficient == null ? null : PercentCell(l.coefficient!),
            _amount(amount),
            PlainCell(l.id),
          ];
        }(),
    ];
  }

  /// The trips as the screen groups them, then each sheet that is not the
  /// one of a trip, with its remark.
  List<List<Cell?>> _trips() {
    final vacations = ledger.vacations;
    final rows = <(List<Comparable<Object>?>, List<Cell?>)>[];
    final used = <String>{};
    for (final trip in vacations.trips) {
      final sheet = trip.sheet;
      if (sheet != null) used.add(sheet.id);
      final lineId = sheet?.lineId ?? trip.anchorLineId;
      rows.add((
        [trip.date, 0, lineId, sheet?.id],
        [
          IntCell(trip.year),
          DateCell(trip.date),
          TextCell(trip.place),
          _int(trip.days),
          AmountCell(trip.amount),
          _date(trip.automaticDate),
          _amount(trip.automaticAmount),
          FlagCell(trip.dateReplaced),
          FlagCell(trip.amountReplaced),
          IntCell(trip.lines.length),
          FlagCell(trip.isManual),
          null,
          _id(sheet?.id),
          _id(lineId),
        ],
      ));
    }
    final extra = {for (final t in vacations.trips) ...t.extraSheets.map((s) => s.id)};
    final orphans = {for (final s in vacations.orphanSheets) s.id};
    for (final sheet in ledger.modules.tripSheets.values) {
      if (used.contains(sheet.id)) continue;
      final remark = extra.contains(sheet.id)
          ? TripRemarks.extra
          : orphans.contains(sheet.id)
          ? TripRemarks.orphan
          : TripRemarks.incomplete;
      rows.add((
        [sheet.date, 1, sheet.lineId, sheet.id],
        [
          _int(sheet.date?.year),
          _date(sheet.date),
          TextCell(sheet.place),
          _int(sheet.days),
          _amount(sheet.amount),
          null,
          null,
          FlagCell(!sheet.isManual && sheet.date != null),
          FlagCell(!sheet.isManual && sheet.amount != null),
          null,
          FlagCell(sheet.isManual),
          PlainCell(remark),
          PlainCell(sheet.id),
          _id(sheet.lineId),
        ],
      ));
    }
    rows.sort((a, b) => _compare(a.$1, b.$1));
    return [for (final (_, row) in rows) row];
  }

  /// One row per line that carries kWh; the columns of the transaction stay
  /// empty when it is gone.
  List<List<Cell?>> _electricity() {
    final readings = ledger.modules.electricityReadings.values.toList()
      ..sort((a, b) {
        final (x, y) = (_owners[a.lineId]?.transaction, _owners[b.lineId]?.transaction);
        return _compare([x?.date, a.lineId, a.id], [y?.date, b.lineId, b.id]);
      });
    return [
      for (final r in readings)
        () {
          final owner = _owners[r.lineId];
          final (t, line) = (owner?.transaction, owner?.line);
          return [
            _date(t?.date),
            t == null ? null : TextCell(t.description),
            _date(line?.periodStart),
            _date(line?.periodEnd),
            _amount(line?.amount ?? t?.amount),
            KwhCell(r.wh),
            PlainCell(r.id),
            PlainCell(r.lineId),
            _id(t?.id),
          ];
        }(),
    ];
  }

  /// One row per tranche; a subscription without tranche has one row.
  List<List<Cell?>> _subscriptions() {
    final subscriptions = ledger.modules.subscriptions.values.toList()
      ..sort((a, b) => _compare([a.name.toLowerCase(), a.name, a.id], [b.name.toLowerCase(), b.name, b.id]));
    final rows = <List<Cell?>>[];
    for (final s in subscriptions) {
      final tranches = [...s.tranches]..sort((a, b) => _compare([a.start, a.id], [b.start, b.id]));
      for (final t in tranches.isEmpty ? const <Tranche?>[null] : tranches) {
        rows.add([
          TextCell(s.name),
          TextCell(s.note),
          _amount(t?.amount),
          t == null ? null : PlainCell(ExportLabels.frequencies[t.frequency]!),
          _date(t?.start),
          _date(t?.end),
          _id(t?.id),
          PlainCell(s.id),
        ]);
      }
    }
    return rows;
  }

  /// One row per module: the name chosen, or the default one.
  List<List<Cell?>> _moduleSettings() => [
    for (final module in ModuleKind.values)
      () {
        final setting = ledger.modules.settings[module];
        return [
          PlainCell(ExportLabels.modules[module]!),
          TextCell(setting?.categoryName ?? defaultModuleCategoryNames[module]!),
          FlagCell(setting != null),
          _id(setting?.id),
        ];
      }(),
  ];
}
