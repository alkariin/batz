#!/usr/bin/env bash
# Deploys a server image file to the NAS over SSH and checks it answers.
#
# Usage: batz-web/scripts/deploy-nas.sh <batz-web-<version>.tar.gz> <user@nas>
#
# The image file is a `docker save` (gzip), as attached to each GitHub release
# or built with `docker save batz-web:<version> | gzip`. The script streams it
# to `docker load` on the NAS, (re)creates the container with its data
# directory on the volume, waits for Docker's health check, then calls
# /healthz over HTTPS from this machine.
#
# Environment:
#   BATZ_NAS_DIR  folder on the NAS holding data/ (default /volume1/docker/batz)
#   BATZ_PORT     published HTTPS port (default 8443)
set -euo pipefail

if (($# != 2)); then
  sed -n '2,15p' "$0" | sed 's/^# \{0,1\}//' >&2
  exit 2
fi
image_file=$1
nas=$2
nas_dir=${BATZ_NAS_DIR:-/volume1/docker/batz}
port=${BATZ_PORT:-8443}
container=batz-web

[[ -f "$image_file" ]] || { echo "No such file: $image_file" >&2; exit 1; }

# On Synology the docker CLI lives in /usr/local/bin, which non-interactive
# SSH sessions do not have on PATH.
remote() { ssh -o BatchMode=yes "$nas" "export PATH=\"\$PATH:/usr/local/bin\"; $1"; }

echo "==> Loading $(basename "$image_file") on $nas"
load_output=$(gunzip -c "$image_file" | remote 'docker load')
echo "$load_output"
# "Loaded image: batz-web:v0.1.0": use the versioned tag, not :latest.
image=$(echo "$load_output" | sed -n 's/^Loaded image: \(batz-web:.*\)$/\1/p' | grep -v ':latest$' | head -1)
[[ -n "$image" ]] || image=$(echo "$load_output" | sed -n 's/^Loaded image: \(batz-web:.*\)$/\1/p' | head -1)
[[ -n "$image" ]] || { echo "The file holds no batz-web image" >&2; exit 1; }

echo "==> Starting $image (data in $nas_dir/data, port $port)"
remote "set -e
mkdir -p '$nas_dir/data'
# The image runs as uid 10001; hand it the data folder without sudo.
docker run --rm --user 0 --entrypoint chown -v '$nas_dir/data:/data' '$image' 10001:10001 /data
docker rm -f $container >/dev/null 2>&1 || true
docker run -d --name $container --restart unless-stopped \
  -p $port:8443 -v '$nas_dir/data:/data' \
  --read-only --cap-drop ALL --security-opt no-new-privileges:true \
  '$image' >/dev/null"

echo "==> Waiting for the health check"
status=starting
for _ in $(seq 1 30); do
  status=$(remote "docker inspect -f '{{.State.Health.Status}}' $container")
  [[ "$status" == healthy ]] && break
  sleep 2
done
if [[ "$status" != healthy ]]; then
  echo "Container is $status; its logs:" >&2
  remote "docker logs --tail 50 $container" >&2
  exit 1
fi

host=${nas#*@}
echo "==> GET https://$host:$port/healthz"
# -k: the certificate is self-signed; apps pin its fingerprint instead.
curl -sSk --max-time 5 "https://$host:$port/healthz"
echo
remote "docker logs $container 2>&1 | sed -n 's/.*certificateFingerprint=//p' | tail -1" |
  sed 's/^/Certificate fingerprint: /'
echo "Pair a device with: ssh $nas 'export PATH=\$PATH:/usr/local/bin; docker exec $container batz-web pairing-code'"
