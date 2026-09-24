from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter, ImageStat


ROOT = Path(__file__).resolve().parents[2]
PROJECT = ROOT / "Spritesheetweapon-master" / "05-成品项目" / "色彩勇者Demo"
SOURCE = PROJECT / "artifacts" / "v1_1_character_art" / "character_sheet_v1_1.png"
OUTPUT = PROJECT / "assets" / "characters" / "portraits"

PANELS = {
    "hero_jinge.png": (4, 3, 126, 125),
    "hero_linjing.png": (132, 3, 254, 125),
    "hero_luoen.png": (258, 3, 380, 125),
    "hero_misha.png": (4, 131, 126, 253),
    "hero_yilan.png": (132, 131, 254, 253),
}

BADGED_PORTRAITS = {"hero_jinge.png", "hero_misha.png"}


def remove_preview_badge(image: Image.Image) -> Image.Image:
    result = image.convert("RGB")
    sample = result.crop((0, 23, 38, 34))
    fill = tuple(round(value) for value in ImageStat.Stat(sample).median)
    clean = result.copy()
    ImageDraw.Draw(clean).rectangle((0, 0, 45, 21), fill=fill)

    mask = Image.new("L", result.size, 0)
    ImageDraw.Draw(mask).rectangle((0, 0, 47, 22), fill=255)
    mask = mask.filter(ImageFilter.GaussianBlur(1.2))
    return Image.composite(clean, result, mask)


def main() -> None:
    OUTPUT.mkdir(parents=True, exist_ok=True)
    sheet = Image.open(SOURCE).convert("RGB")
    for filename, rect in PANELS.items():
        portrait = sheet.crop(rect)
        if filename in BADGED_PORTRAITS:
            portrait = remove_preview_badge(portrait)
        portrait = portrait.resize((512, 512), Image.Resampling.LANCZOS)
        portrait = portrait.filter(
            ImageFilter.UnsharpMask(radius=1.0, percent=105, threshold=3)
        )
        destination = OUTPUT / filename
        portrait.save(destination, optimize=True)
        print(destination)


if __name__ == "__main__":
    main()
