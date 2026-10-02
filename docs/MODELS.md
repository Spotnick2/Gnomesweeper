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
  `DressUpModel:SetUnit("player")`, perfect, so a gnome player can be their own face.
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
| Gnome | the player | `SetUnit("player")` | — | Perfect when the player is a gnome; fall back to an NPC otherwise. |

## Where models go, and where they don't

- **Yes:** the reset face (1 scene), the loss explosion over the clicked tile (1 scene, a one-shot),
  maybe the win celebration (1 scene).
- **No:** a model per tile. Expert has 480 tiles and 99 mines; tiles keep 2D icons
  (`docs/ASSETS.md`). On a loss, the *clicked* mine gets the model, the rest stay icons.
- Animations are unmeasured: which `SetAnimation` IDs each model has (stand, cheer, death,
  "spell" for a bomb's detonation, emote talk for the face) is the probe's job. Don't hardcode IDs
  from Retail lists without measuring.
- **Everything degrades to the 2D art** in `docs/ASSETS.md`: no `ModelScene`, a display that
  doesn't load (no box within the poll window), or a setting to turn models off.

## The probe

`/gsweep models` (a dev command, in the addon or as `Tools/GnomesweeperProbe`):

1. For each candidate display, report whether a box arrives and how long it takes, the box itself,
   and whether it's textured (a screenshot, judged by eye).
2. Step through animation IDs 0..N on one actor with the current ID printed, so the owner can call
   out "that's the cheer", "that's the explosion".
3. Frame time with the face scene and the explosion scene on, over an Expert board.

Record results here (the build, what rendered, the animation IDs), and the addon-agnostic ones
in `C:\Projects\References\PORTING-TBC-TO-FOREVER.md`.
