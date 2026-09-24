from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter, ImageStat


ROOT = Path(__file__).resolve().parents[2]
PROJECT = ROOT / "Spritesheetweapon-master" / "05-成品项目" / "色彩勇者Demo"
SOURCE = ROOT / "production" / "art" / "source" / "v1_portrait_sheet_doubao.png"
OUTPUT = PROJECT / "assets" / "characters" / "portraits"

PANELS = {
    "hero_color_brave.png": (8, 8, 188, 188),
    "boss_gray_dragon.png": (196, 8, 376, 188),
    "boss_mirror_conductor.png": (8, 196, 188, 376),
    "boss_colorless_king.png": (196, 196, 376, 376),
}


def remove_preview_badge(image: Image.Image) -> Image.Image:
    result = image.convert("RGB")
    sample = result.crop((52, 0, 78, 24))
    fill = tuple(round(value) for value in ImageStat.Stat(sample).median)
    clean = result.copy()
    ImageDraw.Draw(clean).rectangle((0, 0, 49, 22), fill=fill)

    mask = Image.new("L", result.size, 0)
    ImageDraw.Draw(mask).rectangle((0, 0, 52, 24), fill=255)
    mask = mask.filter(ImageFilter.GaussianBlur(2.0))
    return Image.composite(clean, result, mask)


def main() -> None:
    OUTPUT.mkdir(parents=True, exist_ok=True)
    sheet = Image.open(SOURCE).convert("RGB")
    for filename, rect in PANELS.items():
        panel = sheet.crop(rect)
        if filename == "hero_color_brave.png":
            panel = remove_preview_badge(panel)
        panel = panel.resize((512, 512), Image.Resampling.LANCZOS)
        panel = panel.filter(ImageFilter.UnsharpMask(radius=1.2, percent=115, threshold=3))
        panel.save(OUTPUT / filename, optimize=True)
        print(OUTPUT / filename)


if __name__ == "__main__":
    main()
