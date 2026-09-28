## Single clickable match tile. Board.gd owns the logical grid; this node only
## displays one color, emits clicks, and plays small feedback animations.
extends Button
class_name Tile

const GameThemeScript = preload("res://scripts/GameTheme.gd")

## Carries the tile's board coordinate back to Board.gd when clicked.
signal tile_clicked(grid_position: Vector2i)

const RUBY_PATH: String = "res://assets/ui_2_2/gems/ruby_smoothed.png"
const SAPPHIRE_PATH: String = "res://assets/ui_2_2/gems/sapphire_smoothed.png"

## Shared cropped bitmaps avoid decoding PNGs on every board refresh.
static var _gem_textures: Dictionary = {}

const TILE_COLORS = {
	"gray": Color(0.451, 0.475, 0.510),
	"red": Color(0.902, 0.294, 0.235),
	"blue": Color(0.302, 0.549, 0.910),
	"gold": Color(0.878, 0.714, 0.298),
}

const TILE_LABELS = {
	"gray": "雾",
	"red": "火",
	"blue": "冰",
	"gold": "金",
}

var grid_position: Vector2i = Vector2i.ZERO
var tile_type: String = "gray"
var is_selected: bool = false
var last_clear_shape: String = ""
var _feedback_tween: Tween
var _gem_icon: TextureRect
var _color_label: Label

## Initializes Button behavior and applies the current visual style.
func _ready() -> void:
	focus_mode = Control.FOCUS_NONE
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	pivot_offset = custom_minimum_size * 0.5
	if not pressed.is_connected(_on_pressed):
		pressed.connect(_on_pressed)
	_apply_visuals()

## Sets both the coordinate and color when the board creates the tile.
func setup(new_position: Vector2i, new_type: String) -> void:
	grid_position = new_position
	set_tile_type(new_type)

## Updates the coordinate after board refreshes or refills.
func set_grid_position(new_position: Vector2i) -> void:
	grid_position = new_position

## Updates the displayed color and resets animation state.
func set_tile_type(new_type: String) -> void:
	_stop_feedback()
	tile_type = new_type
	last_clear_shape = ""
	scale = Vector2.ONE
	modulate = Color.WHITE
	_apply_visuals()

## Enables or removes the selected highlight.
func set_selected(value: bool) -> void:
	is_selected = value
	_apply_visuals()

## Shrinks and fades the tile before Board.gd clears the logical cell.
func play_clear(shape: String = "line_3") -> void:
	_stop_feedback()
	last_clear_shape = shape
	pivot_offset = size * 0.5
	if _skip_motion():
		scale = Vector2.ONE
		modulate = Color(1, 1, 1, 0)
		return
	var special_shape: bool = shape in ["line_4", "line_5", "cross", "l_shape"]
	if special_shape:
		_feedback_tween = create_tween()
		_feedback_tween.tween_property(self, "scale", Vector2(1.08, 1.08), 0.05).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		_feedback_tween.tween_property(self, "scale", Vector2(0.68, 0.68), 0.11).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
		_feedback_tween.parallel().tween_property(self, "modulate:a", 0.0, 0.16)
		return
	_feedback_tween = create_tween().set_parallel(true)
	_feedback_tween.tween_property(self, "scale", Vector2(0.72, 0.72), 0.14).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	_feedback_tween.tween_property(self, "modulate:a", 0.0, 0.14)

## Pops new top-row tiles into view after refills.
func play_spawn() -> void:
	_stop_feedback()
	pivot_offset = size * 0.5
	if _skip_motion():
		scale = Vector2.ONE
		modulate = Color.WHITE
		return
	scale = Vector2(0.80, 0.80)
	modulate = Color(1, 1, 1, 0.55)
	_feedback_tween = create_tween().set_parallel(true)
	_feedback_tween.tween_property(self, "scale", Vector2.ONE, 0.16).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_feedback_tween.tween_property(self, "modulate:a", 1.0, 0.16)

func _stop_feedback() -> void:
	if _feedback_tween != null and _feedback_tween.is_valid():
		_feedback_tween.kill()
	_feedback_tween = null

func _skip_motion() -> bool:
	if not is_inside_tree():
		return false
	var settings: Node = get_node_or_null("/root/SettingsManager")
	return settings != null and (bool(settings.reduced_motion) or bool(settings.quick_resolve))

func _exit_tree() -> void:
	_stop_feedback()

## Emits the board position instead of exposing Button internals to Board.gd.
func _on_pressed() -> void:
	tile_clicked.emit(grid_position)

## Rebuilds text, tooltip, and StyleBox overrides for the current state.
func _apply_visuals() -> void:
	text = ""
	tooltip_text = _tooltip_for_type(tile_type)
	_ensure_icon()
	_gem_icon.texture = _texture_for_type(tile_type)
	_gem_icon.modulate = Color.WHITE
	if tile_type == "gray":
		_gem_icon.modulate = Color(0.75, 0.81, 0.86)
	elif tile_type == "gold":
		_gem_icon.modulate = Color(1.0, 0.79, 0.26)
	_color_label.text = String(TILE_LABELS.get(tile_type, "?"))
	var accent: Color = TILE_COLORS.get(tile_type, Color.GRAY)
	var bg: Color = GameThemeScript.SURFACE.lerp(accent, 0.16)
	var border: Color = GameThemeScript.TEXT_PRIMARY if is_selected else accent.darkened(0.20)
	var width: int = 3 if is_selected else 1
	if is_selected:
		bg = bg.lightened(0.10)
	add_theme_stylebox_override("normal", _make_style(bg, border, width))
	add_theme_stylebox_override("hover", _make_style(bg.lightened(0.10), GameThemeScript.TEXT_PRIMARY, width))
	add_theme_stylebox_override("pressed", _make_style(bg.darkened(0.16), GameThemeScript.TEXT_PRIMARY, width))
	add_theme_stylebox_override("disabled", _make_style(bg.darkened(0.12), border, width))

func _ensure_icon() -> void:
	if _gem_icon != null:
		return
	_gem_icon = TextureRect.new()
	_gem_icon.name = "GemIcon"
	_gem_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_gem_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_gem_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_gem_icon)
	_gem_icon.anchor_left = 0.5
	_gem_icon.anchor_right = 0.5
	_gem_icon.offset_left = -16
	_gem_icon.offset_right = 16
	_gem_icon.offset_top = 4
	_gem_icon.offset_bottom = 32
	_color_label = Label.new()
	_color_label.name = "ColorLabel"
	_color_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_color_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_color_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_color_label.clip_text = true
	_color_label.add_theme_font_override("font", GameThemeScript.bold_font())
	_color_label.add_theme_font_size_override("font_size", 10)
	_color_label.add_theme_color_override("font_color", GameThemeScript.TEXT_PRIMARY)
	add_child(_color_label)
	_color_label.anchor_right = 1.0
	_color_label.offset_left = 4
	_color_label.offset_right = -4
	_color_label.offset_top = 32
	_color_label.offset_bottom = 46

static func _texture_for_type(type_key: String) -> Texture2D:
	var key: String = type_key if TILE_COLORS.has(type_key) else "gray"
	if _gem_textures.has(key):
		return _gem_textures[key] as Texture2D
	var path: String = SAPPHIRE_PATH if key in ["blue", "gold"] else RUBY_PATH
	var image: Image
	if ResourceLoader.exists(path):
		var imported: Texture2D = load(path) as Texture2D
		if imported != null:
			image = imported.get_image()
	if image == null:
		# Fresh checkouts can run headlessly before the editor imports these PNGs.
		image = Image.load_from_file(path)
	if image == null or image.is_empty():
		return null
	image = image.get_region(image.get_used_rect())
	if key in ["gray", "gold"]:
		# Neutralize the source hue before tinting; retain its actual faceted silhouette.
		for y in range(image.get_height()):
			for x in range(image.get_width()):
				var pixel: Color = image.get_pixel(x, y)
				image.set_pixel(x, y, Color(pixel.v, pixel.v, pixel.v, pixel.a))
	var result: ImageTexture = ImageTexture.create_from_image(image)
	_gem_textures[key] = result
	return result

## Creates a compact pixel-like button frame.
func _make_style(bg: Color, border: Color, border_width: int) -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = bg
	style.border_color = border
	style.set_border_width_all(border_width)
	style.corner_radius_top_left = 4
	style.corner_radius_top_right = 4
	style.corner_radius_bottom_left = 4
	style.corner_radius_bottom_right = 4
	style.content_margin_left = 2
	style.content_margin_right = 2
	style.content_margin_top = 2
	style.content_margin_bottom = 2
	return style

## Provides short hover hints for tile behavior.
func _tooltip_for_type(type_key: String) -> String:
	match type_key:
		"red":
			return "红焰：消除获得红色素与技能充能，并施加燃烧（2 回合、1 层）"
		"blue":
			return "蓝霜：消除获得蓝色素与技能充能，30% 概率冻结敌人 1 回合"
		"gold":
			return "金辉：消除获得金色素与技能充能，每块基础获得 2 金币（受战斗上限与增益影响）"
		"gray":
			return "灰蚀：消除获得灰色素与技能充能，也可被净化或转化"
		_:
			return "色块：形成三连即可触发消除事件"
