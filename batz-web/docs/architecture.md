# Architecture

batz is an offline-first app with a small home server. The functional and
technical reference is `docs/specification.md` (French); this page describes
what is built and why.

## Responsibilities

| Part | Does | Does not |
|---|---|---|
| App (`batz-ui`) | Every calculation, on a full local copy of the data. | Depend on the server to work. |
| Server (`batz-web`) | Pair devices; later: keep the reference journal, extract PDF statements, store the original PDFs. | Compute anything accounting-related. |

The server is on the home network only and runs at weekends; the app must
never need it except to synchronise and import.

## Server

Go, Gin, SQLite (`modernc.org/sqlite`, pure Go, no cgo), one container.

```
batz-web/src
├── main.go                       commands: serve, pairing-code, healthcheck, version
└── internal
    ├── version                   build version, minimum app version
    ├── domain/device             devices, pairing codes, keys, errors
    ├── application               use cases (Devices) and their ports
    └── infrastructure
        ├── config                environment, read once at start-up
        ├── persistence           SQLite store and embedded migrations
        ├── tlscert               self-signed certificate, pinning helpers
        └── web                   routes, authentication, error mapping
```

- **Configuration**: `BATZ_DATA_DIR` (default `data`) and `BATZ_PORT`
  (default `8443`), read once by `config.Load`.
- **Data directory**: `batz.db` (SQLite, WAL) and `tls/server.crt` +
  `tls/server.key`. It is the only state to back up.
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

## App

Flutter, Bloc (cubits), Dio, Drift.

```
batz-ui/lib
├── domain        pure Dart, no Flutter
│   ├── journal   hybrid logical clock, journal entries, resolution rule
│   ├── ledger    accounts, category trees, transactions, their rules and totals
│   ├── allocation.dart, fraction.dart, calendar_date.dart   spreading over months
│   └── ids.dart
├── data
│   ├── local     Drift database, journal, derived tables, opening and encryption
│   ├── ledger    reads the ledger from the derived tables, writes to the journal
│   ├── server    HTTPS client with certificate pinning, pairing repository
│   └── secret_store.dart   system secret storage
├── pages         shell, transactions, accounts, categories, server settings, cubits
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
`local_state` table.

When the counter of the clock is full, the clock moves to the next
millisecond, so that a device whose clock ran far ahead never blocks the
writes of the others.

### Ledger

| Journal entity | Table | Fields |
|---|---|---|
| `account` | `accounts` | name, type, importFormat, archived |
| `category` | `categories` | year, name, parentId, nature (top-level groups), position |
| `transaction` | `transactions` | accountId, date, amount, counterpartAccountId, description, note, status |
| `transactionLine` | `transaction_lines` | transactionId, categoryId, amount, periodStart, periodEnd |

`LedgerRepository` reads every table into an immutable `Ledger` and leaves
out records that are incomplete or hold a value the version cannot read; a
category is kept only if its parents reach, in the same year, a top-level
group with a nature. Each operation is a method of `Ledger` that checks the
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

On Android the database is encrypted with SQLCipher (selected per platform
through the `sqlite3` package hooks, see `docs/decisions.md`). Its key, 32
random bytes, is created at the first launch and kept by
`flutter_secure_storage` (Android Keystore), with `resetOnError` disabled so
the key is never silently replaced. Opening fails rather than fall back to an
unencrypted database. Android backups are disabled: a database restored
without its key would be unreadable. Desktops use plain SQLite and rely on the
protection of the operating system.

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

- Server: unit and HTTP tests per package; `test/e2e` builds the binary and
  exercises pairing, refusals, revocation, restarts and certificate pinning
  over real HTTPS.
- App: the clock and the resolution rule; the journal against a naive
  reference model on shuffled histories from three devices; deletion,
  restarts and failed transactions; derived schema changes and the opening of
  a database written by version 0.1.0 (`test/fixtures`); allocation, with
  random amounts and periods; the rules of accounts, category trees,
  transactions and totals; a tree copied on two simulated devices; the
  ledger rebuilt from the journal; Swiss formats; widget tests of the
  navigation, the server, accounts and categories screens and the main path
  of the transactions screen; `test/e2e` drives the app's server code against
  a real `batz-web` process.
