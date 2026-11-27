# batz

Personal accounting for one person: where the money goes, what each year
really costs, and how net worth evolves.

batz imports the monthly PDF statement of the bank, proposes a category for
each line from rules you write once, and keeps two views of every payment:
the day it was paid, and the period it is for. It runs fully offline on
Android, Windows and Ubuntu; a small server on your home network reads the
statements and keeps the reference copy of the data. Nothing leaves your
home, and there is no account to create.

**Status: alpha** (version 0.10.0-alpha). Everything planned for version 1.0
is there; the version number will follow once it has been used for a while.
The screens are in French; the bank statements read are those of
PostFinance, in Swiss francs.

## What it does

- **Import and validation.** The statement of the month is sent to the
  server, which reads and checks it; its lines arrive « à valider », already
  classified by your mapping rules (lines of keywords, each line an
  alternative, under the category or account they classify in). Confirm the
  proposals one by one or in bulk, complete the rest, create a rule or a debt from a line. Validation works offline,
  on the phone.
- **Two views of a year.** The cash-flow view shows what was paid in the
  year; the economic view shows what the year cost: a payment that concerns
  twelve months from September counts four months this year and eight the
  next. A category tree per year, month by month, with the transactions
  behind every amount; redistribution rules; refunds attached to their
  expense ([annual view](docs/features.md#annual-view)).
- **Net wealth.** Declare the balance of an account once or twice a year;
  the gap with the expected balance is a value variation, never an expense.
  Debts, a monthly curve, and for each year a table that explains the change
  of the wealth to the cent ([wealth](docs/features.md#wealth)).
- **Modules.** The annual salary sheet, a flow diagram from the gross salary
  to the taxes, the expenses and the savings, taxes by fiscal year, trips,
  electricity with its kWh, subscriptions ([modules](docs/features.md#modules)).
- **Synchronisation.** Every device holds all the data and works offline.
  Modifications made on several devices combine field by field through the
  server; a lost device is revoked, a lost server is rebuilt from any device
  ([synchronisation](docs/architecture.md#synchronisation)).
- **Export.** Everything entered or imported, as a ZIP of CSV files a
  spreadsheet opens, made on any device, offline
  ([export](docs/features.md#export)).
- **Lock.** The Android app opens behind the lock of the phone; its local
  database is encrypted ([security](docs/architecture.md#security)).

## Install your own instance

batz is not a service: each person runs their own server and apps, with
their own data. You need a machine that runs Docker on your home network (a
NAS is enough; it may be switched off most of the time) and the files of the
[latest release](https://github.com/alkariin/batz/releases).

1. **Server.** Load the image `batz-web-<version>.tar.gz` and start the
   container ([deployment](docs/deployment.md)). The server creates its
   HTTPS certificate on its first start. Do not expose it to the Internet.
2. **Apps.** Android: add `https://github.com/alkariin/batz` to
   [Obtainium](https://github.com/ImranR98/Obtainium), or open the APK.
   Ubuntu and Windows: extract the archive and run `batz`.
3. **Pair each device.** On the server, `docker exec batz-web batz-web
   pairing-code` prints a code valid ten minutes and the fingerprint of the
   certificate. In the app: « Plus › Serveur », the address of the server,
   the code, a name for the device; compare the fingerprint shown with the
   printed one.

A new version installs over the previous one and keeps its data; each
release says whether the server or the apps go first. Every app holds a full
copy of the data, so a lost server is rebuilt from any of them.

## First steps

1. « Plus › Comptes »: create your accounts. Enable the import of statements
   on the bank account: it becomes the *detailed* account, the one whose
   every line is imported.
2. « Plus › Catégories et règles »: build the tree of the year, under groups
   of income and of expenses. batz comes with no tree: yours is the right one. It is
   copied to the next year at the first transaction dated there.
3. « Transactions »: import the first statement (at home, the server on).
   Complete its lines; create a rule each time a line will come back. The
   next statements arrive mostly classified.
4. « Fortune »: declare the balance of the other accounts (savings, pension,
   cash), with its date. Come back once or twice a year.
5. « Année » shows the year as it fills; « Plus › Analyses » holds the
   modules.

## Documentation

| Document | Content |
|---|---|
| [features](docs/features.md) | The annual view, the wealth, the modules and the export: rules and examples. |
| [architecture](docs/architecture.md) | App and server, local database and journal, synchronisation, import of statements, security, tests. |
| [API](docs/api.md) | The HTTP API of the server. |
| [deployment](docs/deployment.md) | Installing, upgrading and pairing; the Android signing key; releasing. |
| [decisions](docs/decisions.md) | Technical decisions and their reasons. |

## Development

`batz-ui/` is the Flutter app (Android, Linux, Windows), `batz-web/` the Go
server (one container, HTTPS only).

Requirements: Go 1.27, Flutter 3.47, Docker, and `pdftotext`
(`poppler-utils`) on PATH for the extraction of statements; for the Ubuntu
build `clang`, `cmake`, `ninja-build`, `pkg-config`, `libgtk-3-dev` and
`libsecret-1-dev`; the Android SDK and a JDK 17 for the APK.

```sh
# Server
cd batz-web/src
go vet ./... && go test -race ./...
BATZ_DATA_DIR=../data go run . serve       # https://localhost:8443
BATZ_DATA_DIR=../data go run . pairing-code
go run . extract internal/infrastructure/extraction/postfinance/testdata/2026-01.pdf
go test ./internal/infrastructure/extraction/postfinance/fake -update   # rewrite the test set

# App (its end-to-end tests build and start the server: Go must be on PATH,
# or BATZ_SERVER_BIN must point to a built batz-web)
cd batz-ui
flutter analyze && flutter test
flutter test test/data/performance_test.dart      # alone: 10 000 transactions
flutter test benchmark/first_exchange_test.dart   # by hand: a first exchange of 20 000 entries
flutter test benchmark/journal_write_test.dart    # by hand: a modification of 1 000 fields
flutter run -d linux
```

The texts of the app are French and live in `batz-ui/lib/l10n/app_fr.arb`;
run `flutter gen-l10n` after editing it.

CI (`.github/workflows/ci.yml`) runs all of this on every change, plus the
Windows, Ubuntu and Android builds and a check of the server image. The
release workflow builds the files of each GitHub release
([releasing](docs/deployment.md#releasing)).

## Personal data

Bank statements, personal mapping configurations, exports of the app and
signing keys are never committed: `.gitignore` keeps them out and CI fails if
one is tracked. The statements used by the tests are fictitious, written by a
generator (`batz-web/src/internal/infrastructure/extraction/postfinance/fake`).

## Licence

MIT, see `LICENSE`.
