"""Regenerate tests/events-<build>.txt from the Forever API dump.

The test stub validates every RegisterEvent against the client's real event
list. The dump lives outside this repo (C:\\Projects\\References), so the list is
checked in as a fixture and tests/test_toc.lua fails if the two ever differ.
A new client build means a new dump: run this, then update EVENTS_FIXTURE in
tests/wow_stubs.lua (see .claude/skills/client-update).

    python Tools/make_events_fixture.py [path-to-dump.md]
"""
import re
import sys
from pathlib import Path

DEFAULT = r"C:\Projects\References\forever-api-1.60.1.70170.md"
dump = Path(sys.argv[1] if len(sys.argv) > 1 else DEFAULT)
build = re.search(r"(\d+\.\d+\.\d+\.\d+)", dump.name).group(1)

events, inside = [], False
for line in dump.read_text(encoding="utf-8").splitlines():
    if line.startswith("## Documented events"):
        inside = True
    elif line.startswith("## "):
        inside = False
    elif inside:
        m = re.match(r"([A-Z][A-Z0-9_]+)\s+\(", line)
        if m:
            events.append(m.group(1))

out = Path(__file__).resolve().parent.parent / "tests" / f"events-{build}.txt"
out.write_text("\n".join(sorted(set(events))) + "\n", encoding="utf-8")
print(f"{len(set(events))} events -> {out}")
