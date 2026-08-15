#!/usr/bin/env python3
"""Static QA for the Quarto multipage navigation and source integrity."""

from __future__ import annotations

import argparse
import json
import re
import subprocess
from pathlib import Path

import yaml


EXPLICIT_ID_RE = re.compile(r"\{#([A-Za-z0-9_-]+)\}")
MARKDOWN_LINK_RE = re.compile(r"\[[^\]]+\]\(([^)]+)\)")
RAW_ANCHOR_RE = re.compile(r"<a\s+href\s*=", re.IGNORECASE)
INDENTED_RAW_ANCHOR_RE = re.compile(r"(?m)^\s{4,}<a\s+href\s*=")


def arguments() -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    parser.add_argument("--root", default=".")
    parser.add_argument("--output", default="qa/navigation_source_qa.json")
    return parser.parse_args()


def page_anchors(path: Path) -> set[str]:
    return set(EXPLICIT_ID_RE.findall(path.read_text(encoding="utf-8")))


def main() -> int:
    args = arguments()
    root = Path(args.root).resolve()
    config = yaml.safe_load((root / "_quarto.yml").read_text(encoding="utf-8"))
    render_pages = [str(item) for item in config["project"]["render"]]
    navbar = config["website"]["navbar"]["left"]
    navbar_pages = [str(item["href"]).split("#", 1)[0] for item in navbar]

    missing_pages = [page for page in render_pages if not (root / page).is_file()]
    navbar_not_rendered = [page for page in navbar_pages if page not in render_pages]
    all_qmd = [root / page for page in render_pages if (root / page).is_file()]
    anchors_by_page = {page.name: sorted(page_anchors(page)) for page in all_qmd}

    broken_links: list[dict[str, str]] = []
    raw_anchor_files: list[str] = []
    indented_raw_anchor_files: list[str] = []
    pandoc_code_anchor_files: list[str] = []

    for page in all_qmd:
        text = page.read_text(encoding="utf-8")
        if RAW_ANCHOR_RE.search(text):
            raw_anchor_files.append(page.name)
        if INDENTED_RAW_ANCHOR_RE.search(text):
            indented_raw_anchor_files.append(page.name)

        for href in MARKDOWN_LINK_RE.findall(text):
            if href.startswith(("http://", "https://", "mailto:")):
                continue
            target, _, fragment = href.partition("#")
            target_page = page.name if not target else target
            target_path = root / target_page
            if not target_path.is_file():
                broken_links.append({"source": page.name, "href": href, "reason": "missing page"})
                continue
            if fragment and fragment not in page_anchors(target_path):
                broken_links.append({"source": page.name, "href": href, "reason": "missing anchor"})

        pandoc = subprocess.run(
            ["pandoc", "--from=markdown", "--to=json", str(page)],
            cwd=root,
            check=False,
            capture_output=True,
            text=True,
        )
        if pandoc.returncode == 0:
            ast = json.loads(pandoc.stdout)
            for block in ast.get("blocks", []):
                if block.get("t") != "CodeBlock":
                    continue
                code = block.get("c", [None, ""])[1]
                if RAW_ANCHOR_RE.search(code):
                    pandoc_code_anchor_files.append(page.name)
                    break

    public_files = [
        root / "_quarto.yml",
        root / "README.md",
        *all_qmd,
        *(root / "assets").glob("*.js"),
        root / "styles.css",
    ]
    forbidden_references: list[dict[str, str]] = []
    forbidden = re.compile(r"\b(?:UBA|CONICET|UBA-CONICET)\b|Universidad de Buenos Aires", re.IGNORECASE)
    for path in public_files:
        if not path.is_file():
            continue
        for line_number, line in enumerate(path.read_text(encoding="utf-8").splitlines(), start=1):
            if forbidden.search(line):
                forbidden_references.append({"file": str(path.relative_to(root)), "line": str(line_number)})

    result = {
        "render_pages": render_pages,
        "navbar_pages": navbar_pages,
        "anchors_by_page": anchors_by_page,
        "checks": {
            "missing_pages": missing_pages,
            "navbar_not_rendered": navbar_not_rendered,
            "broken_internal_links": broken_links,
            "raw_anchor_files": sorted(set(raw_anchor_files)),
            "indented_raw_anchor_files": sorted(set(indented_raw_anchor_files)),
            "pandoc_code_anchor_files": sorted(set(pandoc_code_anchor_files)),
            "forbidden_public_references": forbidden_references,
        },
    }

    output = root / args.output
    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_text(json.dumps(result, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")

    failed = any(result["checks"].values())
    print(json.dumps(result["checks"], ensure_ascii=False, indent=2))
    return 1 if failed else 0


if __name__ == "__main__":
    raise SystemExit(main())
