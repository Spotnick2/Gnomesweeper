<p align="center"><img src="docs/logo.png" width="260" alt="Gnomesweeper"></p>

<h1 align="center">Gnomesweeper: Minesweeper Forever</h1>

<p align="center"><em>One wrong click. Full wipe.</em></p>

<p align="center">
  <a href="https://www.curseforge.com/wow/addons/gnomesweeper">Download on CurseForge</a> ·
  <a href="https://github.com/Spotnick2/Gnomesweeper/issues/new/choose">Report a bug</a> ·
  <a href="CHANGELOG.md">What's new</a>
</p>

Classic Minesweeper for **World of Warcraft: Forever**, for the queue, the flight path and the
wait for the tank. Liquid glass, a gnome who takes every move personally, and Gnomeregan's sounds.

<!-- Screenshots: docs/screenshots/ (board, win, modern, settings). -->

## Features

- **Windows XP's rules.** Beginner (9×9, 10 mines), Intermediate (16×16, 40) and Expert (30×16, 99).
  The first click is always safe and opens an area, or a single tile as in XP.
- **Your best times.** Each difficulty keeps your best, shared by all your characters, with who set it
  and when. The clock turns yellow as you near it, flashes in the last 3 seconds, and goes red past it.
  Beat it for a fanfare and fireworks.
- **The gnome.** She's your new-game button, and she reacts: focused while you play, surprised while you
  hold a tile, laughing when you clear the field, sooty after a wipe. She bounces, shudders and nods.
- **Two looks.** Classic, and Modern with ice-blue glass tiles. The difficulties wear WoW's item colours.
- **Sounds and music.** Clicks, the Walking Bomb, a gnome's last words, a "Congratulations", and
  Gnomeregan's music if you want it.
- **Plays nice with your UI.** Hides itself in combat and comes back after (a setting), never touches
  anything protected, and is usable in combat if you turn that off. A minimap button, an entry in the
  minimap's addon list, and a key binding.

## How to play

Open the board with **`/gsweep`** (or `/gnomesweeper`, `/minewipe`), the minimap button, or a key
(Key Bindings > Gnomesweeper).

| Click | Does |
|---|---|
| **Left-click** a tile | Reveals it. A number says how many mines touch it. |
| **Right-click** a tile | Plants a flag on a mine you've found (then a **?**, if question marks are on). |
| **Middle-click** a number, or **left+right** | Clears the tiles around it, once its flags match the number. A wrong flag reveals a mine. |
| **The gnome** | Starts a new game. During a game, it gives this one up. |

Clear every tile that isn't a mine. The **?** in the title bar explains it all in game.

## Commands

| Command | Does |
|---|---|
| `/gsweep` | Opens or closes the board |
| `/gsweep beginner` · `intermediate` · `expert` | Starts a game at that difficulty |
| `/gsweep scores` | Your best times (also the trophy in the title bar) |
| `/gsweep settings` | The settings (also the gear in the title bar) |
| `/gsweep music` | Gnomeregan's music on or off (also the note in the title bar) |
| `/gsweep combat` | Hiding in combat on or off |
| `/gsweep minimap` | Shows or hides the minimap button |
| `/gsweep scale 0.5` to `1.5` · `reset` | Resizes the window (it never grows past your screen) |
| `/gsweep reset` | Puts the window back in the middle of the screen |

## Settings

In **Options > AddOns > Gnomesweeper** (or the gear in the title bar):

- **Question marks**: right-click cycles flag, then ?, then clear.
- **First click**: opens an area, or one safe tile (Windows XP's rule). Each rule keeps its own best times.
- **Board**: Classic or Modern. Changes at once, even mid-game.
- **Clear with left-click**: a left-click on a number whose flags match clears around it.
- **Sounds**, **Gnomeregan music**, **Fireworks**, **Hide in combat**, the **minimap button**.
- **Window size**, and **Reset best times**.

## Found a bug? Have an idea?

Gnomesweeper is made and tested by one person on one setup, so **your reports are how problems on
other setups get found**: [open an issue](https://github.com/Spotnick2/Gnomesweeper/issues/new/choose).
A Lua error (turn them on with `/console scriptErrors 1`, or use BugSack) and a screenshot help the
most. Ideas are welcome too.

## Credits

- **The rules** follow Windows XP Minesweeper.
  [Kurtsley/XP-Minesweeper-Classic](https://github.com/Kurtsley/XP-Minesweeper-Classic) (MIT) was the
  model for its behaviour; no code is copied. Details in [docs/REFERENCES.md](docs/REFERENCES.md).
- **Libraries**, embedded under their own licences: LibStub, CallbackHandler-1.0, LibDataBroker-1.1 and
  LibDBIcon-1.0 (their authors and licences are listed in [LICENSE](LICENSE)).
- **Sounds, music and the bomb** are World of Warcraft's own, played from the client; nothing of
  Blizzard's is redistributed.
- **The gnome's expressions, the lettering, the laurels and the Modern tiles** were generated for this
  addon ([Media/README.md](Media/README.md), with every prompt in
  [Media/ART-PROMPTS.md](Media/ART-PROMPTS.md)). The rest of the art is drawn by the scripts in `Tools/`.
- **The glass** is the Liquid Glass material shared by the Glass addons (Glass Unit Frames and family).

## Development

Lua 5.1 on Forever's Retail API, no build step. `pwsh tests\run.ps1` runs the tests; CI runs them on
every pull request, with a packaging check. The design is [docs/PLAN.md](docs/PLAN.md), the art
direction [docs/ART.md](docs/ART.md), and the working notes for contributors (and AI agents)
[CLAUDE.md](CLAUDE.md).

## Licence

MIT: see [LICENSE](LICENSE). Embedded libraries keep their own licences.
