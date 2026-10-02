"""Generate the board's tile textures into Media/ as uncompressed 32-bit TGA.

    python Tools/make_tiles.py                 # write Media/tile_*.tga
    python Tools/make_tiles.py --preview x.png # also a magnified contact sheet (not committed)

The glass material's generator (make_textures.py) is a copy that belongs to
GlassUnitFrames, so it stays untouched; this one only IMPORTS its helpers.

Why baked textures and not Glass.Apply per tile: that makes 6 textures, a mask
and a frame per host (480 tiles at Expert), and its sliced mask is measured to
fail on small squares. Three small textures shared by every tile are the same
look for none of the cost. Tiles are 24 units: 32 px textures, a 1 px
transparent margin so neighbours read as separate tiles.

  tile_covered   glossy translucent blue glass, a lit top-left bevel
  tile_exploded  the same in red: the tile that ended the game (a vertex colour
                 can't make blue red, so it is its own texture)
  tile_revealed  flat dark, slightly inset
  tile_hover     a cyan ring and glow, drawn ADD over the covered tile
"""

import argparse
import os
import sys

import numpy as np

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from make_textures import coverage, normals, rounded_rect_sdf, write_tga  # noqa: E402

S = 32                      # texture size
INSET = 1.0                 # transparent margin, px
RADIUS = 5.0


def lerp(a, b, t):
    return a + (b - a) * t


def rgba(rgb, alpha):
    out = np.zeros(alpha.shape + (4,))
    out[..., 0], out[..., 1], out[..., 2] = rgb
    out[..., 3] = alpha
    return out


def covered(top=(0.34, 0.58, 1.00), bottom=(0.12, 0.25, 0.62)):
    d = rounded_rect_sdf(S, S, INSET, RADIUS)
    shape = coverage(d)
    ys = (np.mgrid[0:S, 0:S][0] + 0.5) / S                    # 0 top .. 1 bottom
    top, bottom = np.array(top), np.array(bottom)
    colour = np.stack([lerp(top[i], bottom[i], ys) for i in range(3)], axis=-1)

    # A white gloss over the top half, fading out; confined to the shape.
    gloss = np.clip(1 - ys / 0.55, 0, 1) ** 1.6 * 0.30
    colour = colour + gloss[..., None] * (1 - colour)

    # A bevel lit from the top-left: bright along the upward and leftward
    # edges, dark along the downward and rightward ones.
    nx, ny = normals(d)
    edge = np.exp(-np.maximum(-d, 0) / 1.1)                    # 1 at the rim, fading inward
    light = np.clip(-(nx * 0.45 + ny * 0.9), -1, 1)
    colour = colour + np.where(light > 0, light, 0)[..., None] * edge[..., None] * 0.55 * (1 - colour)
    colour = colour * (1 - np.where(light < 0, -light, 0)[..., None] * edge[..., None] * 0.45)

    out = rgba((0, 0, 0), shape * 0.94)
    out[..., :3] = np.clip(colour, 0, 1)
    return out


def revealed():
    d = rounded_rect_sdf(S, S, INSET, RADIUS - 1)
    shape = coverage(d)
    colour = np.array([0.045, 0.085, 0.17])
    out = rgba(colour, shape * 0.58)
    # A faint darker rim, so a revealed tile reads as pressed in.
    rim = np.exp(-np.maximum(-d, 0) / 1.0) * shape
    out[..., :3] *= (1 - 0.45 * rim[..., None])
    out[..., 3] = np.clip(out[..., 3] + 0.15 * rim, 0, 1)
    return out


def hover():
    d = rounded_rect_sdf(S, S, INSET, RADIUS)
    shape = coverage(d)
    ring = np.exp(-((-d - 0.9) ** 2) / 0.9) * shape            # a ring just inside the edge
    glow = np.exp(-np.maximum(-d, 0) / 3.2) * shape * 0.30     # a soft glow inward
    alpha = np.clip(ring * 0.95 + glow, 0, 1)
    return rgba((0.30, 0.92, 1.00), alpha)


def exploded():
    return covered(top=(1.00, 0.46, 0.32), bottom=(0.60, 0.10, 0.08))


TEXTURES = {"tile_covered": covered, "tile_exploded": exploded, "tile_revealed": revealed, "tile_hover": hover}


def preview(path, scale=6):
    """A magnified contact sheet over a mid-tone background, hover over a covered tile."""
    from PIL import Image

    def over(bg, fg, add=False):
        a = fg[..., 3:4]
        return np.clip(bg + fg[..., :3] * a, 0, 1) if add else bg * (1 - a) + fg[..., :3] * a

    bgc = np.zeros((S, S, 3)) + np.array([0.18, 0.28, 0.14])   # a grassy world behind
    cov = over(bgc, TEXTURES["tile_covered"]())
    rev = over(bgc, TEXTURES["tile_revealed"]())
    hov = over(cov, TEXTURES["tile_hover"](), add=True)
    exp = over(bgc, TEXTURES["tile_exploded"]())
    sheet = np.concatenate([cov, rev, hov, exp], axis=1)
    img = Image.fromarray((sheet * 255).astype(np.uint8)).resize((sheet.shape[1] * scale, S * scale), Image.NEAREST)

    # And a 6x4 block of covered tiles at game size, to judge them as a board.
    board = np.concatenate([np.concatenate([cov] * 6, axis=1)] * 4, axis=0)
    board_img = Image.fromarray((board * 255).astype(np.uint8)).resize((board.shape[1] * 3, board.shape[0] * 3), Image.NEAREST)
    canvas = Image.new("RGB", (max(img.width, board_img.width), img.height + board_img.height + 8), (20, 24, 32))
    canvas.paste(img, (0, 0))
    canvas.paste(board_img, (0, img.height + 8))
    canvas.save(path)
    print("preview ->", path)


if __name__ == "__main__":
    ap = argparse.ArgumentParser()
    ap.add_argument("--preview")
    args = ap.parse_args()
    for name, fn in TEXTURES.items():
        write_tga(name, fn())
    if args.preview:
        preview(args.preview)
