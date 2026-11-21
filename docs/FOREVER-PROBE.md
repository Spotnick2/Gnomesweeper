# GnomesweeperProbe

Gnomesweeper's developer probe, `Tools/GnomesweeperProbe` (#87): a ForeverProbe module (`..\ForeverProbe`,
its `docs/GUIDE.md`; the cross-project entry point is `C:\Projects\WoW\References\Docs\PROBES.md`).
**It is never packaged**, and the shipped addon keeps no probe code (the owner's rule: no probe ships in a
release). Until #87 these were `/gsweep` commands marked "(for measuring)", shipped to every player.

## Running it

1. `pwsh Tools\deploy.ps1 -Probe` deploys the addon, then ForeverProbe, then the probe
   (`-ProbeOnly` for just the probe). `/reload`. `_forever_` is the live client: deploy it only for a
   test session the owner is running.
2. `/fp` opens the console **before** an experiment. The probe's lines land there and in
   `GnomesweeperProbeDB.log`, never in chat. `/fp gs` lists the commands.
3. `/reload` writes `WTF\Account\<account>\SavedVariables\GnomesweeperProbe.lua`: the log, and what each
   command measured (below). A Claude session reads it from disk; nothing needs pasting.

| Command | What it does | Saved in `GnomesweeperProbeDB` |
|---|---|---|
| `/fp gs assets` | A contact sheet of every texture the skin names; says which client paths the client lacks (#6) | `assets` |
| `/fp gs models` | A sheet of every candidate creature model (`docs/MODELS.md`), each cell's load time; click one for the viewer (head crops, animations, particles) (#20) | `models` (the head crop too) |
| `/fp gs modelperf` | The frame rate over the open board for 5 s, then 5 s with a head on the face and a bomb over the tiles | `models.perf` |
| `/fp gs bomb` | Replays the end panel's model (the bomb on a wipe, Tally on a win), to judge it by eye (#21) | the log |
| `/fp gs sounds` | Every candidate sound kit, 3 s apart, then the music (only with the board shown, out of combat); again to stop (#9, #22) | `sounds` |
| `/fp gs perf` | Times an Expert build, a first reveal, a loss and ten difficulty switches on a scratch board, then puts the game back (#4) | the log |
| `/fp gs input` | Logs every tile press and release (`upInside`, `IsMouseOver`) and what each action did; again to stop (#4) | the log |
| `/fp gs guild` | Phase 0 of #15: every way the client names this character, a `P` message to the guild and its echo, `Ambiguate`'s answers, the toasts' state | the log |
| `/fp gs clear` | Empties the saved log | |

How it reaches the addon: its public functions and its `_test` seams. `input` wraps `Window.Dispatch` and
`Grid.Refresh` while it's on and puts them back after, and hooks the tiles' mouse scripts (`HookScript`,
silent while off). The hooks run after the addon's own handler, so a press that only ended the new-game
wave shows as a plain press (the shipped addon used to say so; it no longer logs anything).

## Results

The measurements made with the old `/gsweep` commands are where they were recorded: `docs/MODELS.md`
(models, frame cost), `docs/SOUNDS.md` (sound kits), `docs/SOCIAL.md` (the guild channel, phase 0 and after
the realm hotfix), `docs/PLAN.md` (the board's timings), `docs/ASSETS.md` (textures). New results go there
too, with the build, and addon-agnostic ones in `C:\Projects\WoW\References\Docs\PORTING-TBC-TO-FOREVER.md`.
