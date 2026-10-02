"""Turn a generated image into a game texture: Media/<name>.tga, uncompressed 32-bit.

    python Tools/png_to_tga.py SRC NAME [--size 64] [--trim] [--circle | --round 0.18]
                               [--margin 0.04] [--out DIR] [--preview file.png]

SRC is the master image (keep masters out of git: Media/Source/ is ignored).
WoW loads TGA or BLP, never PNG, and wants power-of-two sizes.

  --size N      the square output size, a power of two (default 64)
  --trim        crop to the artwork first: the bounding box of whatever isn't
                transparent (needs an alpha channel)
  --margin F    transparent border to keep, as a fraction of the size (default 0.04),
                so a tile or icon isn't touching its own edge
  --circle      cut a circular portrait (the HUD face, the title-bar logo)
  --round F     round the corners by this fraction of the size (the AddOns-list icon)
  --out DIR     write there instead of Media/ (to look at a result first)
  --preview P   also write a PNG of the result over a mid-grey checker, magnified 4x

The resize is done on premultiplied alpha, so a transparent edge doesn't pick up a
dark halo. Record each asset's prompt, master name and this command in
Media/README.md.
"""

import argparse
import os
import sys

import numpy as np
from PIL import Image

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import make_textures  # noqa: E402  (the lifted generator: only its TGA writer is used)


def square(im, margin):
    """Pad to a square with transparent borders, leaving `margin` (fraction) around the art."""
    side = max(im.size)
    pad = int(round(side * margin))
    canvas = Image.new("RGBA", (side + 2 * pad, side + 2 * pad), (0, 0, 0, 0))
    canvas.paste(im, ((side + 2 * pad - im.width) // 2, (side + 2 * pad - im.height) // 2))
    return canvas


def shape_mask(size, circle, round_frac):
    """Antialiased alpha for the crop, 1 inside; supersampled 4x."""
    big = size * 4
    ys, xs = np.mgrid[0:big, 0:big].astype(float) + 0.5
    cx = cy = big / 2.0
    if circle:
        d = np.hypot(xs - cx, ys - cy) - big / 2.0
    else:
        r = big * round_frac
        qx = np.abs(xs - cx) - (big / 2.0 - r)
        qy = np.abs(ys - cy) - (big / 2.0 - r)
        d = np.hypot(np.maximum(qx, 0), np.maximum(qy, 0)) + np.minimum(np.maximum(qx, qy), 0) - r
    m = np.clip(0.5 - d, 0, 1)
    return m.reshape(size, 4, size, 4).mean(axis=(1, 3))


def convert(src, size, trim, margin, circle, round_frac):
    assert size & (size - 1) == 0 and size >= 4, "--size must be a power of two"
    im = Image.open(src).convert("RGBA")
    if trim:
        box = im.getchannel("A").getbbox()
        if box is None:
            raise SystemExit(f"{src}: nothing to trim (fully transparent)")
        im = im.crop(box)
    if circle or round_frac:
        # A crop wants the whole picture, not its bounding box: square it up by cropping the long side.
        side = min(im.size)
        left, top = (im.width - side) // 2, (im.height - side) // 2
        im = im.crop((left, top, left + side, top + side))
        out = im.resize((size, size), Image.LANCZOS)            # Pillow resizes RGBA premultiplied
        px = np.asarray(out).astype(float) / 255.0
        px[..., 3] *= shape_mask(size, circle, round_frac)
        return px
    im = square(im, margin)
    out = im.resize((size, size), Image.LANCZOS)
    return np.asarray(out).astype(float) / 255.0


def preview(px, path):
    size = px.shape[0]
    checker = np.indices((size, size)).sum(axis=0) // max(1, size // 8) % 2
    bg = np.where(checker[..., None] == 0, 0.30, 0.42) * np.ones((size, size, 3))
    a = px[..., 3:4]
    comp = bg * (1 - a) + px[..., :3] * a
    Image.fromarray((comp * 255).astype(np.uint8)).resize((size * 4, size * 4), Image.NEAREST).save(path)
    print("preview ->", path)


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("src")
    ap.add_argument("name")
    ap.add_argument("--size", type=int, default=64)
    ap.add_argument("--trim", action="store_true")
    ap.add_argument("--margin", type=float, default=0.04)
    shape = ap.add_mutually_exclusive_group()
    shape.add_argument("--circle", action="store_true")
    shape.add_argument("--round", type=float, default=0.0, dest="round_frac")
    ap.add_argument("--out")
    ap.add_argument("--preview")
    args = ap.parse_args()

    px = convert(args.src, args.size, args.trim, args.margin, args.circle, args.round_frac)
    if args.out:
        os.makedirs(args.out, exist_ok=True)
        make_textures.OUT = args.out
    make_textures.write_tga(args.name, px)
    if args.preview:
        preview(px, args.preview)


if __name__ == "__main__":
    main()
