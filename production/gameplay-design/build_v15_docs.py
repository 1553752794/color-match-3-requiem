from __future__ import annotations

import json
import re
from collections import Counter
from datetime import date
from pathlib import Path

from docx import Document
from docx.enum.table import WD_CELL_VERTICAL_ALIGNMENT, WD_TABLE_ALIGNMENT
from docx.enum.text import WD_ALIGN_PARAGRAPH
from docx.enum.style import WD_STYLE_TYPE
from docx.oxml import OxmlElement
from docx.oxml.ns import qn
from docx.shared import Inches, Pt, RGBColor, Twips


OUT_DIR = Path(__file__).resolve().parent
ROOT = OUT_DIR.parents[1]
GAME_DATA_PATH = next((ROOT / "Spritesheetweapon-master").rglob("GameData.gd"))
GAME_PROJECT_DIR = GAME_DATA_PATH.parent.parent
TEST_SCRIPT_COUNT = len(list((GAME_PROJECT_DIR / "tests").glob("test_*.gd")))

OUT_GDD = OUT_DIR / "色彩勇者_1.5游戏总策划案.docx"
OUT_BALANCE = OUT_DIR / "色彩勇者_1.5角色与关卡数值总表.docx"
TODAY = date(2026, 7, 27)

CONTENT_WIDTH_DXA = 9360
TABLE_INDENT_DXA = 120
CELL_MARGINS = {"top": 80, "bottom": 80, "start": 120, "end": 120}

BLUE = RGBColor(0x2E, 0x74, 0xB5)
DARK_BLUE = RGBColor(0x1F, 0x4D, 0x78)
NAVY = RGBColor(0x0B, 0x25, 0x45)
INK = RGBColor(0x22, 0x22, 0x22)
MUTED = RGBColor(0x66, 0x66, 0x66)
WHITE = RGBColor(0xFF, 0xFF, 0xFF)
GOLD = RGBColor(0xA6, 0x72, 0x00)

FILL_BLUE = "E8EEF5"
FILL_LIGHT = "F4F6F9"
FILL_GRAY = "F2F4F7"
FILL_GREEN = "E2F0D9"
FILL_GOLD = "FFF2CC"
FILL_RED = "FCE4D6"
FILL_PURPLE = "EADCF8"
FILL_BLACK = "E7E2EA"

COLOR_LABELS = {
    "gray": "灰蚀",
    "red": "红焰",
    "blue": "蓝霜",
    "gold": "金辉",
    "neutral": "中立",
    "mixed": "混色",
    "green": "翠生",
    "purple": "紫弦",
    "white": "白昼",
    "black": "黑曜",
}
RARITY_LABELS = {"common": "普通", "rare": "稀有", "epic": "史诗", "boss": "Boss"}
NODE_LABELS = {
    "start": "起点",
    "combat": "普通战",
    "elite": "精英",
    "challenge": "挑战",
    "event": "事件",
    "chest": "宝箱",
    "shop": "商店",
    "camp": "营火",
    "boss": "Boss",
}
INTENT_LABELS = {
    "attack": "攻击",
    "heavy": "重击",
    "charge": "蓄力",
    "defend": "防御",
    "pollute": "污染",
    "steal": "偷取",
    "resist": "定色抗性",
    "resist_dominant": "主色抗性",
    "heal": "回复",
    "player_burn": "点燃玩家",
    "aim_drift": "瞄准偏折",
    "crit_suppress": "暴击压制",
    "add_hazard": "布置危险钉",
    "peg_seal": "封锁钉点",
    "seal": "封锁钉点",
}


def _extract_braced(text: str, start: int) -> str:
    depth = 0
    quoted = False
    escaped = False
    for index in range(start, len(text)):
        char = text[index]
        if quoted:
            if escaped:
                escaped = False
            elif char == "\\":
                escaped = True
            elif char == '"':
                quoted = False
            continue
        if char == '"':
            quoted = True
        elif char == "{":
            depth += 1
        elif char == "}":
            depth -= 1
            if depth == 0:
                return text[start : index + 1]
    raise ValueError("Unbalanced GDScript dictionary")


def parse_const_dict(source: str, name: str) -> dict:
    match = re.search(rf"const\s+{name}(?:\s*:[^=]+)?\s*=\s*", source)
    if match is None:
        raise KeyError(name)
    start = source.find("{", match.end())
    raw = _extract_braced(source, start)
    raw = re.sub(r",\s*([}\]])", r"\1", raw)
    return json.loads(raw)


def load_runtime_data() -> dict:
    source = GAME_DATA_PATH.read_text(encoding="utf-8")
    names = ["SPECTRA", "RELICS", "CHAPTERS", "EVENTS", "ENCOUNTERS", "CHAPTER_NODES", "STARTING_ARCHETYPES"]
    data = {name: parse_const_dict(source, name) for name in names}
    order_match = re.search(r"const COLOR_ORDER[^=]*=\s*(\[[^\n]+\])", source)
    weight_match = re.search(r"const BASE_WEIGHTS[^=]*=\s*", source)
    data["COLOR_ORDER"] = json.loads(order_match.group(1)) if order_match else []
    if weight_match:
        start = source.find("{", weight_match.end())
        raw = re.sub(r",\s*([}\]])", r"\1", _extract_braced(source, start))
        data["BASE_WEIGHTS"] = json.loads(raw)
    else:
        data["BASE_WEIGHTS"] = {}
    return data


def set_run_font(run, size=None, color=None, bold=None, italic=None, name="Calibri") -> None:
    run.font.name = name
    run._element.get_or_add_rPr().get_or_add_rFonts().set(qn("w:ascii"), name)
    run._element.rPr.rFonts.set(qn("w:hAnsi"), name)
    run._element.rPr.rFonts.set(qn("w:eastAsia"), "Microsoft YaHei")
    if size is not None:
        run.font.size = Pt(size)
    if color is not None:
        run.font.color.rgb = color
    if bold is not None:
        run.bold = bold
    if italic is not None:
        run.italic = italic


def set_style_font(style, size, color=INK, bold=None, name="Calibri") -> None:
    style.font.name = name
    style._element.get_or_add_rPr().get_or_add_rFonts().set(qn("w:ascii"), name)
    style._element.rPr.rFonts.set(qn("w:hAnsi"), name)
    style._element.rPr.rFonts.set(qn("w:eastAsia"), "Microsoft YaHei")
    style.font.size = Pt(size)
    style.font.color.rgb = color
    if bold is not None:
        style.font.bold = bold


def add_page_number(paragraph) -> None:
    paragraph.alignment = WD_ALIGN_PARAGRAPH.RIGHT
    run = paragraph.add_run("第 ")
    set_run_font(run, 9, MUTED)
    begin = OxmlElement("w:fldChar")
    begin.set(qn("w:fldCharType"), "begin")
    instruction = OxmlElement("w:instrText")
    instruction.set(qn("xml:space"), "preserve")
    instruction.text = " PAGE "
    end = OxmlElement("w:fldChar")
    end.set(qn("w:fldCharType"), "end")
    run._r.extend([begin, instruction, end])
    tail = paragraph.add_run(" 页")
    set_run_font(tail, 9, MUTED)


def configure_document(doc: Document, preset: str, running_title: str) -> None:
    section = doc.sections[0]
    section.page_width = Inches(8.5)
    section.page_height = Inches(11)
    section.top_margin = Inches(1.0)
    section.bottom_margin = Inches(1.0)
    section.left_margin = Inches(1.0)
    section.right_margin = Inches(1.0)
    section.header_distance = Inches(0.492)
    section.footer_distance = Inches(0.492)

    normal = doc.styles["Normal"]
    set_style_font(normal, 11)
    normal.paragraph_format.space_before = Pt(0)
    normal.paragraph_format.space_after = Pt(8 if preset == "narrative_proposal" else 6)
    normal.paragraph_format.line_spacing = 1.333 if preset == "narrative_proposal" else 1.25
    normal.paragraph_format.alignment = WD_ALIGN_PARAGRAPH.JUSTIFY if preset == "narrative_proposal" else WD_ALIGN_PARAGRAPH.LEFT

    heading_tokens = (
        ((16, 18, 10), (13, 12, 6), (12, 8, 4))
        if preset == "narrative_proposal"
        else ((16, 18, 10), (13, 14, 7), (12, 10, 5))
    )
    for style_name, token, color in zip(
        ("Heading 1", "Heading 2", "Heading 3"), heading_tokens, (BLUE, BLUE, DARK_BLUE)
    ):
        style = doc.styles[style_name]
        size, before, after = token
        set_style_font(style, size, color, True)
        style.paragraph_format.space_before = Pt(before)
        style.paragraph_format.space_after = Pt(after)
        style.paragraph_format.line_spacing = 1.25
        style.paragraph_format.keep_with_next = True

    marker = 0.181 if preset == "narrative_proposal" else 0.187
    hanging = 0.194 if preset == "narrative_proposal" else 0.188
    list_spacing = 1.208 if preset == "narrative_proposal" else 1.25
    for style_name in ("List Bullet", "List Number"):
        style = doc.styles[style_name]
        set_style_font(style, 11)
        style.paragraph_format.left_indent = Inches(0.375)
        style.paragraph_format.first_line_indent = Inches(-hanging)
        style.paragraph_format.tab_stops.add_tab_stop(Inches(marker))
        style.paragraph_format.space_after = Pt(4)
        style.paragraph_format.line_spacing = list_spacing

    if "Table Source" not in [s.name for s in doc.styles]:
        source_style = doc.styles.add_style("Table Source", WD_STYLE_TYPE.PARAGRAPH)
    else:
        source_style = doc.styles["Table Source"]
    set_style_font(source_style, 8.5, MUTED)
    source_style.paragraph_format.space_before = Pt(4)
    source_style.paragraph_format.space_after = Pt(4)
    source_style.paragraph_format.line_spacing = 1.0

    header = section.header.paragraphs[0]
    header.text = ""
    header.paragraph_format.space_after = Pt(0)
    run = header.add_run(running_title)
    set_run_font(run, 9, MUTED)
    footer = section.footer.paragraphs[0]
    footer.text = ""
    add_page_number(footer)


def _set_width(parent, tag: str, value: int) -> None:
    node = parent.find(qn(tag))
    if node is None:
        node = OxmlElement(tag)
        parent.append(node)
    node.set(qn("w:type"), "dxa")
    node.set(qn("w:w"), str(value))


def set_cell_margins(cell) -> None:
    tc_pr = cell._tc.get_or_add_tcPr()
    tc_mar = tc_pr.find(qn("w:tcMar"))
    if tc_mar is None:
        tc_mar = OxmlElement("w:tcMar")
        tc_pr.append(tc_mar)
    for side, value in CELL_MARGINS.items():
        node = tc_mar.find(qn(f"w:{side}"))
        if node is None:
            node = OxmlElement(f"w:{side}")
            tc_mar.append(node)
        node.set(qn("w:type"), "dxa")
        node.set(qn("w:w"), str(value))


def shade_cell(cell, fill: str) -> None:
    tc_pr = cell._tc.get_or_add_tcPr()
    shd = tc_pr.find(qn("w:shd"))
    if shd is None:
        shd = OxmlElement("w:shd")
        tc_pr.append(shd)
    shd.set(qn("w:fill"), fill)


def mark_header_repeat(row) -> None:
    tr_pr = row._tr.get_or_add_trPr()
    node = OxmlElement("w:tblHeader")
    node.set(qn("w:val"), "true")
    tr_pr.append(node)


def prevent_row_split(row) -> None:
    tr_pr = row._tr.get_or_add_trPr()
    node = OxmlElement("w:cantSplit")
    node.set(qn("w:val"), "true")
    tr_pr.append(node)


def apply_table_geometry(table, widths_dxa) -> None:
    widths = [int(v) for v in widths_dxa]
    widths[-1] += CONTENT_WIDTH_DXA - sum(widths)
    table.alignment = WD_TABLE_ALIGNMENT.LEFT
    table.autofit = False
    tbl_pr = table._tbl.tblPr
    _set_width(tbl_pr, "w:tblW", CONTENT_WIDTH_DXA)
    indent = tbl_pr.find(qn("w:tblInd"))
    if indent is None:
        indent = OxmlElement("w:tblInd")
        tbl_pr.append(indent)
    indent.set(qn("w:type"), "dxa")
    indent.set(qn("w:w"), str(TABLE_INDENT_DXA))
    layout = tbl_pr.find(qn("w:tblLayout"))
    if layout is None:
        layout = OxmlElement("w:tblLayout")
        tbl_pr.append(layout)
    layout.set(qn("w:type"), "fixed")
    grid = table._tbl.tblGrid
    for child in list(grid):
        grid.remove(child)
    for width in widths:
        col = OxmlElement("w:gridCol")
        col.set(qn("w:w"), str(width))
        grid.append(col)
    for row in table.rows:
        row.height = None
        for idx, cell in enumerate(row.cells):
            cell.width = Twips(widths[idx])
            _set_width(cell._tc.get_or_add_tcPr(), "w:tcW", widths[idx])
            set_cell_margins(cell)


def set_cell_text(cell, text, *, bold=False, color=INK, size=8.25, align=None) -> None:
    cell.text = ""
    paragraph = cell.paragraphs[0]
    paragraph.paragraph_format.space_before = Pt(0)
    paragraph.paragraph_format.space_after = Pt(0)
    paragraph.paragraph_format.line_spacing = 1.12
    if align is not None:
        paragraph.alignment = align
    run = paragraph.add_run(str(text))
    set_run_font(run, size, color, bold)
    cell.vertical_alignment = WD_CELL_VERTICAL_ALIGNMENT.CENTER


def add_table(doc, headers, rows, widths, *, fill=FILL_BLUE, font_size=8.15, stripe=False):
    if sum(widths) != CONTENT_WIDTH_DXA:
        raise ValueError(f"Table widths must total {CONTENT_WIDTH_DXA}: {widths}")
    table = doc.add_table(rows=1, cols=len(headers))
    table.style = "Table Grid"
    for idx, header in enumerate(headers):
        shade_cell(table.rows[0].cells[idx], fill)
        set_cell_text(table.rows[0].cells[idx], header, bold=True, color=DARK_BLUE, size=8.4)
    mark_header_repeat(table.rows[0])
    prevent_row_split(table.rows[0])
    for row_index, values in enumerate(rows):
        if len(values) != len(headers):
            raise ValueError(f"Expected {len(headers)} cells, got {len(values)}: {values}")
        row = table.add_row()
        prevent_row_split(row)
        for idx, value in enumerate(values):
            cell = row.cells[idx]
            if stripe and row_index % 2 == 1:
                shade_cell(cell, FILL_LIGHT)
            text = str(value)
            align = WD_ALIGN_PARAGRAPH.CENTER if len(text) <= 10 else None
            set_cell_text(cell, text, size=font_size, align=align)
    apply_table_geometry(table, widths)
    spacer = doc.add_paragraph()
    spacer.paragraph_format.space_after = Pt(2)
    return table


def add_para(doc, text, *, style=None, size=None, color=INK, bold=None, italic=None, align=None, after=None):
    paragraph = doc.add_paragraph(style=style)
    if align is not None:
        paragraph.alignment = align
    if after is not None:
        paragraph.paragraph_format.space_after = Pt(after)
    run = paragraph.add_run(text)
    set_run_font(run, size, color, bold, italic)
    return paragraph


def add_bullets(doc, items, numbered=False) -> None:
    style = "List Number" if numbered else "List Bullet"
    for item in items:
        add_para(doc, item, style=style)


def add_source(doc, text="数据源：当前工作区 GameData.gd / GameManager.gd / BattleManager.gd。") -> None:
    add_para(doc, text, style="Table Source")


def add_cover(doc, title, subtitle, doc_type, summary) -> None:
    add_para(doc, "COLOR HEROES / VERSION 1.5", size=10.5, color=GOLD, bold=True, align=WD_ALIGN_PARAGRAPH.CENTER, after=28)
    add_para(doc, title, size=29, color=NAVY, bold=True, align=WD_ALIGN_PARAGRAPH.CENTER, after=10)
    add_para(doc, subtitle, size=14, color=DARK_BLUE, align=WD_ALIGN_PARAGRAPH.CENTER, after=24)
    add_para(doc, doc_type, size=10.5, color=MUTED, bold=True, align=WD_ALIGN_PARAGRAPH.CENTER, after=68)
    add_para(doc, summary, size=12, color=INK, align=WD_ALIGN_PARAGRAPH.CENTER, after=48)
    add_para(doc, "运行时数据基线：Godot 4.6.3 · Save v3 · Build 1.5.0", size=9.5, color=MUTED, align=WD_ALIGN_PARAGRAPH.CENTER, after=4)
    add_para(doc, TODAY.isoformat(), size=9.5, color=MUTED, align=WD_ALIGN_PARAGRAPH.CENTER, after=0)
    doc.add_page_break()


def label_color(value: str) -> str:
    return COLOR_LABELS.get(value, value)


def label_rarity(value: str) -> str:
    return RARITY_LABELS.get(value, value)


def card_pool_text(card: dict) -> str:
    return "/".join(label_rarity(x) if x in RARITY_LABELS else label_color(x) for x in card.get("pools", []))


def upgrade_text(card: dict) -> str:
    upgrade = card.get("upgrade", {})
    return str(upgrade.get("effect", "无")) if upgrade else "无"


def intent_text(encounter: dict) -> str:
    parts = []
    for intent in encounter.get("intents", []):
        kind = INTENT_LABELS.get(str(intent.get("type", "")), str(intent.get("type", "")))
        value = intent.get("value", "")
        suffix = ""
        if isinstance(value, float) and value < 1:
            suffix = f" {int(round(value * 100))}%"
        elif value != "" and value != 0:
            suffix = f" {value}"
        if intent.get("color"):
            suffix += f" {label_color(str(intent['color']))}"
        parts.append(kind + suffix)
    return " → ".join(parts)


def card_distribution(data) -> tuple[Counter, Counter]:
    collectible = [card for card in data["SPECTRA"].values() if "curse" not in card.get("pools", [])]
    return Counter(card.get("color") for card in collectible), Counter(card.get("rarity") for card in collectible)


def build_gdd(data) -> None:
    doc = Document()
    configure_document(doc, "narrative_proposal", "色彩勇者：三消镇魂曲 | 1.5 游戏总策划案")
    add_cover(
        doc,
        "《色彩勇者：三消镇魂曲》",
        "1.5 游戏总策划案",
        "正式产品规格 / Game Design Document",
        "以三消交换为资源规划层、棋谱为构筑层、谱弹钉盘为输出层，形成可复玩的回合制 Roguelite。",
    )

    spectra = data["SPECTRA"]
    relics = data["RELICS"]
    events = data["EVENTS"]
    encounters = data["ENCOUNTERS"]
    nodes = data["CHAPTER_NODES"]
    characters = data["STARTING_ARCHETYPES"]
    color_counts, rarity_counts = card_distribution(data)

    add_para(doc, "文档导读", style="Heading 1")
    add_para(doc, "本案描述当前工作区已经接入并通过发布回归的 1.5 运行时内容，把产品定位、核心循环、系统规则、三章节奏、A0-A10 和验收门槛统一到同一口径。数值表中的内容 ID、名称、条件、效果、敌人数值、事件选项与角色配置直接来自 GameData.gd；谱弹、钉盘、统计与进阶规则来自对应运行时脚本。")
    add_table(
        doc,
        ["内容面", "当前运行时规模", "1.5 设计作用"],
        [
            ("棋谱", "84 张可收集 + 1 张诅咒", "把每回合三步变成可构筑的目标序列与谱弹"),
            ("遗物", f"{len(relics)} 件", "改写战斗、经济、路线和资源规则"),
            ("事件", f"{len(events)} 个", "用不可逆代价塑造局内叙事与构筑"),
            ("路线", f"{len(nodes)} 节点 / 3 章 / 每章 3 模板", "普通、精英、挑战、事件、商店、营火与 Boss 分流"),
            ("遭遇", f"{len(encounters)} 场，含 6 挑战", "覆盖攻击、蓄力、污染、抗性、偷取与恢复"),
            ("角色", f"{len(characters)} 名", "提供五种不同的开局约束与成长方向"),
        ],
        [1800, 2100, 5460],
        fill=FILL_LIGHT,
        font_size=8.8,
    )
    add_source(doc)

    add_para(doc, "1. 产品定位", style="Heading 1")
    add_para(doc, "一句话定位", style="Heading 2")
    add_para(doc, "一款以 6×6 四色棋盘为资源规划入口、以棋谱构筑和 9×8 钉盘瞄准为伤害出口的单人回合制 Roguelite：玩家观察敌人意图，在每回合 3 次有效交换中积累色素、完成棋谱、生成谱弹，并通过角色、牌组、遗物、路线与 A0-A10 形成长期构筑。")
    add_para(doc, "设计支柱", style="Heading 2")
    add_bullets(doc, [
        "因果链明确：常规消除不立即扣除敌人 HP；消除产出色素、推进棋谱并触发颜色基础效果。棋谱完成是标准谱弹的主要来源，少数遗物或被动可额外生成碎弹。",
        "可读决策：敌人意图、色谱进度、步数和关键状态在行动前可见，失败应能被玩家复盘。",
        "构筑改变目标：奖励的价值不只是增伤，而是改变下一回合想消什么、以什么顺序消。",
        "风险换强度：黑曜自伤、灰蚀压力、挑战节点和事件代价提供明确且可预览的风险收益。",
        "新学派不稀释棋盘：翠生、紫弦、白昼、黑曜只作为色谱/遗物学派存在，棋盘仍只生成红、蓝、金、灰。",
    ])
    add_para(doc, "版本边界", style="Heading 2")
    add_para(doc, "1.5 是三章单机正式发布基线：完成五角色、84+1 棋谱、72 遗物、36 事件、三章地图轮换、12 套章节钉盘、A0-A10、v3 续局存档和战绩复盘；不增加联网、多人、付费抽卡或局外数值售卖。工程、存档与 Windows 发布元数据统一为 1.5.0。")

    add_para(doc, "2. 目标人群", style="Heading 1")
    add_table(
        doc,
        ["人群", "核心需求", "本作承诺", "主要风险"],
        [
            ("轻中度 Roguelite 玩家", "短周期构筑、路线取舍、失败可复盘", "三章完整单局、A0-A10、角色差异", "卡面信息过载"),
            ("策略三消玩家", "连消规划、颜色顺序、可控随机", "有效交换才消耗步数，级联可预测", "灰色占比过高造成无力感"),
            ("卡组构筑玩家", "牌组压缩、稀有度、遗物协同", "84 张棋谱与 72 件遗物形成组合空间", "自动触发被误解为传统出牌"),
            ("像素 RPG 用户", "角色气质、章节敌人、视听反馈", "五角色与三章主题统一到颜色叙事", "内容文本压过战斗节奏"),
        ],
        [1700, 2450, 3000, 2210],
        fill=FILL_LIGHT,
        font_size=8.1,
    )
    add_para(doc, "主平台为 Windows PC，单局目标 60-90 分钟；单场普通战 3-6 回合、精英 6-10 回合、Boss 8-15 回合。首次体验应在 10 分钟内理解“看意图 → 看棋谱 → 规划三步 → 生成谱弹 → 瞄准钉盘”的决策顺序。")

    add_para(doc, "3. 核心循环", style="Heading 1")
    add_para(doc, "3.1 单回合循环", style="Heading 2")
    add_bullets(doc, [
        "回合开始：敌人展示当前意图，玩家获得 3 步并补足最多 3 张色谱手牌。",
        "观察：比较敌人伤害/污染/抗性与三张色谱条件，选择本回合主目标和可保留目标。",
        "交换：相邻交换只有形成匹配才消耗 1 步；常规消除产生色素并登记颜色、数量、级联和主动标记，不直接造成 HP 伤害。",
        "成弹：棋谱读取本回合事件并自动完成，生成最多 8 颗待发射谱弹；玩家选择角度，钉点命中决定伤害、状态与资源。",
        "敌方行动：燃烧先结算；冻结可令敌人跳过行动；护盾先吸收伤害；污染同时增加灰蚀压力并染灰棋盘。",
        "回合结束：未完成色谱进入弃谱，基础可保留 1 张；下一回合继续。",
    ], numbered=True)
    add_para(doc, "3.2 单局循环", style="Heading 2")
    add_para(doc, "角色选择 → 起点奖励 → 分支地图 → 战斗/事件/商店/营火/宝箱 → 章节 Boss → 章节遗物与下一章 → 最终 Boss → 颜色倾向结算。每次节点选择都围绕 HP、金币、颜料、牌组稳定性和灰蚀压力五类资源权衡。")

    add_para(doc, "4. 三消棋盘与战斗", style="Heading 1")
    add_table(
        doc,
        ["规则", "运行时值", "设计意图"],
        [
            ("棋盘", "6×6；固定四色", "降低自然连消率，强化三步规划与棋谱选择"),
            ("基础颜色", "灰 0.43 / 红 0.19 / 蓝 0.19 / 金 0.19", "灰是环境压力，三种玩家色承担战斗分工"),
            ("基础步数", "每回合 3；额外步最多使当前值到 4", "强制优先级，不允许无限行动"),
            ("匹配", "横/竖 3+；无初始匹配；保证至少一个可行动作", "降低死局与开场随机爆发"),
            ("灰色死锁保护", "灰块占比 >72% 时自动转化 2 格", "避免污染导致无解"),
            ("无效交换", "回滚且不结算有效消除", "错误成本是信息和节奏，而非隐性伤害"),
        ],
        [1800, 3100, 4460],
        fill=FILL_BLUE,
        font_size=8.5,
    )
    add_para(doc, "4.1 色素与谱弹伤害", style="Heading 2")
    add_para(doc, "常规消除的直接 HP 伤害恒为 0。3/4/5/6+ 连基础产出 3/5/8/11 起色素，额外级联层数继续加成。棋谱完成后按普通/稀有/史诗基础谱弹 8/12/18 点起始伤害、每钉 2/3/3 点解析；单球命中数限制为 7-13，多球最多 8，最终再叠加暴击、穿透、角色弹型、章节钉点和明确的碎弹例外。")
    add_table(
        doc,
        ["颜色", "基础战斗作用", "额外规则"],
        [
            ("红焰", "产红色素并叠加燃烧", "红色谱弹偏中心动量、高命中与燃烧兑现"),
            ("蓝霜", "产蓝色素并有 30% 冻结", "蓝色谱弹偏稳定轨迹、精准暴击与护盾"),
            ("金辉", "产金色素与战斗金币", "金色谱弹命中悬赏钉并强化经济转换"),
            ("灰蚀", "产灰色素；可净化或转染", "灰色谱弹偏穿透、危险钉利用与污染转化"),
        ],
        [1500, 3000, 4860],
        fill=FILL_GRAY,
        font_size=8.5,
    )
    add_para(doc, "4.2 敌人意图", style="Heading 2")
    add_para(doc, "运行时支持攻击、重击、蓄力、防御、污染、偷取、固定色抗性、主色抗性、回复、点燃玩家，以及瞄准偏折、暴击压制、布置危险钉、封锁钉点四类下一发干扰。干扰在发射前预告，只消费一颗谱弹并立即清除；三位 Boss 使用不同循环和双阶段钉盘改写。")
    add_para(doc, "4.3 三章钉盘生态", style="Heading 2")
    add_table(doc, ["章节", "9×8 钉盘主题", "主要压力", "Boss 二阶段"], [
        ("C1 灰雾边境", "火焰 / 雾 / 基础弹道", "燃烧兑现、雾钉与轻度偏折", "扩大火焰与雾区，强化污染节拍"),
        ("C2 镜湖工坊", "镜面 / 弹簧 / 抗性", "反射复制、弹簧改道、颜色抗性", "镜面重排并压缩稳定瞄准区"),
        ("C3 无色王庭", "王锁 / 虚无 / 危险钉", "封锁、伤害损失与终局布雷", "锁钉与虚无重写，要求穿透和净化构筑"),
    ], [1650, 2400, 2700, 2610], fill=FILL_RED, font_size=8.0)

    add_para(doc, "5. 色谱系统", style="Heading 1")
    add_para(doc, "棋谱是自动触发的战术契约，也是标准谱弹的主要生成器；红釉剑柄等少数遗物或角色被动可生成低伤碎弹。每张卡由条件、短条件、效果、稀有度、奖励池、谱弹修正和精研数据构成；翠生、紫弦、白昼、黑曜学派使用 condition_type 与 effects 数组接入通用解析器。手牌上限 3，基础保留 1，初始牌组 8 张，删谱下限由运行时保护。")
    add_table(
        doc,
        ["学派/标签", "可收集数", "核心构筑"],
        [(label_color(color), count, {
            "red": "爆发、燃烧、生命换伤害",
            "blue": "护盾、冻结、意图反制",
            "gold": "金币、商店、资源转伤害",
            "gray": "净化、灰蚀压力与转化",
            "neutral": "基础级联与颜料",
            "mixed": "多色同回合与复合收益",
            "green": "回复、护盾、灰色再利用",
            "purple": "级联、顺序消除与节拍",
            "white": "净化、均衡与抗性破除",
            "black": "自伤、灰蚀与高风险回报",
        }.get(color, "")) for color, count in color_counts.items()],
        [1900, 1400, 6060],
        fill=FILL_GREEN,
        font_size=8.7,
    )
    add_para(doc, f"稀有度分布（不含诅咒）：普通 {rarity_counts['common']}、稀有 {rarity_counts['rare']}、史诗 {rarity_counts['epic']}。黑曜契约独立属于事件诅咒池，不进入普通奖励。翠生、紫弦、白昼、黑曜不会进入 COLOR_ORDER 或 BASE_WEIGHTS。")
    add_para(doc, "5.1 全量色谱目录", style="Heading 2")
    spectrum_rows = []
    for card_id, card in spectra.items():
        scope = "诅咒/事件" if "curse" in card.get("pools", []) else card_pool_text(card)
        spectrum_rows.append((
            card_id,
            card.get("name", ""),
            label_color(str(card.get("color", ""))),
            label_rarity(str(card.get("rarity", ""))),
            card.get("condition", ""),
            card.get("effect", ""),
            upgrade_text(card),
            scope,
        ))
    add_table(doc, ["ID", "名称", "学派", "稀有度", "条件", "基础效果", "精研效果", "池"], spectrum_rows, [1220, 900, 650, 650, 1750, 1750, 1750, 690], fill=FILL_GREEN, font_size=6.75, stripe=True)
    add_source(doc, f"数据源：GameData.SPECTRA，共 {len(spectra)} 条；其中 {len(spectra) - 1} 条可收集、1 条事件诅咒。")

    add_para(doc, "6. 遗物系统", style="Heading 1")
    relic_rarity = Counter(item.get("rarity") for item in relics.values())
    add_para(doc, f"遗物不可重复持有，来源包括精英、宝箱、商店、事件与 Boss。当前目录为普通 {relic_rarity['common']}、稀有 {relic_rarity['rare']}、Boss {relic_rarity['boss']}，合计 {len(relics)} 件。遗物应优先改写操作目标或资源转换，而不是只做无条件常驻增伤。")
    relic_rows = [(rid, r.get("name", ""), label_rarity(str(r.get("rarity", ""))), r.get("description", "")) for rid, r in relics.items()]
    add_table(doc, ["ID", "名称", "稀有度", "运行时效果"], relic_rows, [1900, 1300, 900, 5260], fill=FILL_GOLD, font_size=7.8, stripe=True)
    add_source(doc, f"数据源：GameData.RELICS，共 {len(relics)} 件。")

    add_para(doc, "7. 事件与连续事件", style="Heading 1")
    add_para(doc, f"事件承担非战斗构筑变化，所有代价在确认前展示。当前 {len(events)} 个事件均提供 2 个选项；其中 12 个钉板事件围绕暴击、回声、悬赏、穿透与章节钉点生态展开。无色乐团通过 chain_event 进入乐团后台，其他事件通过节点 event_pool 轮换。")
    event_rows = []
    for event_id, event in events.items():
        choices = " / ".join(f"{index + 1}. {choice.get('label', '')}" for index, choice in enumerate(event.get("choices", [])))
        chain_id = next((str(choice.get("chain_event")) for choice in event.get("choices", []) if choice.get("chain_event")), "")
        chain = str(events.get(chain_id, {}).get("title", chain_id)) if chain_id else "-"
        event_rows.append((event_id, event.get("title", ""), event.get("body", ""), choices, chain))
    add_table(doc, ["ID", "事件", "情境", "选项", "后续"], event_rows, [1650, 1150, 2200, 3710, 650], fill=FILL_PURPLE, font_size=7.25, stripe=True)
    add_source(doc, f"数据源：GameData.EVENTS，共 {len(events)} 个；事件实际结算由 GameManager.apply_event_choice 执行。")

    add_para(doc, "8. 商店、营火与经济", style="Heading 1")
    add_table(
        doc,
        ["项目", "基础价格/收益", "递增与例外"],
        [
            ("普通色谱", "45 金币", "商店默认 3 格；旅商铃增至 4 格"),
            ("稀有/史诗池色谱", "70 金币", "商店 1 格，从 rare + epic 池抽取"),
            ("精研", "55 金币", "每购买 1 次 +20；折扣结算后清零"),
            ("删谱", "65 金币", "每删除 1 次 +25；商会印章首次半价"),
            ("治疗", "普通店 40 / Boss 前店 45", "回复 max(30, 25% 最大 HP)"),
            ("遗物", "120 金币", "仅金币 >=100 时展示；可受遗物折扣"),
            ("刷新", "18 金币", "每次 +7；免费刷新优先消耗"),
            ("营火治疗", "30 HP", "第一章 Boss 前 C1-07 为 24 HP"),
            ("营火精研/净化", "免费二选一", "精研随机可升级实例；净化受牌组下限保护"),
            ("宝箱", "25 金币 +1 颜料或遗物", "镀金钥匙允许选择；金币选项提高至 45"),
        ],
        [1900, 2200, 5260],
        fill=FILL_GOLD,
        font_size=8.2,
    )
    add_para(doc, "战后奖励由遭遇 reward 字段给出金币；普通战提供 3 选 1 色谱，精英额外提供遗物并有 50% 概率获得 1 颜料，挑战固定获得 1 颜料且跳过色谱可得 15 金币。前两章 Boss 分别提供 2 颜料和指定 Boss 遗物；最终 Boss 不再发放中途成长奖励。")

    add_para(doc, "9. 路线、挑战与地图交互", style="Heading 1")
    node_counts = Counter(node.get("type") for node in nodes.values())
    add_para(doc, "三章均为 8 层主干，每章由多条同层分支汇合到 Boss。当前节点构成为：" + "、".join(f"{NODE_LABELS.get(k, k)} {v}" for k, v in node_counts.items()) + "。挑战节点只对 character_ids 中的角色显示，确保专属路线有明确身份而不会封死安全路线。")
    challenge_rows = []
    for node_id, node in nodes.items():
        if node.get("type") != "challenge":
            continue
        encounter = encounters.get(node.get("encounter_id"), {})
        names = [characters.get(cid, {}).get("name", cid) for cid in node.get("character_ids", [])]
        challenge_rows.append((node_id, node.get("name", ""), "/".join(names), encounter.get("max_hp", ""), encounter.get("attack", ""), intent_text(encounter), encounter.get("reward", ""), "/".join(encounter.get("reward_pool", []))))
    add_table(doc, ["节点", "挑战", "角色", "HP", "攻击", "意图循环", "金币", "奖励池"], challenge_rows, [1050, 1050, 1250, 550, 550, 3000, 550, 1360], fill=FILL_RED, font_size=7.4)
    add_para(doc, "每章从标准、高危、经营 3 张模板中按运行 Seed 选择，存档恢复同一模板。地图支持鼠标滚轮以指针为中心缩放，范围 0.75×-1.60×、步长 0.10；左键可在空白处拖拽，中键可在任意位置拖拽，视图带 72 px 越界余量并可复位。")

    add_para(doc, "10. 五角色设计", style="Heading 1")
    character_rows = []
    for char_id, char in characters.items():
        deck_names = [spectra.get(card_id, {}).get("name", card_id) for card_id in char.get("deck", [])]
        relic_id = str(char.get("relic", ""))
        relic_name = relics.get(relic_id, {}).get("name", relic_id)
        bias = char.get("bias", {})
        bias_text = "/".join(f"{label_color(k)}+{v}" for k, v in bias.items() if int(v) > 0) or "无"
        character_rows.append((char_id, f"{char.get('name')}\n{char.get('title')}", char.get("max_hp"), char.get("difficulty"), f"{char.get('passive_name')}：{char.get('passive_text')}", relic_name, "、".join(deck_names), bias_text, "/".join(label_color(x) for x in char.get("exclusive_pools", []))))
    add_table(doc, ["ID", "角色", "HP", "定位", "被动", "起始遗物", "8 张起始牌组", "倾向", "专属池"], character_rows, [650, 1050, 550, 600, 2100, 900, 2350, 600, 560], fill=FILL_PURPLE, font_size=7.0)
    add_para(doc, "角色差异来自最大 HP、被动、主动技、初始牌组、起始遗物和弹型：烬歌使用中心动量高速弹，凛镜使用稳定折射弹，洛恩使用悬赏套利弹，弥砂使用净雾穿透重弹，伊澜使用棱镜多球。角色选择在单局开始后锁定。")

    add_para(doc, "11. 三章敌人与 Boss", style="Heading 1")
    chapter_rows = []
    for chapter_id, chapter in data["CHAPTERS"].items():
        chapter_encounters = [e for key, e in encounters.items() if key.startswith(chapter_id + "-") and e.get("node_type") != "challenge"]
        challenge_count = sum(1 for key, e in encounters.items() if key.startswith(chapter_id + "-") and e.get("node_type") == "challenge")
        boss = next((e for e in chapter_encounters if e.get("node_type") == "boss"), {})
        chapter_rows.append((chapter_id, chapter.get("name", ""), chapter.get("theme", ""), len(chapter_encounters), challenge_count, f"{boss.get('name', '')}\nHP {boss.get('max_hp', '')} / ATK {boss.get('attack', '')}", intent_text(boss)))
    add_table(doc, ["章", "章节", "主题", "常规遭遇", "挑战", "Boss", "Boss 意图循环"], chapter_rows, [500, 1700, 2050, 750, 550, 1300, 2510], fill=FILL_RED, font_size=7.7)
    add_para(doc, "第一章建立污染、蓄力和三色基础；第二章引入更高护甲、偷取与轮换抗性；第三章把主色抗性、高污染和重击节拍叠加。最终 Boss 无色王拥有 680 HP，依次使用 50% 主色抗性、污染 5、攻击 34、护甲 48、蓄力 62、重击 62。")

    add_para(doc, "12. A0-A10 与存档", style="Heading 1")
    add_table(
        doc,
        ["难度", "运行时修改"],
        [
            ("A0", "标准规则；50 初始金币。"),
            ("A1", "全部敌人最大 HP ×1.10。"),
            ("A2", "全部敌人伤害 ×1.10。"),
            ("A3", "治疗效果 ×0.85。"),
            ("A4", "金币收益 ×0.85，商店价格 ×1.10。"),
            ("A5", "灰色生成 +5 个百分点，灰蚀积累 ×1.20。"),
            ("A6", "随机危险钉 +5 个百分点，每球额外危钉预算 +1。"),
            ("A7", "精英 HP ×1.15、伤害 ×1.10，危钉再 +1 个百分点。"),
            ("A8", "Boss HP ×1.20、伤害 ×1.15，危钉再 +1 个百分点。"),
            ("A9", "初始金币降至 25，并加入 1 张黑曜契约。"),
            ("A10", "终局压力再次增强；初始金币 0、2 张黑曜契约；精英/Boss 最终倍率受硬上限保护。"),
        ],
        [1200, 8160],
        fill=FILL_BLACK,
        font_size=8.8,
    )
    add_para(doc, "SaveManager 当前 SAVE_VERSION = 3，BUILD_VERSION = 1.5.0，局内存档位于 user://run_save.json。v1 牌组字符串存档迁移为卡牌实例；v2 自动补齐 run_stats、三章 map_template_ids、四项 peg_upgrades 和 A0-A10 边界。恢复时校验节点、牌组、待领奖励、角色、模板、强化等级和数值边界。", align=WD_ALIGN_PARAGRAPH.LEFT)

    add_para(doc, "13. UI、视听与可访问性", style="Heading 1")
    add_bullets(doc, [
        "角色选择：同屏展示五角色的 HP、定位、被动、起始遗物与牌组预览，确认后进入起点。",
        "战斗 HUD：棋盘、敌人意图、HP/护盾/步数、3 张色谱和战斗日志必须同时可读；色谱进度实时更新。",
        "谱弹 HUD：真实绘制 9×8 章节钉盘、下一发干扰、瞄准轨迹、12 次采样伤害区间、待发射队列和实际结算轨迹。",
        "色弱支持：红蓝金灰除色相外使用图标、材质和边框差异；学派色只作为卡面主题，不制造新棋盘辨色负担。",
        "地图：节点按钮不随拖拽误触，缩放后状态与连线保持清晰，固定工具栏显示缩放百分比。",
        "可访问性：支持瞄准预测开关、高对比钉点、减少动态、快速结算和 0.5×-2.0× 战斗速度。",
        "战绩复盘：结算展示回合、交换、棋谱、谱弹、每球命中、暴击率、单发均伤与主伤害来源。",
        "音频：交换、匹配、级联、色谱完成、冻结、污染和 Boss 重击使用不同层级；灰蚀升高时音乐增加不协和声部。",
    ])

    add_para(doc, "14. 数值边界", style="Heading 1")
    add_table(
        doc,
        ["指标", "边界/目标", "超界处理"],
        [
            ("基础棋盘色", "只能为 gray/red/blue/gold", "数据校验失败，禁止发版"),
            ("角色最大 HP", "112-128（当前）", "先调起始牌组与被动，不做局外永久加成"),
            ("手牌/保留", "手牌 3；保留 1，特定遗物可扩展", "禁止形成无限抽取/保留循环"),
            ("回合步数", "基础 3；当前上限 4", "额外步必须有每战或被动触发限制"),
            ("基础金币软上限", "战斗金色收益 24；商会印章约 29", "金色谱另按自身上限结算"),
            ("灰蚀死锁", "灰占比 >72% 自动转化 2 格", "仍无解时重建可行动棋盘"),
            ("牌组", "初始 8；低于 6 禁止继续删除", "事件与商店统一使用实例校验"),
            ("谱弹边界", "每球 7-13 命中；多球 1-8；队列 0-8", "非法类型回退，数值钳制，溢出拒绝/转化"),
            ("普通/精英 TTK", "普通 3-6 / 精英 6-10 回合", "超出两轮时优先调敌人 HP"),
            ("Boss TTK", "8-15 回合", "先调意图与钉盘节拍，再调纯数值"),
        ],
        [1900, 3350, 4110],
        fill=FILL_GRAY,
        font_size=8.2,
    )

    add_para(doc, "15. 1.5 验收指标", style="Heading 1")
    add_bullets(doc, [
        "内容完整：85 条棋谱记录中恰有 84 条可收集与 1 条诅咒；72 件遗物、36 个事件、33 场遭遇、61 个节点、5 名角色均通过引用校验。",
        "棋盘契约：任何运行 10,000 次的基础掉落采样都不出现 green/purple/white/black 色块；初始棋盘无三连且存在至少一个合法交换。",
        "流程闭环：五角色均可从 C1-00 进入三章并完成最终 Boss；战斗、事件、商店、营火、宝箱和待领奖励均能存档恢复。",
        "战斗质量：A0 五角色通关率目标 35%-65%；任一角色低于 25% 或高于 75% 时调整初始牌组、专属池或挑战权重。",
        "构筑质量：普通/稀有/史诗色谱选择率分别目标 8%-25% / 10%-35% / 15%-45%；低于 5% 的卡复核触发可见性。",
        "路线质量：挑战选择率目标 20%-45%，挑战死亡率不高于同章精英的 1.4 倍；每章至少保留一条非挑战可达路线。",
        "经济质量：平均单局至少能完成 2 次商店服务或购买；洛恩折扣不得令删谱/刷新形成免费循环。",
        f"发布门槛：{TEST_SCRIPT_COUNT} 个 Godot 测试脚本严格通过、主场景 180 帧烟测无错误、1280×720 关键界面无重叠、v2→v3 迁移通过，并导出 Windows 1.5.0 内嵌 PCK。",
    ])

    doc.save(OUT_GDD)


def build_balance(data) -> None:
    doc = Document()
    configure_document(doc, "compact_reference_guide", "色彩勇者：三消镇魂曲 | 1.5 角色与关卡数值总表")
    add_cover(
        doc,
        "《色彩勇者：三消镇魂曲》",
        "1.5 角色与关卡数值总表",
        "角色 / 色谱 / 遗物 / 事件 / 路线 / 遭遇 / 经济 Master",
        "本表由当前 GameData.gd 自动展开，用于实现核对、调参与 QA；所有 ID 与基础数值均以运行时为准。",
    )

    spectra = data["SPECTRA"]
    relics = data["RELICS"]
    events = data["EVENTS"]
    encounters = data["ENCOUNTERS"]
    nodes = data["CHAPTER_NODES"]
    characters = data["STARTING_ARCHETYPES"]
    color_counts, rarity_counts = card_distribution(data)

    add_para(doc, "1. 数据基线", style="Heading 1")
    add_table(
        doc,
        ["数据集", "数量", "校验口径"],
        [
            ("SPECTRA", len(spectra), "84 可收集 + 1 事件诅咒"),
            ("RELICS", len(relics), "普通/稀有/Boss 全部计入"),
            ("EVENTS", len(events), "每项 2 个选项"),
            ("ENCOUNTERS", len(encounters), "27 常规 + 6 挑战"),
            ("CHAPTER_NODES", len(nodes), "三章路线节点总数"),
            ("STARTING_ARCHETYPES", len(characters), "五名正式角色"),
        ],
        [2700, 1200, 5460],
        fill=FILL_BLUE,
        font_size=9.0,
    )
    add_para(doc, "基础棋盘颜色顺序：" + " / ".join(data["COLOR_ORDER"]) + "。基础权重：" + " / ".join(f"{key} {value:.3f}" for key, value in data["BASE_WEIGHTS"].items()) + "。翠生、紫弦、白昼、黑曜不进入棋盘生成。")

    add_para(doc, "2. 五角色数值", style="Heading 1")
    rows = []
    for char_id, char in characters.items():
        deck_names = [spectra.get(card_id, {}).get("name", card_id) for card_id in char.get("deck", [])]
        relic_id = str(char.get("relic", ""))
        bias = "/".join(f"{label_color(k)}+{v}" for k, v in char.get("bias", {}).items() if int(v) > 0) or "无"
        rows.append((char_id, f"{char.get('name', '')}\n{char.get('title', '')}", char.get("max_hp", ""), char.get("difficulty", ""), f"{char.get('passive_name', '')}：{char.get('passive_text', '')}", f"{relics.get(relic_id, {}).get('name', relic_id)} ({relic_id})", "、".join(deck_names), bias, "/".join(char.get("exclusive_pools", []))))
    add_table(doc, ["ID", "角色 / 称号", "HP", "定位", "被动", "遗物", "起始牌组", "倾向", "专属池"], rows, [600, 900, 550, 550, 1800, 1100, 2600, 650, 610], fill=FILL_PURPLE, font_size=6.65)
    add_source(doc, "数据源：GameData.STARTING_ARCHETYPES；每名角色牌组固定 8 张。")

    add_para(doc, "3. 色谱总表", style="Heading 1")
    add_para(doc, f"可收集稀有度：普通 {rarity_counts['common']} / 稀有 {rarity_counts['rare']} / 史诗 {rarity_counts['epic']}。学派分布：" + "、".join(f"{label_color(k)} {v}" for k, v in color_counts.items()) + "。")
    for school in ["red", "blue", "gold", "gray", "neutral", "mixed", "green", "purple", "white", "black"]:
        cards = [(card_id, card) for card_id, card in spectra.items() if card.get("color") == school]
        if not cards:
            continue
        add_para(doc, f"3.{len([x for x in ['red','blue','gold','gray','neutral','mixed','green','purple','white','black'] if ['red','blue','gold','gray','neutral','mixed','green','purple','white','black'].index(x) <= ['red','blue','gold','gray','neutral','mixed','green','purple','white','black'].index(school)])} {label_color(school)}", style="Heading 2")
        rows = []
        for card_id, card in cards:
            rows.append((card_id, card.get("name", ""), label_rarity(str(card.get("rarity", ""))), card.get("condition", ""), card.get("effect", ""), upgrade_text(card), card_pool_text(card)))
        add_table(doc, ["ID", "名称", "稀有度", "条件", "基础效果", "精研", "投放池"], rows, [1450, 900, 650, 1500, 1800, 1800, 1260], fill={"green": FILL_GREEN, "purple": FILL_PURPLE, "white": FILL_BLUE, "black": FILL_BLACK}.get(school, FILL_GRAY), font_size=6.65, stripe=True)
    add_source(doc, "数据源：GameData.SPECTRA；黑曜契约属于 curse/event 池。")

    add_para(doc, "4. 遗物总表", style="Heading 1")
    relic_counts = Counter(item.get("rarity") for item in relics.values())
    add_para(doc, f"当前分布：普通 {relic_counts['common']} / 稀有 {relic_counts['rare']} / Boss {relic_counts['boss']}，合计 {len(relics)}。")
    relic_rows = [(rid, item.get("name", ""), label_rarity(str(item.get("rarity", ""))), item.get("description", "")) for rid, item in relics.items()]
    add_table(doc, ["ID", "遗物", "稀有度", "效果"], relic_rows, [2200, 1300, 850, 5010], fill=FILL_GOLD, font_size=7.7, stripe=True)
    add_source(doc, "数据源：GameData.RELICS。")

    add_para(doc, "5. 事件总表", style="Heading 1")
    event_rows = []
    event_locations = {}
    for node_id, node in nodes.items():
        if node.get("type") != "event":
            continue
        for event_id in node.get("event_pool", [node.get("event_id")]):
            if event_id:
                event_locations.setdefault(event_id, []).append(node_id)
        if node.get("event_id"):
            event_locations.setdefault(node.get("event_id"), []).append(node_id)
    for event_id, event in events.items():
        choices = "\n".join(f"{choice.get('id', '')}: {choice.get('label', '')}" for choice in event.get("choices", []))
        chain_id = next((str(choice.get("chain_event")) for choice in event.get("choices", []) if choice.get("chain_event")), "")
        chain = str(events.get(chain_id, {}).get("title", chain_id)) if chain_id else "-"
        event_rows.append((event_id, event.get("title", ""), "/".join(sorted(set(event_locations.get(event_id, [])))) or "链式/备用", event.get("body", ""), choices, chain))
    add_table(doc, ["ID", "事件", "投放节点", "情境", "选项", "后续"], event_rows, [1500, 1050, 1250, 2000, 2910, 650], fill=FILL_PURPLE, font_size=6.95, stripe=True)
    add_source(doc, "数据源：GameData.EVENTS 与 CHAPTER_NODES.event_pool。")

    add_para(doc, "6. 三章遭遇总表", style="Heading 1")
    for chapter_id, chapter in data["CHAPTERS"].items():
        add_para(doc, f"6.{chapter_id[-1]} {chapter.get('name', chapter_id)}", style="Heading 2")
        rows = []
        for encounter_id, encounter in encounters.items():
            if not encounter_id.startswith(chapter_id + "-"):
                continue
            rows.append((encounter_id, encounter.get("name", ""), NODE_LABELS.get(str(encounter.get("node_type", "")), encounter.get("node_type", "")), encounter.get("max_hp", ""), encounter.get("attack", ""), encounter.get("reward", ""), "/".join(encounter.get("reward_pool", [])), intent_text(encounter), encounter.get("description", "")))
        add_table(doc, ["ID", "遭遇", "类型", "HP", "ATK", "金币", "奖励池", "意图循环", "检验点"], rows, [900, 1100, 650, 450, 450, 500, 1050, 2700, 1560], fill=FILL_RED, font_size=6.75, stripe=True)
    add_source(doc, "数据源：GameData.ENCOUNTERS；表内为 A0 基础数值。")

    add_para(doc, "7. 路线节点总表", style="Heading 1")
    for chapter_id, chapter in data["CHAPTERS"].items():
        add_para(doc, f"7.{chapter_id[-1]} {chapter.get('name', chapter_id)}", style="Heading 2")
        rows = []
        for node_id, node in nodes.items():
            if not node_id.startswith(chapter_id + "-"):
                continue
            role_names = "/".join(characters.get(cid, {}).get("name", cid) for cid in node.get("character_ids", [])) or "-"
            event_pool = "/".join(node.get("event_pool", [])) or str(node.get("event_id", "-"))
            rows.append((node_id, node.get("layer", ""), node.get("name", ""), NODE_LABELS.get(str(node.get("type", "")), node.get("type", "")), str(node.get("encounter_id", "-")), event_pool, role_names, "/".join(node.get("edges", [])) or "终点", node.get("description", "")))
        add_table(doc, ["节点", "层", "名称", "类型", "遭遇", "事件池", "限定角色", "后继", "说明"], rows, [850, 350, 1050, 600, 850, 1450, 1000, 1600, 1610], fill=FILL_BLUE, font_size=6.55, stripe=True)
    add_source(doc, "数据源：GameData.CHAPTER_NODES，共 61 个节点。")

    add_para(doc, "8. 商店、营火与奖励数值", style="Heading 1")
    add_table(
        doc,
        ["模块", "项目", "基础值", "递增/条件", "洛恩折后示例"],
        [
            ("商店", "普通谱", "45", "3 格；旅商铃 4 格", "40"),
            ("商店", "稀有/史诗池谱", "70", "1 格", "63"),
            ("商店", "精研", "55", "+20/次", "50 起"),
            ("商店", "删谱", "65", "+25/次；商会印章首次半价", "58 起；印章约 29"),
            ("商店", "治疗", "40 / 45", "回复 max(30, 25% 最大 HP)", "36 / 40"),
            ("商店", "遗物", "120", "金币 >=100 才展示", "108"),
            ("商店", "刷新", "18", "+7/次；免费次数优先", "16 起"),
            ("营火", "治疗", "30", "C1-07 为 24", "不打折"),
            ("营火", "精研", "1 张", "免费，单次节点", "不打折"),
            ("营火", "净化", "1 张", "牌组过薄则失败但完成节点", "不打折"),
            ("宝箱", "金币", "25 + 1 颜料", "镀金钥匙：45 + 1 颜料", "不打折"),
        ],
        [1000, 1300, 1200, 3800, 2060],
        fill=FILL_GOLD,
        font_size=8.0,
    )
    reward_rows = []
    for encounter_id, encounter in encounters.items():
        node_type = str(encounter.get("node_type", "combat"))
        extra = "三选一色谱"
        if node_type == "elite":
            extra = "三选一色谱 + 遗物；50% 颜料+1"
        elif node_type == "challenge":
            extra = "三选一色谱 + 颜料1；跳过奖励15金币"
        elif node_type == "boss":
            extra = f"指定遗物 {encounter.get('boss_relic', '-')}；颜料 {0 if encounter.get('final_boss') else 2}"
        reward_rows.append((encounter_id, NODE_LABELS.get(node_type, node_type), encounter.get("reward", 0), "/".join(encounter.get("reward_pool", [])), extra))
    add_table(doc, ["遭遇", "类型", "基础金币", "色谱池", "附加奖励"], reward_rows, [1200, 900, 1000, 2600, 3660], fill=FILL_GOLD, font_size=7.5, stripe=True)

    add_para(doc, "9. A0-A10 进阶换算", style="Heading 1")
    add_table(
        doc,
        ["层级", "普通 HP/攻击", "精英最终系数", "Boss 最终系数", "经济与环境压力"],
        [
            ("A0", "1.000 / 1.000", "1.000 / 1.000", "1.000 / 1.000", "50 初始金币"),
            ("A1", "1.100 / 1.000", "1.100 / 1.000", "1.100 / 1.000", "同 A0"),
            ("A2", "1.100 / 1.100", "1.100 / 1.100", "1.100 / 1.100", "同 A0"),
            ("A3", "1.100 / 1.100", "1.100 / 1.100", "1.100 / 1.100", "治疗 ×0.85"),
            ("A4", "1.100 / 1.100", "1.100 / 1.100", "1.100 / 1.100", "金币 ×0.85；商店 ×1.10"),
            ("A5", "1.100 / 1.100", "1.100 / 1.100", "1.100 / 1.100", "灰率 +0.05；灰蚀 ×1.20"),
            ("A6", "1.100 / 1.100", "1.100 / 1.100", "1.100 / 1.100", "危钉 +0.05；预算 +1"),
            ("A7", "1.100 / 1.100", "1.265 / 1.210", "1.100 / 1.100", "危钉累计 +0.06"),
            ("A8", "1.100 / 1.100", "1.265 / 1.210", "1.320 / 1.265", "危钉累计 +0.07"),
            ("A9", "1.100 / 1.100", "1.265 / 1.210", "1.320 / 1.265", "25 金；1 张负担"),
            ("A10", "1.188 / 1.155", "1.350 / 1.250", "1.400 / 1.300", "0 金；2 负担；危钉 +0.10/预算 +2"),
        ],
        [1200, 1400, 1800, 1400, 3560],
        fill=FILL_BLACK,
        font_size=8.4,
    )

    add_para(doc, "10. 数值边界与验收", style="Heading 1")
    add_table(
        doc,
        ["检查项", "当前/目标", "验收方式"],
        [
            ("基础棋盘", "6×6；灰 0.43，红/蓝/金各 0.19", "自动采样 + 无解检测"),
            ("角色", "5 名；HP 112-128；每人 8 张起始谱", "数据引用与完整跑局"),
            ("棋谱", "84 可收集 + 1 诅咒", "ID、池、升级、条件、谱弹解析校验"),
            ("遗物", "72 件", "触发时点、钉点交互、不可重复与存档校验"),
            ("事件", "36 个；每项 2 选项", "资源预览、支付不足、钉板强化与链式跳转"),
            ("挑战", "6 场；角色限定可见", "路径可达、奖励池与角色过滤"),
            ("地图", "缩放 0.75-1.60；滚轮/左拖/中拖/复位", "1280×720 与高 DPI 输入测试"),
            ("普通/精英 TTK", "普通 3-6 / 精英 6-10", "战斗日志中位数"),
            ("Boss TTK", "8-15", "五角色 A0/A5/A10 分层样本"),
            ("通关率", "A0 五角色 35%-65%", "每角色至少 50 局模拟/实测"),
            ("存档", "SAVE_VERSION 3；v1/v2 自动迁移", "统计/地图模板/钉板强化/A0-A10 恢复"),
            ("发布", "BUILD_VERSION 1.5.0", f"{TEST_SCRIPT_COUNT} 测试 + 烟测 + 视觉 QA + Windows 导出"),
        ],
        [2200, 3300, 3860],
        fill=FILL_GRAY,
        font_size=8.0,
    )

    doc.save(OUT_BALANCE)


def validate_runtime_counts(data) -> None:
    spectra = data["SPECTRA"]
    collectible = [card for card in spectra.values() if "curse" not in card.get("pools", [])]
    assert len(spectra) == 85
    assert len(collectible) == 84
    assert len(data["RELICS"]) == 72
    assert len(data["EVENTS"]) == 36
    assert len(data["ENCOUNTERS"]) == 33
    assert len(data["CHAPTER_NODES"]) == 61
    assert len(data["STARTING_ARCHETYPES"]) == 5
    assert sorted(data["COLOR_ORDER"]) == ["blue", "gold", "gray", "red"]
    assert abs(sum(data["BASE_WEIGHTS"].values()) - 1.0) < 0.0001


def main() -> None:
    data = load_runtime_data()
    validate_runtime_counts(data)
    build_gdd(data)
    build_balance(data)
    print(OUT_GDD)
    print(OUT_BALANCE)


if __name__ == "__main__":
    main()
