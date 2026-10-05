# 3D models

Live WoW models in the window: a real gnome as the reset face, real bombs exploding. This builds
on what AltStable measured while rendering hunter and warlock pets (#75 there).

## What is known (measured in AltStable, not here)

From `..\AltStable\docs\forever-api-notes.md` ("Pets", "Model widgets", "A model frame
auto-frames") and the porting guide's "Rendering a character who is not logged in":

- **A creature display ID renders fully textured**, since its texture is baked into the model
  (1.60.1.70124). This covers bombs, bots and NPC gnomes.
- **A player-race display does not**: `SetDisplayInfo(id)` on a player race gives correct geometry
  and a **white, untextured body**. The one exception is the live character:
  `DressUpModel:SetUnit("player")`, perfect, so a gnome player can be their own face. That's a
  **`DressUpModel`** method; in a `ModelScene`, `actor:SetModelByUnit("player")` is declared in
  the 70170 dump but **unmeasured**.
- `SetCreature(npcID)` picks a **random skin** of the creature. Use display IDs, not NPC IDs.
- `SetModelByCreatureDisplayID(id, true)` composites the **active player**: never pass `true`.
- **The framing recipe that works** (`..\AltStable\Plugins\Roster\AltStableRoster.lua`,
  `PetFrame` / `ReadBox` / `PlacePet` / `MeasurePet`):
  - a plain `ModelScene` + `CreateActor()` (preset scenes lack the actors you'd expect);
  - camera: `SetCameraFieldOfView`, near 0.1 / far 100 clip, `SetCameraPosition(dist, 0, 0)`,
    `SetCameraOrientationByYawPitchRoll(math.pi, 0, 0)`;
  - actor: `SetUseCenterForOrigin(true, true, true)`, `SetPosition(0, 0, 0)`, `SetYaw` to turn;
  - **poll `GetActiveBoundingBox()`** every 0.1 s (up to ~3 s) until the model has streamed in, and
    use a token to drop late answers;
  - on Forever it returns **six numbers** (minX, minY, minZ, maxX, maxY, maxZ), not Retail's two
    vectors. Read both shapes;
  - the FOV spans the frame's **larger** side; scale the actor by `viewH / (box.h * margin)`;
  - **`SetParticleOverrideScale(0)`**: particles on a frozen pose ran outside the frame and
    swelled the bounding box. Re-test this per model, since bombs may *want* their fuse sparks;
  - the idle animation is kept: "the sweet spot", per the owner.
- A model frame **auto-frames**, so a render tells you nothing about size. Boxes aren't in world
  scale.

## Candidates (display IDs from Wowhead, 2026-10-02; none probed yet)

| Role | NPC | Display | Content | Notes |
|---|---|---|---|---|
| **Bomb (mine, explosion)** | Walking Bomb (7915) | **6977** | Vanilla, Gnomeregan | **The same model as Mimiron's Bomb Bot** (Ulduar 33836). Vanilla, so Forever has it. |
| Bomb | Goblin Land Mine (7527) | **6271** | Vanilla | The same model as Mimiron's **Proximity Mine** (34362). A literal land mine. |
| Bomb | XE-321 Boombot (33346, XT-002) | 19139 | Ulduar | Not vanilla: probe whether this client has it. |
| Bomb | Explosive Sheep (2675) | 3886 | Vanilla engineering | A gnomish-engineering joke for the win or loss screen. |
| **Gnome face** | High Tinker Mekkatorque (7937) | 143349 | Vanilla NPC, modern model | The king of gnomes. Probe the texture: humanoid NPC displays may or may not be baked. |
| Gnome | Namdo Bizzfizzle (2683) | 4953 | Vanilla engineering trainer | |
| Gnome | Holdout Technician (6407) | 6628 | Vanilla, Gnomeregan | |
| Gnome (loss?) | Leprous Defender / Machinesmith (6223 / 6224) | 6982 / 6936 | Vanilla, Gnomeregan | Leper gnomes: a darkly funny "full wipe" face. |
| Gnome | the player | `DressUpModel:SetUnit("player")` (measured) or `actor:SetModelByUnit("player")` (unmeasured) | — | Perfect when the player is a gnome; fall back to an NPC otherwise. |

## Theme: Gnomeregan (owner, 2026-10-02)

The models come from **Gnomeregan**: a city overrun by its own machines and radiation, and a
final boss (Mekgineer Thermaplugg) who sends **Walking Bombs** at you. That's the "one wrong click"
story, told in vanilla content. The window keeps the storyboard's blue glass look; Gnomeregan
supplies the cast. All of these are vanilla, Wowhead Forever pages, 2026-10-02, not probed:

| Role | NPC | Display | Why |
|---|---|---|---|
| **The wipe** (detonates on the clicked mine) | Walking Bomb (7915) | **6977** | Thermaplugg's bombs; the owner's first pick |
| **The alarm** (loss: red glow, sirens; or a "danger" pulse) | Alarm-a-bomb 2600 (7897) | **6888** | Owner's pick. Shares its model with the Mobile Alert System (7849). |
| **The face** | Blastmaster Emi Shortfuse (7998) | **7138** | Gnomeregan's demolitions gnome (the bomb escort) |
| Face, the mascot? | Tally Berryfizz (5177) | **3124** | Tinker Town's alchemist (Ironforge); the owner: "might match our mascot better". Wowhead, 2026-10-04 |
| Face, alternatives | Kernobee (7850) / Holdout Technician (6407) / Leprous Assistant (7603) | 7132 / 6628 / 6967 | Escort gnome, survivor, leper gnome (for the wipe face?) |
| **The villain** (loss screen: "Thermaplugg wins") | Mekgineer Thermaplugg (7800) | **6980** | The boss behind the bombs |
| Bots (difficulty mascots? win parade?) | Mechanized Sentry / Guardian (6233 / 6234) | 6978 / 6979 | |
| | Arcane Nullifier X-21 (6232) | 6889 | |
| | Mechano-Flamewalker (6226) | 6890 | |
| | Electrocutioner 6000 (6235) | 6915 | |
| | Crowd Pummeler 9-60 (6229) | 6774 | |
| Radiation (loss smoke, "fallout")? | Viscous Fallout (7079) / Irradiated Horror (6220) | 5497 / 4907 | |

Possible mapping, once the probe shows what animates well: Beginner → Mechanized Sentry,
Intermediate → Electrocutioner 6000, Expert → Crowd Pummeler 9-60 (or Thermaplugg) as the
dropdown's mascot. That's an idea, not a decision.

## Where models go, and where they don't

- **Yes, in this order:** the loss explosion over the clicked tile (1 scene, a one-shot), then the
  reset face **only if** the probe shows a readable head crop and distinguishable expressions at
  HUD size (~40 px; AltStable only fitted whole bodies), and maybe a win celebration. The face
  stays 2D until then.
- **Layering:** scenes are mouse-disabled with explicit frame levels against the board and the
  glass rim. Glass masks **don't clip 3D models**, and particles can escape the frame, so test the
  bomb with particles over neighbouring tiles. Cancel pending box polls and animation callbacks on
  reset and hide.
- **No:** a model per tile. Expert has 480 tiles and 99 mines; tiles keep 2D icons
  (`docs/ASSETS.md`). On a loss, the *clicked* mine gets the model, the rest stay icons.
- Animations are unmeasured: which `SetAnimation` IDs each model has (stand, cheer, death,
  "spell" for a bomb's detonation, emote talk for the face) is the probe's job. Don't hardcode IDs
  from Retail lists without measuring.
- **Everything degrades to the 2D art** in `docs/ASSETS.md`: no `ModelScene`, a display that
  doesn't load (no box within the poll window), or a setting to turn models off.

## The probe

`ModelProbe.lua` (#20), in the addon as a measuring command:

1. **`/gsweep models`**: a sheet of every candidate above (23 displays and the player both ways),
   each in its own scene. A cell says how long its box took ("0.3s  h 1.20") or "no box in 3s";
   textured or white is judged by eye.
2. **Click a model**: the viewer shows its whole body, its head at the face button's size (44) and
   a bigger head. `<` `>` walk a short named list (`Probe.ANIMS`: stand, talk, cheer, laugh, death, spell...;
   WoW's numbers, stable since vanilla; stepping every ID was too many to judge); **Particles** turns its effects on or off.
3. **`/gsweep models perf`**, with the board open (`/gsweep expert` is the worst case): the frame
   rate for 5 s as it is, then 5 s with Tally Berryfizz's head on the face and a Walking Bomb (its
   particles on) over the tiles.

Everything goes to `GnomesweeperDB.modelProbe`; a `/reload` writes it to
`WTF\Account\<acct>\SavedVariables\Gnomesweeper.lua`, to be read from disk. Record the results here
(the build, what rendered, textured or not, the animation IDs, the frame cost), and the
addon-agnostic ones in `C:\Projects\References\PORTING-TBC-TO-FOREVER.md`.

## Results (1.60.1.70205, 2026-10-04, `/gsweep models`)

**Every vanilla candidate renders, fully textured, humanoid NPC gnomes included** (the open
question: their textures are baked, unlike a player race's display). Seen by the owner in the
sheet, boxes read from `GnomesweeperDB.modelProbe`.

| Candidate | Display | Box arrived | Height (box) | Notes |
|---|---|---|---|---|
| Walking Bomb | 6977 | 0.1 s | 3.91 | textured |
| Goblin Land Mine | 6271 | 0.1 s | 0.86 | textured |
| XE-321 Boombot | 19139 | — | — | **absent**: `SetModelByCreatureDisplayID` returned `false` at once |
| Explosive Sheep | 3886 | 0.1 s | 1.09 | textured |
| Alarm-a-bomb 2600 | 6888 | 0.1 s | 5.59 | textured; its box is a 5.6 cube (the red glow sphere) |
| Emi Shortfuse | 7138 | 0.0 s | 1.34 | textured |
| **Tally Berryfizz** | **3124** | 0.0 s | 1.34 | textured; **the mascot's model** (owner: "that is our model": green hair, green eyes). Emi's body (same box): the crop fits her face as tuned |
| Kernobee | 7132 | 0.2 s | 1.39 | textured, but it reads as a goblin (green, big ears): the display ID may be wrong |
| Holdout Technician, Namdo Bizzfizzle, Mekkatorque, Leprous Assistant, Leprous Machinesmith | 6628, 4953, 143349, 6967, 6936 | 0.0 s | 1.53 | textured; all five share one box (0.84 × 0.92 × 1.53) |
| Leprous Defender | 6982 | 0.0 s | 1.34 | textured |
| Thermaplugg | 6980 | 0.1 s | 4.93 | textured |
| Mechanized Sentry / Guardian | 6978 / 6979 | 0.2 s | 2.49 | textured; the same model |
| Arcane Nullifier X-21, Crowd Pummeler 9-60 | 6889, 6774 | 0.2 s | 3.38 | textured |
| Mechano-Flamewalker, Electrocutioner 6000 | 6890, 6915 | 0.2 s | 2.64 | textured |
| Viscous Fallout, Irradiated Horror | 5497, 4907 | 0.2 s | 2.68 | textured; the same model |
| The player, `actor:SetModelByUnit("player")` | — | 0.0 s | 2.35 | **works, textured** (was unmeasured) |
| The player, `DressUpModel:SetUnit("player")` | — | — | — | works, textured (as AltStable measured) |

- **An absent display is known at once**: `SetModelByCreatureDisplayID` returns `false`, no need
  to wait for a box. A present one answered within 0.22 s (0 s when already cached).
- **A box isn't the visible size**: the Walking Bomb (3.91) and the Alarm-a-bomb (a 5.6 cube) carry
  room for their effects; fitted from the box they come out smaller than their frame.
- **Frame cost** (`/gsweep models perf`, an Expert board, the models sheet closed): 92.8 fps
  (10.78 ms) without models and 92.8 fps (10.78 ms) with Tally's head on the face and a Walking
  Bomb with particles over the tiles: **no measurable cost** for two scenes. (A first run showed
  +0.3 ms, with the sheet's 25 scenes open in both halves: noise, now excluded.)
- **The head crop** (tuned by the owner on Emi Shortfuse: her face filling the 44-unit square, the
  buns and pigtails cut, the round ring hiding the corners): **35% of the box height, centred 69%
  up**, by raising the camera (the actor stays at the origin). A first guess, the top 40% centred
  80% up, showed only hair and eyes.
- **Animations** (the owner, through the viewer's named list, `Probe.ANIMS`):
  - **Emi Shortfuse, in the head crop**: stand (0), talk (60), talk! (64), talk? (65), cheer (68),
    laugh (70), applaud (80), dance (69), wave (67) and shy (83) keep her face in the crop. **Not
    usable on the face:** cry (77), stun (14) and death (1) / dead (6) play mostly outside it;
    spell cast (32) and spell, area (33) end half outside; ready (25) and attack (16) crouch, so the
    crop sits too high. So the readable expressions are the happy and talking ones: **a loss
    reaction can't come from her head** (a 2D face, or the bomb, carries it).
  - **Walking Bomb**: **death (1) is the explosion**, the wipe's animation; nothing else in the list
    is worth it. Drawn whole (a bomb has no head: the crop doesn't apply), particles on.

## What #21 takes from this

- **The wipe**: Walking Bomb (6977), whole body over the clicked tile, particles on, death (1).
- **The face, if 3D**: **Tally Berryfizz (3124), the mascot's own model**, at the crop above, for
  ready / playing / won (stand, talk, cheer, laugh, applaud). She has Emi's body (the same box),
  so Emi's animation results should hold for her: not measured on Tally herself, check the cheer
  and laugh when #21 uses them. The lost face stays 2D (or a reaction elsewhere): the loss
  animations leave the crop. Whether a 3D face beats the 2D art at 44 units is the owner's call.
- **Any candidate is safe to try**: an absent display says so at once (`false`), a present one
  loads within ~0.2 s, and two scenes cost nothing measurable on Expert.
- **The player's own character** works as a face (`actor:SetModelByUnit("player")`, textured).

## What #21 built first: the end panel (in game, 1.60.1.70205, 2026-10-04)

Over the field, the bomb didn't fit (owner); it went **into the end panel, on its left**, the panel
widened for it and redone after the owner's mockup (gpt-6-astra's concept): title and a line under
it on the right, the main button filled blue. `Models.lua`, `Window.lua`'s `dressEnd`.

- **Wipe**: the Walking Bomb (6977) goes off (death, 1, particles on), then lies in its dead pose
  (6) after 1.5 s. Measured: the **wreckage lies lower than the bomb stood**, below the panel's
  edge; raised 24 units (the camera moves down, the actor stays) it sits inside. Judged right.
- **Win**: Tally (3124). Measured on Tally herself: **Blizzard's cheer (68) plays once** and she
  stands again, and she stays in frame. So a sequence (owner): jump start (37), in the air (38),
  landing (39), cheer (68), again (`Models.CAST.win.steps`; the step lengths are guesses to judge).
- **Size**: the box drawn 104 units tall, standing on the panel's floor (8 units up). 118 over the
  field was right, but stood taller than the panel; 92 fitted the old panel; the mockup's taller
  panel (142) takes 104.
- **The scene must be bigger than the model**: a 96-unit scene sliced the sphere, a 120 one the fuse
  and blast (they reach past the box). 180, centred on the model's column, cuts nothing.
