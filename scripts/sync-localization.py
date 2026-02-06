#!/usr/bin/env python3
"""
Sync localization keys: use English as the single source of truth.
Missing keys in other *.lproj/Localizable.strings files are copied
from English (value = English text, to be translated later).

Usage:
    ./scripts/sync-localization.py

Assumptions:
- Base file: VibeCapture/Resources/en.lproj/Localizable.strings
- Target files: all other */*.lproj/Localizable.strings under VibeCapture/Resources
"""

import pathlib
import re

ROOT = pathlib.Path(__file__).resolve().parent.parent
BASE_FILE = ROOT / "VibeCapture/Resources/en.lproj/Localizable.strings"
RES_ROOT = ROOT / "VibeCapture/Resources"
STRINGS_NAME = "Localizable.strings"

PAIR_RE = re.compile(r'\s*"(?P<key>.*?)"\s*=\s*"(?P<val>(?:\\"|[^"])*?)"\s*;')


def parse_pairs(text: str):
    return PAIR_RE.findall(text)


def main():
    if not BASE_FILE.exists():
        raise SystemExit(f"Base file not found: {BASE_FILE}")

    base_text = BASE_FILE.read_text(encoding="utf-8")
    base_pairs = dict(parse_pairs(base_text))
    base_keys = list(base_pairs.keys())

    targets = [p for p in RES_ROOT.glob("*.lproj") if p.name != "en.lproj"]
    print(f"Base keys: {len(base_keys)}  |  Targets: {len(targets)}")

    for target_dir in targets:
        f = target_dir / STRINGS_NAME
        if not f.exists():
            print(f"- Skip (missing file): {f}")
            continue

        text = f.read_text(encoding="utf-8")
        existing = dict(parse_pairs(text))
        missing = [k for k in base_keys if k not in existing]

        if not missing:
            print(f"- {target_dir.name}: already in sync")
            continue

        lines = [
            "\n\n// === Auto-filled missing keys (copied from en; translate as needed) ===\n"
        ]
        for k in missing:
            v = base_pairs[k]
            lines.append(f'"{k}" = "{v}";\n')

        with f.open("a", encoding="utf-8") as fh:
            fh.writelines(lines)

        print(f"- {target_dir.name}: added {len(missing)} missing keys")

    print("Done.")


if __name__ == "__main__":
    main()
