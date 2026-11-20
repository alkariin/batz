#!/usr/bin/env python3
"""Extract PostFinance statements to CSV.

Usage: python3 extract_v1.1.py

For every "privé - MM YYYY.pdf" next to this script, writes
"privé - MM YYYY.csv" (columns: date;montant;texte), unless the CSV already
exists. The parsing is checked against every balance and the totals printed
by PostFinance: on any mismatch, no CSV is written.
"""

from __future__ import annotations

import csv
import re
import shutil
import subprocess
import sys
import unicodedata
from dataclasses import dataclass, field
from datetime import date, datetime
from decimal import Decimal
from pathlib import Path

__version__ = "1.1"

HERE = Path(__file__).resolve().parent

FILE_RE = re.compile(r"^priv[eé] - \d{2} \d{4}\.pdf$", re.IGNORECASE)
AMOUNT = r"-?\d{1,3}(?:[   ']\d{3})*\.\d{2}"
DATE = r"\d{2}\.\d{2}\.\d{2}"
HEADER_RE = re.compile(r"^\s*Date\s+Texte\s+Crédit\s+Débit\s+Valeur")
TXN_RE = re.compile(
    rf"^\s*(?:(?P<date>{DATE})\s+)?(?P<text>\S.*?)\s{{2,}}(?P<amount>{AMOUNT})"
    rf"\s+(?P<valeur>{DATE})(?:\s+(?P<balance>{AMOUNT}))?\s*$"
)
# pdftotext sometimes puts the amount on its own line (e.g. after a page footer)
AMOUNT_ONLY_RE = re.compile(
    rf"^\s*(?P<amount>{AMOUNT})\s+(?P<valeur>{DATE})(?:\s+(?P<balance>{AMOUNT}))?\s*$"
)
DATED_TEXT_RE = re.compile(rf"^(?P<date>{DATE})\s+(?P<text>\S.*)$")
BALANCE_RE = re.compile(rf"^(?:{DATE}\s+)?Etat de compte\s+({AMOUNT})$")
TOTAL_RE = re.compile(rf"^Total\s+{AMOUNT}")
SKIP_RE = re.compile(
    r"^(Extrait de compte \d{2}\.\d{2}\.\d{4} - |IBAN CH[\d ]+|Numéro de compte |\d{5} FR \d+\.\d{2}$)"
)


class ParseError(Exception):
    pass


@dataclass
class Transaction:
    day: date
    amount: Decimal  # signed: credit > 0, debit < 0
    lines: list[str] = field(default_factory=list)


def parse_amount(raw: str) -> Decimal:
    return Decimal(re.sub(r"[   ']", "", raw))


def parse_statement(path: Path) -> list[Transaction]:
    result = subprocess.run(
        ["pdftotext", "-layout", "-enc", "UTF-8", str(path), "-"],
        capture_output=True, text=True, encoding="utf-8",  # Windows defaults to cp1252
    )
    if result.returncode != 0:
        raise ParseError(f"pdftotext a échoué : {result.stderr.strip()}")

    credit_col = debit_col = None
    opening = closing = running = None
    totals: dict[str, Decimal] | None = None
    current_day = None
    txns: list[Transaction] = []
    current: Transaction | None = None

    for raw in result.stdout.splitlines():
        line = raw.rstrip()
        stripped = line.strip()
        if not stripped:
            continue
        if HEADER_RE.match(line):
            credit_col = line.index("Crédit") + len("Crédit")
            debit_col = line.index("Débit") + len("Débit")
            continue
        if credit_col is None:
            continue  # address block before the first table

        if m := BALANCE_RE.match(stripped):
            if opening is None:
                opening = running = parse_amount(m[1])
            else:
                closing = parse_amount(m[1])
            current = None
            continue
        if TOTAL_RE.match(stripped):
            totals = {}
            for am in re.finditer(AMOUNT, line):
                is_credit = abs(am.end() - credit_col) < abs(am.end() - debit_col)
                totals["credit" if is_credit else "debit"] = parse_amount(am[0])
            current = None
            continue
        if totals is not None or SKIP_RE.match(stripped):
            continue

        if m := TXN_RE.match(line):
            day, text = m["date"], m["text"].strip()
        elif m := AMOUNT_ONLY_RE.match(line):
            # detached amount: its text is the last line read, wrongly appended
            # to the previous transaction
            if current is None or len(current.lines) < 2:
                raise ParseError(f"montant sans libellé : {stripped}")
            head = current.lines.pop()
            d = DATED_TEXT_RE.match(head)
            day, text = (d["date"], d["text"]) if d else (None, head)

        if m:
            if day:
                current_day = datetime.strptime(day, "%d.%m.%y").date()
            if current_day is None or running is None:
                raise ParseError(f"transaction sans date ou solde initial : {stripped}")
            amount = parse_amount(m["amount"])
            end = m.end("amount")
            if abs(end - debit_col) <= abs(end - credit_col):
                amount = -amount
            current = Transaction(current_day, amount, [text])
            txns.append(current)
            running += amount
            if m["balance"] and running != parse_amount(m["balance"]):
                raise ParseError(
                    f"solde calculé {running} ≠ solde imprimé {m['balance']} à la ligne : {stripped}"
                )
            continue

        if current is not None:
            current.lines.append(stripped)

    if opening is None or closing is None or totals is None:
        raise ParseError("solde initial, solde final ou ligne « Total » introuvable")
    credits = sum((t.amount for t in txns if t.amount > 0), Decimal(0))
    debits = -sum((t.amount for t in txns if t.amount < 0), Decimal(0))
    if credits != totals.get("credit", Decimal(0)) or debits != totals.get("debit", Decimal(0)):
        raise ParseError(f"totaux lus (crédit {credits}, débit {debits}) ≠ totaux imprimés")
    if opening + credits - debits != closing:
        raise ParseError(f"solde final attendu {opening + credits - debits}, imprimé {closing}")
    return txns


def main() -> None:
    if not shutil.which("pdftotext"):
        sys.exit("Erreur : pdftotext est introuvable (paquet poppler-utils)")

    pdfs = sorted(p for p in HERE.iterdir() if FILE_RE.match(unicodedata.normalize("NFC", p.name)))
    if not pdfs:
        sys.exit(f"Aucun fichier « privé - MM AAAA.pdf » trouvé dans {HERE}")

    errors = 0
    for pdf in pdfs:
        out = pdf.with_suffix(".csv")
        if out.exists():
            print(f"déjà extrait  {out.name}")
            continue
        try:
            txns = parse_statement(pdf)
        except ParseError as e:
            print(f"ERREUR        {pdf.name} : {e}", file=sys.stderr)
            errors += 1
            continue
        with out.open("w", newline="", encoding="utf-8-sig") as f:
            w = csv.writer(f, delimiter=";")
            w.writerow(["date", "montant", "texte"])
            for t in txns:
                w.writerow([t.day.strftime("%d.%m.%Y"), t.amount, " ".join(t.lines)])
        print(f"extrait       {out.name} ({len(txns)} transactions, soldes vérifiés)")
    sys.exit(1 if errors else 0)


if __name__ == "__main__":
    main()
