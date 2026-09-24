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
OUT_DOCX = OUT_DIR / "色彩勇者_游戏总策划案.docx"

TITLE = "《色彩勇者：三消镇魂曲》游戏总策划案"
SUBTITLE = "正式 1.0 规格 | 三消目标契约 × 色谱构筑 Roguelite"
TODAY = date(2026, 7, 26)

BLUE = RGBColor(0x2E, 0x74, 0xB5)
DARK_BLUE = RGBColor(0x1F, 0x4D, 0x78)
NAVY = RGBColor(0x0B, 0x25, 0x45)
INK = RGBColor(0x22, 0x22, 0x22)
MUTED = RGBColor(0x66, 0x66, 0x66)
HEADER_FILL = "E8EEF5"
LIGHT_FILL = "F4F6F9"
GREEN_FILL = "E2F0D9"
GOLD_FILL = "FFF2CC"
RED_FILL = "FCE4D6"
BLUE_FILL = "DDEBF7"
GRAY_FILL = "F2F2F2"


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
    section.top_margin = Inches(1.0)
    section.bottom_margin = Inches(1.0)
    section.left_margin = Inches(1.0)
    section.right_margin = Inches(1.0)
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

    header = section.header.paragraphs[0]
    header.text = ""
    header.paragraph_format.space_after = Pt(0)
    run = header.add_run("色彩勇者：三消镇魂曲 | 1.0 游戏总策划案")
    set_run_font(run, 9, MUTED)

    footer = section.footer.paragraphs[0]
    footer.text = ""
    footer.alignment = WD_ALIGN_PARAGRAPH.CENTER
    run = footer.add_run("内部策划规格 | 2026-07-26")
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


def set_cell_text(cell, text, bold=False, color=INK, size=8.8, align=None) -> None:
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


def prevent_row_split(row) -> None:
    tr_pr = row._tr.get_or_add_trPr()
    cant_split = tr_pr.find(qn("w:cantSplit"))
    if cant_split is None:
        cant_split = OxmlElement("w:cantSplit")
        tr_pr.append(cant_split)
    cant_split.set(qn("w:val"), "true")


def add_table(doc, headers, rows, widths, header_fill=HEADER_FILL, body_fill=None, font_size=8.6):
    table = doc.add_table(rows=1, cols=len(headers))
    table.style = "Table Grid"
    set_table_geometry(table, widths)
    mark_header_repeat(table)
    prevent_row_split(table.rows[0])
    for i, header in enumerate(headers):
        shade_cell(table.rows[0].cells[i], header_fill)
        set_cell_text(table.rows[0].cells[i], header, bold=True, color=DARK_BLUE, size=8.8)
    for row_data in rows:
        if len(row_data) != len(headers):
            raise ValueError(f"table row has {len(row_data)} cells; expected {len(headers)}: {row_data}")
        row = table.add_row()
        prevent_row_split(row)
        for i, text in enumerate(row_data):
            cell = row.cells[i]
            if body_fill:
                shade_cell(cell, body_fill)
            align = WD_ALIGN_PARAGRAPH.CENTER if len(str(text)) <= 8 else None
            set_cell_text(cell, text, size=font_size, align=align)
    p = doc.add_paragraph()
    p.paragraph_format.space_after = Pt(2)
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
    set_table_geometry(table, [6.5], indent_dxa=160)
    mark_header_repeat(table)
    prevent_row_split(table.rows[0])
    cell = table.rows[0].cells[0]
    shade_cell(cell, fill)
    set_cell_margins(cell, top=120, bottom=120, start=160, end=160)
    cell.text = ""
    p = cell.paragraphs[0]
    p.paragraph_format.space_after = Pt(3)
    r = p.add_run(title)
    set_run_font(r, 10.2, DARK_BLUE, True)
    p2 = cell.add_paragraph()
    p2.paragraph_format.space_after = Pt(0)
    p2.paragraph_format.line_spacing = 1.15
    r2 = p2.add_run(body)
    set_run_font(r2, 9.4, INK)
    doc.add_paragraph()


def add_metadata_rows(doc, rows) -> None:
    table = doc.add_table(rows=len(rows), cols=2)
    table.style = "Table Grid"
    set_table_geometry(table, [1.35, 5.15])
    mark_header_repeat(table)
    for row, (label, value) in zip(table.rows, rows):
        prevent_row_split(row)
        shade_cell(row.cells[0], HEADER_FILL)
        set_cell_text(row.cells[0], label, bold=True, color=DARK_BLUE, size=9)
        set_cell_text(row.cells[1], value, size=9)
    doc.add_paragraph()


def build_doc() -> None:
    doc = Document()
    configure_document(doc)

    add_para(doc, "GAME DESIGN DOCUMENT", size=9.5, color=BLUE, bold=True, align=WD_ALIGN_PARAGRAPH.CENTER)
    title = doc.add_paragraph()
    title.alignment = WD_ALIGN_PARAGRAPH.CENTER
    title.paragraph_format.space_before = Pt(10)
    title.paragraph_format.space_after = Pt(4)
    title.paragraph_format.line_spacing = 1.05
    run = title.add_run("《色彩勇者：三消镇魂曲》")
    set_run_font(run, 22, NAVY, True)
    run.add_break()
    run = title.add_run("游戏总策划案")
    set_run_font(run, 22, NAVY, True)
    subtitle = doc.add_paragraph()
    subtitle.alignment = WD_ALIGN_PARAGRAPH.CENTER
    subtitle.paragraph_format.space_after = Pt(14)
    run = subtitle.add_run(SUBTITLE)
    set_run_font(run, 12, MUTED)

    add_metadata_rows(
        doc,
        [
            ("项目版本", "正式 1.0 范围定义，覆盖完整三章与发布验收"),
            ("目标单局", "60-90 分钟；3 章 24 层（每章 8 层）；每局约 24 个实际节点"),
            ("内容规模", "36 张色谱、24 件遗物、18 名普通敌人、6 名精英、3 名 Boss、12 个事件、3 套起始流派"),
            ("难度结构", "普通难度 + 进阶 1-5，新局可选，推荐依次挑战"),
            ("核心约束", "棋盘仅红/蓝/金/灰；白/黑/混色仅为色谱主题，不生成棋盘块"),
            ("生成日期", TODAY.isoformat()),
        ],
    )
    add_callout(
        doc,
        "1.0 核心结论",
        "《色彩勇者》1.0 应被定义为“以三消完成战术契约”的 Roguelite RPG。色谱不是手牌技能按钮，而是每回合悬挂在棋盘旁的目标契约；玩家通过 3 步三消完成条件，系统自动触发攻击、防御、经济、净化和构筑效果。所有长期内容都围绕“我下一回合想消什么，以及为什么”展开。",
        GREEN_FILL,
    )

    doc.add_heading("目录", level=1)
    add_bullets(
        doc,
        [
            "1. 产品定位",
            "2. 目标人群",
            "3. 1.0 范围总览",
            "4. 核心循环",
            "5. 棋盘与战斗系统",
            "6. 色谱系统",
            "7. 起始流派与构筑深度",
            "8. 敌人与章节结构",
            "9. 事件、遗物与奖励",
            "10. 经济系统",
            "11. 元进度与进阶难度",
            "12. UI/UX",
            "13. 视听方向",
            "14. 技术与数据落地",
            "15. 商业化边界、验收与里程碑",
        ],
    )

    doc.add_heading("1. 产品定位", level=1)
    add_para(
        doc,
        "本作是一款单人买断制 Roguelite 三消 RPG。它用三消提供低门槛操作和即时爽感，用敌人意图提供回合压力，用色谱契约提供构筑目标，用路线、遗物、事件和元进度提供长线复玩。1.0 不追求传统卡牌游戏的抽牌、费用、手动打出，而是把卡牌语言翻译成“棋盘目标”：卡在旁边，玩家在棋盘上完成它。",
    )
    add_table(
        doc,
        ["定位项", "1.0 定义", "落地要求"],
        [
            ["类型", "三消目标契约 + 回合制 RPG + Roguelite 构筑", "玩家主要操作永远是交换棋盘色块。"],
            ["局长", "60-90 分钟", "3 章，每章约 8 个实际节点；失败后可快速重开。"],
            ["平台", "PC 首发，后续移动/Switch 可行", "UI 必须支持鼠标点击与触屏拖拽。"],
            ["售价", "买断制独立游戏", "不得依赖抽卡、体力、付费数值加速。"],
            ["美术", "像素 RPG + 颜色污染/复苏主题", "可读性优先，色块要兼顾色弱识别。"],
        ],
        [1.0, 2.2, 3.3],
    )
    add_table(
        doc,
        ["设计支柱", "含义", "验收问题"],
        [
            ["棋盘即战术", "每次交换同时影响伤害、色谱进度、颜色倾向和敌人反制。", "玩家是否能说出“这一步是为了哪张色谱”？"],
            ["目标契约", "色谱定义目标，不是被点击打出的牌。", "玩家是否把色谱理解为待完成任务，而非技能按钮？"],
            ["构筑改变棋盘目标", "奖励改变下一场战斗想消的颜色、顺序和连消目标。", "拿奖励后，玩家的操作优先级是否变化？"],
            ["透明压力", "敌人意图、污染、抗性、路线风险提前展示。", "失败是否可复盘，而不是归因于纯随机？"],
        ],
        [1.2, 2.8, 2.5],
        header_fill=BLUE_FILL,
    )

    doc.add_heading("2. 目标人群", level=1)
    add_para(
        doc,
        "1.0 的目标不是传统免费三消大盘，而是“愿意在轻操作里做深选择”的付费玩家。三消降低理解门槛，Roguelite 构筑提高复玩上限；两者必须围绕同一目标契约融合。",
    )
    add_table(
        doc,
        ["人群", "画像", "吸引点", "风险"],
        [
            ["核心构筑玩家", "玩过杀戮尖塔、怪物火车、背包英雄", "路线风险、遗物组合、敌人意图、Build 成型", "若三消过随机，会质疑策略深度。"],
            ["轻策略玩家", "喜欢回合制、解谜、轻卡牌", "每回合目标清楚，规则渐进", "若卡面术语过多，会早期流失。"],
            ["三消玩家", "熟悉交换、连消、目标关卡", "消除反馈密集，色彩变化直观", "若失败惩罚太硬，会降低接受度。"],
            ["剧情/收集玩家", "喜欢多结局、图鉴、角色成长", "颜色倾向、事件分支、元进度解锁", "若叙事只停留在结算文本，会失望。"],
        ],
        [1.15, 1.65, 2.05, 1.65],
    )
    add_table(
        doc,
        ["市场表达", "文案"],
        [
            ["一句话", "用三消完成战术契约，在红、蓝、金与灰的世界里构筑你的色谱流派。"],
            ["Steam 短描述", "每回合只有 3 步。看清敌人意图，规划棋盘消除，完成色谱目标，打造红焰爆发、蓝霜控制、金辉运营或灰蚀转化流派。"],
            ["玩家承诺", "没有传统出牌费用，也没有抽卡付费；你做的每一次交换，都是战斗、构筑和结局的一部分。"],
        ],
        [1.4, 5.1],
        header_fill=GOLD_FILL,
    )

    doc.add_heading("3. 1.0 范围总览", level=1)
    add_para(
        doc,
        "1.0 按完整付费单机规格设计：单局 60-90 分钟，3 章 24 层，每章 8 层，每局约 24 个实际节点。节点指玩家实际进入并完成的节点，不等于地图上所有可见节点；地图每章应展示 14-18 个候选节点，玩家每层选择并实际经历 1 个节点。",
    )
    add_table(
        doc,
        ["模块", "1.0 数量", "范围说明"],
        [
            ["章节/层数", "3 章 / 24 层", "灰雾边境、镜湖工坊、无色王庭；每章固定 8 层。"],
            ["实际节点", "约 24/局", "每章完成 8 层；普通、精英、事件、商店与营火构成取决于合法路线，末层固定 Boss。"],
            ["色谱", "36 张", "红 8、蓝 8、金 8、灰 6、主题谱 6（白 1、黑 1、混色 4）；主题不进入棋盘。"],
            ["遗物", "24 件", "普通 12、稀有 9、Boss/特殊 3。"],
            ["普通敌人", "18 名", "每章 6 名，覆盖颜色和机制教学。"],
            ["精英敌人", "6 名", "每章 2 名，高风险高收益。"],
            ["Boss", "3 名", "每章 1 名，检验章节机制。"],
            ["事件", "12 个", "每章 4 个，含代价、染色、删谱、诅咒、路线转换。"],
            ["起始流派", "3 套", "红焰勇者、蓝霜守卫、金辉旅商。"],
            ["进阶难度", "普通 + 进阶 1-5", "新局可直接选择；推荐逐级挑战，规则按等级累积。"],
        ],
        [1.15, 1.0, 4.35],
        font_size=8.5,
    )
    add_table(
        doc,
        ["章节", "主题", "新增压力", "Boss 检验"],
        [
            ["第 1 章：灰雾边境", "学习四基础颜色与目标契约", "污染、基础攻击、少量抗性", "灰蚀龙检验净化与混色。"],
            ["第 2 章：镜湖工坊", "护盾、燃烧、经济与抗性轮换", "偷金币、护盾、主色抗性、蓄力恢复", "镜湖乐监检验切色与打断节奏。"],
            ["第 3 章：无色王庭", "终局高压与构筑完整性", "高污染、主色抗性、连续蓄力", "无色王检验构筑弹性与死局恢复。"],
        ],
        [1.45, 1.6, 1.65, 1.8],
        header_fill=BLUE_FILL,
    )

    doc.add_heading("4. 核心循环", level=1)
    add_callout(
        doc,
        "主循环",
        "路线选择 -> 战斗开局抽 3 张色谱 -> 观察敌人意图与棋盘 -> 用 3 步三消完成目标契约 -> 自动触发色谱效果 -> 敌人行动 -> 战后获得构筑奖励 -> 进入下一节点。",
        BLUE_FILL,
    )
    doc.add_heading("4.1 战斗内循环", level=2)
    add_numbers(
        doc,
        [
            "回合开始：抽 3 张色谱；若有保留槽，先带入保留色谱再补抽。",
            "观察：敌人显示下次意图，色谱显示目标、进度、完成效果和限制。",
            "行动：玩家进行最多 3 次有效交换；无效交换回退且不消耗步数。",
            "结算：每次消除先产生基础伤害，再推进色谱进度；条件满足即自动触发。",
            "级联：下落产生的连消也能推进大部分色谱，但部分色谱要求主动交换触发。",
            "收束：同一个色谱实例每回合最多触发 1 次；重复同名色谱按实例分别计算。",
            "回合末：可保留 1 张未完成色谱，其余弃置；敌人按意图行动。",
        ],
    )
    doc.add_heading("4.2 局内成长循环", level=2)
    add_table(
        doc,
        ["时间点", "玩家决策", "长期影响"],
        [
            ["起始", "选择 1 套起始流派", "决定初始牌组、遗物和颜色倾向。"],
            ["普通战后", "新色谱 / 升级 / 颜料 / 跳过金币", "扩牌、强化或保持牌组精简。"],
            ["精英战后", "遗物 + 高稀有奖励", "获得规则改写能力。"],
            ["事件", "用 HP、金币、灰蚀或诅咒换收益", "改变路线风险和构筑方向。"],
            ["商店", "买谱、升级、删谱、治疗、染色", "把金币转化为稳定性或爆发力。"],
            ["营火", "治疗、升级、净化、侦察 Boss", "在生存与强度之间取舍。"],
        ],
        [1.05, 2.2, 3.25],
    )

    doc.add_heading("5. 棋盘与战斗系统", level=1)
    add_para(
        doc,
        "1.0 棋盘仅保留红、蓝、金、灰四种基础色。这是冻结的数据契约：完整版的深度来自 36 张色谱、敌人意图、遗物和路线，而不是堆叠更多棋盘颜色。白、黑、混色只能作为色谱主题标签；它们不能进入棋盘生成、换色、掉落权重、匹配目标或敌人抗性枚举。",
    )
    add_callout(
        doc,
        "四色与主题数据契约",
        "board_color 仅允许 red / blue / gold / gray。theme_tags 可使用 white / black / mixed：白主题表达净化与校准，黑主题表达代价与约束，混色主题要求组合两种及以上合法棋盘色；三者均不对应可生成、可交换或可消除的第五种棋盘块。",
        RED_FILL,
    )
    add_table(
        doc,
        ["规则", "1.0 标准"],
        [
            ["棋盘", "7×7，相邻正交交换，横/竖 3 连及以上消除。"],
            ["步数", "每玩家回合 3 步；返还步数效果每回合最多 1 次，回合上限 4 步。"],
            ["基础伤害", "10 × 数量倍率 × 级联倍率；红色基础伤害 ×1.50。"],
            ["数量倍率", "3 个 =1.0；4 个 =1.5；5 个 =2.5；6 个以上 =4.0。"],
            ["级联倍率", "1 + (cascade - 1) ×0.35；按实际级联层数计算。"],
            ["无解保护", "棋盘无可行动作时自动重排；重排不改变当前色谱进度。"],
            ["污染", "敌人或事件将非灰块转灰；污染不能直接制造无解。"],
            ["净化", "把灰块转为随机玩家颜色，或按色谱指定转红/蓝/金。"],
        ],
        [1.3, 5.2],
    )
    add_table(
        doc,
        ["颜色", "基础战斗定位", "资源/状态", "反制方式"],
        [
            ["红", "爆发伤害、燃烧", "燃烧层数，上限 4 层", "敌人红抗、反伤、需要蓝盾保护。"],
            ["蓝", "护盾、冻结、打断", "护盾、冻结、打断蓄力", "敌人蓝抗、净化冻结、护盾削减。"],
            ["金", "金币、折扣、商店运营", "金币、折扣、购买力", "偷金币、金抗、收益软上限。"],
            ["灰", "污染、基础、转化材料", "灰蚀压力、净化目标", "灰转收益、净化、混色谱。"],
        ],
        [0.65, 1.65, 1.45, 2.75],
        font_size=8.8,
    )
    add_table(
        doc,
        ["战斗类型", "目标回合数", "HP 区间", "攻击区间", "用途"],
        [
            ["普通战", "3-9 回合", "84-310", "10-28", "按章节递增，提供奖励与机制教学。"],
            ["精英战", "5-12 回合", "148-395", "16-32", "按章节递增，检验 Build 并奖励遗物。"],
            ["Boss 战", "7-14 回合", "280-680", "22-36", "检验章节机制和构筑弹性。"],
        ],
        [1.0, 1.0, 1.0, 1.0, 2.5],
        header_fill=GOLD_FILL,
    )

    doc.add_heading("6. 色谱系统", level=1)
    add_para(
        doc,
        "色谱是“目标契约”，不是传统手牌。色谱可以看起来像卡牌，但玩家不支付费用、不点击打出、不选择目标。玩家只通过三消推进目标，满足后自动触发。为了支持重复同名色谱，1.0 必须采用色谱实例 UID：牌组中每一张都是独立实例，升级、保留、触发、删除都按 UID 处理；图鉴和规则文本按谱系 ID 读取。",
    )
    add_table(
        doc,
        ["字段", "定义", "示例"],
        [
            ["uid", "单张实例身份", "run_card_014"],
            ["spec_id", "色谱模板", "ember_slash"],
            ["trigger_colors", "可读取的棋盘色", "red / blue / gold / gray"],
            ["theme_tags", "不生成棋盘块的主题", "white / black / mixed / burn / freeze"],
            ["condition", "目标条件", "本回合累计红 >=5"],
            ["progress", "实时进度", "红 3/5"],
            ["effect", "完成效果", "造成 18 伤害，燃烧 +2"],
            ["limit", "限制", "每实例每回合 1 次；部分要求主动消除"],
            ["upgrade", "升级层级", "0 或 1；高难可开放 +2 变体"],
        ],
        [0.95, 2.35, 3.2],
        font_size=8.6,
    )
    add_table(
        doc,
        ["规则", "1.0 标准"],
        [
            ["抽取", "每回合抽至 3 张色谱；保留色谱先进入手牌再补抽。"],
            ["保留", "基础保留 1 张未完成色谱；Boss/遗物可临时提高到 2。"],
            ["触发", "同一实例每回合最多触发 1 次；同名不同实例可分别触发。"],
            ["重复上限", "普通同名最多 2 张；稀有同名最多 1 张；诅咒不受上限但有代价。"],
            ["升级", "每张最多 +1；升级要么降低条件，要么增加效果，不只改文案。"],
            ["删谱", "牌组低于 8 张时禁止继续删；删谱优先服务稳定性。"],
            ["跳过奖励", "跳过新色谱给 10 金币或 1 颜料，避免牌组膨胀。"],
        ],
        [1.25, 5.25],
    )
    doc.add_heading("6.1 36 张 1.0 色谱清单", level=2)
    spectra_rows = [
        ["余烬斩", "红", "普通", "本回合累计红 >=5", "18 伤害，燃烧 +2"],
        ["燎原", "红", "普通", "主动红 4 连+", "2 个灰块染红"],
        ["赤潮回响", "红", "稀有", "本回合 2 次红消", "追加本步基础伤害 40%"],
        ["火线突进", "红", "普通", "红消后仍剩 1 步", "12 伤害，下一红条件 -1"],
        ["余温护身", "红", "普通", "敌人燃烧时消红", "获得 8 护盾"],
        ["熔核终止", "红", "稀有", "本回合完成 2 张红谱", "35 伤害，燃烧翻倍至上限"],
        ["血色契约", "红", "稀有", "HP 低于 50% 时消红", "失去 3 HP，造成 30 伤害"],
        ["炎冠审判", "红", "史诗", "红 5 连或三级联", "60 伤害，敌人下回合红抗 +25%"],
        ["凝霜格", "蓝", "普通", "蓝 4 连或两次蓝消", "获得 14 护盾"],
        ["冰封休止", "蓝", "稀有", "先消蓝，再消非蓝", "打断蓄力，否则 65% 冻结"],
        ["镜湖回避", "蓝", "普通", "本回合未受伤且消蓝", "下次伤害 -10"],
        ["霜线规划", "蓝", "普通", "主动蓝消后触发级联", "抽 1 张，若未完成则保留槽 +1"],
        ["冷光护墙", "蓝", "普通", "累计蓝 >=6", "获得 20 护盾"],
        ["静滞封印", "蓝", "稀有", "敌人攻击意图时消蓝", "冻结 1，护盾 +8"],
        ["反射棱冰", "蓝", "稀有", "护盾存在时完成任意色谱", "对敌造成当前护盾 60% 伤害"],
        ["零度终幕", "蓝", "史诗", "连续两回合完成蓝谱", "敌人跳过下次非 Boss 行动"],
        ["点金拍", "金", "普通", "金 >=3 且已完成任一色谱", "+8 金币，金收益 +50%"],
        ["债券折光", "金", "稀有", "本回合未受伤且消金", "下次商店升级 -20%"],
        ["商队节拍", "金", "普通", "主动金 4 连", "+12 金币"],
        ["余款回响", "金", "普通", "跳过一张奖励后下场消金", "+1 颜料，+6 金币"],
        ["镀金护符", "金", "普通", "累计金 >=5", "获得金币等量护盾，上限 16"],
        ["套利连奏", "金", "稀有", "同回合完成金谱与非金谱", "抽 1 张，商店刷新免费 1 次"],
        ["王币指令", "金", "稀有", "金币 >=80 时消金", "消耗 20 金币，造成 45 伤害"],
        ["黄金终章", "金", "史诗", "本场战斗获得金币 >=24", "获得遗物购买折扣，本回合金币封顶解除"],
        ["灰烬炼金", "灰", "稀有", "先消灰，再消金", "灰消除量转为金币与护盾"],
        ["破雾短句", "灰", "普通", "累计灰 >=6", "净化 2 个灰块"],
        ["灰刃", "灰", "普通", "主动灰 4 连", "20 伤害，灰蚀压力 -1"],
        ["雾中取色", "灰", "普通", "灰消后再消玩家色", "+1 颜料"],
        ["残响石碑", "灰", "稀有", "敌人污染后完成色谱", "净化 3 格并抽 1 张"],
        ["灰王契约", "灰", "史诗", "灰蚀压力 >=8", "造成压力×8 伤害，压力清零一半"],
        ["调色练习", "混色主题", "普通", "同回合消除 2 种合法颜色", "+1 颜料，净化 1 个灰块"],
        ["镇魂短句", "混色主题", "普通", "触发 2 层以上级联", "12 伤害，抽 1 张"],
        ["白昼校准", "白主题", "稀有", "完成 2 张不同合法色谱", "清除 1 负面，回复 5 HP"],
        ["棱镜协奏", "混色主题", "稀有", "红蓝金各消一次", "三色效果各触发一次低配版"],
        ["无色停顿", "黑主题", "普通", "本回合不完成同色第二张", "获得 10 护盾，抽 1 张"],
        ["终曲变奏", "混色主题", "史诗", "本回合完成 3 张色谱", "造成 50 伤害，获得 2 颜料"],
    ]
    assert len(spectra_rows) == 36, "frozen 1.0 scope requires exactly 36 collectible spectra"
    assert sum(row[1] == "白主题" for row in spectra_rows) == 1
    assert sum(row[1] == "黑主题" for row in spectra_rows) == 1
    assert sum(row[1] == "混色主题" for row in spectra_rows) == 4
    add_table(doc, ["色谱", "触发/主题", "稀有", "目标契约", "完成效果"], spectra_rows, [1.0, 0.8, 0.65, 2.05, 2.0], font_size=7.25)

    doc.add_heading("7. 起始流派与构筑深度", level=1)
    add_para(
        doc,
        "1.0 提供 3 套起始流派，让新玩家在第一局前就知道自己要尝试什么。每套流派提供 8 张起始牌、1 件起始遗物和一个路线偏好，但仍保留通过奖励转向的空间。",
    )
    add_table(
        doc,
        ["流派", "起始牌组", "起始遗物", "玩法承诺", "弱点"],
        [
            ["红焰勇者", "余烬斩×2、火线突进、余温护身、凝霜格、点金拍、调色练习、镇魂短句", "余温护符", "快速击杀，用燃烧和红色条件制造爆发。", "缺护盾时 HP 压力大，怕红抗。"],
            ["蓝霜守卫", "凝霜格×2、冰封休止、镜湖回避、余烬斩、点金拍、破雾短句、镇魂短句", "冻裂怀表", "看敌人意图，打断蓄力，用护盾稳定推进。", "伤害成型慢，怕偷金币和净化护盾。"],
            ["金辉旅商", "点金拍×2、商队节拍、镀金护符、余烬斩、凝霜格、灰烬炼金、调色练习", "商会印章", "用金币买强度，删谱和升级形成高稳定牌组。", "前期伤害低，怕偷金币和收益封顶。"],
        ],
        [0.85, 2.15, 0.9, 1.3, 1.3],
        font_size=7.6,
    )
    add_table(
        doc,
        ["构筑轴", "核心选择", "成型标志", "反制"],
        [
            ["单色强化", "大量同色谱 + 提高棋盘权重", "每回合能稳定完成 1-2 张同色谱", "敌人抗性、Boss 主色反制。"],
            ["混色弹性", "跨色谱、保留、抽牌、净化", "能根据敌人意图切换目标", "单回合爆发不足。"],
            ["薄牌组", "删谱、升级核心、少拿新谱", "抽到核心谱概率高", "污染/诅咒会明显扰乱。"],
            ["厚牌组", "多拿谱、抽牌遗物、事件奖励", "选择面广，适应敌人多", "核心成型慢，回合目标发散。"],
            ["经济运营", "金谱、商店、折扣、删谱", "金币转化为升级/遗物/治疗", "金币上限、偷金币、低输出。"],
        ],
        [1.15, 1.7, 2.1, 1.55],
    )

    doc.add_heading("8. 敌人与章节结构", level=1)
    add_table(
        doc,
        ["章节", "实际节点结构", "普通敌", "精英", "Boss"],
        [
            ["第 1 章", "8 层：6 个前置节点 + 1 营火 + 1 Boss", "灰雾学徒、褪色犬群、镀金盗贼、霜痕哨兵、灰烬搬运工、织雾小队", "霜甲卫士、猩红祭司", "灰蚀龙"],
            ["第 2 章", "8 层：6 个前置节点 + 1 营火 + 1 Boss", "镜潮信使、熔彩矿工、税契偶师、寒潮祭钟、棱镜猎手、灰玻工匠", "镜湖执法官、熔炉双生", "镜湖乐监"],
            ["第 3 章", "8 层：6 个前置节点 + 1 营火 + 1 Boss", "王庭司墨、断谱骑士、鎏金审计官、静滞唱诗班、黑曜抄写员、四色行刑台", "无色近卫、终曲指挥家", "无色王"],
        ],
        [0.7, 1.5, 2.2, 1.25, 0.85],
        font_size=7.5,
    )
    add_table(
        doc,
        ["普通敌", "章", "机制标签", "设计目的"],
        [
            ["灰雾学徒", "1", "攻击/污染", "基础教学。"],
            ["褪色犬群", "1", "连续攻击/污染", "基础承伤压力。"],
            ["镀金盗贼", "1", "偷金币/金抗", "经济与切色教学。"],
            ["霜痕哨兵", "1", "蓄力/重击", "冻结打断教学。"],
            ["灰烬搬运工", "1", "护盾/污染", "破盾与净化组合。"],
            ["织雾小队", "1", "连续污染", "Boss 前污染预演。"],
            ["镜潮信使", "2", "攻击/护盾", "第二章防守节拍入口。"],
            ["熔彩矿工", "2", "燃烧/蓄力", "持续伤害与打断。"],
            ["税契偶师", "2", "偷金币/护盾", "经济持有风险。"],
            ["寒潮祭钟", "2", "护盾/蓄力", "固定节拍规划。"],
            ["棱镜猎手", "2", "红蓝抗性轮换", "混色与切色。"],
            ["灰玻工匠", "2", "污染/护盾", "Boss 前复合检验。"],
            ["王庭司墨", "3", "污染/主色抗性", "终章压力入口。"],
            ["断谱骑士", "3", "连续攻击/重击", "即时防御检查。"],
            ["鎏金审计官", "3", "偷金币/护盾", "终局经济检查。"],
            ["静滞唱诗班", "3", "护盾/蓄力", "固定节拍打断。"],
            ["黑曜抄写员", "3", "污染/燃烧", "复合状态压力。"],
            ["四色行刑台", "3", "主色抗性/护盾", "最终 Boss 机制预演。"],
        ],
        [1.15, 0.45, 1.55, 3.35],
        font_size=7.5,
    )
    add_table(
        doc,
        ["精英/Boss", "类型", "机制", "奖励定位"],
        [
            ["霜甲卫士", "精英", "防御、蓄力、蓝抗", "蓝谱与打断遗物。"],
            ["猩红祭司", "精英", "玩家燃烧、回血", "红谱与自伤收益。"],
            ["镜湖执法官", "精英", "高护盾、主色抗性、蓄力", "切色与打断奖励。"],
            ["熔炉双生", "精英", "燃烧、偷金币、回复", "红金构筑修正。"],
            ["无色近卫", "精英", "高护盾、高抗性、重击", "混色与净化奖励。"],
            ["终曲指挥家", "精英", "攻击、污染、回复、重击", "成型构筑总检验。"],
            ["灰蚀龙", "Boss", "污染、主色抗性、攻击与蓄力重击五拍循环", "第 1 章净化与打断检验。"],
            ["镜湖乐监", "Boss", "主色抗性、护盾、蓄力、重击、回复循环", "第 2 章切色与打断检验。"],
            ["无色王", "Boss", "主色抗性、污染、护盾与 62 点重击", "第 3 章最终综合检验。"],
        ],
        [1.1, 0.75, 2.55, 2.1],
        font_size=7.7,
    )

    doc.add_heading("9. 事件、遗物与奖励", level=1)
    add_table(
        doc,
        ["事件", "章节", "选择 A", "选择 B", "设计目的"],
        [
            ["褪色神龛", "1", "-8 HP，净化 1 张", "+1 颜料，下战污染 +2", "HP 与牌组质量。"],
            ["流浪调色师", "1", "35 金币 +1 颜料：染色", "跳过：+12 金币", "颜色流派。"],
            ["破碎画廊", "1", "稀有遗物 + 黑曜契约", "回复 20 HP", "高风险遗物。"],
            ["颜料井", "1", "-6 HP，获得 2 颜料", "封井，获得 18 金币", "资源转换。"],
            ["冰封谱库", "2", "蓝色色谱，灰蚀压力 +1", "回复 24 HP", "构筑与生存。"],
            ["静默拍卖", "2", "65 金币买稀有遗物", "卖 1 颜料得 32 金币", "金币用途。"],
            ["镜湖倒影", "2", "回复 18 HP，灰蚀压力 +2", "混色色谱 +1 颜料", "灰蚀与构筑。"],
            ["商队旧债", "2", "55 金币 + 黑曜契约", "30 金币换 2 颜料", "即时经济与长期代价。"],
            ["猩红舞台", "3", "-12 HP，获得红色稀有谱", "回复 26 HP", "爆发与生存。"],
            ["无名画廊", "3", "灰蚀压力 +3，获得稀有遗物", "离开并获得 24 金币", "终局风险。"],
            ["终幕工坊", "3", "最大 HP -8，获得终幕花冠", "回复 35 HP", "终局校准。"],
            ["合唱残响", "3", "混色色谱 +1 颜料", "获得 40 金币", "Boss 前补缺。"],
        ],
        [1.0, 0.5, 1.75, 1.75, 1.5],
        font_size=7.2,
    )
    doc.add_heading("9.1 24 件遗物清单", level=2)
    relic_rows = [
        ["裂色棱镜", "普通", "每场首次完成混色谱时抽 1 张", "混色"],
        ["余温护符", "普通", "燃烧 3 层以上结算时获得 4 护盾", "红蓝"],
        ["破雾铃", "普通", "每场首次污染后净化 1 格并 +1 颜料", "净化"],
        ["冻裂怀表", "稀有", "打断蓄力后返还 1 步，每场 1 次", "蓝"],
        ["商会印章", "稀有", "首次删谱半价，金收益软上限 +20%", "金"],
        ["灰烬花盆", "稀有", "污染后 30% 把 1 灰转可用色", "灰"],
        ["镇门旧徽", "普通", "Boss 前营火额外显示侦察", "路线"],
        ["无色冠冕", "Boss", "每回合额外保留 1 张，Boss 抗性 +10%", "稳定"],
        ["红釉剑柄", "普通", "主动红 4 连额外 +6 伤害", "红"],
        ["蓝纹披肩", "普通", "回合末若有护盾，保留 3 点到下回合", "蓝"],
        ["金账本", "普通", "每 3 次购买后获得 1 颜料", "金"],
        ["灰石酒杯", "普通", "消灰时有 20% 回复 1 HP", "灰"],
        ["熔火戒", "稀有", "红谱升级后第一次触发追加燃烧 +1", "红"],
        ["静湖印", "稀有", "冻结敌人时抽 1 张，每场最多 2 次", "蓝"],
        ["镀金钥匙", "稀有", "宝箱可选择金币或遗物", "路线"],
        ["净白羽", "稀有", "每章第一次灰蚀压力达到 6 时清 3 点", "净化"],
        ["黑曜杯", "稀有", "每场第一次自伤效果翻倍收益", "黑曜主题"],
        ["彩线轴", "普通", "同回合三色消除时 +5 护盾", "混色"],
        ["旧乐谱", "普通", "镇魂短句类效果 +4 伤害", "连消"],
        ["旅商铃", "普通", "商店多展示 1 件商品", "经济"],
        ["残破王旗", "Boss", "每章 Boss 后选择 1 张色谱复制或升级", "成长"],
        ["四色骰", "稀有", "每回合第一张色谱条件随机 -1", "泛用"],
        ["裂纹算盘", "普通", "金币低于 20 时金谱效果 +25%", "追赶"],
        ["终幕花冠", "Boss", "最终 Boss 前按红/蓝/金/灰中最低消除占比获得护盾", "均衡"],
    ]
    assert len(relic_rows) == 24, "frozen 1.0 scope requires exactly 24 relics"
    add_table(doc, ["遗物", "稀有", "效果", "流派"], relic_rows, [1.2, 0.65, 3.8, 0.85], font_size=7.3)
    add_table(
        doc,
        ["奖励来源", "标准奖励", "稀有度规则"],
        [
            ["普通战", "金币 + 三选一奖励", "普通为主，10%-20% 稀有。"],
            ["精英战", "金币 + 遗物 + 高稀有三选一", "保证稀有池，低概率史诗。"],
            ["Boss", "Boss 遗物 + 章节奖励 + 解锁", "提供跨章规则改写。"],
            ["事件", "代价换特化收益", "允许独占色谱或遗物。"],
            ["商店", "购买/升级/删谱/治疗/染色", "金币转化为稳定性。"],
        ],
        [1.1, 2.4, 3.0],
    )

    doc.add_heading("10. 经济系统", level=1)
    add_para(
        doc,
        "经济系统服务构筑，不服务付费。金币是局内资源，只能在本局商店、事件和治疗中使用；颜料是局内稀缺资源，用于染色、净化和特殊升级。二者共同约束金色流派，避免金色只等于更多钱。",
    )
    add_table(
        doc,
        ["资源", "来源", "用途", "约束"],
        [
            ["金币", "金色消除、战斗奖励、事件", "买谱、升级、删谱、治疗、遗物", "单场金色收益软上限 24，部分遗物提高。"],
            ["颜料", "混色谱、事件、Boss 奖励、跳过奖励", "染色、净化、特殊升级", "每章平均 2-4 点，不能无限刷。"],
            ["灰蚀压力", "污染、事件代价、Boss 行为", "影响结局和部分灰谱收益", "达到阈值会强化敌人，但可转化。"],
            ["HP", "战斗承伤、事件代价", "路线风险核心", "默认不全回复，营火/商店是主要恢复。"],
        ],
        [0.9, 1.6, 1.75, 2.25],
    )
    add_table(
        doc,
        ["商店项目", "价格", "递增/限制"],
        [
            ["普通色谱", "45", "每章商店 3 张。"],
            ["稀有色谱", "75", "每店 1-2 张。"],
            ["遗物", "120-180", "稀有度定价，每店最多 1 件。"],
            ["升级", "55", "每购买一次 +20；展示 3 张可选升级目标。"],
            ["删谱", "65", "每删除一次 +25；牌组低于 8 禁止。"],
            ["治疗", "40", "回复 25% 最大 HP；Boss 前商店 45。"],
            ["染色", "50 金币 +1 颜料", "指定一张中立/灰谱转为红/蓝/金。"],
            ["刷新", "15", "每店第一次 15，之后 25。"],
        ],
        [1.35, 1.1, 4.05],
    )

    doc.add_heading("11. 元进度与进阶难度", level=1)
    add_para(
        doc,
        "元进度只解锁横向选择，不提供永久数值碾压。玩家可以解锁起始流派、色谱池、遗物池、事件分支、外观和挑战词条，但不能通过刷局外属性让普通难度失去意义。",
    )
    add_table(
        doc,
        ["元进度", "解锁方式", "边界"],
        [
            ["起始流派", "首次通关章节或达成颜色结局", "只改变初始牌组，不给永久攻击。"],
            ["色谱池", "完成图鉴目标", "逐步加入高级谱，避免新手过载。"],
            ["遗物池", "击败精英/Boss 或完成事件", "解锁后进入随机池。"],
            ["结局图鉴", "按颜色倾向、灰蚀压力、关键事件触发", "提供叙事复玩。"],
            ["外观", "通关、挑战、成就", "不影响数值。"],
        ],
        [1.1, 2.2, 3.2],
    )
    add_table(
        doc,
        ["难度", "开放方式", "运行时规则变化"],
        [
            ["普通", "默认", "标准敌人数值，教程完整。"],
            ["进阶 1", "新局可选", "全部敌人 HP +8%。"],
            ["进阶 2", "新局可选", "继承进阶 1；攻击和重击数值 +10%。"],
            ["进阶 3", "新局可选", "继承进阶 1-2；战斗金币奖励 -15%。"],
            ["进阶 4", "新局可选", "继承进阶 1-3；精英额外 HP ×1.15、伤害 ×1.12。"],
            ["进阶 5", "新局可选", "继承进阶 1-4；Boss 额外 HP ×1.20、伤害 ×1.15，污染意图 +1。"],
        ],
        [0.9, 1.2, 4.4],
    )

    doc.add_heading("12. UI/UX", level=1)
    add_para(
        doc,
        "UI 必须服务三件事：敌人想做什么、色谱想要什么、棋盘哪里能完成目标。卡面不能喧宾夺主，棋盘仍是视觉中心。每一张色谱统一显示“目标、进度、完成、限制”，避免玩家把它理解成可点击技能。",
    )
    add_table(
        doc,
        ["界面", "必须显示", "交互要求"],
        [
            ["战斗主界面", "敌人意图、HP、状态、护盾、棋盘、步数、3 张色谱", "色谱进度实时高亮；可点击仅用于保留/查看详情，不用于释放。"],
            ["色谱详情", "目标、进度、完成、升级变化、触发限制", "长按/悬停展开说明，默认卡面两行内。"],
            ["路线图", "节点类型、风险、预期奖励、当前 HP/金币/灰蚀", "选择前展示节点信息，不隐藏关键风险。"],
            ["奖励界面", "加入后牌组数量、颜色比例、升级预览", "支持跳过奖励；避免强迫拿牌。"],
            ["商店", "金币、颜料、牌组预览、升级目标", "升级/删谱必须可选目标。"],
            ["结算", "颜色比例、完成色谱数、最高连消、结局、解锁", "引导下一局尝试不同流派。"],
        ],
        [1.05, 2.65, 2.8],
        font_size=8.2,
    )
    add_table(
        doc,
        ["可读性规则", "标准"],
        [
            ["卡面文案", "目标不超过 16 个中文字符；效果不超过 22 个中文字符。"],
            ["颜色识别", "每色必须同时有色相、图标、边框纹理。"],
            ["反馈层级", "消除 < 色谱完成 < 连消爆发 < Boss 反制。"],
            ["教程", "第 1 战只教学红/蓝/金/灰与 3 步；第 2 战教学保留；第 3 战教学事件/奖励。"],
            ["失败复盘", "结算显示本局承伤来源、未完成色谱、最高灰蚀压力。"],
        ],
        [1.25, 5.25],
        header_fill=GOLD_FILL,
    )

    doc.add_heading("13. 视听方向", level=1)
    add_table(
        doc,
        ["方向", "1.0 要求"],
        [
            ["视觉基调", "灰雾世界被红、蓝、金重新染色；暗底不应吞掉色块识别。"],
            ["角色表现", "勇者至少有待机、攻击、受击、防御、胜利、失败；敌人至少有意图预备、攻击、受击、死亡。"],
            ["棋盘表现", "每种颜色有图标：红焰、蓝晶、金币、灰石；高亮可完成目标的相关色块。"],
            ["色谱 VFX", "完成时卡面发光并向敌人/勇者飞出效果；升级色谱有二段音。"],
            ["章节环境", "第 1 章灰雾边境，第 2 章镜湖工坊，第 3 章无色王庭。"],
            ["音乐", "地图轻节奏，战斗中速，精英/Boss 增加鼓点；灰蚀高时加入低频不协和层。"],
            ["音效", "交换、无效交换、三连、4/5 连、级联、色谱完成、敌人意图、奖励选择必须分层。"],
        ],
        [1.2, 5.3],
    )

    doc.add_heading("14. 技术与数据落地", level=1)
    add_para(
        doc,
        "1.0 应优先数据驱动。当前 Godot 工程已有棋盘、战斗、敌人和 UI 基础，可继续沿用；但为了支持 36 色谱、24 遗物、3 章 24 层路线和进阶 1-5，必须把规则从硬编码逐步迁移到数据表。关键是色谱实例 UID，否则重复牌、升级、保留和删除都会混淆。",
    )
    add_table(
        doc,
        ["模块", "职责", "1.0 技术要求"],
        [
            ["Board", "棋盘生成、交换、匹配、级联、污染/净化", "clear_event 包含颜色、数量、级联、主动标记、顺序、坐标。"],
            ["SpectrumManager", "进度、触发、保留、升级读取", "按 uid 管理实例，按 spec_id 读取模板。"],
            ["BattleManager", "回合、伤害、敌人意图、状态", "拆 IntentResolver、RewardResolver，避免主类膨胀。"],
            ["GameManager/RunState", "牌组、路线、经济、元进度", "区分局内状态和局外存档。"],
            ["Data", "色谱、遗物、敌人、事件、章节、难度", "JSON/Resource 表，支持热更新和校验。"],
            ["UI Scenes", "战斗 HUD、地图、奖励、商店、事件", "从 Main.gd 动态 UI 拆成可复用场景。"],
            ["Telemetry", "战斗日志、回合数、完成率、死亡原因", "本地调试数据，用于平衡，不上传个人隐私。"],
        ],
        [1.25, 1.65, 3.6],
        font_size=8.2,
    )
    add_table(
        doc,
        ["数据表", "关键字段"],
        [
            ["spectra.json", "spec_id, name, trigger_colors, theme_tags, rarity, condition_type, threshold, effect_type, upgrade_delta"],
            ["relics.json", "id, name, rarity, trigger, effect, stack_rule, conflict_tags"],
            ["enemies.json", "id, chapter, hp, attack, intents, resistances, rewards, tutorial_tags"],
            ["events.json", "id, chapter, choices, costs, rewards, flags, followups"],
            ["chapters.json", "node_pool, boss, event_pool, shop_rules, map_generation"],
            ["difficulty.json", "level, hp_mod, reward_mod, added_rules, boss_mods"],
        ],
        [1.35, 5.15],
        font_size=8.0,
    )

    doc.add_heading("15. 商业化边界、验收与里程碑", level=1)
    doc.add_heading("15.1 商业化边界", level=2)
    add_para(
        doc,
        "商业化采用买断制。允许试玩版、正式版、原声集、美术设定集、免费内容更新和大型付费 DLC；不允许影响战斗强度的内购、抽卡、体力、每日签到压力或数值加速。这样才能保护“每局失败是策略问题，不是付费问题”的信任。",
    )
    add_table(
        doc,
        ["允许", "禁止"],
        [
            ["Steam 买断、首发折扣、试玩节 Demo", "付费抽色谱、付费遗物、体力限制。"],
            ["原声集、美术设定集、皮肤包", "影响棋盘掉落或战斗数值的付费内容。"],
            ["免费平衡更新与挑战模式", "每日任务诱导付费或限时付费强度。"],
            ["大型 DLC：新章节、新敌人、新流派", "把基础体验拆成付费碎片。"],
        ],
        [3.25, 3.25],
        header_fill=RED_FILL,
    )
    doc.add_heading("15.2 1.0 验收标准", level=2)
    add_table(
        doc,
        ["类别", "验收标准"],
        [
            ["局长", "普通难度完整通关中位数 60-90 分钟；失败局也应在 20-50 分钟形成复盘。"],
            ["冻结规模", "3 章 24 层、36 色谱、24 遗物、18 普通敌、6 精英、3 Boss、12 事件、3 起始流派、普通难度与进阶 1-5 全部可配置。"],
            ["四色边界", "棋盘生成、换色、匹配、掉落权重和抗性枚举仅含红/蓝/金/灰；白/黑/混色仅存在于色谱 theme_tags。"],
            ["可读性", "新玩家 10 分钟内理解“色谱是目标契约，不是点击出牌”。"],
            ["战斗节奏", "普通战 3-9 回合，精英 5-12 回合，Boss 7-14 回合；按章节递增。"],
            ["构筑", "连续 3 局至少出现 2 种主流派；通关局平均牌组 10-16 张。"],
            ["公平", "失败访谈中，玩家能指出路线、目标或风险判断问题，而非只归因于随机。"],
            ["UI", "80% 初始色谱无需打开说明即可理解目标与效果。"],
            ["技术", "重复同名色谱实例、升级、保留、删除、触发均无身份混淆。"],
        ],
        [1.15, 5.35],
    )
    doc.add_heading("15.3 制作里程碑", level=2)
    add_table(
        doc,
        ["里程碑", "周期", "交付物", "通过标准"],
        [
            ["M0 规则修复", "2 周", "实例 UID、升级生效、保留/删除修正、12 张核心色谱", "三场战斗无身份混淆，玩家能完成目标契约。"],
            ["M1 第一章切片", "6 周", "第 1 章 8 节点、12 色谱、8 遗物、6 普通、2 精英、1 Boss、4 事件", "单局 20-30 分钟，能公开小范围测试。"],
            ["M2 三章 Alpha", "10 周", "3 章 24 层路线、36 色谱、24 遗物、全敌人与事件数据表", "完整通关 60-90 分钟，主要系统无空白。"],
            ["M3 Beta 平衡", "8 周", "进阶 1-5、教程、结局、UI/UX、音画反馈", "新玩家可独立通关普通，核心玩家可挑战进阶。"],
            ["M4 1.0 候选", "4 周", "性能、存档、成就、Steam 页面素材、试玩版", "内容冻结，严重 bug 清零，可提交发布审核。"],
        ],
        [1.0, 0.8, 2.45, 2.25],
        font_size=8.0,
    )
    add_callout(
        doc,
        "制作优先级",
        "先修规则身份，再扩内容。没有色谱实例 UID 和升级生效，36 张色谱只会放大混淆；有了稳定的目标契约框架，3 章 24 层、约 24 个实际节点和进阶 1-5 才能成立。",
        GREEN_FILL,
    )

    doc.save(OUT_DOCX)
    print(OUT_DOCX)


if __name__ == "__main__":
    build_doc()
