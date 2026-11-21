# batz

Personal accounting for a single user: where the money goes, what each year
really costs, and how net worth evolves. The app works fully offline on
Android, Windows and Ubuntu; a small server on the home network extracts bank
statements and keeps the reference copy of the change journal.

| Folder | Content |
|---|---|
| `batz-ui/` | Flutter app (Android, Linux, Windows). |
| `batz-web/` | Go server, one container, HTTPS only. |
| `docs/specification.md` | Functional and technical specification (French). |
| `docs/decisions.md` | Technical decisions and their evidence. |
| `docs/year-view.md` | How the annual view is computed, with examples. |
| `docs/wealth.md` | Balances, debts, the wealth and the table that explains it. |
| `docs/modules.md` | Salary sheet, flow diagram, taxes, vacations, electricity, subscriptions. |
| `docs/plan/` | Phase plans and acceptance criteria (French). |
| `scripts/` | Repository checks: personal files and terms, real statements. |

The annual view and its rules: [year-view](docs/year-view.md); the wealth
and its rules: [wealth](docs/wealth.md); the modules:
[modules](docs/modules.md). Server
documentation: [architecture](batz-web/docs/architecture.md),
[API](batz-web/docs/api.md), [synchronisation](batz-web/docs/sync.md),
[import of statements](batz-web/docs/import.md),
[deployment](batz-web/docs/deployment.md).

## Status

Version 0.7.0, end of phase 6 (modules). The app works on its own, on each
device, and synchronises with the server when it is reachable:

- accounts of the ten types of the specification, one of them detailed
  (import enabled), archiving;
- a category tree per year, copied from the previous one at the first
  transaction of a year, freely editable;
- manual expenses, incomes and refunds, transfers between accounts;
- the period a payment concerns, spread over its months and years;
- the change journal exchanged through the server: modifications made
  offline on several devices combine field by field, the latest winning; a
  lost device is revoked, a lost server is rebuilt from any device
  ([sync](batz-web/docs/sync.md));
- the monthly PostFinance statement imported through the server, which reads
  and checks it; the app checks that it follows the previous one and writes
  it whole; the original file kept on the server, the server database copied
  before each new file ([import](batz-web/docs/import.md));
- mapping rules per year (keywords, regular expressions, target, period
  model) that propose a classification for each imported line; lines to
  complete one by one, proposals confirmed in bulk, offline;
- the transactions list searched by text and filtered by account, period,
  category and status;
- the « Année » screen: the tree of a year with its amounts month by month,
  in the cash-flow view (what was paid in the year) or the economic view
  (what the year cost), the period offsets between them, and the
  transactions behind every amount; the key figures of the year on the home
  screen;
- redistribution rules that move a percentage of a category to another,
  month by month; refunds attached to their expense, which shows its net
  cost; the shares carried to a year without a category of the same name,
  classified once and remembered ([year view](docs/year-view.md));
- the « Fortune » screen: balances declared once or twice a year on each
  account, the detailed account following its statements; the value
  variation of each declaration, never an income nor an expense; the debts
  table (on me doit, je dois, split, checked); the net wealth of the day,
  its monthly curve, and for each year a table that explains its change to
  the cent; a reminder of the balances older than six months
  ([wealth](docs/wealth.md));
- the modules, in Plus › Analyses: the annual salary sheet and its gap; the
  flow diagram of a year, from the gross or the net to the taxes, the
  expenses and the savings, opened from « Année »; the taxes by fiscal year,
  their total, its share of the salary and a control against the economic
  view; the trips, grouped by their periods; the electricity per year, its
  price, kWh, days and ratios; and the subscriptions with their cost per
  month and per year ([modules](docs/modules.md)).

Phase 0 provided the foundations: app and server skeletons, local database
driven by a change journal, device pairing over pinned HTTPS, CI and
releases.

## Development

Requirements: Go 1.27, Flutter 3.47, Docker; for the Ubuntu build `clang`,
`cmake`, `ninja-build`, `pkg-config`, `libgtk-3-dev` and `libsecret-1-dev`;
the Android SDK and a JDK 17 for the APK.

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
flutter test benchmark/first_exchange_test.dart   # by hand: a first exchange of 20 000 entries
flutter test benchmark/journal_write_test.dart    # by hand: a modification of 1 000 fields
flutter test test/data/performance_test.dart      # alone: reload, views, wealth and modules with 10 000 transactions
flutter run -d linux
```

The extraction of statements needs `pdftotext` (`poppler-utils`) on PATH.

CI (`.github/workflows/ci.yml`) runs all of this, plus the Windows, Ubuntu and
Android builds, and a check of the server image that extracts the test set
inside it (`batz-web/scripts/check-image-extraction.sh`), on every change.

## Personal data

Bank statements, personal mapping configurations and signing keys are never
committed. `scripts/check-personal-files.sh` fails if git tracks such a file;
CI runs it on every change. With a local `personal/terms.txt` (never
committed: names, address, account and card numbers, one per line), it also
fails if one of those terms appears in a tracked file, the text of PDF files
included, or in a commit message.

Real statements kept at the root of the repository serve only local checks:
`scripts/check-real-statements.sh` extracts each and prints only its verdict
and number of lines, and compares dates and amounts with the CSV of the
original script when there is one. The test set is fictitious, written by a
generator (`batz-web/src/internal/infrastructure/extraction/postfinance/fake`).

## Licence

MIT, see `LICENSE`.
