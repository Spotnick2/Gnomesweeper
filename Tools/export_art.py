"""Export the generated art (docs/ART.md, #12) into game textures.

    python Tools/export_art.py           # from the repository root

Reads the full-resolution PNGs in Media/Source/Generated/ (ignored by git: the
prompts that made them are in Media/ART-PROMPTS.md), sizes them, and writes:
  - Media/<name>.tga for every piece the game uses (ADOPTED below);
  - Media/Source/GameTextures/<name>.tga for candidates not wired yet (STAGED);
  - Media/Source/<name>.png, the sized masters, and Media/Source/art-preview.png.
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
import make_textures  # noqa: E402  (the one TGA writer: no footer, exactly header + pixels)
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
# In the game (Skin.TEXTURES). The tiles are a different look (bright ice-blue
# covered tiles) from the calmer one the UI review chose: the owner decides.
# The mine, the exploded mine and the flag too: on the board WoW's bomb and the
# pennant read better (owner, #12).
ADOPTED = ["face_playing", "face_won", "face_lost", "face_pressed", "title", "laurels"]


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
    STAGED.mkdir(exist_ok=True)
    for name, (msize, tsize, opts) in PIECES.items():
        out = MEDIA if name in ADOPTED else STAGED
        im = master(name, msize, opts is None)
        if opts is None:
            # Not Pillow's TGA writer: it appends a 26-byte footer that tests/test_media.lua rejects.
            sized = im.resize(tsize, Image.Resampling.LANCZOS)
            make_textures.OUT = str(out)
            make_textures.write_tga(name, np.asarray(sized).astype(float) / 255.0)
        else:
            subprocess.run([sys.executable, str(ROOT / "Tools" / "png_to_tga.py"), str(SOURCE / (name + ".png")),
                            name, "--size", str(tsize), "--out", str(out)] + opts, cwd=ROOT, check=True)
        print(f"{name:14} -> {out.relative_to(ROOT)}")


if __name__ == "__main__":
    main()
