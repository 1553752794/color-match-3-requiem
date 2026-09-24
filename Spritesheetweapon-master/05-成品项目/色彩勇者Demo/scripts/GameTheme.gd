extends RefCounted
class_name GameTheme

const BG_BASE = Color(0.043, 0.051, 0.063)
const BG_DEEP = Color(0.031, 0.035, 0.039)
const SURFACE = Color(0.078, 0.094, 0.114)
const SURFACE_RAISED = Color(0.106, 0.125, 0.149)
const SURFACE_HOVER = Color(0.141, 0.169, 0.200)
const BORDER = Color(0.212, 0.239, 0.271)

const TEXT_PRIMARY = Color(0.949, 0.906, 0.827)
const TEXT_SECONDARY = Color(0.663, 0.690, 0.714)
const TEXT_MUTED = Color(0.451, 0.475, 0.510)

const RED = Color(0.902, 0.294, 0.235)
const BLUE = Color(0.302, 0.549, 0.910)
const GOLD = Color(0.878, 0.714, 0.298)
const GREEN = Color(0.345, 0.722, 0.604)
const GRAY = Color(0.451, 0.475, 0.510)

static var _regular_font: SystemFont
static var _medium_font: SystemFont
static var _bold_font: SystemFont

static func create_theme() -> Theme:
	var result: Theme = Theme.new()
	result.default_font = regular_font()
	result.default_font_size = 16

	result.set_font("font", "Label", regular_font())
	result.set_font("font", "Button", medium_font())
	result.set_font("font", "CheckButton", medium_font())
	result.set_font("normal_font", "RichTextLabel", regular_font())
	result.set_font("bold_font", "RichTextLabel", bold_font())
	result.set_font("font", "TooltipLabel", regular_font())

	result.set_color("font_color", "Label", TEXT_PRIMARY)
	result.set_color("font_color", "Button", TEXT_PRIMARY)
	result.set_color("font_hover_color", "Button", TEXT_PRIMARY)
	result.set_color("font_pressed_color", "Button", TEXT_PRIMARY)
	result.set_color("font_focus_color", "Button", TEXT_PRIMARY)
	result.set_color("font_disabled_color", "Button", TEXT_MUTED)
	result.set_color("font_color", "CheckButton", TEXT_SECONDARY)
	result.set_color("font_hover_color", "CheckButton", TEXT_PRIMARY)
	result.set_color("default_color", "RichTextLabel", TEXT_SECONDARY)
	result.set_color("font_color", "TooltipLabel", TEXT_PRIMARY)

	result.set_stylebox("panel", "PanelContainer", panel_style())
	result.set_stylebox("panel", "Panel", panel_style())
	result.set_stylebox("normal", "Button", button_style(SURFACE_RAISED, BORDER))
	result.set_stylebox("hover", "Button", button_style(SURFACE_HOVER, TEXT_MUTED))
	result.set_stylebox("pressed", "Button", button_style(BG_DEEP, GOLD, 2))
	result.set_stylebox("focus", "Button", button_style(Color.TRANSPARENT, GOLD, 2))
	result.set_stylebox("disabled", "Button", button_style(SURFACE, BORDER))
	result.set_stylebox("background", "ProgressBar", panel_style(BG_DEEP, BG_DEEP, 0, 2, 0))
	result.set_stylebox("fill", "ProgressBar", panel_style(RED, RED, 0, 2, 0))
	result.set_stylebox("panel", "TooltipPanel", panel_style(SURFACE_RAISED, BORDER, 1, 4, 10))
	result.set_constant("outline_size", "Label", 0)
	result.set_constant("line_separation", "RichTextLabel", 4)
	return result

static func regular_font() -> SystemFont:
	if _regular_font == null:
		_regular_font = _make_system_font(400)
	return _regular_font

static func medium_font() -> SystemFont:
	if _medium_font == null:
		_medium_font = _make_system_font(600)
	return _medium_font

static func bold_font() -> SystemFont:
	if _bold_font == null:
		_bold_font = _make_system_font(700)
	return _bold_font

static func font_for_size(size: int) -> SystemFont:
	if size >= 20:
		return bold_font()
	if size >= 15:
		return medium_font()
	return regular_font()

static func panel_style(
	fill: Color = SURFACE,
	border: Color = BORDER,
	border_width: int = 1,
	radius: int = 4,
	padding: int = 10
) -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_border_width_all(border_width)
	style.corner_radius_top_left = radius
	style.corner_radius_top_right = radius
	style.corner_radius_bottom_left = radius
	style.corner_radius_bottom_right = radius
	style.content_margin_left = padding
	style.content_margin_right = padding
	style.content_margin_top = padding
	style.content_margin_bottom = padding
	return style

static func button_style(fill: Color, border: Color, border_width: int = 1) -> StyleBoxFlat:
	return panel_style(fill, border, border_width, 4, 10)

static func apply_button(button: Button, fill: Color = SURFACE_RAISED, accent: Color = BORDER) -> void:
	button.add_theme_font_override("font", medium_font())
	button.add_theme_font_size_override("font_size", 16)
	button.add_theme_color_override("font_color", TEXT_PRIMARY)
	button.add_theme_color_override("font_hover_color", TEXT_PRIMARY)
	button.add_theme_color_override("font_pressed_color", TEXT_PRIMARY)
	button.add_theme_color_override("font_focus_color", TEXT_PRIMARY)
	button.add_theme_color_override("font_disabled_color", TEXT_MUTED)
	button.add_theme_stylebox_override("normal", button_style(fill, accent))
	button.add_theme_stylebox_override("hover", button_style(fill.lightened(0.10), accent.lightened(0.22)))
	button.add_theme_stylebox_override("pressed", button_style(fill.darkened(0.16), GOLD, 2))
	button.add_theme_stylebox_override("focus", button_style(Color.TRANSPARENT, GOLD, 2))
	button.add_theme_stylebox_override("disabled", button_style(SURFACE, BORDER))

static func _make_system_font(weight: int) -> SystemFont:
	var font: SystemFont = SystemFont.new()
	font.font_names = PackedStringArray([
		"Noto Sans SC",
		"Microsoft YaHei UI",
		"Microsoft YaHei",
		"DengXian",
		"Arial",
	])
	font.font_weight = weight
	font.allow_system_fallback = true
	return font
