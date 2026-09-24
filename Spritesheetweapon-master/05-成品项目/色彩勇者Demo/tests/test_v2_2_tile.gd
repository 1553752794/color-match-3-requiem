extends SceneTree

const TILE_SCRIPT = preload("res://scripts/Tile.gd")
const COLORS: Array[String] = ["gray", "red", "blue", "gold"]

class ErrorCapture extends Logger:
	var errors: Array[String] = []
	var mutex: Mutex = Mutex.new()

	func _log_error(_function: String, file: String, line: int, code: String, rationale: String, _editor_notify: bool, error_type: int, _script_backtraces: Array[ScriptBacktrace]) -> void:
		if error_type == ERROR_TYPE_WARNING:
			return
		mutex.lock()
		errors.append("%s:%d: %s %s" % [file, line, code, rationale])
		mutex.unlock()

	func count() -> int:
		mutex.lock()
		var result: int = errors.size()
		mutex.unlock()
		return result

var failures: Array[String] = []
var passed: int = 0
var fixtures: Array[Button] = []
var settings: Node
var capture: ErrorCapture = ErrorCapture.new()

func _init() -> void:
	OS.add_logger(capture)
	call_deferred("_run")

func _run() -> void:
	settings = root.get_node("SettingsManager")
	var old_reduced: bool = settings.reduced_motion
	var old_quick: bool = settings.quick_resolve
	settings.reduced_motion = false
	settings.quick_resolve = false
	await _run_test("tooltips describe pigment, charge and actual baseline effects", _test_tooltips)
	await _run_test("bitmap icons and labels fit 48 pixel tiles", _test_icon_bounds)
	await _run_test("selection stays visible in every button state", _test_selection)
	await _run_test("reduced motion skips clear and spawn transforms", _test_reduced_motion)
	await _run_test("quick resolve skips clear and spawn tweens", _test_quick_resolve)
	await _run_test("refill cancels the old clear animation", _test_refill_cancels_clear)
	await _run_test("setup cancels animation when a tile is reused", _test_setup_cancels_clear)
	await _run_test("new feedback cancels superseded feedback", _test_superseded_animation)
	await _run_test("clicks retain the current grid coordinate", _test_click)
	if OS.get_cmdline_user_args().has("--render-preview"):
		await _render_preview()
	settings.reduced_motion = old_reduced
	settings.quick_resolve = old_quick
	OS.remove_logger(capture)
	for failure in failures:
		print("[ASSERT] " + failure)
	for error in capture.errors:
		print("[RUNTIME] " + error)
	print("V2.2 tile: %d passed, %d assertions failed, %d runtime errors" % [passed, failures.size(), capture.count()])
	quit(0 if failures.is_empty() and capture.count() == 0 else 1)

func _run_test(test_name: String, test_callable: Callable) -> void:
	var before: int = failures.size()
	var errors_before: int = capture.count()
	var completed: Variant = await test_callable.call()
	_expect(completed is bool and completed == true, test_name + ": must finish without a script error")
	_expect(capture.count() == errors_before, test_name + ": runtime errors must fail the test")
	if failures.size() == before:
		passed += 1
		print("[PASS] " + test_name)
	else:
		print("[FAIL] " + test_name)
	for tile in fixtures:
		tile.free()
	fixtures.clear()
	settings.reduced_motion = false
	settings.quick_resolve = false
	await process_frame

func _new_tile(type_key: String = "gray") -> Button:
	var tile: Button = TILE_SCRIPT.new()
	tile.custom_minimum_size = Vector2(48, 48)
	tile.setup(Vector2i(2, 3), type_key)
	root.add_child(tile)
	tile.size = Vector2(48, 48)
	fixtures.append(tile)
	return tile

func _test_tooltips() -> bool:
	var tile: Button = _new_tile()
	for color_key in COLORS:
		tile.set_tile_type(color_key)
		var hint: String = tile.tooltip_text
		_expect(hint.contains("色素") and hint.contains("充能"), color_key + ": explain pigment and skill charge")
		for false_claim in ["基础伤害", "造成伤害", "伤害提高", "直接伤害"]:
			_expect(not hint.contains(false_claim), color_key + ": must not promise " + false_claim)
		match color_key:
			"red":
				_expect(hint.contains("燃烧"), "red: explain burn")
			"blue":
				_expect(hint.contains("30%") and hint.contains("冻结"), "blue: explain the actual freeze chance")
			"gold":
				_expect(hint.contains("金币") and hint.contains("上限"), "gold: explain capped coin rewards")
	tile.setup(Vector2i.ZERO, "blue")
	_expect(tile.tooltip_text.contains("30%"), "setup must refresh the tooltip")
	tile.set_tile_type("unknown")
	_expect(not tile.tooltip_text.is_empty(), "unknown colors need a safe tooltip")
	return true

func _test_icon_bounds() -> bool:
	var textures: Dictionary = {}
	for color_key in COLORS:
		var tile: Button = _new_tile(color_key)
		await process_frame
		var gem: TextureRect = tile.get_node_or_null("GemIcon") as TextureRect
		_expect(gem != null, color_key + ": needs a bitmap gem")
		if gem == null:
			continue
		_expect(gem.texture != null, color_key + ": texture must load without an editor import")
		_expect(gem.mouse_filter == Control.MOUSE_FILTER_IGNORE, "icon must not intercept clicks or tooltips")
		_expect(gem.size.x <= 36 and gem.size.y <= 36, "icon must leave room for the tile frame")
		_expect(Rect2(Vector2.ZERO, tile.size).encloses(gem.get_rect()), "icon must stay inside the tile")
		_expect(tile.get_combined_minimum_size().x <= 48 and tile.get_combined_minimum_size().y <= 48, "texture must not enlarge a 48 pixel button")
		var label: Label = tile.get_node_or_null("ColorLabel") as Label
		_expect(label != null, "color variants need a non-color identifier")
		if label != null:
			_expect(not label.text.is_empty(), "color label must not be empty")
			_expect(Rect2(Vector2.ZERO, tile.size).encloses(label.get_rect()), "color label must fit inside the tile")
			_expect(not gem.get_rect().intersects(label.get_rect()), "label must not obscure the gem")
		if gem.texture != null:
			textures[color_key] = gem.texture
			var image: Image = gem.texture.get_image()
			_expect(not image.is_empty() and image.get_used_rect().has_area(), "gem bitmap must contain visible pixels")
	if textures.has("red") and textures.has("blue"):
		_expect(textures["red"] != textures["blue"], "ruby and sapphire must retain distinct silhouettes")
	return true

func _test_selection() -> bool:
	var tile: Button = _new_tile("gold")
	var normal_width: int = tile.get_theme_stylebox("normal").border_width_left
	tile.set_selected(true)
	var selected_width: int = tile.get_theme_stylebox("normal").border_width_left
	_expect(selected_width > normal_width, "selection needs a thicker non-color cue")
	for state in ["hover", "pressed", "disabled"]:
		_expect(tile.get_theme_stylebox(state).border_width_left == selected_width, state + ": preserve selection frame")
	tile.set_selected(false)
	_expect(tile.get_theme_stylebox("normal").border_width_left == normal_width, "deselect must restore normal frame")
	return true

func _test_reduced_motion() -> bool:
	settings.reduced_motion = true
	return await _expect_instant_feedback("reduced motion")

func _test_quick_resolve() -> bool:
	settings.quick_resolve = true
	return await _expect_instant_feedback("quick resolve")

func _expect_instant_feedback(mode: String) -> bool:
	var tile: Button = _new_tile()
	tile.play_clear()
	_expect(tile.scale == Vector2.ONE and is_zero_approx(tile.modulate.a), mode + ": clear immediately without shrinking")
	_expect(get_processed_tweens().is_empty(), mode + ": clear must not queue a tween")
	tile.play_spawn()
	_expect(tile.scale == Vector2.ONE and tile.modulate == Color.WHITE, mode + ": spawn immediately visible at full scale")
	_expect(get_processed_tweens().is_empty(), mode + ": spawn must not queue a tween")
	await create_timer(0.22).timeout
	_expect(tile.scale == Vector2.ONE and tile.modulate == Color.WHITE, mode + ": no delayed animation may reset the tile")
	return true

func _test_refill_cancels_clear() -> bool:
	var tile: Button = _new_tile("red")
	tile.play_clear()
	await process_frame
	tile.set_tile_type("blue")
	await create_timer(0.22).timeout
	_expect(tile.scale == Vector2.ONE and tile.modulate == Color.WHITE, "old clear tween must not shrink or hide refilled tile")
	return true

func _test_setup_cancels_clear() -> bool:
	var tile: Button = _new_tile("red")
	tile.play_clear()
	await process_frame
	tile.setup(Vector2i(1, 4), "gold")
	await create_timer(0.22).timeout
	_expect(tile.scale == Vector2.ONE and tile.modulate == Color.WHITE, "setup must reset and cancel stale animation")
	return true

func _test_superseded_animation() -> bool:
	var tile: Button = _new_tile()
	tile.play_spawn()
	var active: Array[Tween] = get_processed_tweens()
	_expect(active.size() == 1, "normal spawn must animate")
	tile.play_clear()
	if active.size() == 1:
		_expect(not active[0].is_valid(), "clear must kill superseded spawn tween")
	active = get_processed_tweens()
	tile.play_spawn()
	for previous in active:
		_expect(not previous.is_valid(), "spawn must kill superseded clear tween")
	await create_timer(0.24).timeout
	_expect(tile.scale == Vector2.ONE and tile.modulate == Color.WHITE, "latest spawn must finish fully visible")
	tile.play_clear()
	active = get_processed_tweens()
	settings.reduced_motion = true
	tile.play_spawn()
	for previous in active:
		_expect(not previous.is_valid(), "instant feedback must also kill existing tween")
	return true

func _test_click() -> bool:
	var tile: Button = _new_tile()
	var clicks: Array[Vector2i] = []
	tile.tile_clicked.connect(func(pos: Vector2i) -> void: clicks.append(pos))
	tile.set_grid_position(Vector2i(5, 1))
	tile.pressed.emit()
	_expect(clicks == [Vector2i(5, 1)], "click must report latest coordinate exactly once")
	return true

func _render_preview() -> void:
	_expect(DisplayServer.get_name() != "headless", "render preview needs a real renderer")
	if DisplayServer.get_name() == "headless":
		return
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	root.content_scale_size = Vector2i(360, 288)
	root.size = Vector2i(360, 288)
	var background: ColorRect = ColorRect.new()
	background.color = Color(0.043, 0.051, 0.063)
	background.size = Vector2(360, 288)
	root.add_child(background)
	var states: Array[String] = ["Normal", "Selected", "Disabled", "Selected + disabled"]
	for row in range(states.size()):
		var label: Label = Label.new()
		label.text = states[row]
		label.add_theme_font_size_override("font_size", 12)
		label.position = Vector2(8, 24 + row * 64)
		root.add_child(label)
		for column in range(COLORS.size()):
			var tile: Button = _new_tile(COLORS[column])
			tile.position = Vector2(140 + column * 52, 12 + row * 64)
			tile.set_selected(row in [1, 3])
			tile.disabled = row >= 2
	await process_frame
	await RenderingServer.frame_post_draw
	var image: Image = root.get_texture().get_image()
	_expect(image != null and not image.is_empty(), "rendered preview must contain an image")
	if image != null and not image.is_empty():
		var path: String = "user://test_v2_2_tile_preview.png"
		_expect(image.save_png(path) == OK, "render preview must save")
		print("[PREVIEW] " + ProjectSettings.globalize_path(path))
	for tile in fixtures:
		tile.free()
	fixtures.clear()
	background.free()

func _expect(condition: bool, message: String) -> void:
	if not condition and not failures.has(message):
		failures.append(message)
