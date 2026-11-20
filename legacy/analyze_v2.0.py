#!/usr/bin/env python3
"""Categorise the extracted CSV statements into Markdown reports.

Usage: python3 analyze_v2.0.py

For every "privé - MM YYYY.csv" next to this script (see extract_v1.0.py),
applies the category tree from config-YYYY.yaml (same year) and writes
"privé - MM YYYY.md" with the categorised, uncategorised and ignored
transactions, plus a summary of the "synthese" subtree (default: Dépenses).
Existing .md files are overwritten.
"""

from __future__ import annotations

import csv
import re
import sys
import unicodedata
from collections import defaultdict
from dataclasses import dataclass
from decimal import Decimal
from pathlib import Path

import yaml

__version__ = "2.0"

HERE = Path(__file__).resolve().parent
FILE_RE = re.compile(r"^priv[eé] - \d{2} (\d{4})\.csv$", re.IGNORECASE)
IGNORE = "Ignorer"


@dataclass
class Transaction:
    day: str
    amount: Decimal
    text: str
    category: str | None = None


@dataclass
class Config:
    order: list[tuple[str, int]]  # every group/category with its depth, file order
    children: dict[str, list[str]]  # group -> direct children (empty for categories)
    rules: list[tuple[str, str]]  # (category, pattern), in file order
    summary_root: str  # node whose subtree is shown in the summary


def fail(message: str) -> None:
    sys.exit(f"Erreur : {message}")


def strip_accents(text: str) -> str:
    text = unicodedata.normalize("NFKD", text)
    return "".join(c for c in text if not unicodedata.combining(c))


def normalise(text: str) -> str:
    """Uppercase, strip accents and collapse whitespace (for rule matching)."""
    return re.sub(r"\s+", " ", strip_accents(text)).upper().strip()


def fmt(value: Decimal) -> str:
    return "-" if value == 0 else f"{value:,.2f}".replace(",", "'")


def cell(text: str) -> str:
    return text.replace("|", "\\|")


def nowrap(text: str) -> str:
    """Keep a table cell on one line, so that "Texte" takes the remaining width."""
    return f'<span style="white-space:nowrap">{cell(text)}</span>'


# --------------------------------------------------------------------------- #
# Configuration and categorisation
# --------------------------------------------------------------------------- #

def load_config(path: Path) -> Config:
    """Parse the "categories" tree: a mapping value is a group of
    sub-categories, a list (or nothing) is a category with its patterns."""
    def err(message: str) -> None:
        fail(f"{path.name} : {message}")

    try:
        raw = yaml.safe_load(path.read_text(encoding="utf-8")) or {}
    except yaml.YAMLError as e:
        err(f"YAML invalide :\n{e}")
    if not isinstance(raw.get("categories"), dict):
        err("section « categories » absente (ancien format ? voir convert_config_v2.0.py)")

    order: list[tuple[str, int]] = []
    children: dict[str, list[str]] = {}
    rules: list[tuple[str, str]] = []

    def walk(tree: dict, depth: int) -> None:
        for name, value in tree.items():
            name = str(name)
            if name in children:
                err(f"catégorie « {name} » définie deux fois")
            order.append((name, depth))
            if isinstance(value, dict):
                children[name] = [str(c) for c in value]
                walk(value, depth + 1)
                continue
            children[name] = []
            if value is not None and not isinstance(value, list):
                err(f"« {name} » : attendu une liste de mots-clés ou des sous-catégories")
            for p in value or []:
                if isinstance(p, bool) or not isinstance(p, (str, int, float)):
                    err(f"« {name} » : motif invalide « {p} » (mets-le entre guillemets)")
                rules.append((name, str(p)))

    walk(raw["categories"], 0)
    summary_root = str(raw.get("synthese") or "Dépenses")
    if summary_root not in children:
        err(f"synthese : catégorie inconnue « {summary_root} »")
    return Config(order, children, rules, summary_root)


def matches(pattern: str, text: str) -> bool:
    """Every "&"-separated part must match (substring, or regex if "re:")."""
    for part in (p.strip() for p in pattern.split("&")):
        if part.startswith("re:"):
            if not re.search(strip_accents(part[3:]), text, re.IGNORECASE):
                return False
        elif normalise(part) not in text:
            return False
    return True


def categorise(txns: list[Transaction], config: Config) -> None:
    for t in txns:
        text = normalise(t.text)
        t.category = next((c for c, p in config.rules if matches(p, text)), None)


# --------------------------------------------------------------------------- #
# Summary
# --------------------------------------------------------------------------- #

def node_values(txns: list[Transaction], config: Config) -> dict[str, Decimal]:
    """Expenses as positive amounts (refunds reduce them); groups = sum of children."""
    own: dict[str, Decimal] = defaultdict(Decimal)
    for t in txns:
        if t.category:
            own[t.category] -= t.amount

    def value(node: str) -> Decimal:
        kids = config.children[node]
        return sum((value(c) for c in kids), Decimal(0)) if kids else own[node]

    return {n: value(n) for n, _ in config.order}


def subtree(config: Config, root: str) -> list[tuple[str, int]]:
    """root and its descendants, with depth relative to root."""
    start = next(i for i, (n, _) in enumerate(config.order) if n == root)
    base = config.order[start][1]
    out = [(root, 0)]
    for name, depth in config.order[start + 1:]:
        if depth <= base:
            break
        out.append((name, depth - base))
    return out


# --------------------------------------------------------------------------- #
# Markdown
# --------------------------------------------------------------------------- #

def totals_line(txns: list[Transaction]) -> str:
    credits = sum((t.amount for t in txns if t.amount > 0), Decimal(0))
    debits = -sum((t.amount for t in txns if t.amount < 0), Decimal(0))
    return f"{len(txns)} transactions — crédits {fmt(credits)}, débits {fmt(debits)}"


def table(txns: list[Transaction], with_category: bool) -> list[str]:
    if not txns:
        return ["_Aucune._"]
    head = ["Catégorie"] if with_category else []
    rows = [
        "| " + " | ".join(head + ["Date", "Montant", "Texte"]) + " |",
        "|" + "---|" * len(head) + "---|---:|---|",
    ]
    for t in txns:
        cols = [nowrap(t.category)] if with_category else []
        cols += [nowrap(t.day), nowrap(fmt(t.amount)), cell(t.text)]
        rows.append("| " + " | ".join(cols) + " |")
    return rows


def render(title: str, txns: list[Transaction], config: Config) -> str:
    rank = {c: i for i, (c, _) in enumerate(config.order)}
    done = sorted(
        (t for t in txns if t.category and t.category != IGNORE),
        key=lambda t: rank[t.category],  # stable: keeps date order within a category
    )
    todo = [t for t in txns if t.category is None]
    ignored = [t for t in txns if t.category == IGNORE]

    values = node_values(txns, config)
    summary = ["| Catégorie | Montant |", "|---|---:|"]
    for node, depth in subtree(config, config.summary_root):
        name = f"**{node}**" if config.children[node] else node
        summary.append(f"| {'&emsp;' * depth}{name} | {fmt(values[node])} |")

    out = [f"# {title}", ""]
    out += ["## Traitées", "", totals_line(done), "", *table(done, True), ""]
    out += ["## Non traitées", "", totals_line(todo), "", *table(todo, False), ""]
    out += ["## Ignorées", "", totals_line(ignored), "", *table(ignored, False), ""]
    out += ["## Synthèse", "", *summary, ""]
    return "\n".join(out)


def read_csv(path: Path) -> list[Transaction]:
    with path.open(newline="", encoding="utf-8-sig") as f:
        return [
            Transaction(row["date"], Decimal(row["montant"]), row["texte"])
            for row in csv.DictReader(f, delimiter=";")
        ]


def config_path(year: int) -> Path:
    return HERE / f"config-{year}.yaml"


def main() -> None:
    files: dict[int, list[Path]] = defaultdict(list)
    for p in sorted(HERE.iterdir()):
        if m := FILE_RE.match(unicodedata.normalize("NFC", p.name)):
            files[int(m[1])].append(p)
    if not files:
        fail(f"aucun fichier « privé - MM AAAA.csv » dans {HERE} (lancer d'abord extract_v1.0.py)")

    missing = [y for y in sorted(files) if not config_path(y).exists()]
    for year in missing:
        previous = config_path(year - 1).name
        print(
            f"ATTENTION : {config_path(year).name} introuvable, {len(files[year])} fichier(s) "
            f"de {year} non analysé(s). Copie par exemple {previous} et adapte-le.",
            file=sys.stderr,
        )

    for year in sorted(set(files) - set(missing)):
        config = load_config(config_path(year))
        for path in files[year]:
            analyse(path, config)
    sys.exit(1 if missing else 0)


def analyse(path: Path, config: Config) -> None:
    txns = read_csv(path)
    categorise(txns, config)
    out = path.with_suffix(".md")
    out.write_text(render(path.stem, txns, config), encoding="utf-8")
    todo = sum(1 for t in txns if t.category is None)
    print(f"{out.name} : {len(txns)} transactions, {todo} non traitées")


if __name__ == "__main__":
    main()
