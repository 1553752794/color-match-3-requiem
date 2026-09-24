extends SceneTree

const MapCanvasScript = preload("res://scripts/MapCanvas.gd")

var failures: Array[String] = []

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	_test_zoom_limits()
	_test_wheel_zoom()
	_test_node_drag_policy()
	_test_view_state_and_reset()
	_test_pan_is_bounded()
	_test_focus_content_point()
	_test_drag_cleanup_notifications()
	if failures.is_empty():
		print("Map canvas tests passed: 7")
		quit(0)
		return
	for failure in failures:
		push_error(failure)
	quit(1)

func _new_canvas() -> Variant:
	var canvas: Variant = MapCanvasScript.new()
	canvas.size = Vector2(800, 420)
	root.add_child(canvas)
	canvas.set_content_size(Vector2(1200, 600))
	return canvas

func _test_zoom_limits() -> void:
	var canvas: Variant = _new_canvas()
	for index in range(20):
		canvas.zoom_in()
	_expect(is_equal_approx(canvas.get_zoom(), MapCanvasScript.MAX_ZOOM), "地图放大必须限制在 1.60x。")
	for index in range(30):
		canvas.zoom_out()
	_expect(is_equal_approx(canvas.get_zoom(), MapCanvasScript.MIN_ZOOM), "地图缩小必须限制在 0.75x。")
	canvas.free()

func _test_wheel_zoom() -> void:
	var canvas: Variant = _new_canvas()
	var wheel: InputEventMouseButton = InputEventMouseButton.new()
	wheel.button_index = MOUSE_BUTTON_WHEEL_UP
	wheel.pressed = true
	wheel.position = Vector2(400, 210)
	canvas._gui_input(wheel)
	_expect(is_equal_approx(canvas.get_zoom(), 1.10), "鼠标滚轮向上必须按固定步长放大地图。")
	canvas.free()

func _test_node_drag_policy() -> void:
	var canvas: Variant = _new_canvas()
	var disabled_node: Button = Button.new()
	disabled_node.disabled = true
	var active_node: Button = Button.new()
	_expect(canvas._can_start_drag_from(disabled_node, MOUSE_BUTTON_LEFT), "禁用或已完成节点必须允许左键起拖。")
	_expect(not canvas._can_start_drag_from(active_node, MOUSE_BUTTON_LEFT), "可选节点必须保留左键点击选路。")
	_expect(canvas._can_start_drag_from(active_node, MOUSE_BUTTON_MIDDLE), "中键必须能从任意节点起拖。")
	disabled_node.free()
	active_node.free()
	canvas.free()

func _test_view_state_and_reset() -> void:
	var canvas: Variant = _new_canvas()
	canvas.set_view_state(1.30, Vector2(90, 45))
	_expect(is_equal_approx(canvas.get_zoom(), 1.30), "地图应恢复保存的缩放比例。")
	_expect(canvas.get_pan().is_equal_approx(Vector2(90, 45)), "地图应恢复保存的拖拽偏移。")
	canvas.reset_view()
	_expect(is_equal_approx(canvas.get_zoom(), 1.0) and canvas.get_pan() == Vector2.ZERO, "复位应恢复 1.0x 与中心位置。")
	canvas.free()

func _test_pan_is_bounded() -> void:
	var canvas: Variant = _new_canvas()
	canvas.set_view_state(1.60, Vector2(5000, -5000))
	var pan: Vector2 = canvas.get_pan()
	_expect(pan.is_equal_approx(Vector2(632, -342)), "地图拖拽必须严格限制在内容边缘与 72 像素回弹区内。")
	canvas.free()

func _test_focus_content_point() -> void:
	var canvas: Variant = _new_canvas()
	canvas.set_view_state(1.30, Vector2.ZERO)
	var content_point := Vector2(500, 260)
	canvas.focus_content_point(content_point)
	var focused_position: Vector2 = canvas.get_content().position + content_point * canvas.get_zoom()
	_expect(focused_position.is_equal_approx(canvas.size * 0.5), "指定内容点必须聚焦到地图视口中心。")
	_expect(is_equal_approx(canvas.get_zoom(), 1.30), "聚焦内容点不得改变当前缩放比例。")
	canvas.free()

func _test_drag_cleanup_notifications() -> void:
	var canvas: Variant = _new_canvas()
	_assert_drag_cleanup(canvas, Control.NOTIFICATION_FOCUS_EXIT, "控件失焦")
	_assert_drag_cleanup(canvas, Control.NOTIFICATION_MOUSE_EXIT, "鼠标离开控件")
	_assert_window_signal_cleanup(canvas, "mouse_exited", "鼠标离开窗口")
	_assert_window_signal_cleanup(canvas, "focus_exited", "窗口失焦")
	_assert_drag_cleanup(canvas, CanvasItem.NOTIFICATION_VISIBILITY_CHANGED, "可见性通知")
	_assert_drag_cleanup(canvas, Node.NOTIFICATION_EXIT_TREE, "退出场景树")
	canvas.free()

func _assert_window_signal_cleanup(canvas: Variant, signal_name: String, label: String) -> void:
	canvas._dragging = true
	canvas._drag_button = MOUSE_BUTTON_LEFT
	canvas.mouse_default_cursor_shape = Control.CURSOR_MOVE
	var window: Window = canvas.get_window()
	window.get(signal_name).emit()
	_expect(not canvas._dragging, "%s必须终止地图拖拽。" % label)
	_expect(canvas._drag_button == MOUSE_BUTTON_NONE, "%s必须清空拖拽按键。" % label)
	_expect(canvas.mouse_default_cursor_shape == Control.CURSOR_DRAG, "%s必须恢复拖拽光标。" % label)

func _assert_drag_cleanup(canvas: Variant, notification: int, label: String) -> void:
	canvas._dragging = true
	canvas._drag_button = MOUSE_BUTTON_LEFT
	canvas.mouse_default_cursor_shape = Control.CURSOR_MOVE
	canvas._notification(notification)
	_expect(not canvas._dragging, "%s必须终止地图拖拽。" % label)
	_expect(canvas._drag_button == MOUSE_BUTTON_NONE, "%s必须清空拖拽按键。" % label)
	_expect(canvas.mouse_default_cursor_shape == Control.CURSOR_DRAG, "%s必须恢复拖拽光标。" % label)

func _expect(condition: bool, message: String) -> void:
	if not condition and not failures.has(message):
		failures.append(message)
