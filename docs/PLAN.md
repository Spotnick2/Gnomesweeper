# Gnomesweeper — plan

> **Gnomesweeper — Minesweeper Forever.** *One wrong click. Full wipe.*

Storyboard: [`storyboard.png`](storyboard.png) — four states of one window.

## The window (from the storyboard)

```
┌──────────────────────────────────────────┐
│ (gnome)  GnomeSweeper            [⚙] [✕] │  title bar: logo, title, tagline
│          One wrong click. Full wipe.     │
│              [ Beginner  ▾ ]             │  difficulty dropdown
│ ┌──────────────────────────────────────┐ │
│ │ 🚩 10        (gnome face)    ⏱ 00:00 │ │  HUD: mines−flags, reset face, timer
│ ├──────────────────────────────────────┤ │
│ │ ▢▢▢▢▢▢▢▢▢                            │ │  the grid: glossy blue glass tiles
│ │ ...                                  │ │
│ └──────────────────────────────────────┘ │
│        Choose a tile to begin.           │  gold hint (state 01 only)
│   Left-click: Reveal   Right-click: Flag │  controls hint
└──────────────────────────────────────────┘
```

The four states:

| # | State | Face | What shows |
|---|---|---|---|
| 01 | Ready to play | goggles up, smiling | all tiles covered, 00:00, gold "Choose a tile to begin." |
| 02 | Find your rhythm | goggles down, focused | revealed cells dark/flat, numbers coloured, flags, **hovered tile glows cyan** |
| 03 | Field cleared | beaming, golden burst behind | gold-rimmed overlay: "Field cleared!", time, "New personal best!" with laurels, **Play again** |
| 04 | One wrong click | shocked | exploded mine tile red with smoke, all bombs shown, overlay "Boom. Full wipe." + **Try again** |

Number colours (storyboard): 1 blue, 2 green, 3 red; take 4–8 from classic Minesweeper
(navy, maroon, teal, black→ use dark grey on glass, grey).

Mines are **gnomish bombs** (round, riveted, red eye) — not skulls.

**Theme: Gnomeregan.** The cast comes from Gnomeregan: Thermaplugg's **Walking Bombs** are the
mines, **Alarm-a-bomb 2600** is the alarm, a Gnomeregan gnome is the face. They're live models where
possible, and generated art (M3) draws on the same look. Display IDs and roles: `docs/MODELS.md`.

## Milestones

The backlog of record is the GitHub issues (`github.com/Spotnick2/Gnomesweeper`), one milestone each; this section is the overview.

### M1 — Playable (day 1): #2 #3 #4 #5 #6
- `Board.lua`: pure game model + full unit tests (rules in `CLAUDE.md`).
- `Window.lua` + `Skin.lua`: the glass window, HUD, pooled tile grid, all three presets via the
  dropdown, states 01–04 with the overlays, Escape to close, draggable, position saved.
- Simple baked tile textures (never glass per tile); a window that fits the screen at every
  difficulty; the timer pauses while the window is hidden.
- Slash commands open/toggle; `/gsweep beginner|intermediate|expert` starts that preset.
- Art: WoW-internal placeholders for every element (`docs/ASSETS.md`), generated art only where
  nothing in the client fits.
- In-game measure: click registration (left/right/middle, chord), tile render cost at Expert size.
  **Measured** (`/gsweep perf`, owner, 2026-10-02, build 70170, two runs): building an Expert board
  2.9 to 3.8 ms; a first reveal and repaint 0.7 to 1.0 ms (9 to 18 cells); a loss showing all 99
  cells 0.7 to 1.2 ms; ten difficulty switches 12 ms. The pool already existed, so the cost of
  creating 480 buttons the first time is not in these numbers. Baked tiles are comfortably cheap,
  so #14 (baked tile refinement) is only about looks now.
- **Done when:** complete games at all three presets, reset and difficulty changes mid-game,
  close and reopen, and input and performance measured in game.

### M2 — Polish: #7 #8 #9 #10 #11 #20 #21 #22 #23
- Personal bests per difficulty **and ruleset** (precise time, date, name), shown in the win
  overlay ("New personal best!"). The record is defined in #7 before anything is saved.
- Settings (gear button): question marks, safe-zone size, chord on left-click, sounds, scale.
- Sounds: SoundKit IDs for reveal / flag / boom / win (measure each plays).
- Face animations (pressed-tile "o" face, win burst, loss smoke).
- The model probe (#20), then live models (#21): the wipe bomb first; a live face only if it
  reads at HUD size.
- Gnomeregan music with a mute button (#22); a keybinding and a launcher (#23).

### M3 — Art pass: #12 #13 #14
- Replace placeholders with generated gnomish art (gnome face set, bomb, exploded tile, logo),
  converted to TGA via the recipe in `Media/README.md`.

### M4 — Social (later, not day 1): #15 #16 #17
- Guild leaderboard over `C_ChatInfo.SendAddonMessage(..., "GUILD")` — the owner's favourite.
- Friends / Battle.net friends (`C_BattleNet.SendGameData`; needs a real BN friendship).
- Brag line in guild chat on a personal best (opt-in).
- Wire format versioned from the first message (sibling lesson from AltStable's sync).
- Read the porting guide's "Addon-to-addon transports" first.

### Maybe: #18
- No-guess board generation (Simon Tatham's generate→solve→retry; see `REFERENCES.md`).
- Custom board size. Daily seeded board shared across the guild (same seed = same board).
