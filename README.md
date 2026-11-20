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
| `docs/plan/` | Phase plans and acceptance criteria (French). |
| `legacy/` | Original Python scripts, kept as a reference for phase 3. |

Server documentation: [architecture](batz-web/docs/architecture.md),
[API](batz-web/docs/api.md), [deployment](batz-web/docs/deployment.md).

## Status

Phase 0 (foundations): app and server skeletons, local database driven by a
change journal, device pairing over pinned HTTPS, CI and releases. No
accounting feature yet.

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

# App (its end-to-end tests build and start the server: Go must be on PATH,
# or BATZ_SERVER_BIN must point to a built batz-web)
cd batz-ui
flutter analyze && flutter test
flutter run -d linux
```

CI (`.github/workflows/ci.yml`) runs all of this, plus the Windows, Ubuntu and
Android builds and a check of the server image, on every change.

## Personal data

Bank statements, personal mapping configurations and signing keys are never
committed. `scripts/check-personal-files.sh` fails if git tracks such a file;
CI runs it on every change.

## Licence

MIT, see `LICENSE`.
