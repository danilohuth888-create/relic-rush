"""Lists German source texts that have no English entry in Shared/LocaleEN.luau.

Usage:  python tools/i18n/check.py           missing entries (exit code 1 if any)
        python tools/i18n/check.py --all     every collected source text

Collected: string literals passed to L(...), Locale.format/text, notify(...)/setObjective(...)
in ExpeditionService, WorldText.set(...), the data fields name/text/hint/title in the shared
catalogues, ActionText/ObjectText literals of prompts, and static sign texts of the world
builders (STATIC below).
"""
import pathlib
import re
import sys

ROOT = pathlib.Path(__file__).resolve().parents[2]
SRC = ROOT / "src"
LUA_STRING = r'"((?:[^"\\\n]|\\.)*)"'

PATTERNS = [
    r'\bL\(\s*' + LUA_STRING,
    r'Locale\.format\([^,]+,\s*' + LUA_STRING,
    r'Locale\.text\([^,]+,\s*' + LUA_STRING,
    r'WorldText\.set\([^,]+,\s*' + LUA_STRING,
    r'"§"\s*\.\.\s*' + LUA_STRING,
    r'notify\(\w+,\s*"\w+",\s*' + LUA_STRING,
    r'setObjective\(run,\s*' + LUA_STRING,
    r'\btext\(player,\s*' + LUA_STRING,
    r'setSign\(plot,\s*' + LUA_STRING,
    r'(?:ActionText|ObjectText)\s*=\s*' + LUA_STRING,
    r'prompt\(run,[^,]+,\s*' + LUA_STRING + r',\s*' + LUA_STRING,
    r'SetAttribute\("LAction",[^\n]*?' + LUA_STRING,
]
DATA_FILES = ["ReplicatedStorage/Shared/Config.luau", "ReplicatedStorage/Shared/RelicDefs.luau",
              "ReplicatedStorage/Shared/Builds.luau", "ReplicatedStorage/Shared/Credits.luau"]
DATA_FIELD = r'\b(?:name|text|hint|title)\s*=\s*' + LUA_STRING
# Texts written by the world builders (tools/world) and other fixed labels.
STATIC = [
    "Kristallplatz", "Willkommen in Aetheria!", "Flüsterwald", "Vergessene Ruinen",
    "Expedition · 1–4 Spieler", "Freie Schatzkammer", "Ausbau-Stein", "Zurück nach Aetheria",
    "🏆 Größte Sammlung", "RELIC RUSH-Team", " und ", "Das hat nicht geklappt.", "Musik", "Effekte",
] + [f"Schatzkammer {i}" for i in range(1, 9)]
ERRORS_BLOCK = r'local ERRORS[^{]*\{(.*?)\n\}'


def unescape(s: str) -> str:
    return s.replace('\\n', '\n').replace('\\"', '"').replace('\\\\', '\\')


def collect() -> set:
    found = set(STATIC)
    for path in SRC.rglob("*.luau"):
        if path.name == "LocaleEN.luau":
            continue
        text = path.read_text(encoding="utf-8")
        for pattern in PATTERNS:
            for match in re.finditer(pattern, text):
                for group in match.groups():
                    if group:
                        found.add(unescape(group))
        if path.name == "HudController.luau":
            block = re.search(ERRORS_BLOCK, text, re.S)
            if block:
                found.update(unescape(m) for m in re.findall(LUA_STRING, block.group(1)))
    for rel in DATA_FILES:
        text = (SRC / rel).read_text(encoding="utf-8")
        found.update(unescape(m) for m in re.findall(DATA_FIELD, text))
    # Pure symbols, numbers and format-only strings need no translation.
    return {s for s in found if re.search(r'[A-Za-zÄÖÜäöüß]{2,}', s) and not s.startswith("rbxasset")}


def translated() -> set:
    text = (SRC / "ReplicatedStorage/Shared/LocaleEN.luau").read_text(encoding="utf-8")
    return {unescape(m) for m in re.findall(r'\[' + LUA_STRING + r'\]\s*=', text)}


def main() -> int:
    sys.stdout.reconfigure(encoding="utf-8")
    sources = collect()
    if "--all" in sys.argv:
        for s in sorted(sources):
            print(repr(s))
        return 0
    have = translated()
    missing = sorted(sources - have)
    unused = sorted(have - sources)
    for s in missing:
        print("MISSING", repr(s))
    for s in unused:
        print("unused ", repr(s))
    print(f"{len(sources)} texts, {len(missing)} missing, {len(unused)} unused")
    return 1 if missing else 0


if __name__ == "__main__":
    sys.exit(main())
