extends Control
class_name StrategyCouncil

const GameThemeScript = preload("res://scripts/GameTheme.gd")
const StrategyRulesScript = preload("res://scripts/StrategyRules.gd")
const ARCHIVE_BACKDROP = preload("res://assets/ui/v2/archive_backdrop.png")

signal back_requested
signal policy_selected(policy_id: String)
signal project_selected(project_id: String)

const PANEL_PADDING: int = 12
const SECTION_GAP: int = 10
const COLOR_MAP: Dictionary = {
	"red": GameThemeScript.RED,
	"blue": GameThemeScript.BLUE,
	"gold": GameThemeScript.GOLD,
	"green": GameThemeScript.GREEN,
	"gray": GameThemeScript.GRAY,
}
const PROJECT_ART: Dictionary = {
	"forge": "res://assets/strategy/council/forge.png",
	"sanctuary": "res://assets/strategy/council/sanctuary.png",
	"exchange": "res://assets/strategy/council/exchange.png",
}

var manager: Node
var _content: VBoxContainer
var _policy_grid: GridContainer
var _project_grid: GridContainer
var _progress_box: VBoxContainer

func build(new_manager: Node) -> void:
	manager = new_manager
	_clear_children()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP

	var backdrop: TextureRect = TextureRect.new()
	backdrop.name = "CouncilBackdrop"
	backdrop.texture = ARCHIVE_BACKDROP
	backdrop.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	backdrop.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	backdrop.modulate = Color(0.42, 0.45, 0.50, 0.34)
	backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(backdrop)

	var veil: ColorRect = ColorRect.new()
	veil.color = Color(0.031, 0.035, 0.039, 0.78)
	veil.mouse_filter = Control.MOUSE_FILTER_IGNORE
	veil.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(veil)

	var margin: MarginContainer = MarginContainer.new()
	margin.name = "CouncilMargin"
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 24)
	margin.add_theme_constant_override("margin_right", 24)
	margin.add_theme_constant_override("margin_top", 20)
	margin.add_theme_constant_override("margin_bottom", 20)
	add_child(margin)

	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.name = "CouncilScroll"
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	margin.add_child(scroll)

	_content = VBoxContainer.new()
	_content.name = "CouncilContent"
	_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_content.add_theme_constant_override("separation", SECTION_GAP)
	scroll.add_child(_content)

	_content.add_child(_build_header())
	_content.add_child(_build_history())
	_content.add_child(_build_policy_section())
	_content.add_child(_build_project_section())
	_content.add_child(_build_progress_section())

	var footer: HBoxContainer = HBoxContainer.new()
	footer.name = "CouncilFooter"
	footer.alignment = BoxContainer.ALIGNMENT_END
	var back: Button = Button.new()
	back.name = "CouncilBack"
	back.text = "返回"
	back.custom_minimum_size = Vector2(120, 44)
	GameThemeScript.apply_button(back, GameThemeScript.SURFACE_RAISED, GameThemeScript.BORDER)
	back.pressed.connect(_on_back_pressed)
	footer.add_child(back)
	_content.add_child(footer)

func _clear_children() -> void:
	for child in get_children():
		remove_child(child)
		child.queue_free()
	_content = null
	_policy_grid = null
	_project_grid = null
	_progress_box = null

func _build_header() -> Control:
	var box: VBoxContainer = VBoxContainer.new()
	box.name = "CouncilHeader"
	box.add_theme_constant_override("separation", 4)
	var title: Label = _label("复兴议会", 28, GameThemeScript.TEXT_PRIMARY)
	title.name = "CouncilTitle"
	box.add_child(title)
	var chapter: String = _chapter_id()
	var subtitle: Label = _label("第 %s 章 · 金币 %d · 颜料 %d" % [chapter.trim_prefix("C"), _manager_int("coins"), _manager_int("pigment", "pigments")], 15, GameThemeScript.GOLD)
	subtitle.name = "CouncilSubtitle"
	box.add_child(subtitle)
	return box

func _build_history() -> Control:
	var panel: PanelContainer = _panel()
	panel.name = "ChapterHistory"
	var label: Label = _label(_history_text(), 14, GameThemeScript.TEXT_SECONDARY)
	label.name = "History_%s" % _chapter_id()
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	panel.add_child(label)
	return panel

func _build_policy_section() -> Control:
	var section: VBoxContainer = _section("本章政策")
	var options: Array[Dictionary] = _call_array("get_policy_options")
	_policy_grid = GridContainer.new()
	_policy_grid.name = "PolicyGrid"
	_policy_grid.columns = 4
	_policy_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_policy_grid.add_theme_constant_override("h_separation", SECTION_GAP)
	_policy_grid.add_theme_constant_override("v_separation", SECTION_GAP)
	for policy in options:
		_policy_grid.add_child(_build_policy_card(policy))
	section.add_child(_policy_grid)
	var selected: Dictionary = _call_dictionary("get_selected_policy")
	var selected_label: Label = _label("当前选择：%s" % String(selected.get("name", "尚未选择")), 13, GameThemeScript.TEXT_MUTED)
	selected_label.name = "SelectedPolicy"
	section.add_child(selected_label)
	section.name = "PolicySection"
	return section

func _build_policy_card(policy: Dictionary) -> Control:
	var id: String = _entry_id(policy)
	var accent: Color = _accent(policy)
	var box: VBoxContainer = VBoxContainer.new()
	box.name = "PolicyCard_%s" % id
	box.custom_minimum_size = Vector2(0, 150)
	box.add_theme_constant_override("separation", 6)
	var title: Label = _label(String(policy.get("name", id)), 17, accent)
	title.name = "PolicyName_%s" % id
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(title)
	var summary: Label = _label(String(policy.get("summary", "本章政策效果待补充。")), 13, GameThemeScript.TEXT_SECONDARY)
	summary.name = "PolicySummary_%s" % id
	summary.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	summary.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(summary)
	var button: Button = Button.new()
	button.name = "Policy_%s" % id
	button.text = "选择政策"
	button.custom_minimum_size = Vector2(0, 38)
	button.disabled = not _can_choose_policy()
	GameThemeScript.apply_button(button, GameThemeScript.SURFACE_RAISED, accent)
	button.pressed.connect(func() -> void: policy_selected.emit(id))
	box.add_child(button)
	return _card_frame(box, accent)

func _build_project_section() -> Control:
	var section: VBoxContainer = _section("章节项目")
	_project_grid = GridContainer.new()
	_project_grid.name = "ProjectGrid"
	_project_grid.columns = 3
	_project_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_project_grid.add_theme_constant_override("h_separation", SECTION_GAP)
	_project_grid.add_theme_constant_override("v_separation", SECTION_GAP)
	var projects: Object = manager.get("projects") as Object
	if projects != null and projects.has_method("options"):
		for project_value in projects.options():
			if project_value is Dictionary:
				_project_grid.add_child(_build_project_card(project_value))
	section.add_child(_project_grid)
	section.name = "ProjectSection"
	return section

func _build_project_card(project: Dictionary) -> Control:
	var id: String = _entry_id(project)
	var accent: Color = _accent(project)
	var box: VBoxContainer = VBoxContainer.new()
	box.name = "ProjectCard_%s" % id
	box.custom_minimum_size = Vector2(0, 182)
	box.add_theme_constant_override("separation", 5)
	var header: HBoxContainer = HBoxContainer.new()
	header.add_theme_constant_override("separation", 10)
	box.add_child(header)
	var art: TextureRect = _project_art(id, accent)
	header.add_child(art)
	var heading: VBoxContainer = VBoxContainer.new()
	heading.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	heading.alignment = BoxContainer.ALIGNMENT_CENTER
	heading.add_theme_constant_override("separation", 8)
	header.add_child(heading)
	var title: Label = _label(String(project.get("name", id)), 17, accent)
	title.name = "ProjectName_%s" % id
	heading.add_child(title)
	var benefit: Label = _label("完工收益\n%s" % _effects_text(project), 13, GameThemeScript.GREEN)
	benefit.name = "ProjectBenefit_%s" % id
	heading.add_child(benefit)
	var description: Label = _label(String(project.get("description", "章节建设项目。")), 13, GameThemeScript.TEXT_SECONDARY)
	description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	description.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(description)
	var cost: Label = _label("消耗：金币 %d · 颜料 %d" % [int(project.get("coin_cost", 0)), int(project.get("pigment_cost", 0))], 12, GameThemeScript.GOLD)
	cost.name = "ProjectCost_%s" % id
	box.add_child(cost)
	var button: Button = Button.new()
	button.name = "Project_%s" % id
	button.text = _project_button_text(id)
	button.custom_minimum_size = Vector2(0, 38)
	button.disabled = not _can_start_project(id)
	GameThemeScript.apply_button(button, GameThemeScript.SURFACE_RAISED, accent)
	button.pressed.connect(func() -> void: project_selected.emit(id))
	box.add_child(button)
	return _card_frame(box, accent)

func _project_button_text(project_id: String) -> String:
	var projects: Object = manager.get("projects") as Object
	var status: Dictionary = projects.status(_chapter_id()) if projects != null and projects.has_method("status") else {}
	if not status.is_empty():
		if String(status.get("id", "")) == project_id:
			if bool(status.get("completed", false)):
				return "已完工"
			return "建设中 %d/%d" % [int(status.get("progress", 0)), int(status.get("target", 0))]
		return "本章已选其他项目"
	if _manager_int("coins") < 30 or _manager_int("pigment", "pigments") < 1:
		return "资源不足"
	return "启动项目"

func _project_art(project_id: String, accent: Color) -> TextureRect:
	var art: TextureRect = TextureRect.new()
	art.name = "ProjectArt_%s" % project_id
	art.custom_minimum_size = Vector2(104, 112)
	art.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	art.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var texture_path: String = String(PROJECT_ART.get(project_id, ""))
	if not texture_path.is_empty() and ResourceLoader.exists(texture_path):
		art.texture = load(texture_path) as Texture2D
	art.visible = art.texture != null
	art.modulate = Color(1.0, 1.0, 1.0, 0.96) if art.texture != null else accent.darkened(0.55)
	return art

func _build_progress_section() -> Control:
	var section: VBoxContainer = _section("章节进度")
	_progress_box = VBoxContainer.new()
	_progress_box.name = "ProgressList"
	_progress_box.add_theme_constant_override("separation", 4)
	var projects: Object = manager.get("projects") as Object
	if projects != null and projects.has_method("status"):
		for chapter in ["C1", "C2", "C3"]:
			var status_value: Variant = projects.status(chapter)
			if not status_value is Dictionary:
				status_value = {}
			var entry: Dictionary = status_value
			var project_name: String = String(entry.get("name", "暂无项目"))
			var progress: int = int(entry.get("progress", 0))
			var target: int = maxi(int(entry.get("target", 0)), 0)
			var completed: bool = entry.get("completed", false) == true
			var mark: String = "未开工" if entry.is_empty() else "已完成" if completed else "%d/%d" % [progress, target]
			var policy_name: String = _policy_name_for_chapter(chapter)
			var line: Label = _label("%s：政策 %s · %s · %s" % [chapter, policy_name, project_name, mark], 13, GameThemeScript.GREEN if completed else GameThemeScript.TEXT_SECONDARY)
			line.name = "Progress_%s" % chapter
			line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			_progress_box.add_child(line)
	if _progress_box.get_child_count() == 0:
		_progress_box.add_child(_label("本章尚无项目进度记录。", 13, GameThemeScript.TEXT_MUTED))
	section.add_child(_progress_box)
	section.name = "ProgressSection"
	return section

func _section(title: String) -> VBoxContainer:
	var box: VBoxContainer = VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_theme_constant_override("separation", 7)
	var heading: Label = _label(title, 18, GameThemeScript.TEXT_PRIMARY)
	box.add_child(heading)
	return box

func _panel() -> PanelContainer:
	var panel: PanelContainer = PanelContainer.new()
	panel.add_theme_stylebox_override("panel", GameThemeScript.panel_style(GameThemeScript.SURFACE, GameThemeScript.BORDER, 1, 4, PANEL_PADDING))
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return panel

func _card_frame(content: Control, accent: Color) -> PanelContainer:
	var panel: PanelContainer = PanelContainer.new()
	panel.add_theme_stylebox_override("panel", GameThemeScript.panel_style(GameThemeScript.SURFACE_RAISED, accent.darkened(0.35), 1, 4, 10))
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.custom_minimum_size.x = 0
	panel.add_child(content)
	return panel

func _label(text_value: String, font_size: int, color: Color) -> Label:
	var label: Label = Label.new()
	label.text = text_value
	label.add_theme_font_override("font", GameThemeScript.font_for_size(font_size))
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return label

func _history_text() -> String:
	var policies: Dictionary = manager.get("chapter_policies") as Dictionary
	var history: Array[String] = []
	for chapter_value in policies.keys():
		var chapter: String = String(chapter_value)
		var policy_id: String = String(policies[chapter])
		history.append("%s：%s" % [chapter, _policy_name(policy_id)])
	history.sort()
	return "章节历史 · " + (" · ".join(history) if not history.is_empty() else "暂无已选政策")

func _chapter_id() -> String:
	if manager != null and manager.has_method("get_strategy_chapter_id"):
		return String(manager.get_strategy_chapter_id())
	return "未知"

func _can_choose_policy() -> bool:
	return manager != null and manager.has_method("can_choose_policy") and manager.can_choose_policy()

func _can_start_project(project_id: String) -> bool:
	return manager != null and manager.has_method("can_start_project") and manager.can_start_project(project_id)

func _call_array(method_name: String) -> Array[Dictionary]:
	if manager == null or not manager.has_method(method_name):
		return []
	var value: Variant = manager.call(method_name)
	var result: Array[Dictionary] = []
	if value is Array:
		for entry in value:
			if entry is Dictionary:
				result.append(entry)
	return result

func _call_dictionary(method_name: String) -> Dictionary:
	if manager == null or not manager.has_method(method_name):
		return {}
	var value: Variant = manager.call(method_name)
	return value if value is Dictionary else {}

func _manager_int(primary: String, alternate: String = "") -> int:
	if manager == null:
		return 0
	var value: Variant = manager.get(primary)
	if value is int or value is float:
		return int(value)
	if alternate != "":
		value = manager.get(alternate)
		if value is int or value is float:
			return int(value)
	return 0

func _entry_id(entry: Dictionary) -> String:
	return String(entry.get("id", entry.get("policy_id", entry.get("project_id", entry.get("name", "entry")))))

func _policy_name_for_chapter(chapter: String) -> String:
	var policies: Dictionary = manager.get("chapter_policies") as Dictionary
	return _policy_name(String(policies.get(chapter, "")))

func _policy_name(policy_id: String) -> String:
	if policy_id.is_empty():
		return "未选择"
	var policy: Dictionary = StrategyRulesScript.policy(policy_id)
	return String(policy.get("name", policy_id))

func _accent(entry: Dictionary) -> Color:
	return COLOR_MAP.get(String(entry.get("color", "gray")), GameThemeScript.GRAY)

func _effects_text(project: Dictionary) -> String:
	var effects: Variant = project.get("effects", [])
	if effects is Dictionary and not effects.is_empty():
		var details: Array[String] = []
		for effect_id in effects.keys():
			details.append(_effect_text(String(effect_id), effects[effect_id]))
		return "；".join(details)
	return "完成后获得章节收益"

func _effect_text(effect_id: String, value: Variant) -> String:
	match effect_id:
		"spectrum_base_damage":
			return "色谱基础伤害 +%d" % int(value)
		"first_turn_shield":
			return "每场开局护盾 +%d" % int(value)
		"shop_discount":
			return "商店价格 -%d%%" % roundi(float(value) * 100.0)
		_:
			return "%s +%s" % [effect_id, str(value)]

func _on_back_pressed() -> void:
	back_requested.emit()
