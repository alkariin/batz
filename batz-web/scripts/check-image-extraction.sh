#!/usr/bin/env bash
# Extracts every fictitious statement of the test set inside a server image
# and compares the output with the expected JSON.
#
# Usage: batz-web/scripts/check-image-extraction.sh <image>
set -euo pipefail

image="${1:?usage: $0 <image>}"
testdata="$(cd "$(dirname "$0")/../src/internal/infrastructure/extraction/postfinance/testdata" && pwd)"

failed=0
for pdf in "$testdata"/*.pdf; do
  name=$(basename "$pdf" .pdf)
  set +e
  out=$(docker run --rm --read-only --cap-drop ALL --network none \
    -v "$testdata:/testdata:ro" --entrypoint batz-web "$image" extract "/testdata/$name.pdf" 2>/dev/null)
  status=$?
  set -e
  if ((status != 0 && status != 2)); then
    echo "$name: extraction failed (exit code $status)"
    failed=1
  elif [[ "$out" == "$(cat "$testdata/$name.json")" ]]; then
    echo "$name: as expected ($(grep -o '"accepted": [a-z]*' <<<"$out"))"
  else
    echo "$name: differs from $name.json"
    failed=1
  fi
done
exit "$failed"
