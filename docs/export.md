# The export

Everything entered or imported, as a ZIP of CSV files a spreadsheet opens:
« Plus › Réglages › Exporter les données ». The functional reference is
`docs/specification.md` (chapter 4.8, in French); the choices made for
phase 7 are in `docs/plan/phase-7.md` (decisions H1 and H2, rules) and
`docs/decisions.md` (7.1 and 7.2).

Code: `batz-ui/lib/domain/export/` (`ledger_export.dart` for the files,
`export_schema.dart` for what goes where, `csv.dart` for the format,
`export_archive.dart` for the ZIP), screen in
`batz-ui/lib/pages/export/export_page.dart`. Tests:
`batz-ui/test/domain/export/`, `batz-ui/test/pages/export/` and
`batz-ui/test/e2e/export_e2e_test.dart`; the expected files of an example
ledger are in `batz-ui/test/fixtures/export/`.

## What it is

- Made on demand, on any device, offline: the export reads the local data
  and nothing else. It writes nothing to the journal and does not go
  through the server.
- One file, `batz-export-YYYY-MM-DD.zip`, saved through the dialog of the
  system. The app keeps no copy of it.
- **The file is not encrypted.** It holds everything the app holds, readable
  by anyone who opens it. The screen says so before exporting.
- There is no way back: the app does not import an export.
- Two synchronised devices export the same CSV files, byte for byte (the
  rows of each file are sorted by its own data; the ZIP itself carries the
  time it was made).

## What it holds

Everything entered or imported, in its state of the day: accounts, declared
balances, statements, the category tree of each year, mapping and
redistribution rules, transactions and their lines, the answers for carried
shares, debts, and what is entered in the modules.

Not exported:

- what the app computes: the annual view, the wealth, its curve, the flow
  diagram, the proposals of the rules for the lines to validate;
- the history of the modifications, and what was deleted;
- the original PDF statements (they stay on the server);
- the pairing with the server and the choices of the device.

A few computed values are written all the same, so that a row reads on its
own: the path of a category (« Logement > Loyer »), the type of a validated
transaction, the total of a debt, the amount of a tax line, and the trips
as the « Vacances » screen groups them.

`export_schema.dart` lists, for each entity of the journal, its file and the
column of each of its fields. A test compares it with the tables of the
app: an entity or a field added later and not exported fails it.

## Format

- UTF-8 with a byte order mark; lines end with CR LF; the first line holds
  the headers. File names, headers and values are in French, as in the app.
- Fields are separated by semicolons. A value holding a semicolon, a quote
  or a line break is quoted, its quotes doubled.
- Amounts in francs, with a decimal point and no thousands separator:
  `1234.50`, `-85.00`. An amount is negative when money leaves the account.
- Percentages `50.00`; base rates of a tax `2.5000`; kWh `1900`, `1900.5`.
- Dates `2026-12-31`. Yes and no: `oui`, `non`. An absent value is empty.
- A text entered by the user or coming from the bank that starts with `=`,
  `+`, `-` or `@` is preceded by an apostrophe, so that a spreadsheet does
  not run it as a formula: `=A1+1` is written `'=A1+1`. A negative amount is
  not a text and stays `-85.00`.
- The identifiers are in columns named `id…`, at the end of each file. They
  link the files: `idCompte` of a transaction is the `id` of a row of
  `comptes.csv`. Beside them, the name is written in clear.

### Opening a file in Excel

Double-clicking works where Windows uses the semicolon as list separator
and the point as decimal symbol. Otherwise: Data › From Text/CSV, origin
« 65001: Unicode (UTF-8) », delimiter « Semicolon »; if the amounts stay
text, « Transform Data » and give their columns the type « Decimal Number »
with the locale « English (United States) ». `LISEZMOI.txt`, in the ZIP,
says the same in French.

## Files

Seventeen CSV files, always present (a file without data holds its headers),
and `LISEZMOI.txt`: the date of the export, the version of the app, the
number of transactions, each file with its number of rows, what is left out
and the format.

| File | One row per | Columns |
|---|---|---|
| `comptes.csv` | account | Nom; Type; Format d'import; Archivé; id |
| `soldes.csv` | declared balance | Compte; Date; Montant; id; idCompte |
| `releves.csv` | imported statement | Compte; Format; IBAN; Début de période; Fin de période; Solde initial; Solde final; Empreinte du fichier; id; idCompte |
| `categories.csv` | category of a year | Année; Chemin; Nom; Nature; Groupe parent; Position; id; idParent |
| `regles.csv` | mapping rule | Année; Mots-clés; Catégorie cible; Compte cible; Modèle de période; Mois; id; idCatégorieCible; idCompteCible |
| `redistributions.csv` | redistribution rule | Année; Catégorie source; Catégorie cible; Pourcentage; id; idCatégorieSource; idCatégorieCible |
| `transactions.csv` | line of a transaction | Date; Compte; Montant; Texte de la banque; Description; Note; Statut; Type; Catégorie; Début de période; Fin de période; Montant de la ligne; Compte de contrepartie; Relevé; Rang dans le relevé; Dépense remboursée; idTransaction; idLigne; idCompte; idCatégorie; idCompteContrepartie; idRelevé; idLigneRemboursée |
| `parts-reportees.csv` | answer for a carried share | Date de paiement; Description; Montant; Année; Catégorie choisie; Catégorie d'origine; id; idLigne; idTransaction; idCatégorieChoisie; idCatégorieOrigine |
| `dettes.csv` | debt | Sens; Personne; Montant; Pourcentage; Total; Date de l'événement; Date de la facture; Date de la demande; Date de réception; Description; Remboursée; Saisie le; Cochée le; id |
| `fiches-salaire.csv` | salary sheet | Année; Brut; Net; id |
| `deductions-salaire.csv` | deduction of a sheet | Année; Rang; Libellé; Montant; id; idFiche |
| `annees-fiscales.csv` | fiscal year | Année; Fortune imposable; TMI; id |
| `impots.csv` | tax line | Année; Impôt; Base; Taux de base; Coefficient; Montant; id |
| `voyages.csv` | trip | Année; Date; Lieu; Jours; Montant; Date automatique; Montant automatique; Date remplacée; Montant remplacé; Nombre de transactions; Ligne manuelle; Remarque; id; idLigne |
| `electricite.csv` | line that carries kWh | Date de paiement; Description; Début de période; Fin de période; Montant; kWh; id; idLigne; idTransaction |
| `abonnements.csv` | tranche of a subscription | Abonnement; Note; Montant; Fréquence; Début; Fin; id; idAbonnement |
| `reglages-modules.csv` | module | Module; Nom de la catégorie liée; Nom choisi; id |

Notes:

- **`transactions.csv`** has one row per line of a transaction, and one row
  for a transaction without line (a transfer, a line to validate): then the
  category and the period are empty. « Montant » is the amount of the
  transaction, « Montant de la ligne » the amount of the line. « Type »
  (dépense, remboursement, revenu, transfert) is empty for a line to
  validate. « Relevé » is the period of the statement the line came from;
  « Dépense remboursée » the date and description of the expense a refund
  is attached to.
- **`categories.csv`**: « Chemin » goes from the top-level group to the
  category; « Nature » (revenus, dépenses) is the one of its top-level
  group. Rows follow the order of the tree.
- **`regles.csv`**: the keywords of a rule are written one per line in
  their cell; « Mois » is the number of months of a period model that needs
  one.
- **`impots.csv`**: « Montant » is base × base rate × coefficient, as the
  screen shows it; empty while the base or the rate is missing. The lines
  of wealth have no base of their own: the taxable wealth is in
  `annees-fiscales.csv`.
- **`voyages.csv`**: one row per trip as the screen groups them, with what
  its sheet says; then one row per other sheet, with its « Remarque »:
  « fiche en trop » (a second sheet on a trip), « fiche sans transaction »
  (its line left the category or is gone), « ligne manuelle incomplète ».
- **`electricite.csv`**: kWh whose line is gone keep their row, without the
  columns of the transaction.
- **`abonnements.csv`**: one row per tranche, and one for a subscription
  without tranche.
- **`reglages-modules.csv`**: one row per module; « Nom choisi » is `non`
  while the default name is used.

## Performance

With 10 000 transactions over five years and the data of the modules
(`test/data/performance_test.dart`), the seventeen files and the ZIP are
made in 300 to 400 ms on the development machine; the test fails above
2 seconds.
