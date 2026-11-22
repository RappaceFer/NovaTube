"""NovaTube — identité visuelle (famille NovaTV) : icône, bannière TV, logo.  © 2026 Rappace"""
import math, os, sys, random
from PIL import Image, ImageDraw, ImageFont, ImageFilter, ImageChops

# usage : python art.py <dossier res de la surcouche> <police InterDisplay-ExtraBold.otf> [dossier aperçus]
RES = sys.argv[1]
FONT = sys.argv[2]
PREV = sys.argv[3] if len(sys.argv) > 3 else os.path.join(RES, '..', 'apercus')
MIP, MIP30 = os.path.join(RES, 'mipmap-nodpi'), os.path.join(RES, 'mipmap-nodpi-v30')
for d in (MIP, MIP30, PREV): os.makedirs(d, exist_ok=True)
OUT = MIP
SS = 4  # suréchantillonnage

BLUE, VIOLET, PINK = (111, 155, 255), (170, 108, 255), (255, 92, 154)
BG, BG2 = (6, 9, 20), (11, 16, 38)

def lerp(a, b, t): return tuple(int(round(a[i] + (b[i] - a[i]) * t)) for i in range(len(a)))
def grad3(t):  # bleu → violet → rose
    return lerp(BLUE, VIOLET, t / .5) if t < .5 else lerp(VIOLET, PINK, (t - .5) / .5)

def linear(w, h, stops, angle):
    """dégradé linéaire (stops = fonction t→couleur), angle en degrés (0 = gauche→droite)."""
    a = math.radians(angle); dx, dy = math.cos(a), math.sin(a)
    small = Image.new('RGB', (max(2, w // 8), max(2, h // 8)))
    px = small.load(); sw, sh = small.size
    cs = [(x * dx + y * dy) for x in (0, sw - 1) for y in (0, sh - 1)]
    lo, hi = min(cs), max(cs)
    for y in range(sh):
        for x in range(sw):
            px[x, y] = stops(((x * dx + y * dy) - lo) / (hi - lo))
    return small.resize((w, h), Image.BICUBIC)

def glow(img, cx, cy, r, color, alpha):
    w, h = img.size
    layer = Image.new('RGBA', (w, h), (0, 0, 0, 0))
    ImageDraw.Draw(layer).ellipse((cx - r, cy - r, cx + r, cy + r), fill=color + (alpha,))
    img.alpha_composite(layer.filter(ImageFilter.GaussianBlur(r * .55)))

def star(d, cx, cy, r, fill):
    k = r * .28
    d.polygon([(cx, cy - r), (cx + k, cy - k), (cx + r, cy), (cx + k, cy + k), (cx, cy + r), (cx - k, cy + k), (cx - r, cy), (cx - k, cy - k)], fill=fill)

def ring(size, box, width, rot, colorfn=None, color=None):
    """ellipse (contour) tournée ; couleur unie ou dégradée le long de x."""
    w, h = size
    m = Image.new('L', (w, h), 0)
    ImageDraw.Draw(m).ellipse(box, outline=255, width=width)
    m = m.rotate(rot, resample=Image.BICUBIC, center=((box[0] + box[2]) / 2, (box[1] + box[3]) / 2))
    fill = linear(w, h, colorfn, 0).convert('RGBA') if colorfn else Image.new('RGBA', (w, h), color)
    fill.putalpha(m if not color or len(color) < 4 else ImageChops.multiply(m, Image.new('L', (w, h), color[3])))
    return fill

def wordmark(height, with_star=True):
    """« Nova » blanc + « Tube » dégradé, italique, orbite et étoile — fond transparent."""
    H = height * SS
    font = ImageFont.truetype(FONT, int(H * .62))
    nova, tube = 'Nova', 'Tube'
    ln = font.getlength(nova); lt = font.getlength(tube)
    gap = int(H * .015)
    W = int(ln + gap + lt + H * .75)
    img = Image.new('RGBA', (W, H), (0, 0, 0, 0))
    x0 = int(H * .36); base_y = int(H * .5)
    txt = Image.new('RGBA', (W, H), (0, 0, 0, 0))
    ImageDraw.Draw(txt).text((x0, base_y), nova, font=font, fill=(255, 255, 255, 255), anchor='lm')
    m = Image.new('L', (W, H), 0)
    ImageDraw.Draw(m).text((x0 + ln + gap, base_y), tube, font=font, fill=255, anchor='lm')
    g = linear(W, H, lambda t: lerp(VIOLET, PINK, min(1, max(0, (t - .45) / .5))), 0).convert('RGBA'); g.putalpha(m)
    txt.alpha_composite(g)
    shear = .17   # italique comme le logo NovaTV
    txt = txt.transform((W, H), Image.AFFINE, (1, shear, -shear * H / 2, 0, 1, 0), resample=Image.BICUBIC)
    box = (int(W * .015), int(H * .07), int(W * .985), int(H * .97))
    orb = ring((W, H), box, max(2, int(H * .026)), 3.5, colorfn=grad3)
    front = orb.copy()
    # l'orbite passe devant le bas du « N » (côté gauche) et derrière le reste, comme NovaTV
    cut = Image.new('L', (W, H), 0); ImageDraw.Draw(cut).rectangle((0, int(H * .6), int(W * .34), H), fill=255)
    front.putalpha(ImageChops.multiply(front.getchannel('A'), cut))
    img.alpha_composite(orb); img.alpha_composite(txt); img.alpha_composite(front)
    if with_star:
        star(ImageDraw.Draw(img), int(W * .94), int(H * .1), int(H * .085), (255, 255, 255, 255))
    return img

# ---------- icône 320×320 : carré arrondi dégradé, orbite, triangle lecture, étoile ----------
def icon(px=320):
    S = px * SS
    base = Image.new('RGBA', (S, S), (0, 0, 0, 0))
    bg = linear(S, S, grad3, 45).convert('RGBA')
    glow(bg, int(S * .25), int(S * .22), int(S * .35), (255, 255, 255), 38)
    glow(bg, int(S * .85), int(S * .9), int(S * .4), (120, 30, 90), 90)
    mask = Image.new('L', (S, S), 0)
    pad = int(S * .04)
    ImageDraw.Draw(mask).rounded_rectangle((pad, pad, S - pad, S - pad), radius=int(S * .24), fill=255)
    base.paste(bg, (0, 0), mask)
    box = (int(S * .12), int(S * .36), int(S * .88), int(S * .70))
    base.alpha_composite(ring((S, S), box, int(S * .022), 14, color=(255, 255, 255, 140)))
    tri = Image.new('L', (S, S), 0)
    cx, cy, r = S * .515, S * .5, S * .2
    ImageDraw.Draw(tri).polygon([(cx - r * .62, cy - r), (cx + r * .98, cy), (cx - r * .62, cy + r)], fill=255)
    tri = tri.filter(ImageFilter.GaussianBlur(S * .014)).point(lambda v: 255 if v > 128 else 0)
    shadow = Image.new('RGBA', (S, S), (50, 10, 70, 0))
    shadow.putalpha(tri.filter(ImageFilter.GaussianBlur(S * .025)).point(lambda v: int(v * .35)))
    base.alpha_composite(shadow, (0, int(S * .015)))
    white = Image.new('RGBA', (S, S), (255, 255, 255, 255)); white.putalpha(tri)
    base.alpha_composite(white)
    star(ImageDraw.Draw(base), int(S * .76), int(S * .24), int(S * .075), (255, 255, 255, 255))
    return base.resize((px, px), Image.LANCZOS)

# ---------- bannière TV (écran d'accueil Fire TV / Android TV) ----------
def banner(w, h):
    W, H = w * SS, h * SS
    img = Image.new('RGBA', (W, H), BG + (255,))
    img.alpha_composite(linear(W, H, lambda t: lerp(BG, BG2, t), 30).convert('RGBA'))
    glow(img, int(W * .82), int(H * .05), int(H * .75), (60, 80, 220), 95)
    glow(img, int(W * .05), int(H * 1.05), int(H * .6), (190, 60, 170), 80)
    glow(img, int(W * .55), int(H * .55), int(H * .5), (120, 70, 255), 35)
    d = ImageDraw.Draw(img)
    random.seed(7)
    for _ in range(14):
        x, y, r = random.randint(0, W), random.randint(0, H), random.choice([SS, SS, int(SS * 1.6)])
        d.ellipse((x - r, y - r, x + r, y + r), fill=(170, 190, 255, random.randint(70, 160)))
    wm = wordmark(int(h * .62))
    sc = (W * .86) / wm.width
    wm = wm.resize((int(wm.width * sc), int(wm.height * sc)), Image.LANCZOS)
    img.alpha_composite(wm, ((W - wm.width) // 2, (H - wm.height) // 2))
    return img.resize((w, h), Image.LANCZOS)

# ---------- logo du coin de l'écran d'accueil (fond transparent) ----------
def logo(w, h, mono=False):
    W, H = w * SS, h * SS
    img = Image.new('RGBA', (W, H), (0, 0, 0, 0))
    wm = wordmark(int(h * .9))
    if mono:
        a = wm.getchannel('A'); wm = Image.new('RGBA', wm.size, (220, 220, 230, 255)); wm.putalpha(a)
    sc = min((W * .96) / wm.width, (H * .9) / wm.height)
    wm = wm.resize((int(wm.width * sc), int(wm.height * sc)), Image.LANCZOS)
    img.alpha_composite(wm, ((W - wm.width) // 2, (H - wm.height) // 2))
    return img.resize((w, h), Image.LANCZOS)

ic = icon(320)
for p in (os.path.join(MIP, 'app_icon.png'), os.path.join(MIP, 'app_icon_alt.png'), os.path.join(MIP30, 'app_icon.png')):
    ic.save(p, optimize=True)
icon(512).save(os.path.join(PREV, 'icone_512.png'), optimize=True)
banner(640, 360).save(os.path.join(MIP, 'app_banner.png'), optimize=True)
banner(1280, 720).save(os.path.join(PREV, 'banniere_1280.png'), optimize=True)
logo(320, 180).save(os.path.join(MIP, 'app_logo.png'), optimize=True)
logo(320, 180).save(os.path.join(MIP, 'app_logo_semi_red.png'), optimize=True)
logo(320, 180, mono=True).save(os.path.join(MIP, 'app_logo_semi_grey.png'), optimize=True)
print('ok', sorted(os.listdir(MIP)), sorted(os.listdir(MIP30)))
