#!/usr/bin/env python3
"""Check MCP4i lesson chapters against the curriculum's structural conventions.

Usage:
    python3 check_lessons.py                       # every docs/lesson-*.md
    python3 check_lessons.py docs/lesson-06-*.md   # specific files

Errors are conventions every published chapter follows. Warnings are habits that most
chapters follow and that are worth a second look. The script checks mechanics only --
it cannot judge voice, accuracy, or whether a claim overreaches what the repository
can demonstrate. Read the chapter yourself for those.
"""

from __future__ import annotations

import re
import sys
from pathlib import Path

LESSON_RE = re.compile(r"^lesson-(\d{2})-[a-z0-9-]+\.md$")
H1_RE = re.compile(r"^# Lesson (\d+) — .+$")
NAV_RE = re.compile(r"^\[Learning index\]\(README\.md\)( · .+)?$")
MILESTONE_RE = re.compile(r"^\*\*Project (milestone|connection):\*\* .+")
LINK_RE = re.compile(r"\[[^\]]*\]\(([^)]+)\)")

DISCOURAGED = {
    "simply": "the curriculum's point is that these steps are not simple",
    "just ": "minimises a step the learner has to defend",
    "seamless": "unmeasured praise",
    "production-ready": "a claim the repository cannot support",
    "guaranteed": "a claim the repository cannot support",
    "powerful": "unmeasured praise",
    "etc.": "hides the boundary the lesson is teaching",
}


def repo_root(start: Path) -> Path:
    fallback = None
    for parent in [start, *start.parents]:
        if (parent / "docs").is_dir():
            if (parent / ".git").exists():
                return parent
            fallback = fallback or parent
    return fallback or start


class Report:
    def __init__(self, name: str) -> None:
        self.name = name
        self.errors: list[str] = []
        self.warnings: list[str] = []

    def error(self, msg: str) -> None:
        self.errors.append(msg)

    def warn(self, msg: str) -> None:
        self.warnings.append(msg)


def check_lesson(path: Path, root: Path, roadmap: str, index: str) -> Report:
    rep = Report(path.name)
    text = path.read_text(encoding="utf-8")
    lines = text.splitlines()

    m = LESSON_RE.match(path.name)
    if not m:
        rep.error("filename should look like lesson-NN-short-slug.md")
        number = None
    else:
        number = int(m.group(1))

    if not lines:
        rep.error("file is empty")
        return rep

    h1 = H1_RE.match(lines[0])
    if not h1:
        rep.error('line 1 should be "# Lesson N — Title" with an em dash (—)')
    elif number is not None and int(h1.group(1)) != number:
        rep.error(f"H1 says Lesson {h1.group(1)} but the filename says {number:02d}")

    nav_line = lines[2] if len(lines) > 2 else ""
    if not NAV_RE.match(nav_line):
        rep.error('line 3 should be the nav line starting "[Learning index](README.md)"')

    head = "\n".join(lines[:12])
    if not any(MILESTONE_RE.match(ln) for ln in lines[:12]):
        rep.error('missing "**Project milestone:**" or "**Project connection:**" line near the top')

    headings = [ln for ln in lines if ln.startswith("## ")]
    heading_text = " ".join(headings).lower()

    if "paper" not in heading_text:
        rep.warn(
            'no "Paper walkthrough" heading; confirm the chapter still traces a fictional '
            "request end to end somewhere"
        )
    if "homework" not in heading_text and "exercise" not in heading_text:
        rep.warn("no homework or exercise section; the learner produces nothing here")
    if not any(h.strip().lower() == "## summary" for h in headings):
        rep.error('missing "## Summary"')
    if "reading" not in heading_text:
        rep.warn('no "Reading and video" section')

    english = [ln for ln in lines if ln.startswith("**English:**")]
    hinglish = [ln for ln in lines if ln.startswith("**Hinglish:**")]
    if not english or not hinglish:
        rep.error("missing the paired **English:** / **Hinglish:** summary")
    elif len(english) != len(hinglish):
        rep.error(
            f"{len(english)} **English:** lines but {len(hinglish)} **Hinglish:** lines; "
            "they are always written as pairs"
        )
    for ln in hinglish:
        if re.search(r"[ऀ-ॿ]", ln):
            rep.error("Hinglish line uses Devanagari; the curriculum uses Roman script")

    if not any(ln.startswith("Gate:") for ln in lines) and "gate" not in heading_text:
        rep.warn('no "Gate:" sentence naming the evidence needed before the next chapter')

    if "fictional" not in text.lower():
        rep.warn("no statement that the identifiers and observations are fictional")

    lower = text.lower()
    for word, why in DISCOURAGED.items():
        if word in lower:
            rep.warn(f'"{word.strip()}" appears — {why}')

    for link in LINK_RE.findall(text):
        if link.startswith(("http://", "https://", "#", "mailto:")):
            continue
        target = (path.parent / link.split("#", 1)[0]).resolve()
        if not target.exists():
            rep.error(f"relative link does not resolve: {link}")

    if path.name not in roadmap:
        rep.error("not listed in docs/00-roadmap.md chapter table")
    if path.name not in index:
        rep.error("not listed in docs/README.md chapter table")

    return rep


def main(argv: list[str]) -> int:
    root = repo_root(Path(__file__).resolve().parent)
    docs = root / "docs"

    if argv:
        paths = [Path(a).resolve() for a in argv]
    else:
        paths = sorted(docs.glob("lesson-*.md"))

    if not paths:
        print("no lesson files found", file=sys.stderr)
        return 1

    roadmap = (docs / "00-roadmap.md").read_text(encoding="utf-8") if (docs / "00-roadmap.md").exists() else ""
    index = (docs / "README.md").read_text(encoding="utf-8") if (docs / "README.md").exists() else ""

    reports = [check_lesson(p, root, roadmap, index) for p in paths]
    errors = sum(len(r.errors) for r in reports)
    warnings = sum(len(r.warnings) for r in reports)

    for rep in reports:
        if not rep.errors and not rep.warnings:
            print(f"ok    {rep.name}")
            continue
        print(f"{'FAIL ' if rep.errors else 'warn '} {rep.name}")
        for msg in rep.errors:
            print(f"      error: {msg}")
        for msg in rep.warnings:
            print(f"      warn:  {msg}")

    print(f"\n{len(reports)} chapters, {errors} errors, {warnings} warnings")
    return 1 if errors else 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
