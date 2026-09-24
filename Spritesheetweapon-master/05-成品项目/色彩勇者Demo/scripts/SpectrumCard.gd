extends PanelContainer
class_name SpectrumCard

const GameDataScript = preload("res://scripts/GameData.gd")
const GameThemeScript = preload("res://scripts/GameTheme.gd")
const SpectrumResolutionScript = preload("res://scripts/SpectrumResolution.gd")

signal retain_requested(instance_id: String)
signal target_requested(instance_id: String)

var card_id: String = ""
var instance_id: String = ""
var title_label: Label
var condition_label: Label
var progress_label: Label
var effect_label: Label
var retain_button: Button
var target_button: Button
var tags_label: Label

func setup(state: Dictionary, retain_enabled: bool = true) -> void:
	card_id = String(state.get("id", ""))
	instance_id = String(state.get("instance_id", ""))
	if title_label == null:
		_build()
	var color_key: String = String(state.get("color", "neutral"))
	var tint: Color = GameDataScript.color_tint(color_key)
	var is_triggered: bool = state.get("triggered", false) == true
	var is_retained: bool = state.get("retained", false) == true
	var is_targeted: bool = state.get("targeted", false) == true
	var trajectory_preview: bool = state.get("trajectory_preview", false) == true and not is_triggered
	var upgraded_suffix: String = "+" if state.get("upgraded", false) == true else ""
	title_label.text = "%s%s · %s" % [state.get("name", card_id), upgraded_suffix, GameDataScript.color_full_name(color_key)]
	condition_label.text = "目标：%s" % state.get("condition", "")
	progress_label.text = "进度：%s" % state.get("progress", "")
	if trajectory_preview:
		title_label.text = "调律预览 · " + title_label.text
		progress_label.text += "  ·  调律透镜锁定"
	var rarity: String = String(state.get("rarity", "common"))
	var base_damage: int = SpectrumResolutionScript.base_damage_for_rarity(rarity)
	var pulse_text: String = "基础 %d 伤害" % base_damage if base_damage > 0 else "无基础伤害"
	effect_label.text = "谱式：%s；附加：%s" % [pulse_text, state.get("effect", "")]
	var tags: Array = state.get("tags", GameDataScript.spectrum_tags(card_id))
	tags_label.text = "流派 · " + (" / ".join(Array(tags)) if not tags.is_empty() else "未分类")
	target_button.disabled = is_triggered
	target_button.text = "目标色谱" if is_targeted else "设为目标"
	target_button.tooltip_text = "本回合优先关注这张色谱"
	retain_button.disabled = is_triggered or not retain_enabled
	retain_button.text = "已完成" if is_triggered else ("保留中" if is_retained else "保留")
	var border: Color = tint.lightened(0.24) if state.get("upgraded", false) == true else tint
	if trajectory_preview:
		border = GameThemeScript.GOLD
	add_theme_stylebox_override("panel", _style(GameThemeScript.SURFACE_RAISED, border if not is_triggered else GameThemeScript.GOLD))
	title_label.add_theme_color_override("font_color", GameThemeScript.TEXT_PRIMARY)
	progress_label.add_theme_color_override("font_color", tint.lightened(0.12) if not is_triggered else GameThemeScript.GREEN)
	GameThemeScript.apply_button(retain_button, GameThemeScript.SURFACE, border)

func set_compact_mode(enabled: bool) -> void:
	if title_label == null:
		_build()
	custom_minimum_size = Vector2(184, 184) if enabled else Vector2(244, 184)
	title_label.add_theme_font_size_override("font_size", 15 if enabled else 17)
	condition_label.add_theme_font_size_override("font_size", 12 if enabled else 13)
	progress_label.add_theme_font_size_override("font_size", 12 if enabled else 13)
	effect_label.add_theme_font_size_override("font_size", 11 if enabled else 12)
	tags_label.add_theme_font_size_override("font_size", 10 if enabled else 11)

func _build() -> void:
	custom_minimum_size = Vector2(244, 214)
	var margin: MarginContainer = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_top", 11)
	margin.add_theme_constant_override("margin_bottom", 9)
	add_child(margin)

	var box: VBoxContainer = VBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	margin.add_child(box)

	title_label = _label("", 17, GameThemeScript.TEXT_PRIMARY)
	title_label.custom_minimum_size = Vector2(0, 22)
	box.add_child(title_label)
	condition_label = _label("", 13, GameThemeScript.TEXT_PRIMARY)
	condition_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	condition_label.custom_minimum_size = Vector2(0, 34)
	box.add_child(condition_label)
	progress_label = _label("", 13, GameThemeScript.GOLD)
	progress_label.custom_minimum_size = Vector2(0, 20)
	box.add_child(progress_label)
	effect_label = _label("", 12, GameThemeScript.TEXT_SECONDARY)
	effect_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	effect_label.custom_minimum_size = Vector2(0, 30)
	box.add_child(effect_label)
	tags_label = _label("", 11, GameThemeScript.GOLD)
	tags_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	tags_label.custom_minimum_size = Vector2(0, 22)
	box.add_child(tags_label)
	retain_button = Button.new()
	retain_button.custom_minimum_size = Vector2(0, 30)
	retain_button.focus_mode = Control.FOCUS_ALL
	retain_button.pressed.connect(func() -> void:
		retain_requested.emit(instance_id)
	)
	box.add_child(retain_button)
	target_button = Button.new()
	target_button.custom_minimum_size = Vector2(0, 28)
	target_button.focus_mode = Control.FOCUS_ALL
	target_button.pressed.connect(func() -> void:
		target_requested.emit(instance_id)
	)
	box.add_child(target_button)

func _label(text: String, size: int, color: Color) -> Label:
	var label: Label = Label.new()
	label.text = text
	label.add_theme_font_override("font", GameThemeScript.font_for_size(size))
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	return label

func _style(fill: Color, border: Color) -> StyleBoxFlat:
	var style: StyleBoxFlat = GameThemeScript.panel_style(fill, border, 2, 4, 0)
	style.border_width_top = 6
	return style
