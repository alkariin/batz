#!/usr/bin/env bash
# Extracts every real statement at the root of the repository (« privé - MM
# YYYY.pdf », never committed) with the server's extraction, and prints, per
# file, only the verdict and the number of lines. When the CSV written by the
# original script for that statement is there, the dates and amounts of both
# are compared; only the outcome is printed, never a line of the statement.
#
# Usage: scripts/check-real-statements.sh [repo-dir]
#
# BATZ_WEB_BIN may name a batz-web binary; otherwise one is built from
# batz-web/src (Go must be on PATH). pdftotext must be on PATH.
set -euo pipefail

repo="$(cd "${1:-.}" && pwd)"
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT

bin="${BATZ_WEB_BIN:-}"
if [[ -z "$bin" ]]; then
  bin="$work/batz-web"
  (cd "$repo/batz-web/src" && go build -o "$bin" .)
fi

mapfile -d '' statements < <(find "$repo" -maxdepth 1 -type f \( -iname 'priv* - *.pdf' -o -iname 'prive - *.pdf' \) -print0 | sort -z)
if ((${#statements[@]} == 0)); then
  echo "No real statement at the root of the repository."
  exit 0
fi

# date;montant;texte (dd.mm.yyyy;-12.50;...) to YYYY-MM-DD<TAB>cents.
csv_amounts() {
  sed '1s/^\xEF\xBB\xBF//' "$1" | tr -d '\r' | awk -F';' 'NR > 1 && NF >= 2 {
    split($1, d, ".")
    amount = $2; sign = 1
    if (substr(amount, 1, 1) == "-") { sign = -1; amount = substr(amount, 2) }
    n = split(amount, p, ".")
    frac = (n > 1) ? substr(p[2] "00", 1, 2) : "00"
    printf "%s-%s-%s\t%d\n", d[3], d[2], d[1], sign * (p[1] * 100 + frac)
  }'
}

failed=0
for pdf in "${statements[@]}"; do
  name=$(basename "$pdf")
  set +e
  verdict=$("$bin" extract -summary "$pdf" 2>/dev/null)
  status=$?
  set -e
  if ((status == 1)); then
    echo "$name: extraction failed"
    failed=1
    continue
  fi
  line="$name: $verdict"
  if ((status != 0)); then
    failed=1
  else
    csv="${pdf%.*}.csv"
    if [[ -f "$csv" ]]; then
      "$bin" extract -amounts "$pdf" >"$work/extracted"
      csv_amounts "$csv" >"$work/original"
      lines=$(wc -l <"$work/original")
      if cmp -s "$work/extracted" "$work/original"; then
        line+="; dates and amounts identical to the original script ($lines lines)"
      elif [[ $(wc -l <"$work/extracted") -ne $lines ]]; then
        line+="; $(wc -l <"$work/extracted") lines extracted, $lines in the CSV of the original script"
        failed=1
      else
        # Each differing line, and which of its date or amount differs,
        # never the values.
        report=$(paste "$work/extracted" "$work/original" | awk -F'\t' '
          $1 != $3 || $2 != $4 {
            what = ($1 != $3 && $2 != $4) ? "date and amount" : ($1 != $3 ? "date" : "amount")
            out = out (out ? ", " : "") "line " NR " (" what ")"
          }
          END { print out }')
        line+="; differs from the original script: $report"
        failed=1
      fi
    else
      line+="; no CSV of the original script"
    fi
  fi
  echo "$line"
done
exit "$failed"
