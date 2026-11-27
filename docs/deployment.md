# Deployment

The server runs as one container on a machine of the home network (a NAS is
enough), never exposed to the Internet. The apps are installed from the files
attached to each GitHub release.

## Server

### Configuration

| Variable | Default (image) | Meaning |
|---|---|---|
| `BATZ_DATA_DIR` | `/data` | Database (paired devices and the reference copy of the journal), TLS certificate, original statement files (`statements/`), documents of the insurances (`documents/`) and dated copies of the database (`backups/`). Back this up. |
| `BATZ_PORT` | `8443` | HTTPS port. |
| `BATZ_BACKUPS` | `12` | Dated copies of the database kept in `backups/`, one written before each new statement file (1 to 1000). |

The image runs as uid 10001 without privileges, so the data directory on the
host must be writable by that uid. Its health check calls `/healthz` over
HTTPS, pinned on the certificate in `/data`. The image carries `pdftotext`,
which reads the statements without writing outside `/data`: the container
stays read-only.

### Install or upgrade

Each release carries `batz-web-<version>.tar.gz`, a `docker save` of the image
(the NAS does not pull from a registry).

```sh
# Synology: docker lives in /usr/local/bin, missing from the PATH of
# non-interactive SSH sessions.
export PATH="$PATH:/usr/local/bin"
gunzip -c batz-web-v0.11.0-alpha.tar.gz | docker load
mkdir -p /volume1/docker/batz/data
# Hand the data folder to uid 10001 (or: sudo chown 10001:10001 …).
docker run --rm --user 0 --entrypoint chown \
  -v /volume1/docker/batz/data:/data batz-web:v0.11.0-alpha 10001:10001 /data
docker rm -f batz-web 2>/dev/null
docker run -d --name batz-web --restart unless-stopped \
  -p 8443:8443 -v /volume1/docker/batz/data:/data \
  --read-only --cap-drop ALL --security-opt no-new-privileges:true \
  batz-web:v0.11.0-alpha
docker inspect -f '{{.State.Health.Status}}' batz-web   # healthy after a few seconds
curl -sk https://localhost:8443/healthz                  # version and minimum app version
```

`batz-web/docker-compose.example.yml` describes the same container.

Upgrading is the same commands with the new file: schema migrations are
embedded and run at start-up, and the data directory and its certificate are
kept. Deleting `tls/` makes every paired app refuse the server until it is
paired again. Each release says whether the server or the apps go first: the
server refuses apps older than its minimum version, which then show that they
are too old and keep their data until they are updated.

On Synology, shared folders carry ACLs that make new files readable by every
NAS account, `tls/server.key` included, whatever the permissions the server
sets. Keep the folder in a share that only administrators can open.

### Pair a device

```sh
docker exec batz-web batz-web pairing-code
```

It prints a code valid ten minutes and the certificate fingerprint. In the
app: « Plus › Serveur », enter the address (`<server>:8443`), the code and a
device name, then compare the fingerprint shown with the printed one.

### Losing the server

Every app holds a full copy of the journal, so the server can always be
rebuilt from them; a backup of the data directory only saves pairing every
device again.

1. Install the server again (empty data directory, or the last backup).
2. The apps say « Le serveur a changé » (new certificate, or a database that
   no longer knows them). On each: « Plus › Serveur », forget the server, pair
   again. The first exchange sends what the server lacks, modifications not
   sent yet included.

A server restored from an older backup with its certificate needs nothing:
the next exchanges of the apps send it what it lacks. Restoring a dated copy
of the database is described in
[architecture](architecture.md#copies-of-the-server-database).

## Apps

| Platform | Release file | Install |
|---|---|---|
| Android | `batz-<version>-android-arm64.apk` | Through Obtainium (below), or open the APK on the phone. Android 7 or later, arm64. |
| Ubuntu | `batz-<version>-linux-x64.tar.gz` | Extract anywhere and run `batz`. Needs `libgtk-3-0` and `libsecret-1-0`. `./install-desktop-entry.sh` adds batz, with its icon, to the applications of the desktop. |
| Windows | `batz-<version>-windows-x64.zip` | Extract anywhere and run `batz.exe`. |

### Android with Obtainium

[Obtainium](https://github.com/ImranR98/Obtainium) installs an app from its
GitHub releases and offers each new one; batz is on no store.

1. « Add app », source URL `https://github.com/alkariin/batz`.
2. Leave the options as they are: each release carries one APK, its tag is
   the version of the app, and releases are never marked as pre-releases.
3. « Install ». Android asks once to allow Obtainium to install apps.

An app installed by hand from a release APK can be added to Obtainium
afterwards: it is the same app, signed with the same key.

### Updating an app

A new version installs over the previous one and keeps the local database,
the pairing and the choices of the device.

- **Android**: Obtainium, or open the new APK. Android refuses an APK signed
  with another key or with a lower build number; the release workflow checks
  both. Uninstalling the app deletes its local data: pair the phone again and
  the first exchange brings everything back.
- **Ubuntu, Windows**: extract the new archive anywhere. The data are not in
  the folder of the app but in `~/.local/share/dev.batz.app/` on Ubuntu and
  `%APPDATA%\batz\batz\` on Windows. On Ubuntu, run
  `./install-desktop-entry.sh` again if the folder moved.

When a version raises the minimum app version of the server (0.11.0-alpha
does: it requires the app 0.11.0), update the server and every app. An app
older than the minimum refuses to synchronise and keeps its changes until it
is updated; then the next exchange sends them.

Every earlier version of the local database is opened by the tests
(`batz-ui/test/data/upgrade_test.dart`).

### Android signing key

Android only upgrades an app with an APK signed by the same key, so every
release is signed with one key, created once and kept safe: losing it means
uninstalling the app, and its local data, to install a new one.

```sh
keytool -genkeypair -keystore batz-release.jks -alias batz \
  -keyalg RSA -keysize 4096 -validity 36500 -dname "CN=batz"
# Its certificate fingerprint, for the ANDROID_CERT_SHA256 variable:
keytool -exportcert -keystore batz-release.jks -alias batz | sha256sum
```

| GitHub setting | Name | Value |
|---|---|---|
| Secret | `ANDROID_KEYSTORE_BASE64` | `base64 -w0 batz-release.jks` |
| Secret | `ANDROID_KEYSTORE_PASSWORD` | Keystore password (also the key password). |
| Secret | `ANDROID_KEY_ALIAS` | `batz` |
| Variable | `ANDROID_CERT_SHA256` | The fingerprint above, lower case, no colons. |

The release workflow refuses an APK signed with anything else. Local builds
without `batz-ui/android/key.properties` use the debug key and cannot upgrade
a released install.

## Releasing

1. Set `version:` in `batz-ui/pubspec.yaml` and `appVersion` in
   `batz-ui/lib/version.dart` (a test checks they agree), and raise the build
   number (`+N`) above the one of every published version.
2. Publish a GitHub release tagged `v<version name>`, suffix included
   (`0.11.0-alpha+12` → `v0.11.0-alpha`), as an ordinary release: Obtainium
   skips pre-releases. The release workflow checks the tag and the build
   number, then attaches the APK, the Ubuntu and Windows archives and the
   server image file.
3. Run the workflow by hand without a tag for a dry run: the files are kept
   as workflow artifacts for three days and no release is touched.
