# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.
`AGENTS.md` points other agents (Codex, Copilot) here: this file is the source of truth.

## What this is

**Gnomesweeper — Minesweeper Forever** is a Minesweeper clone for **World of Warcraft: Forever
1.60.1** (Interface `16001`), written in **Lua 5.1**. It's a single-owner project (Spotnick), on the
same stack and conventions as the sibling Forever addons `..\GlassUnitFrames` (owner of the glass
material), `..\GlassRaidFrames`, `..\GlassXp` (GlassPanel) and `..\AltStable`. When this file
doesn't cover something, check how those handle it before you invent a new idiom.

- **Name in the AddOns list / logo:** Gnomesweeper. Namespace, TOC, deployed folder: `Gnomesweeper`.
- **Commands:** `/gnomesweeper`, `/gsweep`, and the alias `/minewipe`.
- **Tagline:** "One wrong click. Full wipe."
- **Look:** the owner's liquid-glass material with playful gnomish details: a goggled gnome
  face as the reset button (the classic smiley), gnomish bombs as mines, red flags, a stopwatch.
  The storyboard is `docs/storyboard.png`; the design and roadmap are `docs/PLAN.md`.

**Status: M1 in progress.** Done: the scaffold (#1) and the game model, `Board.lua` (#2). Next:
the glass window (#3) and the tile grid (#4) on top of it. Nothing is drawn yet; `/gsweep` still
says "not playable".

**The backlog is GitHub issues** at `github.com/Spotnick2/Gnomesweeper` (private), grouped by
milestone (M1 Playable, M2 Polish, M3 Art pass, M4 Social) and labelled `art`, `measure`
(needs the live client), `social`, `postponed`. `gh issue list -R Spotnick2/Gnomesweeper
--milestone "M1 — Playable"` is the work queue. New work gets an issue first; an issue's body
holds the decided design, so update it when the design changes.

## Layout

TOC load order (planned files in brackets): `Compat.lua` → `Glass.lua` → `Board.lua` →
[`Skin.lua`] → [`Models.lua`] → [`Window.lua`] → [`Scores.lua`] → `Gnomesweeper.lua`.

- **`Compat.lua`**: `Gnomesweeper.API`, the only route to client APIs that moved or may be absent,
  and `MEASURED_ON_BUILD`. Lift helpers from `..\GlassXp\Compat.lua` (`Fail`, `Button`, `Window`)
  when needed instead of rewriting them.
- **`Glass.lua`**: the material, **copied** from GlassUnitFrames' **`main`** branch
  (`git -C ..\GlassUnitFrames show main:Glass.lua`), with only the header and namespace lines
  changed. `tests/test_toc.lua` fails when the two drift; it reads `main` through git because other
  sessions switch that repo's working tree. Change the material there first (with its
  `docs/GLASS-MATERIAL.md`) and copy it back. `Tools/make_textures.py` and `Media/*.tga` are copies
  too. API: `Glass.Apply(host, "large"|"small")`, `Glass.Font`, `Glass.Bar`, `Glass.Sheen`,
  `Glass.ContentLevel`, `Glass.Inset`.
- **`Board.lua`** (#2, done): **the game, pure Lua, no WoW API at all** — and `tests/test_board.lua`
  loads it with every global but a few builtins forbidden, so it stays that way. Everything else is
  a view on it. The header comment is the API; in short:
  - `Gnomesweeper.Board.New(w, h, mines, opts)` returns a board, or `nil, why`. `opts`:
    `rng(n)` (1..n), `safeZone` (`"area"`/`"cell"`), `questionMarks`. `Board.PRESETS` /
    `Board.PRESET_ORDER` hold Beginner, Intermediate, Expert.
  - `b:Reveal(x, y, now)`, `b:Chord(x, y, now)`, `b:ToggleMark(x, y)` each return the **changed cells**
    (unique row-major indices, `{}` for a no-op): repaint exactly those.
  - `b:Cell(i)` → `{state, count | mine, exploded, wrongFlag}`; `b:Index(x, y)`; `b:State()`
    (`ready|playing|won|lost`); `b:FlagsLeft()`; `b:Elapsed(now)` (active seconds, uncapped);
    `b:Pause(now)` / `b:Resume(now)`; `Board.DisplaySeconds(t)` (whole, capped at 999).
  - The clock is the caller's: `now` is always passed in (use `GetTime()`), and `Reveal`/`Chord`
    error without it.
  - `Board._test.FromLayout(rows)` builds a board from text rows (`*` = mine) already past its first
    reveal; tests only.
- **`Skin.lua`** (milestone 1): tile, number, face and icon art in one table (`Skin.TEXTURES`,
  `Skin.NUMBER_COLORS`), so art swaps never touch logic. See `docs/ASSETS.md`.
- **`Models.lua`** (#20, #21): live creature models (the gnome face, the bomb on a wipe) in
  `ModelScene`s, on AltStable's pet-rendering recipe (`docs/MODELS.md`). **Display IDs, never
  `SetCreature`**; never a model per tile; everything degrades to the 2D art.
- **`Window.lua`** (milestone 1): the glass window: title bar (gnome logo, title, tagline, settings,
  close), difficulty dropdown, the HUD (flag counter, gnome face, timer), the grid, the hint line,
  the win/loss overlays. Tiles are **pooled** `Button`s reused across difficulty changes (Expert is
  480 tiles: never create per game), drawn with **simple shared textures** (a baked covered tile,
  a flat revealed fill, a hover glow; `Tools/make_tiles.py`), **never `Glass.Apply` per tile**:
  it makes 6 textures, a mask and a frame per host, and its sliced mask is measured to fail on
  small squares. Glass is for the window and the overlays. The window has a minimum chrome width,
  centres the board, and fits its scale to the screen (Expert at 24 px tiles is 720×384 before
  chrome). It refits after difficulty, resolution and UI-scale changes.
- **`Scores.lua`** (milestone 2): personal bests per difficulty in `GnomesweeperDB`. Social
  leaderboards (guild/friends/Battle.net) are milestone 4 — not day 1.
- **`Gnomesweeper.lua`**: the entry point — `GnomesweeperDB` defaults at `ADDON_LOADED`, slash
  commands. Loads last.

## Game rules (decided — don't re-litigate without the owner)

Windows XP Minesweeper is the baseline (see `docs/REFERENCES.md`):

- Presets: **Beginner 9×9 / 10**, **Intermediate 16×16 / 40**, **Expert 30×16 / 99**; Custom later.
- A board is `w, h ≥ 1` integers with `0 ≤ mines < w·h`; anything else is rejected.
- **Mines are placed on the first successful reveal**, never on the clicked cell. Default safe
  zone: the clicked cell **and its in-bounds neighbours** (5 at an edge, 4 in a corner), so the
  first click opens an area. When the mines don't fit outside that zone, it falls back to the
  single cell. An option narrows it to XP's single cell. Flags placed before the first reveal don't
  influence placement. Placement samples **without replacement** from the eligible cells (no retry
  loop) through the injected `opts.rng(n) → 1..n`. A board is reproducible from the same rng,
  options and first-reveal cell.
- Flood fill is an **iterative queue**, never recursion.
- Flags block reveal, flood fill and chord; question marks behave like covered cells for all three.
  Marking a revealed cell, and every action after a win or loss, does nothing.
- **Chord** on a revealed number whose adjacent flags equal it reveals the other neighbours; a
  wrong flag loses. A chord anywhere else (covered, marked, zero, unsatisfied) does nothing.
  Triggered by middle-click, by left+right, or by left-click on a satisfied number (an option).
- Right-click cycles covered → flag → (question mark, if enabled) → covered.
- Mine counter = mines − flags, may go negative.
- **Timer:** starts on the first *successful* reveal (not marks, not a no-op chord) and freezes on
  win or loss. It counts **active time**: the model has `Pause(now)` / `Resume(now)`, and the window
  pauses while it's hidden. Scores keep the precise, uncapped time; only the display caps at 999 s.
- Win when `revealed == cells − mines`; remaining mines get auto-flagged.
- Loss: the clicked mine shows exploded, other mines revealed, wrong flags crossed.
- Every action returns the changed cells as **one table of unique row-major indices** (`{}` for a
  no-op), including auto-flags and everything a loss reveals. The view repaints exactly those.

## References: read these before touching an unfamiliar API

- `C:\Projects\References\PORTING-TBC-TO-FOREVER.md` — canonical, addon-agnostic field notes
  measured on the live client. Treat as fact; write new addon-agnostic findings **there**.
  Most relevant here: "Checking a texture exists before you draw it" (`GetFileIDFromPath`),
  sounds (`PlaySoundFile` refuses game-file *paths*: use SoundKit / FileDataIDs or shipped files),
  "Draw order inside one layer", "A MaskTexture small in BOTH directions must NOT be sliced"
  (tiles are small!), "Addon-to-addon transports" (for leaderboards).
- `C:\Projects\References\forever-api-1.60.1.70170.md` — the latest API dump: functions, events,
  **widget methods** and the `_G` walk. Proves a name exists, not that it works.
- `C:\Projects\wow-ui-source` — Blizzard's UI source on the **`forever`** branch (check the branch
  first; other sessions share it). Use it to find atlas names (`SetAtlas("...")`) and templates.
- `..\GlassUnitFrames\docs\GLASS-MATERIAL.md` — the material's recipe and its limits.
- `docs/SOUNDS.md` — Gnomeregan sound kits and music (`PlaySound(kit)`, `PlayMusic(fileID)`;
  never `PlaySoundFile` with a game path).
- `docs/MODELS.md` — rendering creature models, from AltStable's measured pet work
  (`..\AltStable\docs\forever-api-notes.md` "Pets", `..\AltStable\Plugins\Roster\AltStableRoster.lua`).
- `docs/REFERENCES.md` — game-logic references and their licences. `docs/ASSETS.md` — the art plan.
- In game: `/api search <name>`.

## Forever facts that matter here

Forever is **Vanilla content on Blizzard's Retail (Mainline) codebase**: Retail API, Lua 5.1.
Advice citing TBC/Classic APIs is usually stale.

- `## Interface: 16001` (**`11601` is the transposed-digit bug**); TOC has no `_Forever` suffix.
- **Nothing here is secure or secret**: plain `Button`s, no combat lockdown concerns, no unit
  numbers. Keep it that way — the window must be usable in combat (it's a minigame for queues and
  flight paths). Never parent anything to a protected frame.
- Register tile clicks with `RegisterForClicks("LeftButtonUp", "RightButtonUp", "MiddleButtonUp")`
  (plain buttons, so the porting guide's "both edges" rule for *secure* buttons doesn't apply —
  but measure it).
- `UISpecialFrames` for Escape-to-close. `FULLSCREEN_DIALOG` strata like GlassPanel's `Window`.
- SavedVariables persist as of 70009. Verify persistence only with a **full client exit**, never
  a `/reload`. Code must still cope when they're absent.

## Toolchain and commands

No build system. Lua 5.1 lives at `C:\Program Files (x86)\Lua\5.1\` (`lua.exe`, `luac.exe`); use
it, not a newer Lua on `PATH`.

```powershell
pwsh tests\run.ps1                                                  # luac -p on every TOC file + every tests\test_*.lua
& 'C:\Program Files (x86)\Lua\5.1\lua.exe' tests\test_toc.lua      # one test, from the repo root
pwsh Tools\deploy.ps1                                               # -> AddOns\Gnomesweeper
pwsh Tools\deploy.ps1 -AddOnsPath "D:\...\_classic_beta_\Interface\AddOns"
```

- Default AddOns path: `C:\Program Files (x86)\World of Warcraft\_classic_beta_\Interface\AddOns`.
- Deploy rewrites `## Version: @project-version@` to `dev` **in the deployed copy only**. Never
  commit a literal version over that token (it has happened twice on sibling projects).
- In game: `/console scriptErrors 1`, then `/reload`. A brand-new addon folder needs a client
  restart. Check the AddOns list shows it enabled and not out of date.

## Addon basics

- One global namespace table, `Gnomesweeper`. Every file starts
  `local ADDON = ...` / `Gnomesweeper = Gnomesweeper or {}`.
- SavedVariables: `GnomesweeperDB` (account-wide: settings, personal bests). Its shape on disk is
  a contract once released — add fields, don't repurpose them.
- Keep a `_test` seam table at the bottom of a file to expose internals to tests. Don't promote
  internals to globals.
- Client-shipped fonts only (`Glass.FONTS`).

## Testing

`tests\` follows the Glass* siblings: plain Lua 5.1, `tests\wow_stubs.lua` (driven through the
`WoW` table), `tests\harness.lua` (`check` / `eq` / `done` / `tocFiles` / `loadAddon`),
`tests\run.ps1`.

- **`Board.lua` is where the tests go.** It's pure, so test it directly: first-click safety,
  flood fill shape, chord with right and wrong flags, win/loss, counter, timer cap. Seed the RNG.
- **The stub is an allowlist.** Before stubbing a global, confirm it's in the dump and copy its
  signature; defining something Forever lacks lets a broken call pass. When the UI lands, grow the
  stub toward `..\GlassRaidFrames\tests\wow_stubs.lua` (dump-validated events and widget methods)
  rather than inventing a new one.
- **Mutation-test a new test**: break the behaviour, confirm it goes red.
- Offline tests can't cover rendering or click feel. Those need the game.

## Workflow (sibling conventions)

- Issue → branch off `main` → PR with `Closes #N` → review → squash-merge. **The owner merges,
  closes PRs and launches reviews.** Never commit to `main`, never `gh pr merge`. Commit or push
  only when asked. Before committing: `pwsh tests\run.ps1` green.
- Adversarial review goes through `/codex-consult` (`.claude/skills/codex-consult/`), with Fable as
  the fallback. Verify its claims before acting, and push back on complexity for a single-owner
  addon. PR reviews from Codex use the owner's global `$wow-addon-review` skill
  (`~/.codex/skills/wow-addon-review`); post each review on the PR.
- A new client build: `/client-update` (`.claude/skills/client-update/`).
- Releases: CurseForge's packager from the tag webhook, reading `.pkgmeta`. Every tag needs a
  `CHANGELOG.md` entry, written for players.

## Conventions

- **Right-size for a single maintainer.** The simplest thing that works; no speculative config.
- **Measured beats reasoned.** If a claim about the client can be checked in game, check it.
- **Reuse WoW's own art first** (`docs/ASSETS.md`); generate only what the client can't supply,
  and record every generated asset's prompt and conversion in `Media/README.md`.
- **Borrow ideas, not unlicensed code.** Only MIT/compatible sources may be copied, with credit
  in `docs/REFERENCES.md` and `LICENSE`.
- Match the surrounding code's idiom. Keep pure refactors in their own commit.
