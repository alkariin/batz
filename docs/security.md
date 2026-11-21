# Security

What protects the data of batz, and what does not. The reference is
`docs/specification.md` (chapter 9, in French); the details of each
mechanism are in `batz-web/docs/architecture.md`, `batz-web/docs/api.md` and
`docs/decisions.md`.

batz is made for one person, on their own devices and a server on their home
network. It has no login and no account: a device is trusted because it was
paired once, by someone who could read a code on the server.

## What protects what

| Threat | Protection |
|---|---|
| Someone on the home network listens to the exchanges | HTTPS only. The server creates its own certificate (ECDSA P-256, valid 10 years); the app records its SHA-256 fingerprint when it is paired and refuses any other certificate afterwards. |
| Someone on the home network talks to the server | Every route but `/healthz` and the pairing asks for the key of a paired device. A device is paired with a one-time code, valid 10 minutes, that only someone with access to the server can obtain; the server keeps the hash of each key, never the key. |
| A device is lost or sold | It is revoked from any other device (« Plus › Serveur »): its key is refused from then on. Its local copy of the data stays on it: see the next lines. |
| Someone picks up the unlocked phone | The Android app opens behind the lock of the phone: fingerprint, face, or its PIN, pattern or password. It locks again when it comes back after more than a minute away. While locked, none of its screens is drawn. |
| Someone looks at the list of recent apps of the phone | From Android 13 on, the list shows no picture of the last screen of batz. |
| Someone copies the files of the phone | The local database of the Android app is encrypted (SQLCipher) with a random key kept by the Android Keystore; the app refuses to start rather than store data unencrypted. The app is excluded from Android backups. |
| The server is reachable from the Internet | It is not meant to be: nothing in batz opens a port or contacts a third party. The app reaches the server by its address on the home network. |
| The server process is compromised | The container runs as an unprivileged user, read-only, without capabilities; it writes only in its data folder. Its only external tool is `pdftotext`, run on the statements it is sent. |
| A statement carries a text made to run as a formula in a spreadsheet | In an export, a text that starts with `=`, `+`, `-` or `@` is preceded by an apostrophe. |
| Personal data or secrets reach the public repository | Nothing personal is committed: `scripts/check-personal-files.sh` refuses statements, personal configurations, keys and exports, and, with a local list of terms, any tracked file or commit message that holds one. CI runs it on every change. The Android signing key lives in the secrets of GitHub. |

## What is not protected

- **Computers.** On Windows and Ubuntu the app has no lock and its database
  is not encrypted: they rely on the session and the disk encryption of the
  operating system. The key of the device is kept by the system (DPAPI on
  Windows, the Secret Service on Ubuntu).
- **The export.** `batz-export-*.zip` holds everything, unencrypted, wherever
  it is saved. The screen says so before exporting.
- **The server's data folder.** The journal, its dated copies (the twelve
  latest are kept) and the original PDF statements are plain files on the
  NAS: whoever reads the volume reads them.
- **A phone unlocked and in hostile hands for long.** The lock of the app
  is a door in front of its screens. The key of the database is not bound
  to the unlocking: a rooted or compromised system could read the data
  while the phone is on.
- **A phone without screen lock.** There is nothing to ask: the app opens,
  and its home screen says so until a screen lock is set.
- **Android 12 and earlier.** The picture of the last screen stays in the
  list of recent apps. Screenshots are possible on every version.
- **The clock of the devices.** The latest modification of a field wins;
  a device with a wrong clock can win when it should not
  (`batz-web/docs/sync.md`).
- **Losing everything at home.** No copy leaves the home network. Each
  device holds the whole journal and can rebuild the server; the original
  PDF files exist only on the server.

## The lock of the Android app, in short

- At opening, and when the app comes back after more than 60 seconds away
  (or when the clock of the phone went back meanwhile). Choosing a PDF or
  saving an export within a minute does not lock.
- Through the dialog of Android. A cancelled or refused dialog leaves the
  app locked, with a button to try again; an unexpected error is shown.
- The screen in progress and what was being typed are found again after
  unlocking. The synchronisation goes on behind the lock.
- Always on: there is no setting to turn it off.

Rules and tests: `docs/decisions.md` (7.0 and 7.3),
`batz-ui/lib/pages/lock/`, `batz-ui/test/pages/lock/`.
