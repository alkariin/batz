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

### 5.2 Debts

**Decisions.**

- New journal entity `debt` (table `debts`), the « Debt » of chapter 6 of
  the specification: direction (`owedToMe`, `iOwe`), person, amount in
  cents, percentage in hundredths of a percent (`basisPoints`, as the
  redistribution), the four dates of the specification, description and
  « remboursé »; plus `enteredOn` and `checkedOn`, written by the app. A
  debt is read when its direction is known and it has a person, an amount,
  a percentage and its day of entry; a date that cannot be read counts as
  missing. Operations and rules live in `domain/ledger/debt.dart`, as an
  extension of the ledger.
- Total: amount × percentage, rounded to the cent, halves away from zero
  (`redistributedCents`, the same rounding as the redistribution).
- A debt counts from its event date, or its day of entry, to the day before
  its date of receipt, or before the day it was checked, while repaid; not
  repaid, it counts from its start on, whatever its date of receipt. A debt
  repaid with neither date (only another version could write one) counts on
  no day. `openDebtsAt` gives the signed sum; `debtTotalsAt` the totals « on
  me doit » and « je dois » of the debts that count that day, whose
  difference is that sum.
- Checking (`checkDebt`) takes the date of receipt the screen proposes
  (today) or none, and records today as the day checked; unchecking clears
  that day and keeps the date of receipt. A modification that does not
  change the state keeps the day checked; one that checks or unchecks
  records or clears it. The day of entry never changes.
- Refusals, with their reason: an empty person, an amount of zero or less,
  a percentage out of 0.01 to 100 %, a date of receipt before the event
  (only when both are given), a first part of a split that is not strictly
  between zero and the total, an unknown debt.
- Splitting (H6) writes the first part on the debt and the rest on a new
  one, both at 100 %, every other field copied, the days of entry and check
  included: the two count on exactly the same days as the original.

**Known limit.** The same debt split on two devices offline: the debt keeps
the first part of the latest split, and both second parts are kept, each a
new record; their totals then exceed the original. The user deletes the one
too many. Computing the identifier of the second part from the first would
have made two splits of different amounts write the same record, but a
debt split again after being modified back would overwrite an earlier part;
the plan accepts the limit. `test/domain/ledger/debts_test.dart` shows it.

**Evidence.** `test/domain/ledger/debts_test.dart`: 200 at 50 % is 100 and
the rounding of halves; each bound of dates; the example of the
specification (the line « Dettes » is the sum of the debts not repaid that
count, day by day); 10 random sets of 40 debts checked every day of 2026
against decision H5 read literally; a split to the cent with every field
kept; each refusal; the day checked kept or changed. The end-to-end test
sends debts, a split and a check through a real server, and the convergence
test creates, modifies, checks, unchecks, splits and deletes debts on four
devices.

### 5.2 The performance test runs alone from its first write

**Decision.** The performance test now holds the machine lock exclusive for
its whole body, data written included, and once the lock is exclusive it
waits until the processors are quiet (two samples of 200 ms below 10 % busy,
20 seconds at most, read from `/proc/stat` on Linux). The limits and the ten
runs checked are unchanged.

**Why.** After step 5.1, the first of the ten reloads took 473, 317 and 331
ms in three runs of the full suite, the nine others 80 to 110 ms, and 100 to
115 ms alone. Timed apart, the database read was the slow part (207 ms, then
about 55 ms), and an idle pause before the measurement alone did not
reproduce it. The development machine has 9 GB of memory, its swap 3.5 GB
full out of 3.8: while the test waited for the lock, after writing its data,
the other test files took the memory and its pages were swapped out. Written
and measured alone, they stay in memory.

**Evidence** (2026-11-21, development machine): three consecutive runs of
the full suite, every test passing, gave reloads of 77 to 121 ms and both
views of a year 7 to 28 ms; the machine was quiet 0.6 to 0.8 s after the lock
was taken.

### 5.3 The wealth and its explanation table

**Decisions.**

- The calculation lives in `domain/views/wealth.dart`: `ledger.wealth(today)`
  (cached per ledger and day) gives the wealth at any date, the accounts at
  a date, the monthly curve, the table of a year and the old balances. The
  wealth at a date is the balance of every account that has one (it exists
  and is not a debts account) plus `openDebtsAt`; the accounts, the curve
  and the table all go through that one function.
- Each line of the table is computed for itself: the two results and the
  offsets from the annual views; value variations and accounts added from
  the points of the year; the line of the debts from the open debts at both
  ends and the movements of the year on the debts accounts; « Non classé »
  from the cash-flow view; « Hors fortune » from the movements of the year
  of the accounts without a balance before their day (a movement of the day
  of the first balance is part of it) or that no longer exist; the change
  of the wealth from the wealth at both ends. `explained`, their sum, is
  used by the tests only; the screen never shows it.
- The table of the current year stops today (H8). Its annual views come
  from `YearViews(ledger, until: today)`: what is paid after today does not
  count yet, neither in the results nor in the wealth. The same cut applies
  to the tables of past years, where it only leaves out a payment dated
  after today for a past period; then the economic result of the table
  differs from the « Année » screen by that payment, until its day comes.
- A year before the first category tree has no annual view: its three
  results are zero and its « Non classé » holds every payment of the year
  outside transfers, which only a merge can leave.
- The wealth starts on its first day: the first balance of an account (the
  opening of the first statement included) or the first day a debt counts.
  The tables go from that year to the current one; the curve from that
  month to the current one, whose value is today's.
- The accounts of the wealth at a date are those that can have a balance of
  their own, by name: with a balance, archived or not (H4); without one,
  only those not archived (« sans solde, hors fortune »), the detailed
  account before its first statement included. Each carries its last
  declared balance and its last statement at that date, and whether its
  balance is old.
- Old balances (H7): an account not archived, neither detailed nor a debts
  account, whose last declared balance is before the same day six months
  earlier (the day clamped to the month: 31.8 gives 28.2). An account
  without a declared balance is never one.

**Evidence.** `test/domain/views/wealth_test.dart`: the example of the plan,
entered through the operations of the app (the statement of 2026 imported
then classified), gives each line and 12'359.00, and 15'000.00 of accounts
added in 2025, the year without view; the same data seen on 31.7.2026 stop
there; a pure loan leaves the wealth and the line of the debts at zero at
each step; an advanced expense, then its refund, are explained at each step;
on 25 random ledgers (`test/support/random_wealth.dart`: declared and
undeclared accounts, an archived one, a deleted one, a detailed one with its
first statement, balances on the day of a movement or after the day seen,
balances left on a debts account and a deleted one, debts, transfers to
« Dettes », proposed transfers, merge gaps), each seen on three days, every
table adds up to the change of the wealth, economic result plus offsets
make the cash-flow result, each line is not zero somewhere, and each month
of the curve is the wealth computed at its date; old balances; no wealth
without balances nor debts.

**Measure** (`test/data/performance_test.dart`, 2026-11-21, development
machine). The data of phase 4 with 12 accounts, 100 declared balances on ten
of them and 200 debts (`test/support/large_ledger.dart`). Reload after a
write, with the net wealth of the key figures and the old balances among
the tasks: 86 to 129 ms over the ten runs of two runs of the test (alone
and in the full suite). The « Fortune » screen on a ledger just loaded (the
accounts at the day, 61 months of curve, the table of the last year, the
balances and the views as of that day computed): 11 to 36 ms. Below the
300 and 100 ms of the plan; the test fails if any run exceeds them.

### 5.4 The « Fortune » screen and the screen of an account

**Decisions.**

- `AppServices.today` gives the day of the device's calendar (by default
  `CalendarDate.today`); the screens of phase 5 read it (the wealth, an
  account, the tasks, the key figures, the debts), and the interface tests
  set it. The rules of the domain take it as a parameter.
- « Fortune » takes the fourth entry of the navigation. From the top: the
  net wealth of the day and its change since 31 December of the year before;
  the accounts by type, each type with its total, each account with its
  balance and the date it comes from (the end of its last statement for an
  account that has statements, otherwise its last balance) and « ancien »
  when its last declared balance is more than six months old; the line
  « Dettes »; the accounts without balance, not archived; the curve; the
  table. On a wide screen the cards keep a readable width.
- The curve is drawn by the app (`WealthCurve`, a `CustomPainter`): a line
  through the end of each month, the zero line, a dot per month up to three
  years. Touching or dragging along it selects the nearest month, whose
  month and amount show above it; the current month is shown first.
- The table offers the years of the wealth, the current one first. Each
  line shows its amount, signed after the results. Value variations,
  accounts added and « Hors fortune » unfold account by account, the line of
  the debts into the open debts at both ends and the movements of the debts
  accounts. The two results open the « Année » screen of that year (pushed,
  so that the year is kept), « Non classé » the validation. « Hors fortune »
  shows only when it is not zero (H3). A year without annual view says so.
- The screen of an account (`AccountPage`), opened from « Fortune », from
  the task of an old balance or from the form of the account (« Soldes et
  mouvements »): the balance of the day and its date; the movements since
  the last balance; the history, latest first, each balance with the one
  expected, its value variation and the movements since the balance before,
  which unfold and open their transaction. « Déclarer un solde » asks for an
  amount (a negative one is allowed: a loan) and a date, today by default;
  a declared balance of the history is modified or deleted the same way.
  Once saved, the value variation of the balance is shown (or, for the
  first one, the amount it brings into the wealth). The detailed account
  and a debts account have no button and say why. Balances that do not
  count (on a debts account, after a merge) are listed and can be deleted.
- Home screen: one task per account whose balance is old, which opens the
  account; the key figures show the net wealth of the day, which opens
  « Fortune », as soon as the wealth holds something.
- `EmptyPage`, the placeholder of the sections, is gone: the five sections
  all have their screen.

**Evidence.** `test/pages/wealth/wealth_page_test.dart`: the example of the
plan on the « Fortune » screen (accounts, debts, the curve read at both
ends, every line of the table of 2026, lines unfolded, « Non classé » to the
validation and the result to « Année »), the table of 2025 on a wide screen;
a balance declared from the account screen shows its variation of 300.00,
one in the future is refused with its reason, then modified and deleted;
an old balance is a task that leads to its account and disappears once a
balance is declared, the limit of six months to the day included; the net
wealth among the key figures opens « Fortune ». Screenshots of the new
screens, taken locally with the real fonts at phone and desktop sizes, were
checked by eye; they are not kept.

### 5.5 The debts table

**Decisions.**

- The line « Dettes » of « Fortune », and the screen of a debts account,
  open the table (`DebtsPage`): the totals « on me doit », « je dois » and
  net of the debts that count today (the net is the line of the wealth),
  then the debts not repaid, then those repaid, each with its person and
  description, its direction, the day it counts from and its date of
  receipt, and its total signed as it counts in the wealth.
- A box checks a debt as repaid: a dialog proposes today as the date of
  receipt, which can be changed or left empty (the day checked then
  serves). Unchecking writes at once. A menu on each debt splits it (the
  first part is asked for, between zero and the total, the second part
  shown once done) or deletes it, after a confirmation.
- The form (`DebtFormPage`) holds every field of the specification: the
  direction, the person, the amount, the percentage (100 by default, two
  decimals at most), the total computed as they are typed, the
  description, the four dates (each optional, typed or picked), and
  « Remboursée », which proposes today as the date of receipt when there is
  none. A refusal of the domain shows its reason; a date that cannot be
  read is refused before. The form also deletes the debt.

**Evidence.** `test/pages/debts/debts_page_test.dart`: a debt of 200 at 50 %
entered from « Fortune » (total computed on screen, the fields written,
the day of entry recorded), split into 40 and 60 after a first part out of
the total is refused, the part of 60 checked with today proposed, then
unchecked, the other part deleted: the totals of the table and the line
« Dettes » of the wealth follow at each step; a debt without person and a
receipt before the event are refused with their reason, and « je dois »
takes from the wealth. Screenshots of the list and the form, taken
locally with the real fonts, were checked by eye; they are not kept.

### 5.5 The end-to-end files delete what they create

**Decision.** `LocalServer` records the directories it creates, the
batz-web binary it builds and the data directories of its servers, and
`test/flutter_test_config.dart` deletes them when each test file ends.

**Why.** Each end-to-end file builds its own binary (38 MB) in a new
temporary directory, and never deleted it. After the runs of phases 2 to 5,
289 of them filled the disk of the development machine (11 GB in `/tmp`),
and a run of the suite stopped, unable to write. They were deleted by
hand, with 232 data directories of test servers. Since then, a full run
leaves nothing in `/tmp` but the file of the machine lock.

### 5.6 Version 0.6.0

The app and the server move to 0.6.0 (the app's build number to 7). The
server's minimum app version becomes 0.6.0: an app 0.5 would receive
declared balances and debts it does not know, keep them in its journal
without showing them, and its user would see no wealth. The tests of the
exchange send 0.6.0 and check that 0.5.0 and older are refused, at the use
case and over HTTP. An app 0.6.0 still works with the server 0.5.0 of the
NAS until it is upgraded. The rules of the wealth are described in
`docs/wealth.md`; the architecture, the API, the deployment (with the
upgrade to 0.6.0) and the README follow.

## 2026-11-21 — Phase 6 decisions taken during development

Functional choices H1 to H8 are in `docs/plan/phase-6.md`. The decisions below
were taken while implementing it.

### 6.0 An archived account at 0 leaves « Fortune »

**Decision.** The accounts of the wealth at a date leave out an archived
account whose balance is 0 or that has none (decision H4 of phase 5: a
balance of 0 takes it out). It stays in Plus › Comptes, and on the dates
when its balance was not 0. `test/domain/views/wealth_test.dart` checks it.

### 6.0 What the modules read from the annual view

**Decisions.**

- The amount of a line before it is placed in a year, internal until now,
  becomes `ViewLine`, read only: its transaction, its own line
  (`ownLineId`: the line, or for a line to validate the identifier it will
  get once validated, what the modules attach kWh or a trip to), the line
  whose answers it follows, its category of origin and that year, its
  amount and its period (for an attached refund, the expense's).
- `YearViews.linesIn(year, kind, categoryId)` gives, for a category of a year
  and everything below it, each line that counts there and what it places
  there month by month, with the placement of the views and before any
  redistribution (H1). A line counted in the year is listed even when its
  shares round to zero there.
- `YearViews.linesNamed(name)` gives the lines classified, in the tree of the
  year of their category, in the category of that name or below it, every
  year together (the trips).
- Neither changes an amount; the tests check on random data that the lines
  of each category of each year and view make what the view shows before
  redistribution.

### 6.0 Settings of the modules

New journal entity `moduleSetting` (table `module_settings`): the module and
the name of its category, one record per module with an identifier computed
from the module. Without a record, the default names of H1. The category of
a module in a year is the category of that name in the tree the year is
shown with (a year to come included), compared as names between years; a
group counts with everything below it; none when the tree has no such name.
The records of the modules are kept together in `ModuleRecords`, read by the
repository in a group of their own.

### 6.0 Database of version 0.6.0

`batz-ui/test/fixtures/v0.6.0/batz.db` was written by version 0.6.0 (commit
`76daa85`) through its own operations, with a fixed clock, in a scratch
worktree: four accounts (one detailed, one debts account), an expense, a
transfer, three declared balances and three debts, one of them split and a
part checked. `test/data/upgrade_test.dart` opens it with the current
version, its derived tables rebuilt, checks the balances, the variation and
the open debts, then writes a setting of a module after its latest entry.

### 6.1 Salary sheet

**Decisions.**

- New journal entities `salarySheet` (table `salary_sheets`: year, gross,
  net, in cents) and `salaryDeduction` (table `salary_deductions`: sheet,
  label, amount, rank). The sheet's identifier is computed from its year;
  a deduction's is random (principle 5). A deduction whose sheet is missing
  is left out when read.
- One operation saves the whole sheet as the form shows it
  (`saveSalarySheet`): the sheet's fields (and `_deleted: false`, so that a
  deleted sheet comes back), each deduction with its label, amount and rank
  in the order of the form, a new one with a new identifier, and the
  deletion of those no longer in the form. Deleting the sheet deletes its
  deductions. Refusals, with their reason: a gross of zero or less, a
  negative net, a deduction without label or negative.
- The gap is gross minus the deductions minus net. The screen computes it as
  the amounts are typed and shows it when it is not zero, never refusing to
  save; at zero it says that the gross minus the deductions gives the net.
- A year without sheet proposes the labels of the closest earlier sheet, or
  AVS, AC and LPP, with empty amounts.
- « Plus » now starts with « Analyses » (the modules), then the settings
  under « Réglages ». Each module screen shows its linked category
  (`ModuleCategoryTile`): its name, whether the tree of the year shown has
  it, and a dialog to change the name.

**Known limit.** Two devices creating the sheet of the same year offline
write one sheet, as required, whose fields follow the latest; but each
device's deductions have their own identifiers, and both sets are kept. The
user removes the extra ones; `test/domain/modules/salary_test.dart` shows it.

**Evidence.** `test/domain/modules/salary_test.dart` (the example, 0.00 then
56.00 of gap; deductions added, moved, removed; deletion and return; each
refusal; the labels proposed; two devices; views and wealth unchanged) and
`test/pages/modules/salary_page_test.dart` (the example typed in the screen,
the gap as it is typed, saved, modified, a refusal, deleted; the name of the
category changed and missing from the tree).

### 6.2 Flow diagram

**Decisions.**

- `flowDiagram` (`domain/modules/flow.dart`) reads the view of the year
  shown, its amounts with redistribution. Each node has a signed amount,
  as it adds to the result: positive on the left, negative on the right.
  In order: the salary (or « Salaire brut » and each deduction), the taxes,
  each top-level group in the order of the tree (whole, or without the
  designated categories it holds), « À classer » of each nature; then
  « Épargne » on the right, or « Puisé dans la fortune » on the left, from
  the savings of the view. A node of zero is left out.
- A designated category weighs what it adds to its top-level group: its
  amount plus its redistribution lines. Its group is shown for the rest,
  « Groupe hors Catégorie » (« hors A et B » when both are in it). A
  designated category that is itself a top-level group replaces it; when
  one designated category holds the other, the outer one only counts.
- The diagram starts from the gross when the sheet of the year exists and
  the salary category is found: « Salaire brut » is the net received plus
  the deductions, and the gap with the gross entered is signalled.
- The bands match both columns stacked in their order: each part of the
  left stack flows to the part of the right stack at the same height. The
  gross thus splits first into the deductions, then into the taxes and the
  expenses.
- The screen (`FlowPage`), opened by « Flux » on « Année » with its year and
  its view, keeps the toggle. It draws the bars and the bands (a colour per
  destination), names each node with its amount beside its bar (moved down
  when labels would overlap), then lists the nodes of each side and their
  total. The drawing keeps at most 900 logical pixels wide. It recalls when
  « Non classé » is left out, and why it starts from the gross or the net.

**Evidence.** `test/domain/modules/flow_test.dart`: the example with the
sheet (96'144.00 each side, every node, the gross splitting into the
deductions) and without (84'000.00); 83'000.00 received (95'144.00, a gap of
-856.00); expenses above income; a group of expenses in gain and a negative
income; the salary and taxes categories missing; on 15 random ledgers, with
and without sheets, every year and view: both sides equal, the bands carry
each node, the nodes give back income, expenses and savings.
`test/pages/modules/flow_page_test.dart`: from « Année » on a phone in both
views, and on a desktop in the dark theme without sheet. Screenshots taken
locally with the real fonts, phone and desktop, light and dark, were checked
by eye; they are not kept.

### 6.3 Taxes

**Decisions.**

- New journal entities `taxYear` (table `tax_years`: year, taxable wealth in
  cents, marginal rate in hundredths of a percent) and `taxLine` (table
  `tax_lines`: year, tax, base in cents, base rate in ten-thousandths of a
  percent, coefficient in hundredths of a percent), with identifiers
  computed from the year, and from the year and the tax. The five taxes are
  fixed (`TaxKind`); the lines of wealth have no base of their own: they use
  the taxable wealth of the year.
- One operation saves the year and its five lines as the form shows them;
  deleting the year deletes its lines. Refusals, with their reason: a
  negative base or taxable wealth, a base rate out of 0 to 100 %, a negative
  coefficient, a marginal rate out of 0 to 100 %. A field left empty is
  kept empty; a line without base or rate counts 0; a coefficient left empty
  is 100 %.
- Amount = base × base rate × coefficient, computed exactly (`BigInt`) and
  rounded once, halves away from zero. The total rate (base rate ×
  coefficient) is rounded to the fourth decimal, for display only. The
  shares of the gross and of the net of the salary sheet of the year are in
  hundredths of a percent; without sheet, none.
- Paid for the year: minus the sum of what `linesIn` places in the taxes
  category of the year in the economic view, before redistribution (H1),
  refunds deducted. No control when the year has no tree (a year before the
  first tree can be entered) or its tree no such category.
- The screen computes each line, the total and the control as the values are
  typed, with the functions of the domain; it is saved as a whole. Two
  helpers of `formats.dart` type and show percentages with a fixed number of
  decimals (`2.5000 %`, `155.00 %`). The summary lists every year entered:
  total, shares, marginal rate, paid and gap.

**Evidence.** `test/domain/modules/taxes_test.dart`: the example line by line
(15'033.80, 15.66 % and 17.93 %); the control (15'000.00 paid for 2026, 33.80
left, while the cash-flow view shows 14'500.00); a year before the first tree;
halves; incomplete lines; on 200 random draws, each amount against an exact
computation and the total against the sum of the lines; each refusal;
modification and deletion; two devices; views and wealth unchanged.
`test/pages/modules/taxes_page_test.dart` types the example in the screen.
A screenshot on a phone, with the real fonts, was checked by eye.

### 6.4 Vacations

**Decisions.**

- The lines of a trip are those `linesNamed` gives for the vacation category,
  every year together: classified in the tree of their year (a line to
  validate as proposed, an attached refund with the category and the period
  of its expense). Sorted by the start of their period, a line joins the
  current trip while it starts at most 15 days after the latest end so far;
  this is the « de proche en proche » of H5 (two intervals overlap or touch:
  0 days of gap).
- New journal entity `tripSheet` (table `trip_sheets`): the line it is
  attached to, place, days, and the date and amount (a cost, positive) that
  replace the automatic ones. A sheet attached to a line has an identifier
  computed from that line; a manual line has none, and a random identifier.
  A line is identified by `ownLineId`: for a line to validate, the line it
  will get once validated, so that a sheet survives the validation.
- The sheet that applies to a trip is the one of its oldest line (the first
  by start, payment date, line); the others are signalled on the trip and
  can be deleted. A sheet whose line is in no trip (it left the category,
  or is gone) is listed apart and can be deleted. Entering the place or the
  days of a trip without sheet attaches one to its first line.
- A replaced date or amount is kept as entered; the automatic value is shown
  beside it, and « Rétablir » clears the replacement. The year of a trip is
  the year of its date, replaced or not. A manual line needs its date and
  its amount; one without them (only another version could write it) shows
  no trip.
- Price per day = amount ÷ days, rounded to the cent, halves away from
  zero; none without days. Refused, with their reason: days below 1, a
  manual line without date or amount.
- The trips are computed when the screen first asks for them, once per
  ledger (an `Expando`), never at the reload.

**Evidence.** `test/domain/modules/vacations_test.dart`: the example (two
trips, 1'825.00 and 130.36 a day; 300.00); the flight ticket with and without
its period; 15 and 16 days; a transaction between two trips joins them, its
period or its category changed parts them; replace and restore; two sheets
on one trip, an orphan sheet; manual lines; on 40 random sets (groups and
sub-categories, refunds, periods), each line in one trip only, the gaps
inside and between trips, the automatic amounts adding up to the lines;
views and wealth unchanged. `test/pages/modules/vacations_page_test.dart`
drives the screen through the example, a replacement and a manual line.

### 6.5 Electricity

**Decisions.**

- New journal entity `electricityReading` (table `electricity_readings`): the
  line (`ownLineId`) and its energy in Wh, with an identifier computed from
  the line. Erasing the kWh of a line deletes the record; negative kWh are
  refused.
- For a year, the lines are those `linesIn` gives for the electricity
  category of the year in the economic view, before redistribution (H1). The
  price is minus their total. The energy of a line is spread over its months
  with `allocate`, the function that spreads the amounts (the last month
  takes the remainder), and the year receives the shares of its months: a
  line counts in a year for all its months there, the category being found
  by name once per year. The days are those of the year covered by the
  period of at least one line, each day once.
- Ratios with one rounding each, halves away from zero: price per day in
  cents, per kWh in ten-thousandths of a franc, kWh per day in hundredths.
  None when the divisor is zero. The screen counts the lines without kWh,
  which overestimate the price per kWh.
- kWh whose line no longer counts in the category of its year (it left it,
  or is gone) are listed apart and can be erased.
- `formatDecimal` shows kWh and ratios with thousands separators; kWh are
  typed with three decimals at most (`parseScaled`), stored in Wh.

**Evidence.** `test/domain/modules/electricity_test.dart`: the example year
by year (2026: 1'220.00, 4'700 kWh, 365 days, 3.34, 0.2596, 12.88; 2027:
100.00, 400 kWh, 31 days, 3.23, 0.2500, 12.90), the cash-flow view of 2026
showing 1'020.00; an instalment and a final invoice over the same days; a
line without kWh; kWh entered, modified, erased, refused, left on a line
that left the category; a category missing; on 30 random sets, the price of
each year against the economic view and the kWh spread against the kWh
entered; two devices; views and wealth unchanged.
`test/pages/modules/electricity_page_test.dart` enters the kWh of the
example from the screen.

### 6.6 Subscriptions

**Decisions.**

- New journal entities `subscription` (table `subscriptions`: name, note)
  and `subscriptionTranche` (table `subscription_tranches`: subscription,
  amount in cents, frequency `monthly` or `yearly`, start, end; the column
  of the end is `end_date`, `END` being an SQL keyword). Both have random
  identifiers (principle 5). A tranche whose subscription is missing is left
  out when read. A subscription is created with its first tranche;
  deleting it deletes its tranches.
- Costs (H8): monthly = the amount, or the amount ÷ 12 rounded to the cent
  for a yearly tranche; yearly = the amount × 12, or the amount. A
  subscription is current when a tranche covers the day; to come when none
  does and one starts later; ended otherwise. The totals add the costs shown
  of the current ones.
- Adding a tranche closes, the day before it starts, the latest tranche that
  starts before it and has no end; an ended tranche is kept as it is (a
  resumption after an end). The new tranche is then refused if it overlaps
  another, as is a modified one (a modification closes nothing). Other
  refusals: no name, an amount of zero or less, an end before the start.
- Two tranches left overlapping by a merge: the subscription says so, and on
  a day both cover, the one that started last applies.
- « Abonnements » is an entry of « Plus » of its own, between the analyses
  and the settings, as the specification lists them.

**Evidence.** `test/domain/modules/subscriptions_test.dart`: the example
(22.82 a month, 273.80 a year, the gym ended); a change of price, a
resumption, a subscription to come; each refusal; two tranches left
overlapping by a merge of two devices; modifications and deletions; views
and wealth unchanged. `test/pages/modules/subscriptions_page_test.dart`
drives the screen: the totals, the order, a new price closing the previous
tranche, an overlap refused, a new yearly subscription. Screenshots of the
screens of vacations, electricity and subscriptions on a phone, with the
real fonts, were checked by eye.

### 6.7 Measure, synchronisation and version 0.7.0

**Measure** (`test/data/performance_test.dart`, 2026-11-21, development
machine). The data of phase 5 with a group « Modules » holding « Vacances »,
« Électricité » and « Impôts », 300 vacation lines (one in four over a week,
one in ten with a sheet), 60 monthly electricity invoices with their kWh, a
salary sheet and a fiscal year for each of the five years, and 40
subscriptions of 3 tranches (`test/support/large_ledger.dart`); 10 360
transactions in all. Over two runs of the test (alone, then in the full
suite), ten measures each: reload after a write 95 to 127 ms; on a ledger
just loaded, the salary sheet 0 to 2 ms; the taxes, the five fiscal years
with their control, 14 to 34 ms; the vacations 4 to 15 ms; the electricity,
five years, 16 to 42 ms; the subscriptions 0 ms; the diagram of the last
year 7 to 30 ms. Below the 300 and 100 ms of the plan;
the test fails if any run exceeds them. The modules are not computed at the
reload (principle 8).

**Synchronisation.** `test/e2e/modules_e2e_test.dart` enters something in
every module on one device, exchanges through a real server, and finds on
the other the same records and the same results (salary sheet, fiscal
year and its control, trips, electricity, subscriptions, diagram), then a
deletion on the second reaching the first; the same salary sheet, fiscal
year and kWh of a line entered on two devices offline give one record each.
The convergence test sets linked categories, saves and deletes salary sheets
and fiscal years, sheets of trips and manual lines, kWh, subscriptions and
tranches on four devices.

**Version.** The app and the server move to 0.7.0 (the app's build number to
8). The server's minimum app version becomes 0.7.0: an app 0.6 would receive
what is entered in the modules, keep it in its journal without showing it.
The tests of the exchange send 0.7.0 and check that 0.6.0 and older are
refused, at the use case and over HTTP. An app 0.7.0 still works with the
server 0.6.0 of the NAS until it is upgraded. The rules of the modules are
described in `docs/modules.md`; the architecture, the API, the deployment
(with the upgrade to 0.7.0) and the README follow.

## 2026-11-21 — Phase 7 decisions taken during development

Functional choices H1 to H8 are in `docs/plan/phase-7.md`. The decisions below
were taken while implementing it.

### 7.0 Writing the ZIP: `archive` 4.7.1

**Decision.** `archive` 4.7.1 (MIT licence, Brendan Duncan; its one new
dependency `posix` 6.5.4 is MIT too). The export builds an `Archive` of
`ArchiveFile.bytes` entries in memory and writes it with
`ZipEncoder().encodeBytes`, then hands the bytes to the save dialog: no
file of the export is ever written elsewhere. Only `package:archive/archive.dart`
is imported, never `archive_io.dart` (the file-system helpers).

**Evidence** (read in the package at that version, `README.md` and
`doc/platforms.md`, 2026-11-21): the package is pure Dart and runs on the
Dart VM, Flutter on mobile and desktop included; zip entries compressed with
deflate go through the zlib of `dart:io` there. Entries carry their own
modification time (`lastModTime`, in seconds since 4.6.0), set when the
entry is created: two exports of the same data give the same CSV files, not
the same ZIP bytes. `ZipDecoder().decodeBytes(…, verify: true)` checks the
CRC of every entry, which the tests use to read an export back.

### 7.0 Unlocking the phone: `local_auth` 3.0.2

**Decision.** `local_auth` 3.0.2 (BSD-3-Clause, the Flutter authors), with
its Android implementation `local_auth_android` 2.3.0 (same licence; it
brings `androidx.biometric` 1.1.0 and `androidx.fragment`). The app calls it
on Android only; `local_auth_windows` 2.0.2 comes with it and is never
called (no lock on desktops, decision H3); there is no Linux
implementation, and none is needed.

**What it asks of the Android app** (`local_auth_android` 2.3.0 `README.md`,
section « Setup », and its sources, read 2026-11-21):

- The activity must be a `FragmentActivity`: `MainActivity` extends
  `FlutterFragmentActivity`. Otherwise `authenticate` fails with
  `NOT_FRAGMENT_ACTIVITY`.
- The permission `android.permission.USE_BIOMETRIC`. The plugin's own
  manifest declares it and the build merges it; the app declares it too, as
  the README asks, so that the main manifest says what the lock needs.
- The `LaunchTheme` must have a `Theme.AppCompat` parent, « to prevent
  crashes on Android 8 and below » (the app's minimum is Android 7, API 24,
  the plugin's minimum too).
- `isDeviceSupported()` is true when the device has a screen lock
  (`KeyguardManager.isDeviceSecure`) or an enrolled biometric;
  `authenticate(localizedReason:, biometricOnly: false)` lets the system
  dialog fall back to the device's PIN, pattern or password (decision H3:
  fingerprint, face or code). Failures are `LocalAuthException`s with a
  `LocalAuthExceptionCode` (`userCanceled`, `systemCanceled`,
  `noCredentialsSet`, `temporaryLockout`, `biometricLockout`, `timeout`, …);
  a refused fingerprint is retried inside the system dialog and only its
  cancellation returns.
- `persistAcrossBackgrounding` stays false: the gate of the app decides
  what happens when it leaves the screen (step 7.3).

### 7.0 Database of version 0.7.0

`batz-ui/test/fixtures/v0.7.0/batz.db` was written by version 0.7.0 (tag
`v0.7.0`, commit `f6fb6ab`) through its own operations, with a fixed clock,
in a scratch worktree: two accounts, the 2026 tree, five expenses and
incomes, and an entry in every module (the vacations module set to
« Voyages », a salary sheet with three deductions, a fiscal year of three
lines, the sheet of a trip and a manual line, kWh on an invoice, a
subscription of two tranches). `test/data/upgrade_test.dart` opens it with
the current version, checks every module's results, and that the derived
tables are not rebuilt (principle 7: no new entity), then writes after its
latest entry.

### 7.0 Versions with a suffix, build numbers and tags

**Decisions.**

- `scripts/check-release-tag.sh TAG` is the check of the release workflow:
  the tag must be `v` followed by the version name of `pubspec.yaml`, suffix
  included (`0.8.0-alpha+9` → `v0.8.0-alpha`; `v0.8.0` is refused). It can
  be run by hand.
- `scripts/check-build-number.sh` reads the build number of
  `pubspec.yaml` at every tag `v*` and fails unless the current one is
  greater than all of them, the tag of the current version name itself left
  out (so it passes on the commit of a release). It fails too when there is
  no tag to compare with: CI checks out with `fetch-depth: 0`. CI runs it on
  every push, and the release workflow before building.
- The app and the server ignore anything after the three numbers when they
  compare versions (unchanged since phase 2): `0.8.0-alpha` is `0.8.0`.
  Tests of both now say so.
- An export is never tracked: `.gitignore` ignores `batz-export-*.zip` and
  `batz-export-*/`, and `scripts/check-personal-files.sh` refuses those
  names and a `LISEZMOI.txt` (the CSV files of an unzipped export were
  already refused, as any CSV outside test fixtures).

### 7.1 The files of the export

**Decisions.**

- `domain/export/` is pure Dart: `exportFiles(ledger)` gives the seventeen
  files of the plan, in its order, each with its headers and its sorted
  rows of typed cells; `csv.dart` writes them (decision H2). The export
  reads the ledger the screens read and nothing else (principle 1).
- Completeness (principle 2): `exportSchema` names, for every entity of the
  journal, its file, the column that holds the identifier of its records,
  and the column each field goes to with how its stored value is written
  (text, identifier, amount, percentage, rate, kWh, date, yes/no, integer,
  label, keywords). The deletion field is excluded from every entity (what
  is deleted is not exported, H1); no entity is excluded.
  `test/domain/export/export_completeness_test.dart` compares it with the
  derived tables of the app, so an entity or a field added later and not
  placed fails it, and checks that taking any entity or field out is
  caught.
- Each file sorts its rows by its own data, identifiers last: accounts by
  name; balances and statements by account and date; categories by year
  and in the order of the tree, the detached ones after; transactions by
  date and identifier; the modules by year. Two synchronised devices hold
  the same records, so they write the same bytes (principle 3; checked in
  step 7.2).
- What is written beside the stored values, so that a line reads alone
  (H1): the account by its name, a category by its path from its top-level
  group (« Logement > Loyer »; a detached category as far as its parents
  go), the parent's name, the statement of a line as its period
  (« du 2026-09-01 au 2026-09-30 »), the expense a refund is attached to as
  its date and description, the type of a validated transaction as the app
  deduces it (none for a line to validate: its proposal is not exported),
  the total of a debt, the amount of a tax line (none while its base or
  rate is missing), and the trips as the screen groups them.
- `transactions.csv` has one row per line, and one row for a transaction
  without line; the line keeps its own amount (« Montant de la ligne »),
  since the model allows several lines. A line to validate has no line
  yet: the kWh and answers attached to the identifier it will get are
  joined to its transaction all the same.
- `voyages.csv`: one row per trip, with its sheet when it has one, then one
  row per other sheet with its remark: « fiche en trop », « fiche sans
  transaction », or « ligne manuelle incomplète » (a manual line without
  date or amount, which the screen does not show as a trip).
  `electricite.csv` keeps kWh whose line is gone, without the columns of
  the transaction. `abonnements.csv` has one row per tranche, and one for
  a subscription without tranche. `reglages-modules.csv` has one row per
  module, with its default name and no identifier when none was chosen.
- Values written as the journal names them get a label: statuses, types,
  natures, directions of debts and frequencies in lower case (« validée »,
  « dépense », « on me doit », « mensuel »), as in the plan's example;
  account types, taxes, modules and period models as the app names them.
  The keywords of a rule are written one per line in their cell.
- Absent values are empty cells, except yes/no, where absent is « non »
  (the app reads it so).

**Evidence.** `test/domain/export/`: `export_format_test.dart` (each rule of
H2; 300 random rows of texts made of semicolons, quotes, line breaks,
accents and formula characters, read back identical by a CSV reader of the
tests and by the `csv` module of Python); `export_example_test.dart` (an
example ledger holding every sort of data gives exactly the files of
`test/fixtures/export/`, which were read by eye, its tax amounts and trip
recomputed by hand; the three lines of the plan's example; a ledger without
data gives seventeen files of headers); `export_completeness_test.dart`;
`export_records_test.dart` (five draws of 400 random operations of every
phase after a statement import and rules: every record of every derived
table not deleted is found in its file with each field written as expected,
computed apart from the code of the export; no deleted record and no
unknown identifier is found). The random operations of the convergence test
moved to `test/support/random_operations.dart` to serve both.

### 7.2 The ZIP and the export screen

**Decisions.**

- `buildExportArchive` (pure Dart) builds the ZIP in memory with `archive`:
  the seventeen CSV files in the order of the plan, then `LISEZMOI.txt`
  (UTF-8 with a byte order mark and CR LF, so that the Notepad of Windows
  reads it): the date of the export, the version of the app, the number of
  transactions, each file with its number of rows, what is not exported,
  the conventions of the format and how to open a file in Excel. Its name
  is `batz-export-AAAA-MM-JJ.zip`, from the day of the device
  (`AppServices.today`). The entries carry the time they were built; only
  the CSV files are expected to be the same on two devices.
- `FileAccess.saveZip` hands the bytes to the save dialog of `file_picker`
  (`application/zip`), as the PDF of a statement is saved since phase 3: the
  system document picker on Android, the XDG portal on Ubuntu, the native
  dialog on Windows. A cancelled dialog writes nothing, and the app keeps no
  copy of the export anywhere.
- « Plus › Réglages › Exporter les données » (`ExportPage`) says what the
  export holds and leaves out, that the file is not encrypted (in a card of
  the error colour), and that it needs no server and changes nothing; after
  the dialog it says « Export enregistré : 17 fichiers CSV et LISEZMOI.txt,
  N transactions. », or that the export was cancelled and nothing saved.
  The files are built on the main isolate, after a frame that shows the
  progress indicator: under 2 seconds with 10 000 transactions.
- The expected CSV files are marked `-text` in `.gitattributes`, so that no
  checkout changes their line endings.

**Evidence.** `test/domain/export/export_archive_test.dart` (the eighteen
entries in order, each CSV identical to its file, read back with checksums
by `archive` and by `unzip -t` and `unzip -Z1`; `LISEZMOI.txt` with its date,
version, counts and conventions); `test/pages/export/export_page_test.dart`
(from « Plus » on a phone: the texts, a save of the ZIP of the day with its
counts on the screen and a bank-like text `=SOMME(A1)` written `'=SOMME(A1)`,
then a cancellation that saves nothing; the journal unchanged by both);
`test/e2e/export_e2e_test.dart` (two devices entering 120 random operations
offline and exchanging through a real batz-web produce the same seventeen
CSV files byte for byte; the export leaves the journal as it was and the
next exchange sends nothing; with the server stopped, the export of the
other device is the same); the convergence test now also compares the CSV
files of its four devices; `test/data/performance_test.dart` measures the
export on the ledger of 10 000 transactions and the data of phase 6.

**Measure** (2026-11-21, development machine, in the full suite, ten runs):
the export of that ledger, its seventeen files and the ZIP, 312 to 372 ms,
below the 2 seconds of the plan; the reload after a write 87 to 116 ms. The
test fails if any run exceeds its limit. A first measure taken while an
Android build was still running gave three to five times as much: the
performance test is only meaningful on a quiet machine, which it waits for.

### 7.3 The lock of the Android app

**Decisions.**

- `DeviceLock` (`data/device_lock.dart`) is what the app asks of the device:
  whether it has a screen lock, and to unlock. An attempt ends unlocked,
  without screen lock, refused (cancelled by the user or by the system, a
  timeout, too many attempts) or failed. `SystemDeviceLock` does it with
  `local_auth`: `isDeviceSupported`, then `authenticate` with
  `biometricOnly: false` (fingerprint, face or the code of the device, H3),
  without the confirmation button after a recognised face, and with French
  texts for the system dialog (`AndroidAuthMessages`, hence
  `local_auth_android` named in `pubspec.yaml`: the Android half of the same
  plugin, no further library). It never throws: a code of the plugin it does
  not know, those added later included, and any other error is a failure
  shown on the lock screen. `AppServices.open` creates it on Android only; on
  Windows and Ubuntu the app has none, hence no lock.
- `LockCubit` holds the rule (H3, H4). The app starts locked. When it leaves
  the screen unlocked, the time is noted, once; when it comes back, it locks
  if strictly more than 60 seconds passed, or if the clock went back. The
  clock is the wall clock of the device (`AppServices.now`): a monotonic
  clock stops while the phone sleeps. The decision is taken in the lifecycle
  callback itself, before the first frame drawn after the return. A return
  tells whether the system dialog is to be opened: when it locks, and when
  the app was left locked without a dialog; never while a dialog is open
  (the code of the device typed on another screen), so one dialog at a time.
- « Leaving the screen » is the app hidden (its activity stopped), not a
  loss of focus: the notification shade, the fingerprint sheet or a split
  screen do not count. `AppLifecycleListener.onHide` and `onShow`.
- `LockGate` stands in `MaterialApp.builder`, in front of the navigator:
  every route and dialog is behind it. Before the first unlocking the
  navigator is not built at all. A locked app keeps it `Offstage` (laid out,
  not painted, no hit test, no semantics) and out of focus, so the screen
  and what was being typed are found again (principles 5 and 6). The cubits
  above it are untouched: the synchronisation goes on while locked.
- A phone without screen lock (H4): the app opens, and a task of the home
  screen says so. At each return the device is asked again; as soon as it
  has a screen lock the app is behind it, whatever the time away.
- Android: `MainActivity` is a `FlutterFragmentActivity`; the main manifest
  declares `USE_BIOMETRIC`; the launch theme and the normal theme get
  AppCompat parents (the README asks it of the launch theme; Flutter
  replaces it by the normal theme once started, the one the dialog opens
  under, so both); `setRecentsScreenshotEnabled(false)` from Android 13
  (H5), and no `FLAG_SECURE`: screenshots stay possible.
- The key of the database is unchanged: kept by the Android Keystore, not
  bound to the unlocking. The lock is a door in front of the screens
  (principle 5); `docs/security.md` says what it protects from.

**Not verified here.** The development machine cannot run an Android
emulator (no hardware virtualisation). The system dialog itself, the
fingerprint, the code of the device and the list of recent apps are checked
on a real phone after installation (plan, « À vérifier par l'utilisateur »).

**Evidence.** `test/pages/lock/lock_cubit_test.dart` (the example of the
plan line by line: 59, 60 and 61 seconds, the clock going back; the time
noted once; cancelled, too many attempts, error; one dialog at a time; a
return to a locked app; a phone without screen lock, then with one, then
without again; a computer). `test/pages/lock/lock_gate_test.dart`, with a
simulated phone and clock under the whole app: nothing of the app in the
widget tree before the first unlocking; the lock screen, its messages and
its buttons; a form half filled found again after a lock at 61 seconds and
after the clock going back, its screens off stage meanwhile; the warning of
the home screen; no lock on a computer. `test/data/device_lock_test.dart`
(every code of the plugin to its outcome). `test/android_manifest_test.dart`
(the permission, the activity, the themes, the recent apps). The release
APK builds with them, and `aapt dump permissions` on it lists `INTERNET`,
`USE_BIOMETRIC` and `USE_FINGERPRINT` (the last from `androidx.biometric`).
