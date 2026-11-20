# Deployment

The server runs as one container on the home NAS (Synology, x86_64), reachable
on the home network only. The apps are installed by hand from the files
attached to each GitHub release.

## Server

### Configuration

| Variable | Default (image) | Meaning |
|---|---|---|
| `BATZ_DATA_DIR` | `/data` | Database and TLS certificate. Back this up. |
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
gunzip -c batz-web-v0.1.0.tar.gz | docker load
mkdir -p /volume1/docker/batz/data
sudo chown 10001:10001 /volume1/docker/batz/data
docker rm -f batz-web 2>/dev/null
docker run -d --name batz-web --restart unless-stopped \
  -p 8443:8443 -v /volume1/docker/batz/data:/data \
  --read-only --cap-drop ALL --security-opt no-new-privileges:true \
  batz-web:v0.1.0
docker inspect -f '{{.State.Health.Status}}' batz-web   # healthy after a few seconds
```

`docker-compose.example.yml` describes the same container. Schema migrations
are embedded and run at start-up; keep the data directory across upgrades.
The certificate is created on the first start and kept: deleting `tls/` makes
every paired app refuse the server until it is paired again.

`scripts/deploy-nas.sh` (phase 0, step 0.8) will automate the copy, load,
restart and `/healthz` check over SSH.

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
