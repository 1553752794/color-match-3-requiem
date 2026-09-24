from __future__ import annotations

from pathlib import Path

from docx import Document
from docx.enum.section import WD_SECTION
from docx.enum.table import WD_CELL_VERTICAL_ALIGNMENT, WD_TABLE_ALIGNMENT
from docx.enum.text import WD_ALIGN_PARAGRAPH
from docx.oxml import OxmlElement
from docx.oxml.ns import qn
from docx.shared import Inches, Pt, RGBColor


OUT_DIR = Path(__file__).resolve().parent
OUT_DOCX = OUT_DIR / "色彩勇者_玩法重构策划案_色谱系统.docx"

BLUE = RGBColor(0x2E, 0x74, 0xB5)
DARK_BLUE = RGBColor(0x1F, 0x4D, 0x78)
INK = RGBColor(0x22, 0x22, 0x22)
MUTED = RGBColor(0x66, 0x66, 0x66)
HEADER_FILL = "E8EEF5"
LIGHT_FILL = "F4F6F9"
RED_FILL = "FCE4D6"
BLUE_FILL = "DDEBF7"
GOLD_FILL = "FFF2CC"
GREEN_FILL = "E2F0D9"


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

    h2 = doc.styles["Heading 2"]
    set_style_font(h2, 13, BLUE, True)
    h2.paragraph_format.space_before = Pt(14)
    h2.paragraph_format.space_after = Pt(7)
    h2.paragraph_format.line_spacing = 1.25

    h3 = doc.styles["Heading 3"]
    set_style_font(h3, 12, DARK_BLUE, True)
    h3.paragraph_format.space_before = Pt(10)
    h3.paragraph_format.space_after = Pt(5)
    h3.paragraph_format.line_spacing = 1.25

    for style_name in ["List Bullet", "List Number"]:
        style = doc.styles[style_name]
        set_style_font(style, 11)
        style.paragraph_format.space_after = Pt(4)
        style.paragraph_format.line_spacing = 1.25

    header_p = section.header.paragraphs[0]
    header_p.text = ""
    header_p.paragraph_format.space_after = Pt(0)
    run = header_p.add_run("色彩勇者玩法重构策划案 | 色谱系统")
    set_run_font(run, 9, MUTED)

    footer_p = section.footer.paragraphs[0]
    footer_p.text = ""
    footer_p.alignment = WD_ALIGN_PARAGRAPH.CENTER
    footer_run = footer_p.add_run("内部玩法设计稿 | 2026-06-27")
    set_run_font(footer_run, 9, MUTED)


def shade_cell(cell, fill: str) -> None:
    tc_pr = cell._tc.get_or_add_tcPr()
    shd = tc_pr.find(qn("w:shd"))
    if shd is None:
        shd = OxmlElement("w:shd")
        tc_pr.append(shd)
    shd.set(qn("w:fill"), fill)


def set_cell_margins(cell, top=80, start=120, bottom=80, end=120) -> None:
    tc = cell._tc
    tc_pr = tc.get_or_add_tcPr()
    tc_mar = tc_pr.first_child_found_in("w:tcMar")
    if tc_mar is None:
        tc_mar = OxmlElement("w:tcMar")
        tc_pr.append(tc_mar)
    for margin_name, value in [("top", top), ("start", start), ("bottom", bottom), ("end", end)]:
        node = tc_mar.find(qn(f"w:{margin_name}"))
        if node is None:
            node = OxmlElement(f"w:{margin_name}")
            tc_mar.append(node)
        node.set(qn("w:w"), str(value))
        node.set(qn("w:type"), "dxa")


def set_cell_text(cell, text, bold=False, color=INK, size=10.2, align=None) -> None:
    cell.text = ""
    p = cell.paragraphs[0]
    p.paragraph_format.space_after = Pt(0)
    p.paragraph_format.line_spacing = 1.2
    if align is not None:
        p.alignment = align
    run = p.add_run(text)
    set_run_font(run, size, color, bold)
    cell.vertical_alignment = WD_CELL_VERTICAL_ALIGNMENT.CENTER
    set_cell_margins(cell)


def set_table_geometry(table, widths_in) -> None:
    table.alignment = WD_TABLE_ALIGNMENT.LEFT
    table.autofit = False
    tbl = table._tbl
    tbl_pr = tbl.tblPr

    tbl_w = tbl_pr.find(qn("w:tblW"))
    if tbl_w is None:
        tbl_w = OxmlElement("w:tblW")
        tbl_pr.append(tbl_w)
    tbl_w.set(qn("w:w"), "9360")
    tbl_w.set(qn("w:type"), "dxa")

    tbl_ind = tbl_pr.find(qn("w:tblInd"))
    if tbl_ind is None:
        tbl_ind = OxmlElement("w:tblInd")
        tbl_pr.append(tbl_ind)
    tbl_ind.set(qn("w:w"), "120")
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
    widths_dxa = [int(round(w * 1440)) for w in widths_in]
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


def add_table(doc, headers, rows, widths, header_fill=HEADER_FILL, body_fill=None):
    table = doc.add_table(rows=1, cols=len(headers))
    table.style = "Table Grid"
    set_table_geometry(table, widths)
    for i, header in enumerate(headers):
        shade_cell(table.rows[0].cells[i], header_fill)
        set_cell_text(table.rows[0].cells[i], header, bold=True, color=DARK_BLUE, size=9.7)
    for row_data in rows:
        row = table.add_row()
        for i, text in enumerate(row_data):
            cell = row.cells[i]
            if body_fill:
                shade_cell(cell, body_fill)
            set_cell_text(cell, str(text), size=9.5)
    doc.add_paragraph()
    return table


def add_para(doc, text="", style=None, size=None, color=INK, bold=None, italic=None, align=None) -> None:
    p = doc.add_paragraph(style=style)
    p.paragraph_format.line_spacing = 1.25
    if align is not None:
        p.alignment = align
    run = p.add_run(text)
    set_run_font(run, size, color, bold, italic)


def add_bullets(doc, items) -> None:
    for item in items:
        add_para(doc, item, style="List Bullet")


def add_numbers(doc, items) -> None:
    for item in items:
        add_para(doc, item, style="List Number")


def add_callout(doc, title, body, fill=LIGHT_FILL) -> None:
    table = doc.add_table(rows=1, cols=1)
    table.style = "Table Grid"
    set_table_geometry(table, [6.5])
    cell = table.rows[0].cells[0]
    shade_cell(cell, fill)
    set_cell_margins(cell, top=120, bottom=120, start=160, end=160)
    cell.text = ""
    p = cell.paragraphs[0]
    p.paragraph_format.space_after = Pt(3)
    r = p.add_run(title)
    set_run_font(r, 10.5, DARK_BLUE, True)
    p2 = cell.add_paragraph()
    p2.paragraph_format.space_after = Pt(0)
    p2.paragraph_format.line_spacing = 1.2
    r2 = p2.add_run(body)
    set_run_font(r2, 10, INK)
    doc.add_paragraph()


def build_doc() -> None:
    doc = Document()
    configure_document(doc)

    title = doc.add_paragraph()
    title.alignment = WD_ALIGN_PARAGRAPH.CENTER
    title.paragraph_format.space_after = Pt(4)
    r = title.add_run("《色彩勇者：三消镇魂曲》玩法重构策划案")
    set_run_font(r, 22, RGBColor(0x0B, 0x25, 0x45), True)

    subtitle = doc.add_paragraph()
    subtitle.alignment = WD_ALIGN_PARAGRAPH.CENTER
    subtitle.paragraph_format.space_after = Pt(12)
    r = subtitle.add_run("三消 × 色谱构筑系统 | MVP 可跑通设计稿")
    set_run_font(r, 12, MUTED)

    add_callout(
        doc,
        "核心判断",
        "本作不应做成“传统三消 + 传统卡牌”的并列系统。推荐把卡牌转化为“色谱”：每张色谱都是挂在回合旁的战术契约，玩家通过三消完成条件并触发效果。这样棋盘仍是主操作，色谱负责给每回合提供目标、构筑和叙事含义。",
        GREEN_FILL,
    )

    doc.add_heading("1. 设计目标与改造理由", level=1)
    add_para(
        doc,
        "现有 Demo 已经跑通主菜单、路线图、三场战斗、7×7 棋盘、颜色伤害、能量技能、染色权和结局统计。它最有价值的方向是“每一次消除都在塑造世界”。本次重构的目标不是推翻三消，而是让三消每一步拥有更明确的战术目标和长期构筑反馈。",
    )
    add_table(
        doc,
        ["当前问题", "影响", "重构目标"],
        [
            ["技能像按钮冷却", "玩家攒满能量后点击释放，三消规划与技能释放之间有断层。", "让技能条件直接嵌入三消过程。"],
            ["颜色资源浅", "红/蓝/金分别是伤害、控制、金币，但局内 Build 变化不足。", "让颜色既影响战斗效果，也影响色谱牌组、奖励、结局。"],
            ["奖励单变量", "染色权只提高掉落权重，短期可感知但长期选择较少。", "奖励分成新色谱、升级、染色、删谱、棋盘生态五类。"],
            ["敌人压力弱", "敌人只有攻击，玩家缺少针对回合目标的判断。", "加入敌人意图，让玩家根据威胁选择完成哪张色谱。"],
        ],
        [1.55, 2.45, 2.5],
    )

    doc.add_heading("2. 核心玩法概念：色谱不是手牌，而是战术契约", level=1)
    add_para(
        doc,
        "色谱看起来可以像卡牌，但它不承担传统卡牌游戏里的“支付费用后点击释放”职责。色谱的职责是定义本回合的三消目标：当玩家通过棋盘操作满足条件时，色谱自动发动。玩家真正的输入仍然是交换色块。",
    )
    add_table(
        doc,
        ["色谱字段", "说明", "示例"],
        [
            ["颜色归属", "决定它被哪些颜色奖励、敌人抗性、结局倾向影响。", "红谱、蓝谱、金谱、灰谱、混色谱"],
            ["触发条件", "把“消什么、怎么消、何时消”转化为目标。", "本回合累计消除 5 个红色"],
            ["效果", "满足条件后自动结算，不额外消耗点击。", "造成伤害并附加燃烧"],
            ["时机", "决定是在消除后、回合末、敌人行动前还是胜利后触发。", "敌人攻击前获得护盾"],
            ["升级项", "提供局内成长方向。", "降低触发门槛、提高效果、增加染色"],
        ],
        [1.15, 3.05, 2.3],
    )
    add_callout(
        doc,
        "一句话定位",
        "棋盘是行动层，色谱是策略层，颜色是资源层和叙事层。玩家不是“先打牌再三消”，而是在三消时完成手上的战术乐章。",
        BLUE_FILL,
    )

    doc.add_heading("3. 核心循环", level=1)
    doc.add_heading("3.1 单步短循环", level=2)
    add_numbers(
        doc,
        [
            "玩家观察棋盘、敌人意图和当前 3 张色谱。",
            "玩家交换相邻色块；只有形成三连才消耗 1 步。",
            "棋盘生成消除事件：颜色、数量、级联层数、触发顺序。",
            "基础三消伤害立即结算，保证即使没有完成色谱也能推进战斗。",
            "色谱读取消除事件，满足条件的色谱自动触发效果。",
            "下落补齐后继续判断级联，直到棋盘稳定。",
        ],
    )
    doc.add_heading("3.2 回合战斗循环", level=2)
    add_numbers(
        doc,
        [
            "回合开始：敌人展示意图，玩家抽 3 张色谱；可保留 1 张未完成色谱到下回合。",
            "玩家有 3 步操作，优先决定要完成哪张色谱，而不是盲目消最多块。",
            "每一步都可造成基础伤害、推进色谱条件、改变棋盘局面。",
            "3 步结束后，未完成且未保留的色谱进入弃谱堆。",
            "敌人根据意图行动：攻击、防御、污染、蓄力、净化玩家增益等。",
            "若敌人 HP 归零则进入奖励；若玩家 HP 归零则失败。",
        ],
    )
    doc.add_heading("3.3 局内成长循环", level=2)
    add_para(
        doc,
        "每场战斗胜利后，奖励不再只是增加某种颜色掉落率，而是让玩家改变下一场战斗的“目标集合”。这让玩家产生“我这局要走红色爆发、蓝色控制、金色运营、还是混色平衡”的 Build 意识。",
    )
    add_table(
        doc,
        ["奖励类型", "玩家获得", "对下一场战斗的影响"],
        [
            ["新色谱", "从 3 张候选中加入 1 张。", "增加新的触发目标和战斗效果。"],
            ["升级色谱", "强化已有色谱。", "降低触发门槛或提高效果，形成核心 Build。"],
            ["染色色谱", "把中立谱染成某种颜色。", "吃颜色加成，也提高对应结局倾向。"],
            ["删谱/净化", "移除低价值或污染色谱。", "提高抽到核心色谱的稳定性。"],
            ["棋盘生态", "提高某颜色掉落、降低灰色污染。", "让牌组目标与棋盘概率互相咬合。"],
        ],
        [1.25, 2.0, 3.25],
    )

    doc.add_heading("4. 资源循环设计", level=1)
    add_para(
        doc,
        "可跑通的玩法必须有稳定来源、明确消耗、正反馈和约束。下面的资源表用于验证系统不会只停留在概念层。",
    )
    add_table(
        doc,
        ["资源", "来源", "消耗/用途", "循环意义", "防失控约束"],
        [
            ["行动步数", "每回合固定 3 步；少量色谱可临时返还 1 步。", "有效交换消耗。", "形成回合压力，让色谱目标有取舍。", "每回合步数上限 4，返还效果每回合最多 1 次。"],
            ["消除事件", "棋盘匹配和级联产生。", "基础伤害、推进色谱条件、记录结局倾向。", "把三消操作转化为所有系统的输入。", "无效交换不消耗步数，棋盘无解时重置。"],
            ["色谱牌组", "初始牌组、战斗奖励、商店购买。", "抽取、弃置、升级、删除、染色。", "提供 Roguelike 构筑核心。", "牌组建议 8-16 张，过小禁止继续删谱。"],
            ["金币", "金色消除、战斗奖励、金色谱触发。", "商店买谱、升级、删谱、治疗。", "让金色成为运营流派而非单纯加分。", "商店价格递增，单场金币收益有软上限。"],
            ["颜料", "完成色谱、精英奖励、Boss 前事件。", "染色色谱、改变棋盘权重、净化灰色污染。", "连接战斗表现与世界染色。", "高阶染色需要混色成本，避免单色滚雪球。"],
            ["颜色倾向", "消除颜色、选择染色、使用对应色谱。", "不直接消耗，用于结局、事件、敌人反应。", "让操作和叙事绑定。", "单色过高会带来敌人抗性或结局代价。"],
            ["灰蚀压力", "敌人污染、事件惩罚、过度使用单色。", "需要蓝/金/混色谱净化，或通过消灰转化。", "提供负反馈和局势变化。", "污染块不能完全阻断可行动作。"],
        ],
        [0.95, 1.25, 1.25, 1.45, 1.6],
    )

    doc.add_heading("5. 战斗规则与数值草案", level=1)
    doc.add_heading("5.1 基础三消仍然保底推进", level=2)
    add_para(
        doc,
        "基础伤害沿用当前 Demo 思路，色谱效果叠加在基础消除之上，而不是取代基础消除。这样即使玩家抽到暂时难完成的色谱，也不会出现“这一回合完全空过”的挫败。",
    )
    add_table(
        doc,
        ["项目", "建议值", "说明"],
        [
            ["棋盘", "7×7", "保留现有尺寸，信息量适中，当前代码已支持。"],
            ["每回合步数", "3", "保留现有节奏；返还步数效果最多使回合达到 4 步。"],
            ["基础伤害", "10 × 数量倍率 × 级联倍率", "沿用当前公式，保证三消爽感。"],
            ["数量倍率", "3=1.0，4=1.5，5=2.5，6+=4.0", "鼓励追求 4 连、5 连和大消除。"],
            ["级联倍率", "1 + (cascade - 1) × 0.35", "保留连消奖励。"],
            ["色谱抽取", "每回合抽 3 张", "让玩家每回合都有明确目标。"],
            ["保留规则", "可保留 1 张未完成色谱", "减少纯随机挫败，支持两回合规划。"],
        ],
        [1.35, 1.5, 3.65],
    )
    doc.add_heading("5.2 起始牌组建议", level=2)
    add_table(
        doc,
        ["色谱", "颜色", "触发条件", "效果"],
        [
            ["余烬斩", "红", "本回合累计消除红色 ≥5。", "造成 18 点伤害，附加燃烧 2 回合。"],
            ["燎原", "红", "一次红色 4 连或以上。", "随机 2 个灰块染红。"],
            ["凝霜格", "蓝", "一次蓝色 4 连或本回合两次蓝色消除。", "获得护盾，抵挡下一次 50% 伤害。"],
            ["冰封休止", "蓝", "本回合先消蓝，再消任意非蓝色。", "敌人冻结概率 +35%；若敌人正在蓄力则必定打断。"],
            ["点金拍", "金", "消除金色 ≥3 且回合结束前仍至少完成 1 张色谱。", "获得金币，并使本回合金色收益 +50%。"],
            ["灰烬炼金", "混色", "先消灰，再消金。", "将本回合灰色消除量转为额外金币。"],
            ["镇魂短句", "中立", "触发 2 级以上连消。", "造成额外伤害，并抽 1 张色谱。"],
            ["调色练习", "中立", "同一回合消除 2 种不同颜色。", "获得 1 颜料；若为三色则额外净化 1 个灰蚀。"],
        ],
        [1.0, 0.65, 2.35, 2.5],
    )

    doc.add_heading("6. 敌人意图与关卡节奏", level=1)
    add_para(
        doc,
        "敌人意图是色谱系统成立的关键压力源。玩家看到敌人下回合要做什么，才会思考“本回合应完成护盾谱、爆发谱、净化谱还是经济谱”。",
    )
    add_table(
        doc,
        ["敌人意图", "行为", "玩家对应决策"],
        [
            ["攻击", "回合末造成直接伤害。", "优先完成蓝色护盾、冻结或快速击杀。"],
            ["蓄力", "下回合强攻，本回合不攻击。", "选择爆发输出或打断型蓝谱。"],
            ["防御", "获得护甲，降低下回合受到的伤害。", "完成金/灰转化、准备下回合，而非强行打伤害。"],
            ["污染", "将若干普通块变成灰蚀块。", "使用净化谱、混色谱或消灰转收益。"],
            ["抗性", "临时提高对某颜色的抗性。", "促使玩家切换颜色目标，避免单色无脑滚雪球。"],
        ],
        [1.25, 2.25, 3.0],
    )

    doc.add_heading("7. 可跑通性验证", level=1)
    doc.add_heading("7.1 规则闭合检查", level=2)
    add_table(
        doc,
        ["检查项", "结论", "原因"],
        [
            ["玩家是否每回合都有事做", "通过", "棋盘保证至少一个可行动作；有效三消必定造成基础伤害。"],
            ["色谱是否会阻断战斗", "通过", "色谱是额外目标，不是造成伤害的唯一入口。未完成也只是进入弃谱。"],
            ["资源是否有来源和消耗", "通过", "步数、金币、颜料、牌组、颜色倾向都有明确来源和用途。"],
            ["构筑是否影响下一场", "通过", "新色谱、升级、染色、删谱、棋盘生态都会改变后续回合目标。"],
            ["失败压力是否存在", "通过", "敌人意图、HP、污染和抗性迫使玩家做取舍。"],
            ["是否会无限循环", "需约束", "返还步数、抽牌、金币收益必须设置每回合/每战上限。本文已给出上限。"],
        ],
        [1.45, 0.9, 4.15],
    )

    doc.add_heading("7.2 示例战斗推演", level=2)
    add_para(
        doc,
        "假设普通敌人 HP 90、攻击 12。玩家起始抽到“余烬斩、凝霜格、点金拍”，本回合敌人意图为攻击。",
    )
    add_table(
        doc,
        ["步骤", "玩家操作/系统事件", "结算结果"],
        [
            ["第 1 步", "玩家交换形成红色 3 连，随后级联出灰色 3 连。", "造成基础伤害；余烬斩进度红 3/5；镇魂类连消谱若在手可被推进。"],
            ["第 2 步", "玩家形成蓝色 4 连。", "造成基础伤害；凝霜格触发，获得护盾，准备抵挡敌人攻击。"],
            ["第 3 步", "玩家形成红色 3 连。", "余烬斩累计红色 6/5，触发 18 点伤害并燃烧。"],
            ["回合末", "点金拍未完成，进入弃谱；敌人攻击。", "护盾抵挡 50% 伤害，玩家只受 6 点；敌人带燃烧进入下回合。"],
            ["下回合", "玩家抽新色谱，弃谱堆等待牌库空后洗回。", "牌组循环继续；战斗进度、HP 压力、颜色倾向都已改变。"],
        ],
        [0.9, 3.0, 2.6],
    )
    add_callout(
        doc,
        "推演结论",
        "这个回合中，玩家没有额外点击“技能按钮”，但完成了防御和输出两张色谱；未完成的金色谱也自然进入弃谱。三消输入、色谱目标、敌人压力和资源变化形成闭环。",
        GREEN_FILL,
    )

    doc.add_heading("8. 与现有 Godot Demo 的落地关系", level=1)
    add_para(
        doc,
        "当前代码已经具备重构所需的核心输入：Board.gd 会输出 clear_events，每个事件包含颜色、数量、级联层数；BattleManager.gd 负责回合、伤害、状态和胜负；GameManager.gd 负责局内数据和结局统计。MVP 改造不需要先重写工程架构。",
    )
    add_table(
        doc,
        ["现有模块", "可复用内容", "需要新增/调整"],
        [
            ["Board.gd", "交换、匹配、连消、clear_events。", "在 clear_events 中补充本回合顺序索引、是否由玩家主动交换触发。"],
            ["BattleManager.gd", "步数、敌人行动、伤害、燃烧、冻结、护盾。", "新增 SpectrumManager，监听消除事件并触发色谱。"],
            ["GameManager.gd", "金币、颜色偏好、颜色使用统计、关卡数据。", "新增牌组、弃谱堆、颜料、色谱升级与染色数据。"],
            ["Main.gd", "战斗 UI、技能按钮区、奖励界面。", "把技能按钮区改为 3 张当前色谱卡位；奖励界面改为三选一构筑奖励。"],
            ["Enemy.gd", "HP、攻击、状态。", "新增 intent 字段、抗性、污染能力。"],
        ],
        [1.25, 2.35, 2.9],
    )

    doc.add_heading("9. MVP 范围建议", level=1)
    add_para(
        doc,
        "第一版不要直接做 8 色和大量遗物。推荐用最小闭环验证“色谱条件驱动三消规划”是否成立。",
    )
    add_table(
        doc,
        ["内容", "MVP 数量", "验收标准"],
        [
            ["颜色", "灰、红、蓝、金 4 色", "每种颜色有清晰战斗定位。"],
            ["色谱", "12 张", "每回合抽 3 张，至少 70% 回合可完成 1 张以上。"],
            ["敌人", "3 个", "至少包含攻击、蓄力、污染三类意图。"],
            ["奖励", "战后 3 选 1", "候选包含新谱、升级、染色或删谱。"],
            ["商店", "1 个节点", "可购买、升级、删谱、治疗。"],
            ["结局", "平衡者、单色魔王、灰蚀失败 3 类", "颜色倾向和灰蚀压力能影响结局文本。"],
        ],
        [1.1, 1.15, 4.25],
    )

    doc.add_heading("10. 风险与调节旋钮", level=1)
    add_table(
        doc,
        ["风险", "表现", "调节旋钮"],
        [
            ["目标过多导致阅读压力", "玩家每回合看不懂 3 张色谱。", "卡面只显示条件、效果、颜色；起始色谱条件保持短句。"],
            ["随机棋盘导致色谱难完成", "玩家抽到红谱但棋盘几乎无红。", "允许保留 1 张；奖励可改变颜色权重；基础伤害保底。"],
            ["单色 Build 滚雪球", "只走红色伤害即可通关。", "敌人临时抗性、结局代价、混色奖励、颜料成本。"],
            ["经济流过强", "金色买空商店，构筑失控。", "商店价格递增，金色收益软上限，金币不能直接买胜利。"],
            ["连消过强", "随机级联无脑触发大量色谱。", "同名色谱每回合最多触发 1 次，抽牌和返步设置上限。"],
        ],
        [1.4, 2.25, 2.85],
    )

    doc.add_heading("11. 最终结论", level=1)
    add_para(
        doc,
        "色谱系统可以跑通，因为它没有把三消和卡牌拆成两个互相争夺注意力的系统，而是把卡牌转化为三消目标。玩家的输入仍然是交换色块；色谱负责解释为什么这一回合要消红、消蓝、追连消或保留金色。资源循环上，步数提供压力，消除事件提供输入，色谱提供目标，金币和颜料提供成长，颜色倾向提供叙事反馈，敌人意图提供反制需求。",
    )
    add_callout(
        doc,
        "推荐下一步",
        "先实现 12 张色谱 + 3 个敌人意图 + 战后三选一奖励，验证每场战斗是否能稳定产生“看目标、规划三步、完成色谱、改变构筑”的体验。验证通过后，再扩展到 8 色、遗物、事件和分支地图。",
        GOLD_FILL,
    )

    doc.save(OUT_DOCX)
    print(OUT_DOCX)


if __name__ == "__main__":
    build_doc()
