# Decision log

Technical decisions behind batz, by topic, each with the fact that settled it.
What the app does and computes is described in [features.md](features.md), how
it is built in [architecture.md](architecture.md). Checks and measures were
made on the development machine (Intel Core i7-14700KF) in November 2026.

## Local storage

### Drift, with SQLCipher on Android only

`drift` 2.35 on `sqlite3` 3.9, whose Dart build hooks bundle the native
library: `batz-ui/pubspec.yaml` picks `sqlcipher` on Android (encrypted) and
plain `sqlite3` elsewhere. The key, set with `PRAGMA key` in Drift's `setup`,
is created on first launch and kept by `flutter_secure_storage` (Android
Keystore). `sqlcipher_flutter_libs` and `sqlite3_flutter_libs` are end of
life since February 2026. Checked 2026-11-20: the file does not open with a
wrong key. SQLCipher adds OpenSSL (about 5 MB per ABI); `sqlite3mc` is a
drop-in fallback through the same option.

### Design rules of the derived tables

The derived tables materialise the journal, one per entity:

1. **No constraint** (uniqueness, foreign key, NOT NULL): entries from other
   devices arrive field by field, in any order, and integrating them must
   never fail. The domain checks business rules when the user enters data.
2. **An incomplete record is ignored when read**, without error, until its
   missing fields arrive; an unknown value written by a newer version makes
   it unreadable rather than misread.
3. **They never migrate.** Each is a `DerivedTable` whose `CREATE` statements
   are generated; their text is kept in `local_state`, and when it differs at
   start, `Journal.open` drops, recreates and recomputes every derived table
   from the journal in one transaction, with no version number to maintain.
   Only the journal tables migrate (Drift's `schemaVersion`).
4. **Calendar dates** (`YYYY-MM-DD`) and **no floating point**: amounts are
   integer cents, percentages hundredths of a percent, weights fractions.

### The domain works on an in-memory snapshot

`LedgerRepository.load` reads every derived table into an immutable `Ledger`
(rows `ORDER BY id`: physical order differs between devices); operations
check their rules against it and return the `Modification` to write. One
person's data fits in memory for years, and the rules test without a
database. Views, balances, wealth and modules are computed from it, cached
per ledger with an `Expando`, never stored: nothing can go stale.

## The journal

### The hybrid logical clock rolls over instead of failing

A full counter moves the clock to the next millisecond. A device whose clock
runs ahead makes the others adopt its time; failing at 65 536 writes would
block them until their wall clock caught up.

### A modification writes only the fields whose value changes

`Journal.write` compares each field with the exact JSON value of the entry
that set it (`true` and `1` stay different) and writes only those that
differ; a field never set is written, even to `null`. Screens submit every
field: otherwise an unchanged field would overwrite another device's change.

### A modification is written in a few statements

Changes go into a temporary table, those already current are deleted in one
statement, the rest is inserted under one timestamp, and the derived tables
are updated by the set-based statements that also integrate received entries
(see [measures](#reference-measures)). A modification holds at most 10 000
changes, the largest page the server accepts, since pages never cut one.

### Computed identifiers for records two devices may create

Such a record gets an identifier derived from what defines it (name-based
SHA-256 UUID, `domain/ids.dart`), so two devices write one record: tree
copies (source category and year), copied rules, statements (account and
fingerprint) and their lines, the category line of an imported transaction
(`<transaction>-line`), answers to shares (line and year), declared balances
(account and date), module settings and module records tied to a year or a
line. Records only one device creates get random identifiers.

## Server storage

### `modernc.org/sqlite` with golang-migrate

`modernc.org/sqlite` (pure Go) with golang-migrate's `database/sqlite` driver
and migrations embedded through `source/iofs`. With `CGO_ENABLED=0` (v1.62.0,
v4.20.1) the binary is static and the image needs no system SQLite.
`go test -race` still needs cgo, present locally and on GitHub runners.

### Imports run one at a time, with a copy of the database first

Before storing a file it does not hold, the server copies its database with
`VACUUM INTO` into `backups/` (named by UTC time to the millisecond; the
oldest beyond `BATZ_BACKUPS`, 12 by default, are deleted), then writes
`statements/<fingerprint>.pdf` under a temporary name and renames it. A
refused statement is neither stored nor backed up. The server refuses nothing
as already imported: the app decides from its journal.

## Synchronisation

### What an exchange checks

The protocol is in [architecture.md](architecture.md) and [api.md](api.md).

- A value travels as the JSON text of the field; the server checks it is one
  scalar the journal accepts (at most 256 KiB) and never re-encodes it.
- A page carries `since`, the receiver's known timestamp per origin; one that
  continues from more than the receiver holds is refused
  (`409 SYNC_STATE_CHANGED`): it would leave a gap, e.g. after the server was
  restored from an older copy between two calls.
- An unknown field is a bad request, so a newer app is never half
  understood. Each exchange is one `BEGIN IMMEDIATE` transaction with
  `ON CONFLICT DO NOTHING`: serialised, and a replay adds nothing.

### The sync engine adds no table to the app

An entry's origin is the end of its timestamp (`substr(hlc, 22)`), the known
state a `GROUP BY` over it, and what the other side lacks is selected with
`json_each`. Pages are integrated by a few set-based statements, not one
round trip per entry (20 000 entries: 66.7 s down to 3.0 s). Screens reload
outside the exchange's error handling: a failed reload is not a sync error.

### Replacing a device's data, and a lost server

The merge-or-replace question comes when device and server both hold entries
and share no origin, which only happens before their first exchange: no flag
is stored. « Remplacer » erases the local journal in one transaction with the
first page and takes a new device identifier, so later entries never follow
erased ones under the same origin. A revoked device keeps its data; a server
reinstalled or restored from a copy is rebuilt by the devices' next exchanges.

### Inconsistencies after a merge are tasks, never refusals

Duplicate category names, detached categories, rules that no longer apply,
broken refund links, overlapping tranches: all computed on the snapshot and
listed as tasks; only an entry that would create one is refused.
Detached categories are kept, never dropped, and only move under a category
of their year's tree, so a move cannot create a loop.

### Known limits of offline edits

- A tree copy writes every field: if device A copies a year then renames a
  copied category, and device B copies the same year offline later, B wins.
- The same debt split on two devices keeps both second parts; the user
  deletes one. A second part derived from the first would let a later split
  overwrite an earlier part.
- The salary sheet of one year created on two devices is one sheet, but both
  sets of deductions are kept; the user removes the extra ones.
- Two sheets on one trip: the oldest line's applies. Overlapping subscription
  tranches: the one that started last applies. Both are shown.

## Import of statements

### `pdftotext` in the server image

`poppler-utils` from Alpine 3.24 (`pdftotext` 25.12.0), run without a shell,
PDF on standard input and text on standard output: the container stays
read-only, and the image grows from 34.6 to 58.4 MB. `-layout` gives
byte-identical text with 24.02 and 25.12, so word coordinates are not
needed. Limits: 30 seconds, 8 MiB of text. CI jobs that run the Go tests or
the app's end-to-end tests install `poppler-utils`.

### Extraction of PostFinance statements

It keeps the original Python script's method (columns placed by the end of
the « Crédit » and « Débit » headers, in characters), with corrections:
page furniture is removed from texts; an amount alone on its line takes the
line before as label and keeps the date printed on its line (the script kept
the previous date, a defect confirmed on a real statement 2026-11-21); the
2025 and 2026 layouts are both read. No message or log holds its text.
The test set comes from a Go generator (`extraction/postfinance/fake`) that
draws PDF files with the geometry of real statements and invented content;
`TestFixturesAreUpToDate` regenerates it byte for byte.

### Neon exports: the format told by the content, the lines by theirs

The server tells the format by the content (`%PDF-`, or a CSV header naming
Neon's columns): one route, no format to send, and `/healthz` lists both.
A Neon export prints no balance, no total, no IBAN and no period, so these
fields of the answer are optional and absent for it, and the app asks the
balance the bank shows. Exports overlap (the year so far, again two weeks
later): a line is identified by its account, date, amount, raw text and
rank among the identical lines of the file, and only new lines are written.
The raw text leaves out what the user can change in Neon or what can vary
(category, tags, exchange rate); changing how it is built would import every
line again, so it is frozen. The period of an import runs from the day after
the previous one to the day of the import: imports stay ordered, the latest
one alone can be deleted, and one import a day is the price. The balance
typed is checked like the continuity of a statement: the previous closing
balance plus the new lines must give it.

### Several detailed accounts; transfers between them paired at load

One detailed account was the rule of the MVP; Neon makes two. A transfer
between them is two lines, one per statement, each a transfer to the other
account, and each counts on its own account only. The pairing is computed at
each load from the amounts, signs and dates (7 days at most, by date then
identifier), like the proposals: no journal field, so no link to break when
a statement is deleted or two devices merge. A transfer without its other
side arrives on the other account as before, so the wealth stays right
until the other statement is imported, and becomes a task after 10 days.
Validating one side validates the other side if it is to validate, in the
same modification; a bulk confirmation writes each line once.

### Sending a file with Dio

The file is the raw body of `POST /api/v1/imports` (`application/pdf`), not
a multipart form: one file, read without parsing a form. Dio 5.11.1 delivered
300 000 bytes unchanged.

### Choosing and saving a file: `file_picker`

`file_picker` 13.4.0, the only package that both picks and saves a file on
Android, Windows and Ubuntu: the system document picker on Android (no
storage permission), the XDG portal over D-Bus on Ubuntu (no `zenity`),
native dialogs on Windows. `file_selector` cannot save on Android. It serves
the statement to import (PDF or CSV), the original file and the export.

### Mapping rules and proposals

The lines of a rule are one field, `lines`, holding a JSON list (the journal
holds scalars). Lines are alternatives because « or » is the common case;
`ET` joins required terms and is read only in capitals between spaces, so a
shop called « Bar et Café » needs no escape. Rules written before 0.9 keep
their `keywords` field (all required) and read as one line `a ET b`: no
entry of the journal is rewritten, and a modification writes `lines` and
clears `keywords`. Text and terms are compared lower-cased, without accents,
whitespace collapsed, so a term spans lines; a `re:` term keeps its case
(lower-casing turns `\S` into `\s`) and matches without case. The weight
of a rule is the number of terms of its heaviest matching line; the
heaviest rules win, and a winning rule whose target is unusable proposes
nothing rather than let a weaker rule decide. Rules propose the payment
date only: the period models of 0.8 (« mois suivant »…) are no longer read,
and a period that differs is set on the line. Only `toValidate` and
`validated` are stored: proposals are computed at load, so writing a rule
writes only the rule. Deleting a category deletes the rules that classify in
it, in the same modification; the redistribution rules still refuse it.

## Ledger rules

### Manual entries refused on the detailed account and on debts accounts

`Ledger._checkManualAccount`. A detailed account is fed only by statements:
it is refused on both sides of a manual transfer, since a transfer from cash
to it would be counted again when the statement showing the deposit is
imported. A debts account refuses manual expenses and incomes (it changes
only through the debts table) but accepts transfers: a pure loan is a
transfer to, then from, « Dettes ». Neither takes a declared balance.
Imported lines refuse manual changes, even if import was disabled since.

### Category trees

Names compare trimmed, lower-cased, without accents (`normalizeName`).
Top-level groups hold no transaction and alone store the nature. The first
transaction of a year without a tree writes the copy of the tree in the same
modification. A category with children, or used by a rule, is not deleted.

### Allocation, periods and rounding

`allocate` weighs each month with an exact `Fraction` (BigInt): 14 March to
13 March is exactly twelve months, with no tolerance in tests. Shares round
to the cent, halves away from zero, the last month taking the remainder; a
negative amount is allocated as its opposite then negated. Month arithmetic
clamps as `java.time` does (one month from 31 January ends on 27 February).
Every other rounding (redistribution, debts, taxes, ratios) is the same.

### Split transactions: every line written, by its identifier

A split adds no field: a transaction holds one `transactionLine` per
category, and the views already counted each line. The draft carries every
line with its identifier, so a modification rewrites the lines it keeps and
deletes the others, and what refers to a line (refund, kWh, answer, trip
sheet) stays attached. The domain refuses lines that do not add up to the
amount. The ledger keeps lines largest first: the first, the main line,
gives the type; an imported line keeps `<transaction>-line` for its first
line. A refund line holds one link, so a refund is never split and
attaching one deletes its other lines. Rules never propose a split.

## Computed views

### One calculation for both annual views

`domain/views/year_view.dart` turns each line into a flow; the cash-flow view
places it at its payment month, the economic view each monthly share, and the
rest is shared code. A validated transaction whose lines do not add up to its
amount counts the difference unclassified, so cash-flow result plus « Non
classé » stays the sum of the payments. Redistribution rules are checked
again at each load: one that no longer applies is kept and listed. The view
chosen is kept per device in `local_state`, never in the journal.

### Fixed amounts of redistribution follow the payments

A fixed amount is taken per payment, not per month: a month with two rent
payments in the cash-flow view, or a payment covering two months, then
moves the right amount. In the economic view it is spread with the same
allocation as the payment. Fixed amounts come before percentages, which
apply to what remains, so a source never changes sign. Refunds give nothing:
a refund of the rent pays no charges.

### Documents: on the server, copied on every device

The journal holds scalars; a file in it would weigh on every exchange and
stay in its history. The server keeps the files under their fingerprint, as
it keeps the original statements; every device keeps a copy in a table of
its local database (encrypted on Android), downloaded after each exchange,
because the server is only on at home and not always: a document must open
on the phone away from home. Adding a document needs the server; nothing
is uploaded later. A document deleted keeps its file on the server, which
does not read the journal.

### Opening a document: `open_filex`, without its permissions

`url_launcher` opens links everywhere and files on the desktops, but not a
file on Android, which needs a FileProvider: `open_filex` 5.0.0 brings one.
It also declares the access to the storage and to the photos, videos and
music of the phone; the app opens only files it wrote in its own temporary
folder, so the manifest removes them (`tools:node="remove"`), and a test
keeps them out.

### Monthly follow-up: boxes stored only when touched

A task linked to a detailed account is checked by its imports, computed at
each load from the end of its latest statement, so importing writes no box
and deleting a statement unchecks again. Only the boxes the user touched are
stored, under an identifier computed from the task and the month (two
devices write one record); a task applies from a month of its own, so a task
added later leaves the earlier months finished. A box stays checkable by
hand on a linked task (a month without statement), never uncheckable once
the imports checked it.

### Accounts: a position written on the first move

`position` is absent until the user moves an account; then every account of
the list (active or archived) gets one, so later moves and merges keep a
definite order (ties fall back on type, name, identifier). The default order
is by type then name, the order « Fortune » already grouped by: the first
move changes nothing else. « Déclaré aux impôts » is a field of the account,
shown only as a colour (the tertiary colour of the theme) and a legend.

### Debts linked to transactions

A debt stores `sourceTransactionId` and `refundTransactionId`; the
transactions store nothing. The date of invoice is copied from the source
transaction at each write of the debt, the date of receipt from the
repaying transaction when it is linked, so the wealth keeps reading dates of
the debt alone. Repaying a debt owed to me attaches the transaction as the
refund of the source expense through the ordinary refund link, in the same
modification: the expense shows its net cost and the views need nothing
new. A transaction deleted leaves the link dangling and the debt as it was.

### Refunds: one link, followed one step

A line stores only `refundedLineId`, followed one step: a chain written by
two devices never reaches an expense, so nothing recurses. Deleting the
expense breaks the link without error and makes it a task. Classifying a
line clears its link, so a line brought back never revives an old one.

### Answers to shares to classify follow the line

A line to validate carries `<transaction>-line`, the identifier validation
will give it, so an answer given before validation still holds. An answer is
read only when no category of the same name exists: a rename that restores a
name makes it unused, never wrong. Pending shares take one pass over the
amounts that change year, not a placement of every year.

### Balances and wealth go through one function each

A balance is a point (declared balance, or opening of the first statement)
plus later movements, summed by date with running totals and binary search;
the wealth at a date sums the accounts that hold a balance and the open
debts. Accounts, curve and table use them; the table's lines are computed
apart and tests check they add up. Today is passed in (`AppServices.today`),
so the rules test without a clock.

### Modules read the annual view and never change it

`YearViews.linesIn` gives the lines of a category and below, month by month,
before redistribution; `linesNamed` those of a category name across years. A
line to validate is named by the identifier it will get, so kWh or a trip
sheet survive validation. A module's category is a name looked up in each
year's tree. Modules are computed when their screen asks, never at reload.

## Export

### Writing the ZIP: `archive` 4.7.1

`archive` 4.7.1 (MIT; its new dependency `posix` 6.5.4 is MIT), pure Dart on
every platform. Only `package:archive/archive.dart` is imported, never
`archive_io.dart`: the ZIP is built in memory and handed to the `file_picker`
save dialog, so nothing is written elsewhere. Entries carry their build time:
two exports give the same CSV files, not the same ZIP bytes. Tests read
exports back with `ZipDecoder().decodeBytes(…, verify: true)`.

### The CSV files are complete and deterministic

`exportSchema` maps every field of every entity to a column (only the
deletion field is left out); `export_completeness_test.dart` compares it with
the derived tables, so a field added later and not placed fails. Rows sort by
their own data, identifiers last, so two synchronised devices write the same
bytes. Fixtures are `-text` in `.gitattributes`; `.gitignore` ignores
`batz-export-*.zip` and `batz-export-*/`.

## Android lock

### `local_auth_android` and its platform interface only

The app depends on `local_auth_android` 2.3.0 (BSD-3-Clause; brings
`androidx.biometric` 1.1.0) and `local_auth_platform_interface` 1.1.0,
through `LocalAuthPlatform.instance`: same dialog and error codes as
`local_auth` 3.0.2, which brought `local_auth_windows` 2.0.2 into the Windows
build, refused by the CI compiler (MSVC 14.52, `STL1011` under `/await`).
batz never locks on desktops; `test/data/device_lock_test.dart` checks that
nothing of the plugin reaches the Windows and Ubuntu builds.

### What `local_auth` asks of the Android app

From the « Setup » section of the `local_auth_android` 2.3.0 README and its
sources (read 2026-11-21), checked by `test/android_manifest_test.dart`:

- `MainActivity` extends `FlutterFragmentActivity` (else
  `NOT_FRAGMENT_ACTIVITY`).
- The main manifest declares `USE_BIOMETRIC`, though the plugin's merges it.
- The launch and normal themes have `Theme.AppCompat` parents, « to prevent
  crashes on Android 8 and below »: Flutter swaps the launch theme for the
  normal one, under which the dialog opens.
- `biometricOnly: false` falls back to the device's code;
  `persistAcrossBackgrounding` stays false, the app's gate decides.

### How the lock decides

It uses the wall clock (a monotonic one stops while the phone sleeps; a clock
gone back locks) and counts leaving as the app hidden, not a loss of focus.
`LockGate` in `MaterialApp.builder` keeps every route behind it, `Offstage`,
so typed text survives; `LockedBackGuard`, asked before the navigator, makes
« back » close nothing while locked. The database key is not bound to
unlocking. No emulator runs here: the dialog is checked on a phone.

## Versions and releases

### Versions with a suffix, build numbers and tags

The suffix belongs to the version name: `0.8.0-alpha+9` gives `appVersion`
(kept equal to `pubspec.yaml` by a test) and the tag `v0.8.0-alpha`, so
Obtainium reads the same version in the tag and in the app; the server image
takes its version from the tag. The build number exceeds that of every
earlier `v*` tag, as Android refuses an update that does not raise it.
Comparisons ignore what follows the three numbers. Releases are not
pre-releases, which Obtainium skips; see [deployment.md](deployment.md).

### The minimum app version follows the journal entities

The server's minimum app version rises when a version adds journal entities
or fields that change what is shown: an older app would keep them unapplied
and show other totals. It also rises when an older app would break what a
version writes. It is 0.11.0: 0.11.0-alpha imports Neon exports, and an app
0.10 would leave out an account of the format `neon` with its transactions
and count a transfer between two imported accounts twice. 0.10.0-alpha
split transactions: an app 0.9 modifying a split transaction would rewrite
its main line with the whole amount and keep the others. 0.9.0-alpha had
added rule lines, fixed
amounts of redistribution, account positions and their tax flag, notes of
balances and the links of debts; an app 0.8 would read a rule without
keywords as unusable and a fixed amount as a rule without percentage.

## CI and tests

### GitHub Actions, Windows included

Standard runners (`ubuntu-latest`, `windows-latest`) are free and unlimited
for public repositories (GitHub documentation, read 2026-11-20). Artifact
storage is capped at 500 MB, so build artifacts are short-lived; release
assets do not count. Windows is built by CI only.

### The performance test runs alone

Every test file holds a shared machine lock (`test/support/machine_lock.dart`,
an advisory file lock). `test/data/performance_test.dart` holds it exclusive
for its whole body, data written included, and waits for quiet processors.
Every one of ten runs must stay below its limit. Among concurrent files and
servers the same reload took 100 ms to 3.9 s, and data written before taking
the lock were swapped out (9 GB of memory).

### End-to-end tests run real servers

`test/e2e/` builds `batz-web` and runs real servers concurrently: a server
counts as started once it logs that it listens, another port is tried if the
bind failed. Their binaries and directories are deleted when each file ends
(289 leftovers once filled 11 GB of `/tmp`). Tests wait for events
(`SyncCubit.whenIdle`), never fixed delays.

### Reference measures

Database in a background isolate as in production, 2026-11-20/21. Data of
`test/support/large_ledger.dart`: 10 360 transactions over five years, 200
rules, 12 accounts, 100 balances, 200 debts, every module. Benchmarks run by
hand (`flutter test benchmark/…`); the tests fail beyond their limit.

| Measure | Test | Result | Limit |
| --- | --- | --- | --- |
| First exchange, 20 000 entries | `benchmark/first_exchange_test.dart` | sent 2.9 s, received 3.0 s | — |
| Journal write, 1 000 fields | `benchmark/journal_write_test.dart` | 51–71 ms (was 3.4–4.5 s) | — |
| Import of 100 lines | `test/data/write_performance_test.dart` | 105–113 ms | 1 s |
| Confirmation of 500 proposals | `test/data/write_performance_test.dart` | 120 ms | 1 s |
| Reload after a write | `test/data/performance_test.dart` | 87–127 ms | 300 ms |
| Both views of a year | `test/data/performance_test.dart` | 7–28 ms | 100 ms |
| « Fortune » screen | `test/data/performance_test.dart` | 11–36 ms | 100 ms |
| Each module and the flow diagram | `test/data/performance_test.dart` | 0–42 ms | 100 ms |
| Export, 17 files and the ZIP | `test/data/performance_test.dart` | 306–372 ms | 2 s |
