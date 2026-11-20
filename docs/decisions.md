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
