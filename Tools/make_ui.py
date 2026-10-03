"""Generate the UI textures into Media/ as uncompressed 32-bit TGA.

    python Tools/make_ui.py                  # write Media/icon_*.tga, ui_*.tga, face_*.tga
    python Tools/make_ui.py --preview x.png  # also a magnified contact sheet (not committed)

The glass material's generator (make_textures.py) is a copy that belongs to
GlassUnitFrames, so it stays untouched; this one only IMPORTS its helpers. The
board tiles are Tools/make_tiles.py. The mascot's face is not drawn here: it is
cut from the logo (see Media/README.md).

What each is for (colour is a runtime decision wherever it can be: white
textures are tinted with SetVertexColor):

  icon_flag      a red pennant on a dark post: flagged tiles and the mine counter
  icon_burst     a starburst, ADD blended behind the bomb on the tile that ended the game
  icon_clock     a small brass clock beside the timer
  icon_trophy    a brass cup on a plinth: the best times button
  icon_music     a pair of eighth notes, white (tinted): the music button
  icon_mute      a red slash, over the note when the music is off
  fx_smoke       a soft grey puff, rising from the tile that went off (#10)
  fx_glow        a soft round glow, white (tinted gold), behind the mascot on a win (#10)
  icon_close     the X on the close button            (light, tinted)
  icon_arrow     the dropdown's arrow                 (white, tinted by difficulty)
  ui_fill        a dark glass button body, 9-sliced (margin 8)
  ui_border      its rim, white, 9-sliced; tinted per button (the difficulty's rarity colour)
  ui_glow        a white rounded fill, 9-sliced: hover (ADD) and pressed (a dark tint)
  face_ring      a white ring round the mascot, tinted by game state
  face_sparkle   gold stars over the face after a win
  face_soot      soot smudges over the face after a wipe
"""

import argparse
import os
import sys

import numpy as np
from PIL import Image, ImageDraw

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from make_textures import coverage, rounded_rect_sdf, write_tga  # noqa: E402

SS = 4                                  # supersampling for the drawn icons


def lerp(a, b, t):
    return a + (b - a) * t


def to_float(im):
    return np.asarray(im.convert("RGBA")).astype(float) / 255.0


def canvas(size):
    return Image.new("RGBA", (size * SS, size * SS), (0, 0, 0, 0))


def finish(im, size):
    return to_float(im.resize((size, size), Image.LANCZOS))     # Pillow resizes RGBA premultiplied


def gradient_fill(mask, top, bottom, box):
    """Fill `mask` (an 'L' image) with a vertical gradient between box's top and bottom rows."""
    w, h = mask.size
    y0, y1 = box
    ys = np.clip((np.arange(h) - y0) / max(1, (y1 - y0)), 0, 1)
    rows = np.stack([lerp(top[i], bottom[i], ys) for i in range(3)], axis=-1)       # (h, 3)
    rgb = np.repeat(rows[:, None, :], w, axis=1)
    out = np.dstack([rgb, np.asarray(mask).astype(float) / 255.0 * 255.0])
    return Image.fromarray(out.astype(np.uint8), "RGBA")


def paste_shape(im, draw_fn, top, bottom, box):
    """Draw a shape with `draw_fn(ImageDraw)` on a mask, fill it with a gradient, composite onto im."""
    mask = Image.new("L", im.size, 0)
    draw_fn(ImageDraw.Draw(mask))
    im.alpha_composite(gradient_fill(mask, top, bottom, box))


# ---------------------------------------------------------------------------
# The flag
# ---------------------------------------------------------------------------

def flag():
    size = 64
    s = size * SS
    u = s / 256.0                                   # design on a 256 grid
    im = canvas(size)

    def P(*pts):
        return [(x * u, y * u) for x, y in pts]

    # base: a gunmetal disc seen from above, with a lit top
    paste_shape(im, lambda d: d.ellipse(P((46, 200), (150, 242)), fill=255),
                (84, 92, 108), (30, 33, 42), (200 * u, 242 * u))
    paste_shape(im, lambda d: d.ellipse(P((60, 204), (136, 226)), fill=255),
                (120, 130, 148), (62, 68, 82), (204 * u, 226 * u))
    # pole: a rounded dark post with a thin light edge
    paste_shape(im, lambda d: d.rounded_rectangle(P((86, 26), (104, 218)), radius=8 * u, fill=255),
                (96, 104, 120), (34, 37, 46), (26 * u, 218 * u))
    paste_shape(im, lambda d: d.rounded_rectangle(P((89, 34), (93, 210)), radius=2 * u, fill=255),
                (190, 200, 216), (110, 118, 134), (34 * u, 210 * u))
    # pennant: a dark outline, the red body, a bright upper edge
    tri = P((98, 30), (226, 90), (98, 150))
    paste_shape(im, lambda d: d.polygon(tri, fill=255), (70, 6, 8), (70, 6, 8), (0, s))
    inner = P((106, 44), (206, 90), (106, 136))
    paste_shape(im, lambda d: d.polygon(inner, fill=255), (255, 92, 74), (176, 16, 22), (44 * u, 136 * u))
    hi = P((108, 48), (200, 90), (108, 100))
    paste_shape(im, lambda d: d.polygon(hi, fill=255), (255, 190, 170), (255, 120, 100), (48 * u, 100 * u))
    # the highlight is a sliver: knock the lower half of it back to the body colour
    return finish(im, size)


# ---------------------------------------------------------------------------
# The clock
# ---------------------------------------------------------------------------

def clock():
    size = 64
    s = size * SS
    u = s / 256.0
    im = canvas(size)

    def P(*pts):
        return [(x * u, y * u) for x, y in pts]

    # crown, then the brass case, then the dark face
    paste_shape(im, lambda d: d.rounded_rectangle(P((112, 14), (144, 38)), radius=6 * u, fill=255),
                (250, 214, 110), (160, 92, 24), (14 * u, 38 * u))
    paste_shape(im, lambda d: d.ellipse(P((22, 32), (234, 244)), fill=255),
                (255, 222, 120), (150, 84, 20), (32 * u, 244 * u))
    paste_shape(im, lambda d: d.ellipse(P((44, 54), (212, 222)), fill=255),
                (24, 40, 74), (10, 18, 40), (54 * u, 222 * u))
    d = ImageDraw.Draw(im)
    light = (236, 244, 255, 255)
    cx, cy = 128 * u, 138 * u
    for ang in range(0, 360, 90):                                   # four ticks
        import math
        x1, y1 = cx + math.sin(math.radians(ang)) * 66 * u, cy - math.cos(math.radians(ang)) * 66 * u
        x2, y2 = cx + math.sin(math.radians(ang)) * 52 * u, cy - math.cos(math.radians(ang)) * 52 * u
        d.line([(x1, y1), (x2, y2)], fill=(150, 190, 235, 255), width=int(7 * u))
    d.line([(cx, cy), (cx, cy - 46 * u)], fill=light, width=int(11 * u))        # hour hand
    d.line([(cx, cy), (cx + 38 * u, cy + 4 * u)], fill=light, width=int(8 * u))  # minute hand
    r = 9 * u
    d.ellipse([cx - r, cy - r, cx + r, cy + r], fill=(255, 214, 110, 255))
    return finish(im, size)


# ---------------------------------------------------------------------------
# The trophy (the best times panel), brass like the clock
# ---------------------------------------------------------------------------

def trophy():
    size = 64
    s = size * SS
    u = s / 256.0
    im = canvas(size)

    def P(*pts):
        return [(x * u, y * u) for x, y in pts]

    brass_top, brass_bottom = (255, 226, 128), (156, 88, 20)
    dark = (96, 52, 10)
    # handles: brass rings either side of the cup, drawn first so the cup covers their inner half
    for box in (P((20, 48), (100, 140)), P((156, 48), (236, 140))):
        paste_shape(im, lambda d, b=box: d.ellipse(b, outline=255, width=int(18 * u)),
                    brass_top, brass_bottom, (48 * u, 140 * u))
    # the cup: a flat rim on top, a rounded bowl below
    paste_shape(im, lambda d: d.chord(P((52, -40), (204, 172)), 0, 180, fill=255),
                brass_top, brass_bottom, (66 * u, 172 * u))
    paste_shape(im, lambda d: d.rounded_rectangle(P((46, 30), (210, 70)), radius=10 * u, fill=255),
                brass_top, brass_bottom, (30 * u, 70 * u))
    # a dark mouth along the rim, and a light streak down the bowl
    paste_shape(im, lambda d: d.rounded_rectangle(P((60, 38), (196, 52)), radius=6 * u, fill=255),
                dark, dark, (0, s))
    paste_shape(im, lambda d: d.rounded_rectangle(P((78, 76), (94, 150)), radius=8 * u, fill=255),
                (255, 246, 210), (255, 220, 140), (76 * u, 150 * u))
    # stem, collar, plinth
    paste_shape(im, lambda d: d.rectangle(P((114, 168), (142, 204)), fill=255),
                (230, 180, 80), (140, 78, 18), (168 * u, 204 * u))
    paste_shape(im, lambda d: d.rounded_rectangle(P((92, 196), (164, 214)), radius=6 * u, fill=255),
                brass_top, brass_bottom, (196 * u, 214 * u))
    paste_shape(im, lambda d: d.rounded_rectangle(P((68, 212), (188, 246)), radius=8 * u, fill=255),
                (84, 92, 108), (30, 33, 42), (212 * u, 246 * u))
    return finish(im, size)


# ---------------------------------------------------------------------------
# The music button: a note, and a slash over it when the music is off
# ---------------------------------------------------------------------------

def music_note():
    """A beamed pair of eighth notes, white (tinted at runtime)."""
    size = 64
    s = size * SS
    u = s / 256.0
    im = canvas(size)
    d = ImageDraw.Draw(im)
    white = (255, 255, 255, 255)
    # two note heads, tilted ovals
    for cx, cy in ((78, 190), (182, 168)):
        head = Image.new("RGBA", im.size, (0, 0, 0, 0))
        ImageDraw.Draw(head).ellipse([(cx - 34) * u, (cy - 24) * u, (cx + 34) * u, (cy + 24) * u], fill=white)
        im.alpha_composite(head.rotate(20, center=(cx * u, cy * u), resample=Image.BICUBIC))
    # stems and the beam joining them
    d.rectangle([104 * u, 52 * u, 120 * u, 186 * u], fill=white)
    d.rectangle([208 * u, 30 * u, 224 * u, 164 * u], fill=white)
    d.polygon([(104 * u, 52 * u), (224 * u, 30 * u), (224 * u, 72 * u), (104 * u, 94 * u)], fill=white)
    return finish(im, size)


def mute_slash():
    """A red diagonal bar, drawn over the note when the music is off."""
    size = 64
    s = size * SS
    u = s / 256.0
    im = canvas(size)
    d = ImageDraw.Draw(im)
    d.line([(40 * u, 216 * u), (216 * u, 40 * u)], fill=(30, 8, 8, 255), width=int(40 * u))     # a dark edge
    d.line([(40 * u, 216 * u), (216 * u, 40 * u)], fill=(232, 64, 56, 255), width=int(24 * u))
    return finish(im, size)


# ---------------------------------------------------------------------------
# A soft round glow behind the mascot on a win (#10): white, tinted gold, ADD
# ---------------------------------------------------------------------------

def soft_glow():
    size = 64
    ys, xs = np.mgrid[0:size, 0:size].astype(float) + 0.5
    r = np.hypot(xs - 32, ys - 32) / 32                               # 0 in the middle, 1 at the edge
    alpha = np.exp(-(r / 0.5) ** 2) * np.clip((1 - r) / 0.15, 0, 1)   # gaussian, nothing at the edge
    out = np.ones((size, size, 4))
    out[..., 3] = alpha
    return out


# ---------------------------------------------------------------------------
# A puff of smoke, rising from the tile that went off (#10)
# ---------------------------------------------------------------------------

def smoke_puff():
    """A soft, lumpy grey puff: a few overlapping blobs, faded at the edge. White-ish
    grey, tinted at runtime; the alpha does the work."""
    size = 64
    ys, xs = np.mgrid[0:size, 0:size].astype(float) + 0.5
    rng = np.random.default_rng(10)                                   # the same puff every run
    alpha = np.zeros((size, size))
    blobs = [(32, 34, 21)] + [(32 + rng.uniform(-11, 11), 32 + rng.uniform(-10, 8), rng.uniform(12, 16)) for _ in range(6)]
    for cx, cy, r in blobs:
        d = np.hypot(xs - cx, ys - cy) / r
        alpha = np.maximum(alpha, np.clip(1 - d, 0, 1) ** 1.1)
    edge = np.clip(1 - np.hypot(xs - 32, ys - 32) / 31, 0, 1)        # nothing reaches the square's edge
    alpha = np.clip(alpha * 1.25, 0, 1) * edge
    shade = 0.78 + 0.18 * np.clip((40 - ys) / 30, 0, 1)                # a lighter top, like lit smoke
    out = np.zeros((size, size, 4))
    out[..., 0] = out[..., 1] = out[..., 2] = shade
    out[..., 3] = alpha
    return out


# ---------------------------------------------------------------------------
# The burst behind the bomb
# ---------------------------------------------------------------------------

def burst():
    size = 64
    ys, xs = np.mgrid[0:size, 0:size].astype(float) + 0.5
    u, v = xs / size * 2 - 1, ys / size * 2 - 1
    r, th = np.hypot(u, v), np.arctan2(v, u)
    reach = 0.40 + 0.58 * np.abs(np.cos(6 * th)) ** 4            # 12 spikes
    alpha = np.clip((reach - r) / 0.07, 0, 1)
    t = np.clip(r / np.maximum(reach, 1e-6), 0, 1)
    out = np.zeros((size, size, 4))
    out[..., 0] = 1.0
    out[..., 1] = lerp(0.95, 0.42, t)
    out[..., 2] = lerp(0.55, 0.06, t)
    out[..., 3] = alpha * lerp(1.0, 0.75, t)
    return out


# ---------------------------------------------------------------------------
# Close X and dropdown arrow
# ---------------------------------------------------------------------------

def close_glyph():
    size = 32
    s = size * SS
    im = canvas(size)
    d = ImageDraw.Draw(im)
    pad, w = 9 * s / 32, 4.2 * s / 32
    col = (232, 242, 255, 255)
    d.line([(pad, pad), (s - pad, s - pad)], fill=col, width=int(w))
    d.line([(s - pad, pad), (pad, s - pad)], fill=col, width=int(w))
    r = w / 2
    for x, y in [(pad, pad), (s - pad, s - pad), (s - pad, pad), (pad, s - pad)]:
        d.ellipse([x - r, y - r, x + r, y + r], fill=col)
    return finish(im, size)


def arrow():
    size = 32
    s = size * SS
    im = canvas(size)
    d = ImageDraw.Draw(im)
    k = s / 32
    d.polygon([(7 * k, 11 * k), (25 * k, 11 * k), (16 * k, 22 * k)], fill=(255, 255, 255, 255))
    return finish(im, size)


# ---------------------------------------------------------------------------
# Glass buttons (9-sliced, margin 8, corner radius 7)
# ---------------------------------------------------------------------------

BTN = 32
BTN_RADIUS = 7.0


def ui_fill():
    d = rounded_rect_sdf(BTN, BTN, 1.0, BTN_RADIUS)
    shape = coverage(d)
    ys = (np.mgrid[0:BTN, 0:BTN][0] + 0.5) / BTN
    top, bottom = np.array([0.14, 0.22, 0.38]), np.array([0.06, 0.11, 0.22])
    colour = np.stack([lerp(top[i], bottom[i], ys) for i in range(3)], axis=-1)
    band = np.clip(1 - ys / 0.30, 0, 1) ** 1.5 * 0.10                    # a narrow light band at the top
    colour = colour + band[..., None] * (1 - colour)
    out = np.zeros((BTN, BTN, 4))
    out[..., :3] = colour
    out[..., 3] = shape * 0.90
    return out


def ui_border():
    d = rounded_rect_sdf(BTN, BTN, 1.0, BTN_RADIUS)
    ring = np.exp(-((-d - 0.9) ** 2) / 0.8) * coverage(d)
    glow = np.exp(-np.maximum(-d, 0) / 2.6) * coverage(d) * 0.20
    out = np.ones((BTN, BTN, 4))
    out[..., 3] = np.clip(ring * 0.95 + glow, 0, 1)
    return out


def ui_glow():
    d = rounded_rect_sdf(BTN, BTN, 1.0, BTN_RADIUS)
    out = np.ones((BTN, BTN, 4))
    out[..., 3] = coverage(d)
    return out


# ---------------------------------------------------------------------------
# The mascot's frame and its two overlays
# ---------------------------------------------------------------------------

def face_ring():
    size = 64
    ys, xs = np.mgrid[0:size, 0:size].astype(float) + 0.5
    r = np.hypot(xs - size / 2, ys - size / 2)
    outer = coverage(r - 31.6, 0.7)
    ring = outer * (1 - coverage(r - 28.2, 0.7))                          # a 3 px band
    inner_dark = (1 - coverage(r - 28.2, 0.7)) * coverage(r - 26.6, 0.7)  # a thin dark line inside it
    out = np.ones((size, size, 4))
    out[..., 3] = ring
    # the dark line is baked in as a darker colour on the ring's inner edge, tint-proof via alpha only:
    out[..., :3] = 1.0
    dark = np.zeros((size, size, 4))
    dark[..., 3] = inner_dark * 0.55
    # composite: white ring over a dark inner line
    a = out[..., 3:4] + dark[..., 3:4] * (1 - out[..., 3:4])
    rgb = (out[..., :3] * out[..., 3:4]) / np.maximum(a, 1e-6)
    res = np.zeros((size, size, 4))
    res[..., :3] = rgb
    res[..., 3] = a[..., 0]
    return res


def sparkle():
    size = 64
    ys, xs = np.mgrid[0:size, 0:size].astype(float) + 0.5
    out = np.zeros((size, size, 4))
    alpha = np.zeros((size, size))
    for cx, cy, rad in [(47, 17, 12.0), (15, 25, 8.0), (50, 47, 7.0), (22, 52, 5.0)]:
        x, y = np.abs(xs - cx), np.abs(ys - cy)
        star = (x ** 0.55 + y ** 0.55) ** (1 / 0.55)                       # an astroid: a 4-point star
        core = np.clip((rad - star) / 1.6, 0, 1)
        glow = np.exp(-(x ** 2 + y ** 2) / (2 * (rad * 0.45) ** 2)) * 0.45
        alpha = np.maximum(alpha, np.clip(core + glow, 0, 1))
    out[..., 0], out[..., 1], out[..., 2] = 1.0, 0.93, 0.55
    out[..., 3] = alpha
    # a white-hot core
    white = np.clip(alpha - 0.55, 0, 1) * 2
    out[..., 1] = lerp(out[..., 1], 1.0, white)
    out[..., 2] = lerp(out[..., 2], 0.95, white)
    return out


def soot():
    size = 64
    ys, xs = np.mgrid[0:size, 0:size].astype(float) + 0.5
    alpha = np.zeros((size, size))
    for cx, cy, sx, sy, a in [(21, 41, 8, 6, 0.85), (43, 39, 7, 6, 0.80), (31, 22, 10, 5, 0.60),
                              (49, 24, 6, 5, 0.65), (30, 52, 12, 5, 0.65), (12, 30, 5, 7, 0.55)]:
        alpha = np.maximum(alpha, a * np.exp(-(((xs - cx) / sx) ** 2 + ((ys - cy) / sy) ** 2)))
    # a smear across one cheek, and a general dimming
    streak = np.exp(-((((xs - 38) - (ys - 30) * 0.9) / 3.0) ** 2)) * (np.abs(ys - 34) < 9) * 0.35
    alpha = np.clip(np.maximum(alpha, streak) + 0.16, 0, 1)
    circle = coverage(np.hypot(xs - size / 2, ys - size / 2) - 31.6, 0.7)
    out = np.zeros((size, size, 4))
    out[..., 3] = alpha * circle
    out[..., 0], out[..., 1], out[..., 2] = 0.04, 0.03, 0.03
    return out


TEXTURES = {
    "icon_flag": flag, "icon_clock": clock, "icon_trophy": trophy, "icon_music": music_note, "icon_mute": mute_slash, "icon_burst": burst, "fx_smoke": smoke_puff, "fx_glow": soft_glow, "icon_close": close_glyph, "icon_arrow": arrow,
    "ui_fill": ui_fill, "ui_border": ui_border, "ui_glow": ui_glow,
    "face_ring": face_ring, "face_sparkle": sparkle, "face_soot": soot,
}


def preview(path):
    def over(bg, fg, tint=None, add=False):
        a = fg[..., 3:4]
        rgb = fg[..., :3] * (np.array(tint) if tint is not None else 1.0)
        return np.clip(bg + rgb * a, 0, 1) if add else bg * (1 - a) + rgb * a

    panel = np.array([0.13, 0.15, 0.20])
    cells = []

    def cell(size, *layers):
        c = np.zeros((size, size, 3)) + panel
        for fn in layers:
            c = fn(c)
        return c

    tex = {k: f() for k, f in TEXTURES.items()}
    cells.append(cell(64, lambda c: over(c, tex["icon_flag"])))
    covered = np.zeros((64, 64, 3)) + np.array([0.15, 0.27, 0.52])
    cells.append(cell(64, lambda c: over(c, tex["icon_flag"]), ) * 0 + over(covered, tex["icon_flag"]))
    cells.append(cell(64, lambda c: over(c, tex["icon_burst"], add=True)))
    cells.append(cell(64, lambda c: over(c, tex["fx_smoke"], tint=(0.55, 0.55, 0.58))))
    cells.append(cell(64, lambda c: over(c, tex["fx_glow"], tint=(0.98, 0.77, 0.38), add=True)))
    cells.append(cell(64, lambda c: over(c, tex["icon_trophy"])))
    cells.append(cell(64, lambda c: over(c, tex["icon_music"], tint=(0.82, 0.92, 1.0))))
    cells.append(cell(64, lambda c: over(over(c, tex["icon_music"], tint=(0.5, 0.55, 0.62)), tex["icon_mute"])))
    cells.append(cell(64, lambda c: over(c, tex["face_ring"], tint=(0.15, 0.7, 0.99))))
    cells.append(cell(64, lambda c: over(c, tex["face_ring"], tint=(1.0, 0.77, 0.38))))
    cells.append(cell(64, lambda c: over(c, tex["face_ring"], tint=(1.0, 0.35, 0.30))))
    row1 = np.concatenate(cells, axis=1)

    # buttons at game sizes: 130x24 sliced by hand (corners 8 px, middle stretched)
    def sliced(w, h, tint):
        out = np.zeros((h, w, 3)) + panel
        fill, border, glow = tex["ui_fill"], tex["ui_border"], tex["ui_glow"]
        for layer, t in ((fill, None), (border, tint)):
            canvas_ = np.zeros((h, w, 4))
            m = 8
            xs = [0, m, w - m, w]
            ys = [0, m, h - m, h]
            sx = [0, m, 32 - m, 32]
            for iy in range(3):
                for ix in range(3):
                    src = layer[sx[iy]:sx[iy + 1], sx[ix]:sx[ix + 1]]
                    dh, dw = ys[iy + 1] - ys[iy], xs[ix + 1] - xs[ix]
                    if dh <= 0 or dw <= 0:
                        continue
                    img = Image.fromarray((src * 255).astype(np.uint8), "RGBA").resize((dw, dh), Image.BILINEAR)
                    canvas_[ys[iy]:ys[iy + 1], xs[ix]:xs[ix + 1]] = np.asarray(img) / 255.0
            out = over(out, canvas_, tint=t)
        return out

    buttons = [sliced(130, 24, (0.12, 1.0, 0.0)), sliced(130, 24, (0.0, 0.44, 0.87)),
               sliced(130, 24, (0.64, 0.21, 0.93)), sliced(130, 24, (0.45, 0.8, 1.0))]
    row2 = np.concatenate([np.pad(b, ((0, 0), (0, 6), (0, 0)), constant_values=0.1) for b in buttons], axis=1)

    def pad_to(a, w):
        return np.pad(a, ((0, 0), (0, max(0, w - a.shape[1])), (0, 0)), constant_values=0.1)

    width = max(row1.shape[1], row2.shape[1])
    rows = [pad_to(row1, width), np.zeros((6, width, 3)) + 0.1, pad_to(row2, width)]
    sheet = np.concatenate(rows, axis=0)
    img = Image.fromarray((np.clip(sheet, 0, 1) * 255).astype(np.uint8))
    img = img.resize((img.width * 3, img.height * 3), Image.NEAREST)
    img.save(path)
    print("preview ->", path)


if __name__ == "__main__":
    ap = argparse.ArgumentParser()
    ap.add_argument("--preview")
    args = ap.parse_args()
    for name, fn in TEXTURES.items():
        write_tga(name, fn())
    if args.preview:
        preview(args.preview)
