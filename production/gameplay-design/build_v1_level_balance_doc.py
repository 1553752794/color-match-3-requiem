from __future__ import annotations

from datetime import date
from pathlib import Path

from docx import Document
from docx.enum.table import WD_CELL_VERTICAL_ALIGNMENT, WD_TABLE_ALIGNMENT
from docx.enum.text import WD_ALIGN_PARAGRAPH
from docx.oxml import OxmlElement
from docx.oxml.ns import qn
from docx.shared import Inches, Pt, RGBColor


OUT_DIR = Path(__file__).resolve().parent
OUT_DOCX = OUT_DIR / "色彩勇者_三章关卡数值总表.docx"

TITLE = "《色彩勇者：三消镇魂曲》三章关卡数值总表"
SUBTITLE = "V1.0 Level, Encounter, Reward & Economy Balance Master"
TODAY = date(2026, 7, 26)

# compact_reference_guide preset tokens, with a small game-design accent palette.
BLUE = RGBColor(0x2E, 0x74, 0xB5)
DARK_BLUE = RGBColor(0x1F, 0x4D, 0x78)
NAVY = RGBColor(0x0B, 0x25, 0x45)
INK = RGBColor(0x22, 0x22, 0x22)
MUTED = RGBColor(0x66, 0x66, 0x66)
WHITE = RGBColor(0xFF, 0xFF, 0xFF)

HEADER_FILL = "E8EEF5"
LIGHT_FILL = "F4F6F9"
GRAY_FILL = "F2F4F7"
GREEN_FILL = "E2F0D9"
GOLD_FILL = "FFF2CC"
RED_FILL = "FCE4D6"
BLUE_FILL = "DDEBF7"
PURPLE_FILL = "EADCF8"


def set_run_font(run, size=None, color=None, bold=None, italic=None, name="Calibri") -> None:
    run.font.name = name
    run._element.rPr.rFonts.set(qn("w:ascii"), name)
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
    style._element.rPr.rFonts.set(qn("w:ascii"), name)
    style._element.rPr.rFonts.set(qn("w:hAnsi"), name)
    style._element.rPr.rFonts.set(qn("w:eastAsia"), "Microsoft YaHei")
    style.font.size = Pt(size)
    style.font.color.rgb = color
    if bold is not None:
        style.font.bold = bold


def configure_document(doc: Document) -> None:
    section = doc.sections[0]
    section.page_width = Inches(8.5)
    section.page_height = Inches(11)
    section.top_margin = Inches(1)
    section.bottom_margin = Inches(1)
    section.left_margin = Inches(1)
    section.right_margin = Inches(1)
    section.header_distance = Inches(0.492)
    section.footer_distance = Inches(0.492)

    normal = doc.styles["Normal"]
    set_style_font(normal, 11)
    normal.paragraph_format.space_before = Pt(0)
    normal.paragraph_format.space_after = Pt(6)
    normal.paragraph_format.line_spacing = 1.25

    h1 = doc.styles["Heading 1"]
    set_style_font(h1, 16, BLUE, True)
    h1.paragraph_format.space_before = Pt(18)
    h1.paragraph_format.space_after = Pt(10)
    h1.paragraph_format.line_spacing = 1.25
    h1.paragraph_format.keep_with_next = True

    h2 = doc.styles["Heading 2"]
    set_style_font(h2, 13, BLUE, True)
    h2.paragraph_format.space_before = Pt(14)
    h2.paragraph_format.space_after = Pt(7)
    h2.paragraph_format.line_spacing = 1.25
    h2.paragraph_format.keep_with_next = True

    h3 = doc.styles["Heading 3"]
    set_style_font(h3, 12, DARK_BLUE, True)
    h3.paragraph_format.space_before = Pt(10)
    h3.paragraph_format.space_after = Pt(5)
    h3.paragraph_format.line_spacing = 1.25
    h3.paragraph_format.keep_with_next = True

    for style_name in ("List Bullet", "List Number"):
        style = doc.styles[style_name]
        set_style_font(style, 11)
        style.paragraph_format.space_after = Pt(4)
        style.paragraph_format.line_spacing = 1.25
        style.paragraph_format.left_indent = Inches(0.375)
        style.paragraph_format.first_line_indent = Inches(-0.188)

    header = section.header.paragraphs[0]
    header.text = ""
    header.paragraph_format.space_after = Pt(0)
    run = header.add_run("色彩勇者：三消镇魂曲 | V1.0 三章关卡数值总表")
    set_run_font(run, 9, MUTED)

    footer = section.footer.paragraphs[0]
    footer.text = ""
    footer.alignment = WD_ALIGN_PARAGRAPH.CENTER
    run = footer.add_run("内部关卡 / 数值文档 | 2026-07-26")
    set_run_font(run, 9, MUTED)


def shade_cell(cell, fill: str) -> None:
    tc_pr = cell._tc.get_or_add_tcPr()
    shd = tc_pr.find(qn("w:shd"))
    if shd is None:
        shd = OxmlElement("w:shd")
        tc_pr.append(shd)
    shd.set(qn("w:fill"), fill)


def set_cell_margins(cell, top=80, start=120, bottom=80, end=120) -> None:
    tc_pr = cell._tc.get_or_add_tcPr()
    tc_mar = tc_pr.first_child_found_in("w:tcMar")
    if tc_mar is None:
        tc_mar = OxmlElement("w:tcMar")
        tc_pr.append(tc_mar)
    for name, value in (("top", top), ("start", start), ("bottom", bottom), ("end", end)):
        node = tc_mar.find(qn(f"w:{name}"))
        if node is None:
            node = OxmlElement(f"w:{name}")
            tc_mar.append(node)
        node.set(qn("w:w"), str(value))
        node.set(qn("w:type"), "dxa")


def set_cell_text(cell, text, bold=False, color=INK, size=8.2, align=None) -> None:
    cell.text = ""
    p = cell.paragraphs[0]
    p.paragraph_format.space_before = Pt(0)
    p.paragraph_format.space_after = Pt(0)
    p.paragraph_format.line_spacing = 1.12
    if align is not None:
        p.alignment = align
    run = p.add_run(str(text))
    set_run_font(run, size, color, bold)
    cell.vertical_alignment = WD_CELL_VERTICAL_ALIGNMENT.CENTER
    set_cell_margins(cell)


def set_table_geometry(table, widths_in, indent_dxa=120) -> None:
    table.alignment = WD_TABLE_ALIGNMENT.LEFT
    table.autofit = False
    tbl = table._tbl
    tbl_pr = tbl.tblPr

    total_dxa = int(round(sum(widths_in) * 1440))
    tbl_w = tbl_pr.find(qn("w:tblW"))
    if tbl_w is None:
        tbl_w = OxmlElement("w:tblW")
        tbl_pr.append(tbl_w)
    tbl_w.set(qn("w:w"), str(total_dxa))
    tbl_w.set(qn("w:type"), "dxa")

    tbl_ind = tbl_pr.find(qn("w:tblInd"))
    if tbl_ind is None:
        tbl_ind = OxmlElement("w:tblInd")
        tbl_pr.append(tbl_ind)
    tbl_ind.set(qn("w:w"), str(indent_dxa))
    tbl_ind.set(qn("w:type"), "dxa")

    tbl_layout = tbl_pr.find(qn("w:tblLayout"))
    if tbl_layout is None:
        tbl_layout = OxmlElement("w:tblLayout")
        tbl_pr.append(tbl_layout)
    tbl_layout.set(qn("w:type"), "fixed")

    grid = tbl.find(qn("w:tblGrid"))
    if grid is None:
        grid = OxmlElement("w:tblGrid")
        tbl.insert(0, grid)
    for child in list(grid):
        grid.remove(child)

    widths_dxa = [int(round(width * 1440)) for width in widths_in]
    if widths_dxa:
        widths_dxa[-1] += total_dxa - sum(widths_dxa)
    for width in widths_dxa:
        col = OxmlElement("w:gridCol")
        col.set(qn("w:w"), str(width))
        grid.append(col)

    for row in table.rows:
        for idx, cell in enumerate(row.cells):
            width = widths_dxa[min(idx, len(widths_dxa) - 1)]
            cell.width = Inches(width / 1440)
            tc_pr = cell._tc.get_or_add_tcPr()
            tc_w = tc_pr.find(qn("w:tcW"))
            if tc_w is None:
                tc_w = OxmlElement("w:tcW")
                tc_pr.append(tc_w)
            tc_w.set(qn("w:w"), str(width))
            tc_w.set(qn("w:type"), "dxa")


def mark_header_repeat(table) -> None:
    tr_pr = table.rows[0]._tr.get_or_add_trPr()
    tbl_header = tr_pr.find(qn("w:tblHeader"))
    if tbl_header is None:
        tbl_header = OxmlElement("w:tblHeader")
        tr_pr.append(tbl_header)
    tbl_header.set(qn("w:val"), "true")


def prevent_row_split(row) -> None:
    tr_pr = row._tr.get_or_add_trPr()
    cant_split = tr_pr.find(qn("w:cantSplit"))
    if cant_split is None:
        cant_split = OxmlElement("w:cantSplit")
        tr_pr.append(cant_split)
    cant_split.set(qn("w:val"), "true")


def add_table(
    doc,
    headers,
    rows,
    widths,
    header_fill=HEADER_FILL,
    body_fill=None,
    font_size=8.0,
    header_size=8.35,
):
    table = doc.add_table(rows=1, cols=len(headers))
    table.style = "Table Grid"
    set_table_geometry(table, widths)
    mark_header_repeat(table)
    prevent_row_split(table.rows[0])
    for i, header in enumerate(headers):
        shade_cell(table.rows[0].cells[i], header_fill)
        set_cell_text(table.rows[0].cells[i], header, bold=True, color=DARK_BLUE, size=header_size)
    for row_data in rows:
        if len(row_data) != len(headers):
            raise ValueError(f"table row has {len(row_data)} cells; expected {len(headers)}: {row_data}")
        row = table.add_row()
        prevent_row_split(row)
        for i, text in enumerate(row_data):
            cell = row.cells[i]
            if body_fill:
                shade_cell(cell, body_fill)
            short_value = len(str(text)) <= 12
            align = WD_ALIGN_PARAGRAPH.CENTER if short_value else None
            set_cell_text(cell, text, size=font_size, align=align)
    spacer = doc.add_paragraph()
    spacer.paragraph_format.space_after = Pt(2)
    return table


def add_para(doc, text="", style=None, size=None, color=INK, bold=None, italic=None, align=None) -> None:
    p = doc.add_paragraph(style=style)
    p.paragraph_format.space_before = Pt(0)
    p.paragraph_format.space_after = Pt(6)
    p.paragraph_format.line_spacing = 1.25
    if align is not None:
        p.alignment = align
    run = p.add_run(text)
    set_run_font(run, size or 11, color, bold, italic)


def add_bullet(doc, text: str) -> None:
    p = doc.add_paragraph(style="List Bullet")
    p.paragraph_format.space_after = Pt(4)
    p.paragraph_format.line_spacing = 1.25
    run = p.add_run(text)
    set_run_font(run, 10.4, INK)


def add_callout(doc, title: str, body: str, fill: str = LIGHT_FILL) -> None:
    table = doc.add_table(rows=1, cols=1)
    table.style = "Table Grid"
    set_table_geometry(table, [6.5], indent_dxa=160)
    mark_header_repeat(table)
    cell = table.rows[0].cells[0]
    shade_cell(cell, fill)
    set_cell_margins(cell, top=120, start=160, bottom=120, end=160)
    cell.text = ""
    p = cell.paragraphs[0]
    p.paragraph_format.space_after = Pt(2)
    title_run = p.add_run(title)
    set_run_font(title_run, 10.2, DARK_BLUE, True)
    body_p = cell.add_paragraph()
    body_p.paragraph_format.space_before = Pt(0)
    body_p.paragraph_format.space_after = Pt(0)
    body_p.paragraph_format.line_spacing = 1.18
    body_run = body_p.add_run(body)
    set_run_font(body_run, 9.4, INK)
    spacer = doc.add_paragraph()
    spacer.paragraph_format.space_after = Pt(2)


CHAPTER_SUMMARY = [
    ["第一章", "灰雾边境", "四色基础：红伤害、蓝防御/冻结、金经济、灰污染", "普通 3-5；精英 5-7；Boss 7-10", "让玩家看懂意图与三步规划。"],
    ["第二章", "镜湖工坊", "护盾、燃烧、经济压力与主色抗性轮换", "普通 5-8；精英 7-10；Boss 9-12", "要求玩家在爆发、防守和资源运营之间切换。"],
    ["第三章", "无色王庭", "高污染、高压意图与终局构筑检查", "普通 6-9；精英 9-12；Boss 10-14", "检验构筑弹性、打断能力与死局恢复。"],
]


RUN_PACING = [
    ["第一章", "约 8", "18-26 分钟", "规则教学、意图识别与第一次构筑转折。"],
    ["第二章", "约 8", "20-30 分钟", "护盾、燃烧、偷取与颜色抗性叠加。"],
    ["第三章", "约 8", "22-34 分钟", "高污染、连续蓄力与终局构筑检查。"],
    ["完整单局", "约 24", "60-90 分钟", "含战斗、路线选择、奖励、商店与事件阅读；暂停时间不计。"],
]


BOARD_COLOR_RULES = [
    ["棋盘基础色", "红 / 蓝 / 金 / 灰", "V1.0 唯一合法棋盘颜色；随机生成、换色、消除、抗性和奖励筛选均不得引用其他基础色。"],
    ["战斗状态", "燃烧、冻结、护盾、抗性", "状态附着于敌我单位或合法颜色结算，不进入棋盘颜色权重。"],
    ["污染机制", "灰蚀压力、灰块净化", "污染只把合法块转为灰色；净化只从灰色恢复到红、蓝或金。"],
    ["色谱主题", "白 / 黑 / 混色", "白、黑仅是色谱主题，混色只组合两种以上合法棋盘色，三者都不是棋盘块。"],
    ["颜色抗性", "红 / 蓝 / 金主色", "敌人可记录并抗拒玩家主色；灰色不计入主色抗性。"],
    ["数据边界", "board_color", "运行时枚举只允许 red / blue / gold / gray；事件、遗物和文案不得扩展该枚举。"],
]


MAPS = {
    "第一章 灰雾边境": [
        ["1", "C1-01", "灰雾巡逻", "普通战", "C1-02A / C1-02B", "强制教学战，沿用当前 Godot C1-01。"],
        ["2", "C1-02A", "褪色犬群", "普通战", "C1-03A / C1-03B", "低 HP 压迫，沿用当前 Godot C1-02A。"],
        ["2", "C1-02B", "褪色神龛", "事件", "C1-03B / C1-03C", "用 HP 换升级/删谱/净化。"],
        ["3", "C1-03A", "镀金盗贼", "普通战", "C1-04A / C1-04B", "金色收益与金抗教学，沿用当前 C1-03A。"],
        ["3", "C1-03B", "旧调色箱", "宝箱", "C1-04B / C1-04C", "低风险遗物补强。"],
        ["3", "C1-03C", "流浪调色师", "事件", "C1-04B / C1-04C", "主动染色、换牌或拿金币。"],
        ["4", "C1-04A", "霜甲卫士", "精英", "C1-05A", "蓝色打断与破甲检查，沿用当前精英。"],
        ["4", "C1-04B", "霜痕哨兵", "普通战", "C1-05A / C1-05B / C1-05C", "蓄力教学，沿用当前 C1-04B。"],
        ["4", "C1-04C", "破篷商队", "商店", "C1-05B / C1-05C / C1-05D", "第一次商店，提供删谱与升级。"],
        ["5", "C1-05A", "调色台", "营火", "C1-06A / C1-06B", "治疗 30% / 升级 / 净化 3 格三选一。"],
        ["5", "C1-05B", "破碎画廊", "事件", "C1-06A / C1-06C", "稀有遗物诱惑，附带灰蚀或 HP 代价。"],
        ["5", "C1-05C", "灰烬搬运工", "普通战", "C1-06A / C1-06C", "污染与护甲复合战斗。"],
        ["5", "C1-05D", "颜料井", "事件", "C1-06B / C1-06C", "用生命换颜料，或封井获得金币。"],
        ["6", "C1-06A", "织雾小队", "普通战", "C1-07", "Boss 前污染预演，沿用当前 C1-06A。"],
        ["6", "C1-06B", "猩红祭司", "精英", "C1-07", "燃烧与回复精英，沿用当前 C1-06B。"],
        ["6", "C1-06C", "金色岔路", "商店", "C1-07", "Boss 前补强，适合经济流。"],
        ["7", "C1-07", "镇门篝火", "营火", "C1-08", "Boss 前保底恢复与意图侦察。"],
        ["8", "C1-08", "灰蚀龙：无色镇魂曲", "Boss", "章节结算", "第一章最终检验，沿用当前 Boss 基线。"],
    ],
    "第二章 镜湖工坊": [
        ["1", "C2-01", "镜潮信使", "普通战", "C2-02A / C2-02B", "第二章开场，检验护盾回合管理。"],
        ["2", "C2-02A", "熔彩矿工", "普通战", "C2-03A / C2-03B", "燃烧与重击交替出现。"],
        ["2", "C2-02B", "冰封谱库", "事件", "C2-03B / C2-03C", "蓝色色谱与回复取舍。"],
        ["3", "C2-03A", "税契偶师", "普通战", "C2-04A / C2-04B", "偷取金币，压迫高金币构筑。"],
        ["3", "C2-03B", "镜底宝箱", "宝箱", "C2-04B / C2-04C", "章节中段遗物补强。"],
        ["3", "C2-03C", "静默拍卖", "事件", "C2-04B / C2-04C", "金币、颜料与稀有遗物交易。"],
        ["4", "C2-04A", "镜湖执法官", "精英", "C2-05A / C2-05B", "高护甲与主色抗性精英。"],
        ["4", "C2-04B", "寒潮祭钟", "普通战", "C2-05A / C2-05C", "防守与蓄力形成固定节拍。"],
        ["4", "C2-04C", "镜湖商站", "商店", "C2-05B / C2-05C / C2-05D", "第二章商店与牌组修剪。"],
        ["5", "C2-05A", "冷却台", "营火", "C2-06A / C2-06B", "治疗、精研或净化。"],
        ["5", "C2-05B", "镜湖倒影", "事件", "C2-06A / C2-06C", "回复与灰蚀压力取舍。"],
        ["5", "C2-05C", "棱镜猎手", "普通战", "C2-06A / C2-06B", "轮换红蓝抗性，鼓励混色完成。"],
        ["5", "C2-05D", "商队旧债", "事件", "C2-06B / C2-06C", "即时经济与黑曜契约代价。"],
        ["6", "C2-06A", "灰玻工匠", "普通战", "C2-07", "Boss 前污染与护甲复合检验。"],
        ["6", "C2-06B", "熔炉双生", "精英", "C2-07", "燃烧、偷取与回复的复合精英。"],
        ["6", "C2-06C", "工坊直售处", "商店", "C2-07", "Boss 前补强。"],
        ["7", "C2-07", "镜湖校音台", "营火", "C2-08", "Boss 前整备与意图侦察。"],
        ["8", "C2-08", "镜湖乐监：倒影赋格", "Boss", "章节结算", "连续抗性、蓄力、护盾与恢复综合考核。"],
    ],
    "第三章 无色王庭": [
        ["1", "C3-01", "王庭司墨", "普通战", "C3-02A / C3-02B", "第三章开场，以污染和主色抗性施压。"],
        ["2", "C3-02A", "断谱骑士", "普通战", "C3-03A / C3-03B", "高频攻击与蓄力重击。"],
        ["2", "C3-02B", "猩红舞台", "事件", "C3-03B / C3-03C", "以生命换红色稀有谱，或恢复 HP。"],
        ["3", "C3-03A", "鎏金审计官", "普通战", "C3-04A / C3-04B", "连续偷取与防御压缩经济窗口。"],
        ["3", "C3-03B", "王庭秘藏", "宝箱", "C3-04B / C3-04C", "终局遗物补强。"],
        ["3", "C3-03C", "无名画廊", "事件", "C3-04B / C3-04C", "用灰蚀压力换稀有遗物。"],
        ["4", "C3-04A", "无色近卫", "精英", "C3-05A / C3-05B", "高护甲、高抗性与重击的终局精英。"],
        ["4", "C3-04B", "静滞唱诗班", "普通战", "C3-05A / C3-05C", "护甲和蓄力形成固定节拍。"],
        ["4", "C3-04C", "王庭黑市", "商店", "C3-05B / C3-05C / C3-05D", "终局商店与构筑修剪。"],
        ["5", "C3-05A", "终幕工坊", "事件", "C3-06A / C3-06B", "最大 HP 换终幕花冠，或回复生命。"],
        ["5", "C3-05B", "合唱残响", "事件", "C3-06A / C3-06C", "补足混色色谱与颜料。"],
        ["5", "C3-05C", "黑曜抄写员", "普通战", "C3-06A / C3-06B", "污染、燃烧与攻击轮转。"],
        ["5", "C3-05D", "终曲休止室", "营火", "C3-06B / C3-06C", "最后一次中途整备。"],
        ["6", "C3-06A", "四色行刑台", "普通战", "C3-07", "最终 Boss 主色抗性预演。"],
        ["6", "C3-06B", "终曲指挥家", "精英", "C3-07", "攻击、污染、回复和重击全意图轮转。"],
        ["6", "C3-06C", "终局商亭", "商店", "C3-07", "最终补给。"],
        ["7", "C3-07", "王座前厅", "营火", "C3-08", "最终 Boss 前恢复与意图侦察。"],
        ["8", "C3-08", "无色王：四色镇魂曲", "Boss", "终局结算", "四色倾向、灰蚀压力与完整构筑总检验。"],
    ],
}


NORMAL_ENEMIES = [
    ["EN-GR-01", "灰雾学徒", "1", "84", "10", "18", "攻击10 -> 污染2 -> 攻击12；基础意图教学。"],
    ["EN-HO-01", "褪色犬群", "1", "115", "12", "20", "攻击12 -> 攻击14 -> 污染1。"],
    ["EN-GD-01", "镀金盗贼", "1", "98", "10", "24", "偷6金 -> 攻击10 -> 金抗35%。"],
    ["EN-FR-01", "霜痕哨兵", "1", "112", "12", "25", "攻击12 -> 蓄力20 -> 重击20。"],
    ["EN-AS-01", "灰烬搬运工", "1", "124", "13", "27", "护盾16 -> 污染2 -> 攻击15。"],
    ["EN-WV-01", "织雾小队", "1", "132", "14", "28", "污染2 -> 攻击14 -> 污染2。"],
    ["EN-ML-01", "镜潮信使", "2", "150", "15", "30", "攻击15 -> 护盾18 -> 攻击18。"],
    ["EN-FG-01", "熔彩矿工", "2", "165", "17", "33", "玩家燃烧1 -> 攻击17 -> 蓄力25 -> 重击25。"],
    ["EN-TX-01", "税契偶师", "2", "158", "16", "36", "偷9金 -> 攻击16 -> 护盾20。"],
    ["EN-BL-01", "寒潮祭钟", "2", "180", "18", "38", "护盾24 -> 蓄力28 -> 重击28。"],
    ["EN-PR-01", "棱镜猎手", "2", "190", "19", "41", "红抗35% -> 攻击19 -> 蓝抗35% -> 攻击21。"],
    ["EN-GL-01", "灰玻工匠", "2", "205", "20", "44", "污染3 -> 护盾26 -> 攻击22。"],
    ["EN-CT-01", "王庭司墨", "3", "230", "22", "45", "污染3 -> 攻击22 -> 主色抗性35%。"],
    ["EN-BK-01", "断谱骑士", "3", "245", "24", "48", "攻击24 -> 攻击20 -> 蓄力36 -> 重击36。"],
    ["EN-AU-01", "鎏金审计官", "3", "260", "23", "52", "偷15金 -> 护盾30 -> 攻击25。"],
    ["EN-CH-01", "静滞唱诗班", "3", "275", "25", "55", "护盾32 -> 蓄力40 -> 重击40 -> 攻击24。"],
    ["EN-OB-01", "黑曜抄写员", "3", "295", "26", "58", "污染4 -> 玩家燃烧1 -> 攻击27。"],
    ["EN-EX-01", "四色行刑台", "3", "310", "28", "62", "主色抗性45% -> 攻击29 -> 护盾34。"],
]


NORMAL_ADVANCE = [
    ["A0 普通", "1.00", "1.00", "1.00", "无额外规则", "标准 1.0 流程。"],
    ["A1 进阶1", "1.08", "1.00", "1.00", "全部敌人 HP +8%", "新局难度选择。"],
    ["A2 进阶2", "1.08", "1.10", "1.00", "攻击与重击数值 +10%", "继承 A1。"],
    ["A3 进阶3", "1.08", "1.10", "0.85", "战斗金币奖励 -15%", "继承 A1-A2。"],
    ["A4 进阶4", "1.08；精英1.24", "1.10；精英1.23", "0.85", "精英额外 HP ×1.15、伤害 ×1.12", "继承 A1-A3。"],
    ["A5 进阶5", "1.08；Boss1.30", "1.10；Boss1.27", "0.85", "Boss 额外 HP ×1.20、伤害 ×1.15、污染 +1", "继承 A1-A4。"],
]


ELITES = [
    ["EL-FR-01", "霜甲卫士", "1", "165", "18", "42 + 遗物", "防御20 -> 攻击18 -> 蓄力30 -> 重击30 -> 蓝抗35%。"],
    ["EL-CR-01", "猩红祭司", "1", "148", "16", "48 + 遗物", "玩家燃烧1 -> 攻击16 -> 回复24 -> 攻击20。"],
    ["EL-ML-01", "镜湖执法官", "2", "250", "23", "58 + 遗物", "护盾32 -> 主色抗性40% -> 攻击25 -> 蓄力38 -> 重击38。"],
    ["EL-FG-02", "熔炉双生", "2", "270", "24", "62 + 遗物", "玩家燃烧1 -> 偷12金 -> 攻击26 -> 回复30。"],
    ["EL-CT-01", "无色近卫", "3", "370", "31", "78 + 遗物", "护盾42 -> 主色抗性45% -> 蓄力50 -> 重击50。"],
    ["EL-FN-01", "终曲指挥家", "3", "395", "32", "84 + 遗物", "攻击28 -> 污染4 -> 回复38 -> 蓄力54 -> 重击54。"],
]


BOSSES = [
    ["B-GR-01", "灰蚀龙：无色镇魂曲", "1", "280", "22", "85", "污染与主色抗性；检验红/蓝/金/灰基础。"],
    ["B-ML-01", "镜湖乐监：倒影赋格", "2", "460", "28", "110", "主色抗性、攻击、护盾、蓄力、重击与回复六拍循环。"],
    ["B-CT-01", "无色王：四色镇魂曲", "3", "680", "36", "0", "主色抗性、污染、攻击、护盾、蓄力与重击六拍循环。"],
]


BOSS_PHASES = [
    ["灰蚀龙 节拍 1-2", "循环位 1-2", "污染3 -> 主色抗性35%", "先控灰蚀，再切换红/蓝/金输出。", "灰色不计入主色抗性。"],
    ["灰蚀龙 节拍 3", "循环位 3", "龙翼横扫：攻击22", "用护盾承担稳定伤害。", "保留稳定伤害窗口。"],
    ["灰蚀龙 节拍 4-5", "循环位 4-5", "蓄力34 -> 重击34", "用冻结打断，或提前建立护盾。", "蓄力意图必须可见。"],
    ["镜湖乐监 节拍 1-2", "循环位 1-2", "主色抗性40% -> 攻击25", "观察抗性后切色输出。", "抗性不连续锁死全部主色。"],
    ["镜湖乐监 节拍 3-4", "循环位 3-4", "护盾34 -> 蓄力42", "破盾后预留冻结或防御。", "护盾不能遮挡蓄力意图。"],
    ["镜湖乐监 节拍 5-6", "循环位 5-6", "重击42 -> 回复34", "打断重击并压住回复窗口。", "回复不超过最大 HP。"],
    ["无色王 节拍 1-2", "循环位 1-2", "主色抗性50% -> 污染5", "切色并维持棋盘可解。", "灰色不计入主色抗性。"],
    ["无色王 节拍 3-4", "循环位 3-4", "攻击34 -> 护盾48", "平衡生存与破盾效率。", "护盾不覆盖后续蓄力提示。"],
    ["无色王 节拍 5-6", "循环位 5-6", "蓄力62 -> 重击62", "终局打断与护盾总检验。", "蓄力意图必须可冻结。"],
]


ENCOUNTER_BY_CHAPTER = [
    ["第一章", "普通战 3-5；精英 0-2；Boss 1", "84-132", "10-14", "148-165", "16-18", "280", "普通难度使用 A0；每条合法路线固定完成 8 层。"],
    ["第二章", "普通战 3-5；精英 0-2；Boss 1", "150-205", "15-20", "250-270", "23-24", "460", "A1-A5 只应用全局难度倍率，不在章节内额外升档。"],
    ["第三章", "普通战 3-5；精英 0-2；Boss 1", "230-310", "22-28", "370-395", "31-32", "680", "普通难度保持 A0；最终 Boss 不再发放无用途金币。"],
]


REWARD_CURVE = [
    ["第一章", "18-28", "42-48 + 普通/稀有遗物", "85 + Boss 遗物", "1 普通谱；20% 稀有", "Boss 前 105-155", "章节后 130-210"],
    ["第二章", "30-44", "58-62 + 稀有遗物", "110 + Boss 遗物", "普通65%/稀有30%/史诗5%", "Boss 前 165-245", "章节后 220-330"],
    ["第三章", "45-62", "78-84 + 稀有/史诗遗物", "最终结算，无金币", "普通55%/稀有35%/史诗10%", "Boss 前 245-360", "终局结算"],
]


SHOP_PRICES = [
    ["普通色谱", "45", "60", "75", "三选一；同色已有 3 张时同色权重 -25%。"],
    ["稀有色谱", "70", "95", "125", "第二章起稳定出现 1 张；第三章可刷新。"],
    ["史诗色谱", "-", "160", "210", "第二章 25% 出现；第三章 60% 出现。"],
    ["升级色谱", "55 +20n", "75 +25n", "95 +30n", "n 为本局已升级次数；营火升级不计 n。"],
    ["删除色谱", "65 +25n", "85 +30n", "110 +35n", "每章首次删除可被商会印章半价。"],
    ["治疗", "40", "55", "75", "回复 25% 最大 HP；第三章另清 1 层毒/封印。"],
    ["普通遗物", "95", "120", "150", "同章商店最多 1 件，防止遗物堆叠失控。"],
    ["刷新", "12", "18", "25", "每次 +8，最多 3 次；避免无限找核心。"],
]


EVENTS = [
    ["褪色神龛", "第一章", "-8 HP，净化 1 张", "+1 颜料，下战污染 +2", "-", "HP 与牌组质量取舍。"],
    ["流浪调色师", "第一章", "35 金币 +1 颜料：染色", "跳过：+12 金币", "-", "主动确定颜色方向。"],
    ["破碎画廊", "第一章", "拿稀有遗物，加入黑曜契约", "回复 20 HP", "-", "高风险遗物与生存取舍。"],
    ["颜料井", "第一章", "失去 6 HP，获得 2 颜料", "封住井口，获得 18 金币", "-", "生命、颜料和金币转换。"],
    ["冰封谱库", "第二章", "随机蓝色色谱，灰蚀压力 +1", "熔解封印，回复 24 HP", "-", "蓝色构筑与生存取舍。"],
    ["静默拍卖", "第二章", "支付 65 金币，获得随机稀有遗物", "出售 1 颜料，获得 32 金币", "-", "金币与颜料双向交易。"],
    ["镜湖倒影", "第二章", "回复 18 HP，灰蚀压力 +2", "获得 1 颜料与随机混色色谱", "-", "灰蚀代价与混色补强。"],
    ["商队旧债", "第二章", "获得 55 金币，加入黑曜契约", "支付 30 金币，获得 2 颜料", "-", "即时经济与长期代价。"],
    ["猩红舞台", "第三章", "失去 12 HP，获得随机红色稀有色谱", "回复 26 HP", "-", "终局爆发与生存取舍。"],
    ["无名画廊", "第三章", "灰蚀压力 +3，获得随机稀有遗物", "离开并获得 24 金币", "-", "终局风险遗物。"],
    ["终幕工坊", "第三章", "最大 HP -8，获得终幕花冠", "回复 35 HP", "-", "不可逆终局校准。"],
    ["合唱残响", "第三章", "随机混色色谱与 1 颜料", "获得 40 金币", "-", "Boss 前补足构筑缺口。"],
]


CARD_RARITY = [
    ["普通", "首章主池；每次奖励 70%-80%", "余烬斩、凝霜格、点金拍、破雾短句、调色练习、无色停顿", "+20%-35% 数值，或触发阈值 -1", "主题谱仍只读取红/蓝/金/灰；不得单卡形成无限资源。"],
    ["稀有", "普通战小概率，精英后保底 1 张", "赤潮回响、冰封休止、债券折光、灰烬炼金、白昼校准、棱镜协奏", "+25%-40% 或附加战术副效果", "每回合触发上限 1-2 次，避免级联随机爆发。"],
    ["史诗", "第二章后小概率；第三章核心池", "炎冠审判、零度终幕、黄金终章、灰王契约、终曲变奏", "收益 +20%-30%，同时降低代价或触发门槛", "白、黑、混色只作为主题；不能绕过 Boss 意图节拍。"],
    ["Boss/特殊", "章节 Boss 后或特殊事件", "无色冠冕、残破王旗、终幕花冠", "默认不可常规升级", "必须改变路线或构筑，不直接把棋盘扩展到第五种颜色。"],
]


CARD_POOLS = [
    ["第一章奖励池", "普通 80% / 稀有 20% / 史诗 0%", "红30%、蓝25%、金20%、灰/混合25%", "3 选 1；首个奖励保底含 1 张基础防御或净化。"],
    ["第二章奖励池", "普通 65% / 稀有 30% / 史诗 5%", "红25%、蓝25%、金20%、灰15%、四色混合15%", "面对护盾、燃烧和抗性压力；缺净化时提高蓝/灰谱权重。"],
    ["第三章奖励池", "普通 55% / 稀有 35% / 史诗 10%", "红22%、蓝22%、金22%、灰14%、四色混合20%", "白/黑仅为主题标签；Boss 前保底防御、净化或打断。"],
    ["精英奖励", "稀有保底；第三章 20% 史诗", "对应合法触发色权重 +30%", "若连续两次同主题，第二次强制跨色候选。"],
    ["Boss 奖励", "Boss 遗物 + Boss 谱可选", "不进普通奖励池", "只在章节间结算发放，避免当前章即时滚雪球。"],
]


RELICS = [
    ["裂色棱镜", "普通", "1+", "每场第一次完成混色谱抽 1 张。", "+6%-9% 有效手牌质量", "每场 1 次。"],
    ["余温护符", "普通", "1+", "燃烧结算时若敌人燃烧 >=3，获得 4 护盾。", "+5%-8% 生存", "每个敌人回合最多 1 次。"],
    ["破雾铃", "普通", "1+", "每场第一次污染后净化 1 格并获得 1 颜料。", "+6%-10% 稳定", "每场 1 次。"],
    ["冻裂怀表", "稀有", "1+", "打断蓄力后返还 1 步。", "+10%-15% 操作收益", "每场最多 1 次。"],
    ["商会印章", "稀有", "1+", "删谱首次半价；金色收益软上限 +20%。", "+12%-18% 经济", "删谱折扣每局 1 次；上限常驻。"],
    ["灰烬花盆", "稀有", "1+", "敌人污染后有 30% 将 1 个灰块转为可用颜色。", "+10%-14% 抗污染", "每次污染最多转 1 格。"],
    ["镇门旧徽", "普通", "1+", "Boss 前营火显示完整意图与抗性侦察。", "信息强度而非战力", "每个 Boss 前营火生效。"],
    ["无色冠冕", "Boss", "第1章", "第一章通关印记；后续章节额外保留 1 张色谱。", "+1 保留位", "唯一，不叠加。"],
    ["红釉剑柄", "普通", "1+", "主动红色 4 连额外造成 6 伤害。", "+6 红色爆发", "每次主动 4 连。"],
    ["蓝纹披肩", "普通", "1+", "回合结束时若有护盾，保留 3 点到下一回合。", "+3 跨回合护盾", "常驻。"],
    ["金账本", "普通", "1+", "每完成 3 次购买后获得 1 颜料。", "+1 颜料/3 次购买", "每 3 次购买触发。"],
    ["灰石酒杯", "普通", "1+", "消除灰色时有 20% 概率回复 1 HP。", "+1 HP 概率续航", "每次灰色消除事件判定。"],
    ["熔火戒", "稀有", "1+", "升级后的红色色谱首次触发时追加 1 层燃烧。", "+1 燃烧", "每场 1 次。"],
    ["静湖印", "稀有", "1+", "冻结敌人时抽 1 张色谱。", "+1 抽取", "每场最多 2 次。"],
    ["镀金钥匙", "稀有", "1+", "开启宝箱时可以选择金币或遗物。", "将随机宝箱改为二选一", "每个宝箱 1 次。"],
    ["净白羽", "稀有", "1+", "灰蚀压力首次达到 6 时清除 3 点。", "-3 灰蚀压力", "每章 1 次。"],
    ["黑曜杯", "稀有", "1+", "每场第一次自伤色谱的收益翻倍。", "自伤收益 x2", "每场 1 次。"],
    ["彩线轴", "普通", "1+", "同回合消除红、蓝、金三色时获得 5 护盾。", "+5 护盾", "每回合 1 次。"],
    ["旧乐谱", "普通", "1+", "镇魂短句类效果额外造成 4 伤害。", "+4 中立伤害", "每次对应色谱触发。"],
    ["旅商铃", "普通", "1+", "商店额外展示 1 件商品。", "+1 商店商品", "常驻。"],
    ["残破王旗", "Boss", "第2章", "每章 Boss 战后选择复制或升级 1 张色谱。", "+1 构筑操作", "持有后每章 Boss 1 次。"],
    ["四色骰", "稀有", "1+", "每回合随机 1 张手牌的首项数值条件 -1，最低为 1。", "目标阈值 -1", "每回合 1 张。"],
    ["裂纹算盘", "普通", "1+", "金币低于 20 时，金色色谱效果 +25%。", "金色效果 x1.25", "低金币期间常驻。"],
    ["终幕花冠", "Boss", "第3章事件", "最终 Boss 战前按最低颜色倾向比例获得护盾。", "0-18 起始护盾", "最终 Boss 入场 1 次。"],
]


ECONOMY = [
    ["开局", "0-30", "0-30", "0-30", "默认 0；若保留系统开放，最高带入 30。"],
    ["首次商店前", "60-95", "85-125", "120-180", "若低于下限，普通战金币或事件金币 +10%。"],
    ["Boss 前", "105-155", "165-245", "245-360", "应足够购买 1 升级 + 1 治疗或 1 稀有谱。"],
    ["章节结束后", "130-210", "220-330", "320-520", "高金币局必须用商店、事件和 Boss 税消耗。"],
    ["单战金色软上限", "24", "30", "36", "商会印章提升 20%，但仍应有显示。"],
    ["目标购买次数", "1-2", "2", "2-3", "若玩家每章购买 <1 次，整体价格下调 15%。"],
]


TTK_THRESHOLDS = [
    ["第一章普通", "3-5", "18-26", "6-22", "平均 <3 回合：HP +10%；>6 回合：HP -10% 或基础伤害 +1。"],
    ["第一章精英", "5-7", "26-34", "22-36", "<5 回合：精英 HP +12%；>8 回合：重击 -10%。"],
    ["第一章 Boss", "7-10", "30-40", "35-60", ">10 回合且玩家败率高：污染值 -1 或 HP -8%。"],
    ["第二章普通", "5-8", "24-38", "18-36", "<5 回合：HP +8%；>8 回合：护盾值或蓄力伤害 -10%。"],
    ["第二章精英", "7-10", "36-50", "35-55", "若精英选择率 <25%，奖励 +10 金或 HP -8%。"],
    ["第二章 Boss", "9-12", "45-60", "50-75", ">12 回合：回复34降至28，或 HP -8%。"],
    ["第三章普通", "6-9", "38-56", "28-50", "<6 回合：HP +10%；>9 回合：护盾/污染值 -10%。"],
    ["第三章精英", "9-12", "52-68", "48-72", ">12 回合：重击或回复值 -10%。"],
    ["第三章 Boss", "10-14", "60-82", "65-100", ">14 回合：Boss HP -10%；灰格死局自动净化2。"],
]


TUNING_RULES = [
    ["过强：普通战平均 <3 回合", "对应章普通敌 HP +10%，或奖励金币 -10%。", "先调后半节点，不动首战教学。"],
    ["过弱：普通战平均 >6/7/8 回合", "对应章 HP -10%，或玩家基础伤害 +1。", "若只发生在低匹配棋盘，优先修棋盘权重。"],
    ["Boss TTK 超阈值", "基础 HP -8%-10%，或降低回复/污染数值。", "不要直接砍 Boss 普攻，保留意图压力。"],
    ["灰格死局", "污染后灰格 >75% 时自动净化 2 格；污染单次上限 6。", "所有 Boss 必须有死局恢复。"],
    ["经济失速", "每章购买次数 <1：价格 -15% 或金币奖励 +15%。", "用商店漏斗检查，而非只看总金币。"],
    ["跳过奖励过多", "奖励跳过率 >55%：提高跨色/净化/升级候选权重。", "说明牌池不解决当前压力。"],
    ["精英无人选", "精英选择率 <25% 且败率正常：精英金币 +10 或遗物稀有权重 +15%。", "败率高时先降攻击，不加奖励诱导。"],
    ["单色碾压", "某色占 Boss 伤害 >65% 且胜率 >70%：Boss 主色抗性 +10% 或跨色奖励提升。", "抗性只检查玩家色，避免灰色误判。"],
]


RUNTIME_VALIDATIONS = [
    ["精研实例", "牌组实例保存 instance_id、card_id、level；结算按 level 读取强化数据。", "已落地；同名色谱可拥有不同实例状态。"],
    ["重复色谱", "每回合触发记录以 instance_id 去重，而非 card_id。", "已落地；同名手牌可分别完成。"],
    ["遗物上限", "每回合、每场、每章触发由独立计数或布尔状态约束。", "已落地；24 件遗物逐件有边界。"],
    ["Boss 主色抗性", "只统计红/蓝/金三种玩家色，不读取灰色污染。", "已落地；混色/白色主题可击碎抗性。"],
    ["蓄力重击", "charge 之后进入 heavy；冻结或打断会清除 charge_pending。", "已落地；意图文本提前公开伤害。"],
    ["灰格死局", "污染后灰格占比超过 75% 时自动净化 2 格。", "已落地；与 Boss 前净化/防御保底共同兜底。"],
]


DATA_LANDING = [
    ["EncounterData", "GameData.ENCOUNTERS 保存 node_type、HP、attack、reward、intents。", "已落地：18 普通 + 6 精英 + 3 Boss。"],
    ["MapData", "GameData.CHAPTER_NODES 按章保存 18 候选节点与 1-8 层连接。", "已落地：单局每层选 1，约 24 个实际节点。"],
    ["IntentSystem", "Enemy/BattleManager 处理 attack、defend、charge、heavy、pollute、steal、resist、heal、player_burn。", "已落地并纳入自动化测试。"],
    ["CardInstance", "GameManager 维护 instance_id、card_id、level 与抽弃牌区域。", "已落地；兼容旧存档迁移。"],
    ["RewardRoll", "按章节、节点类型、稀有度与构筑缺口生成奖励。", "已落地：普通、精英、Boss、商店、事件。"],
    ["RelicSystem", "GameData 定义 24 件遗物，运行时按稀有度与固定来源发放。", "已落地：普通 12、稀有 9、Boss 3。"],
    ["Release QA", "测试汇总内容规模、完整路线、存档、交易、色谱与遗物。", "正式包排除 tests/ 与 tools/。"],
]


BOARD_COLOR_IDS = ("red", "blue", "gold", "gray")


def flatten_text(value):
    if isinstance(value, dict):
        for key, nested in value.items():
            yield str(key)
            yield from flatten_text(nested)
    elif isinstance(value, (list, tuple)):
        for nested in value:
            yield from flatten_text(nested)
    else:
        yield str(value)


def validate_scope() -> None:
    assert len(MAPS) == 3, "V1.0 must contain exactly three chapters"
    assert all(len(rows) == 18 for rows in MAPS.values()), "each chapter must expose 18 candidate nodes"
    assert all(sum(row[3] == "事件" for row in rows) == 4 for rows in MAPS.values()), "each chapter map must contain four event nodes"
    assert len(NORMAL_ENEMIES) == 18, "V1.0 must contain 18 normal enemies"
    assert len(ELITES) == 6, "V1.0 must contain six elites"
    assert len(BOSSES) == 3, "V1.0 must contain three bosses"
    assert len(EVENTS) == 12, "V1.0 must contain 12 events"
    assert len(RELICS) == 24, "V1.0 must contain 24 relics"
    assert {row[0] for row in RELICS} == {
        "裂色棱镜", "余温护符", "破雾铃", "冻裂怀表", "商会印章", "灰烬花盆",
        "镇门旧徽", "无色冠冕", "红釉剑柄", "蓝纹披肩", "金账本", "灰石酒杯",
        "熔火戒", "静湖印", "镀金钥匙", "净白羽", "黑曜杯", "彩线轴",
        "旧乐谱", "旅商铃", "残破王旗", "四色骰", "裂纹算盘", "终幕花冠",
    }, "relic table must match the 24 runtime relics"
    assert all(sum(row[1] == chapter for row in EVENTS) == 4 for chapter in ("第一章", "第二章", "第三章")), "each chapter must contain four authored events"
    assert len(NORMAL_ADVANCE) == 6, "difficulty must contain A0 plus five ascension levels"
    assert [row[0].split()[0] for row in NORMAL_ADVANCE] == ["A0", "A1", "A2", "A3", "A4", "A5"], "ascension IDs must be A0-A5"
    assert RUN_PACING[-1][2] == "60-90 分钟", "full-run duration target must remain 60-90 minutes"
    assert BOARD_COLOR_IDS == ("red", "blue", "gold", "gray"), "board colors are frozen for V1.0"

    corpus = "\n".join(
        flatten_text(
            [
                CHAPTER_SUMMARY,
                MAPS,
                NORMAL_ENEMIES,
                NORMAL_ADVANCE,
                ELITES,
                BOSSES,
                BOSS_PHASES,
                ENCOUNTER_BY_CHAPTER,
                EVENTS,
                CARD_RARITY,
                CARD_POOLS,
                RELICS,
                RUNTIME_VALIDATIONS,
            ]
        )
    )
    forbidden_board_color_phrases = (
        "绿/紫侧色",
        "黑/白终局色",
        "扩展颜色",
        "绿色回复谱",
        "白色净化谱",
        "黑色史诗谱",
        "八色",
        "全色抗性",
        "后续玩家色",
        "白/中立权重",
        "黑与白效果",
    )
    leaked = [phrase for phrase in forbidden_board_color_phrases if phrase in corpus]
    assert not leaked, f"forbidden board-color wording remains: {leaked}"


def add_title_page(doc: Document) -> None:
    add_para(doc, "LEVEL BALANCE MASTER TABLE", size=10.5, color=MUTED, bold=True)

    title = doc.add_paragraph()
    title.paragraph_format.space_before = Pt(10)
    title.paragraph_format.space_after = Pt(4)
    title.paragraph_format.line_spacing = 1.05
    run = title.add_run("《色彩勇者：三消镇魂曲》")
    set_run_font(run, 22, NAVY, True)
    run.add_break()
    run = title.add_run("三章关卡数值总表")
    set_run_font(run, 22, NAVY, True)

    subtitle = doc.add_paragraph()
    subtitle.paragraph_format.space_before = Pt(0)
    subtitle.paragraph_format.space_after = Pt(16)
    run = subtitle.add_run(SUBTITLE)
    set_run_font(run, 13, MUTED)

    add_table(
        doc,
        ["字段", "内容"],
        [
            ["文档目的", "为 V1.0 三章版本提供可直接数据化的地图、敌人、Boss、奖励、经济、卡牌/遗物与调参基线。"],
            ["范围", "3 章；每章 8 层、18 个地图候选节点；单局每章实际访问约 8 节点，共约 24 节点。"],
            ["目标时长", "完整单局 60-90 分钟，含战斗、路线选择、奖励、商店与事件阅读。"],
            ["内容规模", "18 普通敌人、6 精英、3 Boss、12 事件；普通 A0 + A1-A5 五级进阶。"],
            ["四色基线", "棋盘固定 7x7、每回合 3 步，只允许红/蓝/金/灰；章节主题与状态不得增加颜色枚举。"],
            ["设计预设", "紧凑型专业参考手册；表格为主，配少量实现校验说明。"],
            ["编制日期", TODAY.isoformat()],
        ],
        [1.25, 5.25],
        font_size=8.8,
        header_size=9.1,
    )
    add_callout(
        doc,
        "总原则",
        "三章曲线不靠单纯堆 HP，而是逐章增加“看意图、做取舍、处理死局”的负担。第一章教规则，第二章打节奏与状态，第三章考构筑闭环；所有高压机制都必须留下冻结、净化、商店或营火的反制入口。",
        BLUE_FILL,
    )


def build_doc() -> None:
    validate_scope()
    doc = Document()
    configure_document(doc)
    add_title_page(doc)

    doc.add_heading("1. V1.0 数值前提", level=1)
    add_para(
        doc,
        "本文以正式 1.0 Godot 实现作为运行基线，统一三章数据口径。第一章负责规则教学；第二章提高状态与路线压力；第三章提高构筑稳定性要求。",
    )
    add_table(
        doc,
        ["章节", "章节名", "核心学习/考核", "目标 TTK", "策划备注"],
        CHAPTER_SUMMARY,
        [0.72, 1.05, 2.1, 1.05, 1.58],
        font_size=7.9,
    )
    doc.add_heading("1.1 单局节奏与时长预算", level=2)
    add_table(
        doc,
        ["范围", "实际节点", "目标时长", "节奏职责"],
        RUN_PACING,
        [0.95, 0.85, 1.15, 3.55],
        font_size=7.85,
    )
    add_table(
        doc,
        ["系统项", "V1.0 目标值", "说明"],
        [
            ["玩家生命", "120 HP", "首章沿用当前实现；跨章不强制满血，章节后建议回复至 70% 下限。"],
            ["棋盘", "7x7；每回合 3 步", "无效交换不耗步；敌人每玩家回合后按意图行动。"],
            ["棋盘基础色", "红/蓝/金/灰，仅此四色", "当前可运行基线：灰 0.66，红 0.115，蓝 0.115，金 0.11；总权重 1.00。"],
            ["章节扩展方式", "状态 / 主题 / 地图机制", "燃烧、冻结、护盾、抗性、白/黑/混色主题均不得成为棋盘基础色。"],
            ["伤害公式", "10 × 连线倍率 × 级联倍率 × 颜色修正", "3=1.0，4=1.5，5=2.5，6+=4.0；级联 = 1+(cascade-1)*0.35。"],
            ["红色燃烧", "5 伤害/层；上限 4", "红色仍是最快 TTK 入口，但 Boss 用护盾与主色抗性吸收爆发。"],
            ["蓝色冻结", "30% 基础；关键谱可 65%-100%", "冻结必须能稳定取消 charge -> heavy。"],
            ["金色收益", "2 金/块；单战软上限 24/30/36", "避免经济流指数膨胀；商会印章只提高 20%。"],
        ],
        [1.08, 1.4, 4.02],
        font_size=8.0,
    )
    doc.add_heading("1.2 四色系统边界", level=2)
    add_table(
        doc,
        ["层级", "允许内容", "数据约束"],
        BOARD_COLOR_RULES,
        [1.05, 1.45, 4.0],
        font_size=7.75,
    )
    add_callout(
        doc,
        "硬性数据契约",
        "board_color 枚举固定为 red / blue / gold / gray。白、黑、混色只允许通过 theme_tag 表达；燃烧、冻结、护盾、污染和抗性使用独立状态字段，不得向棋盘生成器、掉落权重、Boss 抗性或色谱匹配条件注入第五种颜色。",
        RED_FILL,
    )
    add_callout(
        doc,
        "章节访问模型",
        "每章地图固定 8 层、18 个候选节点，玩家每层实际访问 1 个节点，约 8 节点完成一章。推荐单章构成：普通战 3-5 场、精英 0-2 场、商店/事件/宝箱 1-3 个、营火 1-2 个、Boss 1 场。",
        GREEN_FILL,
    )

    doc.add_heading("2. 三章地图拓扑", level=1)
    for chapter_name, rows in MAPS.items():
        doc.add_heading(chapter_name, level=2)
        add_table(
            doc,
            ["层", "节点 ID", "节点名称", "类型", "连接至", "设计目的 / 实现备注"],
            rows,
            [0.34, 0.72, 1.0, 0.66, 1.28, 2.5],
            font_size=7.05,
            header_size=7.5,
        )

    doc.add_heading("3. 敌人池与进阶", level=1)
    add_para(
        doc,
        "普通敌人为地图常规投放池；精英与 Boss 单独列出。正式 1.0 采用单敌人战斗表现，群体概念通过敌人名称、兼容 HP 与循环意图表达，不增加多目标操作负担。",
    )
    add_table(
        doc,
        ["敌人 ID", "敌人", "章", "HP", "攻", "金币", "核心机制 / 意图"],
        NORMAL_ENEMIES,
        [0.83, 0.82, 0.35, 0.45, 0.38, 0.5, 3.17],
        font_size=7.25,
        header_size=7.55,
    )
    doc.add_heading("3.1 普通难度与 A1-A5 五级进阶", level=2)
    add_table(
        doc,
        ["进阶", "HP 倍率", "攻击倍率", "奖励倍率", "新增词缀", "使用范围"],
        NORMAL_ADVANCE,
        [0.85, 0.7, 0.78, 0.78, 1.72, 1.67],
        font_size=7.55,
        header_size=7.85,
    )
    doc.add_heading("3.2 精英敌人", level=2)
    add_table(
        doc,
        ["敌人 ID", "精英", "章", "HP", "攻", "奖励", "意图循环 / 机制"],
        ELITES,
        [0.82, 0.82, 0.35, 0.48, 0.4, 0.82, 2.81],
        font_size=7.25,
        header_size=7.55,
    )
    doc.add_heading("3.3 Boss 基础表", level=2)
    add_table(
        doc,
        ["Boss ID", "Boss", "章", "HP", "基准攻", "金币", "核心机制"],
        BOSSES,
        [0.85, 1.28, 0.35, 0.5, 0.55, 0.5, 2.47],
        font_size=7.5,
    )

    doc.add_heading("4. Boss 意图节拍", level=1)
    add_table(
        doc,
        ["节拍段", "循环位置", "意图循环", "玩家考核", "调参保护"],
        BOSS_PHASES,
        [0.95, 0.78, 2.05, 1.65, 1.07],
        font_size=7.25,
        header_size=7.55,
    )

    doc.add_heading("5. 遭遇与投放曲线", level=1)
    add_table(
        doc,
        ["章节", "单章战斗构成", "普通 HP", "普通攻", "精英 HP", "精英攻", "Boss HP", "投放规则"],
        ENCOUNTER_BY_CHAPTER,
        [0.65, 1.25, 0.7, 0.62, 0.75, 0.62, 0.65, 1.26],
        font_size=7.2,
        header_size=7.45,
    )
    add_bullet(doc, "普通难度全程使用 A0；第一章首局不随机升阶，确保教学稳定。")
    add_bullet(doc, "选择 A1-A5 后，全局按所选进阶档套用倍率；章节后半只负责机制组合，不再额外偷升档。")
    add_bullet(doc, "每日挑战可叠加独立词缀，但不得修改 A1-A5 的基础倍率，也不得新增棋盘颜色。")

    doc.add_heading("6. 奖励与经济", level=1)
    add_table(
        doc,
        ["章节", "普通战金币", "精英奖励", "Boss 奖励", "卡牌稀有度", "Boss 前金币", "章节后金币"],
        REWARD_CURVE,
        [0.68, 0.72, 1.25, 1.0, 1.28, 0.82, 0.75],
        font_size=7.3,
        header_size=7.55,
    )
    doc.add_heading("6.1 商店价格", level=2)
    add_table(
        doc,
        ["商品", "第一章", "第二章", "第三章", "规则"],
        SHOP_PRICES,
        [1.05, 0.75, 0.75, 0.75, 3.2],
        font_size=7.55,
        header_size=7.85,
    )
    doc.add_heading("6.2 经济曲线", level=2)
    add_table(
        doc,
        ["节点", "第一章", "第二章", "第三章", "调参解释"],
        ECONOMY,
        [1.05, 0.78, 0.78, 0.78, 3.11],
        font_size=7.65,
    )
    add_callout(
        doc,
        "奖励节奏",
        "普通战给即时选择，精英给遗物质变，商店承担修剪与兜底，事件承担高风险转向。Boss 奖励应主要影响下一章，不要让玩家在同章最后一战后获得无法使用的“空奖励”。",
        GOLD_FILL,
    )

    doc.add_heading("7. 事件节点", level=1)
    add_table(
        doc,
        ["事件", "章", "选项 A", "选项 B", "选项 C", "设计目的"],
        EVENTS,
        [0.9, 0.35, 1.4, 1.4, 1.1, 1.35],
        font_size=7.15,
        header_size=7.45,
    )

    doc.add_heading("8. 卡牌 / 色谱与遗物", level=1)
    doc.add_heading("8.1 色谱稀有度与升级收益", level=2)
    add_table(
        doc,
        ["稀有度", "投放", "代表内容", "升级收益", "强度边界"],
        CARD_RARITY,
        [0.72, 1.2, 1.5, 1.35, 1.73],
        font_size=7.35,
        header_size=7.6,
    )
    doc.add_heading("8.2 奖励池权重", level=2)
    add_table(
        doc,
        ["奖励池", "稀有度", "颜色权重", "保底规则"],
        CARD_POOLS,
        [1.0, 1.32, 1.68, 2.5],
        font_size=7.6,
    )
    doc.add_heading("8.3 遗物强度表", level=2)
    add_table(
        doc,
        ["遗物", "稀有度", "章", "效果", "强度预算", "限制"],
        RELICS,
        [0.85, 0.55, 0.35, 2.3, 1.0, 1.45],
        font_size=7.05,
        header_size=7.35,
    )

    doc.add_heading("9. TTK 与调参阈值", level=1)
    add_table(
        doc,
        ["对象", "目标回合", "玩家平均输出/回合", "预期 HP 损耗", "调参动作"],
        TTK_THRESHOLDS,
        [1.0, 0.72, 1.12, 1.0, 2.66],
        font_size=7.45,
        header_size=7.7,
    )
    doc.add_heading("9.1 全局调参规则", level=2)
    add_table(
        doc,
        ["触发条件", "建议调整", "备注"],
        TUNING_RULES,
        [1.55, 2.2, 2.75],
        font_size=7.7,
    )

    doc.add_heading("10. 正式版实现校验", level=1)
    add_callout(
        doc,
        "发布校验重点",
        "精研实例、重复色谱、遗物触发上限、Boss 主色抗性、charge -> heavy 衔接与灰格死局恢复，均已进入正式 1.0 数据通路和自动化验收范围。",
        RED_FILL,
    )
    add_table(
        doc,
        ["校验点", "正式规则", "1.0 状态"],
        RUNTIME_VALIDATIONS,
        [1.1, 2.6, 2.8],
        font_size=7.65,
    )
    doc.add_heading("10.1 数据落点与验收状态", level=2)
    add_table(
        doc,
        ["模块", "数据字段 / 行为", "落地范围"],
        DATA_LANDING,
        [1.05, 3.55, 1.9],
        font_size=7.65,
    )

    doc.add_heading("11. 验收口径", level=1)
    add_bullet(doc, "内容规模：3 章、18 普通敌人、6 精英、3 Boss、12 事件；每章 18 个候选节点、8 层。")
    add_bullet(doc, "完整单局实际访问约 24 个节点，目标时长 60-90 分钟；普通 A0 与 A1-A5 五级进阶均须完成通关率验证。")
    add_bullet(doc, "棋盘基础色始终只有红/蓝/金/灰；任何章节主题、敌人状态、地图机制或色谱标签不得进入颜色枚举。")
    add_bullet(doc, "新手首章胜率目标 55%-70%；熟练玩家三章通关率首版目标 25%-40%。")
    add_bullet(doc, "任意 Boss 战灰格峰值超过 75% 时必须有自动净化或奖励池兜底，不允许无解空转。")
    add_bullet(doc, "每章 Boss 前至少有一次营火或商店路线；高风险路线可以跳过保底，但必须以更高奖励显式诱导。")
    add_bullet(doc, "所有遗物、色谱和敌人意图都要有每回合/每场/每章上限字段，避免随机级联造成指数收益。")

    doc.core_properties.title = TITLE
    doc.core_properties.subject = "V1.0 three-chapter level and balance master table"
    doc.core_properties.author = "Codex"
    doc.core_properties.comments = "Generated from current ColorMatch-3 gameplay-design baseline."
    doc.save(OUT_DOCX)


if __name__ == "__main__":
    build_doc()
    print("Scope QA passed: 3 chapters, 18 normal, 6 elite, 3 boss, 12 events, A0+A1-A5, 60-90 minutes, 4 board colors")
    print(f"Wrote {OUT_DOCX}")
