#!/usr/bin/env python3
"""Boot dedicated iOS Simulators, capture real FlatShift native UI screenshots (EN + ZH),
and frame them into App Store 6.5" iPhone (1284x2778) and 13" iPad (2064x2752) showcases."""
from __future__ import annotations

import subprocess
import time
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont, ImageStat

ROOT = Path(__file__).resolve().parent.parent
DERIVED = ROOT / "build" / "SimDerived"
RAW_DIR = ROOT / "build" / "raw_screens"
OUT_ROOT = Path("/Users/wang/OPC/media/20261125-flatshift/appstore")

# Dedicated simulators (isolated to avoid parallel collisions)
IPHONE_UDID = "15A596B0-664F-4DE4-B7E8-38F9CEAF9C32"  # iPhone 18 Pro
IPAD_UDID = "2ACC9587-CBD7-4596-BB8F-A713E323B149"    # iPad Air 13-inch (M4)
BUNDLE_ID = "com.yanghe.flatshift"

FONT_CN = "/System/Library/Fonts/Hiragino Sans GB.ttc"
FONT_CN_FALLBACK = "/System/Library/Fonts/STHeiti Medium.ttc"
FONT_EN = "/System/Library/Fonts/Supplemental/Arial Bold.ttf"


def load_font(size: int, bold: bool = True, cn: bool = False) -> ImageFont.FreeTypeFont:
    if cn:
        if Path(FONT_CN).exists():
            try:
                return ImageFont.truetype(FONT_CN, size=size, index=2 if bold else 0)
            except Exception:
                return ImageFont.truetype(FONT_CN, size=size, index=0)
        return ImageFont.truetype(FONT_CN_FALLBACK, size=size, index=0)
    if Path(FONT_EN).exists():
        return ImageFont.truetype(FONT_EN, size=size)
    return ImageFont.truetype(FONT_CN, size=size, index=2 if bold else 0)


def run(cmd: list[str], check: bool = True) -> subprocess.CompletedProcess:
    return subprocess.run(cmd, check=check, capture_output=True, text=True)


def build_sim_app() -> Path:
    print("[1/4] Building FlatShift for iOS Simulator...")
    subprocess.run([
        "xcodebuild",
        "-project", str(ROOT / "FlatShift.xcodeproj"),
        "-scheme", "FlatShift",
        "-configuration", "Debug",
        "-destination", f"platform=iOS Simulator,id={IPHONE_UDID}",
        "-derivedDataPath", str(DERIVED),
        "CODE_SIGNING_ALLOWED=NO",
        "build",
    ], check=True)
    app_path = DERIVED / "Build" / "Products" / "Debug-iphonesimulator" / "FlatShift.app"
    if not app_path.exists():
        raise RuntimeError(f"Built app not found at {app_path}")
    return app_path


def capture_device_screens(udid: str, app_path: Path, device_tag: str, screens: list[str], langs: list[str]) -> dict[tuple[str, str], Path]:
    print(f"[2/4] Booting simulator {device_tag} ({udid})...")
    run(["xcrun", "simctl", "boot", udid], check=False)
    run(["xcrun", "simctl", "bootstatus", udid, "-b"])
    run(["xcrun", "simctl", "status_bar", udid, "override", "--time", "9:41", "--batteryState", "charged", "--batteryLevel", "100", "--wifiBars", "3", "--cellularBars", "4"], check=False)
    run(["xcrun", "simctl", "uninstall", udid, BUNDLE_ID], check=False)
    run(["xcrun", "simctl", "install", udid, str(app_path)])

    captured: dict[tuple[str, str], Path] = {}
    RAW_DIR.mkdir(parents=True, exist_ok=True)

    for lang in langs:
        # Reset app container between languages so starter samples match language cleanly
        run(["xcrun", "simctl", "uninstall", udid, BUNDLE_ID], check=False)
        run(["xcrun", "simctl", "install", udid, str(app_path)])
        for screen in screens:
            run(["xcrun", "simctl", "terminate", udid, BUNDLE_ID], check=False)
            time.sleep(0.4)
            # Showcase Night-Shift Dark Mode on calendar slide; crisp Day Mode on others
            theme_arg = "dark" if screen == "calendar" else "light"
            run([
                "xcrun", "simctl", "launch", udid, BUNDLE_ID,
                "-ui_lang", lang,
                "-ui_demo_screen", screen,
                "-ui_theme", theme_arg,
            ])
            out_png = RAW_DIR / f"{device_tag}_{lang}_{screen}.png"
            for attempt in range(7):
                time.sleep(3.2 if attempt == 0 else 1.8)
                run(["xcrun", "simctl", "io", udid, "screenshot", str(out_png)])
                try:
                    im = Image.open(out_png).convert("RGB")
                    w, h = im.size
                    crop = im.crop((int(w * 0.12), int(h * 0.16), int(w * 0.88), int(h * 0.84)))
                    avg_std = sum(ImageStat.Stat(crop).stddev) / 3.0
                    if avg_std > 12.0:
                        break
                except Exception:
                    pass
            captured[(lang, screen)] = out_png
            print(f"  ✓ Captured {out_png.name} ({out_png.stat().st_size // 1024} KB)")

    run(["xcrun", "simctl", "terminate", udid, BUNDLE_ID], check=False)
    run(["xcrun", "simctl", "shutdown", udid], check=False)
    return captured


def draw_rounded_paste(canvas: Image.Image, shot: Image.Image, box: tuple[int, int, int, int], radius: int, bezel_color=(11, 16, 27)) -> None:
    x0, y0, x1, y1 = box
    w, h = x1 - x0, y1 - y0
    resized = shot.convert("RGBA").resize((w, h), Image.Resampling.LANCZOS)
    draw = ImageDraw.Draw(canvas)
    pad = int(w * 0.022)
    draw.rounded_rectangle([x0 - pad, y0 - pad, x1 + pad, y1 + pad], radius=radius + pad, fill=bezel_color)
    mask = Image.new("L", (w, h), 0)
    mdraw = ImageDraw.Draw(mask)
    mdraw.rounded_rectangle([0, 0, w, h], radius=radius, fill=255)
    canvas.paste(resized, (x0, y0), mask)


def compose_store_slide(
    raw_png: Path,
    out_png: Path,
    target_size: tuple[int, int],
    badge: str,
    title: str,
    subtitle: str,
    dark_bg: bool,
    is_cn: bool,
) -> None:
    W, H = target_size
    bg = (19, 27, 46) if dark_bg else (244, 246, 250)        # Midnight Indigo / Light Slate
    ink = (255, 255, 255) if dark_bg else (15, 23, 42)
    sub_ink = (186, 198, 218) if dark_bg else (92, 106, 126)
    accent = (37, 99, 235) if dark_bg else (19, 27, 46)
    badge_ink = (255, 255, 255)

    canvas = Image.new("RGB", (W, H), bg)
    draw = ImageDraw.Draw(canvas)

    f_badge = load_font(int(W * 0.029), bold=True, cn=is_cn)
    f_title = load_font(int(W * 0.062), bold=True, cn=is_cn)
    f_sub = load_font(int(W * 0.032), bold=False, cn=is_cn)

    tb = draw.textbbox((0, 0), badge, font=f_badge)
    bw, bh = tb[2] - tb[0], tb[3] - tb[1]
    px, py = int(W * 0.042), int(H * 0.012)
    pill_h = bh + py * 2
    pill_x0 = (W - bw - px * 2) // 2
    pill_y0 = int(H * 0.038)
    draw.rounded_rectangle([pill_x0, pill_y0, pill_x0 + bw + px * 2, pill_y0 + pill_h], radius=pill_h // 2, fill=accent)
    draw.text((pill_x0 + px - tb[0], pill_y0 + py - tb[1]), badge, font=f_badge, fill=badge_ink)

    ty = pill_y0 + pill_h + int(H * 0.022)
    for line in title.split("\n"):
        lb = draw.textbbox((0, 0), line, font=f_title)
        lw = lb[2] - lb[0]
        draw.text(((W - lw) // 2 - lb[0], ty - lb[1]), line, font=f_title, fill=ink)
        ty += (lb[3] - lb[1]) + int(H * 0.014)

    sy = ty + int(H * 0.008)
    sb = draw.textbbox((0, 0), subtitle, font=f_sub)
    sw = sb[2] - sb[0]
    draw.text(((W - sw) // 2 - sb[0], sy - sb[1]), subtitle, font=f_sub, fill=sub_ink)

    shot = Image.open(raw_png)
    shot_aspect = shot.width / shot.height
    frame_top = sy + (sb[3] - sb[1]) + int(H * 0.032)
    avail_h = H - frame_top - int(H * 0.032)
    avail_w = int(W * 0.80)
    if avail_w / avail_h > shot_aspect:
        fh = avail_h
        fw = int(fh * shot_aspect)
    else:
        fw = avail_w
        fh = int(fw / shot_aspect)
    fx0 = (W - fw) // 2
    fy0 = frame_top
    draw_rounded_paste(canvas, shot, (fx0, fy0, fx0 + fw, fy0 + fh), radius=int(fw * 0.085))

    out_png.parent.mkdir(parents=True, exist_ok=True)
    canvas.save(out_png, "PNG")


def main() -> None:
    app_path = build_sim_app()
    screens = ["home", "calendar", "paycheck", "jobs", "paywall"]
    langs = ["en", "zh"]

    iphone_raw = capture_device_screens(IPHONE_UDID, app_path, "iphone65", screens, langs)
    ipad_raw = capture_device_screens(IPAD_UDID, app_path, "ipad13", screens, langs)

    copy_en = {
        "home": ("100% OFFLINE · ZERO ADS", "1-Tap Shift Clock &\nReal Take-Home Pay", "Daily & weekly OT · Night differentials · Net tax est.", True),
        "calendar": ("NIGHT-SHIFT DARK MODE", "Color-Coded Roster &\n1-Tap Rotations", "Nurse 3x12 · DuPont · 2-2-3 Panama · Daily pay preview", False),
        "paycheck": ("PAYCHECK VERIFICATION", "Crisp PDF Timesheets\n& CSV Payroll Export", "Verify every cent of OT & differentials before payday", True),
        "jobs": ("MULTI-JOB PAY RULES", "Main Shift + Side Gig\nin One Clean Ledger", "24h military time · Custom breaks · Local JSON backup", False),
        "paywall": ("PAY ONCE · OWN FOREVER", "Skip $40+ Shift Apps.\nPay $9.99 Once.", "Free 1 job & 2 PDFs/mo · Zero ads · Optional Lifetime", True),
    }
    copy_zh = {
        "home": ("100% 离线 · 永久无广告", "一键打卡算清加班费\n夜班津贴与税后到手", "支持日/周加班倍率 · 自动扣无薪休 · 精准到分", True),
        "calendar": ("夜班护眼深色模式", "彩色倒班日历\n一键批量套用轮班", "内置护士3x12 · 杜邦四班 · 做四休四 · 日薪直观可见", False),
        "paycheck": ("发薪日工资核对单", "高清 PDF 考勤单\n与 CSV 表格一键导出", "正常工时·加班倍率·津贴与扣税逐项核验不吃亏", True),
        "jobs": ("主业与副业独立算薪", "多份工作独立配置\n24小时制与本地备份", "自定义时薪与扣税比例 · 本地 JSON 随时导入恢复", False),
        "paywall": ("一次买断 · 终身拥有", "告别高价订阅软件\n¥38 买断用一辈子", "免费版每月送2张PDF且零广告 · 可选终身买断", True),
    }

    print("[3/4] Compositing EN & CN App Store screenshots (6.5\" iPhone + 13\" iPad)...")
    for idx, sc in enumerate(screens, start=1):
        for lang, locale_dir, copy_map, is_cn in [
            ("en", "en-US", copy_en, False),
            ("zh", "zh-Hans", copy_zh, True),
        ]:
            badge, title, sub, dark = copy_map[sc]
            compose_store_slide(
                iphone_raw[(lang, sc)],
                OUT_ROOT / locale_dir / "iphone65" / f"{idx:02d}_{sc}.png",
                (1284, 2778),
                badge, title, sub, dark, is_cn,
            )
            compose_store_slide(
                ipad_raw[(lang, sc)],
                OUT_ROOT / locale_dir / "ipad13" / f"{idx:02d}_{sc}.png",
                (2064, 2752),
                badge, title, sub, dark, is_cn,
            )

    print(f"[4/4] Done! Framed App Store screenshots saved in {OUT_ROOT}")


if __name__ == "__main__":
    main()
