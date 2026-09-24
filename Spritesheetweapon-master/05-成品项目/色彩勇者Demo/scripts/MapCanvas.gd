## Clipped, zoomable and pannable route-map viewport.
extends Control
class_name MapCanvas

signal view_changed(zoom: float, pan: Vector2)

const MIN_ZOOM: float = 0.75
const MAX_ZOOM: float = 1.60
const ZOOM_STEP: float = 0.10
const EDGE_OVERSCROLL: float = 72.0

var _content: Control
var _content_size: Vector2 = Vector2(1120.0, 500.0)
var _zoom: float = 1.0
var _pan: Vector2 = Vector2.ZERO
var _dragging: bool = false
var _drag_button: MouseButton = MOUSE_BUTTON_NONE


func _notification(what: int) -> void:
	match what:
		NOTIFICATION_MOUSE_EXIT, NOTIFICATION_FOCUS_EXIT, NOTIFICATION_VISIBILITY_CHANGED, NOTIFICATION_EXIT_TREE:
			_cancel_drag()


func _ready() -> void:
	clip_contents = true
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_default_cursor_shape = Control.CURSOR_DRAG
	_ensure_content()
	var window := get_window()
	if window != null:
		window.focus_exited.connect(_cancel_drag)
		window.mouse_exited.connect(_cancel_drag)
	resized.connect(_apply_transform)
	_apply_transform()

func get_content() -> Control:
	_ensure_content()
	return _content

func set_content_size(value: Vector2) -> void:
	_content_size = Vector2(max(value.x, 1.0), max(value.y, 1.0))
	_ensure_content()
	_content.size = _content_size
	_apply_transform()

func get_zoom() -> float:
	return _zoom

func get_pan() -> Vector2:
	return _pan

func set_view_state(zoom: float, pan: Vector2) -> void:
	_zoom = clampf(zoom, MIN_ZOOM, MAX_ZOOM)
	_pan = pan
	_apply_transform()
	view_changed.emit(_zoom, _pan)


func focus_content_point(content_point: Vector2) -> void:
	_ensure_content()
	var bounded_point := Vector2(
		clampf(content_point.x, 0.0, _content_size.x),
		clampf(content_point.y, 0.0, _content_size.y)
	)
	var centered_origin: Vector2 = (size - _content_size * _zoom) * 0.5
	_pan = size * 0.5 - bounded_point * _zoom - centered_origin
	_apply_transform()
	view_changed.emit(_zoom, _pan)


func zoom_in() -> void:
	_zoom_at(clampf(_zoom + ZOOM_STEP, MIN_ZOOM, MAX_ZOOM), size * 0.5)

func zoom_out() -> void:
	_zoom_at(clampf(_zoom - ZOOM_STEP, MIN_ZOOM, MAX_ZOOM), size * 0.5)

func reset_view() -> void:
	_zoom = 1.0
	_pan = Vector2.ZERO
	_apply_transform()
	view_changed.emit(_zoom, _pan)

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mouse_button: InputEventMouseButton = event
		if mouse_button.button_index == MOUSE_BUTTON_WHEEL_UP and mouse_button.pressed:
			_zoom_at(_zoom + ZOOM_STEP, mouse_button.position)
			accept_event()
			return
		if mouse_button.button_index == MOUSE_BUTTON_WHEEL_DOWN and mouse_button.pressed:
			_zoom_at(_zoom - ZOOM_STEP, mouse_button.position)
			accept_event()
			return
		if mouse_button.button_index in [MOUSE_BUTTON_LEFT, MOUSE_BUTTON_MIDDLE]:
			if mouse_button.pressed and _can_start_drag(mouse_button.button_index):
				_dragging = true
				_drag_button = mouse_button.button_index
				mouse_default_cursor_shape = Control.CURSOR_MOVE
				accept_event()
			elif not mouse_button.pressed and mouse_button.button_index == _drag_button:
				_cancel_drag()
				accept_event()
	elif event is InputEventMouseMotion and _dragging:
		var mouse_motion: InputEventMouseMotion = event
		_pan += mouse_motion.relative
		_apply_transform()
		view_changed.emit(_zoom, _pan)
		accept_event()

func _can_start_drag(button_index: MouseButton) -> bool:
	var hovered: Control = get_viewport().gui_get_hovered_control()
	return _can_start_drag_from(hovered, button_index)

func _can_start_drag_from(hovered: Control, button_index: MouseButton) -> bool:
	if button_index == MOUSE_BUTTON_MIDDLE:
		return true
	if hovered == null or hovered == self or hovered == _content:
		return true
	return hovered is Button and (hovered as Button).disabled


func _cancel_drag() -> void:
	_dragging = false
	_drag_button = MOUSE_BUTTON_NONE
	mouse_default_cursor_shape = Control.CURSOR_DRAG


func _zoom_at(target_zoom: float, anchor: Vector2) -> void:
	var next_zoom: float = clampf(target_zoom, MIN_ZOOM, MAX_ZOOM)
	if is_equal_approx(next_zoom, _zoom):
		return
	_ensure_content()
	var content_point: Vector2 = (anchor - _content.position) / _zoom
	_zoom = next_zoom
	var centered_origin: Vector2 = (size - _content_size * _zoom) * 0.5
	_pan = anchor - content_point * _zoom - centered_origin
	_apply_transform()
	view_changed.emit(_zoom, _pan)

func _ensure_content() -> void:
	if _content != null:
		return
	_content = Control.new()
	_content.name = "MapContent"
	_content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_content.size = _content_size
	add_child(_content)

func _apply_transform() -> void:
	if _content == null:
		return
	_clamp_pan()
	_content.scale = Vector2.ONE * _zoom
	_content.position = (size - _content_size * _zoom) * 0.5 + _pan

func _clamp_pan() -> void:
	var scaled_size: Vector2 = _content_size * _zoom
	var overflow: Vector2 = Vector2(
		max((scaled_size.x - size.x) * 0.5 + EDGE_OVERSCROLL, 0.0),
		max((scaled_size.y - size.y) * 0.5 + EDGE_OVERSCROLL, 0.0)
	)
	_pan.x = clampf(_pan.x, -overflow.x, overflow.x)
	_pan.y = clampf(_pan.y, -overflow.y, overflow.y)
