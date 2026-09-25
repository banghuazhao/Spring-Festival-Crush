import math
from PIL import Image, ImageDraw, ImageFilter, ImageChops
S = 1024
C = S / 2

def arc_poly(start, sweep, r, thick, head_deg=0, head_w=0, steps=80):
    body = sweep - head_deg
    out, inn = [], []
    for i in range(steps + 1):
        a = math.radians(start + body * i / steps)
        out.append((C + (r + thick / 2) * math.cos(a), C - (r + thick / 2) * math.sin(a)))
        inn.append((C + (r - thick / 2) * math.cos(a), C - (r - thick / 2) * math.sin(a)))
    pts = out
    if head_deg:
        ab = math.radians(start + body); at = math.radians(start + sweep)
        pts = out + [(C + (r + head_w / 2) * math.cos(ab), C - (r + head_w / 2) * math.sin(ab)),
                     (C + r * math.cos(at), C - r * math.sin(at)),
                     (C + (r - head_w / 2) * math.cos(ab), C - (r - head_w / 2) * math.sin(ab))]
    return pts + list(reversed(inn))

def mask(poly, blur=0, offset=(0, 0)):
    m = Image.new("L", (S, S), 0)
    ImageDraw.Draw(m).polygon([(x + offset[0], y + offset[1]) for x, y in poly], fill=255)
    return m.filter(ImageFilter.GaussianBlur(blur)) if blur else m

def solid(color):
    return Image.new("RGBA", (S, S), color)

def arrow(img, start, dark, base, mid, light):
    R, T, HD, HW = 285, 190, 46, 350
    poly = arc_poly(start, 152, R, T, HD, HW)
    shape = mask(poly)
    # Contact shadow.
    img.alpha_composite(Image.composite(solid((70, 20, 10, 130)), solid((0, 0, 0, 0)), mask(poly, 16, (8, 24))))
    # Rim (dark), then a lit body inset upward, then a glossy highlight streak.
    img.alpha_composite(Image.composite(solid(dark), solid((0, 0, 0, 0)), shape))
    body = ImageChops.multiply(shape, mask(poly, 0, (0, -10)))
    body = body.filter(ImageFilter.GaussianBlur(3))
    body = ImageChops.multiply(body, mask(arc_poly(start + 1, 150, R, T - 26, HD - 2, HW - 44)))
    img.alpha_composite(Image.composite(solid(base), solid((0, 0, 0, 0)), body))
    groove = ImageChops.multiply(shape, mask(arc_poly(start + 8, 110, R - 10, 16)).filter(ImageFilter.GaussianBlur(2)))
    img.alpha_composite(Image.composite(solid(mid), solid((0, 0, 0, 0)), groove))
    shine = ImageChops.multiply(shape, mask(arc_poly(start + 10, 105, R + 52, 30), 7))
    img.alpha_composite(Image.composite(solid(light), solid((0, 0, 0, 0)), shine))

img = Image.new("RGBA", (S, S), (0, 0, 0, 0))
arrow(img, 18, (16, 86, 74, 255), (40, 170, 144, 255), (22, 118, 100, 255), (205, 255, 236, 210))
arrow(img, 198, (150, 82, 16, 255), (255, 192, 58, 255), (205, 132, 30, 255), (255, 246, 200, 230))
d = ImageDraw.Draw(img)
k = 74
shadow = Image.new("RGBA", (S, S), (0, 0, 0, 0))
sd = ImageDraw.Draw(shadow)
for dx, dy in [(-k, 0), (k, 0), (0, -k), (0, k)]:
    sd.ellipse([C + dx - 84 + 6, C + dy - 84 + 18, C + dx + 84 + 6, C + dy + 84 + 18], fill=(70, 20, 10, 120))
img.alpha_composite(shadow.filter(ImageFilter.GaussianBlur(12)))
for dx, dy in [(-k, 0), (k, 0), (0, -k), (0, k)]:
    d.ellipse([C + dx - 84, C + dy - 84, C + dx + 84, C + dy + 84], fill=(130, 26, 22, 255))
for dx, dy in [(-k, 0), (k, 0), (0, -k), (0, k)]:
    d.ellipse([C + dx - 68, C + dy - 72, C + dx + 68, C + dy + 64], fill=(222, 62, 50, 255))
for dx, dy in [(-k, 0), (k, 0), (0, -k), (0, k)]:
    d.ellipse([C + dx - 40, C + dy - 58, C + dx + 10, C + dy - 30], fill=(255, 150, 130, 160))
d.ellipse([C - 58, C - 58, C + 58, C + 58], fill=(160, 90, 18, 255))
d.ellipse([C - 48, C - 52, C + 48, C + 44], fill=(255, 201, 71, 255))
d.ellipse([C - 30, C - 42, C + 6, C - 16], fill=(255, 248, 214, 230))
out = img.resize((256, 256), Image.LANCZOS)
out.save("SwapBoosterIcon.png", optimize=True)
h=Image.open('/home/user/Spring-Festival-Crush/SpringFestivalCrush/Assets.xcassets/HammerBoosterIcon.imageset/HammerBoosterIcon.png'); s=Image.open('/home/user/Spring-Festival-Crush/SpringFestivalCrush/Assets.xcassets/ShuffleBoosterIcon.imageset/ShuffleBoosterIcon.png')
bg=Image.new('RGBA',(800,280),(216,58,49,255))
for i,im in enumerate([h,s,out]): bg.alpha_composite(im.convert('RGBA'),(10+i*265,12))
small=Image.new('RGBA',(160,50),(216,58,49,255))
for i,im in enumerate([h,s,out]): small.alpha_composite(im.convert('RGBA').resize((36,36),Image.LANCZOS),(10+i*50,7))
bg.alpha_composite(small.resize((320,100)),(470,175)) if False else None
bg.save('compare.png'); small.resize((480,150),Image.NEAREST).save('compare_small.png')
