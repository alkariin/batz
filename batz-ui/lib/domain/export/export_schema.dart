/// What the export holds of each journal entity: every field goes to one
/// column of one file, or is excluded with its reason.
/// `test/domain/export/export_completeness_test.dart` fails when an entity
/// or a field of the journal is in neither.
library;

import '../journal/journal_entry.dart';
import '../ledger/account.dart';
import '../ledger/balance.dart';
import '../ledger/category.dart';
import '../ledger/debt.dart';
import '../ledger/redistribution.dart';
import '../ledger/rule.dart';
import '../ledger/share_classification.dart';
import '../ledger/statement.dart';
import '../ledger/transaction.dart';
import '../modules/electricity.dart';
import '../modules/salary.dart';
import '../modules/settings.dart';
import '../modules/subscriptions.dart';
import '../modules/taxes.dart';
import '../modules/vacations.dart';

/// The names of the files, in the order of docs/features.md, « Export ».
abstract final class ExportFiles {
  static const accounts = 'comptes.csv';
  static const balances = 'soldes.csv';
  static const statements = 'releves.csv';
  static const categories = 'categories.csv';
  static const rules = 'regles.csv';
  static const redistributions = 'redistributions.csv';
  static const transactions = 'transactions.csv';
  static const shares = 'parts-reportees.csv';
  static const debts = 'dettes.csv';
  static const salarySheets = 'fiches-salaire.csv';
  static const salaryDeductions = 'deductions-salaire.csv';
  static const taxYears = 'annees-fiscales.csv';
  static const taxLines = 'impots.csv';
  static const trips = 'voyages.csv';
  static const electricity = 'electricite.csv';
  static const subscriptions = 'abonnements.csv';
  static const moduleSettings = 'reglages-modules.csv';

  static const all = [
    accounts,
    balances,
    statements,
    categories,
    rules,
    redistributions,
    transactions,
    shares,
    debts,
    salarySheets,
    salaryDeductions,
    taxYears,
    taxLines,
    trips,
    electricity,
    subscriptions,
    moduleSettings,
  ];
}

// ------------------------------------------------------------------ labels

/// The texts the export writes for the values the journal stores as names.
/// Statuses, types, natures, directions and frequencies are written in lower
/// case, as values (« validée », « dépense »); types of accounts, taxes,
/// and modules as the app names them.
abstract final class ExportLabels {
  static const accountTypes = {
    AccountType.privateAccount: 'Compte privé',
    AccountType.savings: 'Épargne',
    AccountType.pillar3: '3e pilier',
    AccountType.pillar2: '2e pilier',
    AccountType.investments: 'Investissements',
    AccountType.vehicle: 'Véhicule',
    AccountType.rentDeposit: 'Garantie de loyer',
    AccountType.cash: 'Espèces',
    AccountType.debts: 'Dettes',
    AccountType.other: 'Autre',
  };

  static const importFormats = {ImportFormat.postfinance: 'PostFinance'};

  static const natures = {CategoryNature.income: 'revenus', CategoryNature.expense: 'dépenses'};

  static const statuses = {TransactionStatus.toValidate: 'à valider', TransactionStatus.validated: 'validée'};

  static const kinds = {
    TransactionKind.expense: 'dépense',
    TransactionKind.refund: 'remboursement',
    TransactionKind.income: 'revenu',
    TransactionKind.transfer: 'transfert',
  };

  static const debtDirections = {DebtDirection.owedToMe: 'on me doit', DebtDirection.iOwe: 'je dois'};

  static const taxes = {
    TaxKind.federalIncome: 'Revenu fédéral',
    TaxKind.cantonalIncome: 'Revenu cantonal',
    TaxKind.communalIncome: 'Revenu communal',
    TaxKind.cantonalWealth: 'Fortune cantonale',
    TaxKind.communalWealth: 'Fortune communale',
  };

  static const frequencies = {TrancheFrequency.monthly: 'mensuel', TrancheFrequency.yearly: 'annuel'};

  static const modules = {
    ModuleKind.salary: 'Fiche salaire',
    ModuleKind.taxes: 'Impôts',
    ModuleKind.vacations: 'Vacances',
    ModuleKind.electricity: 'Électricité',
  };

  /// [labels] by the name the journal stores.
  static Map<String, String> byName<T extends Enum>(Map<T, String> labels) => {
    for (final e in labels.entries) e.key.name: e.value,
  };
}

/// The remarks of `voyages.csv` on a sheet that is not the one of a trip.
abstract final class TripRemarks {
  static const extra = 'fiche en trop';
  static const orphan = 'fiche sans transaction';
  static const incomplete = 'ligne manuelle incomplète';
}

// ---------------------------------------------------------------- columns

/// How the stored value of a field is written in its column.
enum ExportKind {
  /// Text entered by the user or read from the bank: with an apostrophe in
  /// front of `=`, `+`, `-` or `@`.
  text,

  /// An identifier, as it is.
  id,

  /// Cents: `1234.50`.
  amount,

  /// Hundredths of a percent: `50.00`.
  percent,

  /// Ten-thousandths of a percent: `2.5000`.
  rate,

  /// Wh, in kWh: `1900.5`.
  kwh,

  /// `2026-12-31`.
  date,

  /// `oui` or `non`; absent is `non`.
  flag,

  integer,

  /// A name of the journal, written with its label.
  label,

  /// The JSON list of the lines of a rule, one per line of the cell.
  ruleLines,
}

/// The column a field goes to.
class ExportColumn {
  const ExportColumn(this.header, this.kind, {this.labels, this.absentShowsComputed = false});

  final String header;
  final ExportKind kind;

  /// For [ExportKind.label]: the label of each stored name.
  final Map<String, String>? labels;

  /// When the field is absent, the column shows the value the app computes
  /// instead (the automatic date and amount of a trip).
  final bool absentShowsComputed;
}

/// Where the records of an entity go.
class ExportedEntity {
  const ExportedEntity({required this.file, required this.idColumn, required this.fields, this.excluded = const {}});

  final String file;

  /// The column that holds the identifier of the record: every row of the
  /// record has it (a subscription has one row per tranche).
  final String idColumn;
  final Map<String, ExportColumn> fields;

  /// Fields left out, with their reason.
  final Map<String, String> excluded;
}

/// Left out of every entity: what is deleted is not exported.
const excludedFromEveryEntity = {deletedField: 'ce qui est supprimé n’est pas exporté'};

/// Entities of the journal left out of the export, with their reason. None:
/// everything entered or imported is exported.
const Map<String, String> excludedEntities = {};

const _text = ExportKind.text;
const _id = ExportKind.id;
const _amount = ExportKind.amount;
const _date = ExportKind.date;

/// Every entity of the journal and where each of its fields goes.
final Map<String, ExportedEntity> exportSchema = {
  AccountFields.entity: ExportedEntity(
    file: ExportFiles.accounts,
    idColumn: 'id',
    fields: {
      AccountFields.name: const ExportColumn('Nom', _text),
      AccountFields.type: ExportColumn(
        'Type',
        ExportKind.label,
        labels: ExportLabels.byName(ExportLabels.accountTypes),
      ),
      AccountFields.importFormat: ExportColumn(
        "Format d'import",
        ExportKind.label,
        labels: ExportLabels.byName(ExportLabels.importFormats),
      ),
      AccountFields.archived: const ExportColumn('Archivé', ExportKind.flag),
      AccountFields.declared: const ExportColumn('Déclaré aux impôts', ExportKind.flag),
      AccountFields.position: const ExportColumn('Position', ExportKind.integer),
    },
  ),
  BalanceFields.entity: const ExportedEntity(
    file: ExportFiles.balances,
    idColumn: 'id',
    fields: {
      BalanceFields.accountId: ExportColumn('idCompte', _id),
      BalanceFields.date: ExportColumn('Date', _date),
      BalanceFields.amount: ExportColumn('Montant', _amount),
      BalanceFields.note: ExportColumn('Note', _text),
    },
  ),
  StatementFields.entity: ExportedEntity(
    file: ExportFiles.statements,
    idColumn: 'id',
    fields: {
      StatementFields.accountId: const ExportColumn('idCompte', _id),
      StatementFields.format: ExportColumn(
        'Format',
        ExportKind.label,
        labels: ExportLabels.byName(ExportLabels.importFormats),
      ),
      StatementFields.iban: const ExportColumn('IBAN', _text),
      StatementFields.periodStart: const ExportColumn('Début de période', _date),
      StatementFields.periodEnd: const ExportColumn('Fin de période', _date),
      StatementFields.openingBalance: const ExportColumn('Solde initial', _amount),
      StatementFields.closingBalance: const ExportColumn('Solde final', _amount),
      StatementFields.fingerprint: const ExportColumn('Empreinte du fichier', _id),
    },
  ),
  CategoryFields.entity: ExportedEntity(
    file: ExportFiles.categories,
    idColumn: 'id',
    fields: {
      CategoryFields.year: const ExportColumn('Année', ExportKind.integer),
      CategoryFields.name: const ExportColumn('Nom', _text),
      CategoryFields.parentId: const ExportColumn('idParent', _id),
      CategoryFields.nature: ExportColumn(
        'Nature',
        ExportKind.label,
        labels: ExportLabels.byName(ExportLabels.natures),
      ),
      CategoryFields.position: const ExportColumn('Position', ExportKind.integer),
    },
  ),
  RuleFields.entity: const ExportedEntity(
    file: ExportFiles.rules,
    idColumn: 'id',
    fields: {
      RuleFields.year: ExportColumn('Année', ExportKind.integer),
      RuleFields.lines: ExportColumn('Lignes', ExportKind.ruleLines, absentShowsComputed: true),
      RuleFields.targetCategoryId: ExportColumn('idCatégorieCible', _id),
      RuleFields.targetAccountId: ExportColumn('idCompteCible', _id),
    },
    excluded: {
      RuleFields.keywords: 'ancienne forme des lignes : la colonne « Lignes » la reprend en une ligne « a ET b »',
    },
  ),
  RedistributionFields.entity: const ExportedEntity(
    file: ExportFiles.redistributions,
    idColumn: 'id',
    fields: {
      RedistributionFields.year: ExportColumn('Année', ExportKind.integer),
      RedistributionFields.sourceCategoryId: ExportColumn('idCatégorieSource', _id),
      RedistributionFields.targetCategoryId: ExportColumn('idCatégorieCible', _id),
      RedistributionFields.basisPoints: ExportColumn('Pourcentage', ExportKind.percent),
      RedistributionFields.amount: ExportColumn('Montant fixe', _amount),
    },
  ),
  TransactionFields.entity: ExportedEntity(
    file: ExportFiles.transactions,
    idColumn: 'idTransaction',
    fields: {
      TransactionFields.accountId: const ExportColumn('idCompte', _id),
      TransactionFields.date: const ExportColumn('Date', _date),
      TransactionFields.amount: const ExportColumn('Montant', _amount),
      TransactionFields.counterpartAccountId: const ExportColumn('idCompteContrepartie', _id),
      TransactionFields.description: const ExportColumn('Description', _text),
      TransactionFields.note: const ExportColumn('Note', _text),
      TransactionFields.status: ExportColumn(
        'Statut',
        ExportKind.label,
        labels: ExportLabels.byName(ExportLabels.statuses),
      ),
      TransactionFields.rawText: const ExportColumn('Texte de la banque', _text),
      TransactionFields.statementId: const ExportColumn('idRelevé', _id),
      TransactionFields.statementRank: const ExportColumn('Rang dans le relevé', ExportKind.integer),
    },
  ),
  LineFields.entity: const ExportedEntity(
    file: ExportFiles.transactions,
    idColumn: 'idLigne',
    fields: {
      LineFields.transactionId: ExportColumn('idTransaction', _id),
      LineFields.categoryId: ExportColumn('idCatégorie', _id),
      LineFields.amount: ExportColumn('Montant de la ligne', _amount),
      LineFields.periodStart: ExportColumn('Début de période', _date),
      LineFields.periodEnd: ExportColumn('Fin de période', _date),
      LineFields.refundedLineId: ExportColumn('idLigneRemboursée', _id),
    },
  ),
  ShareClassificationFields.entity: const ExportedEntity(
    file: ExportFiles.shares,
    idColumn: 'id',
    fields: {
      ShareClassificationFields.lineId: ExportColumn('idLigne', _id),
      ShareClassificationFields.year: ExportColumn('Année', ExportKind.integer),
      ShareClassificationFields.categoryId: ExportColumn('idCatégorieChoisie', _id),
      ShareClassificationFields.originCategoryId: ExportColumn('idCatégorieOrigine', _id),
    },
  ),
  DebtFields.entity: ExportedEntity(
    file: ExportFiles.debts,
    idColumn: 'id',
    fields: {
      DebtFields.direction: ExportColumn(
        'Sens',
        ExportKind.label,
        labels: ExportLabels.byName(ExportLabels.debtDirections),
      ),
      DebtFields.person: const ExportColumn('Personne', _text),
      DebtFields.amount: const ExportColumn('Montant', _amount),
      DebtFields.basisPoints: const ExportColumn('Pourcentage', ExportKind.percent),
      DebtFields.eventDate: const ExportColumn("Date de l'événement", _date),
      DebtFields.invoiceDate: const ExportColumn('Date de la facture', _date),
      DebtFields.requestDate: const ExportColumn('Date de la demande', _date),
      DebtFields.receivedDate: const ExportColumn('Date de réception', _date),
      DebtFields.description: const ExportColumn('Description', _text),
      DebtFields.repaid: const ExportColumn('Remboursée', ExportKind.flag),
      DebtFields.enteredOn: const ExportColumn('Saisie le', _date),
      DebtFields.checkedOn: const ExportColumn('Cochée le', _date),
    },
  ),
  SalarySheetFields.entity: const ExportedEntity(
    file: ExportFiles.salarySheets,
    idColumn: 'id',
    fields: {
      SalarySheetFields.year: ExportColumn('Année', ExportKind.integer),
      SalarySheetFields.gross: ExportColumn('Brut', _amount),
      SalarySheetFields.net: ExportColumn('Net', _amount),
    },
  ),
  SalaryDeductionFields.entity: const ExportedEntity(
    file: ExportFiles.salaryDeductions,
    idColumn: 'id',
    fields: {
      SalaryDeductionFields.sheetId: ExportColumn('idFiche', _id),
      SalaryDeductionFields.label: ExportColumn('Libellé', _text),
      SalaryDeductionFields.amount: ExportColumn('Montant', _amount),
      SalaryDeductionFields.rank: ExportColumn('Rang', ExportKind.integer),
    },
  ),
  TaxYearFields.entity: const ExportedEntity(
    file: ExportFiles.taxYears,
    idColumn: 'id',
    fields: {
      TaxYearFields.year: ExportColumn('Année', ExportKind.integer),
      TaxYearFields.taxableWealth: ExportColumn('Fortune imposable', _amount),
      TaxYearFields.marginalRate: ExportColumn('TMI', ExportKind.percent),
    },
  ),
  TaxLineFields.entity: ExportedEntity(
    file: ExportFiles.taxLines,
    idColumn: 'id',
    fields: {
      TaxLineFields.year: const ExportColumn('Année', ExportKind.integer),
      TaxLineFields.tax: ExportColumn('Impôt', ExportKind.label, labels: ExportLabels.byName(ExportLabels.taxes)),
      TaxLineFields.base: const ExportColumn('Base', _amount),
      TaxLineFields.baseRate: const ExportColumn('Taux de base', ExportKind.rate),
      TaxLineFields.coefficient: const ExportColumn('Coefficient', ExportKind.percent),
    },
  ),
  TripSheetFields.entity: const ExportedEntity(
    file: ExportFiles.trips,
    idColumn: 'id',
    fields: {
      TripSheetFields.lineId: ExportColumn('idLigne', _id),
      TripSheetFields.place: ExportColumn('Lieu', _text),
      TripSheetFields.days: ExportColumn('Jours', ExportKind.integer),
      TripSheetFields.date: ExportColumn('Date', _date, absentShowsComputed: true),
      TripSheetFields.amount: ExportColumn('Montant', _amount, absentShowsComputed: true),
    },
  ),
  ElectricityReadingFields.entity: const ExportedEntity(
    file: ExportFiles.electricity,
    idColumn: 'id',
    fields: {
      ElectricityReadingFields.lineId: ExportColumn('idLigne', _id),
      ElectricityReadingFields.wh: ExportColumn('kWh', ExportKind.kwh),
    },
  ),
  SubscriptionFields.entity: const ExportedEntity(
    file: ExportFiles.subscriptions,
    idColumn: 'idAbonnement',
    fields: {
      SubscriptionFields.name: ExportColumn('Abonnement', _text),
      SubscriptionFields.note: ExportColumn('Note', _text),
    },
  ),
  TrancheFields.entity: ExportedEntity(
    file: ExportFiles.subscriptions,
    idColumn: 'id',
    fields: {
      TrancheFields.subscriptionId: const ExportColumn('idAbonnement', _id),
      TrancheFields.amount: const ExportColumn('Montant', _amount),
      TrancheFields.frequency: ExportColumn(
        'Fréquence',
        ExportKind.label,
        labels: ExportLabels.byName(ExportLabels.frequencies),
      ),
      TrancheFields.start: const ExportColumn('Début', _date),
      TrancheFields.end: const ExportColumn('Fin', _date),
    },
  ),
  ModuleSettingFields.entity: ExportedEntity(
    file: ExportFiles.moduleSettings,
    idColumn: 'id',
    fields: {
      ModuleSettingFields.module: ExportColumn(
        'Module',
        ExportKind.label,
        labels: ExportLabels.byName(ExportLabels.modules),
      ),
      ModuleSettingFields.categoryName: const ExportColumn('Nom de la catégorie liée', _text),
    },
  ),
};
