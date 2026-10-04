"""Export the generated art (docs/ART.md, #12) into game textures.

    python Tools/export_art.py           # from the repository root

Reads the full-resolution PNGs in Media/Source/Generated/ (ignored by git: the
prompts that made them are in Media/ART-PROMPTS.md), sizes them, and writes:
  - Media/<name>.tga for every piece the game uses (ADOPTED below), and the
    Modern theme's tiles under their own names (THEMED: tile_modern_*, #14);
  - Media/Source/GameTextures/<name>.tga for candidates not wired yet (STAGED);
  - Media/Source/<name>.png, the sized masters.
The originals are not in git (66 MB, Media/Source/ is ignored): this runs where
they are. Their prompts are, so they can be made again.
Adapted from the export script Codex wrote with the art (2026-10-03); square
pieces go through Tools/png_to_tga.py, the wide ones (title, laurels) are fitted
without stretching.
"""
from pathlib import Path
import subprocess
import sys

import numpy as np
from PIL import Image, ImageOps

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "Tools"))
import texture_kit  # noqa: E402  (the one TGA writer: no footer, exactly header + pixels)
SOURCE = ROOT / "Media" / "Source"
GENERATED = SOURCE / "Generated"
MEDIA = ROOT / "Media"
STAGED = SOURCE / "GameTextures"

# name -> (master size, texture size, png_to_tga options); None = a wide piece, fitted here.
PIECES = {
    "face_playing":  ((256, 256), 64, ["--circle"]),
    "face_won":      ((256, 256), 64, ["--circle"]),
    "face_lost":     ((256, 256), 64, ["--circle"]),
    "face_pressed":  ((256, 256), 64, ["--circle"]),
    "mine":          ((128, 128), 32, ["--trim"]),
    "mine_exploded": ((128, 128), 32, ["--trim"]),
    "flag":          ((128, 128), 32, ["--trim"]),
    "tile_covered":  ((128, 128), 32, ["--margin", "0"]),
    "tile_revealed": ((128, 128), 32, ["--margin", "0"]),
    "tile_exploded": ((128, 128), 32, ["--margin", "0"]),
    "title":         ((1024, 256), (512, 128), None),
    "laurels":       ((512, 128), (512, 128), None),
}
# In the game (Skin.TEXTURES). The tiles are the Modern theme (THEMED, #14).
# Staged: the mine, the exploded mine and the flag: on the board WoW's bomb and the
# pennant read better (owner, #12), in both themes.
ADOPTED = ["face_playing", "face_won", "face_lost", "face_pressed", "title", "laurels"]
# The Modern theme's tiles (#14, owner): in the game under their own names, so the
# Classic tiles (Tools/make_tiles.py's tile_covered...) are never overwritten.
THEMED = {"tile_covered": "tile_modern_covered", "tile_revealed": "tile_modern_revealed",
          "tile_exploded": "tile_modern_exploded"}


def master(name, size, wide):
    im = Image.open(GENERATED / (name + ".png")).convert("RGBA")
    if wide:
        im = im.crop(im.getchannel("A").getbbox())          # trim, then fit without stretching
        fitted = ImageOps.contain(im, (size[0] - 8, size[1] - 8), Image.Resampling.LANCZOS)
        im = Image.new("RGBA", size)
        im.paste(fitted, ((size[0] - fitted.width) // 2, (size[1] - fitted.height) // 2))
    else:
        im = im.resize(size, Image.Resampling.LANCZOS)      # keep the shared framing (no per-piece trim)
    im.save(SOURCE / (name + ".png"))
    return im


def main():
    STAGED.mkdir(parents=True, exist_ok=True)
    for name, (msize, tsize, opts) in PIECES.items():
        out = MEDIA if (name in ADOPTED or name in THEMED) else STAGED
        outname = THEMED.get(name, name)
        im = master(name, msize, opts is None)
        if opts is None:
            # Not Pillow's TGA writer: it appends a 26-byte footer that tests/test_media.lua rejects.
            sized = im.resize(tsize, Image.Resampling.LANCZOS)
            texture_kit.OUT = str(out)
            texture_kit.write_tga(outname, np.asarray(sized).astype(float) / 255.0)
        else:
            subprocess.run([sys.executable, str(ROOT / "Tools" / "png_to_tga.py"), str(SOURCE / (name + ".png")),
                            outname, "--size", str(tsize), "--out", str(out)] + opts, cwd=ROOT, check=True)
        print(f"{name:14} -> {out.relative_to(ROOT)}{'/' + outname if outname != name else ''}")


if __name__ == "__main__":
    main()
