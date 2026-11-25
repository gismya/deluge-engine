#!/usr/bin/env python3
"""The startup guard (spec §3.4): fails when the firmware's deluge_main or registerTasks text changes.

The Engine doesn't call deluge_main(); it runs its own init list, a copy of the engine half of deluge_main, then the
firmware's registerTasks() and scheduler. A pin move that changes either function must get the host list checked
against the new text. This stores a hash of each function's text and fails on any change.

    tools/startup_guard.py            check the firmware against engine/platform/startup_hashes.json
    tools/startup_guard.py --update   after checking the host init list against the new text, store the new hashes

The host init list today: main() in engine/cli/render_preset.cpp (E1). E2 replaces it with the scheduler startup.
Seam S5 (splitting deluge_main) removes the list and this guard.
"""

import argparse
import hashlib
import json
import re
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "firmware/src/deluge/deluge.cpp"
HASHES = ROOT / "engine/platform/startup_hashes.json"
FUNCTIONS = ("deluge_main", "registerTasks")
HOST_INIT = "engine/cli/render_preset.cpp"


class GuardError(Exception):
    pass


def function_text(text, name):
    """The definition of `name`, from the start of its line to its closing brace (braces in comments, strings and
    character literals don't count)."""
    m = re.search(rf"^[^\n;{{}}]*\b{re.escape(name)}\s*\([^;{{]*\)\s*\{{", text, re.M)
    if not m:
        raise GuardError(f"no definition of {name}()")
    depth, i = 0, m.end() - 1
    token = re.compile(r'//[^\n]*|/\*.*?\*/|"(?:\\.|[^"\\\n])*"|\'(?:\\.|[^\'\\\n])*\'|[{}]', re.S)
    while True:
        t = token.search(text, i)
        if not t:
            raise GuardError(f"{name}() never closes")
        if t.group() == "{":
            depth += 1
        elif t.group() == "}":
            depth -= 1
            if depth == 0:
                return text[m.start():t.end()]
        i = t.end()


def digest(text):
    return hashlib.sha256(text.encode()).hexdigest()


def firmware_commit(source):
    r = subprocess.run(["git", "-C", str(source.parent), "rev-parse", "--short=9", "HEAD"], capture_output=True,
                       text=True)
    return r.stdout.strip() or "unknown"


def main(argv=None):
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--source", type=Path, default=SOURCE)
    ap.add_argument("--hashes", type=Path, default=HASHES)
    ap.add_argument("--update", action="store_true")
    a = ap.parse_args(argv)
    try:
        text = a.source.read_text()
        now = {name: digest(function_text(text, name)) for name in FUNCTIONS}
    except (OSError, GuardError) as e:
        print(f"startup_guard: {e}", file=sys.stderr)
        return 1
    if a.update:
        a.hashes.write_text(json.dumps({**now, "checked_at_firmware": firmware_commit(a.source)}, indent=2) + "\n")
        print(f"startup_guard: stored hashes in {a.hashes}")
        return 0
    stored = json.loads(a.hashes.read_text()) if a.hashes.exists() else {}
    changed = [name for name in FUNCTIONS if stored.get(name) != now[name]]
    if changed:
        print(f"startup_guard: {', '.join(changed)} changed in {a.source} since the host init list was checked "
              f"(at firmware {stored.get('checked_at_firmware', '?')}). Compare the host init list ({HOST_INIT}) "
              "with the new text, fix it, then run tools/startup_guard.py --update.", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
