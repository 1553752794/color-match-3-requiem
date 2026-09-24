from __future__ import annotations

from pathlib import Path
from random import Random

from PIL import Image, ImageDraw, ImageFont


ROOT = Path(__file__).resolve().parents[2]
GAME = ROOT / "Spritesheetweapon-master" / "05-成品项目" / "色彩勇者Demo"
PORTRAITS = GAME / "assets" / "characters" / "portraits"
OUT = Path(__file__).resolve().parent / "v1.5-figma"
OUT.mkdir(parents=True, exist_ok=True)

REGULAR = Path(r"C:\Windows\Fonts\msyh.ttc")
BOLD = Path(r"C:\Windows\Fonts\msyhbd.ttc")

C = {
    "bg": "#0E1215",
    "surface": "#141A1E",
    "raised": "#1B2328",
    "border": "#39464F",
    "border_soft": "#263139",
    "text": "#F4E9CD",
    "muted": "#AAB6BC",
    "red": "#E84B3C",
    "red_dark": "#A52F2B",
    "blue": "#4C8DE8",
    "gold": "#E9BA39",
    "mist": "#9AA0A6",
    "violet": "#8659A8",
    "teal": "#58C3A5",
    "warning": "#F4C44B",
    "white": "#DFE7EB",
    "black": "#090C0E",
}


def font(size: int, bold: bool = False) -> ImageFont.FreeTypeFont:
    return ImageFont.truetype(str(BOLD if bold else REGULAR), size=size)


def canvas(size: tuple[int, int] = (1280, 720)) -> tuple[Image.Image, ImageDraw.ImageDraw]:
    image = Image.new("RGB", size, C["bg"])
    draw = ImageDraw.Draw(image)
    for x in range(24, size[0], 64):
        draw.line((x, 0, x, size[1]), fill="#11171A", width=1)
    for y in range(24, size[1], 64):
        draw.line((0, y, size[0], y), fill="#11171A", width=1)
    return image, draw


def rect(draw: ImageDraw.ImageDraw, box, fill, outline=None, width=1, radius=4):
    draw.rounded_rectangle(box, radius=radius, fill=fill, outline=outline, width=width)


def txt(draw: ImageDraw.ImageDraw, xy, text, size=15, color=None, bold=False, anchor=None):
    draw.text(xy, text, font=font(size, bold), fill=color or C["text"], anchor=anchor)


def fit_txt(draw, box, text, size=15, color=None, bold=False, min_size=10, anchor="mm"):
    x1, y1, x2, y2 = box
    while size > min_size:
        bb = draw.textbbox((0, 0), text, font=font(size, bold))
        if bb[2] - bb[0] <= x2 - x1 - 12 and bb[3] - bb[1] <= y2 - y1 - 8:
            break
        size -= 1
    draw.text(((x1 + x2) / 2, (y1 + y2) / 2), text, font=font(size, bold), fill=color or C["text"], anchor=anchor)


def header(draw, title, subtitle, right):
    draw.rectangle((0, 0, 1280, 74), fill=C["surface"])
    draw.rectangle((0, 73, 1280, 74), fill=C["border"])
    draw.rectangle((24, 20, 29, 55), fill=C["red"])
    txt(draw, (46, 17), title, 24, bold=True)
    txt(draw, (47, 48), subtitle, 12, C["muted"])
    txt(draw, (1250, 37), right, 13, C["gold"], bold=True, anchor="rm")


def panel(draw, box, title=None, accent=None, fill=None):
    rect(draw, box, fill or C["surface"], C["border"], 1, 4)
    if title:
        x1, y1, x2, _ = box
        if accent:
            draw.rectangle((x1, y1, x1 + 4, y1 + 38), fill=accent)
        txt(draw, (x1 + 16, y1 + 11), title, 14, bold=True)
        draw.line((x1 + 12, y1 + 39, x2 - 12, y1 + 39), fill=C["border_soft"], width=1)


def button(draw, box, label, fill=None, outline=None, color=None):
    rect(draw, box, fill or C["raised"], outline or C["border"], 1, 4)
    fit_txt(draw, box, label, 15, color or C["text"], True)


def bar(draw, box, ratio, color, label=None):
    x1, y1, x2, y2 = box
    rect(draw, box, C["black"], C["border_soft"], 1, 2)
    if ratio > 0:
        draw.rectangle((x1 + 2, y1 + 2, x1 + 2 + int((x2 - x1 - 4) * ratio), y2 - 2), fill=color)
    if label:
        txt(draw, ((x1 + x2) / 2, (y1 + y2) / 2), label, 11, C["text"], True, "mm")


def portrait(image, filename, box, border=C["border"]):
    src = Image.open(PORTRAITS / filename).convert("RGB")
    x1, y1, x2, y2 = box
    target_ratio = (x2 - x1) / (y2 - y1)
    source_ratio = src.width / src.height
    if source_ratio > target_ratio:
        nw = int(src.height * target_ratio)
        left = (src.width - nw) // 2
        src = src.crop((left, 0, left + nw, src.height))
    else:
        nh = int(src.width / target_ratio)
        top = (src.height - nh) // 2
        src = src.crop((0, top, src.width, top + nh))
    src = src.resize((x2 - x1, y2 - y1), Image.Resampling.LANCZOS)
    image.paste(src, (x1, y1))
    ImageDraw.Draw(image).rectangle(box, outline=border, width=2)


def tag(draw, x, y, text, color, width=84):
    rect(draw, (x, y, x + width, y + 28), C["raised"], color, 1, 3)
    fit_txt(draw, (x, y, x + width, y + 28), text, 12, color, True)


def build_foundations():
    image, draw = canvas((1280, 440))
    txt(draw, (40, 26), "色彩勇者：三消镇魂曲", 30, bold=True)
    txt(draw, (42, 69), "1.5 RELEASE UI SYSTEM", 12, C["gold"], True)
    txt(draw, (40, 114), "色彩令牌", 18, bold=True)
    swatches = [
        ("底色", "bg"), ("面板", "surface"), ("高层", "raised"),
        ("赤焰", "red"), ("蓝霜", "blue"), ("金辉", "gold"),
        ("雾灰", "mist"), ("紫律", "violet"), ("生命", "teal"),
    ]
    for i, (name, key) in enumerate(swatches):
        x = 40 + i * 132
        rect(draw, (x, 153, x + 112, 223), C[key], C["border"], 1, 4)
        label_color = C["black"] if key in {"gold", "mist", "teal"} else C["text"]
        txt(draw, (x + 10, 194), name, 12, label_color, True)
    txt(draw, (40, 264), "排版层级", 18, bold=True)
    txt(draw, (40, 301), "显示标题 32 / 40", 30, bold=True)
    txt(draw, (418, 306), "模块标题 20 / 28", 20, bold=True)
    txt(draw, (690, 311), "正文 15 / 24 · 关键数据不只依赖颜色传达", 15, C["muted"])
    txt(draw, (40, 377), "间距  4 / 8 / 12 / 16 / 24 / 32     圆角  2 / 4 / 6 / 8", 13, C["gold"], True)
    button(draw, (890, 370, 1045, 410), "主要行动", C["red_dark"], C["red"])
    button(draw, (1060, 370, 1215, 410), "次要行动")
    image.save(OUT / "00_foundations.png", quality=95)


def build_character_select():
    image, draw = canvas()
    header(draw, "选择角色", "五种战斗逻辑 · 共用 6×6 色盘", "BUILD 1.5.0")
    chars = [
        ("烬歌", "焰痕决斗家", "red"), ("凛镜", "镜湖守望者", "blue"),
        ("洛恩", "断路估价师", "gold"), ("弥砂", "雾地拾谱人", "mist"),
        ("伊澜", "三声调律师", "violet"),
    ]
    for i, (name, role, key) in enumerate(chars):
        y = 102 + i * 92
        selected = i == 0
        rect(draw, (32, y, 286, y + 72), C[key] if selected else C["surface"], C[key], 2 if selected else 1, 4)
        txt(draw, (54, y + 15), name, 17, C["black"] if key in {"gold", "mist"} and selected else C["text"], True)
        txt(draw, (54, y + 43), role, 12, C["black"] if key in {"gold", "mist"} and selected else C["muted"])
        if selected:
            txt(draw, (266, y + 36), "已选", 11, C["text"], True, "rm")
    panel(draw, (316, 102, 935, 638), accent=C["red"])
    portrait(image, "hero_jinge.png", (348, 136, 568, 356), C["red"])
    txt(draw, (596, 134), "烬歌 / 焰痕决斗家", 25, bold=True)
    txt(draw, (596, 176), "定位  进攻     最大生命  112", 14, C["muted"])
    tag(draw, 596, 210, "进攻", C["red"], 82)
    tag(draw, 688, 210, "红焰", C["gold"], 82)
    txt(draw, (348, 386), "被动 · 先声燃点", 18, C["red"], True)
    txt(draw, (348, 422), "每场战斗首次主动完成红色 4 连时，额外施加 1 层燃烧。", 15)
    txt(draw, (348, 467), "起始牌组", 13, C["muted"], True)
    deck = [
        ("余烬斩", "red"), ("余烬斩", "red"), ("炼原", "red"), ("赤潮回响", "red"),
        ("凝霜格", "blue"), ("点金拍", "gold"), ("调色练习", "mist"), ("镇魂短句", "violet"),
    ]
    for i, (name, key) in enumerate(deck):
        x = 348 + (i % 4) * 140
        y = 496 + (i // 3) * 54
        y = 496 + (i // 4) * 54
        rect(draw, (x, y, x + 128, y + 40), C["raised"], C[key], 1, 3)
        txt(draw, (x + 12, y + 11), name, 12, C[key], True)
    panel(draw, (961, 102, 1248, 638), "旅程配置", C["gold"])
    txt(draw, (985, 161), "主动技能", 12, C["muted"])
    txt(draw, (985, 190), "灼线校准 · 12", 18, C["red"], True)
    txt(draw, (985, 224), "下一颗弹珠每次命中 +1 伤害；", 12)
    txt(draw, (985, 247), "命中 10 次时追加 2 层燃烧。", 12)
    txt(draw, (985, 298), "专属谱弹", 12, C["muted"])
    txt(draw, (985, 327), "红焰高速弹", 17, C["gold"], True)
    txt(draw, (985, 359), "每次命中 +1 · 高命中追加燃烧", 12, C["muted"])
    txt(draw, (985, 409), "起始遗物", 12, C["muted"])
    txt(draw, (985, 438), "余温护符", 16, C["gold"], True)
    txt(draw, (985, 468), "首个红谱完成后获得护盾", 12, C["muted"])
    button(draw, (985, 555, 1223, 606), "以烬歌开始旅程", C["red_dark"], C["red"])
    button(draw, (32, 657, 176, 700), "返回主菜单")
    txt(draw, (1248, 680), "角色 1 / 5", 12, C["muted"], anchor="rm")
    image.save(OUT / "01_character_select.png", quality=95)


def build_ascension():
    image, draw = canvas()
    header(draw, "进阶难度", "A0-A10 · 每级叠加生效", "当前选择 A7")
    for i in range(11):
        x = 34 + i * 111
        active = i <= 7
        selected = i == 7
        rect(draw, (x, 96, x + 94, 142), C["gold"] if selected else (C["raised"] if active else C["surface"]), C["gold"] if active else C["border"], 2 if selected else 1, 3)
        fit_txt(draw, (x, 96, x + 94, 142), f"A{i}", 15, C["black"] if selected else C["text"], True)
    panel(draw, (34, 168, 814, 650), "叠加规则", C["gold"])
    mods = [
        (1, "敌人生命 +10%"), (2, "敌人伤害 +10%"), (3, "治愈效率 -15%"),
        (4, "金币 -15% / 商店 +10%"), (5, "灰色 +5pp / 灰蚀 +20%"), (6, "危险钉 +5pp / 上限 +1"),
        (7, "精英生命 +15% / 伤害 +10%"), (8, "首领生命 +20% / 伤害 +15%"),
        (9, "负担 +1 / 初始金币 -25"), (10, "终局规则全域共振"),
    ]
    for i, (level, desc) in enumerate(mods):
        col = i % 2
        row = i // 2
        x = 58 + col * 370
        y = 222 + row * 76
        active = level <= 7
        draw.ellipse((x, y, x + 34, y + 34), fill=C["gold"] if active else C["raised"], outline=C["gold"] if active else C["border"])
        fit_txt(draw, (x, y, x + 34, y + 34), str(level), 12, C["black"] if active else C["muted"], True)
        txt(draw, (x + 48, y + 7), desc, 14, C["text"] if active else C["muted"], active)
        txt(draw, (x + 48, y + 31), "已启用" if active else "未启用", 11, C["gold"] if active else C["border"])
    panel(draw, (840, 168, 1246, 650), "A7 · 精英蜕变", C["red"])
    txt(draw, (866, 224), "A1-A7 全部规则累计生效", 14, C["muted"])
    txt(draw, (866, 276), "累计结果", 12, C["muted"])
    for i, (name, value, col) in enumerate([("普通生命", "1.10×", "red"), ("精英生命", "1.27×", "warning"), ("精英伤害", "1.21×", "violet")]):
        y = 306 + i * 54
        txt(draw, (866, y), name, 13)
        txt(draw, (1208, y), value, 15, C[col], True, "rm")
        draw.line((866, y + 31, 1210, y + 31), fill=C["border_soft"])
    txt(draw, (866, 468), "附加压力", 12, C["muted"])
    txt(draw, (866, 497), "危险钉 +6pp · 治愈 85%", 14, C["violet"], True)
    txt(draw, (866, 526), "金币 85% · 商店 110%", 13, C["gold"])
    button(draw, (866, 568, 1220, 621), "开始 A7 旅程", C["red_dark"], C["red"])
    button(draw, (34, 670, 178, 706), "返回角色")
    image.save(OUT / "02_ascension.png", quality=95)


def tile(draw, box, key, symbol):
    fill = C[key]
    rect(draw, box, fill, C["black"], 2, 4)
    color = C["black"] if key in {"gold", "mist"} else C["text"]
    fit_txt(draw, box, symbol, 18, color, True)


def build_match_combat():
    image, draw = canvas()
    header(draw, "第一章 · 灰雾边境", "战斗 4 / 12 · A7", "步数 2/3    金币 86    颜料 4")
    panel(draw, (24, 94, 436, 614), "色盘 · 6×6", C["red"])
    board = [
        "rgmbrr", "bgrmgb", "mrrgbg", "gbmrrm", "rgbgmr", "mgrbrg",
    ]
    keys = {"r": ("red", "火"), "b": ("blue", "冰"), "g": ("gold", "金"), "m": ("mist", "雾")}
    for row, line in enumerate(board):
        for col, ch in enumerate(line):
            x, y = 52 + col * 61, 156 + row * 61
            tile(draw, (x, y, x + 50, y + 50), *keys[ch])
    txt(draw, (52, 541), "选中  火 ×4", 13, C["red"], True)
    txt(draw, (410, 541), "色素 +4", 13, C["gold"], True, "rm")
    txt(draw, (52, 574), "本次消除伤害 0", 12, C["muted"])
    panel(draw, (458, 94, 942, 614), "本回合色谱", C["violet"])
    spectra = [
        ("炼原 · 红焰", "一次红色 4 连+", "4 / 4", "标准谱弹 18", "red"),
        ("余烬斩 · 红焰", "本回合累计红 ≥5", "4 / 5", "燃烧 2 层", "red"),
        ("凝霜格 · 蓝霜", "一次蓝色 4 连", "1 / 4", "护盾 14", "blue"),
    ]
    for i, (name, cond, progress, reward, key) in enumerate(spectra):
        y = 150 + i * 145
        rect(draw, (482, y, 918, y + 124), C["raised"], C[key], 2 if i == 0 else 1, 4)
        txt(draw, (500, y + 14), name, 16, C[key], True)
        txt(draw, (500, y + 45), cond, 12, C["muted"])
        bar(draw, (500, y + 72, 692, y + 90), int(progress[0]) / int(progress[-1]), C[key], progress)
        txt(draw, (896, y + 74), reward, 12, C["gold"], True, "rm")
        txt(draw, (896, y + 101), "已完成" if i == 0 else "保留", 11, C["teal"] if i == 0 else C["muted"], anchor="rm")
    panel(draw, (964, 94, 1256, 614), "敌人与意图", C["red"])
    portrait(image, "boss_gray_dragon.png", (1038, 130, 1182, 274), C["mist"])
    txt(draw, (988, 294), "灰蚀龙", 20, bold=True)
    bar(draw, (988, 328, 1232, 350), .71, C["red"], "198 / 280")
    txt(draw, (988, 374), "下一回合", 12, C["muted"])
    rect(draw, (988, 400, 1232, 449), C["black"], C["red"], 1, 3)
    txt(draw, (1004, 414), "灰鳞拍击 · 20 伤害", 14, C["red"], True)
    txt(draw, (988, 476), "状态", 12, C["muted"])
    tag(draw, 988, 503, "燃烧 2", C["red"], 92)
    tag(draw, 1090, 503, "破谱 1", C["violet"], 92)
    button(draw, (988, 552, 1232, 594), "进入谱弹瞄准", C["red_dark"], C["red"])
    panel(draw, (24, 634, 1256, 704), accent=C["teal"])
    txt(draw, (44, 649), "烬歌", 14, C["red"], True)
    bar(draw, (116, 648, 420, 668), .79, C["teal"], "生命 88 / 112")
    txt(draw, (452, 650), "护盾 14", 13, C["blue"], True)
    tag(draw, 548, 644, "灼线校准 9/12", C["red"], 134)
    txt(draw, (704, 650), "谱弹队列", 12, C["muted"])
    tag(draw, 792, 644, "炼原 18 · 2 发", C["violet"], 142)
    txt(draw, (1232, 652), "回合契约 1/2", 12, C["muted"], anchor="rm")
    image.save(OUT / "03_match_combat.png", quality=95)


def build_pegboard():
    image, draw = canvas()
    header(draw, "谱弹瞄准", "炼原 · 标准谱弹 18", "12 次采样预计 26-41")
    panel(draw, (24, 94, 294, 638), "谱弹队列", C["violet"])
    rect(draw, (46, 148, 270, 276), C["raised"], C["red"], 2, 4)
    txt(draw, (62, 162), "当前谱弹", 11, C["muted"])
    txt(draw, (62, 190), "炼原", 18, C["red"], True)
    txt(draw, (62, 224), "标准谱弹", 12, C["muted"])
    txt(draw, (250, 221), "18", 20, C["gold"], True, "rm")
    txt(draw, (46, 326), "待发射队列", 12, C["muted"])
    txt(draw, (46, 354), "3 / 8", 25, C["violet"], True)
    bar(draw, (46, 394, 270, 414), 3 / 8, C["violet"])
    txt(draw, (46, 434), "其余 2 发等待", 12, C["muted"])
    txt(draw, (46, 553), "弹道修正", 12, C["muted"])
    bar(draw, (46, 579, 270, 599), .62, C["violet"], "+6%")
    button(draw, (46, 610, 270, 628), "取消瞄准")
    panel(draw, (318, 94, 918, 674), "回声钉板 · 9×8", C["gold"])
    board_box = (348, 142, 888, 638)
    rect(draw, board_box, C["black"], C["border"], 1, 4)
    # Target zones.
    zones = [("×0.7", "mist"), ("×1.0", "blue"), ("×1.6", "gold"), ("×1.0", "blue"), ("×0.7", "mist")]
    for i, (label, key) in enumerate(zones):
        x = 360 + i * 103
        rect(draw, (x, 596, x + 91, 624), C["raised"], C[key], 1, 2)
        fit_txt(draw, (x, 596, x + 91, 624), label, 11, C[key], True)
    # Pegs: 9 rows by 8 columns, staggered.
    for row in range(9):
        for col in range(8):
            x = 389 + col * 64 + (32 if row % 2 else 0)
            y = 206 + row * 40
            key = "violet" if (row, col) in {(3, 5), (6, 2)} else ("red" if (row, col) in {(4, 3), (7, 6)} else "white")
            r = 8 if key == "white" else 11
            draw.ellipse((x - r, y - r, x + r, y + r), fill=C[key], outline=C["black"], width=2)
            if key == "violet":
                txt(draw, (x, y), "!", 10, C["text"], True, "mm")
    # Aim line and projected bounces.
    trajectory = [(618, 160), (566, 252), (632, 333), (538, 431), (610, 526), (610, 595)]
    draw.line(trajectory, fill=C["red"], width=4)
    for x, y in trajectory[1:-1]:
        draw.ellipse((x - 5, y - 5, x + 5, y + 5), fill=C["gold"])
    draw.ellipse((606, 148, 630, 172), fill=C["red"], outline=C["text"], width=2)
    panel(draw, (942, 94, 1256, 674), "命中预估", C["red"])
    txt(draw, (968, 150), "伤害区间", 12, C["muted"])
    txt(draw, (968, 177), "26 - 41", 34, C["gold"], True)
    txt(draw, (968, 224), "中位数 33 · 12 次采样", 12, C["muted"])
    txt(draw, (968, 274), "预计命中", 12, C["muted"])
    for i, (name, value, key) in enumerate([("普通钉", "7", "white"), ("增幅钉", "2", "red"), ("干扰钉", "1", "violet")]):
        y = 304 + i * 45
        draw.ellipse((970, y, 986, y + 16), fill=C[key])
        txt(draw, (998, y - 2), name, 13)
        txt(draw, (1226, y - 2), value, 14, C[key], True, "rm")
    txt(draw, (968, 454), "敌方干扰意图", 12, C["muted"])
    rect(draw, (968, 482, 1230, 540), C["black"], C["violet"], 1, 3)
    txt(draw, (984, 494), "镜像偏折", 14, C["violet"], True)
    txt(draw, (984, 518), "首次触钉后水平偏转 8°", 11, C["muted"])
    button(draw, (968, 586, 1230, 640), "发射谱弹", C["red_dark"], C["red"])
    image.save(OUT / "04_pegboard.png", quality=95)


def toggle(draw, x, y, on=True):
    fill = C["teal"] if on else C["raised"]
    rect(draw, (x, y, x + 48, y + 24), fill, C["teal"] if on else C["border"], 1, 12)
    cx = x + 36 if on else x + 12
    draw.ellipse((cx - 8, y + 4, cx + 8, y + 20), fill=C["text"] if on else C["muted"])


def slider(draw, box, ratio):
    x1, y1, x2, y2 = box
    draw.line((x1, (y1 + y2) / 2, x2, (y1 + y2) / 2), fill=C["border"], width=4)
    px = x1 + int((x2 - x1) * ratio)
    draw.line((x1, (y1 + y2) / 2, px, (y1 + y2) / 2), fill=C["gold"], width=4)
    draw.ellipse((px - 8, (y1 + y2) / 2 - 8, px + 8, (y1 + y2) / 2 + 8), fill=C["text"], outline=C["gold"])


def build_settings():
    image, draw = canvas()
    header(draw, "设置", "修改后即时应用并保存 · Save v3", "已保存 21:46")
    tabs = [("音频", False), ("显示", False), ("玩法", False), ("无障碍", True)]
    for i, (name, active) in enumerate(tabs):
        x = 34 + i * 176
        button(draw, (x, 98, x + 160, 140), name, C["gold"] if active else C["surface"], C["gold"] if active else C["border"], C["black"] if active else C["text"])
    panel(draw, (34, 166, 624, 662), "音频与显示", C["gold"])
    audio = [("主音量", 1.0, "100%"), ("音乐音量", .75, "75%"), ("音效音量", .85, "85%")]
    for i, (name, value, value_text) in enumerate(audio):
        y = 224 + i * 102
        txt(draw, (58, y), name, 14, bold=True)
        txt(draw, (586, y), value_text, 13, C["gold"], True, "rm")
        slider(draw, (58, y + 38, 586, y + 58), value)
    txt(draw, (58, 536), "全屏", 15, bold=True)
    txt(draw, (58, 565), "默认关闭", 12, C["muted"])
    toggle(draw, 538, 540, False)
    panel(draw, (650, 166, 1246, 662), "玩法与无障碍", C["teal"])
    settings = [
        ("减少动态效果", "默认关闭", False),
        ("瞄准预测", "12 次模拟伤害区间", True),
        ("快速结算", "默认关闭", False),
        ("高对比钉点", "强化特殊钉轮廓", False),
    ]
    for i, (name, desc, on) in enumerate(settings):
        y = 218 + i * 76
        txt(draw, (674, y), name, 15, bold=True)
        txt(draw, (674, y + 27), desc, 12, C["muted"])
        toggle(draw, 1166, y + 4, on)
        draw.line((674, y + 59, 1218, y + 59), fill=C["border_soft"])
    txt(draw, (674, 528), "战斗速度", 15, bold=True)
    txt(draw, (1218, 528), "1.0×", 13, C["gold"], True, "rm")
    slider(draw, (674, 566, 1218, 586), 1 / 3)
    txt(draw, (674, 599), "0.5×", 11, C["muted"])
    txt(draw, (1218, 599), "2.0×", 11, C["muted"], anchor="rm")
    txt(draw, (1218, 630), "步进 0.25×", 11, C["muted"], anchor="rm")
    button(draw, (34, 678, 178, 710), "返回游戏")
    image.save(OUT / "05_settings.png", quality=95)


def build_recap():
    image, draw = canvas()
    header(draw, "结算：完整色谱", "第三章 · 无色王座", "种子 C7F2-91A4 · 46:18")
    txt(draw, (40, 102), "完整色谱", 34, C["gold"], True)
    txt(draw, (40, 148), "烬歌完成三章旅程，谱弹击碎无色之王。", 15, C["muted"])
    panel(draw, (34, 198, 416, 632), "色彩使用", C["gold"])
    chart = [("红焰", .47, "red"), ("蓝霜", .21, "blue"), ("金辉", .19, "gold"), ("雾灰", .13, "mist")]
    for i, (name, value, key) in enumerate(chart):
        y = 256 + i * 70
        txt(draw, (58, y), name, 12, C["muted"])
        bar(draw, (118, y + 2, 374, y + 20), value, C[key])
        txt(draw, (386, y), f"{int(value * 100)}%", 12, C[key], True, "rm")
    txt(draw, (58, 548), "灰蚀压力", 12, C["muted"])
    txt(draw, (386, 548), "3", 18, C["mist"], True, "rm")
    panel(draw, (440, 198, 856, 632), "战斗统计", C["violet"])
    stats = [("回合", "42"), ("交换", "86"), ("完成棋谱", "22"), ("发射", "31")]
    for i, (name, value) in enumerate(stats):
        col, row = i % 2, i // 2
        x, y = 466 + col * 188, 252 + row * 86
        txt(draw, (x, y), name, 12, C["muted"])
        txt(draw, (x, y + 25), value, 25, C["text"], True)
    detail = [("每球命中", "8.4"), ("暴击率", "14%"), ("单发均伤", "33.6"), ("主伤害", "炼原")]
    for i, (name, value) in enumerate(detail):
        y = 444 + i * 41
        txt(draw, (466, y), name, 12, C["muted"])
        txt(draw, (828, y), value, 13, C["gold"] if i == 3 else C["text"], True, "rm")
    panel(draw, (880, 198, 1246, 632), "构筑收束", C["teal"])
    details = [
        ("总伤害", "4,862", "red"), ("获得护盾", "214", "blue"),
        ("金币净收益", "+152", "gold"), ("牌组", "18 张", "text"),
    ]
    for i, (name, value, key) in enumerate(details):
        y = 254 + i * 62
        txt(draw, (906, y), name, 12, C["muted"])
        txt(draw, (1218, y), value, 17, C[key], True, "rm")
        draw.line((906, y + 36, 1218, y + 36), fill=C["border_soft"])
    txt(draw, (906, 512), "遗物", 12, C["muted"])
    txt(draw, (906, 542), "余温护符 · 镜面弦 · 灰烬冠", 13, C["gold"], True)
    txt(draw, (906, 580), "最高来源  炼原 1,284", 12, C["muted"])
    button(draw, (1038, 656, 1246, 704), "重新开始", C["red_dark"], C["red"])
    image.save(OUT / "06_run_recap.png", quality=95)


def main():
    build_foundations()
    build_character_select()
    build_ascension()
    build_match_combat()
    build_pegboard()
    build_settings()
    build_recap()
    for path in sorted(OUT.glob("*.png")):
        with Image.open(path) as image:
            print(f"{path.name}: {image.width}x{image.height}")


if __name__ == "__main__":
    main()
