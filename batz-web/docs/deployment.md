# Deployment

The server runs as one container on the home NAS (Synology, x86_64), reachable
on the home network only. The apps are installed by hand from the files
attached to each GitHub release.

## Server

### Configuration

| Variable | Default (image) | Meaning |
|---|---|---|
| `BATZ_DATA_DIR` | `/data` | Database (paired devices and the reference copy of the journal) and TLS certificate. Back this up. |
| `BATZ_PORT` | `8443` | HTTPS port. |

The image runs as uid 10001 without privileges; the data directory on the host
must be writable by that uid. Its health check calls `/healthz` over HTTPS,
pinned on the certificate in `/data`.

### Install or upgrade from a release file

Each release carries `batz-web-<version>.tar.gz`, a `docker save` of the image
(the NAS does not pull from a registry).

```sh
# On the NAS (Synology: docker lives in /usr/local/bin, which non-interactive
# SSH sessions do not have on PATH)
export PATH="$PATH:/usr/local/bin"
gunzip -c batz-web-v0.3.0.tar.gz | docker load
mkdir -p /volume1/docker/batz/data
sudo chown 10001:10001 /volume1/docker/batz/data
docker rm -f batz-web 2>/dev/null
docker run -d --name batz-web --restart unless-stopped \
  -p 8443:8443 -v /volume1/docker/batz/data:/data \
  --read-only --cap-drop ALL --security-opt no-new-privileges:true \
  batz-web:v0.3.0
docker inspect -f '{{.State.Health.Status}}' batz-web   # healthy after a few seconds
```

`docker-compose.example.yml` describes the same container. Schema migrations
are embedded and run at start-up; keep the data directory across upgrades.
The certificate is created on the first start and kept: deleting `tls/` makes
every paired app refuse the server until it is paired again.

### With the deployment script

From the development machine, with SSH key access to the NAS:

```sh
batz-web/scripts/deploy-nas.sh batz-web-v0.3.0.tar.gz user@192.168.1.95
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
| Android | `batz-<version>-android-arm64.apk` | Open the APK on the phone (allow installs from that source). |
| Ubuntu | `batz-<version>-linux-x64.tar.gz` | Extract anywhere and run `batz`. Needs `libgtk-3-0` and `libsecret-1-0`. |
| Windows | `batz-<version>-windows-x64.zip` | Extract anywhere and run `batz.exe`. |

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
   `batz-ui/lib/version.dart`; a test checks they agree).
2. Publish a GitHub release tagged `v<version>`. The release workflow checks
   the tag against the pubspec, then attaches the APK, the Ubuntu and Windows
   archives and the server image file.
3. Run it by hand without a tag for a dry run: the files are kept as workflow
   artifacts for three days and no release is touched.
