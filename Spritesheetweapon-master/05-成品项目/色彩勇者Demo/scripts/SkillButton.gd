## Reusable battle skill button. It displays energy progress, disables itself
## until the skill can be paid for, and emits the requested skill id.
extends Button
class_name SkillButton

## Raised when the player clicks an enabled skill button.
signal skill_requested(skill_id: String)

## Static skill metadata assigned by Main.gd during UI construction.
var skill_id: String = ""
var display_name: String = ""
var color_key: String = ""
var cost: int = 10

## Configures the skill identity, visual behavior, and initial disabled state.
func setup(new_skill_id: String, new_display_name: String, new_color_key: String, new_cost: int) -> void:
	skill_id = new_skill_id
	display_name = new_display_name
	color_key = new_color_key
	cost = new_cost
	focus_mode = Control.FOCUS_NONE
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	custom_minimum_size = Vector2(168, 64)
	if not pressed.is_connected(_on_pressed):
		pressed.connect(_on_pressed)
	update_energy(0)

## Refreshes progress text, tooltip, enabled state, and color styling.
func update_energy(current: int) -> void:
	disabled = current < cost
	text = "%s\n%d/%d" % [display_name, min(current, cost), cost]
	tooltip_text = "%s 能量：%d/%d" % [display_name, current, cost]
	add_theme_font_size_override("font_size", 15)
	add_theme_color_override("font_color", Color(0.98, 0.95, 0.86))
	add_theme_color_override("font_disabled_color", Color(0.45, 0.45, 0.48))
	var fill: Color = _fill_color()
	if disabled:
		add_theme_stylebox_override("normal", _make_style(Color(0.16, 0.16, 0.18), fill.darkened(0.35), 2))
		add_theme_stylebox_override("hover", _make_style(Color(0.16, 0.16, 0.18), fill.darkened(0.35), 2))
	else:
		add_theme_stylebox_override("normal", _make_style(fill.darkened(0.2), fill.lightened(0.35), 2))
		add_theme_stylebox_override("hover", _make_style(fill, Color.WHITE, 2))
		add_theme_stylebox_override("pressed", _make_style(fill.darkened(0.35), Color.WHITE, 3))

## Emits only the id so BattleManager remains the single source of skill logic.
func _on_pressed() -> void:
	skill_requested.emit(skill_id)

## Maps skill color to a readable button fill.
func _fill_color() -> Color:
	match color_key:
		"red":
			return Color(0.78, 0.18, 0.12)
		"blue":
			return Color(0.15, 0.38, 0.78)
		"gold":
			return Color(0.86, 0.62, 0.12)
		_:
			return Color(0.42, 0.42, 0.45)

## Creates the pixel-style button frame used by enabled and disabled states.
func _make_style(bg: Color, border: Color, border_width: int) -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = bg
	style.border_color = border
	style.set_border_width_all(border_width)
	style.corner_radius_top_left = 4
	style.corner_radius_top_right = 4
	style.corner_radius_bottom_left = 4
	style.corner_radius_bottom_right = 4
	style.content_margin_left = 6
	style.content_margin_right = 6
	style.content_margin_top = 4
	style.content_margin_bottom = 4
	return style
