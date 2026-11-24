# Genera las imágenes del tema Txcmatheo para el fork de Veyra.
# Uso: python -I make_txc_assets.py <carpeta qml/Veyra> <logo txcmatheo png>
import sys, math
from PIL import Image, ImageDraw, ImageFont, ImageFilter, ImageChops

out = sys.argv[1].rstrip("/\\") + "/"
logo_src = Image.open(sys.argv[2]).convert("RGB")
BLACK = "C:/Windows/Fonts/seguibl.ttf"

def hexrgb(h):
    h = h.lstrip("#"); return tuple(int(h[i:i + 2], 16) for i in (0, 2, 4))

def lerp(a, b, t):
    return tuple(int(round(a[i] + (b[i] - a[i]) * t)) for i in range(len(a)))

def vgradient(size, stops):
    w, h = size
    col = Image.new("RGB", (1, h))
    px = col.load()
    for y in range(h):
        t = y / max(1, h - 1)
        for i in range(len(stops) - 1):
            p0, c0 = stops[i]; p1, c1 = stops[i + 1]
            if p0 <= t <= p1:
                px[0, y] = lerp(hexrgb(c0), hexrgb(c1), (t - p0) / max(1e-6, p1 - p0)); break
    return col.resize((w, h))

def recolor_alpha(img, color_img):
    """Mantiene el alfa de img y pinta con color_img."""
    a = img.convert("RGBA").getchannel("A")
    c = color_img.convert("RGBA").resize(img.size)
    c.putalpha(a)
    return c

def rounded_mask(size, r):
    m = Image.new("L", size, 0)
    ImageDraw.Draw(m).rounded_rectangle([0, 0, size[0] - 1, size[1] - 1], r, fill=255)
    return m

# ---------------------------------------------------------------- fondos (backdrop)
def backdrop(strength):
    w, h = 1280, 800
    base = vgradient((w, h), [(0, "#0D0D11"), (0.55, "#121216"), (1, "#17141F")]).convert("RGB")
    glow = Image.new("L", (w, h), 0)
    d = ImageDraw.Draw(glow)
    d.ellipse([w * 0.05, h * 0.62, w * 0.95, h * 1.45], fill=255)
    d.ellipse([-w * 0.2, -h * 0.55, w * 0.45, h * 0.25], fill=110)
    glow = glow.filter(ImageFilter.GaussianBlur(170))
    purple = Image.new("RGB", (w, h), hexrgb("#9346DC"))
    alpha = glow.point(lambda v: int(v * strength))
    return Image.composite(purple, base, alpha)

backdrop(0.28).save(out + "backdrop-dusk.png")
backdrop(0.45).save(out + "backdrop-dusk-strong.png")

# ---------------------------------------------------------------- logo (inicio)
def logo_canvas(cw, ch, box):
    canvas = Image.new("RGBA", (cw, ch), (0, 0, 0, 0))
    icon = logo_src.resize((box, box), Image.LANCZOS).convert("RGBA")
    icon.putalpha(rounded_mask((box, box), int(box * 0.22)))
    x, y = (cw - box) // 2, (ch - box) // 2
    glow = Image.new("RGBA", (cw, ch), (0, 0, 0, 0))
    gm = Image.new("L", (cw, ch), 0)
    ImageDraw.Draw(gm).rounded_rectangle([x, y, x + box, y + box], int(box * 0.22), fill=200)
    gm = gm.filter(ImageFilter.GaussianBlur(box * 0.09))
    glow = Image.new("RGBA", (cw, ch), hexrgb("#B06CFF") + (0,))
    glow.putalpha(gm)
    canvas.alpha_composite(glow)
    canvas.alpha_composite(icon, (x, y))
    return canvas

logo_canvas(720, 480, 380).save(out + "logo-dusk.png")
logo_canvas(360, 240, 190).save(out + "logo.png")

# ---------------------------------------------------------------- wordmark en capas
W, H = 1164, 969

def text_mask(text, font_px, xy, anchor="la"):
    m = Image.new("L", (W, H), 0)
    f = ImageFont.truetype(BLACK, font_px)
    ImageDraw.Draw(m).text(xy, text, font=f, fill=255, anchor=anchor)
    return m

def fit_font(text, width):
    lo, hi = 20, 900
    while lo < hi:
        mid = (lo + hi + 1) // 2
        f = ImageFont.truetype(BLACK, mid)
        b = f.getbbox(text)
        if b[2] - b[0] <= width: lo = mid
        else: hi = mid - 1
    return lo

def layer_from_mask(mask, fill_img):
    """Capa de 'papel': relleno recortado por la máscara + sombra suave debajo."""
    layer = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    sh = mask.filter(ImageFilter.GaussianBlur(14)).point(lambda v: int(v * 0.55))
    shadow = Image.new("RGBA", (W, H), (6, 4, 12, 0)); shadow.putalpha(sh)
    layer.alpha_composite(shadow, (0, 10))
    f = fill_img.convert("RGBA").resize((W, H)); f.putalpha(mask)
    layer.alpha_composite(f)
    return layer

# Arriba: "Txcmatheo" (la capa delantera, en el sitio de "Veyra")
top_text = "Txcmatheo"
fs_top = fit_font(top_text, 1108)
ft = ImageFont.truetype(BLACK, fs_top)
bt = ft.getbbox(top_text)
top_h = bt[3] - bt[1]
# Abajo: "VISION" en Bahnschrift Bold Condensed, estirada para llenar la caja como el "NR" original,
# partida en dos capas ("VIS" detrás, "ION" en medio)
BAHN = "C:/Windows/Fonts/bahnschrift.ttf"
def bahn(px):
    f = ImageFont.truetype(BAHN, px); f.set_variation_by_name("Bold Condensed"); return f
fb = bahn(600)
bb = fb.getbbox("VISION")
big = (bb[2] + 40, bb[3] + 40)
def big_mask(text):
    m = Image.new("L", big, 0)
    ImageDraw.Draw(m).text((0, 0), text, font=fb, fill=255)
    return m.crop(bb)
mb_full = big_mask("VISION")
mb_vis = big_mask("VIS")
mb_ion = ImageChops.subtract(mb_full, mb_vis)
margin, gap = 28, 52
top_h_target = top_h
bot_w = W - 2 * margin
natural = bot_w * mb_full.height / mb_full.width
bot_h = int(min(H - 2 * margin - top_h - gap, natural * 1.3))
margin_y = (H - top_h - gap - bot_h) // 2
def place(m):
    canvas = Image.new("L", (W, H), 0)
    canvas.paste(m.resize((bot_w, bot_h), Image.LANCZOS), (margin, margin_y + top_h + gap))
    return canvas
m_vis = place(mb_vis)
m_ion = place(mb_ion)
bot_y = margin_y + top_h + gap
top_xy = ((W - (bt[2] - bt[0])) // 2 - bt[0], margin_y - bt[1])
m_top = text_mask(top_text, fs_top, top_xy)

top_fill = vgradient((W, H), [(0, "#7C4DFF"), (0.25, "#A35BE6"), (0.45, "#E08CFF"), (1, "#E08CFF")])
# Las letras grandes llevan el logo dentro (como las palmeras en el original)
box = int(bot_h * 1.15)
logo_big = logo_src.resize((box, box), Image.LANCZOS)
bot_fill = vgradient((W, H), [(0, "#4A22A0"), (1, "#7E3AD8")])
lx = (W - box) // 2
ly = bot_y + bot_h // 2 - box // 2
bot_fill.paste(logo_big, (lx, ly))

l_vis = layer_from_mask(m_vis, bot_fill)
l_ion = layer_from_mask(m_ion, bot_fill)
l_top = layer_from_mask(m_top, top_fill)
l_vis.save(out + "wordmark-dusk-n.png")
l_ion.save(out + "wordmark-dusk-r.png")
l_top.save(out + "wordmark-dusk-veyra.png")

full = Image.new("RGBA", (W, H), (0, 0, 0, 0))
for l in (l_vis, l_ion, l_top):
    full.alpha_composite(l)
full.save(out + "wordmark-dusk.png")

# Brillo: la caja del wordmark crecida 186/1164 por lado, a media escala
pad = 186
g = Image.new("RGBA", (W + 2 * pad, H + 2 * pad), (0, 0, 0, 0))
g.alpha_composite(full, (pad, pad))
a = g.getchannel("A").filter(ImageFilter.GaussianBlur(46))
gc = Image.new("RGBA", g.size, hexrgb("#B06CFF") + (0,)); gc.putalpha(a.point(lambda v: min(255, int(v * 1.6))))
gc.resize((768, 670), Image.LANCZOS).save(out + "wordmark-dusk-glow.png")

# ---------------------------------------------------------------- intro: sol, brillo, horizonte
sun = Image.open(out + "intro-sun.png")
recolor_alpha(sun, vgradient(sun.size, [(0, "#F4E4FF"), (0.5, "#C58BFF"), (1, "#7C3FD6")])).save(out + "intro-sun.png")
sg = Image.open(out + "intro-sun-glow.png")
recolor_alpha(sg, Image.new("RGB", sg.size, hexrgb("#A35BE6"))).save(out + "intro-sun-glow.png")
hz = Image.open(out + "intro-horizon.png")
recolor_alpha(hz, Image.new("RGB", hz.size, hexrgb("#D9B0FF"))).save(out + "intro-horizon.png")
print("ok", fs_top, top_h, bot_h)
