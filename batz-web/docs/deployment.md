# Deployment

The server runs as one container on the home NAS (Synology, x86_64), reachable
on the home network only. The apps are installed from the files attached to
each GitHub release: by hand on the computers, by hand or through Obtainium
on the phone.

## Server

### Configuration

| Variable | Default (image) | Meaning |
|---|---|---|
| `BATZ_DATA_DIR` | `/data` | Database (paired devices and the reference copy of the journal), TLS certificate, original statement files (`statements/`) and dated copies of the database (`backups/`). Back this up. |
| `BATZ_PORT` | `8443` | HTTPS port. |
| `BATZ_BACKUPS` | `12` | Dated copies of the database kept in `backups/`, one written before each new statement file (1 to 1000). |

The image runs as uid 10001 without privileges; the data directory on the host
must be writable by that uid. Its health check calls `/healthz` over HTTPS,
pinned on the certificate in `/data`. The image carries `pdftotext`
(Alpine's `poppler-utils`), which reads the statements without writing
anything outside `/data`: the container stays read-only.

### Install or upgrade from a release file

Each release carries `batz-web-<version>.tar.gz`, a `docker save` of the image
(the NAS does not pull from a registry).

```sh
# On the NAS (Synology: docker lives in /usr/local/bin, which non-interactive
# SSH sessions do not have on PATH)
export PATH="$PATH:/usr/local/bin"
gunzip -c batz-web-v0.8.0-alpha.tar.gz | docker load
mkdir -p /volume1/docker/batz/data
sudo chown 10001:10001 /volume1/docker/batz/data
docker rm -f batz-web 2>/dev/null
docker run -d --name batz-web --restart unless-stopped \
  -p 8443:8443 -v /volume1/docker/batz/data:/data \
  --read-only --cap-drop ALL --security-opt no-new-privileges:true \
  batz-web:v0.8.0-alpha
docker inspect -f '{{.State.Health.Status}}' batz-web   # healthy after a few seconds
```

`docker-compose.example.yml` describes the same container. Schema migrations
are embedded and run at start-up; keep the data directory across upgrades.
The certificate is created on the first start and kept: deleting `tls/` makes
every paired app refuse the server until it is paired again.

### With the deployment script

From the development machine, with SSH key access to the NAS:

```sh
batz-web/scripts/deploy-nas.sh batz-web-v0.8.0-alpha.tar.gz user@192.168.1.95
```

It streams the image to `docker load`, gives the data folder to uid 10001
through a short-lived container (no `sudo` needed), recreates the container,
waits for Docker's health check, calls `/healthz` over HTTPS and prints the
certificate fingerprint. `BATZ_NAS_DIR` (default `/volume1/docker/batz`) and
`BATZ_PORT` (default `8443`) change the folder and port. Running it again
upgrades the server and keeps its data and certificate.

On Synology, shared folders carry ACLs that make new files readable by every
NAS account, `tls/server.key` included, whatever the permissions the server
sets. Keep the folder in a share that only administrators can open.

### Upgrading to 0.8.0-alpha (export, lock)

Server 0.8.0-alpha changes only its version: no route, no migration, no
folder. Nothing new enters the journal (the export and the lock of the
Android app belong to each device), so it still accepts apps 0.7.0, and apps
0.8.0-alpha work with a server 0.7.0: upgrade the server and the apps in any
order. Nothing needs to be paired again. The suffix does not count when
versions are compared: `0.8.0-alpha` is `0.8.0`.

After the upgrade, the Android app asks to unlock the phone when it opens
(fingerprint, face or the code of the device): see
[security](../../docs/security.md).

### Upgrading to 0.7.0 (modules)

Server 0.7.0 changes only its version: no route, no migration, no folder.
It requires apps 0.7.0 or later, the first that know what is entered in the
modules (salary sheets, fiscal years, trips, kWh, subscriptions): an app 0.6
would keep them in its journal without showing them, so it shows that it is
too old for the server. Apps 0.7.0 work with a server 0.6.0 meanwhile.
Upgrade the server, then the apps; nothing needs to be paired again. The
apps rebuild their local tables from their journal at the first start,
their data kept.

### Upgrading to 0.6.0 (wealth)

Server 0.6.0 changes only its version: no route, no migration, no folder.
It requires apps 0.6.0 or later, the first that know the declared balances
and the debts: an app 0.5 would keep them in its journal without showing
them, so it shows that it is too old for the server. Apps 0.6.0 work with a
server 0.5.0 meanwhile. Upgrade the server, then the apps; nothing needs to
be paired again. The apps rebuild their local tables from their journal at
the first start, their data kept.

### Upgrading to 0.5.0 (annual view)

Server 0.5.0 changes only its version: no route, no migration, no folder.
It requires apps 0.5.0 or later, the first that know the redistribution
rules, the refunds attached to an expense and the answers for the shares to
classify: an app 0.4 would keep them in its journal unapplied and show other
totals, so it shows that it is too old for the server. Apps 0.5.0 work with a
server 0.4.0 meanwhile. Upgrade the server, then the apps; nothing needs to
be paired again. The apps rebuild their local tables from their journal at
the first start, their data kept.

### Upgrading to 0.4.0 (import of statements)

Server 0.4.0 adds the import routes (`POST /api/v1/imports`,
`GET /api/v1/imports/{fingerprint}/pdf`), `pdftotext` in the image, and two
folders it creates in the data directory: `statements/` and `backups/`. The
database schema does not change. It requires apps 0.4.0 or later, the first
that know statements, imported lines and rules: an app 0.3.0 shows that it is
too old for the server. Upgrade the server first, then the apps; nothing needs
to be paired again. The apps rebuild their local tables from their journal at
the first start (a few seconds), their data kept.

An app 0.4.0 paired with a server 0.3.0 synchronises but refuses to import,
saying the server is too old. See [import.md](import.md) for the flow and
for restoring a copy of the database.

### Upgrading to 0.3.0 (synchronisation)

Server 0.3.0 adds the journal table (migration 2, applied at start-up, paired
devices kept) and the route `POST /api/v1/sync`. It requires apps 0.3.0 or
later: an older app shows that it is too old for the server. Upgrade the
server first, then the apps; nothing needs to be paired again.

The first exchange of each app sends its whole journal. When an app holds data
and the server already holds data from another device it never exchanged with
(devices used separately until then), the app asks whether to merge the two
or to replace its own data by the server's. Merging can leave duplicates
(two categories with the same name, two detailed accounts), listed as tasks on
the home screen.

### Losing the server

Every app holds a full copy of the journal, so the server can always be
rebuilt from them; a backup of the data directory only saves pairing every
device again.

1. Install the server again (empty data directory, or the last backup).
2. The apps say « Le serveur a changé » (new certificate, or a database that
   no longer knows them). On each: Plus › Serveur, forget the server, pair
   again. The first exchange sends what the server lacks, modifications not
   sent yet included.

A server restored from an older backup with its certificate needs nothing:
the apps' next exchanges send it what it lacks.

### Pair a device

```sh
docker exec batz-web batz-web pairing-code
```

It prints a code valid 10 minutes and the certificate fingerprint. In the
app: Plus → Serveur, enter the address (`192.168.1.95:8443`), the code and a
device name, then compare the fingerprint shown with the printed one.

## Apps

| Platform | Release file | Install |
|---|---|---|
| Android | `batz-<version>-android-arm64.apk` | Through Obtainium (below), or open the APK on the phone (allow installs from that source). Android 7 or later, arm64. |
| Ubuntu | `batz-<version>-linux-x64.tar.gz` | Extract anywhere and run `batz`. Needs `libgtk-3-0` and `libsecret-1-0`. `./install-desktop-entry.sh` adds batz, with its icon, to the applications of the desktop. |
| Windows | `batz-<version>-windows-x64.zip` | Extract anywhere and run `batz.exe`. |

### Android with Obtainium

[Obtainium](https://github.com/ImranR98/Obtainium) installs an app from its releases
and tells when a new one is published; batz is on no store.

1. In Obtainium: « Add app », source URL `https://github.com/alkariin/batz`.
2. Leave the options as they are. Each release carries one APK, and its tag
   is the version of the app (`v0.8.0-alpha` for the version name
   `0.8.0-alpha`), which is how Obtainium knows that the installed app is up
   to date. The releases are ordinary ones, not marked as pre-releases, so
   « Include prereleases » is not needed.
3. « Install ». Android asks once to allow Obtainium to install apps.

When a release is published, Obtainium offers the update; installing it
replaces the app and keeps its data. An app installed by hand from an APK of
a release can be added to Obtainium afterwards: it is the same app, signed
with the same key.

### Updating an app

A new version installs over the previous one: the local database, the
pairing with the server and the choices of the device are kept, on every
platform.

- **Android**: Obtainium, or open the new APK. Android refuses an APK
  signed with another key or with a lower build number; the release workflow
  checks both (`scripts/check-build-number.sh`, the certificate fingerprint).
- **Ubuntu, Windows**: extract the new archive over the old folder, or
  anywhere else: the data are not in the folder of the app. They are in
  `~/.local/share/dev.batz.app/` on Ubuntu and in `%APPDATA%\batz\batz\` on
  Windows. On Ubuntu, run `./install-desktop-entry.sh` again if the folder
  moved.
- An app older than the server asks for shows that it is too old and does
  not synchronise until it is updated; its data stay.
- Every earlier version of the local database is opened by the tests of each
  release (`batz-ui/test/data/upgrade_test.dart`).

Uninstalling the Android app deletes its local data: pair the phone again
afterwards, and the first exchange brings everything back from the server.

### Android signing key

Android only upgrades an app with an APK signed by the same key, so every
release is signed with one key, created once and kept safe (losing it means
uninstalling the app, and its local data, to install a new one).

```sh
keytool -genkeypair -keystore batz-release.jks -alias batz \
  -keyalg RSA -keysize 4096 -validity 36500 -dname "CN=batz"
# Its certificate fingerprint, for the ANDROID_CERT_SHA256 variable:
keytool -exportcert -keystore batz-release.jks -alias batz | sha256sum
```

GitHub repository settings:

| Kind | Name | Value |
|---|---|---|
| Secret | `ANDROID_KEYSTORE_BASE64` | `base64 -w0 batz-release.jks` |
| Secret | `ANDROID_KEYSTORE_PASSWORD` | Keystore password (also used as key password). |
| Secret | `ANDROID_KEY_ALIAS` | `batz` |
| Variable | `ANDROID_CERT_SHA256` | The fingerprint above, lower case, no colons. |

The release workflow refuses to publish an APK signed with anything else.
Local builds without `batz-ui/android/key.properties` are signed with the
debug key and cannot upgrade a released install.

## Releasing

1. Set `version:` in `batz-ui/pubspec.yaml` (and `appVersion` in
   `batz-ui/lib/version.dart`; a test checks they agree), and raise its
   build number (`+N`): `scripts/check-build-number.sh` fails when it is not
   greater than the one of every published version.
2. Publish a GitHub release tagged `v<version name>`, suffix included
   (`0.8.0-alpha+9` → `v0.8.0-alpha`), as an ordinary release: Obtainium
   skips pre-releases. The release workflow checks the tag
   (`scripts/check-release-tag.sh`) and the build number, then attaches the
   APK, the Ubuntu and Windows archives and the server image file.
3. Run it by hand without a tag for a dry run: the files are kept as workflow
   artifacts for three days and no release is touched.
