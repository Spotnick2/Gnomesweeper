# Art plan

**To check every texture on the live client: `/gsweep assets`** (#6). It shows a contact sheet of
everything the skin names, says which client paths the client doesn't have, and saves the results
(`GnomesweeperDB.assetProbe`) for a `/reload` to write to disk. A green square or an empty cell on
the sheet is a texture the client can't draw.

**Measured with it** (owner, 1.60.1.70205, 2026-10-02): **all 19 textures draw**, with no green
square and no empty cell: the 17 files of ours (the face and the logo are one file), the settings
gear (a client path, `GetFileIDFromPath` → `311226`) and the bomb (client id `133709`, judged by
eye). For our own files `GetFileIDFromPath` answered negative ids (`-2411` to `-2436`), one per path:
the client does find addon files by path, under temporary ids. Whether it answers `nil` for a missing
addon file is still unmeasured, so our art stays judged by eye (and by `tests/test_media.lua`).

Live 3D models (the gnome face, the bomb on a wipe) are in [`MODELS.md`](MODELS.md); this file is
the 2D art, which is also every model's fallback.

**Rule: reuse the client's own art first.** Generate only what the client can't supply, and
record every generated file's prompt and conversion in `Media/README.md` (AltStable's
`Media/Scene/PROMPTS.md` pattern). WoW loads **TGA/BLP, never PNG**; PNG masters stay out of git
(see `.gitignore`).

**Every candidate below is UNVERIFIED** unless marked. Icon paths are from memory or from the UI
source; the Forever client may lack some. Verify each in game before relying on it:
`GetFileIDFromPath("Interface\\Icons\\...")` returns nil for a missing file (porting guide,
"Checking a texture exists before you draw it"), and `C_Texture.GetAtlasInfo(name)` returns nil for
a missing atlas. Plan: a `/gsweep assets` probe that checks this whole table and prints the misses.

## Listed for Forever by Wowhead

Searched 2026-10-02 on [wowhead.com/forever/icons/name:bomb](https://www.wowhead.com/forever/icons/name:bomb)
and [name:gnome](https://www.wowhead.com/forever/icons/name:gnome). All of these are tagged
`firstseenpatch: 16001`, so they're in Forever's files. This is still from Wowhead's data, not
measured: #6 confirms them in game. File IDs can be passed straight to `SetTexture`.

| Icon | File ID | Use |
|---|---|---|
| `inv_misc_bomb_04` | 133712 | **Smiley bomb**: the AddOns-list icon (`## IconTexture`). A nod to Minesweeper's smiley. **Measured: renders in the AddOns list** (owner, 2026-10-02). |
| `inv_misc_bomb_01` … `_09` | 133709 … 133717 | Mine candidates (round engineering bombs). Pick the one that reads best at tile size. |
| `inv_misc_blackironbomb` | 463515 | Mine candidate |
| `creatureportrait_g_bomb_02` | 512904 | Mine candidate (a goblin bomb portrait) |
| `inv_eng_bombfire` | 2115301 | Exploded mine overlay candidate |
| `achievement_character_gnome_male` / `_female` | 236446 / 236445 | Gnome face placeholder and title-bar logo |
| `inv_misc_head_gnome_01` / `_02` | 134164 / 134165 | Gnome face placeholder |
| `inv_misc_head_clockworkgnome_01` | 134152 | Face for the loss state? |
| `inv_helm_armor_engineering_b_02_gnome` | 4741993 | Gnomish goggles: a HUD accent |
| `inv_gnometoy` | 4226119 | Gnomish detail |
| `inv_misc_tournaments_symbol_gnome` | 255139 | Gnomeregan crest: a watermark or logo backing |

Other bomb families listed there, if the misc bombs read poorly: `inv_crabbomb_*`,
`inv_111_goldenbomb_*`, `inv_eng_bomb*`, `ability_iyyokuk_bomb_*` (coloured round bombs).

## Measured in game

First in-game look at the window (owner's screenshots, 2026-10-02, build 1.60.1.70170, PR #25).
**Rendered** (no green squares): the logo `achievement_character_gnome_male` (236446), the face
`inv_misc_head_gnome_01` (134164), `Interface\Icons\INV_Misc_PocketWatch_01`,
`Interface\WorldMap\GEAR_64GREY`, `Interface\Buttons\Arrow-Down-Up`, and the
`UIPanelCloseButton` template. **Not what the name suggests:** `Interface\Icons\INV_BannerPVP_02` is
the blue **Alliance** banner. `inv_bannerpvp_01` (132485) is the red one (the Horde crest) and
**renders**: it's the HUD flag now.
Still unmeasured: everything not in this list, and whether `Interface\Icons\...` paths are as safe
as file IDs. #6 does the rest.

## Chosen for the board (#4)

- **Mine:** `inv_misc_bomb_01` (133709), the classic black bomb with a lit fuse; the candidates
  were compared at 18 px and it is the one that stays legible. (The spiked `_02`, the smiley `_04`,
  the dynamite and the red crab bomb were set aside; `inv_eng_bombfire`, 2115301, is a bomb in
  flames for a later "boom".) **Measured to render** (owner's screenshots of games and losses).
- **Flag:** our own red pennant on a dark post (`Media/icon_flag.tga`, `Tools/make_ui.py`), the same on the
  tiles and beside the counter. (The Horde banner `inv_bannerpvp_01` stood in until the UI review
  said a faction crest doesn't say "flagged mine".)
- **Wrong flag:** the flag with a red text "X" over it; **question mark:** a gold text "?". No
  textures, so nothing can come out as a green square.
- **Tiles:** baked textures, `Media/tile_*.tga` (`Media/README.md`), not WoW art.
- **Trophy** (the best times button, #7): ours, `Media/icon_trophy.tga` (`Tools/make_ui.py`), brass
  like the clock. Why not the client's: the button is a 22-unit glass square showing a 14-unit icon,
  the size of the clock and close glyphs beside it, and the client's trophy and achievement art is
  square item icons with a painted frame and background (they turn into a dark tile at 14 units) or
  Retail achievement atlases not measured on Forever. **Unmeasured alternative**, if a client icon is
  wanted: try `Interface\Icons\INV_Misc_Trophy_*` / `Achievement_*` names with `/gsweep assets`
  (`GetFileIDFromPath`) before switching.

## The mascot (#5, #30)

The HUD picture and the title-bar logo are **the logo's gnome**, cut from `docs/logo.png` as
`Media/face_mascot.tga` (see `Media/README.md`). One expression; the game state shows in her
ring (cyan, gold, red) and what is drawn over her (gold sparkles after a win, soot after a
wipe). The real expressions are #12; the requests are in `docs/ART.md`.

Retired: the stock gnome-head icons that stood in first (236446, 134164, 236445, and the bomb
133709 as the loss face). All four were measured to render, but together they were three different
characters and then a bomb, which the UI review rightly called out.

## Element by element

| Element (storyboard) | First choice (client) | Fallback | Generate? |
|---|---|---|---|
| Window body | **`Glass.Apply(host, "large")`** — have it | — | no |
| Covered tile (glossy blue glass) | `Glass.Apply(tile, "small")` tinted blue — but 480 tiles × ~8 layers is heavy; measure. Cheaper: one pre-baked tile texture from `make_textures.py` (rounded, gloss, blue) | flat `SetColorTexture` + `gloss.tga` | **probably** — a single `tile.tga` generated by script, not AI |
| Hovered tile (cyan glow) | `Interface\Buttons\ButtonHilight-Square` (ADD), tinted cyan | `bags-glow-white` atlas | no |
| Revealed cell | dark translucent fill + thin inner line (`SetColorTexture`) | — | no |
| Numbers 1–8 | `Glass.Font` (FRIZQT / ARIALN, outlined), coloured per `Skin.NUMBER_COLORS` | — | no |
| Flag | `Interface\Icons\INV_BannerPVP_02` (red, Horde) / `Flag-1`/`Flag-2` atlases (seen in UI source XML) | `Interface\WorldStateFrame\HordeFlag` | maybe, for a crisp small flag |
| Mine (gnomish bomb) | `inv_misc_bomb_01`…`_09` (Wowhead-listed, above) | `inv_misc_blackironbomb`, `creatureportrait_g_bomb_02` | M3: a round riveted bomb with a red eye |
| Exploded mine | mine icon + red `SetColorTexture` underlay + `Interface\Icons\Spell_Fire_SelfDestruct` | — | M3 |
| Wrong flag | flag + `Interface\Buttons\UI-GroupLoot-Pass-Up` (red X) | `128-redbutton-exit` atlas (in UI source) | no |
| Gnome face (reset button) | `achievement_character_gnome_male`/`_female`, `inv_misc_head_gnome_01`/`_02` (Wowhead-listed, above); or `SetPortraitTexture(tex, "player")` when the player *is* a gnome | — | **yes (M3)**: 4 expressions — ready (goggles up), focused (goggles down), win (beaming), loss (shocked) + "o" pressed |
| Logo (title bar) | same gnome icon, circular-masked (`Interface\CharacterFrame\TempPortraitAlphaMask`) | — | M3, with the face set |
| Flag counter icon | the flag above, small | — | no |
| Timer icon | `Interface\Icons\INV_Misc_PocketWatch_01` | `Interface\TimeManager\ClockBackground` (in UI source) | no |
| Settings gear | `Interface\WorldMap\GEAR_64GREY` (in UI source) | `Interface\Icons\Trade_Engineering` | no |
| Best times (trophy, #7) | ours: `icon_trophy` (see "Chosen for the board") | client trophy/achievement icons, unmeasured | done (script) |
| Close button | `UIPanelCloseButton` template (measured to exist), or atlas `128-redbutton-exit` (in UI source) | — | no |
| Difficulty dropdown | `WowStyle1DropdownTemplate` (measured to exist) / `common-dropdown-*` atlases | `UIDropDownMenuTemplate` | no |
| Win overlay (gold rim, laurels, burst) | `Glass.Apply` + gold rim tint; laurels: `ui-achievement-*` atlases (in UI source: `ui-achievement-glow-shine`) | — | maybe laurels |
| Play again / Try again button | `UIPanelButtonTemplate` re-skinned blue, or a small glass button (GlassPanel `API.Button`) | — | no |
| Loss smoke | `Interface\Cooldown\star4` / spell particle textures, animated alpha | — | no |
| Tavern background (storyboard) | **out of scope** — the window floats over the game world | — | no |

## Sounds

See [`SOUNDS.md`](SOUNDS.md): Gnomeregan sound kits for every moment, and the zone music.
