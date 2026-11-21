# Decision log

Technical decisions taken during development, with the evidence behind them.
Functional decisions live in `specification.md`.

## 2026-11-20 — Phase 0 technical checks (specification, chapter 14)

All three leads named in the specification were confirmed. No alternative had
to be submitted.

### 1. Local database: Drift, with SQLCipher on Android only

**Decision.** `drift` 2.35 on top of `sqlite3` 3.9. The `sqlite3` package
bundles its own native library through Dart build hooks and lets the app pick
the build per operating system in `pubspec.yaml`:

```yaml
hooks:
  user_defines:
    sqlite3:
      source:
        android: sqlcipher   # SQLCipher community edition, encrypted
        default: sqlite3     # upstream SQLite, plain, on Linux and Windows
```

The encryption key is set with `PRAGMA key` in Drift's `setup` callback, and the
key itself is created on first launch and kept by `flutter_secure_storage`
(Android Keystore).

`sqlcipher_flutter_libs` and `sqlite3_flutter_libs` are end of life since
February 2026 (`0.x+eol` on pub.dev): the hook options replace them.

**Evidence** (throwaway Flutter project, Flutter 3.47.7):

- With `source: sqlcipher` on Linux, `PRAGMA cipher_version` returns
  `4.20.0 community`. A Drift database written with a key has no
  `SQLite format 3` header; opening it without a key or with a wrong key fails
  (`hmac check failed for pgno=1`); reopening with the right key reads the row
  back.
- With the per-OS map above, the same test on Linux reports no
  `cipher_version`: plain SQLite.
- `flutter build apk --debug --target-platform android-arm64` succeeds and the
  APK contains `lib/arm64-v8a/libsqlcipher.so` (ELF aarch64, exports
  `sqlcipher_export` and `cipher_version`).
- Not checkable on this machine: running the encrypted database on a real
  Android device. It is covered by the user's install check at the end of
  phase 0.

**Notes.** The SQLCipher build links OpenSSL on Android (about 5 MB per ABI)
and may lag behind upstream SQLite by a few versions. SQLite3MultipleCiphers
(`source: sqlite3mc`) is a drop-in fallback through the same option.

### 2. Server SQLite: `modernc.org/sqlite` with golang-migrate

**Decision.** `modernc.org/sqlite` (pure Go, driver name `sqlite`) with
`github.com/golang-migrate/migrate/v4/database/sqlite`, the golang-migrate
driver written for it, and migrations embedded with `source/iofs`.

**Evidence** (throwaway Go module, Go 1.27.2): with `CGO_ENABLED=0`,
`modernc.org/sqlite` v1.62.0 and golang-migrate v4.20.1 apply an embedded
migration (`version 1, dirty=false`, SQLite 3.54.1) and the test binary is
statically linked. The dependency graph contains no `mattn/go-sqlite3`.

**Notes.** The server image is built with `CGO_ENABLED=0` and needs no system
SQLite. `go test -race` still requires cgo, which is available on the
development machine and on GitHub runners.

### 3. GitHub Actions is free for this public repository, Windows included

**Decision.** CI and releases run on standard GitHub-hosted runners
(`ubuntu-latest`, `windows-latest`).

**Evidence** (official documentation, read on 2026-11-20):

- <https://docs.github.com/en/actions/how-tos/write-workflows/choose-where-workflows-run/choose-the-runner-for-a-job>,
  section "Standard GitHub-hosted runners for public repositories": "Use of
  the standard GitHub-hosted runners is free and unlimited on public
  repositories." The table lists `windows-latest` (4 CPU, 16 GB RAM) next to
  `ubuntu-latest`.
- <https://docs.github.com/en/billing/concepts/product-billing/github-actions>:
  "The use of standard GitHub-hosted runners is free: In public repositories".
  Only larger runners are billed for public repositories.
- <https://docs.github.com/en/actions/reference/limits>: 6 hours per job,
  20 concurrent jobs on the Free plan, 10 GB of cache per repository.

**Notes.** Artifact storage is capped at 500 MB on the Free plan and shared
with GitHub Packages, so CI keeps build artifacts short-lived. Release assets
attached to a GitHub release are not workflow artifacts.

## 2026-11-20 — Design rules for local data (from phase 1 on)

Set by the phase 1 plan, as consequences of the change journal of phase 0.
They hold for every later phase.

1. **Derived tables have no constraint**: no uniqueness, no foreign key, no
   NOT NULL on a field. Business rules are checked by the domain when the
   user enters data. From phase 2 on, entries made on another device arrive
   field by field, in any order, and integrating them must never fail.
2. **An incomplete record is ignored when read**, without error. It appears
   once its missing fields arrive.
3. **Derived tables never migrate**: whenever their schema changes, they are
   dropped, recreated and recomputed from the journal. Only the journal tables
   have real migrations.
4. **Copying a tree gives computed identifiers**, derived from the source
   category and the target year. Two devices that copy the same tree offline
   thus write the same records, not two trees.
5. **Dates are calendar dates**, stored as `YYYY-MM-DD` text, with neither time
   nor time zone.
6. **No floating point in calculations**: amounts are integer cents, month
   weights are exact fractions.

## 2026-11-20 — Phase 1 decisions taken during development

Functional choices H1 to H6 are in `docs/plan/phase-1.md`. The decisions below
were taken while implementing it.

### 1.0 The clock rolls over instead of failing

**Decision.** When the counter of the hybrid logical clock is full, the clock
moves to the next millisecond with a counter of 0. `HlcOverflowException` is
gone.

**Why.** A device whose clock runs far ahead makes every other device adopt
its time after a synchronisation; their counters then grow with each write
until the wall clock catches up. Failing at 65536 writes would block them.
Moving one millisecond ahead keeps every timestamp greater than all the
previous ones; the logical time only runs slightly ahead of the wall clock.

### 1.0 Derived tables are described in Dart and rebuilt on schema change

**Decision.** Each derived table is a `DerivedTable` (entity, table, typed
nullable columns, plain indexes) and its `CREATE` statements are generated.
The text of all those statements is the *derived schema*; it is kept in
`local_state` with the list of derived table names. At every start,
`Journal.open` compares it with the schema of the running version; if they
differ, it drops the old and new derived tables, recreates them, and replays
the whole journal (with `field_versions`), in one transaction.

**Why.** Rule 3 of the phase plan without a version number to maintain by
hand: any change to a derived table, even a renamed column, triggers the
rebuild. Drift's `schemaVersion` stays reserved for the journal tables, the
only ones with real migrations; it is still 1.

**Evidence.** `test/data/upgrade_test.dart` opens a database written by
version 0.1.0 (`test/fixtures/v0.1.0/batz.db`), keeps its device identifier
and journal; `test/data/journal_test.dart` covers the rebuild on schema change
and the absence of rebuild when the schema is unchanged.

### 1.1 Allocation: exact fractions, halves rounded away from zero

**Decision.** `allocate` (in `batz-ui/lib/domain/allocation.dart`) computes
each month's weight as an exact `Fraction` (BigInt numerator and
denominator). A share is the amount times its weight divided by the total
weight, rounded to the nearest cent with halves rounded up; the last month
takes the remainder. A negative amount is allocated as its opposite, then
negated, which makes the two results exact opposites, as the plan requires.
Calendar dates are a `CalendarDate` value (year, month, day), stored as
`YYYY-MM-DD`.

**Why.** Exact fractions make "twelve months" exactly 12 for a period from
14 March to 13 March, with no tolerance in the tests. Rounding the magnitude
rather than the signed value is what gives exact symmetry.

### 1.2 Domain rules work on an in-memory snapshot of the ledger

**Decision.** `LedgerRepository.load` reads every derived table into an
immutable `Ledger`. Each operation is a method of `Ledger` that checks the
business rules against that snapshot and returns the `Modification` to write,
or throws a `LedgerException` whose reason the app turns into a French
message. `LedgerCubit` holds the snapshot for all pages and reloads it after
each write.

**Why.** The data of one person fits in memory for years, and pure Dart
rules are tested without a database. The same rules will check entries made
on this device in phase 2; entries from other devices bypass them (rule 1).

### 1.2 Reading a record: required fields and unknown values

**Decision.** An account needs a name and a known type; an unknown import
format also makes it unreadable. A missing `archived` reads as false. Records
that do not qualify are left out of the `Ledger`, without error, and appear as
soon as the missing field arrives (rule 2). An archived detailed account still
counts as the only detailed account.

**Why.** A value written by a newer version (a new account type, a new
statement format) must not be misread by an older one.

### 1.3 Category trees

**Decisions.**

- Names are compared after trimming, lower-casing and replacing accented
  Latin letters by their base letter (`normalizeName`, H1). Spaces inside a
  name still count.
- Top-level groups are groups in the sense of H2: they never hold a
  transaction, even without children. Only a category without children below
  a group does.
- A group's nature is stored on the group only; the other categories inherit
  it from their top-level group. Moving a category to the top level requires
  choosing a nature; moving a group below another category makes it inherit.
- When a year has no earlier tree to copy, the two default groups get
  computed identifiers too (from the year and the nature), for the same reason
  as copies (rule 4): two devices creating the first tree offline must not
  produce two trees.
- A tree is read only through its consistent part: a category whose parents
  do not reach, within the same year, a top-level group with a nature, or that
  is part of a loop, is ignored (rule 2). Two devices that move categories
  concurrently can create such a loop; the categories involved disappear until
  one of the moves is undone.
- Until the first transaction of a year writes its tree, the transaction form
  offers the categories of `treeOrPreview(year)`: the tree the copy would
  give, with the same computed identifiers. The category picked there is thus
  valid once the copy is written, in the same modification as the
  transaction.
- Deleting a category that has children is refused, in addition to H5.

**Known limit, for phase 2.** The copy writes every field of the copied
categories. If device A copies a year and then renames a copied category, and
device B copies the same year offline later in time, B's copy wins over A's
rename once synchronised. The records are the same on both devices, as
required, but the rename is lost.

### 1.4 Transactions and transfers

**Decisions.**

- Entity names in the journal: `transaction` and `transactionLine`; tables
  `transactions` and `transaction_lines`. In Dart the class is
  `LedgerTransaction`, to avoid the name of database transactions.
- A transfer has no line at all: no category, no period. Turning an entry
  into a transfer is not offered; the app modifies an entry as an entry and a
  transfer as a transfer.
- The detailed account is refused on *both* sides of a manual transfer, not
  only as the departure account: a transfer from cash to the detailed account
  would be counted a second time when the statement that shows the deposit is
  imported.
- A debts account refuses manual expenses and incomes, as the plan states, but
  accepts transfers in both directions: chapter 4.7 of the specification
  records a pure loan as "a transfer to, then from, « Dettes »", and the
  explanation table of the wealth view subtracts net transfers to it.
- An archived account is no longer offered for new entries; an existing entry
  on it can still be corrected.
- The first transaction of a year without a tree, expense, income or
  transfer, carries the copy of the tree in the same modification (step 1.3,
  H6): the tree and the transaction are written together, or not at all. A
  transfer has no category, but it is still a transaction dated in that year.
  The same holds when a modification moves a transaction into such a year.
- Cash-flow totals (`Ledger.cashTotals`) add each line to its category and to
  every ancestor; the totals of income and expenses are those of the top-level
  groups of each nature. A line without a category of the year's tree is
  counted apart as unclassified.

### 1.5 Transactions screen

**Decisions.**

- Dates are typed in the Swiss format (`31.12.2026`) or picked from a
  calendar; amounts are typed without sign, and a negative one is refused
  (H3).
- The form offers the categories of `treeOrPreview(year)` for the year of the
  date typed. When the date moves to another year, the chosen category is
  replaced by the category of the same name in that year (specification,
  4.1), or cleared if there is none. Each category is shown with its nature,
  so that the default direction (H3) is visible before saving.
- The direction follows the category's nature until the user flips it.
- In the list, a transfer shows its stored amount (negative, on the departure
  account), except when the list is filtered on the arrival account, where it
  shows the money coming in.
- The detail of a payment shows its total per year, then its share per month
  (`MM.YYYY`), computed by `allocate` from its line.

## 2026-11-20 — Phase 2 decisions taken during development

Functional choices H1 to H6 are in `docs/plan/phase-2.md`. The decisions below
were taken while implementing it.

### 2.0 A modification writes only the fields whose value changes

**Decision.** `Journal.write` compares each field of the modification with
the current value of that field, inside the same transaction, and writes only
those that differ. The comparison uses the exact JSON value of the journal
entry that gives the field its value (`field_versions` joined with
`journal`), not the derived column, so that `true` and `1` stay different. A
field that no entry ever set is written, even to `null`. When nothing
changes, nothing is written and `write` returns null.

**Why.** Screens submit every field of a record. Without the rule, the most
recent modification would also carry the unchanged fields, and once
synchronised it would overwrite what another device changed in the meantime
(the first acceptance criterion of phase 2). The rule sits in the journal, so
every entity of later phases follows it without anything to remember.

**Evidence.** `test/data/journal_test.dart` (fields left out, nothing
written, exact comparison, field never set, value received from another
device) and `test/data/field_merge_test.dart`: a note corrected on one device
and a category changed later on another, both through `Ledger.updateEntry`
with every field submitted, are both kept on both devices.

### 2.0 Detached categories are kept and listed, never dropped

**Decision.** `CategoryForest.build` sorts the categories into the trees of
their years and *detached* categories, each with its reason: part of a loop,
parent missing (deleted or not arrived), parent in another year, top-level
group without a nature, or below one of those (`detachedAncestor`). The first
four are the *heads*: the categories screen lists them under « À replacer »,
with the categories below them, and offers to move them; moving a head puts
back everything below it. A detached category can be moved to the top level
of its year (with a nature) or under a category of its year's tree, never
under another detached one, so a move cannot create a new loop.

A year whose categories are all detached has no tree: its first transaction
still copies the closest earlier tree. Transactions classified in a detached
category count as unclassified until it is put back.

This replaces the phase 1 behaviour, where such categories were ignored and
disappeared from every screen.

### 2.0 Database of version 0.2.0

`test/fixtures/v0.2.0/batz.db` was written by version 0.2.0 (commit
`ce7076b`) through its own operations: accounts, two trees, expenses, a
payment over two years, a transfer, a deletion. `test/data/upgrade_test.dart`
opens it with the current version and checks that every record is read back
and that new writes follow the old ones. Phase 2 changes neither the journal
tables nor the derived tables.

### 2.1 Exchange route: what the server checks and stores

**Decisions.**

- One table `journal`, `WITHOUT ROWID`, keyed by (timestamp, entity, record,
  field) like the app's, with the origin device copied from the timestamp into
  its own column and indexed with it: the known state is one
  `MAX(hlc) GROUP BY origin` over that index. Each row also records which
  paired device sent it and when, for diagnosis only.
- A value travels as the JSON text of the field's value (`"value": "-4590"`,
  `"value": "\"Coop\""`). The server checks that it is one JSON scalar the
  journal accepts (null, boolean, 64-bit integer, string; at most 256 KiB),
  then stores and returns that text unchanged: it never re-encodes.
- A page carries `since`: for each origin present, the receiver's known
  timestamp the page was computed from. The receiver refuses a page that
  continues from more than it holds (`409 SYNC_STATE_CHANGED` on the server),
  which would leave a gap, for instance after the server was restored from an
  older copy between two calls. Each entry must also come after `since` for
  its origin, and a page must be sorted by timestamp with no entry twice.
- Limits: 10 000 entries per page and 32 MiB per request on `/sync` (the other
  routes keep 1 MiB); the pages the server sends hold 1 000 entries unless the
  app asks for another size, and stop at 8 MiB. A modification is never cut:
  when a single one is larger than the page, it goes whole.
- The request body is decoded strictly: an unknown field is a bad request, so
  that a newer app is never half understood. The protocol number covers
  evolutions.
- `/healthz` reports `syncProtocol`. The server refuses an exchange whose
  protocol differs (`400 SYNC_PROTOCOL_UNSUPPORTED`) or whose app version is
  older than its minimum (`426 APP_VERSION_UNSUPPORTED`). The minimum stays
  0.1.0 until the version bump of step 2.7, so that every commit of the phase
  passes its tests.
- Every exchange is one `BEGIN IMMEDIATE` transaction: check, insertion with
  `ON CONFLICT DO NOTHING`, then the server state and the page for the app.
  Exchanges are thus serialised and replaying one adds nothing.

### 2.2 Sync engine of the app

**Decisions.**

- No new journal table and no Drift migration: the origin of an entry is the
  end of its timestamp (`substr(hlc, 22)` in SQL), the known state is a
  `GROUP BY` over it, and what another copy lacks is selected with
  `json_each` over its known state, bounded below by the lowest of its
  timestamps so that SQLite skips what both hold.
- The memory of the server (its last known state and the date of the last
  exchange that went to its end) is one row of `local_state`, tagged with the
  identifier the server gave at pairing: after a new pairing it is ignored,
  and every modification counts as waiting until the first exchange.
- The engine's first call sends no entry: it learns the server state, then
  each call sends what the server lacks according to the previous answer.
  When the server answers `SYNC_STATE_CHANGED`, the exchange starts again
  from its current state, at most three times. A page from the server that
  would leave a gap, or an answer announcing more entries without any, stops
  the exchange as a protocol error.
- Pages sent: 500 entries or 4 MiB; pages asked: 1 000 entries.
- A modification holds at most 10 000 changes (`maxModificationChanges`), the
  largest page the server accepts, since pages never cut a modification.
- Received pages are integrated with a few set-based statements per page
  instead of one round trip per entry: the page goes into a temporary table,
  the entries already held are dropped, the others are inserted, then for
  each field the latest new entry is applied when it is newer than
  `field_versions` (`json_extract` gives the SQL value). The rebuild of the
  derived tables uses the same statements over the whole journal. The tests
  that check the journal against a naive model, the rebuild tests and the
  convergence test pass unchanged.
- The ledger reads derived rows `ORDER BY id`: their physical order depends
  on the order entries arrived in, which differs between devices.

**Measure** (`batz-ui/benchmark/first_exchange_test.dart`, run on
2026-11-20 on the development machine, Intel Core i7-14700KF, server and app
on the same machine, database files in background isolates as in
production): a device holding 20 000 entries sends them to an empty server in
2.9 s (42 calls); a new device receives them in 3.0 s (21 calls). With the
first version of the integration, one round trip per entry, the second
figure was 66.7 s.

### 2.3 Triggers, states and versions

**Decisions.**

- `SyncCubit` runs the exchanges of decision H2: at start, when the app comes
  back to the foreground (`AppLifecycleListener.onResume`), 3 seconds after
  the last local modification (`Journal.localWrites`), every 5 minutes while
  the app is shown (the timer stops on `onHide`), and from the button. One
  exchange runs at a time; a trigger during an exchange schedules exactly one
  more after it.
- Statuses: not paired, never synchronised, in progress, up to date,
  offline, revoked, incompatible versions, error. An unreachable server only
  gives « Hors ligne ». While the device is revoked or incompatible,
  automatic exchanges stop; the button still tries, and the next start of the
  app tries once.
- The number of modifications waiting is the number of distinct timestamps
  the device holds beyond the server state remembered at the last exchange;
  it is recomputed after each local write and each exchange.
- Compatibility is checked with `/healthz` before any exchange: the app
  refuses when the server's `minAppVersion` is above its own version or when
  the server speaks a newer protocol (app too old), and when the server
  reports no `syncProtocol` or an older one (server too old, which is the
  case of servers before 0.3.0). The refusals of `/sync` itself
  (`APP_VERSION_UNSUPPORTED`, `SYNC_PROTOCOL_UNSUPPORTED`, `NOT_FOUND`) give
  the same statuses. The reason and the versions are shown.
- The clock offset is the server time of the answer minus the middle of the
  call, measured at each call; beyond 5 minutes either way the card warns
  (decision H5), without blocking anything.
- The home screen, empty until now, shows the synchronisation card; Plus ›
  Serveur shows the same card above the server details. After an exchange
  that received entries, `LedgerCubit` reloads, so every screen shows them.

### 2.4 First exchange and replacement (H1)

**Decisions.**

- The question is asked when the device and the server both hold entries and
  no origin is common to their known states. That can only happen before
  their first exchange: after one, each holds the other's origins. No flag
  is stored. The check runs on the first answer, before anything of it is
  integrated and before anything is sent, so leaving the question unanswered
  changes nothing; automatic exchanges then wait for the answer.
- « Fusionner » runs an ordinary exchange that skips the check. Duplicates it
  creates are left to the tasks of step 2.6.
- « Remplacer » asks the server as a device holding nothing, then, in one
  transaction, erases the journal, the field versions and the derived tables,
  stores a new journal identifier and integrates the first page; the exchange
  then continues as usual. Nothing is erased if the server does not answer.
  The new identifier guarantees that the entries written afterwards never
  follow, under the same origin, entries that were erased. The same action is
  offered in Plus › Serveur, after a confirmation that names the loss of the
  modifications not sent.
- `Journal.deviceId` is no longer final: it changes only through
  `replaceWith`, and the clock restarts with it.

### 2.5 Revocation and a lost server

**Decisions.**

- A revoked device (`DEVICE_REVOKED`) stops its automatic exchanges and says
  so; nothing of its data is touched and it can still be used. Paired again
  (Plus › Serveur: forget the server, then pair), it is an ordinary device:
  its first exchange sends what the server lacks, its unsent modifications
  included.
- A server that presents another certificate, or that answers
  `DEVICE_KEY_INVALID` (same certificate, database lost), gives the status
  « Le serveur a changé », which stops automatic exchanges and invites to pair
  again. The server screen explains `DEVICE_KEY_INVALID` too and offers to
  forget the server. No data is erased on the device: after pairing again,
  the first exchange rebuilds the server (an empty server is an ordinary
  exchange), and the other devices follow the same way without being asked
  the question of H1, since they share their origins with the rebuilt server.
- A server restored from an older copy needs nothing at all: each device's
  next exchange sends what the copy lacks.
- `test/e2e/rebuild_e2e_test.dart` covers the revoked device, both forms of a
  reinstalled server at the same address, and a restored copy, with a new
  device checked against the rebuilt server.
- End-to-end test files run concurrently, each starting servers: the harness
  considers a server started only once its own process logs that it listens,
  and tries another port if the bind failed. A server reinstalled at the same
  address is simulated by moving the devices' pairing to the new server's
  address, the old certificate still pinned, rather than by reusing a port.

### 2.6 Inconsistencies after a merge (H4)

**Decisions.**

- `Ledger.issues` lists, year by year, the categories of one tree that share
  a name (compared as names are, decision H1 of phase 1) and the detached
  categories, then the accounts when more than one is detailed (archived ones
  included, as for the rule itself). Computed on the snapshot, never stored.
- The home screen lists them under « À faire », each leading to the screen
  that corrects it: the categories of that year (duplicates are marked
  « Nom en double dans cette année »; detached ones are under « À replacer »)
  or the accounts.
- Never blocking: an account that is already detailed stays editable while
  another one is too; only making one more account detailed is refused.
  Renaming or deleting one of two categories with the same name works as
  usual.

### 2.7 Version 0.3.0

The app and the server move to 0.3.0 together. The server's minimum app
version becomes 0.3.0, the first that speaks the exchange protocol: an app
0.2.0 paired with a server 0.3.0 shows that it is too old, and its
exchanges would be refused anyway. The description of the exchange is in
`batz-web/docs/sync.md`.

The full suite runs its test files concurrently, several of them starting
servers. Three tests written during this phase depended on timing and failed
under that load: the convergence test now has a timeout of 3 minutes per seed
(about 10 seconds alone), and the cubit tests wait for the events they check
(`SyncCubit.whenIdle`, the states emitted) instead of fixed delays. Four
consecutive full runs passed afterwards.

## 2026-11-21 — Phase 3 decisions taken during development

Functional choices H1 to H8 are in `docs/plan/phase-3.md`. The decisions below
were taken while implementing it.

### 3.0 A modification is written in a few statements

**Decision.** `Journal.write` no longer runs several queries per field. The
changes go into a temporary table, those whose exact JSON value is already
the current one are deleted from it with one statement (`field_versions`
joined with `journal`, as before), the rest is inserted into the journal
under one timestamp, and the derived tables are updated with the set-based
statements already used to integrate received entries (`_applyLatest`). The
rules of 2.0 hold unchanged: only the fields whose value changes are written,
a field never set is written even to `null`, nothing is written when nothing
changes.

**Measure** (`batz-ui/benchmark/journal_write_test.dart`, run on 2026-11-21 on
the development machine, Intel Core i7-14700KF, database file in a background
isolate as in production, journal already holding 20 000 entries): one
modification of 1 000 fields took 3.4 to 4.5 s before (0.7 s when nothing
changed), and takes 51 to 71 ms after (19 ms when nothing changes). The tests
of the journal against its naive model, the rebuild tests and the convergence
test pass unchanged.

### 3.0 Reloading the screens after an exchange

**Decision.** `SyncCubit` reloads the screens after the exchange is over and
its status is shown, outside its error handling. A failure to reload is
reported to the bloc observers (`addError`) and never shown as a
synchronisation error: the exchange itself went to its end.

### 3.0 `pdftotext` in the server image

**Decision.** The image installs `poppler-utils` from Alpine 3.24
(`pdftotext` 25.12.0). The server runs it without a shell, the PDF on its
standard input and the text on its standard output: nothing is written to
disk, so the container stays read-only.

**Evidence** (2026-11-21):

- The image grows from 34.6 MB to 58.4 MB (`docker image inspect`,
  uncompressed size).
- In a container started with `--read-only --cap-drop ALL` as user 10001,
  `pdftotext -layout -enc UTF-8 - -` reads the PDF from its standard input.
- `pdftotext -layout` writes exactly the same text with version 24.02 (the
  development machine, Ubuntu 24.04) and 25.12 (the image), byte for byte, for
  each real statement at the root of the repository and for the fictitious
  ones. The extraction therefore keeps the method of the original script
  (`-layout`); word coordinates (`-bbox-layout`) are not needed.

### 3.0 Choosing and saving a file: `file_picker`

**Decision.** `file_picker` 13.4.0, the only package that both picks and saves
a file on Android, Windows and Ubuntu: `FilePicker.pickFile` (the PDF to
import) and `FilePicker.saveFile(bytes: …)` (the original PDF). On Android it
goes through the system document picker, without any storage permission; on
Ubuntu through the XDG desktop portal over D-Bus (no `zenity` needed); on
Windows through the native dialogs. `file_selector`, the other candidate,
cannot save a file on Android.

**Evidence.** With the dependency, `flutter build linux` and `flutter build
apk` succeed on the development machine and the APK registers
`FilePickerPlugin`. Windows is built by CI only.

### 3.0 Sending a file with Dio

**Decision.** The app sends the PDF as the raw body of `POST
/api/v1/imports`, with `Content-Type: application/pdf`, rather than a
multipart form: one file, nothing else to send, and the server reads it
without parsing a form.

**Evidence.** With Dio 5.11.1, `post(data: Uint8List, contentType:
'application/pdf')` delivers a body of 300 000 bytes identical to the one
sent, with that content type and its length (a throwaway test against a local
HTTP server). The real route is covered by the end-to-end tests of step 3.5.

### 3.0 Personal terms in tracked files

**Decision.** `scripts/check-personal-files.sh` also reads
`personal/terms.txt` (one term per line, never tracked: `/personal/` is
ignored by git) and fails when a term appears, without case, in a tracked
file (binary files included, the text of PDF files through `pdftotext`) or
in a commit message of any branch. A match names the file and the line of the
term in the list, never the term. Without the list, as in CI, this part is
skipped and says so.

On the development machine, the list was built by a local script from the
real statements (holder's name and address, IBANs, account and card numbers,
phone numbers, names of the other parties of transfers), without displaying
any of them; generic bank words it caught at first were removed. It can be
completed by hand.

### 3.0 Fictitious statements

**Decision.** `batz-web/src/internal/infrastructure/extraction/postfinance/fake`
writes PDF files itself (standard Helvetica fonts, WinAnsi), laid out with
the positions measured with `pdftotext -bbox-layout` on real statements of
2026: header block, columns and their right edges, line height, page header
of the following pages, form code printed vertically in the left margin,
page number. Only the geometry and the bank's own formulas (« ACHAT/SERVICE
DU », « CARTE NO », « DONNEUR D'ORDRE: », …) come from real statements;
every name, place, amount and number is invented. Its output depends only on
its input: `TestFixturesAreUpToDate` regenerates the test set in
`postfinance/testdata` and compares it byte for byte (`-update` rewrites it).

The test set: January, February and March 2026, consecutive in dates and
balances; a statement of another account continuing March; February with a
movement amount, a total, then a closing balance altered; an invoice that is
no statement. January has a day that goes on over a new page without its
date being repeated; both months have labels of up to five lines and an
amount that pdftotext separates from its label by the vertical footer, once
with the date of a new day, once without.

That separation was reproduced by its real cause, measured on a real
statement: the vertical footer's top lies between the top of a label and the
top of its amount, half a point lower, and pdftotext writes lines in the order
of their tops.

**Evidence.** `pdftotext -layout` gives the same structure as on the real
statements. The original script (`legacy/extract_v1.1.py`), run locally on
the test set, accepts the four consistent statements (27, 21, 12 and 3
movements) and refuses the three altered ones for the expected reason
(running balance, totals, closing balance) and the invoice.

### 3.0 Database of version 0.3.0

`batz-ui/test/fixtures/v0.3.0/batz.db` was written by version 0.3.0 (commit
`806a457`) through its own operations, with a fixed clock: three accounts
(one detailed), the 2026 tree, an expense, a transfer, a deleted expense, a
rename integrated as an exchange page from another device, and the memory of
the server after an exchange. `test/data/upgrade_test.dart` opens it with the
current version and checks every record, the memory of the server (nothing
waiting) and a new write after the old entries.

### 3.1 Extraction of PostFinance statements

**Decisions.**

- The domain `statement` holds the statement as read (IBAN without spaces,
  currency, period, opening and closing balances, printed totals, lines with
  booking date, signed amount in cents, raw text, short label and the balance
  printed after the line when there is one) and its checks, in this order:
  currency (CHF only), period (every line inside it, in order), each balance
  printed in its course, printed totals, closing balance. The first failure
  refuses the statement with the name of the check (`currency`, `period`,
  `runningBalance`, `totals`, `closingBalance`). A statement that cannot be
  read entirely (a movement without a date or a label, a balance or the totals
  missing, two IBANs) is refused with the check `layout`; a PDF that is no
  statement with `IMPORT_UNKNOWN_FORMAT`; a file pdftotext cannot read, or
  that does not start like a PDF, with `IMPORT_UNREADABLE`. Messages hold
  dates, amounts and line numbers, never the text of the statement.
- `extraction/postfinance` keeps the method of the original script (columns
  placed by the end of the « Crédit » and « Débit » headers of each page,
  counted in characters, not bytes), with three corrections: the page
  furniture (vertical form code, « Page n / m », the header block repeated
  on each page, « Date dd.mm.yyyy ») is removed from the texts, where the
  original script kept it on six lines of a real statement of 2026; an amount
  on a line of its own takes the line before as its label, with the date
  printed on its line when there is one; and the 2025 layout (period, IBAN and
  currency at the right of the first page) and the 2026 one are both read.
- Short label (H3): when the first line is a type of operation the module
  recognises (upper-case words ending with « DU » and maybe its date, or
  « DÉBIT », « CRÉDIT », « CRÉDIT POSTFINANCE CARD », « PRIX POUR »), that
  line, the date on the next line, the card line, the IBAN line and « DONNEUR
  D'ORDRE: » are left out; otherwise, or when nothing is left, the whole text
  on one line.
- pdftotext runs without a shell, with a 30-second limit and 8 MiB of text at
  most; a run that exceeds them refuses the file as unreadable. A missing
  pdftotext is an internal failure, not a refusal.
- `batz-web extract <pdf>` prints the JSON of the result (exit code 2 when the
  statement is refused); `-summary` prints only the verdict and the number of
  lines, `-amounts` the date and amount of each line. The JSON expected for
  each fictitious statement is computed by the generator from what it printed
  (`testdata/*.json`), not from the extraction, and the tests compare the
  extraction with it.
- `scripts/check-real-statements.sh` extracts each real statement at the root
  of the repository and prints only the verdict and the number of lines; when
  the CSV of the original script is there, it compares dates and amounts and
  prints only the outcome.

**A defect of the original script.** On the real statement of June 2026, one
date differs from the CSV of the original script (line 50): an amount that
pdftotext put on a line of its own after the vertical footer, with the date of
a new day on that line. The original script reads such a line as a movement
whose text is the date and keeps the date of the movement before; the
extraction reads the printed date. Checked locally, without displaying the
line: the booking date printed on line 50 is the extracted one; line 49 ends
its day (the statement prints a balance after it, equal to the running
balance), and the original script dates line 50 on that same day, after the
balance that closes it, which contradicts the statement; the amounts are the
same. `scripts/check-real-statements.sh` compares strictly and names any
differing line and field: it reported this one, and failed.

With the user's agreement (2026-11-21), the reference was corrected rather
than the comparison loosened or the extraction made to copy the defect: in
the local copy of the original script (`personal/legacy/`, not tracked), a
detached amount that carries a date now takes the line above as its label and
its own date, as a detached amount without a date already did. Checked
locally: the corrected script gives the CSV of both statements of 2025 byte
for byte, and on the fictitious statements the expected dates and amounts;
on June 2026 it changes only the date of line 50 (and the texts of lines 49
and 50, the label moving back to its line). The CSV of June 2026 was written
again by it; the one of the uncorrected script is kept in `personal/backup/`.

**Evidence** (2026-11-21, development machine): `scripts/check-real-statements.sh`
accepts the three real statements present (62, 49 and 70 lines), with dates
and amounts identical to the CSV of the original script, corrected as above
for June 2026. On the
fictitious statements, the extraction gives exactly the expected JSON, labels
and printed balances included.

### 3.2 Import route, original files and copies of the database

**Decisions.**

- `POST /api/v1/imports` takes the PDF as the raw request body (10 MiB at
  most, `413 IMPORT_TOO_LARGE` beyond) and answers `200` with the
  fingerprint (SHA-256 of the file, lower-case hex) and the statement read.
  A refusal is a `422` whose body adds `check` to the usual code and message:
  `IMPORT_UNREADABLE`, `IMPORT_UNKNOWN_FORMAT`, `IMPORT_INCONSISTENT` with the
  check in cause. The extraction is deterministic, so the same file always
  gets the same answer; the server keeps no copy of the answer.
- The server refuses nothing because it was already imported (decision H1):
  the app decides from its journal.
- Imports run one at a time (a mutex in `application.Imports`): when the
  server does not hold the file yet, it writes a copy of its database, then
  stores the file; two copies of a file sent together give one backup and one
  file. A refused statement is neither stored nor backed up, and no file is
  stored if its backup failed.
- The copies are written with `VACUUM INTO` into `backups/` in the data
  directory, named by the UTC time to the millisecond
  (`batz-20261121T101530.123Z.db`) so that names sort in time order; after
  each one, the oldest beyond `BATZ_BACKUPS` (12 by default, 1 to 1000) are
  deleted. A copy is an ordinary database: restoring it is stopping the
  server and putting it in place of `batz.db`.
- Files go to `statements/<fingerprint>.pdf`, written under a temporary name
  and renamed, so that a file present is complete.
  `GET /api/v1/imports/{fingerprint}/pdf` returns it as `application/pdf`; a
  fingerprint the server does not hold, or that has not the form of one,
  gives `404 IMPORT_PDF_NOT_FOUND`, which is what a rebuilt server answers.
- `/healthz` reports `importFormats` (`["postfinance"]`); a server without
  it is too old to import. At start, the server warns if pdftotext is
  missing.
- The logs of an import hold the device, the beginning of the fingerprint,
  the number of lines and whether the file was new; those of a refusal the
  code and the check. Never a text, an amount or the IBAN of a statement; a
  test sends the test set and checks every line of text against the logs.
- The image installs `poppler-utils`; CI extracts the test set inside the
  built image (`batz-web/scripts/check-image-extraction.sh`), in a read-only
  container without network, and compares with the expected JSON. The CI
  jobs that run the Go tests install `poppler-utils`.

**Evidence.** In the image started read-only with a data volume, an import
answers with its 27 lines, `backups/` holds one copy and `statements/` the
file under its fingerprint; the logs show only the fields above.

### 3.3 Statements and imported lines in the app

**Decisions.**

- New journal entity `statement` (table `statements`): account, format,
  IBAN, period, opening and closing balances, fingerprint of the file. The
  number of lines is not stored: it is the number of transactions that name
  the statement. Transactions gain `rawText`, `statementId` and
  `statementRank`.
- The journal stores two statuses only, `toValidate` and `validated`
  (principle 3); `toComplete` and `proposed`, never written by an earlier
  version, are gone from the enum.
- Identifiers are computed (`derivedId`, the SHA-256 name-based UUID of the
  tree copies, moved to `domain/ids.dart`): the statement from the account and
  the fingerprint, each line from the statement and its rank. The line that
  will hold the category of an imported transaction is `<transaction>-line`,
  so that two devices validating the same line write the same record too.
- `Ledger.importStatement` checks, in this order, and refuses with a
  `StatementRefusedException` before anything is written: account not
  detailed or of another format; statement already imported (its computed
  identifier exists: decision H1); IBAN different from the account's latest
  statement (both IBANs given); not following the latest statement (the day
  after it and its closing balance expected, both pairs given); lines not
  adding up to the difference of the balances; more changes than one
  modification holds (about 1 200 lines). Then it writes the statement, its
  lines (8 fields each: account, date, amount, raw text, description = short
  label, status, statement, rank) and the copy of the tree of each year a
  line opens, in one modification. `StatementImport.first` tells the app it is
  the account's first statement (H7).
- Deleting the latest statement (H8) deletes it, its lines and their
  category lines. Imported again, its computed identifiers are the same:
  `Ledger.deletedStatementIds` (statements whose `_deleted` is true) tells the
  import to write `_deleted: false` and to reset what the user may have set
  on its lines (note, counterpart account); a first import writes neither.
- Nothing can change the amount, date, account or raw text of an imported
  line: no operation writes them after the import. Manual operations are
  refused on the detailed account (as in phase 1) and on any imported line,
  even if import was disabled on its account since. Description and note
  change through `updateImportedDetails`; category, transfer and period with
  the validation of step 3.4.
- Until step 3.4 computes proposals, an imported line without a category line
  counts in the cash-flow totals as unclassified.

**Measure** (`test/data/write_performance_test.dart`, part of the suite, on
the development machine, database file in a background isolate): the import
of a statement of 100 lines, 818 fields with the copy of a first tree, is
written in 113 ms. The test fails beyond one second.

### 3.4 Mapping rules and proposals

**Decisions.**

- New journal entity `rule` (table `rules`): year, keywords, target category
  or target account (exactly one), period model and number of months. The
  keywords are one field holding a JSON list of strings, since the journal
  holds scalars: a modification of the keywords replaces the list as a whole.
- Matching: the raw text and the keywords are compared lower-cased, without
  accents and with every run of spaces or line breaks as one space, so a
  keyword can span two lines of the bank's text. A keyword written `re:…` is
  a regular expression, as in the original script; it is matched without
  case against the same normalised text, its accented letters replaced by
  their base letter but its case kept (lower-casing it would turn `\S` into
  `\s`). An invalid expression is refused when the rule is written
  (`isValidKeyword` lets the screen check each keyword); a rule received with
  one never matches. The same keyword twice counts once.
- Outcome of a line to validate (`outcomeOf`): among the rules of its payment
  year that match, those with the most keywords win. One result among them
  (same target, same period model and number of months, decision H5) gives a
  proposal, named after the first winning rule by identifier; different
  results give a conflict listing the rules. A winning rule whose target can
  no longer be used (category deleted, detached, a group or out of the year's
  tree; account gone, archived or detailed) proposes nothing and the line is
  to complete: an unusable rule still takes part in the priority rather than
  letting a weaker rule propose something its author did not choose. Such
  rules are listed by `Ledger.unusableRules` for the tasks of step 3.6.
- Proposals are computed when the ledger is loaded, for the lines to
  validate only, and never stored (principle 3): creating, modifying or
  deleting a rule writes only the rule. The cash-flow totals count a proposed
  line in its category, a proposed transfer nowhere, and a line without a
  proposal as unclassified; the list shows a proposed line with its proposed
  category and type.
- Periods (H6, `domain/period_model.dart`): month arithmetic clamps to the
  end of the month, as in `java.time`. N months after a payment end the day
  before the same day N months later, clamped: from 31 January, one month
  ends on 27 February. N months before start on the same day N months
  earlier, clamped: before 31 May, three months start on 28 February. The
  table of H6 holds exactly; 12 months from any day weigh exactly 12 months
  in the allocation, leap years included. Months go from 1 to 120.
- Validation writes the result (principle 4): `classify` writes the
  category, the amount and the period on the line `<transaction>-line` (with
  `_deleted: false` when the transaction has no line, which brings back a
  line deleted with its statement or by a transfer) and the validated status;
  or the counterpart account, deleting the line. Correcting a proposal is
  classifying it (H4). An imported transfer keeps the statement's sign:
  negative, the money goes to the counterpart; positive, it comes from it.
  `confirmProposals` writes the proposals of the given lines that have one,
  in one modification (7 fields per line), or in several of whole lines if
  they would exceed 10 000 changes.
- Rules follow the copy of the tree: the copy of year Y writes the rules of
  the source year with identifiers computed from the source rule and Y
  (`copiedRuleId`), a category target replaced by the copy of that category.
  The preview of a tree (`treeOrPreview`) keeps only the categories.
- A category targeted by a rule cannot be deleted (`categoryUsedByRules`,
  with the number of rules).
- `linesClassifiedBy` counts the lines to validate a rule being written would
  propose, alone or with rules of the same result: the « Créer une règle »
  screen shows it.

**Measure** (`test/data/write_performance_test.dart`, part of the suite,
development machine, database file in a background isolate): the
confirmation of 500 proposals, 3 500 fields in one modification, is written in
120 ms; the import of 100 lines in 105 ms. The test fails beyond one second.

### 3.5 The import flow in the app

**Decisions.**

- Transactions › « Importer un relevé » opens a screen run by `ImportCubit`.
  It first runs an exchange (`SyncCubit.sync`, waited for to its end): if the
  status is not « À jour » (not paired, offline, revoked, server changed,
  incompatible, question pending, error), the import does not start and the
  screen says why, with « Réessayer ».
- The user picks the detailed account (active ones; usually one) and the PDF
  (`FileAccess`, `file_picker` in the app, a fake in tests). The app first
  computes the fingerprint and refuses a statement already imported from its
  journal, without sending it (H1). It then checks that the server's
  `/healthz` announces the account's format (a server before 0.4.0 is « trop
  ancien pour importer »), sends the file, and checks the statement read by
  the server against its ledger (`Ledger.importStatement`). Every refusal
  names its reason: the server's code and check, the app's reason with what
  was expected and found, or a server that stopped answering.
- The first statement of an account asks for confirmation (H7), naming the
  opening balance and the date it sets. The check against the ledger is made
  again at the confirmation: the ledger may have changed meanwhile.
- The result names the period, the number of lines, how many the rules
  propose and how many are to complete. The exchange that sends the import
  follows like after any modification (3 seconds later).
- « Relevés du compte » (from the import screen, or the form of the detailed
  account) lists the statements, latest first, with their period, balances
  and number of lines; each can have its original PDF saved (fetched by
  fingerprint; a server that no longer holds it is said to have been
  rebuilt, without error); the latest can be deleted after a confirmation
  that names its lines (H8).
- `AppServices` is given to the widget tree (`RepositoryProvider`) with two
  new seams for tests: the import transport and the file access.
- The CI job of the app installs `poppler-utils`: its end-to-end tests run
  the real server, which reads the fictitious statements.

**Evidence.** `test/pages/import/import_flow_test.dart` drives the screens
(synchronisation first, H7, H1 without calling the server, a skipped month,
a refusal of the server with its check, the next month, the list, the PDF
saved then missing, the latest statement deleted, a server unreachable or too
old). `test/e2e/import_e2e_test.dart` runs the same cubits against a real
`batz-web`: the three months imported with balances computed equal to the
printed ones, five refusals with the journal unchanged, the same statement
imported by two devices giving no line twice, lines validated with the server
stopped and received validated by another device after its restart, the PDF
fetched by fingerprint and missing on a rebuilt server.

### 3.6 Validation screens

**Decisions.**

- The number of lines to validate is a badge on the Transactions entry of
  the navigation and a card at the top of the transactions list. The home
  screen lists, before the merge inconsistencies, the lines to validate, the
  lines whose rules compete and, per year, the rules that propose nothing
  any more; the first two lead to the validation screen, the third to the
  rules of the year.
- The validation screen has two tabs. « À compléter »: each line with its
  date, amount and whole bank text, and the competing rules or the unusable
  rule when there is one. « Proposées »: each line with its description, its
  proposal (category and period, or transfer) and the rule that gives it,
  and « Confirmer les propositions », one modification for all of them.
- A line opens the classification screen: category of its payment year and
  period (from the proposal or the stored classification, the payment date
  otherwise), or transfer with an account (it says whether the money goes to
  it or comes from it, from the sign); description and note. « Valider »
  writes all of it in one modification (`Ledger.validateLine`). « Créer une
  règle » opens the rule form with the description as first keyword and the
  chosen target; the form shows, as it is typed, how many lines to validate
  the rule would classify, and flags an invalid expression.
- Plus › « Règles de classement » lists the rules of a year (keywords,
  target, period model), unusable ones marked, and opens the same form to
  modify or delete one.
- The transactions list searches words (each required, without case or
  accents) in the description, the note, the bank text, the category, the
  accounts and the amount (`1650.00`), and filters by account, year, month,
  category name (the same name in every year, or « Non classé ») and status
  (to validate, to complete, proposed, validated). Lines to validate show
  their state. The search lives in the domain (`Ledger.search`).
- Everything is local: the validation works without a server and can be
  left at any point; what is validated is sent at the next exchange.

**Evidence.** `test/pages/validation/validation_flow_test.dart` validates,
without any server, a rule created from a line (with its count and an
invalid expression refused), the five proposals confirmed, a transfer
classified by hand, and the rules screen; then the search and the status
filter; then the tasks of competing rules and of an unusable rule.
`test/domain/ledger/search_test.dart` covers each filter and the search
fields.

### 3.7 Version 0.4.0

The app and the server move to 0.4.0 together. The server's minimum app
version becomes 0.4.0: an app 0.3.0 would receive statements, imported lines
and rules it does not know, keep them in its journal without showing them,
and let its user enter by hand what the import already brought. The tests of
the exchange send 0.4.0 (the server's minimum) and check that 0.3.0 is
refused. The original scripts left the repository (`legacy/`), as the
specification planned: the extraction no longer needs them, the check of the
real statements compares with the CSV files they wrote, and they remain in
the history (commit `806a457`). The import is described in
`batz-web/docs/import.md`; the API, the architecture, the deployment (with
the upgrade to 0.4.0 and the restoration of a copy of the database) and the
README follow.

## 2026-11-21 — Phase 4 decisions taken during development

Functional choices H1 to H8 are in `docs/plan/phase-4.md`. The decisions below
were taken while implementing it.

### 4.0 The keyword of « Créer une règle » is in the bank text

**Decision.** The rule form no longer starts from the description as a
whole: `suggestedKeyword` (in `domain/ledger/rule.dart`) gives the longest
run of consecutive words of the description found in the bank text as rules
read it (lower case, without accents, spaces collapsed), the first one among
equals, with at least three letters or digits. When there is none (the user
wrote their own description), it gives the line of the bank text with the
most letters, the first line left aside when there are others (it names the
type of operation). A candidate that starts with `re:` is skipped: it would
be read as a regular expression. The keyword is therefore always in the text
of the line, and the rule classifies at least that line as long as its
keywords are kept.

**Why.** The short label (decision H3 of phase 3) joins the lines of the
bank text that remain once the generic ones are left out; a card or IBAN
line between two kept lines makes it absent from the text as a whole.

**Evidence.** `test/domain/ledger/rules_test.dart` checks every line of the
three fictitious statements and three lines built for the case (two labels
whose lines are not consecutive, a description rewritten by the user):
the keyword is found and the rule proposes the line. Checked locally on the
three real statements, without displaying them: 181 lines, the 3 whose label
is not in the text (one per statement) now get a run of 8, 14 and 12 words of
it; all 181 keywords are in their text.

### 4.0 Reloading after a write, measured with ten years of data

**Measure** (`test/data/reload_performance_test.dart`, part of the suite,
run on 2026-11-21 on the development machine, Intel Core i7-14700KF, database
file in a background isolate as in production). Data from
`test/support/large_ledger.dart`: 10 000 transactions over five years (60
statements of 160 lines and 400 manual expenses), five trees of 50
categories, 200 mapping rules, 160 lines to validate. Reading the derived
tables, building the ledger, the proposals of the lines to validate and the
tasks takes 60 to 99 ms over five runs; the write before it 47 to 97 ms.
Below the 300 ms of the plan: nothing to correct. Since 4.7, the test fails
when any of ten runs exceeds 300 ms (see 4.7 for how it is kept apart from
the other test files).

### 4.0 Database of version 0.4.1

`batz-ui/test/fixtures/v0.4.1/batz.db` was written by version 0.4.1 through
its own operations, with a fixed clock, in a worktree of commit `f906f86`:
three accounts (one detailed), the trees 2026 and 2027, three mapping rules
and their copies, the fictitious statement of January imported (7 proposals
confirmed, one line classified by hand over the year, 19 lines to validate)
and two manual expenses, one over two years. `test/data/upgrade_test.dart`
opens it with the current version and checks every kind of record, then that
a new rule proposes for the lines left to validate.

### 4.1 One calculation for both views of a year

**Decisions.**

- The calculation lives in `batz-ui/lib/domain/views/year_view.dart`. It
  reads the ledger and adds nothing to `ledger.dart`: `ledger.views` (an
  extension, cached with an `Expando` for the life of the ledger) gives
  `YearViews`, whose `of(year, kind)` builds a `YearView` the first time it is
  asked for. A new ledger is loaded after each write, so nothing is ever
  stale and nothing is stored (principle 1).
- Each line of a transaction becomes a *flow*: its origin category, its
  amount and its period; a line to validate becomes the flow of its
  proposal (a proposed transfer gives none). The cash-flow view places a
  flow once, at the month of its payment; the economic view places each of
  its monthly shares (`allocate`, skipped for a period within one month).
  Everything after the placement is the same code for both views
  (principle 2).
- The origin category is a category of the tree of the payment year, any
  category of it, a group included (only a merge can classify a line in a
  group). In another year, a share goes to the category of the same name if
  it can hold transactions (a group cannot, H5); otherwise to « À classer »
  of the origin's nature, which counts in the income or the expenses.
- « Non classé »: a validated transaction without a line, a line without a
  category or whose category is not in the tree of its payment year, a line
  to validate without a proposal (no rule, a conflict or an unusable rule).
  It counts at the payment date in both views, outside income and expenses.
- A category shows what is classified in it; a group the sum of its
  children plus what was classified in it directly. Income and expenses are
  the sums of the top-level groups of their nature and of « À classer ».
- Period offsets are signed like a result (income positive, expenses
  negative) and are the same in both views: the economic shares, outside the
  year, of what was paid in it; and the shares in the year of what was paid
  in other years. The identity cash result = economic result + first −
  second holds by construction and is checked on random data.
- The years offered go from the first tree to the latest of the current
  year, the latest tree and the latest share. A later year without a tree is
  shown with `treeOrPreview` (H6): its shares go to the computed identifiers
  of the copy to come. A year before the first tree gives no view (`null`).
- `Ledger.cashTotals` and `YearTotals` of phase 1 are gone: their tests
  read the cash-flow view (one implementation).
- `composition(year, kind, row, month:)` replays the same placement and
  keeps the amounts of one row (a category with everything below it,
  « À classer » of a nature, « Non classé »), summed per transaction.

**Measure** (`test/data/performance_test.dart`, same data and machine as the
measure of 4.0): both views of a year, on a ledger just loaded, take 9 to
55 ms over five runs (the first one includes the warm-up). Since 4.7, the
test fails when any of ten runs exceeds 100 ms.

### 4.2 Redistribution rules

**Decisions.**

- New journal entity `redistribution` (table `redistributions`): year,
  source category, target category and `basisPoints`, the percentage in
  hundredths of a percent (1000 is 10 %). A rule needs the four fields to be
  read; whether it applies is decided at each load. Its operations and its
  checks live in `domain/ledger/redistribution.dart`, as an extension of the
  ledger.
- Creation and modification follow H2 and give their reason: no tree for
  the year; same category; source or target not a category without children
  of the year (a top-level group never holds transactions, so it is refused
  too); natures that differ; a percentage out of 0.01 to 100 %; a rule with
  the same source and target already there (it is modified instead); a
  target that is the source of another rule, or a source that is the target
  of one; the rules from the source above 100 % (the error carries the total
  it would reach). A modification is checked against the other rules only;
  its year cannot change.
- The calculation takes, month by month, the amount the source shows before
  any redistribution (proposed lines, refunds and shares from other years
  included: everything placed in it), applies the percentage and rounds to
  the cent, halves away from zero (`redistributedCents`). That amount leaves
  the source and joins the target. A category keeps showing its own amount;
  each rule is a line of its own under the source and under the target; the
  groups add those lines. Both views (H1).
- A rule that does not apply is kept, left out of the calculation and
  listed with its reason: source or target missing from the tree (deleted,
  detached, another year), not a category without children, the same
  category, natures that differ, a percentage out of range; then, among the
  rules that pass those checks, every rule of a source above 100 % and every
  rule whose target is a source or whose source is a target.
- The copy of a tree writes the redistribution rules of the source year with
  computed identifiers (`copiedRedistributionId`) and their categories
  transposed; a year to come without a tree shows those copies.
- A category that a redistribution rule uses as source or target cannot be
  deleted (`categoryUsedByRedistributions`, with the number of rules).
- `test/support/random_ledger.dart` holds redistribution rules, and the
  checks of every view (group sums with the redistribution lines, zero sum,
  identity of the offsets) run on it. The convergence test creates, modifies
  and deletes redistribution rules on four devices.

### 4.3 Refunds attached to an expense

**Decisions.**

- A line gains `refundedLineId` (column `refunded_line_id`): the line of
  the expense it refunds. The journal keeps only that link (principle 5).
- The link holds while the refund is validated money that came in (its line
  positive), not a transfer, and leads to a validated expense: a line of
  money that left, in an expense category of the tree of its payment year
  (`Ledger.isExpenseLine`). It is followed one step only: a chain written by
  two devices leads to a refund, never an expense, so it does not hold, and
  nothing recurses.
- While the link holds, the refund's flow takes the category, the period and
  the year of the expense; the cash-flow view still places it at its own
  payment date, mapped by name into the year of that date when it is
  another one. `categoryOf` gives the expense's category (so the list, the
  search and the type show « Remboursement » in it).
- Attaching (`attachRefund`, in `domain/ledger/refund.dart`) refuses money
  that left, a transfer and a target that is not a validated expense.
  It writes the link, the refund's own category (the category of the same
  name as the expense's in the tree of its payment year when it can hold
  transactions, else the line's current category for a validated line, else
  none), its payment date as period, and validates an imported line to
  validate. A manual entry can be attached in the same modification
  (`EntryDraft.refundedLineId`): it must come in, its category is then
  optional and computed the same way. Detaching writes the link to null:
  the own category and date apply again.
- Classifying an imported line in a category writes the link to null when
  the line has one, or when the line is new or brought back (a line deleted
  with its statement must not bring an old link back). Confirming a proposal
  therefore writes 8 fields per line instead of 7.
- Deleting the expense, or the statement that holds it, breaks the link
  without error: the refund counts with its own category and date, and
  `brokenRefunds` lists it for the tasks until it is detached or attached
  again.
- The expense shows its refunds (`refundsOf`) and its net cost
  (`netCostOf`: its amount plus its refunds). `refundTargets(text)` finds
  the validated expenses by the words and amounts of the transactions
  search.
- The random ledger of the view tests holds attached refunds, one link in
  five broken; the convergence test attaches and detaches refunds; the
  performance data holds 100 attached refunds among the 10 000 transactions.

### 4.4 Shares to classify

**Decisions.**

- New journal entity `shareClassification` (table `share_classifications`),
  the « LineYearCategory » of chapter 6 of the specification: line, year,
  category chosen and category of origin the answer was given for. Its
  identifier is computed from the line and the year
  (`shareClassificationId`), so that two devices answering the same question
  write one record, whose fields follow the latest answer.
- Each flow of the calculation carries the line whose answers it follows:
  its own line; for a line to validate, `<transaction>-line`, the identifier
  the validation will give it (a question can thus be answered before the
  line is validated, and the answer holds after); for an attached refund,
  the expense's line (its shares follow the expense's answers, H3).
- In a year other than the one of its category, a share goes to the
  category of the same name if it can hold transactions; otherwise to the
  category of the answer, while the answer holds (the line still has the
  category it was given for, and the category chosen can hold transactions
  in the tree of the year, H5); otherwise to « À classer ». Nothing is
  stored when the name matches: an answer is only read when needed, so a
  rename that restores a name makes it unused, never wrong.
- The questions waiting (`YearViews.pendingShares`) are the lines with an
  amount in « À classer » of a year shown, in either view, grouped by
  category of origin and year, with the amount of each line in each view
  (the cash-flow amount only comes from a refund paid in another year than
  its expense). They are computed in one pass over the amounts that change
  year, with the placement of the views; the view tests check on random data
  that they add up exactly to the « À classer » lines of every view.
- Answering (`classifyShares`, one modification for a group or one line)
  refuses a year before the first tree, a category that cannot hold
  transactions, an unknown line and a category of the other nature: an
  expense share stays an expense (H5 says where the answer goes, not that it
  may change the nature; « À classer » already counts in the nature of the
  origin). For a year whose tree is still the copy to come, the same
  modification writes the tree.
- A category chosen by an answer can be deleted like any other: the question
  comes back (H5).

**Measure** (`test/data/performance_test.dart`, same data and machine,
answers and a renamed category in the last year added): the reload after a
write, now with the shares to classify, the other tasks and the key figures
of the year, takes 84 to 107 ms after the first run when the test runs
alone; both views of the last year 8 to 20 ms. Two corrections were needed
on the way. Computing the pending shares by placing every year in both views
took the reload to 114–239 ms; one pass over the amounts that change year
brought the pending shares from about 70 to 15–27 ms. Then the repository
sends its nine queries together (`Record.wait`) instead of one after the
other: the rows of one are read while the background isolate runs the next.

Within the full suite, other files (servers, the convergence test) compete
for the processor: the same reload took from 126 ms to 3.9 s, and a run of
the suite failed once. How the measurement is kept apart from them is
decided in 4.7.

**Evidence.** `test/domain/views/shares_test.dart`;
`test/e2e/year_view_e2e_test.dart` sends redistribution rules, an attached
refund and an answer from one device to another through a real server,
checks the same views on both, and copies a tree on two devices offline;
the convergence test answers shares at random on four devices.

### 4.5 The « Année » screen

**Decisions.**

- `YearPage` takes the « Année » entry of the navigation. It offers the
  years of `YearViews.years` (the current year first, otherwise the latest)
  and the toggle Trésorerie / Économique. The view chosen is kept in the
  local state of the database (`PreferencesStore`, key `year_view_kind`):
  on this device only, never in the journal; economic the first time (H7).
- The header gives income, expenses and savings, « Non classé » when it is
  not zero, and in the economic view the two period offsets, signed as a
  result. A notice recalls the lines to validate counted as proposed (it
  opens the validation), another that a year to come is shown with the tree
  of its copy.
- The tree lists every category with its total, groups first and folding;
  under a category, its redistribution lines (« Vers … » under the source,
  « Depuis … » under the target, with the percentage); after the last
  top-level group of a nature, « À classer » of that nature when it is not
  zero; « Non classé » last. Expenses, their groups, their « À classer »
  and their redistribution lines show as costs, without a minus sign: a
  refund or what leaves through a redistribution shows with one (H7).
  Income and « Non classé » show as paid.
- From 1 100 logical pixels wide, each line shows twelve columns and the
  total; below, the total and a button that unfolds the twelve months.
  Every amount (a month or the year) opens the transactions that make it,
  with the part each one counts (`CompositionPage`); each opens its detail.
  A redistribution line opens nothing.
- The home screen shows the key figures of the current year in the
  economic view (H8) and opens « Année » through the navigation of the
  shell (`ShellScope`); nothing when the year has no tree to show.

**Evidence.** `test/pages/year/year_page_test.dart` (the toggle on a
payment over two years, months unfolded, a month and a category opening
their transactions and a detail, the next year with its preview, a group
folded, the view kept on the device, twelve columns on a wide screen).
Screenshots taken locally with the real fonts, phone and desktop sizes,
were checked by eye; they are not kept.

### 4.6 Screens for redistribution, refunds and shares to classify

**Decisions.**

- Plus › « Redistribution » lists the rules of a year (« De … vers … » and
  the percentage); a rule that does not apply carries a warning and its
  reason. The form offers the categories of the year that can hold
  transactions, with their nature, and a percentage typed as `10`, `33.33`
  or `0,5` (`parsePercent`, at most two decimals); every refusal of H2 is
  shown with its reason. The home screen lists, per year, the rules that do
  not apply, and the « Année » screen recalls them; both open this screen.
- Attaching (H4): the validation screen offers a third choice,
  « Remboursement », for money that came in; the expense is found by text
  and amount among the validated expenses of every account and year
  (`RefundTargetPage`, the transactions search), and « Valider » attaches
  the line with its description and note in one modification
  (`validateAsRefund`). The detail of a transaction that came in offers
  « Rattacher à une dépense », or « Détacher » once attached. The manual
  entry offers « Rembourse une dépense » for money that comes in: the
  category and the period then give way to the expense.
- The detail of an expense lists its refunds and its net cost; the detail
  of a refund shows its expense, which it opens, or says that the link is
  broken. Its months follow the period of the expense. The home screen
  lists the refunds that lost their expense (`BrokenRefundsPage`).
- « Parts à classer »: a task on the home screen, and the « À classer »
  line of the « Année » screen, open the questions, one card per category of
  origin and year: the lines with their amounts in each view, one category
  for the whole group (« Classer le groupe »), and a menu on each line to
  answer it alone. Only the categories of the year of the same nature are
  offered.

**Evidence.** `test/pages/year/phase4_flows_test.dart`: a credit of the
fictitious statement attached at validation to a purchase, found by text,
then the purchase showing the refund and its net cost, and the refund
detached from its detail; a share answered from the « À classer » line,
the task gone and the amount in its category; a redistribution rule
created in Plus (two refusals first), its two lines in the year, month by
month and in both views. `test/pages/home/tasks_test.dart`: after a merge,
two redistribution rules above 100 % and a refund whose expense was deleted
on another device are tasks; deleting one rule and detaching the refund
clears them. Screenshots of each new screen, taken locally, were checked by
eye.

### 4.7 The performance test runs alone, every run checked

**Decision.** Every test file of `test/` holds a lock shared while it runs
(`test/flutter_test_config.dart`, `test/support/machine_lock.dart`: an
advisory lock on a file of the temporary directory). The performance test
writes its data under it, then takes it exclusive for its measurements: it
waits until it is the only test file running, and the files that start
meanwhile wait for it. Every one of its ten reloads must stay below 300 ms
and every one of its ten computations of both views below 100 ms; nothing is
skipped and every test of the suite runs.

**Why.** The development machine has 8 processors; `flutter test` runs test
files in concurrent processes, and the end-to-end files build batz-web and
run its servers. Measured among them, the same reload took from about
100 ms to 2.2 s, most runs above 300 ms; a first version of the test took
the best of five, then of ten runs, which the limits of the plan do not
allow. Holding the lock only while test servers run was not enough: the
screens of the other files still took a reload to 443 ms once.

**Evidence** (2026-11-21, development machine): the test alone, ten runs
each time, gave reloads of 82 to 107 ms and views of 7 to 20 ms; three
consecutive runs of the full suite gave reloads of 69 to 131 ms and views of
7 to 27 ms, every run below its limit, the suite taking 64 to 69 s instead
of about 63 s.

### 4.7 Version 0.5.0

The app and the server move to 0.5.0 together. The server's minimum app
version becomes 0.5.0: an app 0.4 would receive redistribution rules,
refund links and answers it does not know, keep them in its journal without
applying them, and show other totals than the devices that do. The tests of
the exchange send 0.5.0 and check that 0.4.0 and 0.4.1 are refused, at the
use case and over HTTP. An app 0.5.0 still works with the server 0.4.0 of
the NAS until it is upgraded. The rules of the annual view are described in
`docs/year-view.md`; the architecture, the API, the deployment (with the
upgrade to 0.5.0) and the README follow.

## 2026-11-21 — Phase 5 decisions taken during development

Functional choices H1 to H8 are in `docs/plan/phase-5.md`. The decisions below
were taken while implementing it.

### 5.0 A transaction counts for exactly its amount

**Decision.** In the annual view, a validated transaction outside transfers
whose lines do not add up to its amount gets one more flow: the difference,
unclassified, at its payment date, in both views. It shows in « Non classé »
and in its composition, under the transaction; saving the transaction again
writes both amounts and makes it disappear. For every year, the cash-flow
result plus « Non classé » is therefore the sum of the payments outside
transfers, which the balances of phase 5 will count.

**What the merge of the plan really does.** The plan's example (an amount
corrected on one device, the same entry attached to an expense on another)
leaves no gap: since 2.0, a modification writes only the fields whose value
changes, and attaching writes the line's amount only when it differs from
the transaction's on that device. The operations of the app always write
both amounts together, so two devices that start consistent stay
consistent. A gap needs a device that already holds one, or a version that
writes otherwise; the view copes with it anyway (principle 6).

**Evidence.** `test/domain/views/year_view_test.dart`: the merge of the plan
on two devices writes only the link and keeps both amounts equal; a line
amount written apart is counted as above, then saved again. The random
ledger of the view tests now holds such gaps (one line in fifteen), and
`checkViews` checks, year by year, cash-flow result plus « Non classé »
against the payments outside transfers.

### 5.0 Database of version 0.5.0

`batz-ui/test/fixtures/v0.5.0/batz.db` was written by version 0.5.0 (commit
`ce5e4b2`) through its own operations, with a fixed clock, in a scratch
worktree: three accounts (one detailed), the trees 2026 and 2027 (« Nourriture »
renamed in 2027), a redistribution rule and its copy, a refund attached to an
expense over three months, a payment over two years whose share of 2027 is
answered, and a transfer. `test/data/upgrade_test.dart` opens it with the
current version, checks each of these records and the views they give, then
writes after its latest entry.

### 5.1 Declared balances

**Decisions.**

- New journal entity `balance` (table `balances`): account, date and
  amount, read only when all three are valid. Its identifier is computed
  from the account and the date (`balanceId`): declaring twice the same day,
  on one device or two, writes one record whose amount follows the latest
  declaration. A declaration also writes `_deleted: false`, so that a balance
  deleted that day comes back. Modifying the date of a balance deletes it
  and declares the one of the new day in the same modification.
- Refusals, with their reason: an unknown account, the detailed account
  (its statements give the balance), a debts account (no balance of its
  own, H5), a date after today. Today is passed in by the screen, so that
  the rules are tested without a clock. An archived account accepts a
  balance: declaring 0 takes it out of the wealth (H4). A balance left on
  an account that became detailed can be deleted, not modified.
- The calculation lives in `domain/views/balances.dart`, next to the
  annual view, and reads the ledger: `ledger.balances` (cached with an
  `Expando` like the views) gives, per account, its points, its movements
  and the balance at any date. One function computes a balance from a point
  (the point plus the movements dated after its day, up to the date
  included); the balance at a date and the balance expected at a declared
  balance both go through it (principle 2). Movements are summed by date
  with running totals, found by binary search.
- Points: the declared balances, and for an account with statements, the
  opening balance of the first one (by start date) on the day before it
  starts, whether the account is still detailed or not. On the same day the
  statement's point comes first: a balance declared that day (only a merge
  can leave one) is then a point of its own, with its variation from the
  bank's balance. A debts account has no point, and an account that no
  longer exists neither: their declared balances are kept apart as ignored,
  and their movements stay listed (the wealth will count them elsewhere).
- Movements: a transaction's amount on its account, its opposite on the
  counterpart of a transfer, validated or proposed; a line to validate is a
  transfer only when its rules propose one, as in the annual view, whatever
  its stored counterpart.
- An account with declared balances is archived rather than deleted (H4);
  `AccountRemoval` counts them apart, and the message says that the account
  stays in the wealth with its last balance.
- The repository sends its ten queries in two groups awaited together:
  Dart's `wait` on a record takes nine futures at most.

**Evidence.** `test/domain/views/balances_test.dart` (the example of the
plan: 10'500 from 15.3 to 29.6 and 300 of variation on 30.6; the views
unchanged by declarations, also on random data; a movement on the day of a
balance; an account without balance; a negative balance; a proposed
transfer; the detailed account from its first statement's opening to its
closing balance; a balance left on an account that became detailed; each
refusal; replacing, moving, deleting and declaring again; archiving; an
account deleted on another device and balances left on a debts account;
two devices declaring the same day). `test/e2e/wealth_e2e_test.dart`
exchanges balances through a real server, and the convergence test
declares, modifies and deletes balances on four devices. The database of
0.5.0 opens, its derived tables rebuilt, and takes a balance.
