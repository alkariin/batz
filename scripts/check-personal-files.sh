#!/usr/bin/env bash
# Fails if git tracks a file that may hold personal data or a secret.
#
# Usage: scripts/check-personal-files.sh [repo-dir]
#
# Bank statements and their exports, personal mapping configs, signing keys
# and env files must never be committed. Fictitious statements used by tests
# are allowed under a `testdata/` or `fixtures/` directory.
set -euo pipefail

repo="${1:-.}"

forbidden='(^|/)priv[eé]? - |(^|/)prive - |(^|/)config-[0-9]{4}\.yaml|(^|/)specification\.txt$|\.(jks|keystore|p12|pfx|pem|key)$|(^|/)key\.properties$|(^|/)\.env(\..*)?$'
# Statements and their exports outside test fixtures.
data_files='\.(pdf|csv)$'
fixtures='(^|/)(testdata|fixtures)/'

offending=()
while IFS= read -r -d '' path; do
  if [[ "$path" =~ \.env\.example$ ]]; then
    continue
  fi
  if printf '%s' "$path" | grep -Eiq "$forbidden"; then
    offending+=("$path")
  elif printf '%s' "$path" | grep -Eiq "$data_files" && ! printf '%s' "$path" | grep -Eq "$fixtures"; then
    offending+=("$path")
  fi
done < <(git -C "$repo" ls-files -z)

if ((${#offending[@]} > 0)); then
  echo "Personal or secret files are tracked by git:" >&2
  printf '  %s\n' "${offending[@]}" >&2
  exit 1
fi

echo "No personal or secret file is tracked ($(git -C "$repo" ls-files | wc -l) files checked)."
