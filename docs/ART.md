# Art direction

![The Gnomesweeper logo](logo.png)

The logo (`docs/logo.png`, the CurseForge logo, 1254×1254) is the reference for everything
we draw. This file says what it tells us, gives its **measured palette**, compares the
game's current placeholders with it, and has a brief and a prompt for each piece of art
still to make (#12 faces, #13 mine and flag, #14 tiles). `docs/ASSETS.md` is the other
half: which WoW art stands in meanwhile. `docs/storyboard.png` is the layout.

## What the logo says

- **Friendly mischief.** The gnome grins, glances sideways, and rests her hands on the
  tiles like she's about to flip one. The mine beside her is big and decorative, not
  frightening. "One wrong click. Full wipe." is a joke she's in on.
- **The cast.** A girl gnome: bright green hair in two big pigtails, freckles, pointed
  ears with silver hoop earrings, big green eyes, brass goggles with large glowing blue
  lenses pushed up on her head, a red jacket collar. A spiked mine: a dark cracked
  gunmetal sphere with brass conical studs and one big glowing orange core. Ice-clear
  glass cube tiles with a bold blue **1**, a bold green **2** and a red pennant flag on a
  dark post.
- **Materials.** Polished brass with rivets; glowing blue glass; clear ice-blue glass;
  dark gunmetal with fine cracks. Everything has a bright rim light and a soft glow.
- **Rendering.** Saturated, high contrast, glossy, thick clean shapes, thick outlines on
  the lettering. A glowing blue glass frame over a deep navy backdrop with a few sparks.
- **Lettering.** Chunky gold letters with a deep-blue outline and a small brass gear under
  the word: the title as a piece of art, not a font.

## The palette (measured from the logo, by colour family)

| Role | Shadow | Mid | Light |
|---|---|---|---|
| Gold lettering | `#f8b34e` | `#fbc560` | `#fddd7e` |
| Brass (mine studs, goggles, gear) | `#a45f16` | `#ea921b` | `#fbd867` |
| Hair green | `#395d10` | `#318b2d` | `#59c139` |
| Orange core and glow | `#f96e00` | `#eb753d` | `#f7a833` |
| Goggle lens cyan | `#019df5` | `#26b2fd` | `#3edafd` |
| Ice tiles | `#81d8fd` | `#8ce6fd` | `#abeafe` |
| Glass frame blue | `#0c64ca` | `#0098ee` | `#40a1fc` |
| Backdrop navy | `#031334` | `#001c4a` | `#0c275a` |
| Red (flag, jacket) | `#a01714` | `#f11b13` | `#d25331` |
| Number **1** blue | `#014fc4` | `#0059d9` | `#0161df` |
| Number **2** green | `#018f22` | `#019441` | `#01c52b` |
| Skin | `#d78b71` | `#fb9d69` | `#f9a07a` |

(Shadow / mid / light are the 15th, 50th and 85th percentile by brightness of the pixels
in that colour family. A prompt can name the "mid" hex; the generator will find the rest.)

## How the game compares today

What the placeholders do differently from the logo, so nobody mistakes the placeholders
for the direction:

| Piece | Now | The logo |
|---|---|---|
| Window glass | the shared GlassUnitFrames material: cool, pale, quiet | a glowing electric-blue frame (`#0098ee`) |
| Tiles | glossy saturated blue (`Tools/make_tiles.py`) | pale ice-blue glass cubes, almost white-cyan (`#8ce6fd`), thick bright bevel |
| Numbers | light blue / green / red on dark revealed tiles | deep saturated blue and green on pale ice |
| Mine | the black lit-fuse bomb icon (`inv_misc_bomb_01`) | a brass-studded sphere with a glowing orange core |
| Flag | the red Horde banner icon | a red pennant on a dark post |
| Face | gnome-head icons | the green-haired gnome, in five expressions |
| Title | plain white and blue text | chunky gold lettering with a gear |
| Gold text (`Skin.COLORS.gold`) | `#ffd100` | `#fbc560`, warmer and softer |

Two cheap, local experiments that need no new art, both for the owner to call:
1. **Ice tiles** in `Tools/make_tiles.py` (pale top `#abeafe`, bottom `#81d8fd`), with the
   numbers switched to the logo's deep blue and green. This is the first thing #14 should try.
2. **A blue rim on this window only**, `win.glass.rim:SetVertexColor` to `#0098ee`. It
   leaves `Glass.lua` alone, since that file belongs to GlassUnitFrames.

## Legibility at game size

The logo reads at 64 px as a circle but loses its detail: the lettering is mush, and the
flag and numbers shrink to specks. So:
- The **title-bar logo, the HUD faces and the AddOns-list icon** should be the **gnome's
  face only**, cropped tight, not the whole logo.
- The **mine and flag** are drawn at 18 units on a tile: a simple silhouette and one bright
  accent (the orange core, the red pennant) beats fine detail.
- A texture is judged **at its game size**, over the real window, not at 1254 px.

## Briefs and prompts

Use the **style block** at the start of every prompt, so the pieces look like one set.
Ask for a **transparent background** and the subject centred with room round it. The
generator is the owner's; these are written to be pasted.

> **Style block.** Stylised fantasy game art in the style of a polished mobile-game icon:
> a cheerful, slightly mischievous gnome world. Thick clean shapes, glossy highlights,
> bright rim light, saturated colours. Polished brass with rivets, glowing blue glass,
> clear ice-blue glass, dark cracked gunmetal. Palette: gold #fbc560, brass #ea921b,
> hair green #318b2d, cyan #26b2fd, ice #8ce6fd, orange core #f96e00, red #f11b13,
> deep navy #001c4a. Transparent background.

### The mascot (#12)

> **The gnome.** A young female gnome with bright green hair in two big pigtails,
> freckles, pointed ears with silver hoop earrings, large green eyes, brass aviator goggles
> with big glowing blue lenses, a red jacket collar.

Reuse that sentence unchanged in every face prompt. Bust crop, square, the face filling
most of the frame (it is shown at 40 units):

| Face | Expression | Used for |
|---|---|---|
| **ready** | a toothy mischievous grin, goggles pushed up on her head | the HUD before the first click; the title-bar logo |
| **playing** | focused, goggles pulled down over her eyes, a small smirk | while a game is on |
| **won** | laughing with delight, eyes closed, a few gold sparkles | after clearing the field |
| **lost** | shocked: eyes huge, mouth a round "O", hair standing on end, soot on her cheeks, one goggle lens cracked | after a wipe |
| **pressed** | surprised "o" mouth, eyebrows up | while a tile is held down (#10) |

Master 256×256. Game texture 64×64, circular.

### The mine and the flag (#13)

> **Mine.** A round spiked naval mine: dark cracked gunmetal sphere, six brass conical studs
> with rivets, one large glowing orange core ring in the centre. Front view, centred,
> simple bold silhouette that stays readable at 24 pixels.
>
> **Exploded mine.** The same mine bursting: the core flaring white-orange, a ring of
> fire and sparks, the studs flying off. Same silhouette and centred.
>
> **Flag.** A glossy red triangular pennant on a short dark gunmetal pole with a small
> round base. Centred, bold, readable at 24 pixels.

Master 128×128. Game texture 32×32 (a tile icon is 18 units).

### The tiles (#14)

> **Covered tile.** A rounded-square tile of clear ice-blue glass with a thick bright
> white-cyan bevel on the top and left, a soft inner glow and faint frost. Seen from above,
> filling the frame with a thin transparent border.
>
> **Revealed tile.** The same rounded square pressed in: dark navy glass, flat, a subtle
> darker inner edge.
>
> **Exploded tile.** The covered tile cracked, glowing red-orange from within.

Master 128×128. Game texture 32×32, replacing `Media/tile_covered|revealed|exploded.tga`
(the hover ring stays generated). The numbers then need to be **darker**: pale ice wants the
logo's deep blue and green, not the light hues that suit the dark tile.

### The title (optional)

> **Lettering.** The word "Gnomesweeper" in chunky rounded gold letters with a deep-blue
> outline and a thick bottom shadow, and a small brass gear centred under it. Transparent
> background, wide.

Master 1024×256, texture 512×128. It would replace the 20-point title text in the window.
Decide whether the game says **GnomeSweeper** (as the logo and the storyboard do) or
**Gnomesweeper** (the TOC and the owner's first spec) before generating it.

### The AddOns-list icon and CurseForge

- **CurseForge** takes `docs/logo.png` as is.
- **The AddOns list** shows a 32-pixel icon, so use the mascot's face rather than the whole
  logo: a rounded 64×64 of the "ready" face, set with
  `## IconTexture: Interface\AddOns\Gnomesweeper\Media\<name>`. **A custom texture path there
  is unmeasured on Forever**; the smiley bomb works by file ID, so keep that until the path
  has been tried (a client restart shows it).

## From a generated image to the game

Masters are PNG; the game loads TGA. Keep masters in `Media/Source/` (ignored by git, like
every PNG under `Media/`), then:

```
python Tools/png_to_tga.py Media/Source/face_ready.png face_ready --size 64 --circle
python Tools/png_to_tga.py Media/Source/mine.png mine --size 32 --trim
python Tools/png_to_tga.py Media/Source/icon.png icon --size 64 --round 0.2
python Tools/png_to_tga.py Media/Source/mine.png mine --size 32 --trim --out %TEMP%\look --preview mine.png
```

The last form writes elsewhere and a magnified preview over a checker, to judge it before it
goes in `Media/`. The tool resizes on premultiplied alpha (no dark halo on a transparent
edge). `tests/test_media.lua` then checks every texture in `Media/` is a valid power-of-two
32-bit TGA, so a bad conversion fails the suite.

For each asset record in `Media/README.md`: the file, what it is for, the prompt, the
master's name, and the command. Then point `Skin.TEXTURES` at it, and the placeholder is
gone; nothing else changes.
