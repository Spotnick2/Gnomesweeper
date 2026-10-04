"""Helpers for Gnomesweeper's own art tools: write a texture, and draw rounded shapes.

    from texture_kit import coverage, normals, rounded_rect_sdf, write_tga

Kept from the glass material's generator (make_textures.py), which left this repo
with the material for LibGlass-1.0 (#71): make_tiles.py, make_ui.py, png_to_tga.py
and export_art.py import these and write into OUR Media/ (OUT), never the library's.

TGAs are uncompressed 32-bit, power-of-two, bottom-left origin, no footer.
"""

import os
import numpy as np

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "Media")


def write_tga(name, rgba):
    """rgba: float array (h, w, 4) in 0..1, row 0 = top."""
    h, w, _ = rgba.shape
    assert w & (w - 1) == 0 and h & (h - 1) == 0, f"{name}: not power of two"
    px = (np.clip(rgba, 0, 1) * 255 + 0.5).astype(np.uint8)
    bgra = px[::-1, :, [2, 1, 0, 3]]            # flip to bottom-left origin, RGBA -> BGRA
    header = bytes([0, 0, 2, 0, 0, 0, 0, 0, 0, 0, 0, 0,
                    w & 255, w >> 8, h & 255, h >> 8, 32, 0x08])
    with open(os.path.join(OUT, name + ".tga"), "wb") as f:
        f.write(header)
        f.write(bgra.tobytes())
    print(f"  {name}.tga  {w}x{h}")


def rounded_rect_sdf(w, h, inset, radius):
    """Signed distance (px) to a rounded rect inset from the texture edge; negative inside."""
    ys, xs = np.mgrid[0:h, 0:w].astype(np.float64) + 0.5
    cx, cy = w / 2.0, h / 2.0
    hx, hy = w / 2.0 - inset, h / 2.0 - inset
    qx = np.abs(xs - cx) - (hx - radius)
    qy = np.abs(ys - cy) - (hy - radius)
    outside = np.hypot(np.maximum(qx, 0), np.maximum(qy, 0))
    inside = np.minimum(np.maximum(qx, qy), 0)
    return outside + inside - radius


def coverage(d, soft=0.75):
    """Antialiased fill from a signed distance: 1 inside, 0 outside."""
    return np.clip(0.5 - d / (2 * soft), 0, 1)


def normals(d):
    gy, gx = np.gradient(d)
    n = np.hypot(gx, gy) + 1e-9
    return gx / n, gy / n
