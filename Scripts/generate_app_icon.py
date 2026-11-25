#!/usr/bin/env python3
"""Generate crisp 1024x1024 AppIcon and LaunchBg Assets.xcassets for FlatShift.
Design: Midnight Indigo (#131B2E) precision shift-clock & color-coded calendar badge
with Electric Cobalt (#2563EB), Shift Mint (#10B981), and Overtime Amber (#F59E0B) accents."""
from __future__ import annotations

import json
import math
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parent.parent
ASSETS = ROOT / "Resources" / "Assets.xcassets"


def draw_icon(out_png: Path) -> None:
    S = 1024
    # Deep Midnight Indigo gradient canvas
    img = Image.new("RGB", (S, S), (19, 27, 46))
    draw = ImageDraw.Draw(img)

    # Smooth subtle radial depth
    for i in range(28):
        inset = i * 16
        r = max(11, 19 + int((28 - i) * 0.45))
        g = max(17, 27 + int((28 - i) * 0.65))
        b = max(32, 46 + int((28 - i) * 1.15))
        draw.rounded_rectangle([inset, inset, S - inset, S - inset], radius=max(40, 220 - i * 4), fill=(r, g, b))

    # Subtle precision time-grid lines
    grid_col = (31, 45, 74)
    for g in range(128, S, 128):
        draw.line([(g, 0), (g, S)], fill=grid_col, width=2)
        draw.line([(0, g), (S, g)], fill=grid_col, width=2)

    # Calendar / Shift Card base with soft shadow
    draw.rounded_rectangle([168, 178, 846, 856], radius=108, fill=(8, 13, 24))
    card = [152, 152, 830, 830]
    draw.rounded_rectangle(card, radius=104, fill=(244, 247, 252))

    # Electric Cobalt top calendar header bar
    draw.rounded_rectangle([152, 152, 830, 326], radius=104, fill=(37, 99, 235))
    draw.rectangle([152, 250, 830, 326], fill=(37, 99, 235))

    # Two metallic calendar binder rings
    for rx in (322, 660):
        draw.rounded_rectangle([rx - 26, 108, rx + 26, 224], radius=24, fill=(19, 27, 46))
        draw.rounded_rectangle([rx - 14, 120, rx + 14, 212], radius=14, fill=(226, 232, 240))

    # 3x2 Color-Coded Shift Pills inside Calendar Card (DAY Mint, NIGHT Indigo/Violet, OT Amber)
    pill_rows = [
        [(204, 376, 376, 462, (16, 185, 129)), (404, 376, 576, 462, (16, 185, 129)), (604, 376, 776, 462, (124, 58, 237))],
        [(204, 492, 376, 578, (124, 58, 237)), (404, 492, 576, 578, (245, 158, 11)), (604, 492, 776, 578, (203, 213, 225))],
    ]
    for row in pill_rows:
        for x0, y0, x1, y1, col in row:
            draw.rounded_rectangle([x0, y0, x1, y1], radius=26, fill=col)
            # Crisp inner white bar representing shift hours
            draw.rounded_rectangle([x0 + 26, y0 + 34, x1 - 44, y0 + 52], radius=9, fill=(255, 255, 255))

    # Bottom Pay / Hours Summary Strip on card
    draw.rounded_rectangle([204, 628, 608, 768], radius=32, fill=(226, 232, 240))
    draw.rounded_rectangle([236, 664, 410, 692], radius=12, fill=(19, 27, 46))
    draw.rounded_rectangle([236, 710, 514, 738], radius=12, fill=(37, 99, 235))

    # Overlapping Precision Shift-Clock + Overtime Arc Badge (bottom-right)
    cx, cy, r = 720, 720, 188
    # Outer cutout ring matching background indigo
    draw.ellipse([cx - r - 20, cy - r - 20, cx + r + 20, cy + r + 20], fill=(19, 27, 46))
    # Clock dial face
    draw.ellipse([cx - r, cy - r, cx + r, cy + r], fill=(19, 27, 46))
    # Subtle inner face
    draw.ellipse([cx - r + 22, cy - r + 22, cx + r - 22, cy + r - 22], fill=(27, 39, 66))

    # Shift Mint regular arc (12 o'clock to 8 o'clock = 240 deg) and Overtime Amber arc (8 o'clock to 11 o'clock)
    arc_box = [cx - r + 14, cy - r + 14, cx + r - 14, cy + r - 14]
    draw.arc(arc_box, start=-90, end=145, fill=(16, 185, 129), width=26)
    draw.arc(arc_box, start=155, end=258, fill=(245, 158, 11), width=26)

    # 12 crisp clock ticks
    for t in range(12):
        ang = math.radians(t * 30 - 90)
        r_out = r - 48
        r_in = r - (72 if t % 3 == 0 else 60)
        x0, y0 = cx + r_in * math.cos(ang), cy + r_in * math.sin(ang)
        x1, y1 = cx + r_out * math.cos(ang), cy + r_out * math.sin(ang)
        draw.line([(x0, y0), (x1, y1)], fill=(226, 232, 240) if t % 3 == 0 else (100, 116, 139), width=9 if t % 3 == 0 else 5)

    # Clock hands (clean 10:10 / active shift angle)
    # Hour hand
    h_ang = math.radians(-140)
    draw.line([(cx, cy), (cx + 76 * math.cos(h_ang), cy + 76 * math.sin(h_ang))], fill=(255, 255, 255), width=18)
    draw.ellipse([cx + 76 * math.cos(h_ang) - 9, cy + 76 * math.sin(h_ang) - 9, cx + 76 * math.cos(h_ang) + 9, cy + 76 * math.sin(h_ang) + 9], fill=(255, 255, 255))
    # Minute hand
    m_ang = math.radians(-30)
    draw.line([(cx, cy), (cx + 106 * math.cos(m_ang), cy + 106 * math.sin(m_ang))], fill=(245, 158, 11), width=14)
    draw.ellipse([cx + 106 * math.cos(m_ang) - 7, cy + 106 * math.sin(m_ang) - 7, cx + 106 * math.cos(m_ang) + 7, cy + 106 * math.sin(m_ang) + 7], fill=(245, 158, 11))
    # Center pin
    draw.ellipse([cx - 18, cy - 18, cx + 18, cy + 18], fill=(255, 255, 255))
    draw.ellipse([cx - 8, cy - 8, cx + 8, cy + 8], fill=(37, 99, 235))

    out_png.parent.mkdir(parents=True, exist_ok=True)
    img.save(out_png, "PNG")


def main() -> None:
    ASSETS.mkdir(parents=True, exist_ok=True)
    (ASSETS / "Contents.json").write_text(json.dumps({"info": {"author": "xcode", "version": 1}}, indent=2))

    icon_dir = ASSETS / "AppIcon.appiconset"
    icon_dir.mkdir(parents=True, exist_ok=True)
    icon_png = icon_dir / "AppIcon-1024.png"
    draw_icon(icon_png)
    (icon_dir / "Contents.json").write_text(json.dumps({
        "images": [{"filename": "AppIcon-1024.png", "idiom": "universal", "platform": "ios", "size": "1024x1024"}],
        "info": {"author": "xcode", "version": 1},
    }, indent=2))

    launch_dir = ASSETS / "LaunchBg.colorset"
    launch_dir.mkdir(parents=True, exist_ok=True)
    (launch_dir / "Contents.json").write_text(json.dumps({
        "colors": [
            {
                "color": {
                    "color-space": "srgb",
                    "components": {"alpha": "1.000", "blue": "0.980", "green": "0.965", "red": "0.957"},
                },
                "idiom": "universal",
            },
            {
                "appearances": [{"appearance": "luminosity", "value": "dark"}],
                "color": {
                    "color-space": "srgb",
                    "components": {"alpha": "1.000", "blue": "0.180", "green": "0.106", "red": "0.075"},
                },
                "idiom": "universal",
            },
        ],
        "info": {"author": "xcode", "version": 1},
    }, indent=2))

    docs_icon = ROOT / "docs" / "icon.png"
    docs_icon.parent.mkdir(parents=True, exist_ok=True)
    Image.open(icon_png).resize((512, 512), Image.Resampling.LANCZOS).save(docs_icon, "PNG")
    print(f"✓ Generated {icon_png} and {docs_icon}")


if __name__ == "__main__":
    main()
