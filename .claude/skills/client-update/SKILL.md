---
name: client-update
description: Handle a new WoW Forever client build for Gnomesweeper - find (or have AltStable produce) the new API dump in C:\Projects\References, diff it against the previous build for names this addon uses, and prepare the MEASURED_ON_BUILD bump PR. Use when the owner says there is a new build/API bump, "apidump done", "new api build", or a build newer than MEASURED_ON_BUILD shows up in C:\Projects\References.
version: 1.0.0
allowed-tools: [Bash, Read, Edit, Write, Grep, Glob]
---

# A new Forever client build

Adapted from AltStable's `client-update` skill. **Gnomesweeper does not own the dump tooling**: the
dump addon and its converters live in `..\AltStable\Tools\ForeverAPIDump\`, and the converted dumps
are shared by every Forever project in `C:\Projects\References\forever-api-<version>.<build>.md`.

## Who does what

| Step | Who | What |
|---|---|---|
| 1. Dump | **owner**, in game | only if `C:\Projects\References` has no dump for the new build yet: deploy AltStable's dump addon, `/apidump`, `/reload` |
| 1. Convert | you | `pwsh ..\AltStable\Tools\ForeverAPIDump\Convert-Dump.ps1` (skip if the file already exists — another session may have done it) |
| 2. Diff | you | `pwsh ..\AltStable\Tools\ForeverAPIDump\Compare-Dumps.ps1` |
| 3. Check | you | grep this repo for every changed name |
| 4. Bump PR | you | edits, tests, branch, PR (commit/push only when asked) |

**Never delete old dumps**; that is the owner's call.

## 2–3. Diff and check

- The documented sections (functions, events, tables, **widget methods**, namespace functions) are
  the client. The `_G` walks pick up whatever addons were loaded — never a finding on their own.
- For every documented change, grep `*.lua` and `tests/` for the name. Gnomesweeper's surface is
  small (frames, buttons, textures, fonts, `C_Texture`, `GetFileIDFromPath`, sounds, later
  `C_ChatInfo` / `C_BattleNet`): a removed or re-signatured function we call is a bug to fix before
  the bump, not a note.
- Re-check the art: if `/gsweep assets` exists (#6), ask the owner to run it on the new build — a
  client update can drop or rename an icon or atlas.

## 4. The bump PR

Branch `build-<build>` from `main`:

1. `Compat.lua` — `Gnomesweeper.MEASURED_ON_BUILD = "<version>.<build>"`.
2. `CLAUDE.md`, `AGENTS.md`, `docs/REFERENCES.md`, `.claude/skills/codex-consult/SKILL.md` — the
   dump file name they cite.
3. `tests/wow_stubs.lua` — the dump file name in the header, and `GetBuildInfo` if it is stubbed.
4. The event list the stub validates against: `python Tools/make_events_fixture.py` writes
   `tests/events-<build>.txt` from the new dump. Point `EVENTS_FIXTURE` (`tests/wow_stubs.lua`) and the
   default dump path (`tests/test_toc.lua`, `tests/test_methods.lua`) at the new build, and delete the old
   fixture. `test_methods.lua` then re-checks every widget method the addon calls against the new dump,
   which is the real answer to "did this build remove something we use".

Then `pwsh tests\run.ps1` green, `pwsh Tools\deploy.ps1`, and a `/reload` in game. Commit, push and
open the PR (`Closes #N`) **only when the owner asks** — the owner runs every review.

Addon-agnostic findings about the new build go in `C:\Projects\References\PORTING-TBC-TO-FOREVER.md`,
not here.
