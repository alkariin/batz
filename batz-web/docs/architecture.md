# Architecture

batz is an offline-first app with a small home server. The functional and
technical reference is `docs/specification.md` (French); this page describes
what is built and why.

## Responsibilities

| Part | Does | Does not |
|---|---|---|
| App (`batz-ui`) | Every calculation, on a full local copy of the data. | Depend on the server to work. |
| Server (`batz-web`) | Pair devices; keep the reference copy of the change journal; extract and check PDF statements, keep the original files. | Interpret the journal, decide what is imported, or compute anything accounting-related. |

The server is on the home network only and runs at weekends; the app must
never need it except to synchronise and import.

## Server

Go, Gin, SQLite (`modernc.org/sqlite`, pure Go, no cgo), one container.

```
batz-web/src
├── main.go                       commands: serve, pairing-code, healthcheck, extract, version
└── internal
    ├── version                   build version, minimum app version
    ├── domain/device             devices, pairing codes, keys, errors
    ├── domain/journal            journal entries, known states, shape checks
    ├── domain/statement          a statement as read, its consistency checks, refusal codes
    ├── application               use cases (Devices, Sync, Imports) and their ports
    └── infrastructure
        ├── config                environment, read once at start-up
        ├── extraction/postfinance  pdftotext and the reading of PostFinance statements
        │   └── fake              generator of fictitious statements (test set in testdata/)
        ├── persistence           SQLite stores (devices, journal), embedded migrations,
        │                         original files, dated copies of the database
        ├── tlscert               self-signed certificate, pinning helpers
        └── web                   routes, authentication, error mapping
```

- **Configuration**: `BATZ_DATA_DIR` (default `data`), `BATZ_PORT`
  (default `8443`) and `BATZ_BACKUPS` (default `12`), read once by
  `config.Load`.
- **Data directory**: `batz.db` (SQLite, WAL), `tls/server.crt` +
  `tls/server.key`, `statements/<fingerprint>.pdf` (the original files) and
  `backups/batz-<time>.db` (dated copies of the database). It is the only
  state to back up.
- **Migrations** are embedded in the binary (`go:embed`) and applied at start
  by golang-migrate. The specification placed them in `batz-web/db/migrations`;
  embedding them means a server image always carries exactly the schema of its
  version and the NAS needs nothing else.
- **HTTPS only**: the certificate (ECDSA P-256, valid 10 years) is created on
  first start and kept in the data directory. There is no plain HTTP listener.
- **Pairing**: `batz-web pairing-code` (run next to the server, e.g. with
  `docker exec`) stores the SHA-256 of a one-time code valid 10 minutes and
  prints the code and the certificate fingerprint. `POST /api/v1/pairing`
  consumes the code in a single `BEGIN IMMEDIATE` transaction, creates the
  device and returns its key once. Only the key's SHA-256 is stored; keys and
  codes are random enough that a slow hash adds nothing.
- **Authentication**: `Authorization: Bearer <device key>`; revoked devices
  are refused. Revoking oneself is how an app unpairs.
- **Journal**: `POST /api/v1/sync` exchanges the change journal with the apps
  (see [sync.md](sync.md)). The server keeps the entries as received in one
  `journal` table, keyed like the app's and indexed by origin device and
  timestamp, and checks only their shape; each exchange is one transaction.
  It never resolves conflicts: the apps do.
- **Import**: `POST /api/v1/imports` reads a PDF statement with `pdftotext`
  (no shell, PDF on standard input, time-limited), checks its consistency and
  answers with its lines; a file it did not hold is kept under its
  fingerprint, after a dated copy of the database (`VACUUM INTO`, the latest
  12 kept). It writes nothing to the journal. See [import.md](import.md).

## App

Flutter, Bloc (cubits), Dio, Drift.

```
batz-ui/lib
├── domain        pure Dart, no Flutter
│   ├── journal   hybrid logical clock, journal entries, resolution rule
│   ├── ledger    accounts, category trees, transactions, statements, mapping
│   │             rules and their proposals, redistribution rules, refunds
│   │             attached to an expense, answers for shares, declared
│   │             balances, debts, search
│   ├── views     the annual view: cash-flow and economic views of a year,
│   │             composition of an amount, shares to classify, the lines
│   │             the modules read; the balances of the accounts, the
│   │             wealth, its curve and its explanation
│   ├── modules   linked categories, salary sheet, flow diagram, taxes,
│   │             trips, electricity, subscriptions
│   ├── allocation.dart, fraction.dart, calendar_date.dart   spreading over months
│   ├── period_model.dart   periods of the mapping rules
│   └── ids.dart  random and computed identifiers
├── data
│   ├── local     Drift database, journal, derived tables, opening and encryption,
│   │             preferences of the device
│   ├── ledger    reads the ledger from the derived tables, writes to the journal
│   ├── server    HTTPS client with certificate pinning, pairing repository,
│   │             import answer
│   ├── sync      exchange engine, wire format, memory of the server state
│   ├── files.dart          picking and saving files (file_picker)
│   └── secret_store.dart   system secret storage
├── pages         shell, home (synchronisation, tasks, key figures), transactions
│                 (search, filters), import and statements, validation and
│                 rules, year (views, composition), redistribution, refunds,
│                 shares to classify, wealth (accounts, curve, table, the
│                 screen of an account), debts, modules (salary sheet, flow
│                 diagram, taxes, vacations, electricity, subscriptions),
│                 accounts, categories, server settings, cubits (ledger,
│                 server, sync, import)
├── components    shared widgets
├── helpers       Swiss formats, theme
└── l10n          French texts (ARB) and generated localisations
```

The design rules for local data (no constraint on derived tables, incomplete
records ignored, derived tables rebuilt instead of migrated, computed
identifiers for copies, calendar dates, no floating point) are listed in
`docs/decisions.md`.

### Local database and journal

Every write goes through `Journal`:

1. A `Modification` is a set of field changes (`entity`, `recordId`, `field`,
   `value`). All its entries share one timestamp and are written and applied
   in one transaction: all or nothing.
2. Timestamps come from a hybrid logical clock (`domain/journal/hlc.dart`):
   wall time in milliseconds, a counter, and the device identifier. The clock
   never goes backwards (it resumes after the latest timestamp in the journal
   at start-up) and moves past every timestamp it observes from other devices.
   Encoded as fixed-width text, timestamps sort the same in Dart and SQLite.
3. Resolution is field by field, the latest timestamp wins; equal time and
   counter are decided by the device identifier. The `field_versions` table
   keeps, for each field, the timestamp of its current value.
4. A deletion is the reserved field `_deleted` set to `true`; it is resolved
   like any other field, so a later edit of another field does not resurrect
   the record, and an explicit restore (`_deleted = false`) does.
5. Derived tables (`DerivedTable`) are plain SQL tables with `id`, `deleted`
   and one nullable column per field, with no constraint. Their `CREATE`
   statements are generated from their definitions; the text of all of them,
   the *derived schema*, is kept in `local_state`. When `Journal.open` finds
   another schema (first launch, new version), it drops the derived tables,
   recreates them and replays the journal. Entries of entities unknown to the
   running version are kept in the journal and applied by that rebuild once a
   version knows them. Drift's schema version covers the journal tables only.

The device identifier is a UUID created at the first launch and stored in the
`local_state` table. It is the *origin* of the entries the device writes, and
changes only when the device's data are replaced by the server's.

A modification writes only the fields whose value changes, compared with the
exact JSON value currently in force: screens submit every field, and the
unchanged ones must not overwrite, once synchronised, what another device
changed.

Entries received from the server are integrated a page at a time, in one
transaction, with set-based statements: the page goes into a temporary table,
the entries already held are dropped, the others are inserted, and for each
field the latest new entry is applied when it is newer than `field_versions`.
The rebuild of the derived tables uses the same statements over the whole
journal.

When the counter of the clock is full, the clock moves to the next
millisecond, so that a device whose clock ran far ahead never blocks the
writes of the others.

### Ledger

| Journal entity | Table | Fields |
|---|---|---|
| `account` | `accounts` | name, type, importFormat, archived |
| `category` | `categories` | year, name, parentId, nature (top-level groups), position |
| `transaction` | `transactions` | accountId, date, amount, counterpartAccountId, description, note, status (`toValidate`, `validated`), rawText, statementId, statementRank |
| `transactionLine` | `transaction_lines` | transactionId, categoryId, amount, periodStart, periodEnd, refundedLineId |
| `statement` | `statements` | accountId, format, iban, periodStart, periodEnd, openingBalance, closingBalance, fingerprint |
| `rule` | `rules` | year, keywords (JSON list), targetCategoryId or targetAccountId, periodModel, periodMonths |
| `redistribution` | `redistributions` | year, sourceCategoryId, targetCategoryId, basisPoints (hundredths of a percent) |
| `shareClassification` | `share_classifications` | lineId, year, categoryId, originCategoryId |
| `balance` | `balances` | accountId, date, amount (identifier computed from the account and the date) |
| `debt` | `debts` | direction, person, amount, basisPoints, eventDate, invoiceDate, requestDate, receivedDate, description, repaid, enteredOn, checkedOn |
| `moduleSetting` | `module_settings` | module, categoryName (identifier computed from the module) |
| `salarySheet`, `salaryDeduction` | `salary_sheets`, `salary_deductions` | year, gross, net; sheetId, label, amount, rank |
| `taxYear`, `taxLine` | `tax_years`, `tax_lines` | year, taxableWealth, marginalRate; year, tax, base, baseRate, coefficient |
| `tripSheet` | `trip_sheets` | lineId (absent for a manual line), place, days, date, amount |
| `electricityReading` | `electricity_readings` | lineId, wh |
| `subscription`, `subscriptionTranche` | `subscriptions`, `subscription_tranches` | name, note; subscriptionId, amount, frequency, start, end |

`LedgerRepository` reads every table, by identifier, into an immutable
`Ledger` and leaves out records that are incomplete or hold a value the
version cannot read. A category whose parents do not reach, in the same year,
a top-level group with a nature is *detached*: `CategoryForest` keeps it apart
with its reason (loop, missing parent, parent in another year, group without
nature), and the categories screen lists it under « À replacer ».
`Ledger.issues` lists the inconsistencies a merge can leave (same name twice
in a year, several detailed accounts, detached categories) for the home
screen. Each operation is a method of `Ledger` that checks the
business rules and returns the `Modification` to write, or throws a
`LedgerException` whose reason the pages turn into a French message.
`LedgerCubit` holds the current `Ledger` for every page.

- **Category trees**: one per year. A year's tree is copied from the closest
  earlier year that has one, at the first transaction of the year or by hand;
  copies and default groups get identifiers computed with SHA-256, so two
  devices copying offline write the same records. Names are compared without
  case, accents or surrounding spaces.
- **Transactions**: amounts are signed integer cents; the type (expense,
  refund, income, transfer) is deduced from the counterpart account, the
  nature of the category and the sign. A transfer is one record on the
  departure account, with no line.
- **Allocation**: `allocate` spreads an amount over the months of a period;
  each month weighs its covered days over its days as an exact fraction, the
  shares are rounded to the cent and the last one takes the remainder.
- **Statements**: `Ledger.importStatement` checks a statement read by the
  server against the account's latest one and returns one modification with
  the statement, its lines (to validate) and the tree copies; identifiers are
  computed from the account, the fingerprint and the rank. Imported lines
  keep the bank's amount, date and text; the latest statement can be
  deleted with its lines.
- **Rules and proposals**: the rules of a year match the raw text of a line
  (every keyword, without case, accents or repeated spaces; `re:` for a
  regular expression); the most keywords win, a tie of different results is
  a conflict. The proposal of each line to validate is computed when the
  ledger loads, never stored, and counted in the totals; validating writes
  the classification. Rules follow the copy of a tree. See
  [import.md](import.md).
- **Annual view**: `ledger.views` computes, for a year and a view, the
  amounts of every category month by month, from flows built once per
  ledger: each line gives one amount at its payment date (cash flow) or one
  per monthly share of its period (economic), placed in the category of the
  same name of the month's year, an answer, or « À classer ». Redistribution
  rules move a percentage between two categories month by month; a refund
  attached to an expense follows its category and period; the period
  offsets reconcile both views. Nothing is stored. See
  [`docs/year-view.md`](../../docs/year-view.md).
- **Wealth**: `ledger.balances` gives, per account, its points (declared
  balances, the opening of its first statement) and its movements (both
  sides of a transfer, proposed ones included), and one function for the
  balance at any date, from which the expected balance and the value
  variation of each declaration follow. `ledger.wealth(today)` adds the
  debts that count each day and gives the wealth at a date, the monthly
  curve and the table of a year, each line computed for itself; the views
  it reads count what is paid up to today. Nothing is stored but the
  balances and the debts. See [`docs/wealth.md`](../../docs/wealth.md).
- **Modules**: each reads the lines the annual view counts
  (`YearViews.linesIn`, `linesNamed`), as the view classifies and spreads
  them, and never classifies again; only what the user enters is stored.
  The trips, totals, ratios, the control of the taxes and the flow diagram
  are computed when their screen opens. See
  [`docs/modules.md`](../../docs/modules.md).

On Android the database is encrypted with SQLCipher (selected per platform
through the `sqlite3` package hooks, see `docs/decisions.md`). Its key, 32
random bytes, is created at the first launch and kept by
`flutter_secure_storage` (Android Keystore), with `resetOnError` disabled so
the key is never silently replaced. Opening fails rather than fall back to an
unencrypted database. Android backups are disabled: a database restored
without its key would be unreadable. Desktops use plain SQLite and rely on the
protection of the operating system.

### Synchronisation

`SyncEngine` (`data/sync`) runs one exchange: `GET /healthz` to check the
versions, then `POST /api/v1/sync` in a loop, each call carrying the device's
known state and a page of what the server lacks, each answer integrated in one
transaction. `SyncStore` remembers, in `local_state`, the server state seen at
the last exchange and its date, to count the modifications waiting.
`SyncCubit` decides when to run it (at start, back to the foreground, 3 s
after a modification, every 5 minutes while shown, on demand), runs one at a
time, and turns the outcome into the status shown on the home screen and in
Plus › Serveur. The protocol, its invariant and the cases of a new device, a
revoked one and a lost server are in [sync.md](sync.md).

### Pairing and certificate pinning

The server certificate is self-signed, so the app trusts no certificate
authority at all (`SecurityContext(withTrustedRoots: false)`): every
certificate goes through a callback that compares its SHA-256 with the pinned
fingerprint, before any request is sent.

Pairing: the app first calls `/healthz` and records the certificate it sees,
then sends the pairing request through a client pinned on that certificate.
The address, device id, device key and fingerprint are stored together in the
system secret store. The fingerprint is shown in the server settings, to be
compared with the one printed by `batz-web pairing-code`. Changing the address
keeps the pin, so another machine at that address is refused.

## Tests

- Server: unit and HTTP tests per package, the exchange included (pages
  never cutting a modification, a page refused as a whole, the same page twice
  without duplicate, `since`, versions, sizes), the extraction of every
  fictitious statement against what its generator printed, each check, the
  import route (refusals, the same file twice, 12 copies kept, the original
  file, logs without statement text); `test/e2e` builds the binary and
  exercises pairing, refusals, revocation, restarts, certificate pinning, an
  exchange between two simulated devices, `extract` and an import over real
  HTTPS.
- App: the clock and the resolution rule; the journal against a naive
  reference model on shuffled histories from three devices; deletion,
  restarts and failed transactions; derived schema changes and the opening of
  a database written by version 0.1.0 (`test/fixtures`); allocation, with
  random amounts and periods; the rules of accounts, category trees,
  transactions and totals; a tree copied on two simulated devices; the
  ledger rebuilt from the journal; Swiss formats; widget tests of the
  navigation, the server, accounts and categories screens and the main path
  of the transactions screen; `test/e2e` drives the app's server code against
  a real `batz-web` process: pairing, and the synchronisation of simulated
  devices (concurrent edits, deletions, cut exchanges, the first exchange of
  H1, revocation, a rebuilt server, and a convergence test with random
  operations, clocks, exchange orders and cuts), and the import of the
  fictitious statements (balances, refusals, two devices, validation with the
  server stopped, the original file). The synchronisation, import and
  validation screens are tested against servers in memory; the import, the
  rules, the periods and the search have their own domain tests, and
  `test/data/write_performance_test.dart` bounds the writing of an import and
  of a confirmation in bulk. The annual view has its own tests: the examples
  of the specification, then properties checked on random ledgers (the
  twelve months of every line, the cash-flow total, the identity of the
  period offsets, the questions waiting equal to « À classer »),
  redistribution, refunds and shares to classify; `test/e2e/year_view_e2e_test.dart`
  sends the new records between devices through a real server, and the
  convergence test includes their operations. The wealth has its own tests:
  the examples of the plan (the table of reference line by line, a pure
  loan, an advanced expense), the balances and the debts rule by rule, and on
  random ledgers each table adding up to the change of the wealth and each
  month of the curve equal to the wealth at its date;
  `test/e2e/wealth_e2e_test.dart` sends balances and debts between devices,
  and the convergence test declares balances and handles debts.
  `test/data/performance_test.dart` bounds every reload after a write, every
  computation of the views of a year and of the « Fortune » screen with
  10 000 transactions, 100 balances and 200 debts, alone on the machine
  (every test file holds a shared lock, the measurement takes it exclusive
  for the whole test); databases written by versions 0.1.0 to 0.6.0 are
  opened by `test/data/upgrade_test.dart`. Each module has its tests: the
  examples of the plan, properties on random data (the flow diagram
  balanced, each line of the vacation category in one trip, the price of
  the electricity against the economic view, the tax total against its
  lines), and the check that no entry changes the views nor the wealth;
  `test/e2e/modules_e2e_test.dart` sends them between devices, and the
  convergence test includes their operations. The performance test also
  bounds each module screen and the diagram. `benchmark/first_exchange_test.dart` and
  `benchmark/journal_write_test.dart`, run by hand, measure a first exchange
  of 20 000 entries and the writing of 1 000 fields.
