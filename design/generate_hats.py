"""
Fly Me to the Moon - Hat Layering System Generator (v2)
Outputs modular hat pieces (brim / crown / band / addon) as 128x128 transparent
PNGs that stack pixel-perfect for Godot's Sprite2D layering approach (Section 4
of the art spec).

v2 changes:
- 10 of each piece (was 5)
- Brim and crown are now driven by the SAME 10 materials, using the exact same
  paint function for both, so a "felt" brim and a "felt" crown are guaranteed
  to match (not just similarly colored).
- No outline/rim color on brims (removed the gold trim).
"""
import os
import math
import numpy as np
from PIL import Image, ImageDraw, ImageFilter, ImageFont

np.random.seed(7)

# ---------------------------------------------------------------- canvas setup
SIZE  = 128
SCALE = 4                  # supersample factor for smooth vector edges
BIG   = SIZE * SCALE
CX    = BIG // 2

OUT = "hats"
for sub in ("brims", "crowns", "bands", "addons", "previews", "previews/combos"):
    os.makedirs(f"{OUT}/{sub}", exist_ok=True)


def S(v):
    """Convert a coordinate from 128px design space to the supersampled canvas."""
    return v * SCALE


def P(pts):
    """Convert a list of (x, y) points from 128px design space to supersampled."""
    return [(S(x), S(y)) for x, y in pts]


# ---------------------------------------------------------------- palette (Noir Jazz)
CHARCOAL   = (27, 31, 43, 255)
INK        = (16, 17, 23, 255)
GOLD       = (201, 162, 39, 255)
GOLD_LT    = (231, 196, 96, 255)
CRIMSON    = (150, 26, 46, 255)
CRIMSON_LT = (196, 60, 84, 255)
CREAM      = (232, 223, 202, 255)
CREAM_DK   = (206, 194, 165, 255)
NEON_CYAN  = (58, 235, 219, 255)
NEON_PINK  = (255, 45, 190, 255)
SILVER     = (200, 205, 213, 255)
SILVER_DK  = (118, 124, 136, 255)
BROWN      = (91, 58, 41, 255)
BROWN_LT   = (138, 94, 64, 255)
STRAW      = (217, 182, 84, 255)
STRAW_DK   = (171, 136, 58, 255)
WHITE      = (245, 245, 240, 255)


# ---------------------------------------------------------------- core helpers
def blank():
    return Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))


def mask_from(draw_fn):
    """Render a shape at 4x scale on an L canvas, then downsize for a smooth edge."""
    big = Image.new("L", (BIG, BIG), 0)
    draw_fn(ImageDraw.Draw(big))
    return big.resize((SIZE, SIZE), Image.LANCZOS)


def cut(paint, mask):
    out = blank()
    out.paste(paint, (0, 0), mask)
    return out


def solid(color):
    return Image.new("RGBA", (SIZE, SIZE), color)


def grad(c1, c2, axis="v"):
    c1 = np.array(c1, dtype=np.float32)
    c2 = np.array(c2, dtype=np.float32)
    y, x = np.mgrid[0:SIZE, 0:SIZE]
    if axis == "v":
        t = y / (SIZE - 1)
    elif axis == "d":
        t = (x + y) / (2 * (SIZE - 1))
    else:
        t = x / (SIZE - 1)
    t = t[..., None]
    arr = (c1 * (1 - t) + c2 * t).astype(np.uint8)
    return Image.fromarray(arr, "RGBA")


def stack(*layers):
    base = layers[0].copy()
    for layer in layers[1:]:
        base = Image.alpha_composite(base, layer)
    return base


def save(img, path):
    img.save(path)


# ================================================================== MATERIALS
# One paint function per material, shared identically by BOTH the brim and
# the crown of that material - this is what guarantees a felt brim always
# matches a felt crown, a titanium brim always matches a titanium crown, etc.

def cardboard_paint():
    paint = solid((200, 161, 101, 255))
    d = ImageDraw.Draw(paint)
    for y in range(0, SIZE, 6):
        d.line([(0, y), (SIZE, y)], fill=(170, 130, 80, 255), width=1)
    return paint


def felt_paint():
    paint = grad((36, 40, 54, 255), (22, 25, 34, 255), "v")
    d = ImageDraw.Draw(paint)
    rng = np.random.RandomState(21)
    for _ in range(20):
        x, y = rng.randint(0, SIZE), rng.randint(0, SIZE)
        r = rng.randint(3, 8)
        d.ellipse([x - r, y - r, x + r, y + r], fill=(24, 27, 37, 255))
    return paint


def leather_paint():
    paint = solid(BROWN)
    d = ImageDraw.Draw(paint)
    d.polygon([(10, 140), (70, 10), (90, 10), (30, 140)], fill=(115, 76, 53, 255))
    rng = np.random.RandomState(22)
    for _ in range(6):
        x0, y0 = rng.randint(10, 118), rng.randint(10, 118)
        x1, y1 = x0 + rng.randint(-10, 10), y0 + rng.randint(6, 16)
        d.line([(x0, y0), (x1, y1)], fill=(50, 30, 20, 255), width=1)
    return paint


def straw_paint():
    paint = solid(STRAW)
    d = ImageDraw.Draw(paint)
    for i in range(-SIZE, SIZE, 7):
        d.line([(i, 0), (i + SIZE, SIZE)], fill=STRAW_DK, width=1)
        d.line([(i, SIZE), (i + SIZE, 0)], fill=STRAW_DK, width=1)
    return paint


def titanium_paint():
    paint = grad(SILVER, SILVER_DK, "d")
    d = ImageDraw.Draw(paint)
    d.polygon([(0, 60), (40, 10), (60, 10), (20, 60)], fill=(235, 238, 242, 255))
    return paint


def velvet_paint():
    paint = grad((70, 20, 46, 255), (38, 10, 26, 255), "v")
    d = ImageDraw.Draw(paint)
    rng = np.random.RandomState(23)
    for _ in range(10):
        x, y = rng.randint(0, SIZE), rng.randint(0, SIZE)
        r = rng.randint(10, 20)
        d.ellipse([x - r, y - r, x + r, y + r], fill=(90, 30, 58, 255))
    return paint


def tweed_paint():
    paint = solid((110, 102, 84, 255))
    d = ImageDraw.Draw(paint)
    for i in range(-SIZE, SIZE, 5):
        d.line([(i, 0), (i + SIZE, SIZE)], fill=(80, 74, 60, 255), width=1)
    for i in range(0, SIZE, 9):
        d.line([(0, i), (SIZE, i)], fill=(140, 132, 110, 255), width=1)
    return paint


def pinstripe_paint():
    paint = solid((26, 30, 46, 255))
    d = ImageDraw.Draw(paint)
    for x in range(4, SIZE, 10):
        d.line([(x, 0), (x, SIZE)], fill=(220, 220, 225, 255), width=1)
    return paint


def pearl_grey_paint():
    # Steel/pearl grey felt - the color most associated with Sinatra's classic
    # fedora (see Miller Hats' "The Sinatra" replica: steel gray, smooth felt).
    paint = grad((162, 160, 156, 255), (110, 108, 104, 255), "v")
    d = ImageDraw.Draw(paint)
    rng = np.random.RandomState(25)
    for _ in range(18):
        x, y = rng.randint(0, SIZE), rng.randint(0, SIZE)
        r = rng.randint(3, 7)
        d.ellipse([x - r, y - r, x + r, y + r], fill=(96, 94, 90, 255))
    return paint


def trilby_noir_paint():
    # Near-black felt - Sinatra was, per period accounts, more often in a
    # trilby (narrower brim, shorter crown) than a full-size fedora.
    paint = grad((40, 38, 40, 255), (16, 15, 16, 255), "v")
    d = ImageDraw.Draw(paint)
    rng = np.random.RandomState(26)
    for _ in range(18):
        x, y = rng.randint(0, SIZE), rng.randint(0, SIZE)
        r = rng.randint(3, 7)
        d.ellipse([x - r, y - r, x + r, y + r], fill=(10, 9, 10, 255))
    return paint


MATERIAL_PAINT = {
    "cardboard":   cardboard_paint,
    "felt":        felt_paint,
    "leather":     leather_paint,
    "straw":       straw_paint,
    "titanium":    titanium_paint,
    "velvet":      velvet_paint,
    "tweed":       tweed_paint,
    "pinstripe":   pinstripe_paint,
    "pearl_grey":  pearl_grey_paint,
    "trilby_noir": trilby_noir_paint,
}
MATERIALS = list(MATERIAL_PAINT.keys())


# ================================================================== CROWN SHAPES
# Every material gets its own silhouette (not just a recolor). All share the
# same base "neck" rectangle so any crown lines up with any band, regardless
# of material - the visual variety lives above that line.
NECK = (30, 60, 98, 80)


def draw_neck(d):
    d.rectangle([S(NECK[0]), S(NECK[1]), S(NECK[2]), S(NECK[3])], fill=255)


def crown_mask_felt():
    def f(d):
        draw_neck(d)
        d.ellipse([S(26), S(20), S(102), S(64)], fill=255)
        d.polygon(P([(60, 18), (68, 18), (64, 25)]), fill=0)
    return mask_from(f)


def crown_mask_cardboard():
    def f(d):
        draw_neck(d)
        d.polygon(P([
            (32, 60), (32, 30), (38, 22),
            (46, 26), (54, 19), (62, 25), (70, 18), (78, 24), (86, 19), (90, 24),
            (96, 30), (96, 60),
        ]), fill=255)
    return mask_from(f)


def crown_mask_leather():
    def f(d):
        draw_neck(d)
        d.polygon(P([(29, 60), (27, 34), (40, 18), (70, 15), (92, 22), (99, 40), (99, 60)]), fill=255)
        d.polygon(P([(72, 16), (86, 20), (76, 30)]), fill=0)
    return mask_from(f)


def crown_mask_straw():
    def f(d):
        draw_neck(d)
        d.rectangle([S(33), S(34), S(95), S(60)], fill=255)
        d.ellipse([S(33), S(26), S(95), S(42)], fill=255)
    return mask_from(f)


def crown_mask_titanium():
    def f(d):
        draw_neck(d)
        d.polygon(P([(32, 60), (32, 42), (48, 20), (80, 20), (96, 42), (96, 60)]), fill=255)
    return mask_from(f)


def crown_mask_velvet():
    def f(d):
        draw_neck(d)
        d.ellipse([S(22), S(14), S(106), S(64)], fill=255)
    return mask_from(f)


def crown_mask_tweed():
    def f(d):
        draw_neck(d)
        d.ellipse([S(26), S(26), S(102), S(62)], fill=255)
    return mask_from(f)


def crown_mask_pinstripe():
    def f(d):
        draw_neck(d)
        d.rectangle([S(38), S(20), S(90), S(60)], fill=255)
        d.ellipse([S(38), S(12), S(90), S(30)], fill=255)
    return mask_from(f)


def crown_mask_pearl_grey():
    """Tight pinch 'teardrop' crown - the sharp, narrow silhouette of Sinatra's
    classic fedora (real replicas are sold as a 4 3/8" tight-pinch teardrop
    crown, per Miller Hats' "1155 The Sinatra")."""
    def f(d):
        draw_neck(d)
        d.polygon(P([(36, 60), (36, 32), (50, 20), (64, 15), (78, 20), (92, 32), (92, 60)]), fill=255)
        d.polygon(P([(60, 17), (68, 17), (64, 24)]), fill=0)
    return mask_from(f)


def crown_mask_trilby_noir():
    """Short, compact crown - period accounts describe Sinatra's trilby as
    having a distinctly shorter crown than a full-size fedora, with a
    subtler pinch (handled as a drawn crease in crown_detail, not carved)."""
    def f(d):
        draw_neck(d)
        d.rectangle([S(34), S(40), S(94), S(60)], fill=255)
        d.ellipse([S(34), S(32), S(94), S(48)], fill=255)
    return mask_from(f)


CROWN_MASKS = {
    "cardboard":   crown_mask_cardboard,
    "felt":        crown_mask_felt,
    "leather":     crown_mask_leather,
    "straw":       crown_mask_straw,
    "titanium":    crown_mask_titanium,
    "velvet":      crown_mask_velvet,
    "tweed":       crown_mask_tweed,
    "pinstripe":   crown_mask_pinstripe,
    "pearl_grey":  crown_mask_pearl_grey,
    "trilby_noir": crown_mask_trilby_noir,
}


def crown_detail(img, material):
    d = ImageDraw.Draw(img)
    if material == "felt":
        d.line([(64, 25), (64, 60)], fill=(14, 15, 20, 255), width=2)
        d.line([(48, 30), (58, 22)], fill=(14, 15, 20, 255), width=1)
        d.line([(80, 30), (70, 22)], fill=(14, 15, 20, 255), width=1)
    elif material == "cardboard":
        d.line([(40, 30), (88, 38)], fill=(140, 105, 60, 255), width=2)
    elif material == "straw":
        d.line([(33, 42), (95, 42)], fill=STRAW_DK, width=1)
    elif material == "titanium":
        d.line([(48, 20), (32, 42)], fill=(70, 76, 86, 255), width=1)
        d.line([(80, 20), (96, 42)], fill=(70, 76, 86, 255), width=1)
    elif material == "tweed":
        for x in (44, 56, 72, 84):
            d.line([(x, 30), (x, 60)], fill=(80, 74, 60, 255), width=1)
    elif material == "pinstripe":
        d.line([(38, 22), (38, 60)], fill=(10, 11, 16, 255), width=1)
        d.line([(90, 22), (90, 60)], fill=(10, 11, 16, 255), width=1)
    elif material == "pearl_grey":
        d.line([(64, 20), (64, 60)], fill=(60, 58, 54, 255), width=2)
        d.line([(48, 26), (58, 20)], fill=(60, 58, 54, 255), width=1)
        d.line([(80, 26), (70, 20)], fill=(60, 58, 54, 255), width=1)
    elif material == "trilby_noir":
        d.line([(64, 36), (64, 60)], fill=(6, 5, 6, 255), width=2)
    return img


def make_crown(material):
    mask = CROWN_MASKS[material]()
    img = cut(MATERIAL_PAINT[material](), mask)
    return crown_detail(img, material)


CROWNS = {m: (lambda m=m: make_crown(m)) for m in MATERIALS}


# ================================================================== BRIM SHAPES
# Each brim is textured with the SAME paint function as its matching crown
# (same material => identical texture, guaranteed). Shapes are chosen to fit
# each material's traditional hat style. No outline/rim color.
BRIM_ELLIPSE_BBOX = {
    "felt":      (14, 71, 114, 93),
    "leather":   (3, 70, 125, 94),
    "tweed":     (19, 77, 109, 91),
    "velvet":    (10, 69, 118, 95),
    "pinstripe": (16, 73, 112, 91),
}
BRIM_ROUNDED_BBOX = {
    "straw": (8, 76, 120, 92),
}


def brim_mask_cardboard():
    cx, cy = 64, 82
    rx, ry = 50, 11
    rng = np.random.RandomState(31)
    n = 22
    pts = []
    for i in range(n):
        ang = 2 * math.pi * i / n
        jitter = rng.uniform(0.82, 1.16)
        pts.append((cx + math.cos(ang) * rx * jitter, cy + math.sin(ang) * ry * jitter))
    return mask_from(lambda d: d.polygon(P(pts), fill=255))


def brim_mask_titanium():
    pts = [(20, 82), (40, 71), (88, 71), (108, 82), (88, 93), (40, 93)]
    return mask_from(lambda d: d.polygon(P(pts), fill=255))


def rotated_ellipse_points(cx, cy, rx, ry, angle_deg, n=40):
    """Ellipse boundary points rotated about (cx, cy) - used for the tilted
    snap brims below, since PIL's ellipse() can't draw at an angle directly."""
    theta = math.radians(angle_deg)
    pts = []
    for i in range(n):
        a = 2 * math.pi * i / n
        x0, y0 = rx * math.cos(a), ry * math.sin(a)
        x = cx + x0 * math.cos(theta) - y0 * math.sin(theta)
        y = cy + x0 * math.sin(theta) + y0 * math.cos(theta)
        pts.append((x, y))
    return pts


def brim_mask_pearl_grey():
    """Narrow snap brim worn at a rakish tilt - Sinatra reportedly favored a
    2 1/8" brim, narrower than a standard fedora, worn snapped at an angle."""
    pts = rotated_ellipse_points(64, 82, 45, 9, -8)
    return mask_from(lambda d: d.polygon(P(pts), fill=255))


def brim_mask_trilby_noir():
    """Even narrower brim than the fedora above - trilbys are defined by a
    shorter, tighter brim than a full fedora."""
    pts = rotated_ellipse_points(64, 81, 38, 7, -10)
    return mask_from(lambda d: d.polygon(P(pts), fill=255))


def brim_mask_for(material):
    if material in BRIM_ELLIPSE_BBOX:
        bbox = BRIM_ELLIPSE_BBOX[material]
        return mask_from(lambda d: d.ellipse([S(v) for v in bbox], fill=255))
    if material in BRIM_ROUNDED_BBOX:
        bbox = BRIM_ROUNDED_BBOX[material]
        return mask_from(lambda d: d.rounded_rectangle([S(v) for v in bbox], radius=S(6), fill=255))
    if material == "cardboard":
        return brim_mask_cardboard()
    if material == "titanium":
        return brim_mask_titanium()
    if material == "pearl_grey":
        return brim_mask_pearl_grey()
    if material == "trilby_noir":
        return brim_mask_trilby_noir()
    raise ValueError(material)


def brim_detail(img, material):
    d = ImageDraw.Draw(img)
    if material == "pinstripe":
        d.arc([32, 76, 96, 96], start=200, end=340, fill=(8, 9, 13, 255), width=3)
    return img


def make_brim(material):
    mask = brim_mask_for(material)
    img = cut(MATERIAL_PAINT[material](), mask)
    return brim_detail(img, material)


BRIMS = {m: (lambda m=m: make_brim(m)) for m in MATERIALS}


# ================================================================== BAND (shared wrap)
BAND_BBOX = (28, 68, 100, 84)


def band_shape_mask():
    return mask_from(lambda d: d.rounded_rectangle([S(v) for v in BAND_BBOX], radius=S(6), fill=255))


def make_band_cotton(mask):
    img = cut(solid(CREAM), mask)
    d = ImageDraw.Draw(img)
    d.line([(28, 70), (100, 70)], fill=CREAM_DK, width=1)
    d.line([(28, 82), (100, 82)], fill=CREAM_DK, width=1)
    return img


def make_band_silk(mask):
    img = cut(grad(CRIMSON, CRIMSON_LT, "d"), mask)
    d = ImageDraw.Draw(img)
    d.line([(32, 83), (68, 69)], fill=(250, 225, 225, 255), width=3)
    return img


def make_band_spiked(mask):
    body = cut(solid(INK), mask)

    def f(d):
        for i in range(7):
            x = 34 + i * 10
            d.polygon([(S(x - 4), S(68)), (S(x + 4), S(68)), (S(x), S(53))], fill=255)
    spike_mask = mask_from(f)
    spikes = cut(solid(SILVER), spike_mask)
    return stack(body, spikes)


def make_band_dynamo(mask):
    img = cut(solid((18, 20, 26, 255)), mask)
    d = ImageDraw.Draw(img)
    for i in range(4):
        x = 38 + i * 14
        d.line([(x, 72), (x, 80)], fill=NEON_CYAN, width=2)
        d.line([(x - 4, 76), (x + 4, 76)], fill=NEON_CYAN, width=2)
    glow = img.filter(ImageFilter.GaussianBlur(3))
    return stack(glow, img)


def make_band_chrono(mask):
    img = cut(grad(GOLD, GOLD_LT, "h"), mask)
    face_mask = mask_from(lambda d: d.ellipse([S(56), S(66), S(72), S(82)], fill=255))
    dial = cut(solid(CHARCOAL), face_mask)
    d = ImageDraw.Draw(dial)
    d.ellipse([56, 66, 72, 82], outline=GOLD, width=1)
    d.line([(64, 74), (64, 70)], fill=GOLD, width=1)
    d.line([(64, 74), (68, 76)], fill=GOLD, width=1)
    return stack(img, dial)


def make_band_velvet_ribbon(mask):
    img = cut(grad((70, 20, 46, 255), (45, 12, 28, 255), "d"), mask)
    d = ImageDraw.Draw(img)
    d.line([(32, 83), (68, 69)], fill=(150, 65, 95, 255), width=3)
    return img


def make_band_brass_rivet(mask):
    img = cut(grad((196, 150, 70, 255), (140, 100, 40, 255), "h"), mask)
    d = ImageDraw.Draw(img)
    for x in range(36, 96, 12):
        d.ellipse([x - 2, 74, x + 2, 78], fill=(90, 62, 20, 255))
    return img


def make_band_houndstooth(mask):
    img = cut(solid((235, 232, 222, 255)), mask)
    d = ImageDraw.Draw(img)
    for i, x in enumerate(range(28, 100, 8)):
        c1 = (30, 30, 34, 255) if i % 2 == 0 else (235, 232, 222, 255)
        c2 = (235, 232, 222, 255) if i % 2 == 0 else (30, 30, 34, 255)
        d.rectangle([x, 68, x + 8, 76], fill=c1)
        d.rectangle([x, 76, x + 8, 84], fill=c2)
    return img


def make_band_neon_magenta(mask):
    img = cut(solid((20, 10, 22, 255)), mask)
    d = ImageDraw.Draw(img)
    for i in range(4):
        x = 38 + i * 14
        d.line([(x, 72), (x, 80)], fill=NEON_PINK, width=2)
        d.line([(x - 4, 76), (x + 4, 76)], fill=NEON_PINK, width=2)
    glow = img.filter(ImageFilter.GaussianBlur(3))
    return stack(glow, img)


def make_band_pearl_strand(mask):
    img = cut(solid((30, 32, 40, 255)), mask)
    d = ImageDraw.Draw(img)
    for x in range(34, 96, 9):
        d.ellipse([x - 3, 72, x + 3, 80], fill=(240, 238, 232, 255))
        d.ellipse([x - 1, 73, x + 1, 75], fill=(255, 255, 255, 255))
    return img


BANDS = {
    "cotton":        make_band_cotton,
    "silk":          make_band_silk,
    "spiked":        make_band_spiked,
    "dynamo":        make_band_dynamo,
    "chrono":        make_band_chrono,
    "velvet_ribbon": make_band_velvet_ribbon,
    "brass_rivet":   make_band_brass_rivet,
    "houndstooth":   make_band_houndstooth,
    "neon_magenta":  make_band_neon_magenta,
    "pearl_strand":  make_band_pearl_strand,
}


# ================================================================== ADD-ONS
ADDON_ANCHOR = (94, 75)


def make_addon_paperclip():
    ax, ay = ADDON_ANCHOR
    m1 = mask_from(lambda d: d.arc([S(ax - 8), S(ay - 12), S(ax + 2), S(ay + 2)], start=100, end=440, fill=255, width=S(2)))
    m2 = mask_from(lambda d: d.arc([S(ax - 4), S(ay - 9), S(ax + 6), S(ay + 5)], start=280, end=260 + 360, fill=255, width=S(2)))
    return stack(cut(solid(SILVER), m1), cut(solid(SILVER), m2))


def make_addon_playing_card():
    ax, ay = ADDON_ANCHOR
    bbox = (ax - 9, ay - 13, ax + 9, ay + 5)
    m = mask_from(lambda d: d.rounded_rectangle([S(v) for v in bbox], radius=S(2), fill=255))
    img = cut(solid(WHITE), m)
    d = ImageDraw.Draw(img)
    d.rounded_rectangle(bbox, radius=2, outline=INK, width=1)
    cx, cy = ax, ay - 4
    d.ellipse([cx - 3, cy - 3, cx + 1, cy + 1], fill=INK)
    d.ellipse([cx - 1, cy - 3, cx + 3, cy + 1], fill=INK)
    d.polygon([(cx - 3, cy - 1), (cx + 3, cy - 1), (cx, cy + 4)], fill=INK)
    d.line([(cx, cy + 4), (cx, cy + 7)], fill=INK, width=1)
    return img


def make_addon_matchstick():
    img = blank()
    d = ImageDraw.Draw(img)
    ax, ay = ADDON_ANCHOR
    d.line([(ax - 8, ay + 6), (ax + 6, ay - 10)], fill=BROWN_LT, width=3)
    d.ellipse([ax + 3, ay - 14, ax + 9, ay - 8], fill=CRIMSON)
    return img


def make_addon_fuzzy_dice():
    img = blank()
    d = ImageDraw.Draw(img)
    ax, ay = ADDON_ANCHOR
    d.line([(ax, ay - 9), (ax - 3, ay - 1)], fill=BROWN, width=1)
    d.line([(ax, ay - 9), (ax + 5, ay - 1)], fill=BROWN, width=1)
    for dx in (-6, 4):
        bbox = (ax + dx - 4, ay - 1, ax + dx + 4, ay + 7)
        m = mask_from(lambda dd, b=bbox: dd.rounded_rectangle([S(v) for v in b], radius=S(1), fill=255))
        die = cut(solid(WHITE), m)
        dd = ImageDraw.Draw(die)
        cx, cy = ax + dx, ay + 3
        for pdx, pdy in [(-1, -1), (1, 1), (0, 0)]:
            dd.ellipse([cx + pdx * 2 - 1, cy + pdy * 2 - 1, cx + pdx * 2 + 1, cy + pdy * 2 + 1], fill=INK)
        img = stack(img, die)
    return img


def make_addon_golden_coin():
    ax, ay = ADDON_ANCHOR
    bbox = (ax - 7, ay - 9, ax + 7, ay + 5)
    m = mask_from(lambda d: d.ellipse([S(v) for v in bbox], fill=255))
    img = cut(grad(GOLD_LT, GOLD, "d"), m)
    d = ImageDraw.Draw(img)
    d.ellipse(bbox, outline=(120, 90, 20, 255), width=1)
    inset = (bbox[0] + 2, bbox[1] + 2, bbox[2] - 2, bbox[3] - 2)
    d.ellipse(inset, outline=(255, 224, 140, 255), width=1)
    return img


def make_addon_feather():
    img = blank()
    d = ImageDraw.Draw(img)
    ax, ay = ADDON_ANCHOR
    d.line([(ax, ay + 6), (ax - 2, ay - 16)], fill=(230, 225, 210, 255), width=1)
    for t in range(8):
        y = ay + 4 - t * 2.5
        x = ax - t * 0.3
        col = (196, 40, 46, 255) if t % 2 == 0 else (230, 225, 210, 255)
        d.line([(x, y), (x - 5, y - 3)], fill=col, width=1)
        d.line([(x, y), (x + 4, y - 3)], fill=(230, 225, 210, 255), width=1)
    return img


def make_addon_harmonica():
    ax, ay = ADDON_ANCHOR
    bbox = (ax - 8, ay - 4, ax + 8, ay + 4)
    m = mask_from(lambda d: d.rounded_rectangle([S(v) for v in bbox], radius=S(1), fill=255))
    img = cut(solid(SILVER), m)
    d = ImageDraw.Draw(img)
    for x in range(int(bbox[0]) + 2, int(bbox[2]) - 1, 2):
        d.line([(x, bbox[1] + 1), (x, bbox[3] - 1)], fill=(60, 62, 68, 255), width=1)
    return img


def make_addon_poker_chip():
    ax, ay = ADDON_ANCHOR
    bbox = (ax - 7, ay - 8, ax + 7, ay + 6)
    m = mask_from(lambda d: d.ellipse([S(v) for v in bbox], fill=255))
    img = cut(solid(CRIMSON), m)
    d = ImageDraw.Draw(img)
    d.ellipse(bbox, outline=WHITE, width=1)
    inset = (bbox[0] + 3, bbox[1] + 3, bbox[2] - 3, bbox[3] - 3)
    d.ellipse(inset, outline=WHITE, width=1)
    return img


def make_addon_bullet_casing():
    img = blank()
    d = ImageDraw.Draw(img)
    ax, ay = ADDON_ANCHOR
    d.rectangle([ax - 3, ay - 10, ax + 3, ay + 4], fill=(196, 160, 80, 255))
    d.ellipse([ax - 3, ay + 2, ax + 3, ay + 6], fill=(140, 110, 50, 255))
    d.polygon([(ax - 3, ay - 10), (ax + 3, ay - 10), (ax, ay - 15)], fill=(210, 178, 100, 255))
    return img


def make_addon_horseshoe():
    ax, ay = ADDON_ANCHOR
    m = mask_from(lambda d: d.arc([S(ax - 8), S(ay - 9), S(ax + 8), S(ay + 7)], start=20, end=340, fill=255, width=S(3)))
    img = cut(solid(SILVER), m)
    return img


ADDONS = {
    "paperclip":     make_addon_paperclip,
    "playing_card":  make_addon_playing_card,
    "matchstick":    make_addon_matchstick,
    "fuzzy_dice":    make_addon_fuzzy_dice,
    "golden_coin":   make_addon_golden_coin,
    "feather":       make_addon_feather,
    "harmonica":     make_addon_harmonica,
    "poker_chip":    make_addon_poker_chip,
    "bullet_casing": make_addon_bullet_casing,
    "horseshoe":     make_addon_horseshoe,
}


# ================================================================== GENERATE
BAND_MASK = band_shape_mask()

for name, fn in BRIMS.items():
    save(fn(), f"{OUT}/brims/brim_{name}.png")

for name, fn in CROWNS.items():
    save(fn(), f"{OUT}/crowns/crown_{name}.png")

for name, fn in BANDS.items():
    save(fn(BAND_MASK), f"{OUT}/bands/band_{name}.png")

for name, fn in ADDONS.items():
    save(fn(), f"{OUT}/addons/addon_{name}.png")

print(f"Generated {len(BRIMS)} brims, {len(CROWNS)} crowns, {len(BANDS)} bands, {len(ADDONS)} addons")

# ------------------------------------------------------------ sample combos
# One combo per material, brim + crown always the SAME material (proving the
# match), cycling through a different band + add-on each time.
band_names = list(BANDS.keys())
addon_names = list(ADDONS.keys())
combos = [(m, m, band_names[i], addon_names[i]) for i, m in enumerate(MATERIALS)]

combo_imgs = []
for i, (b, c, bd, a) in enumerate(combos):
    brim = Image.open(f"{OUT}/brims/brim_{b}.png")
    crown = Image.open(f"{OUT}/crowns/crown_{c}.png")
    band = Image.open(f"{OUT}/bands/band_{bd}.png")
    addon = Image.open(f"{OUT}/addons/addon_{a}.png")
    combo = stack(brim, crown, band, addon)
    label = f"{b}\n{bd}+{a}"
    save(combo, f"{OUT}/previews/combos/combo_{i+1}_{b}.png")
    combo_imgs.append((combo, label))

print("Generated", len(combos), "sample combo hats (brim/crown material matched)")

# ------------------------------------------------------------ contact sheet
def label_font(size=13, bold=False):
    candidates = [
        "/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf" if bold else "/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf",
        "/usr/share/fonts/truetype/liberation/LiberationSans-Bold.ttf",
    ]
    for c in candidates:
        if os.path.exists(c):
            return ImageFont.truetype(c, size)
    return ImageFont.load_default()


FONT_TITLE = label_font(22, bold=True)
FONT_ROW   = label_font(14, bold=True)
FONT_SMALL = label_font(10)

rows = [
    ("BRIMS",  [(n, Image.open(f"{OUT}/brims/brim_{n}.png")) for n in BRIMS]),
    ("CROWNS", [(n, Image.open(f"{OUT}/crowns/crown_{n}.png")) for n in CROWNS]),
    ("BANDS",  [(n, Image.open(f"{OUT}/bands/band_{n}.png")) for n in BANDS]),
    ("ADDONS", [(n, Image.open(f"{OUT}/addons/addon_{n}.png")) for n in ADDONS]),
    ("MATCHED COMBOS (brim+crown same material)", [(lbl, img) for img, lbl in combo_imgs]),
]

CELL_W, CELL_H = 128, 158
COLS = 10
sheet_w = CELL_W * COLS + 40
sheet_h = 90 + len(rows) * (CELL_H + 30) + 20
sheet = Image.new("RGBA", (sheet_w, sheet_h), (16, 18, 26, 255))
d = ImageDraw.Draw(sheet)
d.text((20, 18), "FLY ME TO THE MOON — HAT LAYERING SYSTEM (v2)", font=FONT_TITLE, fill=GOLD)
d.text((20, 50), "10 materials shared between brim + crown, so every material matches across both layers", font=FONT_SMALL, fill=(180, 180, 190, 255))

y = 88
for row_label, cells in rows:
    d.text((20, y), row_label, font=FONT_ROW, fill=CRIMSON_LT)
    for i, (name, img) in enumerate(cells):
        x = 20 + i * CELL_W
        thumb = img.resize((100, 100), Image.LANCZOS)
        back = Image.new("RGBA", (108, 108), (40, 42, 52, 255))
        back.paste(thumb, (4, 4), thumb)
        sheet.paste(back, (x, y + 18), back)
        label_txt = name.replace("_", " ")
        if "\n" in label_txt:
            for li, line in enumerate(label_txt.split("\n")):
                d.text((x, y + 18 + 112 + li * 12), line, font=FONT_SMALL, fill=(215, 215, 220, 255))
        else:
            d.text((x, y + 18 + 112), label_txt, font=FONT_SMALL, fill=(215, 215, 220, 255))
    y += CELL_H + 30

save(sheet, f"{OUT}/previews/contact_sheet.png")
print("Saved contact sheet:", f"{OUT}/previews/contact_sheet.png")
