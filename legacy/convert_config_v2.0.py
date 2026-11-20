#!/usr/bin/env python3
"""Convert config-YYYY.yaml files from the v1 format (structure + regles)
to the v2 format (single "categories" tree) used by analyze_v2.0.py.

Usage: python3 convert_config_v2.0.py

Every config-YYYY.yaml next to this script that still has a "structure"
section is converted in place; the original is kept as config-YYYY.yaml.v1.
Comments attached to the patterns are preserved.
"""

from __future__ import annotations

import json
import re
import sys
from collections import defaultdict
from pathlib import Path

import yaml

__version__ = "2.0"

HERE = Path(__file__).resolve().parent
IGNORE = "Ignorer"

HEADER = """\
# =============================================================================
# Sous-arbre affiché dans la section « Synthèse » des fichiers .md
# (dépenses en positif, remboursements en négatif).
# =============================================================================
synthese: {synthese}

# =============================================================================
# Catégories : un arbre, dans l'ordre d'affichage.
# - Un nom suivi de sous-noms est un GROUPE : son montant = somme de ses enfants.
# - Un nom suivi d'une liste "- motif" est une CATÉGORIE : une transaction y va
#   si l'un des motifs est trouvé dans son texte. Sans motif : "Nom:" seul.
# - La PREMIÈRE catégorie qui correspond gagne, dans l'ordre du fichier.
# - Majuscules/accents ignorés : "coop" trouve "COOP-1234 EXEMPLE".
# - "A & B" : A et B doivent tous deux être présents.
# - "re:..." : expression régulière.
# - Catégorie spéciale "Ignorer" : transferts internes, etc.
# - Chaque nom doit être unique dans tout l'arbre.
# =============================================================================
categories:
"""


def raw_rule_lines(text: str) -> dict[str, list[str]]:
    """Lines (patterns and comments) under each category of "regles:", as written."""
    result: dict[str, list[str]] = {}
    current = None
    inside = False
    for line in text.splitlines():
        if re.match(r"^regles:\s*(#.*)?$", line):
            inside = True
            continue
        if not inside or not line.strip() or line.startswith("#"):
            continue
        if not line.startswith(" "):
            inside = False  # next top-level key
            continue
        if m := re.match(r"^  ([^\s#][^#]*?):\s*(#.*)?$", line):
            current = m[1].strip()
            result[current] = []
        elif line.startswith("    ") and current:
            result[current].append(line[4:].rstrip())
    return result


def convert(text: str) -> tuple[str, list[str]]:
    raw = yaml.safe_load(text) or {}
    rules = raw.get("regles") or {}
    raw_lines = raw_rule_lines(text)

    edges = []
    for item in raw.get("structure") or []:
        src, dst = (s.strip() for s in item.split(">", 1))
        edges.append((src, dst))
    children = defaultdict(list)
    has_in = set()
    for s, d in edges:
        children[s].append(d)
        has_in.add(d)
    nodes = list(dict.fromkeys(n for e in edges for n in e))
    sources = [n for n in nodes if n not in has_in]

    out: list[str] = []

    def leaf(name: str, indent: str, kids: list[str] | None = None) -> None:
        patterns = rules.get(name) or []
        lines = raw_lines.get(name)
        out.append(f"{indent}{name}:")
        if lines is not None and sum(1 for l in lines if l.lstrip().startswith("- ")) == len(patterns):
            out.extend(f"{indent}  {l}" if l else "" for l in lines)
        else:  # unusual layout: rewrite the patterns, comments are lost
            out.extend(f"{indent}  - {json.dumps(str(p), ensure_ascii=False)}" for p in patterns)

    def node(name: str, depth: int) -> None:
        indent = "  " * (depth + 1)
        if children[name]:
            out.append(f"{indent}{name}:")
            for c in children[name]:
                node(c, depth + 1)
        else:
            leaf(name, indent)

    leaf(IGNORE, "  ")
    out.append("")
    for hub in dict.fromkeys(d for s, d in edges if s in sources):
        out.append(f"  {hub}:")  # incomes grouped under the node they feed
        for s in sources:
            if hub in children[s]:
                leaf(s, "    ")
        out.append("")
        for c in children[hub]:
            node(c, 0)
            out.append("")

    # v1 priority = order of "regles"; v2 priority = order of the tree
    old = [c for c, p in rules.items() if p]
    position = {name: i for i, name in enumerate(re.findall(r"^\s*([^\s#-][^#]*?):", "\n".join(out), re.M))}
    new = sorted(old, key=lambda c: position.get(c, -1))
    moved = [f"{a} passe maintenant avant {b}"
             for i, a in enumerate(new) for b in new[i + 1:] if old.index(a) > old.index(b)]
    content = HEADER.format(synthese=raw.get("synthese") or "Dépenses") + "\n".join(out).rstrip() + "\n"
    return content, moved


def main() -> None:
    configs = sorted(HERE.glob("config-*.yaml"))
    if not configs:
        sys.exit(f"Aucun fichier config-AAAA.yaml dans {HERE}")
    for path in configs:
        text = path.read_text(encoding="utf-8")
        if "structure" not in (yaml.safe_load(text) or {}):
            print(f"déjà au format v2  {path.name}")
            continue
        backup = path.with_name(path.name + ".v1")
        backup.write_text(text, encoding="utf-8")
        content, moved = convert(text)
        path.write_text(content, encoding="utf-8")
        print(f"converti           {path.name} (original : {backup.name})")
        if moved:
            print("  ATTENTION, l'ordre de priorité des règles a changé (vérifie les rapports) :")
            for m in moved:
                print(f"    - {m}")


if __name__ == "__main__":
    main()
