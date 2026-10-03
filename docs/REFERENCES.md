# References

Licences matter: **only MIT/compatible code may be copied** (credit it here and in `LICENSE`).
Everything else is ideas only. Licences below were read from the repos on 2026-10-02 — recheck
before copying anything.

## Game logic

| Reference | Licence | Worth borrowing |
|---|---|---|
| [Kurtsley/XP-Minesweeper-Classic](https://github.com/Kurtsley/XP-Minesweeper-Classic) (LÖVE, Lua) | MIT | The closest model of XP behaviour. `src/board.lua` (`addMinesExcluding` on first click, `checkVictory`, auto-flag on win), `src/tile.lua` (reveal), `src/inputhandlers.lua` (chord: left+right / middle, flag count == number), `config.qMarks` question-mark toggle. |
| [SomeDevNow/love2d-minesweeper](https://github.com/SomeDevNow/love2d-minesweeper) (LÖVE, Lua) | MIT | Rough (hardcoded 16×16/40). Only the **iterative queue flood fill** (`data.clear_blanks` in `src/grid_info.lua`) is worth a look. |
| [Simon Tatham's Mines](https://www.chiark.greenend.org.uk/~sgtatham/puzzles/doc/mines.html) ([source](https://git.tartarus.org/?p=simon/puzzles.git)) | MIT (verify) | "Ensure solubility": generate → run a logical solver → retry, so a board never needs a guess. For a later no-guess mode. |
| [Microsoft Minesweeper (Wikipedia)](https://en.wikipedia.org/wiki/Microsoft_Minesweeper), [Minesweeper wiki](https://minesweeper.fandom.com/wiki/Microsoft_Minesweeper) | — | The rules baseline: presets, first-click guarantee, chord, timer cap 999, counter may go negative, question marks. |
| Minesweeper v3.0.0 by Phoslead (Retail, Interface 120000, Ace3 + LibDBIcon) — local copy at `C:\Projects\References\Minesweeper_v3.0.0` | **No licence file: ideas only.** **Secondary reference — don't consult it first**: the author may port it to Forever themselves, so Gnomesweeper should stand on its own. Notable ideas: shipped `.ogg` sfx (cell, flag, explosion, clock, lose, victory), game-mode picker, game log and replay, minimap button. |
| [MineSweeper (WoW, CurseForge)](https://www.curseforge.com/wow/addons/minesweeper) | All Rights Reserved | **Ideas only.** Abandoned 2012. Had: first click never loses, pause when minimised, character/guild/friends leaderboards, "show on death / in group" triggers. |

## Sibling addons (same owner, same stack)

| Repo | Take from it |
|---|---|
| `..\GlassUnitFrames` | **Owner of the glass material**: `Glass.lua`, `Tools/make_textures.py`, `Media/`, `docs/GLASS-MATERIAL.md`. Options panel on Retail's Settings framework. |
| `..\GlassXp` (GlassPanel) | The closest template: single-owner CLAUDE.md, `Compat.lua` helpers (`Fail`, `Button`, `Window` = the one glass dialog), `Share.lua` (safe import/export strings), `Options.lua`, tests harness. |
| `..\GlassRaidFrames` | `tests/test_toc.lua` (material drift check), `tests/wow_stubs.lua` (dump-validated allowlist stub), `Tools/deploy.ps1`. |
| `..\AltStable` | Addon-message sync (versioned protocol, chunking under 255 bytes, ChatThrottleLib) — the model for M4 leaderboards. `docs/SYNC-DISCOVERY.md`. `.pkgmeta` and release flow. |

## Forever client

- `C:\Projects\References\PORTING-TBC-TO-FOREVER.md` — canonical measured field notes.
- `C:\Projects\References\forever-api-1.60.1.70205.md` — latest API dump (functions, events,
  widget methods, `_G`).
- `C:\Projects\wow-ui-source` (branch `forever`) — Blizzard's FrameXML: atlas names, templates.
