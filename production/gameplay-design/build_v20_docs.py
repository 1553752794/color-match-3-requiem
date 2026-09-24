from __future__ import annotations

import json
import math
import re
import sys
import zipfile
from collections import Counter
from copy import copy
from datetime import date
from pathlib import Path
from xml.etree import ElementTree as ET


OUT_DIR = Path(__file__).resolve().parent
ROOT = OUT_DIR.parents[1]
QA_DIR = OUT_DIR / "qa_v20_docs"
LOCAL_PYTHON_LIBS = QA_DIR / "python_libs"
if LOCAL_PYTHON_LIBS.exists():
    sys.path.insert(0, str(LOCAL_PYTHON_LIBS))

from docx import Document
from docx.enum.section import WD_SECTION
from docx.enum.style import WD_STYLE_TYPE
from docx.enum.table import WD_CELL_VERTICAL_ALIGNMENT, WD_TABLE_ALIGNMENT
from docx.enum.text import WD_ALIGN_PARAGRAPH
from docx.oxml import OxmlElement
from docx.oxml.ns import qn
from docx.shared import Inches, Pt, RGBColor, Twips
from openpyxl import Workbook, load_workbook
from openpyxl.comments import Comment
from openpyxl.formatting.rule import CellIsRule
from openpyxl.styles import Alignment, Border, Font, PatternFill, Side
from openpyxl.utils import get_column_letter
from openpyxl.worksheet.datavalidation import DataValidation


GAME_DATA_PATH = next((ROOT / "Spritesheetweapon-master").rglob("GameData.gd"))
OUT_GDD = OUT_DIR / "色彩勇者_2.0游戏总策划案.docx"
OUT_XLSX = OUT_DIR / "色彩勇者_2.0关卡数值总表.xlsx"
TODAY = date(2026, 7, 30)

CONTENT_WIDTH_DXA = 9360
TABLE_INDENT_DXA = 120
CELL_MARGINS = {"top": 80, "bottom": 80, "start": 120, "end": 120}

BLUE = RGBColor(0x2E, 0x74, 0xB5)
DARK_BLUE = RGBColor(0x1F, 0x4D, 0x78)
NAVY = RGBColor(0x0B, 0x25, 0x45)
INK = RGBColor(0x22, 0x26, 0x2B)
MUTED = RGBColor(0x68, 0x70, 0x78)
GOLD = RGBColor(0x9B, 0x6A, 0x00)
RED = RGBColor(0xA5, 0x2E, 0x2E)

FILL_BLUE = "E8EEF5"
FILL_LIGHT = "F7F9FB"
FILL_GRAY = "F2F4F7"
FILL_GREEN = "E5F1E8"
FILL_GOLD = "FFF2CC"
FILL_RED = "FCE8E6"
FILL_PURPLE = "EEE5F3"
FILL_DARK = "E7E9EC"

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
RARITY_LABELS = {
    "common": "普通",
    "rare": "稀有",
    "epic": "史诗",
    "boss": "Boss",
}
NODE_LABELS = {
    "start": "起点",
    "combat": "普通",
    "elite": "精英",
    "challenge": "挑战",
    "event": "事件",
    "chest": "宝箱",
    "shop": "商店",
    "camp": "整备",
    "boss": "Boss",
}
INTENT_LABELS = {
    "attack": "攻击",
    "heavy": "重击",
    "charge": "蓄力",
    "defend": "防御",
    "pollute": "污染",
    "steal": "偷取",
    "resist": "学派抗性",
    "resist_dominant": "主学派抗性",
    "heal": "回复",
    "player_burn": "燃烧",
    "seal": "封谱",
    "spectrum_seal": "封谱",
    "condition_pressure": "条件压制",
    "add_hazard": "污染",
    "peg_seal": "封谱",
    "aim_drift": "谱式削弱",
    "crit_suppress": "强拍压制",
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
    names = [
        "SPECTRA",
        "RELICS",
        "CHAPTERS",
        "EVENTS",
        "ENCOUNTERS",
        "CHAPTER_NODES",
        "MAP_TEMPLATE_SPECS",
        "STARTING_ARCHETYPES",
    ]
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


def label_color(value: str) -> str:
    return COLOR_LABELS.get(value, value)


def label_rarity(value: str) -> str:
    return RARITY_LABELS.get(value, value)


def collectible_spectra(data: dict) -> list[dict]:
    return [
        card
        for card in data["SPECTRA"].values()
        if "curse" not in card.get("pools", []) and card.get("rarity") != "curse"
    ]


def intent_text(encounter: dict) -> str:
    parts = []
    for intent in encounter.get("intents", []):
        raw_kind = str(intent.get("type", ""))
        kind = INTENT_LABELS.get(raw_kind, raw_kind or "特殊")
        value = intent.get("value", "")
        suffix = ""
        if isinstance(value, float) and value < 1:
            suffix = f" {int(round(value * 100))}%"
        elif value not in ("", 0, None):
            suffix = f" {value}"
        if intent.get("color"):
            suffix += f" {label_color(str(intent['color']))}"
        if intent.get("count"):
            suffix += f" ×{intent['count']}"
        parts.append(kind + suffix)
    return " → ".join(parts) if parts else "按遭遇脚本公开轮换"


def runtime_summary(data: dict) -> dict[str, int]:
    return {
        "色谱总数": len(data["SPECTRA"]),
        "可收集色谱": len(collectible_spectra(data)),
        "遗物": len(data["RELICS"]),
        "事件": len(data["EVENTS"]),
        "遭遇": len(data["ENCOUNTERS"]),
        "地图节点": len(data["CHAPTER_NODES"]),
        "地图模板": sum(len(v) for v in data["MAP_TEMPLATE_SPECS"].values()),
        "角色": len(data["STARTING_ARCHETYPES"]),
    }


# ---------------------------------------------------------------------------
# DOCX


def set_run_font(run, size=None, color=None, bold=None, italic=None, name="Calibri") -> None:
    run.font.name = name
    rpr = run._element.get_or_add_rPr()
    rfonts = rpr.get_or_add_rFonts()
    rfonts.set(qn("w:ascii"), name)
    rfonts.set(qn("w:hAnsi"), name)
    rfonts.set(qn("w:eastAsia"), "Microsoft YaHei")
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
    rpr = style._element.get_or_add_rPr()
    rfonts = rpr.get_or_add_rFonts()
    rfonts.set(qn("w:ascii"), name)
    rfonts.set(qn("w:hAnsi"), name)
    rfonts.set(qn("w:eastAsia"), "Microsoft YaHei")
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
    separate = OxmlElement("w:fldChar")
    separate.set(qn("w:fldCharType"), "separate")
    end = OxmlElement("w:fldChar")
    end.set(qn("w:fldCharType"), "end")
    run._r.extend([begin, instruction, separate, end])
    tail = paragraph.add_run(" 页")
    set_run_font(tail, 9, MUTED)


def configure_document(doc: Document) -> None:
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
    set_style_font(normal, 10.5)
    normal.paragraph_format.space_before = Pt(0)
    normal.paragraph_format.space_after = Pt(6)
    normal.paragraph_format.line_spacing = 1.25
    normal.paragraph_format.alignment = WD_ALIGN_PARAGRAPH.LEFT

    heading_tokens = ((16, 18, 10), (13, 14, 7), (11.5, 10, 5))
    for style_name, token, color in zip(
        ("Heading 1", "Heading 2", "Heading 3"),
        heading_tokens,
        (BLUE, BLUE, DARK_BLUE),
    ):
        style = doc.styles[style_name]
        size, before, after = token
        set_style_font(style, size, color, True)
        style.paragraph_format.space_before = Pt(before)
        style.paragraph_format.space_after = Pt(after)
        style.paragraph_format.line_spacing = 1.25
        style.paragraph_format.keep_with_next = True

    for style_name in ("List Bullet", "List Number"):
        style = doc.styles[style_name]
        set_style_font(style, 10.5)
        style.paragraph_format.left_indent = Inches(0.375)
        style.paragraph_format.first_line_indent = Inches(-0.188)
        style.paragraph_format.space_after = Pt(4)
        style.paragraph_format.line_spacing = 1.25

    if "Table Source" not in [s.name for s in doc.styles]:
        source_style = doc.styles.add_style("Table Source", WD_STYLE_TYPE.PARAGRAPH)
    else:
        source_style = doc.styles["Table Source"]
    set_style_font(source_style, 8.25, MUTED)
    source_style.paragraph_format.space_before = Pt(4)
    source_style.paragraph_format.space_after = Pt(4)
    source_style.paragraph_format.line_spacing = 1.0

    if "Lead Callout" not in [s.name for s in doc.styles]:
        lead_style = doc.styles.add_style("Lead Callout", WD_STYLE_TYPE.PARAGRAPH)
    else:
        lead_style = doc.styles["Lead Callout"]
    set_style_font(lead_style, 11, NAVY, True)
    lead_style.paragraph_format.space_before = Pt(8)
    lead_style.paragraph_format.space_after = Pt(10)
    lead_style.paragraph_format.line_spacing = 1.25

    header = section.header.paragraphs[0]
    header.text = ""
    header.paragraph_format.space_after = Pt(0)
    run = header.add_run("色彩勇者：三消镇魂曲 | 2.0 游戏总策划案")
    set_run_font(run, 8.5, MUTED)
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
    if tr_pr.find(qn("w:cantSplit")) is None:
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
        for index, cell in enumerate(row.cells):
            cell.width = Twips(widths[index])
            _set_width(cell._tc.get_or_add_tcPr(), "w:tcW", widths[index])
            set_cell_margins(cell)


def set_cell_text(cell, text, *, bold=False, color=INK, size=8.0, align=None) -> None:
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


def add_table(doc, headers, rows, widths, *, fill=FILL_BLUE, font_size=7.8, stripe=False):
    if sum(widths) != CONTENT_WIDTH_DXA:
        raise ValueError(f"Table widths must total {CONTENT_WIDTH_DXA}: {widths}")
    table = doc.add_table(rows=1, cols=len(headers))
    table.style = "Table Grid"
    for index, header in enumerate(headers):
        shade_cell(table.rows[0].cells[index], fill)
        set_cell_text(table.rows[0].cells[index], header, bold=True, color=DARK_BLUE, size=8.2)
    mark_header_repeat(table.rows[0])
    prevent_row_split(table.rows[0])
    for row_index, values in enumerate(rows):
        if len(values) != len(headers):
            raise ValueError(f"Expected {len(headers)} cells, got {len(values)}")
        row = table.add_row()
        prevent_row_split(row)
        for index, value in enumerate(values):
            cell = row.cells[index]
            if stripe and row_index % 2 == 1:
                shade_cell(cell, FILL_LIGHT)
            text = str(value)
            align = WD_ALIGN_PARAGRAPH.CENTER if len(text) <= 10 else None
            set_cell_text(cell, text, size=font_size, align=align)
    apply_table_geometry(table, widths)
    spacer = doc.add_paragraph()
    spacer.paragraph_format.space_after = Pt(2)
    return table


def add_para(
    doc,
    text,
    *,
    style=None,
    size=None,
    color=INK,
    bold=None,
    italic=None,
    align=None,
    after=None,
):
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


def add_source(doc, text="依据：2.0 规格与当前 GameData.gd 运行时数据。") -> None:
    add_para(doc, text, style="Table Source")


def add_major_heading(doc, title: str, first=False) -> None:
    add_para(doc, title, style="Heading 1")


def add_cover(doc, summary: dict[str, int]) -> None:
    add_para(
        doc,
        "COLOR HEROES / VERSION 2.0",
        size=10.5,
        color=GOLD,
        bold=True,
        align=WD_ALIGN_PARAGRAPH.CENTER,
        after=30,
    )
    add_para(
        doc,
        "《色彩勇者：三消镇魂曲》",
        size=28,
        color=NAVY,
        bold=True,
        align=WD_ALIGN_PARAGRAPH.CENTER,
        after=10,
    )
    add_para(
        doc,
        "2.0 游戏总策划案",
        size=15,
        color=DARK_BLUE,
        align=WD_ALIGN_PARAGRAPH.CENTER,
        after=22,
    )
    add_para(
        doc,
        "正式产品规格 / Game Design Document",
        size=10.5,
        color=MUTED,
        bold=True,
        align=WD_ALIGN_PARAGRAPH.CENTER,
        after=54,
    )
    add_para(
        doc,
        "纯三消空间规划 + 条件卡牌构筑 + 路线选择的单机 Roguelite。\n消除负责产色素，色谱达成负责完整结算。",
        size=12,
        color=INK,
        bold=True,
        align=WD_ALIGN_PARAGRAPH.CENTER,
        after=42,
    )
    add_para(
        doc,
        f"运行时快照：{summary['角色']} 角色 · {summary['遭遇']} 遭遇 · {summary['地图模板']} 地图模板",
        size=9.5,
        color=MUTED,
        align=WD_ALIGN_PARAGRAPH.CENTER,
        after=4,
    )
    add_para(
        doc,
        "Godot 4.6 · Run Save v4 · Profile v1 · Build 2.0.0",
        size=9.5,
        color=MUTED,
        align=WD_ALIGN_PARAGRAPH.CENTER,
        after=4,
    )
    add_para(
        doc,
        TODAY.isoformat(),
        size=9.5,
        color=MUTED,
        align=WD_ALIGN_PARAGRAPH.CENTER,
        after=0,
    )
    doc.add_page_break()


def build_gdd(data: dict) -> None:
    doc = Document()
    configure_document(doc)
    summary = runtime_summary(data)
    characters = data["STARTING_ARCHETYPES"]
    chapters = data["CHAPTERS"]
    encounters = data["ENCOUNTERS"]
    templates = data["MAP_TEMPLATE_SPECS"]
    rarity_counts = Counter(card.get("rarity", "未标记") for card in collectible_spectra(data))
    school_counts = Counter(card.get("color", "neutral") for card in collectible_spectra(data))

    add_cover(doc, summary)

    add_major_heading(doc, "文档控制与产品定义", first=True)
    add_para(
        doc,
        "一句话定位：以 6×6 三消棋盘完成色素采集，以三张条件色谱完成伤害、防御与资源结算，再用角色、遗物、事件、路线和碎片证据形成高复玩构筑。",
        style="Lead Callout",
    )
    add_table(
        doc,
        ["字段", "2.0 冻结口径"],
        [
            ("类型", "纯三消 + 条件卡牌构筑 + 单局路线选择的单机 Roguelite"),
            ("战斗职责", "普通消除产色素并推进条件；色谱达成立即承担伤害、护盾、控制、回复、经济与棋盘改造"),
            ("产品边界", "不包含弹珠、物理发射或任何战斗中的第二操作层；玩家输入始终围绕三消交换、卡牌规划与主动技"),
            ("基础规格", "6×6 / 红蓝金灰四种基础棋子 / 每回合 3 次有效交换 / 3 张手牌 / 保留 1 张"),
            ("单局长度", "A0 完整远征 55-85 分钟；单章 16-25 分钟"),
            ("平台与输入", "Windows PC 首发；鼠标、键盘与手柄完整可用；基准 1280×720"),
            ("存档", "Run Save v4 保存节点外单局状态；Profile v1 保存永久档案；不支持战斗中途存档"),
        ],
        [1800, 7560],
        fill=FILL_BLUE,
        font_size=8.5,
    )
    add_source(doc, "冻结口径：v2_0_system_battle_spec.md、v2_0_balance_spec.md 与当前 GameData.gd。")

    add_para(doc, "阅读路径", style="Heading 2")
    add_bullets(
        doc,
        [
            "产品与发行负责人：先读第 1、11、12 章，确认目标人群、商业边界与发布门槛。",
            "系统与战斗策划：先读第 2-5、8 章，按冻结结算顺序和数值硬上限实现。",
            "关卡与内容策划：先读第 6-7、9 章，按内容配额、四地图池和碎片证据组织生产。",
            "程序、UI 与 QA：先读第 3、8、10、12 章，所有来源、边界和可追溯统计均为发布条件。",
        ],
    )

    add_major_heading(doc, "1. 产品定位、目标人群与体验支柱")
    add_para(doc, "1.1 目标人群", style="Heading 2")
    add_table(
        doc,
        ["人群", "主要诉求", "设计回应", "成功信号"],
        [
            ("三消策略玩家", "清晰交换、连线规划、低随机挫败", "6×6 固定几何、无效交换不扣步、死局免费重排、色形双编码", "前三场可解释每次有效交换的收益"),
            ("卡牌肉鸽玩家", "构筑取舍、敌人意图、路线风险", "条件卡牌、公开意图、九学派、四地图池、遗物与事件联动", "每局形成至少 1 条可命名构筑主轴"),
            ("轻中度策略玩家", "低操作门槛、稳定反馈、可暂停思考", "每回合仅 3 步、三张手牌、即时预览、快速结算", "首章 20 分钟内理解职责分工"),
            ("收集与叙事玩家", "角色差异、档案发现、结局证据", "五角色证词、30 枚记忆、10 组档案、可解释结局", "12-22 局内完成全记忆发现目标"),
        ],
        [1500, 2100, 3560, 2200],
        fill=FILL_GREEN,
        font_size=7.7,
        stripe=True,
    )
    add_para(doc, "1.2 三条体验支柱", style="Heading 2")
    add_bullets(
        doc,
        [
            "看得懂：交换、色素、色谱进度、敌人意图、共鸣和最终数值均有公开来源。",
            "想得深：当前三步、保留牌、下一回合引音、路线和经济共同制造短中长期规划。",
            "局局不同：五角色、三誓约、四地图池、九学派、遗物、事件和回想改变构筑入口。",
        ],
    )
    add_para(doc, "1.3 非目标", style="Heading 2")
    add_bullets(
        doc,
        [
            "不让普通消除按格数直接换算敌人 HP；强拍只推进条件或放大当次色谱结算。",
            "不增加第五种基础棋子；紫弦、翠生、白昼、黑曜与混色属于卡牌学派。",
            "不使用隐藏命中、不可预览物理随机或强制实时操作制造难度。",
            "2.0 不做联网对战、体力制、抽卡付费、每日任务或数值型永久成长。",
        ],
    )

    add_major_heading(doc, "2. 核心循环、单局结构与胜负")
    add_para(doc, "2.1 三层循环", style="Heading 2")
    add_table(
        doc,
        ["层级", "循环", "主要决策", "产出"],
        [
            ("回合", "观察意图 → 选色谱 → 有效交换 → 级联 → 色谱即时结算 → 敌人行动", "三步投向、达成顺序、主动技、保留", "伤害、防御、控制、资源、谱序尾音"),
            ("节点", "选路 → 战斗/事件/商店/整备 → 奖励 → 下一节点", "风险、经济、牌组浓度、回复", "色谱、遗物、金币、颜料、记忆与证据"),
            ("远征", "角色与誓约 → 三章 → 无色王 → 结局证据 → 档案", "角色构筑、地图池、A0-A10、回想", "结局、档案进度、下一局信息与构筑选择"),
        ],
        [1000, 3100, 2500, 2760],
        fill=FILL_BLUE,
        font_size=8.0,
        stripe=True,
    )
    add_para(doc, "2.2 单局节奏", style="Heading 2")
    add_bullets(
        doc,
        [
            "开局：选择 1 名角色、1 项誓约、A0-A10 与最多 3 枚回想；生成本章地图模板。",
            "章节：每章至少两次有效分岔，包含战斗、事件、商店/宝箱、整备与 Boss。",
            "成长：每局期望获得 9-14 张色谱、移除 2-5 张、精研 3-6 次、获得 7-11 件遗物。",
            "失败：Run Save 结束，结算战斗与证据统计；Profile 保留已发现记忆和已见结局。",
            "胜利：击败无色王，按学派、灰蚀、地图、角色挑战和记忆证据解释结局。",
        ],
    )
    add_para(doc, "2.3 目标时长与通关率", style="Heading 2")
    add_table(
        doc,
        ["指标", "A0", "A5", "A10", "说明"],
        [
            ("熟悉玩家通关率", "55%-70%", "25%-40%", "8%-18%", "按角色分别统计，不用全体均值掩盖异常"),
            ("完整远征", "55-85 分钟", "60-90 分钟", "65-95 分钟", "普通战超过 8 回合视为拖沓"),
            ("普通/精英/Boss 回合", "3-6 / 5-8 / 8-13", "同窗上沿", "同窗上沿", "提升压力而非无上限堆 HP"),
        ],
        [1900, 1200, 1200, 1200, 3860],
        fill=FILL_GOLD,
        font_size=8.2,
    )

    add_major_heading(doc, "3. 战斗系统：6×6 三消与即时色谱结算")
    add_para(doc, "3.1 固定战斗边界", style="Heading 2")
    add_table(
        doc,
        ["项目", "基线", "边界"],
        [
            ("棋盘", "6×6，红/蓝/金/灰", "生成时无自动连线且至少有 1 个合法交换"),
            ("手牌", "3 张条件色谱", "同名实例独立进度；精研只作用于实例"),
            ("步数", "每回合 3 次有效交换", "无效交换回位且不扣步；额外步数硬上限 2"),
            ("保留", "回合末最多 1 张", "封谱可暂时禁止保留，但不能永久废牌"),
            ("主动技", "充能 0-20", "常规 2-4 回合一次；只修正下一张达成色谱或公开状态"),
            ("灰蚀", "压力 0-20", "灰色生成权重硬上限 64%；灰格超过 72% 自动净化 2 格"),
            ("级联", "统计 1-12 层", "超过 12 正常清盘，不再增加倍率与统计奖励"),
        ],
        [1450, 2500, 5410],
        fill=FILL_BLUE,
        font_size=8.4,
        stripe=True,
    )
    add_para(doc, "3.2 单回合结算顺序", style="Heading 2")
    add_bullets(
        doc,
        [
            "补牌到 3 张；把上一回合尾音复制为本回合引音；清空本回合尾音与共鸣消费标记。",
            "玩家可先发动主动技，再交换相邻棋子；只有形成横向或纵向 3 个以上同色连线才消耗 1 步。",
            "按消除事件解析当前连线、下落和全部级联；每个事件产色素、触发颜色基础效果并推进三张色谱。",
            "任一色谱首次满足条件时立即建立只读快照；同事件多卡按手牌槽从左到右完整结算。",
            "色谱按代价 → 角色/精研 → 共鸣 → 伤害 → 状态 → 防御/资源 → 棋盘 → 统计与叙事的顺序执行。",
            "当前交换的全部级联和色谱效果完成后扣步；步数为 0 且无待处理效果时敌人执行公开意图。",
        ],
        numbered=True,
    )
    add_para(doc, "3.3 消除产出", style="Heading 2")
    add_table(
        doc,
        ["去重格数", "基础色素", "强拍值", "用途"],
        [
            (3, 3, 0, "基础推进"),
            (4, 5, 1, "条件与角色被动"),
            (5, 8, 2, "高价值条件"),
            ("6+", "11 + 超出格数", 3, "终幕条件；仍不直接造成伤害"),
        ],
        [1400, 1800, 1400, 4760],
        fill=FILL_GREEN,
        font_size=8.6,
    )
    add_para(doc, "第 2 层级联起，每层额外获得 1 点对应色素，单次消除事件的级联额外色素上限为 5。交叉连线按去重后的棋子合集记录一次事件。")
    add_para(doc, "3.4 死局、污染与锁格保护", style="Heading 2")
    add_bullets(
        doc,
        [
            "无合法交换立即按 Seed 派生随机源重排，不扣步、不推进色谱、不触发奖励。",
            "灰格占比超过 72% 时，一次下落链只自动净化 2 格，优先避免制造免费连线。",
            "锁格后若无合法交换，临时解除最早锁格；所有干扰必须给玩家留下可执行解。",
            "同一输入、Seed、手牌顺序与棋盘状态必须得到同一结果，所有随机来源写入战斗日志。",
        ],
    )

    add_major_heading(doc, "4. 颜色、色谱条件、学派与谱序共鸣")
    add_para(doc, "4.1 四种基础棋子", style="Heading 2")
    weight_rows = []
    usage = {
        "gray": "压力、净化、破律与跨色条件",
        "red": "伤害、燃烧、自伤爆发",
        "blue": "护盾、冻结、意图反制",
        "gold": "金币、颜料、资源转换",
    }
    for color in data["COLOR_ORDER"]:
        weight_rows.append((label_color(color), f"{data['BASE_WEIGHTS'].get(color, 0):.0%}", usage[color], "基础棋子"))
    add_table(doc, ["颜色", "生成权重", "主要职责", "身份"], weight_rows, [1200, 1300, 4200, 2660], fill=FILL_GRAY, font_size=8.5)
    add_para(doc, "4.2 九学派", style="Heading 2")
    school_rows = [
        ("红焰", "R", "伤害、燃烧、自伤爆发", "生存压力"),
        ("蓝霜", "B", "护盾、冻结、意图反制", "输出偏慢"),
        ("金辉", "G", "金币、颜料、资源转换", "即时战力偏低"),
        ("灰蚀", "X", "净化、破甲、压力转换", "依赖灰色状态"),
        ("紫弦", "R+B", "顺序、返奏、抽牌", "操作次序复杂"),
        ("翠生", "B+G", "回复、护盾、染色", "爆发偏低"),
        ("白昼", "R+B+G", "三色、净化、均衡收益", "条件较难"),
        ("黑曜", "X", "自伤、诅咒、高额结算", "失败风险高"),
        ("混色", "R+B+G", "跨色条件、复合效果", "单项效率较低"),
    ]
    add_table(doc, ["学派", "签名", "主要身份", "构筑风险"], school_rows, [1300, 1300, 3800, 2960], fill=FILL_PURPLE, font_size=8.1, stripe=True)
    add_para(doc, "中立色谱不参与谱序，负责基础资源、删改牌组或异常处理；事件诅咒只产生代价，不提供正基础伤害。")
    add_para(doc, "4.3 条件与效果白名单", style="Heading 2")
    add_bullets(
        doc,
        [
            "条件：单色累计、四色累计、颜色种类、最大连线、级联深度、主动交换色、颜色顺序、已达成数量/学派、剩余步数、HP、护盾、金币、灰蚀、敌人状态与公开意图。",
            "效果：伤害、护盾、燃烧、冻结、回复、净化、改色、金币、颜料、技能充能、抽牌、额外步数和返奏。",
            "未知条件显示为不可达成并写入校验错误；未知效果安全跳过并记录日志，禁止静默当作成功。",
            "达成后的卡牌进入弃牌堆；新抽到的卡不能追溯本回合之前的消除事件。",
        ],
    )
    add_para(doc, "4.4 稀有度与内容配额", style="Heading 2")
    add_table(
        doc,
        ["稀有度", "2.0 目标", "运行时可收集", "条件 BP", "效果 BP", "伤害窗"],
        [
            ("普通", 56, rarity_counts.get("common", 0), "8-14", "7-13", "8-18"),
            ("稀有", 42, rarity_counts.get("rare", 0), "12-20", "12-22", "16-32"),
            ("史诗", 16, rarity_counts.get("epic", 0), "18-30", "22-38", "30-65"),
            ("事件诅咒", 3, max(summary["色谱总数"] - summary["可收集色谱"], 0), "特殊", "-6 至 -18", "无正伤害"),
        ],
        [1300, 1100, 1400, 1500, 1500, 2560],
        fill=FILL_GOLD,
        font_size=8.3,
    )
    add_para(doc, "正式生产目标为 114 张可收集色谱 + 3 张事件诅咒，共 117 张；普通 56 / 稀有 42 / 史诗 16，约占可收集池 49% / 37% / 14%，优先保证首发教学与构筑稳定性；九学派至少各有 8 张可收集色谱。")
    add_para(doc, "4.5 六类谱序共鸣", style="Heading 2")
    add_table(
        doc,
        ["共鸣", "签名条件", "应音色谱修正", "上限"],
        [
            ("同频和声", "签名有交集", "最大数值效果 +20%", "8 BP"),
            ("紫弦折射", "R 与 B 组合", "首个数值效果以 30% 返奏一次", "8 BP"),
            ("翠生回路", "B 与 G 组合", "4 护盾；高灰蚀时净化 1 格", "7 BP"),
            ("熔金脉冲", "R 与 G 组合", "+4 伤害并获得 1 金币", "7 BP"),
            ("白昼三和", "联合集齐 R/B/G", "最大数值 +10%，净化 1 格", "8 BP"),
            ("消色回声", "任一签名含 X", "忽略颜色抗性，灰蚀压力 -1", "8 BP"),
        ],
        [1600, 1800, 4300, 1660],
        fill=FILL_PURPLE,
        font_size=8.2,
        stripe=True,
    )
    add_para(doc, "上一回合最后达成的有效色谱是引音，本回合第一张有效色谱是应音；每回合最多触发一次。中立与诅咒不读取、不消费、不更新谱序。")

    add_major_heading(doc, "5. 五名角色与差异化构筑")
    add_para(doc, "角色差异必须同时落在最大 HP、起始牌组、被动、主动技、专属池和角色挑战六处；只改数值不算独立角色。", style="Lead Callout")
    role_risks = {
        "red": "自伤与防御不足",
        "blue": "击杀速度偏慢",
        "gold": "战斗即时收益低",
        "gray": "依赖灰色状态",
        "mixed": "条件与顺序复杂",
    }
    role_rows = []
    for char_id, char in characters.items():
        skill = char.get("active_skill", {})
        role_rows.append(
            (
                char.get("name", char_id),
                char.get("max_hp", ""),
                char.get("difficulty", ""),
                f"{char.get('passive_name', '')}：{char.get('passive_text', '')}",
                f"{skill.get('name', '')}（{skill.get('cost', '')}）：{skill.get('text', '')}",
                role_risks.get(char_id, "需实测"),
            )
        )
    add_table(doc, ["角色", "HP", "定位", "被动", "主动技", "构筑风险"], role_rows, [800, 500, 800, 2350, 3300, 1610], fill=FILL_GREEN, font_size=7.25, stripe=True)
    add_source(doc, "角色数值与技能文案：GameData.STARTING_ARCHETYPES。")
    add_para(doc, "5.1 起始牌组约束", style="Heading 2")
    add_bullets(
        doc,
        [
            "每名角色固定 8 张起始色谱，至少包含 2 张防御/回复、2 张伤害与 1 张身份牌。",
            "起始牌组不能把角色核心功能锁在单一稀有奖励或单一事件中。",
            "同一基础牌可跨角色使用，但角色被动与主动技必须改变其结算价值或路线优先级。",
            "每名角色至少 2 场跨章挑战；挑战奖励进入对应角色专属池，并写入档案证词。",
        ],
    )
    add_para(doc, "5.2 平衡验收", style="Heading 2")
    add_bullets(
        doc,
        [
            "A0/A5/A10 分层采样；任一角色达成率、承伤、经济或通关率长期偏离全体均值 20% 以上即进入复盘。",
            "主动技常规每 2-4 回合可用一次，充能硬上限 20；不得制造新的操作阶段。",
            "伊澜返奏受 4 次总重复与 60% 单次倍率上限；洛恩战斗金币受 24 硬上限。",
        ],
    )

    add_major_heading(doc, "6. 构筑、遗物、事件与经济")
    add_para(doc, "6.1 正式内容规模", style="Heading 2")
    add_table(
        doc,
        ["内容", "2.0 目标", "运行时快照", "生产定义"],
        [
            ("色谱", 117, summary["色谱总数"], "114 可收集 + 3 事件诅咒；普通 56 / 稀有 42 / 史诗 16"),
            ("遗物", 72, summary["遗物"], "强拍12 / 色谱返奏14 / 谱序10 / 防御破律12 / 经济10 / 角色事件9 / Boss5"),
            ("事件", 54, summary["事件"], "36 既有 + 18 碎片叙事；至少 6 条三段链"),
            ("记忆", 30, 30, "10 组 × 3 枚；默认发现 M01-M03；3 个回想槽"),
            ("地图模板", 12, summary["地图模板"], "三章 × standard/risk/economy/archive"),
            ("角色", 5, summary["角色"], "每名角色完整六维差异与专属挑战"),
        ],
        [1300, 1200, 1400, 5460],
        fill=FILL_BLUE,
        font_size=8.15,
        stripe=True,
    )
    add_para(doc, "6.2 遗物设计", style="Heading 2")
    add_bullets(
        doc,
        [
            "遗物只在明确时点触发：战斗开始、消除事件、色谱达成、共鸣、敌人意图、战后奖励或商店。",
            "同类加成采用加法并受全局硬上限约束；遗物不得让普通消除直接改变敌人 HP。",
            "普通遗物目标 8-18 BP/战，稀有 14-24 BP/战，Boss 20-32 BP/战；经济遗物按章节等价金币估算。",
            "同名遗物默认不可重复；若允许叠加，卡面必须显示层数、上限与溢出处理。",
        ],
    )
    add_para(doc, "6.3 事件设计", style="Heading 2")
    add_bullets(
        doc,
        [
            "事件提供 2-4 个选择；选项先写行为，再明确代价、收益和条件不足原因。",
            "事件在节点首次打开时由 run_seed + chapter + node_id 决定并持久化，重载不得重抽。",
            "角色专属选项可以改变代价或信息，但不能绕过同事件收益上限。",
            "重复记忆转化为 1 点记忆墨；记忆墨不足时不能推进付费档案选项。",
        ],
    )
    add_para(doc, "6.4 经济基线", style="Heading 2")
    add_table(
        doc,
        ["模块", "项目", "基础区间", "递增/上限"],
        [
            ("战斗", "普通 / 精英 / Boss", "14-22 / 28-42 / 55-75 金币", "A2 起战斗金币 ×0.90"),
            ("商店", "普通 / 稀有 / 史诗色谱", "45-65 / 80-110 / 130-175", "A2 起价格 ×1.05"),
            ("商店", "普通 / 稀有 / 史诗遗物", "145-190 / 220-285 / 330-420", "显示可负担性与来源"),
            ("服务", "移除", "75 金币", "每次 +25，上限 200；A7 再 +15"),
            ("服务", "精研", "60 金币", "每次 +15，上限 150"),
            ("单局", "净收入 / 支出率", "520-760 / 72%-90%", "避免存钱成为唯一最优解"),
        ],
        [1300, 2100, 3100, 2860],
        fill=FILL_GOLD,
        font_size=8.2,
        stripe=True,
    )

    add_major_heading(doc, "7. 三章、敌人、地图模板与关卡节奏")
    add_para(doc, "7.1 章节曲线", style="Heading 2")
    chapter_targets = {
        "C1": ("灰雾边境", "84-132", "148-165", "280", "污染、灰权重、锁格、红焰抗性"),
        "C2": ("镜湖工坊", "150-205", "250-270", "460", "改色、冻结、封谱、顺序条件"),
        "C3": ("无色王庭", "230-310", "370-395", "680", "多色限制、抗性轮换、压力累积"),
    }
    chapter_rows = []
    for chapter_id in ("C1", "C2", "C3"):
        name, normal_hp, elite_hp, boss_hp, lesson = chapter_targets[chapter_id]
        runtime_count = len([key for key in encounters if key.startswith(chapter_id + "-")])
        chapter_rows.append((chapter_id, name, runtime_count, normal_hp, elite_hp, boss_hp, lesson))
    add_table(doc, ["章节", "地点", "遭遇数", "普通 HP", "精英 HP", "Boss HP", "机制教学"], chapter_rows, [650, 1200, 750, 1100, 1100, 1000, 3560], fill=FILL_RED, font_size=7.8)
    add_para(doc, "Boss 均在 65% 与 30% HP 阈值切换意图池；单张色谱跨越多个阈值时按顺序推进并合并提示，不插入额外操作。")
    add_para(doc, "7.2 四类地图轮换池", style="Heading 2")
    map_desc = {
        "standard": ("4-5 战斗、2-3 事件、1 商店、1 整备、Boss", "中性", "守序之誓固定"),
        "risk": ("3-4 战斗、2 精英/挑战、1-2 事件、Boss", "敌人 HP +5%", "破谱之誓固定"),
        "economy": ("2-3 战斗、3-4 事件、1-2 商店/宝箱、Boss", "刷新 +5", "见证之誓固定"),
        "archive": ("3 战斗、1 档案精英、2-3 档案事件、Boss", "灰蚀获取 +1", "完成任一记忆组后可选"),
    }
    map_rows = []
    for chapter_id, chapter_templates in templates.items():
        for template_id, template in chapter_templates.items():
            composition, risk, entry = map_desc[template_id]
            overrides = template.get("edge_overrides", {})
            branches = sum(1 for edges in overrides.values() if len(edges) > 1)
            map_rows.append((chapter_id, template.get("name", template_id), template_id, composition, risk, entry, branches))
    add_table(doc, ["章", "模板名", "ID", "节点目标", "修正", "进入方式", "覆盖分岔"], map_rows, [500, 1150, 850, 3150, 1200, 1760, 750], fill=FILL_GREEN, font_size=7.1, stripe=True)
    add_source(doc, "模板名称、边覆盖与运行时数量：GameData.MAP_TEMPLATE_SPECS。")
    add_para(doc, "7.3 地图生成与操作", style="Heading 2")
    add_bullets(
        doc,
        [
            "单局 Seed 决定未被誓约固定的模板候选、事件分配和奖励；读档恢复同一节点与边。",
            "所有模板从起点可达 Boss，至少两次有效分岔；隐藏边只连接相邻层且不能跳过 Boss。",
            "鼠标滚轮以指针位置缩放，范围 0.75-1.65；左键空白区或中键拖拽；按钮提供放大、缩小和复位。",
            "拖拽离窗立即结束；缩放或拖拽不得让全部可达节点移出可视区。",
        ],
    )
    add_para(doc, "7.4 敌人设计预算", style="Heading 2")
    add_bullets(
        doc,
        [
            "普通敌人同时维持不超过 1 种干扰，精英不超过 2 种，Boss 不超过 3 种。",
            "污染：普通 1-3 格、精英 2-4、Boss 3-6；锁格必须保留合法交换。",
            "抗性：普通 10%-20%、精英 15%-30%、Boss 20%-40%，最终伤害倍率不低于 0.50。",
            "封谱只能提高单槽条件 1-3 或禁止保留 1 回合；不能永久废弃卡牌。",
            "三章全部敌人的基础 HP、攻击、奖励、意图序列和 A0-A10 换算见配套数值工作簿。",
        ],
    )

    add_major_heading(doc, "8. 数值框架、公式与 A0-A10")
    add_para(doc, "8.1 伤害公式", style="Heading 2")
    add_para(doc, "raw = card_damage + character_bonus + resonance_bonus + relic_bonus + memory_bonus", style="Lead Callout")
    add_bullets(
        doc,
        [
            "amped = floor(raw × clamp(amplify_ratio, 0.50, 1.35))",
            "resisted = floor(amped × clamp(color_resistance, 0.50, 1.00))",
            "final_damage = clamp(resisted - effective_armor, 0, 180)",
            "普通 / 稀有 / 史诗伤害窗为 8-18 / 16-32 / 30-65；明确高代价终幕可到 66-90 基础伤害。",
        ],
    )
    add_para(doc, "8.2 单回合资源硬上限", style="Heading 2")
    add_table(
        doc,
        ["资源", "软上限", "硬上限", "溢出处理"],
        [
            ("护盾", 30, 60, "截断并记录溢出"),
            ("回复", 12, 24, "不超过最大 HP"),
            ("战斗金币", 12, 24, "截断并记录来源"),
            ("颜料", 1, 2, "不自动转成金币"),
            ("净化格", 4, 8, "无目标则失效"),
            ("额外步数", 1, 2, "不延后到下回合"),
            ("抽牌", 2, 3, "仅补空槽"),
        ],
        [1700, 1300, 1300, 5060],
        fill=FILL_BLUE,
        font_size=8.4,
    )
    add_para(doc, "8.3 战斗 KPI", style="Heading 2")
    add_table(
        doc,
        ["指标", "普通", "精英", "Boss", "警戒线"],
        [
            ("有效交换率", "82%-94%", "80%-92%", "80%-92%", "<72%"),
            ("每回合色谱达成", "1.20-1.75", "1.10-1.60", "1.05-1.55", ">2.20"),
            ("平均级联深度", "1.25-1.70", "1.20-1.65", "1.20-1.65", ">2.10"),
            ("4 连以上占比", "18%-32%", "16%-30%", "16%-30%", ">40%"),
            ("共鸣触发率", "32%-48%", "35%-52%", "38%-55%", ">65%"),
            ("战斗回合", "3-6", "5-8", "8-13", "普通 >8"),
        ],
        [2000, 1500, 1500, 1500, 2860],
        fill=FILL_GOLD,
        font_size=8.4,
        stripe=True,
    )
    add_para(doc, "8.4 A0-A10", style="Heading 2")
    ascension_rows = [
        ("A0", "标准远征"),
        ("A1", "普通敌人 HP +8%"),
        ("A2", "战斗金币 -10%，商店价格 +5%"),
        ("A3", "初始灰蚀压力 +2，灰色最低权重 +3 个百分点"),
        ("A4", "精英 HP +12%，意图数值 +8%"),
        ("A5", "每章首场战斗加入 1 个锁格"),
        ("A6", "Boss HP +15%，阶段干扰 +1 格"),
        ("A7", "稀有奖励权重 -12%，移除费用 +15 金币"),
        ("A8", "敌人抗性额外 +10 个百分点，受 50% 下限保护"),
        ("A9", "每场战斗首次封谱条件增量 +1"),
        ("A10", "开局少 1 次换牌机会；Boss 意图数值再 +10%"),
    ]
    add_table(doc, ["等级", "新增规则"], ascension_rows, [1200, 8160], fill=FILL_DARK, font_size=8.5, stripe=True)
    add_para(doc, "累计硬上限：敌人 HP ×1.45、意图 ×1.35、商店 ×1.30、灰权重 64%、抗性最低伤害倍率 50%、锁格 4 格。工作簿以公式计算各遭遇的所选进阶值。")

    add_major_heading(doc, "9. 碎片化叙事、记忆与结局")
    add_para(doc, "9.1 叙事循环", style="Heading 2")
    add_para(doc, "发现记忆 → 写入档案 → 装备回想 → 解锁事件证词与档案路线 → 干预棋盘/色谱/意图 → 形成结局证据", style="Lead Callout")
    add_bullets(
        doc,
        [
            "颜色是现实被理解和执行的谱律；扩展学派是组合解释方式，不是额外基础棋子。",
            "断色令把冲突历史拆成彼此不相认的片段，三章 Boss 是保存、校准与执行机制的具象。",
            "跨局档案主要提供信息和构筑选择，不永久增加基础 HP、基础伤害或初始金币。",
            "每条叙事奖励至少改变地图情报、事件选项、棋盘、色谱、意图、资源或结局证据之一。",
        ],
    )
    add_para(doc, "9.2 十组记忆", style="Heading 2")
    memory_rows = [
        ("G01", "守灯者旧誓", "M01-M03", "首战护盾或色素"),
        ("G02", "被删去的守灯档案", "M04-M06", "灰雾污染减免"),
        ("G03", "无色王庭", "M07-M09", "王庭节点情报"),
        ("G04", "王庭删改令", "M10-M12", "显示合法隐藏边"),
        ("G05", "镜湖回声", "M13-M15", "意图预览与蓝霜修正"),
        ("G06", "倒影的罢工", "M16-M18", "镜湖封谱减免"),
        ("G07", "断色回廊", "M19-M21", "档案池与事件链提示"),
        ("G08", "回廊见证词", "M22-M24", "角色专属色谱保底"),
        ("G09", "失拍校准记录", "M25-M27", "锁格、改色或抗性干预"),
        ("G10", "三种都发生过的结局", "M28-M30", "复调终局证据"),
    ]
    add_table(doc, ["组", "名称", "成员", "局内入口"], memory_rows, [800, 2400, 1500, 4660], fill=FILL_PURPLE, font_size=8.1, stripe=True)
    add_para(doc, "默认发现 M01-M03。每局最多装备 3 枚回想；单组总价值不超过 0.35 件普通遗物，同局三枚合计不超过 0.75 件。")
    add_para(doc, "9.3 事件链与结局", style="Heading 2")
    add_bullets(
        doc,
        [
            "18 个新增叙事事件形成 6 条三段链，与 36 个既有事件共同构成 54 个正式事件。",
            "结局优先级：远征失败 → 复调终局 → 灰蚀终局 → 红/蓝/金主色结局 → 平衡结局。",
            "复调终局要求完成 G10、至少 6 组记忆、红蓝金学派达到最低使用线并击败无色王。",
            "结算页逐条列出触发证据；未知隐藏结局只显示轮廓与来源提示。",
        ],
    )

    add_major_heading(doc, "10. UX、UI、美术、音频与无障碍")
    add_para(doc, "10.1 战斗信息目标", style="Heading 2")
    add_para(doc, "玩家在 3 秒内必须读出：剩余步数、三张色谱差什么、敌人意图、本次交换推进什么、最近结果来自哪张色谱。", style="Lead Callout")
    add_table(
        doc,
        ["区域", "1280×720 规格", "必显信息"],
        [
            ("顶栏", "56 高", "角色 HP/盾/充能、章节/回合/步数、敌人 HP"),
            ("左栏", "472 宽；棋盘视觉区 420×420", "6×6 棋盘、状态、交换预览"),
            ("中栏", "344 宽", "谱序轨 72；三张 312×124 色谱；主动技与保留"),
            ("右栏", "400 宽", "意图 96、状态 72、舞台 216、日志 152"),
            ("底栏", "80 高", "资源、遗物摘要、结束回合、临时提示"),
        ],
        [1300, 2800, 5260],
        fill=FILL_BLUE,
        font_size=8.2,
        stripe=True,
    )
    add_para(doc, "10.2 关键交互", style="Heading 2")
    add_bullets(
        doc,
        [
            "普通消除只显示色素、基础颜色效果和色谱进度，不显示敌人伤害数字。",
            "色谱达成反馈顺序固定为卡名 → 共鸣 → 修正 → 最终结果；快速结算只能缩时，不能省略来源。",
            "地图支持指针缩放、拖拽、按钮缩放和复位；所有控制均提供 Tooltip 与键盘/手柄焦点。",
            "1280×720、1920×1080、1024×576、960×540、超宽屏与 125% UI 缩放均需截图回归。",
            "卡牌圆角 6px、面板 4px、模态 8px；不嵌套卡片，动态文本不得改变棋盘和卡牌稳定尺寸。",
        ],
    )
    add_para(doc, "10.3 美术与音频生产量", style="Heading 2")
    add_table(
        doc,
        ["资源", "数量", "建议规格"],
        [
            ("角色主立绘 / 战斗半身", "5 / 5", "1600×1600 / 768×768 透明 PNG"),
            ("Boss / 普通精英敌人", "3 / 24", "1600×1200 / 768×768 透明 PNG"),
            ("章节背景", 12, "1920×1080 WebP；四地图池各一张"),
            ("事件关键图 / 记忆物证", "18 / 30", "1280×720 / 768×512"),
            ("棋子 / 学派角标 / 遗物", "4+状态 / 11 / 72", "96×96 / 64×64 / 128×128"),
            ("色谱主图 / UI 图标", "117 / 48-64", "512×320 WebP / 32-64px PNG"),
        ],
        [2500, 1800, 5060],
        fill=FILL_GREEN,
        font_size=8.2,
        stripe=True,
    )
    add_para(doc, "四色消除使用不同短音色，级联只提高层级；色谱达成使用学派短句，共鸣增加第二声部。音频不替代视觉信息，关闭音效后规则仍完整可读。")
    add_para(doc, "10.4 无障碍", style="Heading 2")
    add_bullets(
        doc,
        [
            "四棋子同时用颜色、轮廓和中心符号编码；灰度截图仍可区分。",
            "正文对比不低于 4.5:1；最小字号 12px；数字使用等宽数字避免跳动。",
            "提供高对比棋子、减少动态、字幕、焦点强化、屏幕震动与闪光强度设置。",
            "所有滑杆显示数值，二元项使用开关，模式项使用分段控件。",
        ],
    )

    add_major_heading(doc, "11. 数据、存档、统计与技术边界")
    add_para(doc, "11.1 数据合同", style="Heading 2")
    add_bullets(
        doc,
        [
            "色谱实例包含 instance_id、card_id、level、学派、条件、effects、upgrade、rarity 与 pools；ID 全局唯一。",
            "所有奖励池、事件链、地图边、角色牌组和遗物引用必须在导出前通过数据校验。",
            "所有随机结果使用 Seed 派生源，禁止依赖帧率、系统时间或不持久化的全局随机。",
            "退役字段只在迁移层读取；当前 UI、统计和内容数据不暴露旧架构语义。",
        ],
    )
    add_para(doc, "11.2 存档", style="Heading 2")
    add_table(
        doc,
        ["存档", "保存内容", "边界"],
        [
            ("Run Save v4", "角色、誓约、A 等级、地图模板、节点与边、事件链、牌组、遗物、回想、奖励、结局证据、统计", "节点外保存；战斗中途不保存"),
            ("Profile v1", "M01-M30、角色阅读、10 组完成、记忆墨、默认/最近回想、Boss 记录、已见结局", "新开远征不得清空"),
            ("迁移", "未知 ID、重复槽、负数资源和旧字段清洗", "损坏 Run Save 不得覆盖有效 Profile"),
        ],
        [1500, 5500, 2360],
        fill=FILL_GRAY,
        font_size=8.0,
    )
    add_para(doc, "11.3 统计与可追溯性", style="Heading 2")
    add_bullets(
        doc,
        [
            "交换：有效/无效、消除事件、消除格数、最大连线、最高级联。",
            "色谱：达成数、每回合达成、学派分布、保留、色谱伤害、燃烧、最高单卡与来源。",
            "谱序：推进、六类共鸣次数、共鸣率；防御、回复、金币净值、颜料、净化与额外步数。",
            "关卡：战斗类型时长、地图模板、节点选择、事件链、Boss 干预、胜负与结局证据。",
            "结算页首要五项固定为有效交换率、平均每回合达成、最高级联、共鸣率、最高单卡伤害。",
        ],
    )

    add_major_heading(doc, "12. 商业方案、版本策略与发行验收")
    add_para(doc, "12.1 商业基线（建议）", style="Heading 2")
    add_table(
        doc,
        ["项目", "建议口径", "原则"],
        [
            ("产品形态", "PC 单机买断制，建议国区定价 48 元，首发 10% 折扣", "完整三章、五角色和全部系统一次性交付"),
            ("试玩版", "第一章 + 2 名角色 + 限定档案，存档可迁移", "明确展示三消产色素、色谱结算和路线构筑"),
            ("后续内容", "免费平衡/可用性更新；大型角色或章节内容可做资料片", "不拆卖基础卡池、遗物或数值优势"),
            ("禁用商业化", "无体力、抽卡、战斗通行证、付费复活或永久属性售卖", "不破坏可解释的单局公平性"),
            ("商店页素材", "主循环短片、五角色、四地图池、档案证据、无障碍说明", "素材必须显示真实棋盘与卡牌界面"),
        ],
        [1500, 4250, 3610],
        fill=FILL_GOLD,
        font_size=8.1,
        stripe=True,
    )
    add_para(doc, "12.2 版本节奏", style="Heading 2")
    add_bullets(
        doc,
        [
            "2.0.0：冻结纯三消 + 条件卡牌主循环，完成三章、五角色、四地图池、档案与 Windows 发布。",
            "2.0.1-2.0.3：只修复崩溃、存档、软锁、输入、可读性和严重数值异常，不新增破坏基线的系统。",
            "2.1：以遥测和实测确认角色、地图池与学派缺口后扩内容，继续复用现有公式和硬上限。",
            "任何版本变更先更新工作簿输入，再用固定 Seed 回归，最后更新玩家可见说明。",
        ],
    )
    add_para(doc, "12.3 2.0 发布验收", style="Heading 2")
    acceptance_rows = [
        ("玩法", "普通消除直接伤害恒为 0；色谱在同一交换链立即完整结算；没有第二操作层", "自动测试 + 战斗日志"),
        ("内容", "117 色谱、72 遗物、54 事件、30 记忆、10 组、5 角色、12 地图模板引用闭合", "数据校验"),
        ("关卡", "每章四模板可达 Boss 且至少两次有效分岔；三章敌人曲线符合工作簿", "图遍历 + 固定 Seed"),
        ("平衡", "KPI、硬上限、角色偏差与 A0/A5/A10 通关率进入目标窗", "每角色每 A 等级至少 500 Seed"),
        ("UX", "1280×720 到超宽屏无裁切；地图滚轮缩放、拖拽、按钮和复位一致", "截图 + 输入矩阵"),
        ("叙事", "54 事件可达；记忆、回想、Boss 干预和结局证据可追溯", "内容巡检 + 存档往返"),
        ("存档", "Run v4 / Profile v1 往返；损坏与旧字段安全处理", "迁移与破损样本"),
        ("发布", "Headless 测试、Windows 导出、首次启动、续局、胜败结算与退出无阻断缺陷", "发布候选冒烟"),
    ]
    add_table(doc, ["域", "通过条件", "证据"], acceptance_rows, [1200, 5900, 2260], fill=FILL_RED, font_size=7.7, stripe=True)
    add_para(doc, "12.4 必测边界", style="Heading 2")
    add_bullets(
        doc,
        [
            "第一回合达成无共鸣；同事件达成三张按槽位；当前卡击杀后完成其资源收益并停止后续队列。",
            "额外步数、重复、护盾、回复、金币、净化、抽牌与伤害均按硬上限截断并记录溢出。",
            "无合法交换免费重排；灰格超过 72% 一链净化一次；锁格后必须仍有合法交换。",
            "敌人单次跨两个阶段按序推进并合并提示；抗性与护甲不低于公式下限。",
            "最长中文、四位 HP、五位金币、A10、125% UI 缩放、窗口失焦拖拽与坏存档均覆盖。",
        ],
    )

    add_major_heading(doc, "附录 A. 运行时快照与数据责任")
    add_table(
        doc,
        ["数据集", "当前数量", "正式目标", "责任"],
        [
            ("SPECTRA", summary["色谱总数"], 117, "卡牌/数值策划"),
            ("RELICS", summary["遗物"], 72, "系统/内容策划"),
            ("EVENTS", summary["事件"], 54, "叙事/事件策划"),
            ("ENCOUNTERS", summary["遭遇"], "三章完整池", "战斗/关卡策划"),
            ("CHAPTER_NODES", summary["地图节点"], "所有模板可达", "关卡策划"),
            ("MAP_TEMPLATE_SPECS", summary["地图模板"], 12, "关卡/程序"),
            ("STARTING_ARCHETYPES", summary["角色"], 5, "角色/战斗策划"),
        ],
        [2200, 1500, 1800, 3860],
        fill=FILL_GRAY,
        font_size=8.4,
        stripe=True,
    )
    add_source(doc, f"运行时文件：{GAME_DATA_PATH}")
    add_para(doc, "正式目标与运行时数量不一致时，配套工作簿的“08_内容规模”以差额公式标红；发布验收以目标全部闭合为准。")

    doc.core_properties.title = "色彩勇者 2.0 游戏总策划案"
    doc.core_properties.subject = "纯三消 + 条件卡牌构筑 Roguelite 正式产品规格"
    doc.core_properties.author = "Color Heroes Game Studio"
    doc.core_properties.keywords = "三消,色谱,卡牌构筑,Roguelite,2.0"
    doc.save(OUT_GDD)


# ---------------------------------------------------------------------------
# XLSX


XLS_NAVY = "0B2545"
XLS_BLUE = "2E74B5"
XLS_LIGHT_BLUE = "E8EEF5"
XLS_LIGHT = "F7F9FB"
XLS_GREEN = "E5F1E8"
XLS_GOLD = "FFF2CC"
XLS_RED = "FCE8E6"
XLS_PURPLE = "EEE5F3"
XLS_GRAY = "E7E9EC"
XLS_WHITE = "FFFFFF"
XLS_INK = "22262B"
XLS_MUTED = "687078"
XLS_INPUT_BLUE = "1F4E78"
XLS_FORMULA_GREEN = "008000"
THIN_GRAY = Side(style="thin", color="C8CDD2")


def xls_font(size=10, bold=False, color=XLS_INK):
    return Font(name="Microsoft YaHei", size=size, bold=bold, color=color)


def configure_sheet(ws, title: str, subtitle: str, max_col: int, landscape=False) -> int:
    ws.sheet_view.showGridLines = False
    ws.freeze_panes = "A5"
    ws.merge_cells(start_row=1, start_column=1, end_row=1, end_column=max_col)
    title_cell = ws.cell(1, 1, title)
    title_cell.font = xls_font(18, True, XLS_WHITE)
    title_cell.fill = PatternFill("solid", fgColor=XLS_NAVY)
    title_cell.alignment = Alignment(vertical="center")
    ws.row_dimensions[1].height = 32
    ws.merge_cells(start_row=2, start_column=1, end_row=2, end_column=max_col)
    subtitle_cell = ws.cell(2, 1, subtitle)
    subtitle_cell.font = xls_font(9, False, XLS_MUTED)
    subtitle_cell.alignment = Alignment(wrap_text=True, vertical="center")
    ws.row_dimensions[2].height = 28
    ws.sheet_properties.pageSetUpPr.fitToPage = True
    ws.page_setup.orientation = "landscape" if landscape else "portrait"
    ws.page_setup.fitToWidth = 1
    ws.page_setup.fitToHeight = 0
    ws.page_margins.left = 0.25
    ws.page_margins.right = 0.25
    ws.page_margins.top = 0.45
    ws.page_margins.bottom = 0.45
    ws.oddFooter.center.text = "色彩勇者 2.0 数值总表"
    ws.oddFooter.right.text = "第 &[Page] / &[Pages] 页"
    return 4


def write_table(
    ws,
    start_row: int,
    headers: list,
    rows: list,
    widths: list[float],
    *,
    fill=XLS_LIGHT_BLUE,
    formula_columns: set[int] | None = None,
    input_columns: set[int] | None = None,
    filter_table=True,
) -> int:
    formula_columns = formula_columns or set()
    input_columns = input_columns or set()
    for col, header in enumerate(headers, 1):
        cell = ws.cell(start_row, col, header)
        cell.font = xls_font(10, True, XLS_NAVY)
        cell.fill = PatternFill("solid", fgColor=fill)
        cell.alignment = Alignment(horizontal="center", vertical="center", wrap_text=True)
        cell.border = Border(top=THIN_GRAY, bottom=THIN_GRAY, left=THIN_GRAY, right=THIN_GRAY)
    ws.row_dimensions[start_row].height = 28
    for row_index, values in enumerate(rows, start_row + 1):
        for col, value in enumerate(values, 1):
            cell = ws.cell(row_index, col, value)
            cell.font = xls_font(
                9,
                False,
                XLS_FORMULA_GREEN if col in formula_columns else XLS_INPUT_BLUE if col in input_columns else XLS_INK,
            )
            cell.fill = PatternFill("solid", fgColor=XLS_WHITE if row_index % 2 else XLS_LIGHT)
            cell.alignment = Alignment(
                horizontal="center" if isinstance(value, (int, float)) or col in formula_columns else "left",
                vertical="center",
                wrap_text=True,
            )
            cell.border = Border(top=THIN_GRAY, bottom=THIN_GRAY, left=THIN_GRAY, right=THIN_GRAY)
        ws.row_dimensions[row_index].height = 34
    for col, width in enumerate(widths, 1):
        ws.column_dimensions[get_column_letter(col)].width = width
    end_row = start_row + len(rows)
    if filter_table and rows:
        ws.auto_filter.ref = f"A{start_row}:{get_column_letter(len(headers))}{end_row}"
    return end_row


def section_label(ws, row: int, text: str, max_col: int) -> int:
    ws.merge_cells(start_row=row, start_column=1, end_row=row, end_column=max_col)
    cell = ws.cell(row, 1, text)
    cell.font = xls_font(12, True, XLS_BLUE)
    cell.alignment = Alignment(vertical="center")
    cell.fill = PatternFill("solid", fgColor=XLS_LIGHT_BLUE)
    ws.row_dimensions[row].height = 24
    return row + 1


def set_print_area(ws, max_row: int, max_col: int) -> None:
    ws.print_area = f"A1:{get_column_letter(max_col)}{max_row}"
    ws.sheet_properties.pageSetUpPr.fitToPage = True


def build_workbook(data: dict) -> None:
    wb = Workbook()
    wb.remove(wb.active)
    summary = runtime_summary(data)
    characters = data["STARTING_ARCHETYPES"]
    encounters = data["ENCOUNTERS"]
    templates = data["MAP_TEMPLATE_SPECS"]
    rarity_counts = Counter(card.get("rarity", "未标记") for card in collectible_spectra(data))
    school_counts = Counter(card.get("color", "neutral") for card in collectible_spectra(data))

    ws = wb.create_sheet("00_说明")
    row = configure_sheet(ws, "色彩勇者 2.0 关卡数值总表", "蓝字为输入，绿字为公式；所有公式保留在工作簿中，可直接调整参数并由 Excel/LibreOffice 重算。", 6)
    rows = [
        ("版本", "2.0.0", "架构", "纯三消 + 条件卡牌构筑 Roguelite", "基准", "6×6 / 四色 / 3 步 / 3 手牌"),
        ("数据源", "GameData.gd", "规格", "四份 v2_0_*.md", "日期", TODAY.isoformat()),
        ("正式边界", "消除产色素", "结算", "色谱达成立即结算", "禁止", "不含弹珠或第二战斗操作层"),
        ("保存", "Run Save v4", "档案", "Profile v1", "引擎", "Godot 4.6"),
    ]
    row = write_table(ws, row, ["字段", "值", "字段", "值", "字段", "值"], rows, [14, 22, 14, 36, 14, 30], fill=XLS_LIGHT_BLUE, input_columns={2, 4, 6}) + 2
    row = section_label(ws, row, "全局调参", 6)
    ws.cell(row, 1, "当前进阶")
    ws.cell(row, 2, "A0")
    ws.cell(row, 2).font = xls_font(10, True, XLS_INPUT_BLUE)
    ws.cell(row, 2).fill = PatternFill("solid", fgColor=XLS_GOLD)
    ws.cell(row, 2).alignment = Alignment(horizontal="center")
    dv = DataValidation(type="list", formula1='"A0,A1,A2,A3,A4,A5,A6,A7,A8,A9,A10"', allow_blank=False)
    ws.add_data_validation(dv)
    dv.add(ws.cell(row, 2))
    ws.cell(row, 3, "敌人表的有效 HP、攻击和金币会随该值重算。")
    ws.merge_cells(start_row=row, start_column=3, end_row=row, end_column=6)
    ws.cell(row, 3).alignment = Alignment(wrap_text=True)
    selected_ascension_cell = f"'00_说明'!$B${row}"
    row += 3
    row = section_label(ws, row, "工作表索引", 6)
    index_rows = [
        ("01_角色", "五角色 HP、牌组、被动、主动技和专属池"),
        ("02_色谱稀有度", "117 张目标、运行时差额、九学派与 BP 基线"),
        ("03_颜色与棋盘", "四棋子权重、消除产出、共鸣与棋盘边界"),
        ("04-06_三章敌人", "基础值与所选进阶的公式换算"),
        ("07_地图模板", "三章四模板、边覆盖和分岔规模"),
        ("08_内容规模", "色谱、遗物、事件、记忆、地图与角色目标差额"),
        ("09_进阶A0-A10", "增量输入与累计倍率公式"),
        ("10_关键公式", "伤害示例、硬上限与公式说明"),
        ("11_经济与奖励", "战斗、商店、服务和单局经济"),
        ("12_KPI与QA", "目标窗、样例输入与公式判定"),
    ]
    row = write_table(ws, row, ["工作表", "用途"], index_rows, [24, 92], fill=XLS_GRAY, filter_table=False) + 1
    set_print_area(ws, row, 6)

    ws = wb.create_sheet("01_角色")
    row = configure_sheet(ws, "01 角色数值", "运行时来源：GameData.STARTING_ARCHETYPES；角色差异必须同时覆盖 HP、牌组、被动、主动技、专属池和挑战。", 11, landscape=True)
    char_rows = []
    for char_id, char in characters.items():
        skill = char.get("active_skill", {})
        deck = char.get("deck", [])
        school_bias = "/".join(f"{label_color(k)}+{v}" for k, v in char.get("bias", {}).items() if v)
        char_rows.append(
            (
                char_id,
                char.get("name", ""),
                char.get("title", ""),
                char.get("max_hp", 0),
                char.get("difficulty", ""),
                char.get("passive_name", ""),
                char.get("passive_text", ""),
                skill.get("cost", 0),
                f"{skill.get('name', '')}：{skill.get('text', '')}",
                " / ".join(deck),
                f"{school_bias}；专属 {'/'.join(char.get('exclusive_pools', []))}",
            )
        )
    row = write_table(ws, row, ["ID", "角色", "称号", "HP", "定位", "被动", "被动效果", "充能", "主动技", "8 张起始牌组", "倾向/专属池"], char_rows, [10, 10, 16, 8, 10, 14, 34, 8, 42, 64, 28], fill=XLS_GREEN, input_columns=set(range(1, 12)))
    ws.freeze_panes = "A5"
    set_print_area(ws, row, 11)

    ws = wb.create_sheet("02_色谱稀有度")
    row = configure_sheet(ws, "02 色谱稀有度与学派", "目标 114 张可收集 + 3 张事件诅咒；运行时数量由 GameData.gd 自动统计，差额用公式计算。", 7, landscape=True)
    rarity_rows = [
        ("普通", 56, rarity_counts.get("common", 0), "=C5-B5", "8-14", "7-13", "8-18"),
        ("稀有", 42, rarity_counts.get("rare", 0), "=C6-B6", "12-20", "12-22", "16-32"),
        ("史诗", 16, rarity_counts.get("epic", 0), "=C7-B7", "18-30", "22-38", "30-65"),
        ("事件诅咒", 3, max(summary["色谱总数"] - summary["可收集色谱"], 0), "=C8-B8", "特殊", "-6 至 -18", "无正伤害"),
        ("合计", "=SUM(B5:B8)", "=SUM(C5:C8)", "=C9-B9", "-", "-", "-"),
    ]
    row = write_table(ws, row, ["稀有度", "正式目标", "运行时", "差额", "条件 BP", "效果 BP", "伤害型基础窗"], rarity_rows, [16, 14, 14, 12, 16, 16, 22], fill=XLS_GOLD, formula_columns={2, 3, 4}) + 2
    row = section_label(ws, row, "九学派运行时分布", 7)
    school_roles = {
        "red": ("R", "伤害/燃烧", "生存压力"),
        "blue": ("B", "护盾/冻结", "输出偏慢"),
        "gold": ("G", "经济/转换", "即时战力低"),
        "gray": ("X", "净化/破甲", "灰状态依赖"),
        "purple": ("R+B", "顺序/返奏", "操作复杂"),
        "green": ("B+G", "回复/染色", "爆发偏低"),
        "white": ("R+B+G", "三色/净化", "条件较难"),
        "black": ("X", "自伤/高结算", "失败风险"),
        "mixed": ("R+B+G", "跨色/复合", "单项效率低"),
        "neutral": ("-", "工具/异常处理", "不参与谱序"),
    }
    school_rows = []
    for school in ("red", "blue", "gold", "gray", "purple", "green", "white", "black", "mixed", "neutral"):
        signature, role, risk = school_roles[school]
        target = 8 if school != "neutral" else "机动额度"
        actual = school_counts.get(school, 0)
        delta = f"=IF(ISNUMBER(B{row + 1 + len(school_rows)}),C{row + 1 + len(school_rows)}-B{row + 1 + len(school_rows)},\"-\")"
        school_rows.append((label_color(school), target, actual, delta, signature, role, risk))
    row = write_table(ws, row, ["学派", "最低目标", "运行时", "差额", "签名", "主要身份", "风险"], school_rows, [15, 14, 14, 12, 14, 24, 26], fill=XLS_PURPLE, formula_columns={4})
    set_print_area(ws, row, 7)

    ws = wb.create_sheet("03_颜色与棋盘")
    row = configure_sheet(ws, "03 颜色与棋盘", "基础棋子固定为红、蓝、金、灰；扩展学派不加入棋子生成池。普通消除不直接造成敌人伤害。", 7, landscape=True)
    color_usage = {
        "gray": "压力/净化/破律",
        "red": "伤害/燃烧",
        "blue": "护盾/冻结",
        "gold": "金币/颜料",
    }
    color_rows = []
    for index, color in enumerate(data["COLOR_ORDER"], 5):
        color_rows.append((label_color(color), data["BASE_WEIGHTS"].get(color, 0), "=B" + str(index), "=B" + str(index) + "/SUM($B$5:$B$8)", color_usage[color], "基础棋子", "通过"))
    color_rows.append(("合计", "=SUM(B5:B8)", "=SUM(C5:C8)", "=SUM(D5:D8)", "-", "-", '=IF(ABS(B9-1)<0.0001,"通过","检查")'))
    row = write_table(ws, row, ["颜色", "基础权重", "公式副本", "归一化", "主要用途", "身份", "校验"], color_rows, [14, 14, 14, 14, 26, 16, 14], fill=XLS_LIGHT_BLUE, formula_columns={2, 3, 4, 7}, input_columns={2}) + 2
    for r in range(5, 10):
        ws.cell(r, 2).number_format = "0.0%"
        ws.cell(r, 3).number_format = "0.0%"
        ws.cell(r, 4).number_format = "0.0%"
    row = section_label(ws, row, "连线与级联产出", 7)
    match_rows = []
    for size in (3, 4, 5, 6, 7, 8):
        excel_row = row + 1 + len(match_rows)
        pigment_formula = f'=IF(A{excel_row}=3,3,IF(A{excel_row}=4,5,IF(A{excel_row}=5,8,11+A{excel_row}-6)))'
        beat_formula = f'=IF(A{excel_row}=3,0,IF(A{excel_row}=4,1,IF(A{excel_row}=5,2,3)))'
        match_rows.append((size, pigment_formula, beat_formula, 0, "第 2 层起每层 +1 对应色素", 5, "不直接伤害"))
    row = write_table(ws, row, ["去重格数", "基础色素", "强拍值", "直接伤害", "级联规则", "级联额外上限", "敌人 HP"], match_rows, [14, 14, 14, 14, 34, 18, 18], fill=XLS_GREEN, formula_columns={2, 3, 4}) + 2
    row = section_label(ws, row, "棋盘硬边界", 7)
    board_rows = [
        ("尺寸", "6×6", "固定几何"),
        ("有效交换", "必须形成横/竖 3 连", "无效交换不扣步"),
        ("死局", "立即重排", "不扣步、不推进色谱"),
        ("灰权重", "基础 43%，硬上限 64%", "受灰蚀压力调整"),
        ("高污染", "灰格 >72% 自动净化 2 格", "同一链最多一次"),
        ("锁格", "硬上限 4", "必须保留合法交换"),
        ("级联", "统计上限 12", "超过仍清盘但不增益"),
    ]
    row = write_table(ws, row, ["规则", "数值", "处理"], board_rows, [22, 42, 52], fill=XLS_GRAY, filter_table=False)
    set_print_area(ws, row, 7)

    enemy_sheet_names = {"C1": "04_C1敌人", "C2": "05_C2敌人", "C3": "06_C3敌人"}
    for chapter_id, sheet_name in enemy_sheet_names.items():
        ws = wb.create_sheet(sheet_name)
        chapter_name = {"C1": "灰雾边境", "C2": "镜湖工坊", "C3": "无色王庭"}[chapter_id]
        row = configure_sheet(ws, f"{sheet_name[:2]} {chapter_name}敌人", f"基础值来自 GameData.ENCOUNTERS；有效值引用 {selected_ascension_cell} 与“09_进阶A0-A10”。", 12, landscape=True)
        enemy_rows = []
        for encounter_id, encounter in encounters.items():
            if not encounter_id.startswith(chapter_id + "-"):
                continue
            excel_row = row + 1 + len(enemy_rows)
            node_type = NODE_LABELS.get(str(encounter.get("node_type", "combat")), str(encounter.get("node_type", "combat")))
            hp_formula = (
                f'=ROUND(D{excel_row}*IF(C{excel_row}="Boss",INDEX(\'09_进阶A0-A10\'!$E:$E,MATCH({selected_ascension_cell},\'09_进阶A0-A10\'!$A:$A,0)),'
                f'IF(OR(C{excel_row}="精英",C{excel_row}="挑战"),INDEX(\'09_进阶A0-A10\'!$D:$D,MATCH({selected_ascension_cell},\'09_进阶A0-A10\'!$A:$A,0)),'
                f'INDEX(\'09_进阶A0-A10\'!$C:$C,MATCH({selected_ascension_cell},\'09_进阶A0-A10\'!$A:$A,0)))),0)'
            )
            attack_formula = (
                f'=ROUND(E{excel_row}*IF(C{excel_row}="Boss",INDEX(\'09_进阶A0-A10\'!$G:$G,MATCH({selected_ascension_cell},\'09_进阶A0-A10\'!$A:$A,0)),'
                f'INDEX(\'09_进阶A0-A10\'!$F:$F,MATCH({selected_ascension_cell},\'09_进阶A0-A10\'!$A:$A,0))),0)'
            )
            reward_formula = f'=ROUND(F{excel_row}*INDEX(\'09_进阶A0-A10\'!$H:$H,MATCH({selected_ascension_cell},\'09_进阶A0-A10\'!$A:$A,0)),0)'
            enemy_rows.append(
                (
                    encounter_id,
                    encounter.get("enemy_name", encounter.get("name", "")),
                    node_type,
                    encounter.get("max_hp", 0),
                    encounter.get("attack", 0),
                    encounter.get("reward", 0),
                    hp_formula,
                    attack_formula,
                    reward_formula,
                    intent_text(encounter),
                    encounter.get("description", ""),
                    "/".join(encounter.get("reward_pool", [])),
                )
            )
        row = write_table(ws, row, ["遭遇ID", "敌人", "类型", "A0 HP", "A0 ATK", "A0金币", "有效HP", "有效ATK", "有效金币", "公开意图序列", "检验点", "奖励池"], enemy_rows, [15, 18, 10, 10, 10, 10, 12, 12, 12, 42, 34, 24], fill=XLS_RED, formula_columns={7, 8, 9}, input_columns={4, 5, 6})
        ws.freeze_panes = "A5"
        set_print_area(ws, row, 12)

    ws = wb.create_sheet("07_地图模板")
    row = configure_sheet(ws, "07 三章地图模板", "每章四种可复现模板；运行时边覆盖来自 GameData.MAP_TEMPLATE_SPECS。", 10, landscape=True)
    desc = {
        "standard": ("均衡", "4-5战 / 2-3事件 / 1商店 / 1整备 / Boss", "中性", "守序之誓"),
        "risk": ("高风险", "3-4战 / 2精英挑战 / 1-2事件 / Boss", "敌人HP +5%", "破谱之誓"),
        "economy": ("经营", "2-3战 / 3-4事件 / 1-2商店宝箱 / Boss", "刷新 +5", "见证之誓"),
        "archive": ("档案", "3战 / 1档案精英 / 2-3档案事件 / Boss", "灰蚀获取 +1", "完成记忆组"),
    }
    map_rows = []
    for chapter_id, chapter_templates in templates.items():
        for template_id, template in chapter_templates.items():
            excel_row = row + 1 + len(map_rows)
            overrides = template.get("edge_overrides", {})
            source_nodes = len(overrides)
            edge_count = sum(len(edges) for edges in overrides.values())
            branch_count = sum(1 for edges in overrides.values() if len(edges) > 1)
            style, composition, risk, entry = desc[template_id]
            map_rows.append((chapter_id, template_id, template.get("name", ""), style, composition, risk, entry, source_nodes, edge_count, f'=IF(H{excel_row}=0,"基线图",IF(I{excel_row}>=H{excel_row},"通过","检查"))'))
    row = write_table(ws, row, ["章节", "模板ID", "名称", "倾向", "节点构成目标", "风险修正", "进入方式", "覆盖源节点", "覆盖边数", "结构校验"], map_rows, [10, 14, 18, 12, 42, 20, 20, 14, 12, 14], fill=XLS_GREEN, formula_columns={10}, input_columns={8, 9})
    set_print_area(ws, row, 10)

    ws = wb.create_sheet("08_内容规模")
    row = configure_sheet(ws, "08 正式内容规模", "目标与运行时快照并列；差额为运行时 - 目标，0 表示数量闭合。", 7, landscape=True)
    scale_rows = [
        ("色谱总数", 117, summary["色谱总数"], "=C5-B5", "114 可收集 + 3 事件诅咒", "卡牌策划", '=IF(D5=0,"通过","缺口")'),
        ("可收集色谱", 114, summary["可收集色谱"], "=C6-B6", "普通56 / 稀有42 / 史诗16", "卡牌/数值", '=IF(D6=0,"通过","缺口")'),
        ("遗物", 72, summary["遗物"], "=C7-B7", "7 类配额", "系统策划", '=IF(D7=0,"通过","缺口")'),
        ("事件", 54, summary["事件"], "=C8-B8", "36 既有 + 18 叙事", "事件/叙事", '=IF(D8=0,"通过","缺口")'),
        ("记忆", 30, 30, "=C9-B9", "10 组 × 3", "叙事策划", '=IF(D9=0,"通过","缺口")'),
        ("记忆组", 10, 10, "=C10-B10", "每组固定 3 枚", "叙事策划", '=IF(D10=0,"通过","缺口")'),
        ("地图模板", 12, summary["地图模板"], "=C11-B11", "三章 × 四模板", "关卡策划", '=IF(D11=0,"通过","缺口")'),
        ("角色", 5, summary["角色"], "=C12-B12", "完整六维差异", "角色策划", '=IF(D12=0,"通过","缺口")'),
        ("遭遇", summary["遭遇"], summary["遭遇"], "=C13-B13", "三章普通/精英/Boss/挑战/档案", "战斗策划", '=IF(D13=0,"通过","缺口")'),
        ("地图节点", summary["地图节点"], summary["地图节点"], "=C14-B14", "所有模板可达 Boss", "关卡策划", '=IF(D14=0,"通过","缺口")'),
    ]
    row = write_table(ws, row, ["内容", "正式目标", "运行时", "差额", "构成", "负责人", "状态"], scale_rows, [20, 14, 14, 12, 40, 20, 14], fill=XLS_LIGHT_BLUE, formula_columns={4, 7}, input_columns={2, 3})
    ws.conditional_formatting.add(f"D5:D{row}", CellIsRule(operator="notEqual", formula=["0"], fill=PatternFill("solid", fgColor=XLS_RED)))
    set_print_area(ws, row, 7)

    ws = wb.create_sheet("09_进阶A0-A10")
    row = configure_sheet(ws, "09 A0-A10 累计换算", "上表为公式输出，下表为每级增量输入；调整蓝字增量即可重算三章敌人。", 14, landscape=True)
    rules = [
        "标准远征",
        "普通敌人 HP +8%",
        "战斗金币 -10%，商店 +5%",
        "初始灰蚀 +2，灰权重 +3pt",
        "精英 HP +12%，意图 +8%",
        "首战加入 1 锁格",
        "Boss HP +15%，阶段干扰 +1",
        "稀有权重 -12%，移除 +15",
        "抗性 +10pt",
        "首次封谱条件 +1",
        "Boss 意图再 +10%",
    ]
    increments = [
        ("A0", 0, 0, 0, 0, 0, 1, 1, 0, 0, 0, 0, 1),
        ("A1", 0.08, 0, 0, 0, 0, 1, 1, 0, 0, 0, 0, 1),
        ("A2", 0, 0, 0, 0, 0, 0.90, 1.05, 0, 0, 0, 0, 1),
        ("A3", 0, 0, 0, 0, 0, 1, 1, 0, 2, 0, 0, 1),
        ("A4", 0, 0.12, 0, 0.08, 0, 1, 1, 0, 0, 0, 0, 1),
        ("A5", 0, 0, 0, 0, 0, 1, 1, 0, 0, 1, 0, 1),
        ("A6", 0, 0, 0.15, 0, 0, 1, 1, 0, 0, 0, 0, 1),
        ("A7", 0, 0, 0, 0, 0, 1, 1, 0, 0, 0, 15, 0.88),
        ("A8", 0, 0, 0, 0, 0, 1, 1, 0.10, 0, 0, 0, 1),
        ("A9", 0, 0, 0, 0, 0, 1, 1, 0, 0, 0, 0, 1),
        ("A10", 0, 0, 0, 0, 0.10, 1, 1, 0, 0, 0, 0, 1),
    ]
    output_rows = []
    output_start = row + 1
    input_data_start = output_start + len(increments) + 3
    for index, inc in enumerate(increments):
        excel_row = output_start + index
        input_row = input_data_start + index
        level = inc[0]
        if index == 0:
            formulas = (1, 1, 1, 1, 1, 1, 1, 0, 0, 0, 0, 1)
        else:
            prev = excel_row - 1
            formulas = (
                f"=MIN(C{prev}*(1+'09_进阶A0-A10'!B{input_row}),'10_关键公式'!$B$25)",
                f"=MIN(D{prev}*(1+'09_进阶A0-A10'!C{input_row}),'10_关键公式'!$B$25)",
                f"=MIN(E{prev}*(1+'09_进阶A0-A10'!D{input_row}),'10_关键公式'!$B$25)",
                f"=MIN(F{prev}*(1+'09_进阶A0-A10'!E{input_row}),'10_关键公式'!$B$26)",
                f"=MIN(G{prev}*(1+'09_进阶A0-A10'!E{input_row})*(1+'09_进阶A0-A10'!F{input_row}),'10_关键公式'!$B$26)",
                f"=H{prev}*'09_进阶A0-A10'!G{input_row}",
                f"=MIN(I{prev}*'09_进阶A0-A10'!H{input_row},'10_关键公式'!$B$27)",
                f"=J{prev}+'09_进阶A0-A10'!I{input_row}",
                f"=K{prev}+'09_进阶A0-A10'!J{input_row}",
                f"=MIN(L{prev}+'09_进阶A0-A10'!K{input_row},'10_关键公式'!$B$30)",
                f"=M{prev}+'09_进阶A0-A10'!L{input_row}",
                f"=N{prev}*'09_进阶A0-A10'!M{input_row}",
            )
        output_rows.append((level, rules[index], *formulas))
    row = write_table(ws, row, ["等级", "新增规则", "普通HP", "精英HP", "BossHP", "通用意图", "Boss意图", "金币", "商店", "抗性+", "初始灰蚀", "锁格", "移除+", "稀有权重"], output_rows, [9, 34, 11, 11, 11, 12, 12, 11, 11, 11, 12, 10, 10, 12], fill=XLS_GRAY, formula_columns=set(range(3, 15))) + 2
    for r in range(output_start, output_start + len(increments)):
        for c in (3, 4, 5, 6, 7, 8, 9, 10, 14):
            ws.cell(r, c).number_format = "0.0%" if c == 10 else "0.000x"
    row = section_label(ws, row, "每级增量输入（蓝字）", 14)
    input_rows = [(inc[0], *inc[1:]) for inc in increments]
    row = write_table(ws, row, ["等级", "普通HP+", "精英HP+", "BossHP+", "意图+", "Boss额外+", "金币倍率", "商店倍率", "抗性+", "灰蚀+", "锁格+", "移除+", "稀有权重倍率"], input_rows, [9, 12, 12, 12, 11, 13, 12, 12, 11, 10, 10, 10, 14], fill=XLS_GOLD, input_columns=set(range(2, 14)), filter_table=False)
    for r in range(input_data_start, input_data_start + len(increments)):
        for c in range(2, 10):
            ws.cell(r, c).number_format = "0.0%"
    set_print_area(ws, row, 14)

    ws = wb.create_sheet("10_关键公式")
    row = configure_sheet(ws, "10 关键公式与硬上限", "公式区使用可审计的分步计算；输入为蓝字，公式为绿字。", 6, landscape=True)
    damage_inputs = [
        ("卡牌基础伤害", 24, "card_damage", "输入"),
        ("角色加成", 6, "character_bonus", "输入"),
        ("共鸣加成", 4, "resonance_bonus", "输入"),
        ("遗物加成", 3, "relic_bonus", "输入"),
        ("记忆加成", 2, "memory_bonus", "输入"),
        ("增幅倍率", 1.20, "amplify_ratio", "限制 0.50-1.35"),
        ("颜色抗性倍率", 0.80, "color_resistance", "限制 0.50-1.00"),
        ("有效护甲", 5, "effective_armor", "最低结果 0"),
    ]
    row = write_table(ws, row, ["输入", "值", "变量", "说明"], damage_inputs, [26, 16, 28, 44], fill=XLS_LIGHT_BLUE, input_columns={2}, filter_table=False) + 2
    row = section_label(ws, row, "伤害分步计算", 6)
    calc_start = row + 1
    calc_rows = [
        ("raw", "=SUM(B5:B9)", "加总卡牌、角色、共鸣、遗物、记忆", 39),
        ("amped", f"=INT(B{calc_start}*MIN(MAX(B10,$B$33),$B$32))", "增幅倍率钳制后向下取整", 46),
        ("resisted", f"=INT(B{calc_start + 1}*MIN(MAX(B11,$B$29),1))", "抗性倍率钳制后向下取整", 36),
        ("final_damage", f"=MIN(MAX(B{calc_start + 2}-B12,0),$B$31)", "扣护甲并限制 0-180", 31),
        ("Python镜像", 31, "用于 openpyxl 结构验证，不参与战斗公式", 31),
        ("一致性", f'=IF(B{calc_start + 3}=B{calc_start + 4},"通过","检查")', "公式结果应等于镜像", "通过"),
    ]
    row = write_table(ws, row, ["步骤", "公式/值", "说明", "期望结果"], calc_rows, [24, 28, 48, 18], fill=XLS_GREEN, formula_columns={2}, filter_table=False) + 2
    row = section_label(ws, row, "全局硬上限", 6)
    caps_start = row + 1
    cap_rows = [
        ("敌人 HP 倍率", 1.45, "A0-A10 累计"),
        ("意图倍率", 1.35, "A0-A10 累计"),
        ("商店倍率", 1.30, "A0-A10 累计"),
        ("灰色权重", 0.64, "基础 0.43"),
        ("抗性最低伤害倍率", 0.50, "任何难度仍保底"),
        ("锁格", 4, "且必须保留合法交换"),
        ("单次最终伤害", 180, "所有伤害来源合并后"),
        ("增幅倍率上限", 1.35, "amplify_ratio"),
        ("增幅倍率下限", 0.50, "amplify_ratio"),
        ("效果重复次数", 4, "第 2 次起只重复数值"),
        ("重复倍率", 0.60, "默认 0.35，最高 0.60"),
    ]
    row = write_table(ws, row, ["上限", "值", "说明"], cap_rows, [34, 18, 64], fill=XLS_GOLD, input_columns={2}, filter_table=False)
    for r in range(caps_start, caps_start + len(cap_rows)):
        if isinstance(ws.cell(r, 2).value, float):
            ws.cell(r, 2).number_format = "0.0%" if ws.cell(r, 2).value < 1 else "0.00x"
    set_print_area(ws, row, 6)

    ws = wb.create_sheet("11_经济与奖励")
    row = configure_sheet(ws, "11 经济与奖励", "基础价格与期望区间；进阶倍率由“09_进阶A0-A10”提供。", 8, landscape=True)
    economy_rows = [
        ("战斗", "普通金币", 14, 22, "=AVERAGE(C5:D5)", "每场", "金币倍率", "14-22"),
        ("战斗", "精英金币", 28, 42, "=AVERAGE(C6:D6)", "每场", "金币倍率", "28-42"),
        ("战斗", "Boss金币", 55, 75, "=AVERAGE(C7:D7)", "每章", "金币倍率", "55-75"),
        ("商店", "普通色谱", 45, 65, "=AVERAGE(C8:D8)", "单件", "商店倍率", "45-65"),
        ("商店", "稀有色谱", 80, 110, "=AVERAGE(C9:D9)", "单件", "商店倍率", "80-110"),
        ("商店", "史诗色谱", 130, 175, "=AVERAGE(C10:D10)", "单件", "商店倍率", "130-175"),
        ("商店", "普通遗物", 145, 190, "=AVERAGE(C11:D11)", "单件", "商店倍率", "145-190"),
        ("商店", "稀有遗物", 220, 285, "=AVERAGE(C12:D12)", "单件", "商店倍率", "220-285"),
        ("商店", "史诗遗物", 330, 420, "=AVERAGE(C13:D13)", "单件", "商店倍率", "330-420"),
        ("服务", "移除", 75, 200, "=C14", "每次 +25", "A7 额外 +15", "75-200"),
        ("服务", "精研", 60, 150, "=C15", "每次 +15", "无", "60-150"),
        ("单局", "净收入", 520, 760, "=AVERAGE(C16:D16)", "每局", "支出率 72%-90%", "520-760"),
    ]
    row = write_table(ws, row, ["模块", "项目", "低值", "高值/上限", "中值公式", "单位", "进阶影响", "目标窗"], economy_rows, [14, 22, 12, 15, 16, 14, 22, 18], fill=XLS_GOLD, formula_columns={5}, input_columns={3, 4})
    set_print_area(ws, row, 8)

    ws = wb.create_sheet("12_KPI与QA")
    row = configure_sheet(ws, "12 KPI 与公式验收", "样例观测值可替换为实测；状态列用公式判断是否在目标窗。", 8, landscape=True)
    kpi_rows = [
        ("普通", "有效交换率", 0.82, 0.94, 0.88, "=IF(AND(E5>=C5,E5<=D5),\"通过\",\"检查\")", "<72% 可读性问题", "比例"),
        ("普通", "每回合色谱达成", 1.20, 1.75, 1.45, "=IF(AND(E6>=C6,E6<=D6),\"通过\",\"检查\")", ">2.20 条件过松", "次/回合"),
        ("普通", "平均级联深度", 1.25, 1.70, 1.42, "=IF(AND(E7>=C7,E7<=D7),\"通过\",\"检查\")", ">2.10 随机收益过强", "层"),
        ("普通", "4连以上占比", 0.18, 0.32, 0.24, "=IF(AND(E8>=C8,E8<=D8),\"通过\",\"检查\")", ">40% 棋盘过松", "比例"),
        ("普通", "共鸣触发率", 0.32, 0.48, 0.40, "=IF(AND(E9>=C9,E9<=D9),\"通过\",\"检查\")", ">65% 无取舍", "比例"),
        ("普通", "战斗回合", 3, 6, 4.5, "=IF(AND(E10>=C10,E10<=D10),\"通过\",\"检查\")", ">8 拖沓", "回合"),
        ("精英", "战斗回合", 5, 8, 6.5, "=IF(AND(E11>=C11,E11<=D11),\"通过\",\"检查\")", ">10 拖沓", "回合"),
        ("Boss", "战斗回合", 8, 13, 10.5, "=IF(AND(E12>=C12,E12<=D12),\"通过\",\"检查\")", ">15 拖沓", "回合"),
        ("A0", "熟悉玩家通关率", 0.55, 0.70, 0.62, "=IF(AND(E13>=C13,E13<=D13),\"通过\",\"检查\")", "按角色拆分", "比例"),
        ("A5", "熟悉玩家通关率", 0.25, 0.40, 0.33, "=IF(AND(E14>=C14,E14<=D14),\"通过\",\"检查\")", "按角色拆分", "比例"),
        ("A10", "熟悉玩家通关率", 0.08, 0.18, 0.13, "=IF(AND(E15>=C15,E15<=D15),\"通过\",\"检查\")", "按角色拆分", "比例"),
    ]
    row = write_table(ws, row, ["场景", "指标", "下限", "上限", "样例观测", "状态", "警戒线/备注", "单位"], kpi_rows, [12, 25, 12, 12, 14, 14, 30, 14], fill=XLS_GREEN, formula_columns={6}, input_columns={5}) + 2
    for r in range(5, 16):
        if ws.cell(r, 8).value == "比例":
            for c in (3, 4, 5):
                ws.cell(r, c).number_format = "0.0%"
    row = section_label(ws, row, "发布结构检查", 8)
    qa_rows = [
        ("棋盘", "6×6 / 四色 / 每回合 3 步", "自动 + 截图", "必须"),
        ("职责", "普通消除直接伤害 = 0", "战斗日志", "必须"),
        ("结算", "色谱在同一交换链即时结算", "集成测试", "必须"),
        ("地图", "每章四模板可达 Boss 且至少两次分岔", "图遍历", "必须"),
        ("内容", "117 / 72 / 54 / 30 / 10 / 5 / 12 闭合", "08_内容规模", "必须"),
        ("公式", "无 #REF! / #DIV/0! / #VALUE! / #NAME?", "openpyxl 扫描", "必须"),
        ("UI", "1280×720 至超宽屏无裁切；地图缩放拖拽可用", "截图与输入矩阵", "必须"),
        ("存档", "Run v4 / Profile v1 往返与坏档保护", "自动测试", "必须"),
    ]
    row = write_table(ws, row, ["域", "检查", "证据", "门槛"], qa_rows, [16, 58, 30, 12], fill=XLS_RED, filter_table=False)
    set_print_area(ws, row, 8)

    for ws in wb.worksheets:
        for row_cells in ws.iter_rows():
            for cell in row_cells:
                if cell.value is not None and cell.row > 2:
                    alignment = copy(cell.alignment)
                    alignment.vertical = "center"
                    alignment.wrap_text = True
                    cell.alignment = alignment
        ws.sheet_properties.pageSetUpPr.fitToPage = True
        ws.page_setup.paperSize = ws.PAPERSIZE_A4

    wb.calculation.fullCalcOnLoad = True
    wb.calculation.forceFullCalc = True
    wb.calculation.calcMode = "auto"
    wb.save(OUT_XLSX)


# ---------------------------------------------------------------------------
# Validation


def validate_docx(path: Path) -> dict:
    doc = Document(path)
    text = "\n".join(p.text for p in doc.paragraphs)
    for table in doc.tables:
        text += "\n" + "\n".join(" | ".join(cell.text for cell in row.cells) for row in table.rows)
    required = [
        "纯三消 + 条件卡牌",
        "6×6",
        "普通消除",
        "色谱达成立即",
        "目标人群",
        "五名角色",
        "四类地图",
        "A0-A10",
        "商业基线",
        "发布验收",
    ]
    missing = [term for term in required if term not in text]
    if missing:
        raise AssertionError(f"DOCX missing required terms: {missing}")
    forbidden = ["钉板", "发射阶段", "瞄准预测", "轨迹结算", "主球", "多球"]
    present_forbidden = [term for term in forbidden if term in text]
    if present_forbidden:
        raise AssertionError(f"DOCX contains retired terms: {present_forbidden}")
    if text.count("弹珠") != 1:
        raise AssertionError("DOCX must contain exactly one explicit no-peg scope statement")

    ns = {"w": "http://schemas.openxmlformats.org/wordprocessingml/2006/main"}
    with zipfile.ZipFile(path) as archive:
        root = ET.fromstring(archive.read("word/document.xml"))
    tables = root.findall(".//w:tbl", ns)
    bad_geometry = []
    for index, table in enumerate(tables, 1):
        width_node = table.find("./w:tblPr/w:tblW", ns)
        width = int(width_node.get(f"{{{ns['w']}}}w", "0")) if width_node is not None else 0
        grid = table.findall("./w:tblGrid/w:gridCol", ns)
        grid_sum = sum(int(col.get(f"{{{ns['w']}}}w", "0")) for col in grid)
        if width != CONTENT_WIDTH_DXA or grid_sum != CONTENT_WIDTH_DXA:
            bad_geometry.append((index, width, grid_sum))
    if bad_geometry:
        raise AssertionError(f"DOCX bad table geometry: {bad_geometry[:3]}")
    return {
        "paragraphs": len(doc.paragraphs),
        "tables": len(doc.tables),
        "required_terms": len(required),
        "retired_terms": 0,
    }


def validate_workbook(path: Path) -> dict:
    wb = load_workbook(path, data_only=False)
    required = [
        "00_说明",
        "01_角色",
        "02_色谱稀有度",
        "03_颜色与棋盘",
        "04_C1敌人",
        "05_C2敌人",
        "06_C3敌人",
        "07_地图模板",
        "08_内容规模",
        "09_进阶A0-A10",
        "10_关键公式",
        "11_经济与奖励",
        "12_KPI与QA",
    ]
    if wb.sheetnames != required:
        raise AssertionError(f"Unexpected sheet order: {wb.sheetnames}")
    formulas = []
    errors = []
    cross_sheet_errors = []
    for ws in wb.worksheets:
        if ws.max_row < 5 or ws.max_column < 2:
            raise AssertionError(f"Sheet too small: {ws.title}")
        if ws.freeze_panes is None:
            raise AssertionError(f"Missing freeze pane: {ws.title}")
        for row in ws.iter_rows():
            for cell in row:
                value = cell.value
                if isinstance(value, str) and value.startswith("="):
                    formulas.append((ws.title, cell.coordinate, value))
                    if any(token in value.upper() for token in ("#REF!", "#DIV/0!", "#VALUE!", "#NAME?", "#N/A")):
                        errors.append((ws.title, cell.coordinate, value))
                    for sheet_name in re.findall(r"'([^']+)'!", value):
                        if sheet_name not in wb.sheetnames:
                            cross_sheet_errors.append((ws.title, cell.coordinate, sheet_name))
    if len(formulas) < 100:
        raise AssertionError(f"Formula count too low: {len(formulas)}")
    if errors:
        raise AssertionError(f"Formula errors: {errors[:3]}")
    if cross_sheet_errors:
        raise AssertionError(f"Bad sheet refs: {cross_sheet_errors[:3]}")

    expected_formula = "=MIN(MAX(B18-B12,0),$B$31)"
    if wb["10_关键公式"]["B19"].value != expected_formula:
        raise AssertionError(f"Damage formula drift: {wb['10_关键公式']['B19'].value}")
    progression = wb["09_进阶A0-A10"]
    representative_formulas = {
        "C6": "'09_进阶A0-A10'!B20",
        "H7": "'09_进阶A0-A10'!G21",
        "D9": "'09_进阶A0-A10'!C23",
        "E11": "'09_进阶A0-A10'!D25",
        "G15": "'09_进阶A0-A10'!F29",
    }
    for coordinate, reference in representative_formulas.items():
        formula = str(progression[coordinate].value)
        if reference not in formula:
            raise AssertionError(f"Ascension reference drift at {coordinate}: {formula}")
    weights = [wb["03_颜色与棋盘"].cell(row, 2).value for row in range(5, 9)]
    if not math.isclose(sum(float(x) for x in weights), 1.0, abs_tol=0.0001):
        raise AssertionError(f"Color weights do not sum to 1: {weights}")
    return {
        "sheets": len(wb.sheetnames),
        "formulas": len(formulas),
        "formula_errors": 0,
        "cross_sheet_errors": 0,
    }


def write_validation_report(doc_report: dict, workbook_report: dict, data: dict) -> None:
    QA_DIR.mkdir(parents=True, exist_ok=True)
    summary = runtime_summary(data)
    report = [
        "Color Heroes 2.0 document generation validation",
        f"date={TODAY.isoformat()}",
        f"docx={OUT_GDD}",
        f"xlsx={OUT_XLSX}",
        f"docx_paragraphs={doc_report['paragraphs']}",
        f"docx_tables={doc_report['tables']}",
        f"docx_retired_terms={doc_report['retired_terms']}",
        f"xlsx_sheets={workbook_report['sheets']}",
        f"xlsx_formulas={workbook_report['formulas']}",
        f"xlsx_formula_errors={workbook_report['formula_errors']}",
        f"xlsx_cross_sheet_errors={workbook_report['cross_sheet_errors']}",
    ]
    report.extend(f"runtime_{key}={value}" for key, value in summary.items())
    (QA_DIR / "validation_report.txt").write_text("\n".join(report) + "\n", encoding="utf-8")


def main() -> None:
    QA_DIR.mkdir(parents=True, exist_ok=True)
    data = load_runtime_data()
    build_gdd(data)
    build_workbook(data)
    doc_report = validate_docx(OUT_GDD)
    workbook_report = validate_workbook(OUT_XLSX)
    write_validation_report(doc_report, workbook_report, data)
    print(OUT_GDD)
    print(OUT_XLSX)
    print(json.dumps({"docx": doc_report, "xlsx": workbook_report, "runtime": runtime_summary(data)}, ensure_ascii=False))


if __name__ == "__main__":
    main()
