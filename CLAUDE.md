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

**Status: M1 done; M2 next.** M1: the scaffold (#1), the game model `Board.lua` (#2), the glass
window (#3), the tile grid (#4), the game states (#5) and the asset probe (#6): **the game is
playable** at all three difficulties and ends with the storyboard's overlays. Since then: the art
direction from the logo (#28), the Liquid Glass polish with the rarity colours (#30). M2 so
far: personal bests and the best times panel (#7), the settings (#8). #32 (confirm before a difficulty change) waits on the owner, and the
mascot's expressions and the mine wait on art (`docs/ART.md`).

**The backlog is GitHub issues** at `github.com/Spotnick2/Gnomesweeper` (public since the CurseForge setup), grouped by
milestone (M1 Playable, M2 Polish, M3 Art pass, M4 Social) and labelled `art`, `measure`
(needs the live client), `social`, `postponed`. `gh issue list -R Spotnick2/Gnomesweeper
--milestone "M1 — Playable"` is the work queue. New work gets an issue first; an issue's body
holds the decided design, so update it when the design changes.

## Layout

TOC load order (planned files in brackets): `Libs\*` (LibStub, CallbackHandler-1.0, LibDataBroker-1.1,
LibDBIcon-1.0) → `Compat.lua` → `Glass.lua` → `Board.lua` → `Layout.lua` → `Scores.lua` → `Skin.lua` →
`Widgets.lua` → `Input.lua` → `Grid.lua` → [`Models.lua`] → `Effects.lua` → `Window.lua` → `Options.lua` → `Minimap.lua` →
`Sounds.lua` → `Assets.lua` → `Gnomesweeper.lua`.

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
- **`Layout.lua`** (#3): the window's geometry as **pure functions**, loaded in tests with every
  global forbidden like `Board.lua`: `Layout.Size(cols, rows)` (a minimum chrome width, the board
  centred, 24-unit tiles), `Layout.FitScale` (never more than 95% of the screen; the screen is
  UIParent's size, so a UI-scale or resolution change moves it), `Layout.FormatTime`,
  `Layout.ValidPos` / `Layout.ClampPos` (a saved position is the window's top-left corner in
  **UIParent units**).
- **`Skin.lua`**: every texture and colour in one table (`Skin.TEXTURES`, `Skin.COLORS`), so art
  swaps never touch logic. The art is **ours, in `Media/`**: generated by script (`Tools/make_tiles.py`,
  `Tools/make_ui.py`), the ready face cut from the logo (`Tools/png_to_tga.py`), and the generated
  art of #12 (the expressions, the title lettering, the laurels: `Tools/export_art.py` from
  `Media/Source/Generated/`, `Media/README.md`). **On the board, WoW's bomb (133709) and our pennant**:
  the generated mine and flag read worse at tile size (owner), and are staged. The bomb and the
  settings gear are the client's (`docs/ASSETS.md`). `Skin.FACE` maps each game state to its expression;
  `Skin.TITLE_CROP` crops the lettering to its drawn part. `Skin.RARITY` has WoW's
  item-quality colours and `Skin.DIFFICULTY_QUALITY` maps Beginner/Intermediate/Expert to
  uncommon/rare/epic (`Skin.DifficultyColor(key)`); **legendary is held back** for a much harder
  level some day (#18). The mascot shows the game state by her expression (`Skin.FACE`, #12) and a
  ring coloured by state (`Skin.FACE_RING`); nothing is drawn over her (the sparkle and soot that
  stood in for the expressions are gone). `Skin.ASPECT` gives the wide textures' shape (the title, the
  laurels; `Skin.LAUREL_CROP` crops the laurels to their drawn branches). `Skin.NUMBER_COLORS` has the 1-8 colours.
- **`Widgets.lua`**: the Liquid Glass controls: `GlassButton` (a dark glass body, a rim that takes an
  accent colour, a hover glow, a pressed state), `IconButton`, `FaceButton` (the mascot in her ring),
  `GlassPanel`, `Tip`. Baked textures, 9-sliced for the wide buttons; **a small square is never
  sliced** (its corners would meet). Methods we add are lower-case (`b:setAccent`), so none can
  collide with the client's. A `GlassPanel` has a near-opaque, masked backing under its glass body (a list over the
  HUD must not show it through), the difficulty list sits at window level +30 (above the result
  overlay's rim at +25), and a glass button clears its pressed look if it hides before the release.
- **`Input.lua`** (#4): mouse gestures to actions, **pure** (every global forbidden in its test).
  `Input.New({reveal, mark, chord})` then `g:Down(tile, button)`, `g:Up(tile, button, inside)`,
  `g:Cancel()`. Every action fires from a **release**, once. Left, right or middle pressed and
  released on the same tile: reveal, mark, chord. Left+right (either order) latches a **chord** that
  fires on the first release if it is on the tile both were pressed on, and consumes both releases.
  A release off the tile, on another tile, or with no recorded press does nothing. The click-order
  matrix is `tests/test_input.lua`.
- **`Grid.lua`** (#4): the board view. `Grid.Attach(parent, action)`, `Grid.Rebuild(board)` (a new
  game), `Grid.Refresh(list)` (repaint exactly the cells an action changed), `Grid.SetInteractive`,
  `Grid.Cancel`. Tiles are **pooled** `Button`s (Expert is 480: created once, up to the largest
  board seen, then reused and hidden; never per game). A tile has a background (one of three
  **shared baked textures** from `Tools/make_tiles.py`: covered, revealed, exploded) and a hover
  glow up front; its flag/bomb icon and its number are created the first time it needs them. **No
  `Glass.Apply` per tile**: it makes 6 textures, a mask and a frame per host, and its sliced mask
  is measured to fail on small squares. **The new-game wave (#43)**: `Grid.Shuffle()` re-covers the tiles
  in a diagonal wave from the top-left (each fades in and drops `SHUFFLE_DROP` units), `SHUFFLE_SPREAD`
  + `SHUFFLE_FALL` = three seconds, the arm's sound (both start on the click), from one `OnUpdate` that exists only while it runs; a press during it
  finishes it and isn't a click, and a rebuild or the window closing finishes it too. Only the player's
  new game plays it (`playerNewGame` in Window: the face, Play again, Try again, with the arm's sound).
  Mouse: `OnMouseDown`/`OnMouseUp` only, **never `OnClick`**
  (one dispatch path); `upInside` from the client, `IsMouseOver()` when it isn't passed.
- **`Models.lua`** (#20, #21): live creature models (the gnome face, the bomb on a wipe) in
  `ModelScene`s, on AltStable's pet-rendering recipe (`docs/MODELS.md`). **Display IDs, never
  `SetCreature`**; never a model per tile; everything degrades to the 2D art.
- **`Window.lua`** (#3, done; #4 and #5 build on it): the glass window, built **lazily** on the first
  `/gsweep`. It owns the current game (`Window.game`, a `Board`) and is the only thing that creates
  one: `Window.NewGame(preset)`, `Window.Open(preset)`, `Window.Toggle()`. Its parts:
  - Title bar (name and tagline, no portrait: the mascot is the HUD's face), then its icons: the music
    note, the trophy for the best times, the **?** (its tooltip is how to play: every click, clearing
    around a number, the gnome), the settings gear (#8),
    close), a difficulty
    button in the difficulty's **rarity colour** with a small **hand-rolled** list (not Blizzard's
    dropdown API, which no sibling has measured on Forever; each row gives the name and
    `9x9 · 10 mines`, built from `Board.PRESETS`, and the current row has a bar down its edge; the list
    closes on an outside click by polling `IsMouseButtonDown` in an OnUpdate that exists only while it's
    open), the HUD strip (mines left, the mascot = a new game, the clock). The strip's width is capped
    (`Layout.HudWidth`) so the three stay together on Expert. A dark backing under the glass keeps the
    scenery from competing with the board.
  - **`Window.Dispatch(kind, i)` is the controller**, the one place the game is acted on: it asks
    the board (`Reveal`/`Chord`/`ToggleMark` at `game:XY(i)`, with `chordOnLeft` turning a left click
    on a revealed number into a chord), has `Grid.Refresh` repaint the changed cells, refreshes the
    HUD, and turns the hover glow off when the game ends. #5's overlays hang off `Window.win` and
    start from the state `Dispatch` leaves. `Window._test.ui` exposes the widgets to tests, and
    `Window._test.SetGame(board)` swaps in a hand-built board.
  - **The clock is active time:** hiding the window calls `game:Pause`, showing it `game:Resume`.
    An `OnUpdate` redraws the clock only while a game is in progress.
  - **Fit:** `Window.Layout()` runs on a new game, on every show, and on `DISPLAY_SIZE_CHANGED` /
    `UI_SCALE_CHANGED`. The window is moved by dragging, saved as `GnomesweeperDB.pos`, and clamped
    back on screen when restored. `/gsweep reset` forgets it.
  - **The end of a game (#5):** the mascot follows `game:State()` (`ui.face:setState`, set in
    `Window.Refresh`). The action that ENDS a game (a state change in `Dispatch`, not just a finished
    state) calls `Window.ShowEnd()`: one overlay frame, built on first use and re-dressed each time,
    centred on the board, above the tiles (so the board under it takes no clicks; the Board no-ops
    after the end anyway) and under the difficulty list. Cleared: gold title and rim, "Time mm:ss",
    "Play again". Wipe: red title and rim, "Try again". Under a win's time: **"New personal best!"**
    in gold, or the best that stands ("Best 00:42"), from `Scores` (#7). **"See the field"** (and a click on the
    panel) puts the overlay away, `Window.DismissEnd()`, and the result stays in the footer as a
    **result bar** with its Play again / Try again button, in place of the controls; the finished
    board is untouched. It does not come back on later clicks, and a new game (the button, the face,
    the difficulty list) clears both. The burst, the smoke and the fireworks are `Effects.lua`'s (#10).
  - **A difficulty change asks first when there's something to lose (#32, owner: "a reveal beyond
    the first, or any flag"):** a flag on the board (read from it, so a flag taken off again doesn't
    count; a board not started yet counts too), or a second reveal or chord (`reveals`, counted in
    `Dispatch`). The list then shows "Start Expert? This game will be lost." with Start / Keep game
    (`askFor`); anything that closes the list cancels (an outside click with any button), and so does
    the game ending. A first reveal
    alone or a finished game switch at once. `chooseDifficulty` decides for both the list and
    `/gsweep <difficulty>`.
  - **The first launch's pointer (#45, owner: a glass callout):** above the face with a gold arrow
    down, "Click the gnome for a new game..." and Got it; `GnomesweeperDB.seenFaceTip` is saved when
    it shows. It goes on Got it, the face, the difficulty button (it covers it), or the window closing,
    and it is one of the floating panels (the list or Best times put it away).
  - **Hide in combat (#37, a setting, on by default; `/gsweep combat`):** `PLAYER_REGEN_DISABLED` hides
    the window (the clock pauses, a press is cancelled, the list goes, the music stops, as any close)
    and records `Window.combatHid = shownCount`; `PLAYER_REGEN_ENABLED` brings it back only if it
    still matches (the player didn't show or close it meanwhile). Opened mid-fight, it stays until the
    next fight. The window is never protected: with the setting off it works in combat.
  - **The footer:** "Choose a tile to begin." (ready only), `Left-click: Reveal     Right-click: Flag`,
    `Middle-click: Clear around number`. (The **?** that explains clearing moved to the title bar.)
  - **Scale:** `/gsweep scale 0.5 to 1.5` (or `reset`) sets `GnomesweeperDB.scale`; `Layout.FitScale`
    still keeps the window inside 95% of the screen, so the scale wanted and the scale shown can
    differ, and the command says so.
  - **Measuring commands:** `/gsweep perf` times an Expert build, a first reveal, a loss and ten
    difficulty switches on a scratch board (then puts your game back); `/gsweep input` logs every
    tile press and release with `upInside` and `IsMouseOver`, for the live input matrix. The lines
    are also kept in `GnomesweeperDB.inputLog` (last 300, debug only), so a `/reload` writes them to
    `WTF\Account\<acct>\SavedVariables\Gnomesweeper.lua` and they can be **read from disk**
    instead of pasted. The same trick works for any future probe.
- **`Options.lua`** (#8): the settings. `Options.ITEMS` lists them (question marks, the first-click
  rule, left-click clearing, the window scale; sounds #9, music #22, models #21 and hiding in combat
  #37 join it with their issues). **`Options.Set(key, value)` is the one place a setting changes**: it
  checks the value (refused: nothing changes), saves it, applies it, and refreshes the page. The slash
  commands go through it too. Question marks and the first-click rule are part of a board: they apply
  from the next game, and a board nobody has touched (every tile covered: no reveal, no mark) is
  replaced at once. The same value again does nothing. **Reset best times...** on the page (owner)
  forgets every best and count (`Scores.Reset`): the first click only arms it for `RESET_WINDOW`
  (5 s), a second resets (no popup: none measured on Forever); `Window.ScoresReset` drops the best
  to beat.
  **The one place to set them is Options > AddOns > Gnomesweeper** (owner's call: guild scores and
  more are coming, and a panel in the window would outgrow it); the gear and `/gsweep settings` open
  it (`Options.Open`). It is GlassUnitFrames' recipe: a canvas registered at `PLAYER_LOGIN` (its controls on a
  scroll frame's child, `UIPanelScrollFrameTemplate`, since the settings outgrew the canvas), built on
  its first show and **hidden at creation** (or its first show is blank: measured), Blizzard's check/radio/button templates with the client's own
  art as the fallback (`API.SafeFrame`). **Sub-pages** go under it, registered right after it, in
  order (GlassRaidFrames' Click-casting way): **About** (version from `API.AddOnVersion`, "dev"
  unpackaged; how to play; **links** to CurseForge and GitHub in read-only edit boxes to copy from,
  `Options.LINKS`; the commands from `GS.HELP`, minus the "(for measuring)" ones). **The recipe is
  shared**, for every Forever addon: the porting guide's "An Options page with sub-pages and an About
  page" (update it there when something new is measured here). Neither
  page is a named frame (no globals). Showing the page never builds the game window: a size set there
  is saved and used when the window is built (`Window.SetScale` doesn't build it).
  **Blizzard's `SettingsPanel` is in the HIGH strata and our window in FULLSCREEN_DIALOG, above it**:
  while it is open our window steps aside (hidden, so its clock pauses) and comes back when it closes,
  if it was open and the player didn't show or close it meanwhile (`Window.shownCount`); that is
  hooked on `SettingsPanel` itself, so it also holds when Settings is opened from the game menu.
  The best times, the list's column and the tooltip show the **current game's** first-click rule, so
  a rule changed mid-game shows with the next game, the one it applies to. `Window.Floating(frame)` keeps the difficulty list and the best times one at a
  time and closes them with the window. A screen or UI-scale change refreshes the page (the size note
  says when the window is shown smaller to fit).
- **`Libs\`** (#40): LibStub, CallbackHandler-1.0, LibDataBroker-1.1 and LibDBIcon-1.0 (MINOR 56),
  **copied from `..\GlassMiniMapBar\Libs`** (owner's decision: the standard minimap button, which every
  collector picks up). Never edited here. **Not loaded in tests**: `tocFiles()` skips `Libs\` (pass
  `true` for all), and the stub's `LibStub` hands out recording fakes (`WoW.ldb`, `WoW.ldbi`).
- **`Minimap.lua`** (#40): the minimap button, a LibDataBroker launcher (the mascot's face) shown by
  LibDBIcon, registered at `PLAYER_LOGIN`. **Left-click opens or closes the board, right-click opens
  the settings.** Its position and shown state are LibDBIcon's own table, `GnomesweeperDB.minimap`
  (made at `ADDON_LOADED`, replaced if damaged). Showing it is a setting ("Minimap button", and
  `/gsweep minimap`), through `Options.Set` (an item with `get`/`set` keeps its value outside
  `GnomesweeperDB[key]`). Without the libraries there is simply no button.
- **`Effects.lua`** (#10): the celebrations, all client `AnimationGroup`s on a few textures (no OnUpdate
  of ours), each built once with `play`/`stop`/`isPlaying`. **The burst**: the gold starburst turning
  behind the face while a win shows (`Window.Refresh`): no longer a spinning starburst (owner: harsh); a
  gold ring ripples out once and a soft glow (`Media/fx_glow`) breathes, the spell-proc glow's rhythm. **The smoke**: three puffs (`Media/fx_smoke`,
  `Tools/make_ui.py`) rising from the tile that went off, looping while the wipe shows. **The pulse**:
  the overlay's bigger "New personal best!" line (`o.newBest`, 16 pt, gold, swelling to 110%; the quiet `o.best` keeps
  "Best 00:42"). **Fireworks** on a new personal best (the owner's idea): seven bursts in gold, the
  difficulty's rarity colour and white, at random places over the board, staggered, with kit 8569;
  a **Fireworks** setting (on). The effects sit on `ui.fx`, a frame at window level +12: over the
  tiles, under the end overlay. **The surprised face**: `Grid.Attach`'s third argument tells Window
  when a tile is held (the first button down, the last up, or `Grid.Cancel`), and the face
  `setPressed`s while the game can be played: her surprised face, `Skin.TEXTURES.facePressed` (#12).
  The animation methods are the dump's
  `SimpleAnim*API`; `test_methods` checks each against its type's group.
- **`Sounds.lua`** (#9, #22): the effects and Gnomeregan's music. **Effects** are client sound
  kits played with the global `PlaySound(kit, "SFX")` (the game's sound toggle and volume apply;
  `PlaySoundFile` refuses game paths here, and `C_Sound.PlaySound`'s second argument is an enum, not
  a channel). `Sounds.KITS` holds the picks (`docs/SOUNDS.md`, all measured to play): a reveal or
  chord clicks, a flag on and off each click, a win congratulates (no click on top), a wipe is the
  bomb and then, after `WIPE_DELAY`, a gnome's last words (two `PlaySound`s at once overlap), the
  face / Play again / Try again press the big red button. **Voices follow the character's sex**
  (`UnitSex`: the wipe cry, and a greeting on the first open of a session). The clock passing the
  best to beat (its time when the game started) plays an alert, once a game. An action that changes nothing is silent. A new game or the window
  closing cancels a sound still waiting (`Sounds.Cancel`). `Window.Dispatch` calls `Sounds.Action`.
  **Music**: `PlayMusic(53189)` replaces the zone's music; **one check** (the setting on, the window
  shown, not in combat) runs whenever any of them changes (`Sounds.UpdateMusic`: the window's
  show/hide, `PLAYER_REGEN_*`, a setting), and `StopMusic()` only for music this addon started.
  Off by default. The title bar's **note** button (greyed under a red slash when off) and the
  settings change the same value. **`/gsweep sounds`** plays every candidate, `PROBE_GAP` apart,
  then the music, and saves each kit's `willPlay` in `GnomesweeperDB.soundProbe` (a probe, to pick
  by ear; a second `/gsweep sounds` stops it).
- **`Assets.lua`** (#6): `/gsweep assets`, a contact sheet of every `Skin.TEXTURES` entry with its name
  and kind (`media` = ours, `path` = a client path, `fileID` = a client ID). Only a path can be judged
  by the client (`GetFileIDFromPath` answers nil for one it lacks); our files and file IDs are judged
  by eye (getters echo nonsense IDs). What `GetFileIDFromPath` answers for our own files is recorded
  too. Results go to `GnomesweeperDB.assetProbe` for a `/reload` to write to disk.
- **`Scores.lua`** (#7): personal bests, **pure** (every global forbidden in its test); the window
  hands it the saved table and the record. **`GnomesweeperDB.scores` is a contract once released**
  (the leaderboards, #15, build on it): `{ version = 1, [category] = { best = record, played = n,
  won = n } }`, `category = difficulty .. ":" .. ruleset` (`area` or `cell`, the first-click safe zone:
  the two starts aren't comparable), `record = { time = precise active seconds, at = time(), name =
  full name with surname, realm }`. Shown seconds are derived, never stored; a tie keeps the
  **earlier** record. **played** counts on a game's first successful reveal (abandoned games count),
  **won** on the win. The window (`recordScores` in `Dispatch`, before the refresh) takes the category
  when the board is made, so a setting changed mid-game can't misfile it. Reading never creates the
  table (opening the window leaves the SavedVariables alone). Shown: the end overlay and result bar,
  a best-time column in the difficulty list, and the difficulty button's tooltip (best, who, won of
  played), and the **best times panel**: the trophy or `/gsweep scores` (`Window.ShowBests`) opens a
  `GlassPanel` at window level +30 (like the list; opening one closes the other) with every
  difficulty's best, who and when, and won of played, under the current first-click rule (it says
  which). It works whatever the game is doing, refreshes whenever a game starts or ends, and closes
  with the window. When a win doesn't beat the best but reads the same whole second, the overlay
  and the result bar show **tenths** on both (`Layout.FormatTenths`), so it can't look like a tie.
  The list's best column is filled when the list opens, not on every click. `Window._test.SetGame(board,
  category)` keeps no scores unless given a category.
  `API.PlayerFullName()` (Compat, lifted from AltStable) adds the surname. Social leaderboards
  (guild/friends/Battle.net) are milestone 4.
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
- `C:\Projects\References\forever-api-1.60.1.70205.md` — the latest API dump: functions, events,
  **widget methods** and the `_G` walk. Proves a name exists, not that it works.
- `C:\Projects\wow-ui-source` — Blizzard's UI source on the **`forever`** branch (check the branch
  first; other sessions share it). Use it to find atlas names (`SetAtlas("...")`) and templates.
- `..\GlassUnitFrames\docs\GLASS-MATERIAL.md` — the material's recipe and its limits.
- `docs/SOUNDS.md` — Gnomeregan sound kits and music (`PlaySound(kit)`, `PlayMusic(fileID)`;
  never `PlaySoundFile` with a game path).
- `docs/MODELS.md` — rendering creature models, from AltStable's measured pet work
  (`..\AltStable\docs\forever-api-notes.md` "Pets", `..\AltStable\Plugins\Roster\AltStableRoster.lua`).
- `docs/REFERENCES.md` — game-logic references and their licences. `docs/ASSETS.md` — the art plan.
- `docs/ART.md` — **the art direction**: the CurseForge logo (`docs/logo.png`) sets the tone; its
  measured palette, how the placeholders differ from it, and a prompt for each piece of art.
  `Tools/png_to_tga.py` turns a generated PNG into a texture.
- In game: `/api search <name>`.

## Forever facts that matter here

Forever is **Vanilla content on Blizzard's Retail (Mainline) codebase**: Retail API, Lua 5.1.
Advice citing TBC/Classic APIs is usually stale.

- `## Interface: 16001` (**`11601` is the transposed-digit bug**); TOC has no `_Forever` suffix.
- **Nothing here is secure or secret**: plain `Button`s, no combat lockdown concerns, no unit
  numbers. Keep it that way — the window must be usable in combat (it's a minigame for queues and
  flight paths). Never parent anything to a protected frame.
- Tiles use `OnMouseDown` / `OnMouseUp`, not `OnClick`, so `RegisterForClicks` doesn't matter and the
  porting guide's "both edges" rule (for *secure* buttons) doesn't apply. **Measured (70170):**
  `OnMouseUp` passes `upInside` as a boolean that agrees with `IsMouseOver()`, and a release goes to
  the tile that got the press even after the cursor left it (see the porting guide's "Mouse input on
  a plain Button"). **The middle button arrives too, and so do two buttons held at once** (left pressed first,
  right second: both `OnMouseDown`s and both `OnMouseUp`s, with `upInside` correct on each), so
  left+right needs no special client support. Unmeasured: right pressed first, and closing the
  window with a button held. `/gsweep input` logs the events and what each action did.
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

- **Pure files are tested directly**, loaded with `newPureEnv()` / `loadPure()` (the harness): every
  global but a few Lua builtins is forbidden, reads and writes. `test_board.lua`, `test_layout.lua`,
  `test_input.lua`.
- **The stub is an allowlist**, modelled on `..\GlassRaidFrames\tests\wow_stubs.lua`:
  - globals are **strict** (reading one the stub doesn't define is an error), so before stubbing one,
    confirm it's in the dump and copy its signature;
  - `RegisterEvent` throws on an event the client lacks (`tests/events-1.60.1.70205.txt`, made from
    the dump by `Tools/make_events_fixture.py`; `test_toc` checks it against the dump);
  - widgets answer **any** method as a recorded no-op, so **`test_methods.lua`** checks every
    `Type:Method` the addon called against the dump's widget methods (skipped, loudly, without the
    dump: set `GNOMESWEEPER_API_DUMP` to another path);
  - the stub models the scale chain (`GetEffectiveScale`), so a position compared in the wrong
    space can fail. A test double whose scale is always 1 can't catch that.
- **`test_effects.lua`** is the celebrations: the burst and the smoke following the game, the face while
  a tile is held (one button, two, a window closing mid-press, a finished game, the real art), and a new
  best's fanfare, cheer and fireworks (on the board, staggered, off by the setting).
- **`test_sounds.lua`** is the sounds and music on the stub's recorded `PlaySound`/`PlayMusic`/
  `StopMusic` and its clock (`WoW.advance` runs `C_Timer`s): every effect, the delayed gnome and its
  cancelling, the music's one check (window, combat, setting, a login in combat), the note button,
  the probe.
- **`test_minimap.lua`** is the minimap button on the library fakes: registration, both clicks, the
  tooltip, the setting and `/gsweep minimap`, a button saved hidden, a damaged table, no libraries.
- **`test_options.lua`** is the settings: `Options.Set` (refused values, next game vs. now, marks
  kept, the same value), the steps of the scale, the gear opening the page and the window stepping
  aside (and back, and its clock paused), the page (registration, templates and the fallback art), and
  the About sub-page.
- **`test_scores.lua`** is personal bests: the model with every global forbidden (categories, ties,
  damaged data), the full name, and in the window: counting, the overlay, the result bar, the list,
  the tooltip, a reload, and the result bar's room for its text on every difficulty.
- **`test_assets.lua`** is the contact sheet: kinds, the survey, a missing path, a throwing check, the
  sheet's cells, the saved results.
- **`test_overlay.lua`** plays games to their end through the stub: the mascot's states, both overlays,
  what they say and show, the button, putting the overlay away, a click not bringing it back.
- **`test_polish.lua`** is the Liquid Glass polish (#30): the rarity colours, the difficulty details,
  the glass controls (sliced or not), the flag, the detonated tile's burst, the footer and its help, looking
  at a finished board and the result bar, the capped HUD, and the scale across every difficulty on four
  screens. **`test_media.lua`** checks every texture in `Media/` is a valid power-of-two 32-bit TGA.
- **`test_grid.lua`** clicks tiles through the stub on hand-built boards (`Window._test.SetGame`):
  the pool, painting, flood, flags, chords, wrong gestures, the end of a game, `/gsweep perf|input`.
- **`test_window.lua`** drives the window through the stub: slash commands, clicks, drags, ticks,
  screen changes. Set `frame._left` / `_top` / `_mouseOver` and `WoW.now` / `WoW.screen` /
  `WoW.mouseDown` to stage the client.
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
