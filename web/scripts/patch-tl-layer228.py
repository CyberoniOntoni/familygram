"""Align FamilyGram Web TL constructors with server layer 228 for known ID mismatches."""
from __future__ import annotations

import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
API_TL = ROOT / "src" / "lib" / "gramjs" / "tl" / "static" / "api.tl"
API_TL_TS = ROOT / "src" / "lib" / "gramjs" / "tl" / "apiTl.ts"
SRC_228 = Path(r"D:\Software\Grok\testgram\docs\api.tl.228")

# Constructors that must match server Latest=228 wire IDs (and fields).
NAMES = [
    "user",
    "channel",
    "botCommand",
    "messages.searchGlobal",
]


def find_line(text: str, name: str) -> str:
    for line in text.splitlines():
        if line.startswith(f"{name}#"):
            return line
    raise KeyError(name)


def patch_file(path: Path, replacements: dict[str, str]) -> None:
    text = path.read_text(encoding="utf-8")
    orig = text
    for name, new_line in replacements.items():
        pat = re.compile(rf"^{re.escape(name)}#[0-9a-fA-F]+\s.*?= .*?;", re.M)
        if not pat.search(text):
            print(f"WARN: no match for {name} in {path.name}")
            continue
        text = pat.sub(new_line, text, count=1)
        print(f"patched {name} in {path.name}")
    if text != orig:
        path.write_text(text, encoding="utf-8", newline="\n")
        print(f"wrote {path}")
    else:
        print(f"no change {path}")


def main() -> None:
    s228 = SRC_228.read_text(encoding="utf-8")
    replacements = {name: find_line(s228, name) for name in NAMES}
    patch_file(API_TL, replacements)
    patch_file(API_TL_TS, replacements)

    # Spot-check apiTl.ts
    web = API_TL_TS.read_text(encoding="utf-8")
    for name, line in replacements.items():
        cid = re.search(r"#([0-9a-fA-F]+)", line).group(1).lower()
        if f"{name}#{cid}" not in web.lower() and f"{name}#{cid}" not in web:
            # case
            if f"{name}#{cid}" not in web:
                print(f"VERIFY FAIL {name}#{cid}")
            else:
                print(f"VERIFY OK {name}#{cid}")
        else:
            print(f"VERIFY OK {name}#{cid}")


if __name__ == "__main__":
    main()
