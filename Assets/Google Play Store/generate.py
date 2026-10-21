#!/usr/bin/env python3
"""Renders the Google Play listing graphics from the icon geometry and the raw
captures in Assets/Screenshots/Android/Store.

Usage: python3 generate.py <path to RobotoFlex-Regular.ttf>
(pull it from any Android 16 device: adb pull /system/fonts/RobotoFlex-Regular.ttf)

Needs Pillow. SF Pro is not used: its licence covers Apple platforms only.
"""
import os
import sys

from PIL import Image, ImageChops, ImageDraw, ImageFilter, ImageFont

HERE = os.path.dirname(os.path.abspath(__file__))
RAW = os.path.join(HERE, "..", "Screenshots", "Android", "Store")
FONT = sys.argv[1]

# The icon's gradient, as in Android/app/src/main/res/drawable/ic_launcher_background.xml.
TOP = (0x63, 0xBC, 0xFF)
BOTTOM = (0x4D, 0xA3, 0xEB)
WHITE = (255, 255, 255)
SS = 4  # supersampling for the vector artwork


def font(size, weight):
    f = ImageFont.truetype(FONT, size)
    axes = [a["default"] for a in f.get_variation_axes()]
    axes[0], axes[1] = min(144, max(8, size)), weight  # opsz, wght
    f.set_variation_by_axes(axes)
    return f


def gradient(w, h, top=TOP, bottom=BOTTOM):
    col = Image.new("RGB", (1, h))
    for y in range(h):
        t = y / max(1, h - 1)
        col.putpixel((0, y), tuple(round(a + (b - a) * t) for a, b in zip(top, bottom)))
    return col.resize((w, h))


def vgradient_mask(w, h, y0, y1, a0, a1):
    """Alpha ramp from a0 at y0 to a1 at y1 (0..1), clamped outside."""
    col = Image.new("L", (1, h))
    for y in range(h):
        t = min(1, max(0, (y - y0) / max(1, y1 - y0)))
        col.putpixel((0, y), round(255 * (a0 + (a1 - a0) * t)))
    return col.resize((w, h))


def glyph(size):
    """The file-in-folder glyph from Apple/Wooosh/AppIcon.icon on a 1024 canvas,
    drawn flat the way the Android launcher icon is. Returns an RGBA white layer."""
    n = size * SS
    k = n / 1024

    def s(*v):
        return [round(x * k) for x in v]

    def rr(box, r):
        m = Image.new("L", (n, n))
        ImageDraw.Draw(m).rounded_rectangle(s(*box), radius=round(r * k), fill=255)
        return m

    back = ImageChops.lighter(rr((252, 348, 772, 756), 48), rr((252, 300, 472, 420), 36))
    # The file's top right corner is a straight 45 degree cut, not rounded.
    corner = Image.new("L", (n, n))
    ImageDraw.Draw(corner).polygon(s(552, 200, 720, 200, 720, 368), fill=255)
    file_ = ImageChops.subtract(rr((368, 220, 656, 520), 36), corner)
    front = rr((252, 428, 772, 756), 48)

    # Launchers have no glass, so the file stops at the front panel's top edge and a
    # fading glow stands in for the part the panel would frost.
    edge = round(428 * k)
    above = ImageChops.multiply(file_, vgradient_mask(n, n, edge - 1, edge, 1, 0))
    glow = ImageChops.multiply(file_, vgradient_mask(n, n, edge, round(520 * k), 0.4, 0.0))
    glow = ImageChops.multiply(glow, vgradient_mask(n, n, edge - 1, edge, 0, 1))

    out = Image.new("RGBA", (n, n), WHITE + (0,))

    def over(mask):
        layer = Image.new("RGBA", (n, n), WHITE + (0,))
        layer.putalpha(mask)
        out.alpha_composite(layer)

    over(back.point(lambda v: round(v * 0.25)))
    over(ImageChops.lighter(above, glow))
    over(ImageChops.multiply(front, vgradient_mask(n, n, round(428 * k), round(756 * k), 0.42, 0.22)))
    return out.resize((size, size), Image.LANCZOS)


def icon():
    im = gradient(512, 512).convert("RGBA")
    im.alpha_composite(glyph(512))
    # Play applies its own mask and shadow: full-bleed square, no alpha.
    im.convert("RGB").save(os.path.join(HERE, "Icon-512.png"))


def text_center(d, cx, y, s, f, fill=WHITE):
    w = d.textlength(s, font=f)
    d.text((cx - w / 2, y), s, font=f, fill=fill)


def feature_graphic():
    w, h = 1024, 500
    im = gradient(w, h).convert("RGBA")
    # A large, faint copy of the glyph bleeds off the right edge for depth.
    big = glyph(760)
    faint = big.copy()
    faint.putalpha(big.getchannel("A").point(lambda v: round(v * 0.22)))
    im.alpha_composite(faint, (560, -150))
    im.alpha_composite(glyph(300), (40, 100))
    d = ImageDraw.Draw(im)
    d.text((330, 150), "Send", font=font(112, 700), fill=WHITE)
    d.text((336, 290), "Encrypted file sharing between", font=font(34, 500), fill=WHITE)
    d.text((336, 334), "your devices. No accounts.", font=font(34, 500), fill=WHITE)
    im.convert("RGB").save(os.path.join(HERE, "Feature-Graphic-1024x500.png"))


def phone_shot(raw, caption, sub, out, dark=False):
    # 9:16 at 1440x2560: Play rejects the device's own 1080x2424 (wider than 2:1).
    W, H = 1440, 2560
    bg = gradient(W, H, (0x2C, 0x4A, 0x6E), (0x14, 0x22, 0x36)) if dark else gradient(W, H)
    im = bg.convert("RGBA")
    d = ImageDraw.Draw(im)
    lines = caption.split("\n")
    y = 170
    for line in lines:
        text_center(d, W / 2, y, line, font(104, 750))
        y += 124
    if sub:
        text_center(d, W / 2, y + 26, sub, font(50, 450), (255, 255, 255))
    top = 600

    # The whole screen stays visible: the offer sheet's buttons sit at the very bottom.
    shot = Image.open(raw).convert("RGBA")
    bezel = 18
    sh = H - top - 90 - 2 * bezel
    sw = round(shot.width * sh / shot.height)
    shot = shot.resize((sw, sh), Image.LANCZOS)
    fw, fh = sw + 2 * bezel, shot.height + 2 * bezel
    fx = (W - fw) // 2

    shadow = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    ImageDraw.Draw(shadow).rounded_rectangle((fx, top + 30, fx + fw, top + fh + 30), 96, fill=(0, 30, 60, 110))
    im.alpha_composite(shadow.filter(ImageFilter.GaussianBlur(40)))

    frame = Image.new("RGBA", (fw, fh), (0, 0, 0, 0))
    ImageDraw.Draw(frame).rounded_rectangle((0, 0, fw - 1, fh - 1), 96, fill=(22, 24, 28, 255))
    mask = Image.new("L", shot.size)
    ImageDraw.Draw(mask).rounded_rectangle((0, 0, sw - 1, shot.height - 1), 80, fill=255)
    frame.paste(shot, (bezel, bezel), mask)
    im.alpha_composite(frame, (fx, top))
    im.convert("RGB").save(out)


SHOTS = [
    ("list-light.png", "Send to Devices\nNearby", "Phones, tablets, and computers on your Wi-Fi.", False),
    ("offer-light.png", "You Decide What\nComes In", "Nothing arrives until you accept it.", False),
    ("transfer-light.png", "Fast, Even for\nHuge Files", "Straight from device to device.", False),
    ("pair-light.png", "Pair Once with\na QR Code", "Every transfer after that is verified.", False),
    ("list-dark.png", "Android, iPhone,\nMac, and Windows", "One way to share across all of them.", True),
    ("settings-light.png", "No Accounts.\nNo Cloud Storage.", "You choose who can see your device.", False),
]


def main():
    icon()
    feature_graphic()
    for i, (raw, cap, sub, dark) in enumerate(SHOTS, 1):
        name = os.path.splitext(raw)[0]
        phone_shot(os.path.join(RAW, raw), cap, sub,
                   os.path.join(HERE, "Screenshots", f"{i:02d}-{name}.png"), dark)


if __name__ == "__main__":
    main()
