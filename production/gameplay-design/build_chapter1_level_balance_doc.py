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
OUT_DOCX = OUT_DIR / "色彩勇者_第一章关卡数值文档.docx"

TITLE = "《色彩勇者：三消镇魂曲》第一章关卡数值文档"
SUBTITLE = "第一章：灰雾边境 | Act 1 Level, Encounter & Reward Balance"
TODAY = date(2026, 6, 27)

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
    run = header.add_run("色彩勇者：三消镇魂曲 | 第一章关卡数值")
    set_run_font(run, 9, MUTED)

    footer = section.footer.paragraphs[0]
    footer.text = ""
    footer.alignment = WD_ALIGN_PARAGRAPH.CENTER
    run = footer.add_run("内部关卡数值文档 | 2026-06-27")
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


def set_cell_text(cell, text, bold=False, color=INK, size=8.6, align=None) -> None:
    cell.text = ""
    p = cell.paragraphs[0]
    p.paragraph_format.space_before = Pt(0)
    p.paragraph_format.space_after = Pt(0)
    p.paragraph_format.line_spacing = 1.15
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


def add_table(
    doc,
    headers,
    rows,
    widths,
    header_fill=HEADER_FILL,
    body_fill=None,
    font_size=8.4,
    header_size=8.7,
):
    table = doc.add_table(rows=1, cols=len(headers))
    table.style = "Table Grid"
    set_table_geometry(table, widths)
    mark_header_repeat(table)
    for i, header in enumerate(headers):
        shade_cell(table.rows[0].cells[i], header_fill)
        set_cell_text(table.rows[0].cells[i], header, bold=True, color=DARK_BLUE, size=header_size)
    for row_data in rows:
        row = table.add_row()
        for i, text in enumerate(row_data):
            cell = row.cells[i]
            if body_fill:
                shade_cell(cell, body_fill)
            align = WD_ALIGN_PARAGRAPH.CENTER if len(str(text)) <= 10 else None
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
    set_run_font(run, 10.5, INK)


def add_callout(doc, title: str, body: str, fill: str = LIGHT_FILL) -> None:
    table = doc.add_table(rows=1, cols=1)
    table.style = "Table Grid"
    set_table_geometry(table, [6.5])
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
    set_run_font(body_run, 9.5, INK)
    spacer = doc.add_paragraph()
    spacer.paragraph_format.space_after = Pt(2)


def add_title_page(doc: Document) -> None:
    add_para(doc, "LEVEL BALANCE DOCUMENT", size=10.5, color=MUTED, bold=True)

    title = doc.add_paragraph()
    title.paragraph_format.space_before = Pt(10)
    title.paragraph_format.space_after = Pt(4)
    run = title.add_run(TITLE)
    set_run_font(run, 24, NAVY, True)

    subtitle = doc.add_paragraph()
    subtitle.paragraph_format.space_before = Pt(0)
    subtitle.paragraph_format.space_after = Pt(16)
    run = subtitle.add_run(SUBTITLE)
    set_run_font(run, 13, MUTED)

    add_table(
        doc,
        ["字段", "内容"],
        [
            ["文档目的", "为第一章提供可落地的地图、节点、敌人、奖励与调参基线。"],
            ["依据材料", "《色彩勇者：三消镇魂曲》游戏总策划案、玩法重构策划案、当前 Godot MVP 脚本数值。"],
            ["适用版本", "M1 短路线 MVP，可向 M2 公开 Demo 扩展。"],
            ["核心基线", "玩家 HP 120；7x7 棋盘；每回合 3 步；灰/红/蓝/金四色；普通 3-5 回合、精英 5-7 回合、Boss 7-10 回合。"],
            ["编制日期", TODAY.isoformat()],
        ],
        [1.25, 5.25],
        font_size=9.0,
        header_size=9.3,
    )
    add_callout(
        doc,
        "章节定位",
        "第一章承担教学、验证和第一次 Build 成型三项任务。地图必须让玩家学会看敌人意图、围绕色谱规划 3 步、在普通战与精英/商店/事件之间做风险收益选择，并最终用混色与净化能力通过 Boss 检验。",
        BLUE_FILL,
    )


def build_doc() -> None:
    doc = Document()
    configure_document(doc)
    add_title_page(doc)

    doc.add_heading("1. 数值前提与章节目标", level=1)
    add_para(
        doc,
        "第一章名为“灰雾边境”。它发生在被灰雾吞没的镇外道路、废弃画廊和镇门遗迹，目标是在一局 12-18 分钟内让玩家完成从基础三消战斗到初步 Roguelite 构筑的理解。",
    )
    add_table(
        doc,
        ["项目", "目标值", "说明"],
        [
            ["单局章节时长", "12-18 分钟", "新手首局可到 20 分钟；熟练后 10-14 分钟。"],
            ["地图节点池", "14 个节点", "玩家单局实际进入 8 个节点：起点、5-6 个中段节点、营火、Boss。"],
            ["战斗节点数量", "7 个可选战斗 + 1 Boss", "每局普通战 3-4 场，精英 0-2 场。"],
            ["初始生命", "120 HP", "沿用当前 Demo；第一章不默认全回复，路线压力来自 HP 管理。"],
            ["棋盘与回合", "7x7；每玩家回合 3 步", "无效交换不耗步；敌人每 3 步行动一次。"],
            ["颜色范围", "灰、红、蓝、金 + 中立/混色标签", "第一章不强制引入 8 色，先把四色情况打磨清楚。"],
            ["关卡目标", "击败灰蚀龙并保持灰蚀压力可控", "Boss 会反制玩家最高颜色倾向，要求混色或净化。"],
        ],
        [1.25, 1.35, 3.9],
        font_size=8.8,
    )

    doc.add_heading("1.1 战斗公式基线", level=2)
    add_table(
        doc,
        ["公式/规则", "第一章基线", "调参备注"],
        [
            ["基础伤害", "10 × 数量倍率 × 级联倍率 × 颜色修正", "当前 Demo 已验证；色谱收益叠加在基础伤害之上。"],
            ["数量倍率", "3 连=1.0；4 连=1.5；5 连=2.5；6+ 连=4.0", "5 连以上会显著缩短 TTK，Boss 应用阶段机制吸收爆发。"],
            ["级联倍率", "1 + (cascade - 1) × 0.35", "保留三消爽感；部分色谱要求主动消除，避免纯随机级联代打。"],
            ["红色", "伤害 ×1.5，附加燃烧 2 回合，每次敌方行动前 5 伤害", "第一章燃烧层数上限建议 4，防止红色单通。"],
            ["蓝色", "30% 冻结 1 回合；防御谱可生成护盾", "冻结对蓄力意图权重更高，是精英与 Boss 的关键反制。"],
            ["金色", "每消 1 个 +2 金币；金色谱可提升本回合收益", "单战金色额外收益软上限 24 金币。"],
            ["灰色", "基础伤害；被污染时低收益但可被净化/转化", "灰是压力源，不应变成完全无效块。"],
        ],
        [1.2, 2.5, 2.8],
        font_size=8.3,
    )

    doc.add_heading("1.2 难度曲线目标", level=2)
    add_table(
        doc,
        ["节点类型", "HP 范围", "攻击范围", "目标回合", "预期 HP 损耗", "奖励强度"],
        [
            ["普通战前段", "84-100", "10-12", "3-4", "6-14", "普通色谱 + 18-22 金币。"],
            ["普通战后段", "112-132", "12-14", "4-5", "12-22", "普通/稀有混池 + 22-28 金币。"],
            ["精英", "148-165", "16-18", "5-7", "22-36", "遗物 + 稀有色谱 + 38-48 金币。"],
            ["Boss", "280", "18-32", "7-10", "35-60", "Boss 遗物 + 章节结算奖励。"],
        ],
        [1.15, 1.0, 1.0, 0.9, 1.15, 2.3],
        font_size=8.5,
    )
    add_callout(
        doc,
        "调性判断",
        "第一章不追求高惩罚，而追求“我知道为什么赢或输”。敌人意图要提前展示，奖励要改变下一场目标，Boss 失败要让玩家能复盘是单色过高、净化不足、贪精英还是商店资源不足。",
        GREEN_FILL,
    )

    doc.add_heading("2. 第一章地图", level=1)
    add_para(
        doc,
        "地图采用 9 层节点结构。第一战强制教学，中段提供普通/事件/商店/精英之间的取舍，Boss 前强制给一次调色台，避免玩家因早期选择完全锁死。",
    )
    add_table(
        doc,
        ["层", "节点 ID", "节点名称", "类型", "连接至", "设计目的"],
        [
            ["0", "C1-00", "褪色路牌", "起点", "C1-01", "选择初始小奖励，建立颜色目标。"],
            ["1", "C1-01", "灰雾巡逻", "普通战", "C1-02A / C1-02B", "基础战斗教学：攻击、燃烧、冻结、金币。"],
            ["2", "C1-02A", "褪色犬群", "普通战", "C1-03A / C1-03B", "首次多目标压力或融合体压力。"],
            ["2", "C1-02B", "褪色神龛", "事件", "C1-03B / C1-03C", "用 HP 或灰蚀交换牌组质量。"],
            ["3", "C1-03A", "镀金盗贼", "普通战", "C1-04A / C1-04B", "教学金色不只是收益，也会被敌人反制。"],
            ["3", "C1-03B", "旧调色箱", "宝箱", "C1-04B / C1-04C", "低风险获得遗物或颜料。"],
            ["3", "C1-03C", "流浪调色师", "事件", "C1-04B / C1-04C", "第一次主动染色或获得金币。"],
            ["4", "C1-04A", "霜甲卫士", "精英", "C1-05A", "检验蓝色打断、破甲和爆发窗口。"],
            ["4", "C1-04B", "霜痕哨兵", "普通战", "C1-05A / C1-05B", "安全路线的中段战斗。"],
            ["4", "C1-04C", "破篷商队", "商店", "C1-05B", "资源转化节点，奖励金色运营。"],
            ["5", "C1-05A", "调色台", "营火", "C1-06A / C1-06B", "治疗、升级、净化三选一。"],
            ["5", "C1-05B", "破碎画廊", "事件", "C1-06A / C1-06C", "稀有遗物诱惑与诅咒代价。"],
            ["6", "C1-06A", "织雾小队", "普通战", "C1-07", "Boss 前污染压力预演。"],
            ["6", "C1-06B", "猩红祭司", "精英", "C1-07", "高风险高收益，考验续航与击杀顺序。"],
            ["6", "C1-06C", "金色岔路", "商店", "C1-07", "Boss 前补强，适合经济流。"],
            ["7", "C1-07", "镇门篝火", "营火", "C1-08", "Boss 前最后调参，防止失败过于随机。"],
            ["8", "C1-08", "灰蚀龙：无色镇魂曲", "Boss", "结算", "章节最终检验：混色、净化、意图应对。"],
        ],
        [0.35, 0.72, 1.0, 0.72, 1.3, 2.41],
        font_size=7.35,
        header_size=7.8,
    )

    doc.add_heading("2.1 路线风险分层", level=2)
    add_table(
        doc,
        ["路线类型", "典型路径", "战斗构成", "预期 Boss 前状态", "适合玩家"],
        [
            ["安全路线", "C1-01 -> 事件/宝箱 -> C1-04B -> 调色台 -> C1-06A -> 篝火", "普通 3，精英 0", "HP 90-105；遗物 1；金币 55-80", "新手或低 HP 局。"],
            ["均衡路线", "C1-01 -> C1-02A -> C1-03A/宝箱 -> C1-04A -> 调色台 -> C1-06A", "普通 3，精英 1", "HP 72-92；遗物 2；金币 85-120", "推荐默认路线。"],
            ["贪婪路线", "C1-01 -> C1-02A -> C1-03A -> C1-04A -> 调色台 -> C1-06B", "普通 3，精英 2", "HP 52-78；遗物 3；金币 120+", "熟练玩家，Boss 前需治疗或强构筑。"],
            ["经济路线", "C1-01 -> 事件 -> 宝箱/调色师 -> 商店 -> 画廊 -> 金色岔路", "普通 1-2，精英 0", "HP 95+；牌组更薄；金币消耗大", "金色流和构筑修剪。"],
        ],
        [1.0, 2.0, 1.0, 1.55, 0.95],
        font_size=7.9,
    )

    doc.add_heading("3. 敌人模板", level=1)
    add_para(
        doc,
        "以下为第一章敌人池。若当前 MVP 仍保持单敌人战斗，可使用“单体兼容值”把多目标遭遇压缩成一个融合体；正式版多目标实现后，再拆成表内敌人数量。",
    )
    add_table(
        doc,
        ["敌人 ID", "敌人", "定位", "数量用法", "HP", "攻击", "核心机制"],
        [
            ["EN-GR-01", "灰雾学徒", "入门普通", "单体", "84", "10", "攻击与污染交替；每 2 次行动污染 2 格。"],
            ["EN-HO-01", "褪色猎犬", "低 HP 压迫", "2 只一组", "58", "7", "同伴死亡后剩余猎犬攻击 +2；鼓励群伤或优先击杀。"],
            ["EN-GD-01", "镀金盗贼", "经济反制", "单体", "98", "10", "偷取 6 金币；防守回合获得金色抗性。"],
            ["EN-FR-01", "霜痕哨兵", "蓄力教学", "单体", "112", "12", "每 3 次行动蓄力，下次造成 20 伤害；可被冻结打断。"],
            ["EN-WV-01", "织雾卒", "污染小怪", "3 只一组", "46", "6", "每隔一回合污染 1 格；死亡时净化 1 个灰蚀。"],
            ["EL-FR-01", "霜甲卫士", "防御精英", "单体", "165", "18", "获得护甲、蓄力重击、蓝抗性轮换。"],
            ["EL-CR-01", "猩红祭司", "燃烧精英", "1 主 + 2 侍从", "148 / 45", "16 / 6", "给玩家燃烧；牺牲侍从回复 24 HP。"],
            ["B-GR-01", "灰蚀龙", "章节 Boss", "单体 + 阶段幻影", "280", "22", "三阶段污染；反制玩家最高颜色倾向。"],
        ],
        [0.8, 0.85, 0.85, 0.8, 0.55, 0.55, 2.1],
        font_size=7.6,
        header_size=7.8,
    )

    doc.add_heading("3.1 敌人意图规则", level=2)
    add_table(
        doc,
        ["意图", "显示文本", "数值", "玩家反制"],
        [
            ["攻击", "准备攻击", "本敌人攻击值", "护盾、冻结、击杀。"],
            ["蓄力", "正在聚力", "本回合不攻击；下次攻击 +60%-90%", "蓝色冻结或红色爆发。"],
            ["防御", "结霜护甲", "获得 18-24 护甲或 35% 减伤 1 回合", "准备经济/净化，或用高倍率连消破盾。"],
            ["污染", "扩散灰雾", "生成 2-5 个灰蚀格；Boss 为 4-6 个", "净化谱、消灰转收益、混色谱。"],
            ["偷取", "窃取金辉", "偷 6-10 金币；玩家金币不足时改为 6 伤害", "优先击杀或避开金色贪收益。"],
            ["抗性", "抵抗主色", "对一种颜色 -35% 伤害 1 回合", "切换颜色目标，完成混色谱。"],
            ["牺牲", "血色献祭", "消耗侍从回复 24 HP 并给玩家燃烧 1 层", "先杀侍从或冻结祭司。"],
        ],
        [0.75, 1.0, 1.8, 2.95],
        font_size=8.0,
    )

    doc.add_heading("4. 战斗节点数值表", level=1)
    add_table(
        doc,
        ["节点", "战斗", "敌人数量", "敌人数值", "机制脚本", "目标回合", "关卡后奖励"],
        [
            ["C1-01", "灰雾巡逻", "1", "灰雾学徒 84 HP / 10 ATK", "T1 攻击；T2 污染 2 格；T3 攻击 12；循环。", "3-4", "18 金币；固定三选一：余烬斩/凝霜格/点金拍；颜色偏好 +1。"],
            ["C1-02A", "褪色犬群", "2", "褪色猎犬 58 HP / 7 ATK ×2；单体兼容 115 HP / 12 ATK", "两只轮流攻击；击杀一只后另一只攻击 +2；若单体则 50% HP 后攻击 +2。", "3-4", "20 金币；普通色谱三选一；30% 出现调色练习。"],
            ["C1-03A", "镀金盗贼", "1", "镀金盗贼 98 HP / 10 ATK", "T1 偷 6 金币；T2 攻击；T3 金抗性 35% 并攻击 8；循环。", "3-5", "24 金币；普通/金色谱三选一；若 3 回合内击杀，额外 +8 金币。"],
            ["C1-04B", "霜痕哨兵", "1", "霜痕哨兵 112 HP / 12 ATK", "T1 攻击；T2 蓄力；T3 重击 20；冻结可取消重击并使其下次行动改为攻击 10。", "4-5", "25 金币；普通/蓝色谱三选一；40% 给 1 颜料。"],
            ["C1-06A", "织雾小队", "3", "织雾卒 46 HP / 6 ATK ×3；单体兼容 132 HP / 14 ATK", "每轮污染 1-2 格；每击杀 1 只净化 1 灰蚀；单体每损失 33% HP 净化 1 格。", "4-5", "28 金币；普通/混色谱三选一；必定出现 1 个净化相关选项。"],
            ["C1-04A", "霜甲卫士", "1", "霜甲卫士 165 HP / 18 ATK", "T1 防御 20 护甲；T2 攻击 18；T3 蓄力；T4 重击 30；防御回合蓝伤害 -35%。", "5-7", "42 金币；遗物 1 件；稀有色谱三选一；颜色偏好 +1。"],
            ["C1-06B", "猩红祭司", "3", "祭司 148 HP / 16 ATK + 灰烬侍从 45 HP / 6 ATK ×2", "祭司给玩家燃烧；侍从存活时每轮补 6 伤害；祭司可牺牲侍从回血 24。", "5-7", "48 金币；遗物 1 件；稀有/红色谱三选一；1 颜料。"],
            ["C1-08", "灰蚀龙：无色镇魂曲", "1", "灰蚀龙 280 HP / 22 ATK", "三阶段：污染、主色抗性、镇魂重击；详见 Boss 表。", "7-10", "85 金币；Boss 遗物三选一；章节结算奖励；解锁第二章。"],
        ],
        [0.65, 0.85, 0.62, 1.05, 1.75, 0.63, 1.07],
        font_size=6.9,
        header_size=7.3,
    )

    doc.add_heading("4.1 非战斗节点数值表", level=2)
    add_table(
        doc,
        ["节点", "名称", "类型", "选项/库存", "数值结果", "设计目的"],
        [
            ["C1-00", "褪色路牌", "起点", "选择红/蓝/金/均衡祝福", "红/蓝/金：对应偏好 +1；均衡：+8 金币 +1 颜料", "让第一局立刻有方向。"],
            ["C1-02B", "褪色神龛", "事件", "A 失去 8 HP 净化 1 张灰谱；B 获得 1 颜料但下战污染 +2", "A 提高稳定性；B 提供染色资源", "HP 与牌组质量取舍。"],
            ["C1-03B", "旧调色箱", "宝箱", "随机普通遗物或 25 金币 + 1 颜料", "70% 普通遗物；30% 资源组合", "低风险补强。"],
            ["C1-03C", "流浪调色师", "事件", "A 花 35 金币染色 1 张中立谱；B 跳过得 12 金币", "染色后对应偏好 +1", "服务颜色流派。"],
            ["C1-04C", "破篷商队", "商店", "5 张色谱、2 遗物、升级、删谱、治疗", "价格见商店表；首次刷新 15 金币", "金色运营和牌组修剪。"],
            ["C1-05A", "调色台", "营火", "治疗/升级/净化三选一", "治疗 30 HP；升级 1 张；净化 1 张灰谱或诅咒谱", "中段复原与构筑选择。"],
            ["C1-05B", "破碎画廊", "事件", "A 获得稀有遗物并加入 1 张裂纹诅咒；B 回复 20 HP", "诅咒：抽到时本回合灰权重 +0.08", "风险遗物诱惑。"],
            ["C1-06C", "金色岔路", "商店", "Boss 前商店，治疗库存 +1", "治疗价格 45；删谱价格不递增一次", "给低战斗路线补强。"],
            ["C1-07", "镇门篝火", "营火", "Boss 前必选：治疗/升级/净化/侦察", "治疗 24 HP；侦察显示 Boss 抗性初始目标", "降低 Boss 信息不透明。"],
        ],
        [0.65, 0.85, 0.65, 1.85, 1.4, 1.1],
        font_size=7.1,
        header_size=7.5,
    )

    doc.add_heading("5. Boss：灰蚀龙“无色镇魂曲”", level=1)
    add_para(
        doc,
        "Boss 是第一章的总验收：玩家如果只堆单色，会被抗性拖慢；如果完全不处理灰蚀，会被棋盘污染压垮；如果能用混色谱、净化和冻结打断，则战斗应在 7-10 个玩家回合内结束。",
    )
    add_table(
        doc,
        ["阶段", "HP 区间", "意图循环", "特殊规则", "玩家应对"],
        [
            ["P1 灰鳞苏醒", "280-197", "攻击 20 -> 污染 3 格 -> 攻击 22", "无抗性；每次污染优先靠近已有灰蚀。", "建立输出节奏，保留净化或混色谱。"],
            ["P2 抗性色谱", "196-99", "主色抗性 -> 攻击 24 -> 污染 4 格 -> 蓄力", "读取玩家当前最高颜色使用率，对该色 -35% 伤害 1 回合。", "切换颜色，完成混色谱可立即移除抗性。"],
            ["P3 镇魂重击", "98-0", "蓄力 -> 重击 32 -> 污染 5 格 -> 攻击 24", "蓄力未被打断时额外把 2 个非灰格转灰；冻结或一次 5 连可打断。", "优先蓝色打断，或用红色爆发抢杀。"],
        ],
        [0.95, 0.85, 1.55, 1.8, 1.35],
        font_size=8.0,
    )
    add_table(
        doc,
        ["Boss 调参项", "默认", "偏简单", "偏困难", "调节影响"],
        [
            ["总 HP", "280", "250", "320", "直接影响战斗回合数。"],
            ["P2 主色抗性", "35%", "25%", "45%", "反单色力度。"],
            ["污染数量", "3/4/5", "2/3/4", "4/5/6", "棋盘压力与净化价值。"],
            ["重击伤害", "32", "28", "38", "Boss 处决窗口。"],
            ["混色移除抗性", "是", "是且造成 8 伤害", "仅本回合移除", "混色谱价值。"],
        ],
        [1.25, 0.8, 0.8, 0.8, 2.85],
        font_size=8.3,
    )

    doc.add_heading("6. 奖励与经济", level=1)
    doc.add_heading("6.1 节点奖励规则", level=2)
    add_table(
        doc,
        ["来源", "金币", "色谱/升级", "遗物/颜料", "治疗/净化", "约束"],
        [
            ["普通战", "18-28", "普通三选一；20% 稀有替换", "10%-40% 给 1 颜料", "无默认治疗", "奖励可跳过，跳过 +10 金币。"],
            ["精英", "42-48", "稀有三选一；可含升级", "必得 1 遗物；50% 给 1 颜料", "无默认治疗", "精英遗物不应全是纯数值。"],
            ["宝箱", "0 或 25", "无或随机升级", "70% 普通遗物；30% 颜料", "无", "低风险但选择少。"],
            ["事件", "-35 到 +20", "染色、删谱、诅咒、特殊谱", "可给稀有遗物", "可治疗 20", "必须有明确代价。"],
            ["商店", "消耗", "购买/升级/删谱", "购买遗物/颜料服务", "治疗 25% 最大 HP", "价格递增，防止金色流买空。"],
            ["Boss", "85", "Boss 后选择章节奖励", "Boss 遗物三选一", "进入下章前回复 35% 最大 HP", "章节奖励改变后续 Build 方向。"],
        ],
        [0.8, 0.7, 1.55, 1.25, 1.25, 0.95],
        font_size=7.7,
    )

    doc.add_heading("6.2 第一章色谱奖励池", level=2)
    add_table(
        doc,
        ["色谱", "颜色", "稀有度", "触发条件", "效果"],
        [
            ["余烬斩", "红", "普通", "本回合累计红 >=5", "18 伤害，燃烧 2 回合。"],
            ["燎原", "红", "普通", "一次红色 4 连+", "随机 2 个灰块染红。"],
            ["凝霜格", "蓝", "普通", "一次蓝色 4 连或两次蓝色消除", "获得 12 护盾。"],
            ["点金拍", "金", "普通", "消除金 >=3 且完成任一色谱", "+8 金币，本回合金色收益 +50%。"],
            ["调色练习", "中立", "普通", "同回合消除 2 种颜色", "+1 颜料；三色则净化 1 灰蚀。"],
            ["镇魂短句", "中立", "普通", "触发 2 层以上级联", "12 伤害并抽 1 张；每回合限 1 次。"],
            ["赤潮回响", "红", "稀有", "本回合触发 2 次红色消除", "追加 40% 基础伤害溅射。"],
            ["冰封休止", "蓝", "稀有", "先消蓝，再消非蓝", "若敌人蓄力则打断，否则冻结概率 +35%。"],
            ["债券折光", "金", "稀有", "本回合未受伤且消除金色", "下一次商店升级费用 -20%。"],
            ["灰烬炼金", "混色", "稀有", "先消灰，再消金", "灰色消除量转化为金币和 4 护盾。"],
            ["白昼校准", "白/混色", "史诗", "完成 2 张不同颜色色谱", "清除 1 负面，回复 4 HP。"],
            ["黑曜契约", "黑/混色", "史诗", "剩余 1 步时完成色谱", "失去 3 HP，造成 35 伤害。"],
        ],
        [0.9, 0.55, 0.65, 1.9, 2.5],
        font_size=7.4,
        header_size=7.8,
    )

    doc.add_heading("6.3 第一章遗物池", level=2)
    add_table(
        doc,
        ["遗物", "稀有度", "来源", "效果", "构筑意图"],
        [
            ["裂色棱镜", "普通", "宝箱/精英", "每场战斗第一次完成混色谱时抽 1 张。", "鼓励混色，不直接堆伤害。"],
            ["余温护符", "普通", "宝箱/精英", "燃烧结算时若敌人燃烧 >=3，获得 4 护盾。", "红蓝混搭。"],
            ["冻裂怀表", "稀有", "精英/商店", "打断蓄力后返还 1 步，每场最多 1 次。", "提高读意图价值。"],
            ["商会印章", "稀有", "商店/精英", "商店首次删谱半价；金色收益软上限 +20%。", "经济流但受约束。"],
            ["灰烬花盆", "稀有", "事件/宝箱", "消除灰蚀时有 30% 生成可用颜色。", "把污染转化为机会。"],
            ["破雾铃", "普通", "宝箱/事件", "每场第一次污染发生后，净化 1 格并获得 1 蓝能量。", "新手容错。"],
            ["镇门旧徽", "普通", "精英/商店", "Boss 前营火额外提供一次侦察。", "信息收益。"],
            ["无色冠冕", "Boss", "Boss", "每回合可额外保留 1 张未完成色谱，但第二章 Boss 抗性更强。", "稳定性换长期风险。"],
        ],
        [1.0, 0.65, 0.9, 2.25, 1.7],
        font_size=7.5,
    )

    doc.add_heading("6.4 商店价格", level=2)
    add_table(
        doc,
        ["商品", "第一章价格", "库存", "递增规则", "备注"],
        [
            ["购买普通色谱", "45 金币", "3 张", "无", "可刷新，刷新 15 金币。"],
            ["购买稀有色谱", "70 金币", "1 张", "无", "Boss 前商店必刷 1 张。"],
            ["升级色谱", "55 金币", "1 次", "每买一次 +20", "优先改条件，其次加效果。"],
            ["删谱/净化", "65 金币", "1 次", "每删一次 +25", "牌组低于 8 张时不可购买。"],
            ["治疗", "40 金币", "1 次", "Boss 前商店 45 金币", "回复 30 HP 或 25% 最大 HP，取高者。"],
            ["普通遗物", "120 金币", "1 件", "无", "经济路线的高价值目标。"],
            ["调色服务", "50 金币 +1 颜料", "1 次", "无", "染色 1 张中立谱，对应偏好 +1。"],
        ],
        [1.2, 0.9, 0.7, 1.15, 2.55],
        font_size=8.0,
    )

    doc.add_heading("7. 数值压力测算", level=1)
    add_table(
        doc,
        ["路线", "进入 Boss 前奖励", "进入 Boss 前 HP", "Boss 胜率目标", "设计解读"],
        [
            ["安全路线", "1-2 遗物，2-3 新谱，金币 55-80", "90-105", "70%-80%", "奖励少但稳定，应能靠基础理解通关。"],
            ["均衡路线", "2 遗物，3-4 新谱，金币 85-120", "72-92", "65%-75%", "推荐路线，Boss 有压力但 Build 更完整。"],
            ["贪婪路线", "3 遗物，4-5 新谱，金币 120+", "52-78", "55%-70%", "上限更高，失败多来自低 HP 和诅咒。"],
            ["经济路线", "1 遗物，精修牌组，金币基本花光", "95+", "60%-75%", "Boss 依赖商店购买质量，战斗练习少。"],
        ],
        [1.0, 1.65, 0.9, 1.0, 1.95],
        font_size=8.2,
    )
    add_table(
        doc,
        ["指标", "目标区间", "过低表现", "过高表现", "优先调参"],
        [
            ["普通战平均回合", "3-5", "玩家无感通关，奖励像白给", "早期疲劳，路线节奏拖慢", "HP 每次 ±10；攻击每次 ±2。"],
            ["精英平均回合", "5-7", "精英不值得绕路", "精英路线必死", "护甲/蓄力伤害/金币奖励。"],
            ["Boss 平均回合", "7-10", "Boss 无阶段感", "失败像数值墙", "Boss HP、污染数、抗性持续时间。"],
            ["Boss 前平均 HP", "65-95", "路线风险消失", "玩家不敢打精英", "营火治疗、普通攻击、事件代价。"],
            ["单色使用占比", "35%-55%", "颜色选择无意义", "单色压倒所有路线", "抗性、混色奖励、颜色权重。"],
            ["商店购买次数", "1-3", "金币无价值", "金色流买空系统", "价格、金币产出、刷新费用。"],
        ],
        [1.05, 1.05, 1.35, 1.35, 1.7],
        font_size=7.8,
    )

    doc.add_heading("8. 数据化落地建议", level=1)
    add_para(
        doc,
        "当前 Godot Demo 的 GameManager.stages 仍是三节点数组。第一章扩展时建议先把地图、敌人和奖励拆成数据表，再让 UI 根据 node_id 和 edges 生成路线图。这样可以先接入单体兼容值，之后再切到多敌人战斗。",
    )
    add_table(
        doc,
        ["数据表", "关键字段", "第一章必填内容"],
        [
            ["chapter_nodes.json", "id、layer、type、name、edges、encounter_id、reward_table、risk", "录入 C1-00 至 C1-08 的全部节点和连接。"],
            ["encounters.json", "id、enemy_units、mvp_single_fallback、intent_script、target_turns", "录入 7 个战斗遭遇 + Boss。"],
            ["enemies.json", "id、name、max_hp、attack、resist、status_rules、sprite_key", "录入本章 8 个敌人模板。"],
            ["reward_tables.json", "id、gold_min/max、spectrum_pool、relic_pool、special_choice", "普通、精英、Boss、宝箱、事件、商店分表。"],
            ["events.json", "id、title、choices、cost、reward、flags", "录入 4 个第一章事件，保留后续扩展位。"],
            ["shop_inventory.json", "slot_type、price、rarity_weight、stock、price_growth", "商店和 Boss 前商店共用，库存权重不同。"],
        ],
        [1.35, 2.45, 2.7],
        font_size=7.9,
    )
    add_callout(
        doc,
        "落地顺序",
        "建议先实现：地图数据表 -> 普通/精英/Boss 单体兼容值 -> 奖励表 -> 商店与事件 -> 多目标战斗。不要一开始就同时接入 8 色、复杂遗物和多敌人 UI，否则很难判断第一章失败来自数值、界面还是规则复杂度。",
        GOLD_FILL,
    )

    doc.add_heading("9. 试玩验收清单", level=1)
    add_bullet(doc, "新玩家 10 分钟内能说出：色谱不是按钮，而是本回合三消目标。")
    add_bullet(doc, "70% 以上回合中，玩家会先看敌人意图或色谱再进行交换。")
    add_bullet(doc, "普通战平均 3-5 回合，精英平均 5-7 回合，Boss 平均 7-10 回合。")
    add_bullet(doc, "至少 2 条路线有明显价值：安全路线能通关，精英路线能拿到更强构筑。")
    add_bullet(doc, "失败玩家能指出原因：低 HP、没有净化、贪精英、Boss 抗性、商店选择，而不是只觉得随机。")
    add_bullet(doc, "连续 3 局至少出现 2 种主流派记忆点：红色爆发、蓝色控制、金色运营、混色净化。")
    add_bullet(doc, "Boss 前商店和营火不会成为必选答案；玩家能根据当前 HP、金币和牌组质量做不同选择。")

    doc.save(OUT_DOCX)
    print(OUT_DOCX)


if __name__ == "__main__":
    build_doc()
