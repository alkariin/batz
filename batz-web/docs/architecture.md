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
├── domain        pure Dart: ids, hybrid logical clock, journal entries, resolution rule
├── data
│   ├── local     Drift database, journal, derived tables, opening and encryption
│   ├── server    HTTPS client with certificate pinning, pairing repository
│   └── secret_store.dart   system secret storage
├── pages         shell (navigation), server settings and its cubit
├── components    shared widgets
├── helpers       Swiss formats, theme
└── l10n          French texts (ARB) and generated localisations
```

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
   and one column per field. They can be rebuilt from the journal at any
   time. Entries of entities unknown to the running version are kept in the
   journal and applied after an upgrade by a rebuild.

The device identifier is a UUID created at the first launch and stored in the
`local_state` table.

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
  restarts and failed transactions; Swiss formats; widget tests of the
  navigation and the server screen; `test/e2e` drives the app's server code
  against a real `batz-web` process.
