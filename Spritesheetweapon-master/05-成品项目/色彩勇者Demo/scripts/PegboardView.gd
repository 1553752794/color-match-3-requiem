extends Control
class_name PegboardView

const PegboardResolverScript = preload("res://scripts/PegboardResolver.gd")

signal fire_requested(aim: float)

const BOARD_MARGIN: float = 18.0
const HEADER_HEIGHT: float = 54.0
const FOOTER_HEIGHT: float = 50.0
const PEG_ROWS: int = 8
const PEG_COLUMNS: int = 9

var aim: float = 0.0
var queue_count: int = 0
var current_shot: Dictionary = {}
var current_profile: Dictionary = {}
var last_result: Dictionary = {}
var dragging: bool = false
var fire_button: Button
var prediction_enabled: bool = true
var high_contrast_pegs: bool = false

func _ready() -> void:
	custom_minimum_size = Vector2(286, 354)
	mouse_filter = Control.MOUSE_FILTER_STOP
	clip_contents = true
	focus_mode = Control.FOCUS_ALL
	fire_button = Button.new()
	fire_button.text = "发射"
	fire_button.focus_mode = Control.FOCUS_ALL
	fire_button.anchor_left = 0.12
	fire_button.anchor_right = 0.88
	fire_button.anchor_top = 1.0
	fire_button.anchor_bottom = 1.0
	fire_button.offset_top = -44.0
	fire_button.offset_bottom = -8.0
	fire_button.pressed.connect(_request_fire)
	add_child(fire_button)
	_update_button()
	queue_redraw()

func set_queue_state(count: int, shot: Dictionary = {}) -> void:
	queue_count = max(count, 0)
	current_shot = shot.duplicate(true)
	_update_button()
	queue_redraw()

func set_profile(profile: Dictionary) -> void:
	current_profile = profile.duplicate(true)
	queue_redraw()

func set_accessibility(show_prediction: bool, high_contrast: bool) -> void:
	prediction_enabled = show_prediction
	high_contrast_pegs = high_contrast
	queue_redraw()

func show_result(result: Dictionary) -> void:
	last_result = result.duplicate(true)
	queue_redraw()

func clear_result() -> void:
	last_result.clear()
	queue_redraw()

func get_aim() -> float:
	return aim

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mouse_button: InputEventMouseButton = event
		if mouse_button.button_index == MOUSE_BUTTON_LEFT:
			dragging = mouse_button.pressed
			if mouse_button.pressed:
				_update_aim(mouse_button.position.x)
				grab_focus()
			accept_event()
	elif event is InputEventMouseMotion and dragging:
		var mouse_motion: InputEventMouseMotion = event
		_update_aim(mouse_motion.position.x)
		accept_event()
	elif event is InputEventKey and event.pressed and not event.echo:
		var key_event: InputEventKey = event
		if key_event.keycode in [KEY_ENTER, KEY_SPACE]:
			_request_fire()
			accept_event()
		elif key_event.keycode in [KEY_LEFT, KEY_A]:
			aim = clampf(aim - 0.08, -1.0, 1.0)
			queue_redraw()
		elif key_event.keycode in [KEY_RIGHT, KEY_D]:
			aim = clampf(aim + 0.08, -1.0, 1.0)
			queue_redraw()

func _update_aim(local_x: float) -> void:
	var usable_width: float = max(size.x - BOARD_MARGIN * 2.0, 1.0)
	aim = clampf(((local_x - BOARD_MARGIN) / usable_width) * 2.0 - 1.0, -1.0, 1.0)
	queue_redraw()

func _request_fire() -> void:
	if queue_count <= 0:
		return
	fire_requested.emit(aim)

func _update_button() -> void:
	if fire_button == null:
		return
	fire_button.disabled = queue_count <= 0
	fire_button.text = "发射  %d" % queue_count if queue_count > 0 else "等待棋谱"
	fire_button.tooltip_text = String(current_shot.get("name", "当前没有待发射弹珠"))

func _draw() -> void:
	var panel_rect: Rect2 = Rect2(Vector2.ZERO, size)
	draw_rect(panel_rect, Color(0.050, 0.058, 0.066), true)
	draw_rect(panel_rect.grow(-1.0), Color(0.26, 0.29, 0.31), false, 1.0)
	var board_top: float = HEADER_HEIGHT
	var board_bottom: float = max(size.y - FOOTER_HEIGHT, board_top + 1.0)
	var board_rect: Rect2 = Rect2(
		Vector2(BOARD_MARGIN, board_top),
		Vector2(max(size.x - BOARD_MARGIN * 2.0, 1.0), board_bottom - board_top)
	)
	draw_rect(board_rect, Color(0.025, 0.030, 0.035), true)
	_draw_header()
	_draw_pegs(board_rect)
	_draw_aim_line(board_rect)
	_draw_result_path(board_rect)

func _draw_header() -> void:
	var font: Font = ThemeDB.fallback_font
	var shot_name: String = String(current_shot.get("name", "谱弹待机"))
	draw_string(font, Vector2(16, 22), shot_name, HORIZONTAL_ALIGNMENT_LEFT, size.x - 32.0, 15, Color(0.93, 0.90, 0.78))
	var status: String = "队列 %d" % queue_count
	if not last_result.is_empty():
		status = "%d 命中  /  %d 伤害" % [int(last_result.get("hits", 0)), int(last_result.get("damage", 0))]
	elif prediction_enabled and not current_shot.is_empty():
		var prediction: Vector2i = _sample_damage_range()
		status = "队列 %d  ·  模拟 %d-%d" % [queue_count, prediction.x, prediction.y]
	draw_string(font, Vector2(16, 43), status, HORIZONTAL_ALIGNMENT_LEFT, size.x - 32.0, 12, Color(0.68, 0.72, 0.74))

func _sample_damage_range() -> Vector2i:
	var resolver: PegboardResolver = PegboardResolverScript.new()
	var preview_shot: Dictionary = current_shot.duplicate(true)
	if not current_profile.is_empty():
		preview_shot["pegboard_profile"] = current_profile.duplicate(true)
	var minimum_damage: int = 0
	var maximum_damage: int = 0
	var serial: int = int(preview_shot.get("serial", 0))
	for sample_index in range(12):
		var chapter: int = clampi(int(current_profile.get("chapter", 1)), 1, 3)
		var result: Dictionary = resolver.resolve(preview_shot, aim, serial * 104729 + sample_index * 7919, chapter)
		var ratio: float = clampf(_safe_float(preview_shot.get("ball_damage_ratio", 1.0), 1.0), 0.1, 3.0)
		var damage: int = int(round(float(result.get("damage", 0)) * ratio))
		damage += maxi(_safe_int(preview_shot.get("bonus_damage", 0), 0), 0)
		var peg_types: Array = result.get("peg_types", []) if result.get("peg_types", []) is Array else []
		damage += peg_types.count("echo") * maxi(_safe_int(preview_shot.get("echo_damage", 0), 0), 0)
		damage += peg_types.count("hazard") * maxi(_safe_int(preview_shot.get("hazard_damage", 0), 0), 0)
		minimum_damage = damage if sample_index == 0 else mini(minimum_damage, damage)
		maximum_damage = maxi(maximum_damage, damage)
	return Vector2i(maxi(minimum_damage, 0), maxi(maximum_damage, 0))

func _safe_int(value: Variant, fallback: int) -> int:
	if value is int:
		return int(value)
	if value is float and not is_nan(float(value)) and not is_inf(float(value)):
		return int(value)
	return fallback

func _safe_float(value: Variant, fallback: float) -> float:
	if value is int or value is float:
		var numeric_value: float = float(value)
		if not is_nan(numeric_value) and not is_inf(numeric_value):
			return numeric_value
	return fallback

func _draw_pegs(board_rect: Rect2) -> void:
	var pegs_value: Variant = current_profile.get("pegs", [])
	if pegs_value is Array and not pegs_value.is_empty():
		for peg_value in pegs_value:
			if not peg_value is Dictionary:
				continue
			var peg: Dictionary = peg_value
			var point: Vector2 = Vector2(
				lerpf(board_rect.position.x, board_rect.end.x, (float(peg.get("x", 0.0)) + 1.0) * 0.5),
				lerpf(board_rect.position.y, board_rect.end.y, float(peg.get("y", 0.5)))
			)
			var peg_type: String = String(peg.get("type", "normal"))
			var radius: float = 4.6 if peg_type in ["bumper", "lock", "void"] else 4.0
			draw_circle(point, radius, _peg_color(peg_type))
			if peg_type in ["lock", "resistance", "void"] or (high_contrast_pegs and peg_type != "normal"):
				draw_circle(point, radius + 2.0, _peg_color(peg_type).lightened(0.22), false, 1.0)
		return
	var x_gap: float = board_rect.size.x / float(PEG_COLUMNS + 1)
	var y_gap: float = board_rect.size.y / float(PEG_ROWS + 1)
	for row in range(PEG_ROWS):
		var offset: float = x_gap * 0.5 if row % 2 == 1 else 0.0
		for column in range(PEG_COLUMNS):
			var point: Vector2 = Vector2(
				board_rect.position.x + x_gap * float(column + 1) + offset,
				board_rect.position.y + y_gap * float(row + 1)
			)
			if point.x >= board_rect.end.x - 4.0:
				continue
			var peg_color: Color = Color(0.53, 0.57, 0.58)
			if (row + column) % 9 == 0:
				peg_color = Color(0.88, 0.67, 0.22)
			elif (row * 2 + column) % 11 == 0:
				peg_color = Color(0.86, 0.34, 0.28)
			draw_circle(point, 4.2, peg_color)

func _peg_color(peg_type: String) -> Color:
	match peg_type:
		"critical": return Color(0.98, 0.76, 0.25)
		"echo": return Color(0.40, 0.76, 0.94)
		"flame": return Color(0.94, 0.28, 0.18)
		"mist": return Color(0.55, 0.63, 0.62)
		"mirror": return Color(0.66, 0.88, 0.98)
		"bumper": return Color(0.28, 0.78, 0.56)
		"resistance": return Color(0.72, 0.42, 0.82)
		"lock": return Color(0.90, 0.62, 0.18)
		"void": return Color(0.28, 0.22, 0.38)
		"hazard": return Color(0.88, 0.20, 0.22)
		_: return Color(0.53, 0.57, 0.58)

func _draw_aim_line(board_rect: Rect2) -> void:
	var launch: Vector2 = Vector2(board_rect.get_center().x, board_rect.position.y + 8.0)
	var aim_data: Dictionary = current_profile.get("aim", {})
	var effective_aim: float = clampf(
		aim + float(aim_data.get("drift", 0.0)),
		float(aim_data.get("min", -1.0)),
		float(aim_data.get("max", 1.0))
	)
	var target: Vector2 = Vector2(
		lerpf(board_rect.position.x + 12.0, board_rect.end.x - 12.0, (effective_aim + 1.0) * 0.5),
		board_rect.position.y + board_rect.size.y * 0.36
	)
	draw_dashed_line(launch, target, Color(0.92, 0.90, 0.78, 0.82), 2.0, 7.0)
	if not is_zero_approx(effective_aim - aim):
		var requested_target: Vector2 = Vector2(
			lerpf(board_rect.position.x + 12.0, board_rect.end.x - 12.0, (aim + 1.0) * 0.5),
			board_rect.position.y + board_rect.size.y * 0.36
		)
		draw_dashed_line(launch, requested_target, Color(0.78, 0.34, 0.30, 0.55), 1.0, 5.0)
	draw_circle(launch, 6.0, Color(0.94, 0.92, 0.82))

func _draw_result_path(board_rect: Rect2) -> void:
	var balls_value: Variant = last_result.get("balls", [])
	if not balls_value is Array:
		return
	var ball_index: int = 0
	for ball_value in balls_value:
		if not ball_value is Dictionary:
			continue
		var ball: Dictionary = ball_value
		var path_value: Variant = ball.get("path", [])
		if not path_value is Array or path_value.size() < 2:
			continue
		var points: PackedVector2Array = PackedVector2Array()
		for normalized_value in path_value:
			var normalized: Vector2 = normalized_value
			points.append(Vector2(
				lerpf(board_rect.position.x, board_rect.end.x, (normalized.x + 1.0) * 0.5),
				lerpf(board_rect.position.y, board_rect.end.y, normalized.y)
			))
		var path_color: Color = [Color(0.94, 0.34, 0.26), Color(0.34, 0.64, 0.96), Color(0.94, 0.72, 0.24)][ball_index % 3]
		draw_polyline(points, path_color, 2.2, true)
		ball_index += 1
