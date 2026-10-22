#!/usr/bin/env python3
"""Valida a documentação atual do repositório Database Infra.

A validação roda sem rede e sem credenciais e verifica:

- presença e conteúdo dos documentos e diagramas obrigatórios;
- coerência das entidades entre a fonte Mermaid, o modelo relacional e o SVG;
- integridade dos links relativos dos arquivos Markdown.
"""

from __future__ import annotations

import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
DOCS = ROOT / "docs"

REQUIRED_FILES = [
    ROOT / "README.md",
    DOCS / "modelo-relacional.md",
    DOCS / "indices-desempenho.md",
    DOCS / "adr" / "0001-consistencia-modelo.md",
    DOCS / "assets" / "arquitetura-database.png",
    DOCS / "assets" / "modelo-relacional-database.png",
    DOCS / "diagrams" / "er-model.mmd",
    DOCS / "diagrams" / "er-model.svg",
]

MERMAID_ENTITY = re.compile(r"^\s{4}([a-z_][a-z0-9_]*)\s*\{", re.MULTILINE)
DOCUMENTED_ENTITY = re.compile(
    r"^\|\s*`([a-z_][a-z0-9_]*)`\s*\|",
    re.MULTILINE,
)
MARKDOWN_LINK = re.compile(r"\[[^\]]*\]\(([^)#\s]+)(?:#[^)]*)?\)")

errors: list[str] = []


def relative(path: Path) -> Path:
    return path.relative_to(ROOT)


def check_required_files() -> None:
    for path in REQUIRED_FILES:
        if not path.is_file():
            errors.append(f"arquivo obrigatório ausente: {relative(path)}")
            continue
        if path.stat().st_size == 0:
            errors.append(f"arquivo obrigatório vazio: {relative(path)}")


def check_er_model() -> None:
    mmd_path = DOCS / "diagrams" / "er-model.mmd"
    svg_path = DOCS / "diagrams" / "er-model.svg"
    doc_path = DOCS / "modelo-relacional.md"

    if not all(path.is_file() for path in (mmd_path, svg_path, doc_path)):
        return

    diagram = set(MERMAID_ENTITY.findall(mmd_path.read_text(encoding="utf-8")))
    documented = set(
        DOCUMENTED_ENTITY.findall(doc_path.read_text(encoding="utf-8"))
    )

    if not diagram:
        errors.append("nenhuma entidade encontrada em docs/diagrams/er-model.mmd")
        return

    if not documented:
        errors.append("nenhuma entidade encontrada em docs/modelo-relacional.md")
        return

    for entity in sorted(diagram - documented):
        errors.append(
            f"entidade `{entity}` está no diagrama, mas não em "
            "docs/modelo-relacional.md"
        )

    for entity in sorted(documented - diagram):
        errors.append(
            f"entidade `{entity}` está em docs/modelo-relacional.md, mas não no diagrama"
        )

    svg = svg_path.read_text(encoding="utf-8", errors="ignore")
    for entity in sorted(diagram):
        if entity not in svg:
            errors.append(
                f"entidade `{entity}` não aparece em docs/diagrams/er-model.svg: "
                "regenere a imagem a partir de docs/diagrams/er-model.mmd"
            )


def check_relative_links() -> None:
    for markdown in sorted(ROOT.rglob("*.md")):
        if ".git" in markdown.parts:
            continue

        content = markdown.read_text(encoding="utf-8")
        for target in MARKDOWN_LINK.findall(content):
            if "://" in target or target.startswith(("mailto:", "tel:")):
                continue

            resolved = (markdown.parent / target).resolve()
            try:
                resolved.relative_to(ROOT)
            except ValueError:
                errors.append(
                    f"{relative(markdown)}: link relativo sai do repositório -> {target}"
                )
                continue

            if not resolved.exists():
                errors.append(
                    f"{relative(markdown)}: link relativo quebrado -> {target}"
                )


def main() -> int:
    check_required_files()
    check_er_model()
    check_relative_links()

    if errors:
        for error in sorted(set(errors)):
            print(f"::error::{error}")
        return 1

    print("Documentação e diagrama ER coerentes.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
