#!/usr/bin/env bash
# Fails if git tracks a file that may hold personal data or a secret, or if a
# personal term appears in a tracked file or a commit message.
#
# Usage: scripts/check-personal-files.sh [repo-dir]
#
# 1. File names: bank statements and their exports, personal mapping configs,
#    signing keys and env files must never be committed. Fictitious
#    statements used by tests are allowed under a `testdata/` or `fixtures/`
#    directory.
# 2. Contents: when `personal/terms.txt` exists (never tracked: one term per
#    line, `#` for comments), no tracked file, text of PDF files included, and
#    no commit message may contain one of its terms, compared without case.
#    Without that list, as in CI, this check is skipped and says so. Matches
#    name the file and the number of the term, never the term itself.
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

count=$(git -C "$repo" ls-files | wc -l)
echo "No personal or secret file is tracked ($count files checked)."

terms_file="$repo/personal/terms.txt"
if [[ ! -f "$terms_file" ]]; then
  echo "Personal terms check skipped: personal/terms.txt is absent."
  exit 0
fi

# The terms, numbered by their line in the file.
numbers=()
terms=()
n=0
while IFS= read -r line || [[ -n "$line" ]]; do
  n=$((n + 1))
  term="${line#"${line%%[![:space:]]*}"}"
  term="${term%"${term##*[![:space:]]}"}"
  [[ -z "$term" || "$term" == \#* ]] && continue
  numbers+=("$n")
  terms+=("$term")
done <"$terms_file"
if ((${#terms[@]} == 0)); then
  echo "Personal terms check skipped: personal/terms.txt holds no term."
  exit 0
fi

if ! command -v pdftotext >/dev/null; then
  echo "pdftotext is required to check the text of tracked PDF files." >&2
  exit 1
fi

# Every tracked file as text: PDFs through pdftotext, the others as they are,
# binary files included (SQLite fixtures hold their text in clear).
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
files=()
while IFS= read -r -d '' path; do
  [[ -f "$repo/$path" ]] || continue
  files+=("$path")
done < <(git -C "$repo" ls-files -z)
pdf_texts=()
for path in "${files[@]}"; do
  if [[ "$path" =~ \.[pP][dD][fF]$ ]]; then
    out="$work/pdf-${#pdf_texts[@]}.txt"
    pdftotext -enc UTF-8 "$repo/$path" "$out" 2>/dev/null || : >"$out"
    pdf_texts+=("$path"$'\t'"$out")
  fi
done
git -C "$repo" log --all --format=%B >"$work/commit-messages.txt"

found=0
for i in "${!terms[@]}"; do
  term="${terms[$i]}"
  hits=()
  while IFS= read -r path; do
    [[ -n "$path" ]] && hits+=("$path")
  done < <(cd "$repo" && printf '%s\0' "${files[@]}" | xargs -0 grep -Flia -e "$term" -- 2>/dev/null || true)
  for entry in "${pdf_texts[@]}"; do
    if grep -Fqi -e "$term" -- "${entry#*$'\t'}"; then
      hits+=("${entry%%$'\t'*} (text of the PDF)")
    fi
  done
  if grep -Fqi -e "$term" -- "$work/commit-messages.txt"; then
    hits+=("a commit message")
  fi
  if ((${#hits[@]} > 0)); then
    found=1
    echo "Term on line ${numbers[$i]} of personal/terms.txt found in:" >&2
    printf '  %s\n' "${hits[@]}" >&2
  fi
done
if ((found)); then
  exit 1
fi
echo "No personal term in tracked files or commit messages (${#terms[@]} terms, ${#files[@]} files, ${#pdf_texts[@]} PDF texts, $(git -C "$repo" rev-list --all | wc -l) commits)."
