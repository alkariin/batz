# Architecture

batz is an offline-first app with a small home server. This page describes
how both are built and work together. What the app computes and shows is in
[features](features.md), the server routes in the [API](api.md),
installation and releases in [deployment](deployment.md), and the reasons for
the technical choices in [decisions](decisions.md).

## Responsibilities

| Part | Does | Does not |
|---|---|---|
| App (`batz-ui`) | Every calculation, on a full local copy of the data. | Depend on the server to work. |
| Server (`batz-web`) | Pair devices; keep the reference copy of the change journal; extract and check PDF statements, keep the original files. | Interpret the journal, decide what is imported, or compute anything accounting-related. |

The server is on the home network only and runs at weekends; the app needs
it only to synchronise and to import statements.

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

- **Configuration**: `BATZ_DATA_DIR` (default `data`), `BATZ_PORT` (`8443`)
  and `BATZ_BACKUPS` (`12`), read once by `config.Load`.
- **Data directory**, the only state to back up: `batz.db` (SQLite, WAL),
  `tls/server.crt` and `tls/server.key`, `statements/<fingerprint>.pdf` (the
  original files) and `backups/batz-<time>.db` (dated copies of the database).
- **Migrations** are embedded in the binary (`go:embed`) and applied at start
  by golang-migrate: an image carries exactly the schema of its version.
- **HTTPS only**, with no plain HTTP listener: the certificate (ECDSA P-256,
  valid 10 years) is created on first start and kept in the data directory.
- **Authentication**: `Authorization: Bearer <device key>` on every route but
  `/healthz` and the pairing; revoked devices are refused. Revoking oneself is
  how an app unpairs.
- **Journal**: one `journal` table, keyed like the app's and indexed by
  origin and timestamp ([Synchronisation](#synchronisation)).

## App

Flutter, Bloc (cubits), Dio, Drift.

```
batz-ui/lib
├── domain       pure Dart, no Flutter
│   ├── journal  hybrid logical clock, journal entries, known state, resolution rule
│   ├── ledger   the records and their business rules, mapping rules, search
│   ├── views    annual view, balances of the accounts, wealth
│   ├── modules  salary sheet, flow diagram, taxes, trips, electricity, subscriptions
│   ├── export   the files of an export, the CSV format, the ZIP
│   └── allocation, fractions, calendar dates, periods of the rules, identifiers
├── data
│   ├── local    Drift database, journal, derived tables, opening and encryption
│   ├── ledger   reads the ledger from the derived tables, writes to the journal
│   ├── server   HTTPS client with certificate pinning, pairing, import answer
│   ├── sync     exchange engine, wire format, memory of the server state
│   └── files, device lock (Android), system secret storage
├── pages        one folder per screen, the lock in front of them, the cubits
├── components   shared widgets
├── helpers      Swiss formats, theme
└── l10n         French texts (ARB) and generated localisations
```

Rules for local data: derived tables have no constraint (no uniqueness,
foreign key or NOT NULL), since entries from other devices arrive field by
field, in any order, and integrating them must never fail; the domain checks
the business rules when the user enters data. An incomplete record is
ignored when read until its missing fields arrive. Derived tables never
migrate: they are rebuilt from the journal. Copies get computed identifiers,
so two devices copying the same thing offline write the same records. Dates
are calendar dates (`YYYY-MM-DD`) without time or zone; amounts are integer
cents and month weights exact fractions: no floating point.

### Local database and journal

Every write goes through `Journal`:

1. A `Modification` is a set of field changes (`entity`, `recordId`, `field`,
   `value`). Its entries share one timestamp, so a timestamp identifies a
   modification, and are written and applied in one transaction.
2. Only the fields whose value changes are written, compared with the exact
   JSON value in force: screens submit every field, and the unchanged ones
   must not overwrite, once synchronised, what another device changed.
3. Timestamps come from a hybrid logical clock (`domain/journal/hlc.dart`):
   wall time in milliseconds, a counter and the device identifier, as
   fixed-width text whose order is the time order in Dart, SQLite and Go.

   ```
   001763647200000:0000:3f2c1a9e-8b7d-4c6e-9f10-2a3b4c5d6e7f
   └─ wall time, ms ┘└ctr┘└──────────── origin device ────────┘
   ```

   The clock never goes backwards: it resumes after the latest timestamp of
   the journal at start-up and moves past every timestamp it observes. When
   its counter is full it moves to the next millisecond, so a device whose
   clock ran far ahead never blocks the writes of the others.
4. Resolution is field by field: the latest timestamp wins; equal time and
   counter are decided by the device identifier. `field_versions` keeps the
   timestamp of the current value of each field.
5. A deletion is the reserved boolean field `_deleted` set to `true`, resolved
   like any other: neither a later edit of another field nor an older edit
   arriving late brings the record back; an explicit restore does.
6. Derived tables (`DerivedTable`) are plain SQL tables with `id`, `deleted`
   and one nullable column per field, their `CREATE` statements generated
   from their definitions. When `Journal.open` finds that the text of all of
   them (the *derived schema*, kept in `local_state`) changed, it drops,
   recreates and refills them from the journal. Entries the running version
   does not know stay in the journal until a version that knows them
   rebuilds. Drift's schema version covers the journal tables only.

The device identifier, a UUID created at the first launch and kept in
`local_state`, is the *origin* of the entries the device writes. It is not
the identifier the server gives at pairing, and changes only when the
device's data are replaced by the server's.

On Android the database is encrypted with SQLCipher (selected per platform
through the `sqlite3` package hooks). Its key, 32 random bytes, is created at
the first launch and kept by `flutter_secure_storage` (Android Keystore) with
`resetOnError` disabled, so it is never silently replaced; opening fails
rather than fall back to an unencrypted database. Android backups are
disabled: a database restored without its key would be unreadable. Desktops
use plain SQLite.

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

`LedgerRepository` reads every table into an immutable `Ledger`, leaving out
records that are incomplete or hold a value the version cannot read. Each
operation is a method of `Ledger` that checks the business rules and returns
the `Modification` to write, or throws a `LedgerException` whose reason the
pages turn into a French message. `LedgerCubit` holds the current `Ledger`
for every page.

- **Category trees**: one per year, copied from the closest earlier year that
  has one, at the first transaction of the year or by hand; copies and
  default groups get identifiers computed with SHA-256. Names are compared
  without case, accents or surrounding spaces. A category whose parents do
  not reach, in the same year, a top-level group with a nature is
  *detached*: `CategoryForest` keeps it apart with its reason (loop, missing
  parent, parent in another year, group without nature).
- **Transactions**: amounts are signed integer cents; the type (expense,
  refund, income, transfer) follows from the counterpart account, the nature
  of the category and the sign. A transfer is one record on the departure
  account, with no line.
- **Allocation**: `allocate` spreads an amount over the months of a period;
  each month weighs its covered days over its days as an exact fraction, the
  shares are rounded to the cent and the last one takes the remainder.

Statements and mapping rules are described with the
[import](#the-lines-in-the-app). The annual view (`ledger.views`), the
balances and the wealth (`ledger.balances`, `ledger.wealth(today)`), the
modules (which read the lines the view counts, through `YearViews.linesIn`
and `linesNamed`, and never classify again) and the export (`exportFiles`,
`buildExportArchive`) are computed from the `Ledger` when a screen needs
them; only what the user enters is stored. What they compute is in
[features](features.md).

## Pairing and certificate pinning

`batz-web pairing-code`, run next to the server (e.g. with `docker exec`),
stores the SHA-256 of a one-time code valid 10 minutes and prints the code
and the certificate fingerprint. `POST /api/v1/pairing` consumes the code in
a single `BEGIN IMMEDIATE` transaction, creates the device and returns its
key once. Only the key's SHA-256 is stored: keys and codes are random enough
that a slow hash adds nothing.

The app trusts no certificate authority
(`SecurityContext(withTrustedRoots: false)`): every certificate goes through
a callback that compares its SHA-256 with the pinned fingerprint before any
request is sent. To pair, the app
calls `/healthz`, records the certificate it sees, then sends the pairing
request through a client pinned on it. The address, device id, device key
and fingerprint are kept together in the system secret store. The
fingerprint is shown in the server settings, to compare with the one
`pairing-code` printed. Changing the address keeps the pin, so another
machine at that address is refused.

## Synchronisation

How the apps exchange their change journal through the server
([`POST /api/v1/sync`](api.md#post-apiv1sync)).

### Principle

The server stores the entries exactly as the apps send them; conflicts are
resolved by the apps, field by field, the latest change wins. During an
exchange each side sends the other what it lacks according to the other's
known state, whatever the origin. There is no cursor and no recovery mode: a
new device, an empty server or a server restored from an old copy are
ordinary exchanges, which is what lets the server be rebuilt from any device.
An entry already held is ignored, so an interrupted exchange resumes at the
next one without loss or duplicate. The server checks the device, the
protocol, the app version, the shape of every entry and the size of the
page, and refuses an incorrect page as a whole.

### Entries, origins and known state

An entry is one field of one record set to one value (`entity`, `recordId`,
`field`, `value`), stamped with the timestamp of its modification. The last
part of the timestamp is its *origin*: the journal identifier of the device
that wrote it.

The known state of a copy gives, for each origin, the latest timestamp held:

```json
{ "3f2c1a9e-…": "001763647200000:0003:3f2c1a9e-…", "8b1d…": "001763650000000:0000:8b1d…" }
```

A copy with known state `K` lacks every entry of origin `o` stamped after
`K[o]`, and every entry of an origin absent from `K`.

### Invariant

**For each origin, every copy holds that origin's entries from the first one,
without a gap.** The known state is meaningful only because of it. It holds
because:

- A device stamps its own entries in increasing order (the clock never goes
  back, even across restarts).
- What is sent is selected from the receiver's known state and **sorted by
  timestamp**: for each origin, a page holds a contiguous run that starts
  right after what the receiver held.
- A page is **integrated in one transaction**, and **never cuts a
  modification**: entries sharing a timestamp travel together (a single
  modification larger than a page is sent whole).
- A page carries `since`: for each origin present, the receiver's known
  timestamp it was computed from. The receiver refuses a page that continues
  from more than it holds (on the server: `409 SYNC_STATE_CHANGED`), for
  instance when the server was restored from an older copy between two calls.
- A device whose data are replaced by the server's takes a new journal
  identifier, so that its new entries never follow, under the same origin,
  entries that were erased.

### Protocol

Before exchanging, the app calls `GET /healthz` and stops when its version is
below `minAppVersion` (app too old), when `syncProtocol` is absent (server
before 0.3.0) or smaller than its own (server too old), or larger (app too
old). Then it calls `POST /api/v1/sync` in a loop:

```
server := unknown, more := true
loop
    page := server unknown ? nothing : what the server lacks according to `server`
    stop if server is known, page is empty and not more
    answer := POST /sync { known: my known state, since: page.since, entries: page }
    (first answer only) check for a device used separately, see below
    integrate answer.entries in one transaction (refused if answer.since > what I hold)
    server := answer.known, more := answer.more
    remember `server` (to count the modifications waiting)
remember the date of the exchange
```

- The first call sends no entry: it learns the server state.
- The server integrates the page in one transaction, then answers with its
  state *after* integrating it and a page of what the device lacks according
  to the request's `known`.
- On `SYNC_STATE_CHANGED` the app starts again from the server's current
  state, at most three times.
- An answer announcing `more` without any entry, or a server page that would
  leave a gap, stops the exchange as a protocol error.
- Local modifications made during an exchange go with the next call.

Page sizes: the app sends 500 entries (or 4 MiB) per call and asks for 1 000;
the server accepts up to 10 000 entries and 32 MiB per call, and sends at most
the size asked, stopping at 8 MiB. A modification holds at most 10 000
changes. The value of an entry travels as its JSON text, at most 256 KiB; the
server checks that it is null, a boolean, a 64-bit integer or a string, then
stores and returns that text unchanged. A first exchange of 20 000 entries
takes about 3 s each way on the development machine.

### Integration on the device

Each page goes into a temporary table; entries already held are dropped, the
others are inserted into the journal; then, for each field touched, the
latest new entry is applied to the derived table if it is newer than
`field_versions`. It is one transaction of a few set-based statements, with
the result of applying the entries one by one, in any order. The rebuild of
the derived tables runs the same statements over the whole journal.

### When it runs

`SyncEngine` (`data/sync`) runs one exchange; `SyncStore` remembers, in
`local_state`, the server state seen at the last exchange and its date.
`SyncCubit` runs it when the app opens, when it comes back to the
foreground, 3 seconds after the last modification, every 5 minutes while it
is shown, and from « Synchroniser ». One exchange runs at a time; a trigger
during an exchange schedules exactly one more. An unreachable server shows
« Hors ligne », never an error. After an exchange that received entries,
every screen reloads.

The home screen and Plus › Serveur show the status, the date of the last
exchange, the number of modifications waiting (timestamps held beyond the
server state of the last exchange), and a warning, which never blocks
anything, when the device clock is more than 5 minutes away from the
server's (`serverTime`, at each call).

### First exchange of a device used separately

When the device and the server both hold entries and their known states have
no origin in common, they never exchanged. The app checks this on the first
answer, before integrating or sending anything, and asks:

- **Fusionner**: an ordinary exchange. Duplicates it may create are listed as
  [tasks](#inconsistencies-after-a-merge).
- **Remplacer les données de cet appareil**: the app asks the server as a
  device holding nothing; with the first answer, in one transaction, it erases
  its journal and derived tables, takes a new journal identifier and
  integrates the page, then the exchange continues as usual. Nothing is
  erased if the server does not answer. Modifications not sent are lost: the
  app says so before confirming. The same action is in Plus › Serveur.

### Revoked device, lost server

- A revoked device (`401 DEVICE_REVOKED`) stops its automatic exchanges and
  says so; its data stay and it remains usable. Paired again, its first
  exchange sends everything the server lacks, unsent modifications included.
- A server that presents another certificate, or no longer knows the device's
  key (`401 DEVICE_KEY_INVALID`), was probably reinstalled: the app says « Le
  serveur a changé » and invites to pair again. The ordinary exchange then
  rebuilds the server from the device; the other devices pair again and send
  what they hold. Sharing origins with the rebuilt server, they are not asked
  whether to merge or replace.
- A server restored from an older copy needs nothing: each device's next
  exchange sends what the copy lacks.

### Inconsistencies after a merge

Each device checks the business rules against its own data only. After a
merge the data can hold two categories with the same name in one year,
several detailed accounts, or detached categories (a loop made by two moves
at the same time, a parent deleted on one device while a child was added on
another). None of them blocks anything: `Ledger.issues` lists them under
« À faire » on the home screen, to correct through the usual screens;
detached categories are listed under « À replacer » in the categories
screen, with the action that moves them back.

### Known limits

- If one device copies a year's tree and then renames or moves a copied
  category, and another device, not yet synchronised, copies the same tree
  later, the rename is undone after synchronisation. Both devices show the
  same tree; nothing is duplicated or deleted.
- The order of changes depends on the device clocks: a device whose clock is
  far behind loses its concurrent changes. The clock warning is there for
  that.
- A device database restored from an older file backup keeps its journal
  identifier but forgets entries it had already sent; if its clock is behind,
  its next entries could take timestamps the server already holds for that
  origin and never be sent. Android backups are disabled; on a desktop,
  install afresh and pair instead: the server sends everything back.

## Import of statements

Each month the user sends the PDF statement of the bank to the server, which
reads and checks it; the app checks that it follows the previous one and
writes the statement and its lines into the journal, where they wait to be
validated ([`POST /api/v1/imports`](api.md#post-apiv1imports)).

| Part | Does | Does not |
|---|---|---|
| Server | Reads the PDF with `pdftotext`, checks its internal consistency, keeps the file under its fingerprint after a dated copy of its database, answers with the lines. | Write anything to the journal; know which statements were imported. |
| App | Checks the continuity with the account's previous statement, writes the statement and all its lines in **one** modification, proposes a classification from the rules, validates. | Read PDF files. |

The rules of the domain stay in the app, in one implementation. Writing the
statement in one modification makes the import all or nothing, on this
device and on every device that receives it.

### The flow

1. Transactions › « Importer un relevé » first runs a synchronisation; if it
   does not go to its end (no server, unreachable, revoked, other server,
   incompatible versions, a question pending), the import does not start and
   the screen says why.
2. The user picks the detailed account and the PDF file. The app computes its
   fingerprint (SHA-256) and refuses a statement its journal already holds,
   without sending it: the journal knows, even after the server was rebuilt.
3. The app checks that `/healthz` announces the account's format
   (`importFormats`), then sends the file. The server extracts and checks the
   statement; accepted, it keeps the file and answers with the statement and
   its fingerprint, refused, it answers `422` with the code and the check.
4. `Ledger.importStatement` checks the statement against the ledger. The
   first statement of an account asks for a confirmation: it sets the
   starting balance, and no earlier statement can be imported afterwards.
5. The app writes the statement, its lines (« à valider ») and the copy of
   the category tree of each year a line opens, in one modification, and
   shows the period, the number of lines, how many the rules propose and how
   many are to complete. The modification reaches the server at the next
   exchange, like any other.

The validation can then happen anywhere, offline: it only writes to the
local journal.

### Checks and refusals

The server reads the statement in full, then checks it in this order; the
first failure refuses it as a whole. Amounts are integer cents throughout.

| Check | Refused when |
|---|---|
| `layout` | It cannot be read entirely: a movement without a date or a label, the opening or closing balance or the totals missing, two IBANs. |
| `currency` | The account is not in Swiss francs (the currency is printed after the IBAN on the first page). |
| `period` | A movement is dated outside the period of the statement, or before the movement above it. |
| `runningBalance` | A balance printed in the course of the statement (after the last movement of a day) differs from the opening balance plus the movements up to it. |
| `totals` | The printed total of credits or of debits differs from the movements. |
| `closingBalance` | The opening balance plus all the movements differs from the closing balance. |

Every refusal, from the server (code) or the app (reason), and what the user
reads; a refused statement writes nothing.

| Refusal | When | Message |
|---|---|---|
| `IMPORT_UNREADABLE` | The file is not a PDF pdftotext can read. | Ce fichier n'est pas un PDF lisible. |
| `IMPORT_UNKNOWN_FORMAT` | The PDF is not a PostFinance statement. | Ce PDF n'est pas un relevé PostFinance. |
| `IMPORT_INCONSISTENT` | A check above fails. | Relevé incohérent, rien n'est importé : *the check in cause*. |
| `IMPORT_TOO_LARGE` | The file is over 10 MiB. | Ce fichier dépasse 10 Mo. |
| Server too old | `/healthz` has no `importFormats`. | Le serveur (version …) est trop ancien pour importer des relevés. |
| Server unreachable | The server does not answer while the file is sent. | Le serveur ne répond plus : le relevé n'a pas été envoyé. |
| Account not detailed | Import is not enabled on the account. | Ce compte n'est pas détaillé : activez l'import du compte pour y importer ses relevés. |
| Other format | The account imports another format. | Ce relevé n'est pas au format d'import de ce compte. |
| Already imported | The account holds the statement of this file (its identifier is computed from the account and the fingerprint). | Ce relevé est déjà importé. |
| Other account | The IBAN differs from the account's latest statement. | Ce relevé est celui d'un autre compte : IBAN …, alors que les relevés précédents portent l'IBAN …. |
| Not contiguous | It does not start the day after the latest statement, or its opening balance is not that one's closing balance. | Ce relevé ne suit pas le précédent : il commence le … avec un solde de …, alors que le suivant doit commencer le … avec un solde de …. |
| Sum | Its lines do not add up to the difference between its balances. | Les lignes du relevé ne donnent pas l'écart entre ses soldes initial et final. |
| Too large | It would not fit in one modification (about 1 200 lines). | Ce relevé compte trop de lignes pour être importé en une fois. |

### The PostFinance format

The only format is PostFinance, PDF, in French; each format is a module of
the server (`internal/infrastructure/extraction/postfinance`). The text comes
from `pdftotext -layout -enc UTF-8 - -`: the PDF on standard input, the text
on standard output, without a shell, within 30 seconds and 8 MiB of text.
`pdftotext` 24.02 (Ubuntu 24.04) and 25.12 (the image) give the same text.

The text is read line by line: the period
(« Extrait de compte dd.mm.yyyy - dd.mm.yyyy »); the IBAN, the same on every
page, and the currency printed after it on the first page; « Etat de
compte » with the opening then the closing balance, « Total » with the
printed totals; the header « Date Texte Crédit Débit Valeur Solde » of each
page, since an amount belongs to the credit or debit column whose header it
ends nearest to, in characters, and columns move from page to page. A movement is its booking date (only on the
first movement of a day, so a day can go on over a page without it), the
first line of its text, its amount, its value date, the balance after the
last movement of the day, then the following lines of text. The page
furniture is removed from the texts: the form code printed vertically in the
margin, « Page n / m » and the header block repeated on each page. An amount
that pdftotext puts on a line of its own, after the vertical form code (when
the code's top falls between the top of a label and the top of its amount),
takes the line above as its label, and the date on its line if any.

A line's amount is signed (positive for a credit), its date is the booking
date, its raw text the bank's text with its lines separated by line breaks.
Its **short label**, the initial description, is that text on one line,
without the generic lines when the first is a type of operation the module
recognises (upper-case words ending with « DU » and maybe a date, or
« DÉBIT », « CRÉDIT », « CRÉDIT POSTFINANCE CARD », « PRIX POUR »): that
first line, the date on the next line, the card line (« CARTE NO … »,
« CARTE N° … »), the IBAN of the other party and « DONNEUR D'ORDRE: ». The
raw text never changes; the rules read only it. If the bank changes its
layout, the statements are refused (`layout` or `IMPORT_UNKNOWN_FORMAT`)
rather than read wrongly: the checks of balances and totals catch a line
read in the wrong column.

### The lines in the app

- A `statement` (account, format, IBAN, period, balances, fingerprint) and
  one `transaction` per line (account, date, amount, raw text, description,
  status, statement, rank), with identifiers computed from the account, the
  fingerprint and the rank: two devices importing the same file write the
  same records, never a line twice.
- On the detailed account, the amount, date, account and raw text of a line
  never change, and no line is entered or deleted by hand; category, period,
  description and note change.
- The rules of a year match the raw text of a line: every keyword, without
  case, accents or repeated spaces, or `re:` for a regular expression. The
  rule with the most keywords wins; a tie of different results is a
  conflict. Rules follow the copy of a tree.
- A line is « à valider » or « validée ». For a line to validate, the
  classification shown and counted in the totals is computed at each load
  from the rules of its year, never stored: « proposée » when one result
  wins, « à compléter » otherwise (no rule, a conflict, or a winning rule
  whose target can no longer be used). Creating or modifying a rule writes
  only the rule.
- Validating writes the category and period, or the counterpart account of a
  transfer, and the status. A transfer keeps the statement's sign: negative,
  the money goes to the other account; positive, it comes from it.
- « Supprimer le dernier relevé » (Relevés du compte) deletes the latest
  statement of the account and all its lines, after a confirmation; only the
  latest, so that the others stay contiguous. It can then be imported again.

### The original files

The server keeps each accepted file as `statements/<fingerprint>.pdf`. The
fingerprint is in the journal's statement, which is all the app needs to
fetch it again: Relevés du compte › « Enregistrer le PDF d'origine »
([`GET /api/v1/imports/{fingerprint}/pdf`](api.md#get-apiv1importsfingerprintpdf)).
A server rebuilt since the import no longer has the file: the app says so,
without error. Losing the original files is accepted.

### Copies of the server database

Before it stores a file it did not hold, the server writes a consistent copy
of its database while it runs (`VACUUM INTO`), as
`backups/batz-<UTC time>.db`, and keeps the latest `BATZ_BACKUPS` (12 by
default). A file it already holds writes no copy.

To restore one, for instance after an import made by mistake before the
devices exchanged it: stop the server (`docker stop batz-web`); in the data
directory, move `batz.db`, `batz.db-wal` and `batz.db-shm` aside and copy the
chosen `backups/batz-….db` to `batz.db` (owned by uid 10001, like the rest
of the folder); start it again (`docker start batz-web`). The certificate
stays (it is in `tls/`); the paired devices are those of the copy's date, so
a device paired since must pair again. The devices then send what the copy
lacks: a restored copy removes nothing from them. To undo an import on every
device, delete the last statement in the app instead.

### The fictitious test set

No real statement is committed. The generator in `…/postfinance/fake` writes
the test set (`…/postfinance/testdata`): PDF files laid out with the
positions measured on real statements (header block, columns, line height,
form code in the margin, page numbers), where only the geometry and the
bank's own formulas (« ACHAT/SERVICE DU », « CARTE NO », …) are real and
every name, place, amount and number is invented, each with the JSON the
extraction must give. It holds three consecutive months, a statement of
another account continuing them, three altered statements (a movement
amount, a total, a closing balance) and an invoice; it covers a day going on
over a new page without its date, labels of up to five lines, and an amount
that pdftotext separates from its label. `TestFixturesAreUpToDate`
regenerates the set and compares it byte for byte (`-update` rewrites it).

`batz-web extract <file.pdf>` prints the JSON of the result (exit code 2 when
the statement is refused; `-summary` prints only the verdict and the number
of lines, `-amounts` the date and amount of each line). CI runs it on every
file of the set inside the server image and compares the output with its
JSON.

## Security

batz is made for one person, on their own devices and a server on their home
network. It has no login and no account: a device is trusted because it was
paired once, by someone who could read a code on the server.

### What protects what

| Threat | Protection |
|---|---|
| Someone on the home network listens to the exchanges | HTTPS only; the app pins the server's certificate when it is paired and refuses any other afterwards. |
| Someone on the home network talks to the server | Every route but `/healthz` and the pairing asks for the key of a paired device. Pairing takes a one-time code, valid 10 minutes, that only someone with access to the server can obtain; the server keeps the hash of each key, never the key. |
| A device is lost or sold | It is revoked from any other device (Plus › Serveur): its key is refused from then on. Its local copy of the data stays on it: see the next lines. |
| Someone picks up the unlocked phone | The Android app opens behind the lock of the phone, and locks again after more than a minute away ([below](#the-android-lock-in-short)). |
| Someone looks at the recent apps of the phone | From Android 13 on, the list shows no picture of the last screen of batz. |
| Someone copies the files of the phone | The Android database is encrypted with a key kept by the Android Keystore; the app refuses to start rather than store data unencrypted, and is excluded from Android backups. |
| The server is reachable from the Internet | It is not meant to be: nothing in batz opens a port or contacts a third party. The app reaches the server by its address on the home network. |
| The server process is compromised | The container runs as an unprivileged user, read-only, without capabilities, and writes only in its data folder. Its only external tool is `pdftotext`, run on the statements it is sent. |
| A statement carries a text made to run as a spreadsheet formula | In an export, a text that starts with `=`, `+`, `-` or `@` is preceded by an apostrophe. |
| Personal data or secrets reach the public repository | Git ignores statements, personal configurations, keys and exports, and CI fails when such a file is tracked (PDF and CSV files only as test data). The Android signing key lives in the secrets of GitHub. |

### What is not protected

- **Computers.** On Windows and Ubuntu the app has no lock and its database
  is not encrypted: they rely on the session and the disk encryption of the
  system, which also keeps the device key (DPAPI, the Secret Service).
- **The export.** `batz-export-*.zip` holds everything, unencrypted, wherever
  it is saved; the screen says so before exporting.
- **The server's data folder.** The journal, its dated copies and the
  original statements are plain files on the NAS.
- **A phone unlocked and in hostile hands for long.** The lock is a door in
  front of the screens; the database key is not bound to the unlocking, so a
  rooted or compromised system could read the data while the phone is on.
- **A phone without screen lock**: there is nothing to ask; the app opens,
  and its home screen says so until a screen lock is set.
- **Android 12 and earlier** keep the picture of the last screen in the
  recent apps. Screenshots are possible on every version.
- **The clock of the devices**: see [known limits](#known-limits).
- **Losing everything at home.** No copy leaves the home network. Each device
  holds the whole journal and can rebuild the server; the original PDF files
  exist only on the server.

### The Android lock, in short

- `LockGate` stands in front of the navigator and draws none of the screens
  while `LockCubit` says the app is locked: at opening, and when it comes
  back after more than 60 seconds away (or the phone's clock went back
  meanwhile). Choosing a PDF or saving an export within a minute does not
  lock.
- `DeviceLock` (`local_auth_android`) shows the dialog of Android:
  fingerprint, face, or the phone's PIN, pattern or password. A cancelled or
  refused dialog leaves the app locked, with a button to try again; an
  unexpected error is shown.
- The screen in progress and what was being typed are found again after
  unlocking; the synchronisation goes on behind the lock.
- Always on: there is no setting to turn it off.

## Tests

CI runs these tests on every push to main and every pull request; the app's
end-to-end tests run against a real `batz-web` binary built for them.

| What | Where |
|---|---|
| Server: entry shape, pages never cutting a modification, `since`, sizes and versions, a page refused as a whole and accepted twice without duplicate | `batz-web/src/internal/domain/journal`, `internal/application`, `internal/infrastructure/web` |
| Server: extraction of every fictitious statement against what its generator printed, each check; the import route (refusals, the same file twice, 12 copies kept, the original file, logs without statement text) | `internal/infrastructure/extraction/postfinance`, `internal/application`, `internal/infrastructure/persistence`, `internal/infrastructure/web` |
| Server binary over HTTPS: pairing, refusals, revocation, restarts, certificate pinning, an exchange between two simulated devices, `extract`, an import | `batz-web/src/test/e2e` |
| App domain: the clock, the resolution rule, the ledger's rules, allocation with random amounts and periods, rules and search, Swiss formats | `batz-ui/test/domain`, `test/helpers` |
| Annual view, wealth, modules: worked examples, then properties on random ledgers (the twelve months of every line, the identity of the period offsets, each wealth table adding up to the change of the wealth, the flow diagram balanced, the tax total against its lines, …), and no module entry changing the views or the wealth | `test/domain/views`, `test/domain/modules` |
| Export: an example ledger against its expected files, the format read back by another reader, every record of random ledgers in its file, the completeness of the schema | `test/domain/export` |
| Journal: a naive reference model on shuffled histories from three devices; deletion, restarts, failed transactions, derived schema changes, the ledger rebuilt from the journal; databases written by versions 0.1.0 to 0.7.0 (`test/fixtures`) | `test/data`, `test/data/upgrade_test.dart` |
| Exchange: known state, pages, gap refused, copies holding a prefix of every origin; the engine (restart after a state change, protocol errors, clock offset, a device used separately) | `test/data/journal_exchange_test.dart`, `test/data/sync_engine_test.dart` |
| Screens, with servers in memory where needed; the lock with a simulated phone and clock, and what it asks of the Android manifest | `test/pages`, `test/android_manifest_test.dart` |
| Against a real server: pairing; concurrent edits, deletions, a cut exchange, merge and replace; revocation, a rebuilt server, a restored copy; the import of the fictitious statements; the records of every feature sent between devices; two devices exporting the same files | `test/e2e` |
| Convergence: random operations of the app on four devices with skewed clocks, random exchanges, random cuts | `test/e2e/convergence_e2e_test.dart` |
| Performance: every reload after a write, the year views, « Fortune », each module screen and the export with 10 000 transactions, 100 balances and 200 debts; the writing of an import and of a bulk confirmation | `test/data/performance_test.dart`, `test/data/write_performance_test.dart` |

The performance test runs alone: every test file holds a shared lock that the
measurement takes exclusively. `batz-ui/benchmark/`, run by hand, measures a
first exchange of 20 000 entries and the writing of 1 000 fields.
