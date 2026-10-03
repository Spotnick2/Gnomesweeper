# Gnomesweeper art prompts

Generated with the built-in image generation tool, 2026-10-03. Each call requested a transparent background. Selected full-resolution results and the user reference images are preserved locally under `Media/Source/` (gitignored). These prompts record the actual calls, including the two final corrections.

Reference roles: `docs/logo.png` supplies palette, goggles, materials and portrait framing; `character-reference-front.png` supplies the green-haired gnome's identity; `style-reference-gnome.png` and `style-reference-rumble.png` supply sculpted mobile-game rendering. Additional character screenshots are retained as supporting references. Expression variants use the selected playing portrait plus the logo. Object variants use their matching base asset.

## face-playing

```text
Stylised fantasy game art in the style of a polished mobile-game icon: a cheerful, slightly mischievous gnome world. Thick clean shapes, glossy highlights, bright rim light, saturated colours. Polished brass with rivets, glowing blue glass, clear ice-blue glass, dark cracked gunmetal. Palette: gold #fbc560, brass #ea921b, hair green #318b2d, cyan #26b2fd, ice #8ce6fd, orange core #f96e00, red #f11b13, deep navy #001c4a. Transparent background.
Additional art direction from the user: Warcraft Rumble-inspired chunky sculpted toy-like fantasy shapes, broad graphic planes and painterly shading, stylised bold proportions and lively expressive faces. Sculpted hair locks, warm painted-metal highlights and cool rim light. Avoid glossy doll realism or fine individual hair strands. The user's green-haired in-game gnome is the character identity; the pink-haired Rumble gnome is a rendering/style reference only, never copy its pink hair or its outfit.
Use case: stylized-concept. Asset: face_playing, one square isolated portrait, to be reduced to 256x256 master and 64x64 game icon.
A young female gnome with bright green hair in two big pigtails, freckles, pointed ears with silver hoop earrings, large green eyes, brass aviator goggles with big glowing blue lenses, a red jacket collar.
Reference roles: 1 logo = colors, goggles and close-up framing; 2 actual green-haired gnome = facial identity and earrings; 3 pink-haired gnome and 4 Rumble poster = chunky expressive sculpted/painterly rendering, not subjects or text to reproduce. Tight square head portrait only, same tilted head pose as logo. Match normalized framing from logo crop (370,60)-(910,600) in its 1254 square: goggles at upper edge, eyes around 62% down the square, nose around 73%, chin near 96%, outer pigtails cropped at sides. Main face must remain large at 40px; small sliver of red jacket at bottom. Keep the screenshot's stocky gnome nose, short rounded jaw, brown expressive brows, pointed ears with silver hoops. Expression focused/worried with a small closed-mouth smirk, brass goggles pulled DOWN over the eyes, cyan glass with green eyes still partly visible. Broad readable hair locks, expressive sculpted miniature look, NOT a realistic glossy doll. True transparent background, no white or black background, no frame, no UI ring, no lettering, no hands, no scenery, no extra props.
```

## face-won

```text
Stylised fantasy game art in the style of a polished mobile-game icon: a cheerful, slightly mischievous gnome world. Thick clean shapes, glossy highlights, bright rim light, saturated colours. Polished brass with rivets, glowing blue glass, clear ice-blue glass, dark cracked gunmetal. Palette: gold #fbc560, brass #ea921b, hair green #318b2d, cyan #26b2fd, ice #8ce6fd, orange core #f96e00, red #f11b13, deep navy #001c4a. Transparent background.
Additional art direction from the user: Warcraft Rumble-inspired chunky sculpted toy-like fantasy shapes, broad graphic planes and painterly shading, stylised bold proportions and lively expressive faces. Sculpted hair locks, warm painted-metal highlights and cool rim light. Avoid glossy doll realism or fine individual hair strands. The user's green-haired in-game gnome is the character identity; the pink-haired Rumble gnome is a rendering/style reference only, never copy its pink hair or its outfit.
A young female gnome with bright green hair in two big pigtails, freckles, pointed ears with silver hoop earrings, large green eyes, brass aviator goggles with big glowing blue lenses, a red jacket collar.
Use case: identity-preserve. Edit target image 1 is the approved focused portrait; image 2 is the original logo supporting reference for goggles worn on forehead. Produce ONE square transparent portrait asset face_won. Change only expression and goggle position as specified; preserve rendering, character identity, composition, background transparency, head size and position. Do not zoom out to fit all hair; maintain the tight portrait crop. No framing ring, writing, logo, scene, hands or new props.
Victorious: laughing with delight, eyes gently CLOSED in joy, big open happy laugh, rosy cheeks, three or four small gold sparkles near the hair. Goggles pushed UP on her forehead (as in the logo). Preserve the head tilt, jaw position, silhouette, hair ties, cropped pigtails, earrings and red collar from the first image. Expression must be clearly legible at 40px.
```

## face-lost

```text
Stylised fantasy game art in the style of a polished mobile-game icon: a cheerful, slightly mischievous gnome world. Thick clean shapes, glossy highlights, bright rim light, saturated colours. Polished brass with rivets, glowing blue glass, clear ice-blue glass, dark cracked gunmetal. Palette: gold #fbc560, brass #ea921b, hair green #318b2d, cyan #26b2fd, ice #8ce6fd, orange core #f96e00, red #f11b13, deep navy #001c4a. Transparent background.
Additional art direction from the user: Warcraft Rumble-inspired chunky sculpted toy-like fantasy shapes, broad graphic planes and painterly shading, stylised bold proportions and lively expressive faces. Sculpted hair locks, warm painted-metal highlights and cool rim light. Avoid glossy doll realism or fine individual hair strands. The user's green-haired in-game gnome is the character identity; the pink-haired Rumble gnome is a rendering/style reference only, never copy its pink hair or its outfit.
A young female gnome with bright green hair in two big pigtails, freckles, pointed ears with silver hoop earrings, large green eyes, brass aviator goggles with big glowing blue lenses, a red jacket collar.
Use case: identity-preserve. Edit target image 1 is the approved focused portrait; image 2 is the original logo supporting reference for goggles worn on forehead. Produce ONE square transparent portrait asset face_lost. Change only expression and goggle position as specified; preserve rendering, character identity, composition, background transparency, head size and position. Do not zoom out to fit all hair; maintain the tight portrait crop. No framing ring, writing, logo, scene, hands or new props.
Comic soot-covered defeat after a mine exploded: eyes huge, mouth a large round O, soot smudges on both cheeks and nose, one cyan goggle lens CRACKED, goggles pushed UP on forehead as in logo. Hair tips slightly frazzled and standing on end, preserving overall pigtail positions and silhouette. No injury, blood or tears; humorous surprised aftermath. Preserve head tilt, jaw position, earrings, face scale and red collar from first image.
```

## face-pressed

```text
Stylised fantasy game art in the style of a polished mobile-game icon: a cheerful, slightly mischievous gnome world. Thick clean shapes, glossy highlights, bright rim light, saturated colours. Polished brass with rivets, glowing blue glass, clear ice-blue glass, dark cracked gunmetal. Palette: gold #fbc560, brass #ea921b, hair green #318b2d, cyan #26b2fd, ice #8ce6fd, orange core #f96e00, red #f11b13, deep navy #001c4a. Transparent background.
Additional art direction from the user: Warcraft Rumble-inspired chunky sculpted toy-like fantasy shapes, broad graphic planes and painterly shading, stylised bold proportions and lively expressive faces. Sculpted hair locks, warm painted-metal highlights and cool rim light. Avoid glossy doll realism or fine individual hair strands. The user's green-haired in-game gnome is the character identity; the pink-haired Rumble gnome is a rendering/style reference only, never copy its pink hair or its outfit.
A young female gnome with bright green hair in two big pigtails, freckles, pointed ears with silver hoop earrings, large green eyes, brass aviator goggles with big glowing blue lenses, a red jacket collar.
Use case: identity-preserve. Edit target image 1 is the approved focused portrait; image 2 is the original logo supporting reference for goggles worn on forehead. Produce ONE square transparent portrait asset face_pressed. Change only expression and goggle position as specified; preserve rendering, character identity, composition, background transparency, head size and position. Do not zoom out to fit all hair; maintain the tight portrait crop. No framing ring, writing, logo, scene, hands or new props.
Surprised while a tile is held: small round o mouth, raised eyebrows, wide alert green eyes. CLEAN cheeks with freckles, no soot, no cracks, no sparkles. Goggles pushed UP on forehead, as in logo. Preserve exactly the same head tilt, jaw position, cropped pigtails, hair ties, ears, earrings, face scale and red collar from first image.
```

## mine

```text
Stylised fantasy game art in the style of a polished mobile-game icon: a cheerful, slightly mischievous gnome world. Thick clean shapes, glossy highlights, bright rim light, saturated colours. Polished brass with rivets, glowing blue glass, clear ice-blue glass, dark cracked gunmetal. Palette: gold #fbc560, brass #ea921b, hair green #318b2d, cyan #26b2fd, ice #8ce6fd, orange core #f96e00, red #f11b13, deep navy #001c4a. Transparent background.
Rendering: Warcraft Rumble-inspired chunky sculpted toy-like forms, broad painted planes and bold readable silhouettes. Match the supplied logo's materials and palette. Reference images are style references only; create only the requested isolated asset.
Use case: stylized-concept. Create one square game icon: a round spiked naval mine, dark cracked gunmetal sphere, exactly six brass conical studs with rivet collars, one large glowing orange core ring in the centre. Front view, centred, simple bold silhouette readable at 24 pixels. Whole object visible within 8 percent transparent margin. No ground, scene, text, badge or character. Intended master 128x128.
```

## mine-exploded

```text
Stylised fantasy game art in the style of a polished mobile-game icon: a cheerful, slightly mischievous gnome world. Thick clean shapes, glossy highlights, bright rim light, saturated colours. Polished brass with rivets, glowing blue glass, clear ice-blue glass, dark cracked gunmetal. Palette: gold #fbc560, brass #ea921b, hair green #318b2d, cyan #26b2fd, ice #8ce6fd, orange core #f96e00, red #f11b13, deep navy #001c4a. Transparent background.
Rendering: Warcraft Rumble-inspired chunky sculpted toy-like forms, broad painted planes and bold readable silhouettes. Match the supplied logo's materials and palette. Reference images are style references only; create only the requested isolated asset.
Use case: precise-object-edit. Edit this mine into its exploding state. Keep the same centered gunmetal sphere, six brass stud positions, front view and square framing. Core flares white-orange, a compact ring of stylized orange fire and sparks around it, the six brass studs detaching just slightly outward. Still recognizable as same round mine with strong dark outer shell; keep explosion compact and whole inside canvas. Transparent background, no ground, text, scene or character. Master128x128 and readable at24px.
```

## flag

```text
Stylised fantasy game art in the style of a polished mobile-game icon: a cheerful, slightly mischievous gnome world. Thick clean shapes, glossy highlights, bright rim light, saturated colours. Polished brass with rivets, glowing blue glass, clear ice-blue glass, dark cracked gunmetal. Palette: gold #fbc560, brass #ea921b, hair green #318b2d, cyan #26b2fd, ice #8ce6fd, orange core #f96e00, red #f11b13, deep navy #001c4a. Transparent background.
Rendering: Warcraft Rumble-inspired chunky sculpted toy-like forms, broad painted planes and bold readable silhouettes. Match the supplied logo's materials and palette. Reference images are style references only; create only the requested isolated asset.
Use case: stylized-concept. One isolated game icon: a glossy red triangular pennant on a short dark gunmetal pole with a small round base. Front view with slight fabric wave, centered bold simple silhouette readable at 24 pixels. Vivid red pennant dominates. Tiny brass fasteners. Square canvas with whole object and 8 percent transparent margin. No scene, text, badge, glow halo or character. Intended master128x128.
```

## tile-covered

```text
Stylised fantasy game art in the style of a polished mobile-game icon: a cheerful, slightly mischievous gnome world. Thick clean shapes, glossy highlights, bright rim light, saturated colours. Polished brass with rivets, glowing blue glass, clear ice-blue glass, dark cracked gunmetal. Palette: gold #fbc560, brass #ea921b, hair green #318b2d, cyan #26b2fd, ice #8ce6fd, orange core #f96e00, red #f11b13, deep navy #001c4a. Transparent background.
Rendering: Warcraft Rumble-inspired chunky sculpted toy-like forms, broad painted planes and bold readable silhouettes. Match the supplied logo's materials and palette. Reference images are style references only; create only the requested isolated asset.
Use case: stylized-concept. One single rounded-square game tile, orthographic directly top-down view with all four sides parallel to canvas edges. Clear ice-blue glass, thick bright white-cyan bevel on top and left, soft inner glow, faint frost restrained at edges. Calm uncluttered pale blue square centre where a number will later go. Fill square canvas leaving a thin uniform 4 percent transparent border. No number, symbol, text, flag, bomb, perspective, visible side faces, cube, extra tile or scene. Master128x128, must be readable when shrunk to32x32.
```

## tile-revealed

### Initial generation

```text
Stylised fantasy game art in the style of a polished mobile-game icon: a cheerful, slightly mischievous gnome world. Thick clean shapes, glossy highlights, bright rim light, saturated colours. Polished brass with rivets, glowing blue glass, clear ice-blue glass, dark cracked gunmetal. Palette: gold #fbc560, brass #ea921b, hair green #318b2d, cyan #26b2fd, ice #8ce6fd, orange core #f96e00, red #f11b13, deep navy #001c4a. Transparent background.
Rendering: Warcraft Rumble-inspired chunky sculpted toy-like forms, broad painted planes and bold readable silhouettes. Match the supplied logo's materials and palette. Reference images are style references only; create only the requested isolated asset.
Use case: precise-object-edit. Change the covered glass tile into its revealed, pressed-in state. Same exact square silhouette, corner radii, canvas, alignment, transparent margin and top-down camera. Interior becomes flat deep navy #001c4a glass, with a subtle darker inset inner edge. Greatly reduce the bright bevel and frost; the centre must be calm, dark, unobstructed and almost uniform so bright numbers will remain readable. No text, numbers, symbols or objects. Transparent PNG game texture, intended master128x128. Preserve all framing and scale from supplied covered tile.
```

### Revision 1

```text
Stylised fantasy game art in the style of a polished mobile-game icon: a cheerful, slightly mischievous gnome world. Thick clean shapes, glossy highlights, bright rim light, saturated colours. Polished brass with rivets, glowing blue glass, clear ice-blue glass, dark cracked gunmetal. Palette: gold #fbc560, brass #ea921b, hair green #318b2d, cyan #26b2fd, ice #8ce6fd, orange core #f96e00, red #f11b13, deep navy #001c4a. Transparent background.
Rendering: Warcraft Rumble-inspired chunky sculpted toy-like forms, broad painted planes and bold readable silhouettes. Match the supplied logo's materials and palette. Reference images are style references only; create only the requested isolated asset.
Use case: precise-object-edit. Modify only the supplied revealed tile's outer rim. Replace the entire luminous cyan thick outer rim with flat dark navy blue glass (#001c4a), a thin muted blue-grey edge and subtle dark inner shadow. No bright cyan or white highlights anywhere, no glows, no raised bevel. The entire tile should read as a flat recessed dark navy square with a quiet narrow border. Keep its exact outer square silhouette, rounded corner geometry, size, location, transparency outside the square and existing flat navy centre. No numbers, lettering, symbols or extra objects. This is the unlit/revealed state of a game board tile.
```

## tile-exploded

```text
Stylised fantasy game art in the style of a polished mobile-game icon: a cheerful, slightly mischievous gnome world. Thick clean shapes, glossy highlights, bright rim light, saturated colours. Polished brass with rivets, glowing blue glass, clear ice-blue glass, dark cracked gunmetal. Palette: gold #fbc560, brass #ea921b, hair green #318b2d, cyan #26b2fd, ice #8ce6fd, orange core #f96e00, red #f11b13, deep navy #001c4a. Transparent background.
Rendering: Warcraft Rumble-inspired chunky sculpted toy-like forms, broad painted planes and bold readable silhouettes. Match the supplied logo's materials and palette. Reference images are style references only; create only the requested isolated asset.
Use case: precise-object-edit. Change the covered glass tile into its exploded state. Same exact square silhouette, corner radii, canvas, alignment, transparent margin and top-down camera. Glass is cracked and glowing red-orange from within, with a few thick readable branching fractures and fiery orange highlights across its existing bevel. Still a single tile, not an explosion cloud. No text, numbers, mine, flag or flying debris outside the tile. Transparent PNG game texture, intended master128x128. Preserve all framing and scale from supplied covered tile.
```

## title

### Initial generation

```text
Stylised fantasy game art in the style of a polished mobile-game icon: a cheerful, slightly mischievous gnome world. Thick clean shapes, glossy highlights, bright rim light, saturated colours. Polished brass with rivets, glowing blue glass, clear ice-blue glass, dark cracked gunmetal. Palette: gold #fbc560, brass #ea921b, hair green #318b2d, cyan #26b2fd, ice #8ce6fd, orange core #f96e00, red #f11b13, deep navy #001c4a. Transparent background.
Rendering: Warcraft Rumble-inspired chunky sculpted toy-like forms, broad painted planes and bold readable silhouettes. Match the supplied logo's materials and palette. Reference images are style references only; create only the requested isolated asset.
Use case: logo-brand. Create only the word "Gnomesweeper" spelled exactly G-n-o-m-e-s-w-e-e-p-e-r, capital G and all other letters lowercase. Chunky rounded gold lettering with a deep navy-blue outline and thick bottom shadow. One small brass gear centred directly beneath the word. Wide horizontal single line, composition aspect ratio 4:1, intended master1024x256. Keep the gear small so letters fill nearly all width. No other text, frame, character, scenery or extra objects. Genuine transparent background including outside letter outlines.
```

### Revision 1

```text
Stylised fantasy game art in the style of a polished mobile-game icon: a cheerful, slightly mischievous gnome world. Thick clean shapes, glossy highlights, bright rim light, saturated colours. Polished brass with rivets, glowing blue glass, clear ice-blue glass, dark cracked gunmetal. Palette: gold #fbc560, brass #ea921b, hair green #318b2d, cyan #26b2fd, ice #8ce6fd, orange core #f96e00, red #f11b13, deep navy #001c4a. Transparent background.
Rendering: Warcraft Rumble-inspired chunky sculpted toy-like forms, broad painted planes and bold readable silhouettes. Match the supplied logo's materials and palette. Reference images are style references only; create only the requested isolated asset.
Use case: text-localization. Edit the supplied title artwork. Change the capital S in GnomeSweeper to a lowercase s, so the exact text is "Gnomesweeper", only G is uppercase. Match the height of s to lowercase n, o, m and e. Preserve gold beveled chunky lettering, navy outline, small brass gear centered below and transparent background. Make the complete composition wide and shallow to fit a 4:1 canvas; do not crop letters or stretch them. No additional text.
```

## laurels

```text
Stylised fantasy game art in the style of a polished mobile-game icon: a cheerful, slightly mischievous gnome world. Thick clean shapes, glossy highlights, bright rim light, saturated colours. Polished brass with rivets, glowing blue glass, clear ice-blue glass, dark cracked gunmetal. Palette: gold #fbc560, brass #ea921b, hair green #318b2d, cyan #26b2fd, ice #8ce6fd, orange core #f96e00, red #f11b13, deep navy #001c4a. Transparent background.
Rendering: Warcraft Rumble-inspired chunky sculpted toy-like forms, broad painted planes and bold readable silhouettes. Match the supplied logo's materials and palette. Reference images are style references only; create only the requested isolated asset.
Use case: stylized-concept. Create two polished gold laurel branches for a fantasy game personal-best award. Wide low composition aspect ratio4:1, intended master512x128. Branches begin near bottom centre, sweep horizontally outward and curve upward at left and right ends; open at the top, large completely empty transparent middle reserved for a line of text. Broad gold leaves, bright upper edges, warm brass shadows. No text, ribbon, medal, stars, circular wreath, character or backdrop. Whole branches visible with thin transparent margin.
```
