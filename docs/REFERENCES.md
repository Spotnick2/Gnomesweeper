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

## Embedded libraries (`Libs\`, #40)

Copied as they are from `..\GlassMiniMapBar\Libs` (which embeds the same versions); never edited
here. They are the standard WoW addon libraries that hundreds of addons embed, and are shipped
inside the addon, as embedding them is meant to be done. Also noticed in `LICENSE`, which says they
are under their own licences, not ours.

**Licences, read 2026-10-03** (Codex's review of #41 found the pages; each notice ships in its
folder and is summarised in `LICENSE`):
- LibStub: public domain (its header).
- CallbackHandler-1.0: "BSD License", https://www.curseforge.com/wow/addons/callbackhandler/license
  (the page leaves the holder blank; the Ace3 Development Team is named, CallbackHandler being Ace3's).
- LibDBIcon-1.0: "Ace3 Style BSD", https://www.curseforge.com/wow/addons/libdbicon-1-0/license.
  It forbids redistributing it **stand-alone**; embedded is fine.
- LibDataBroker-1.1: **no licence text anywhere**. Its repository (tekkub/libdatabroker-1-1) has
  none; https://www.curseforge.com/wow/addons/libdatabroker-1-1/license says "All Rights Reserved
  unless otherwise explicitly stated". It exists to be embedded and nearly every addon does
  (GlassMiniMapBar too), and LibDBIcon requires it: **the owner chose to embed it anyway** (#41).

| Library | Version | Authors / notes |
|---|---|---|
| LibStub | MINOR 2 | Kaelten, Cladhaire, ckknight, Mikk, Ammo, Nevcairiel, joshborke. Public domain (its header). |
| CallbackHandler-1.0 | MINOR 8 | Nevcairiel and the Ace3 team. BSD. |
| LibDataBroker-1.1 | MINOR 4 | tekkub. No published licence ("All Rights Reserved" on CurseForge). |
| LibDBIcon-1.0 | MINOR 56 | funkydude. Ace3-style BSD (no stand-alone redistribution). |

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
