extends SceneTree

const MAIN_SCENE = preload("res://scenes/Main.tscn")
const MainScript = preload("res://scripts/Main.gd")
const GameDataScript = preload("res://scripts/GameData.gd")
const GameThemeScript = preload("res://scripts/GameTheme.gd")
const MapCanvasScript = preload("res://scripts/MapCanvas.gd")

const CHAPTER_KEYS := ["C1", "C2", "C3"]
const MAP_TEMPLATES := ["archive", "risk", "economy", "standard"]
const VIEWPORTS := [Vector2i(1280, 720), Vector2i(1600, 900)]

var failures: Array[String] = []
var main: Control
var game_manager: Node


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	main = MAIN_SCENE.instantiate() as Control
	root.add_child(main)
	await process_frame
	game_manager = root.get_node("GameManager")

	_test_template_subgraphs()
	await _test_render_geometry()
	await _test_optional_route_highlight_semantics()

	if failures.is_empty():
		print("V2 map route rendering tests passed")
		quit(0)
		return
	for failure in failures:
		push_error(failure)
	quit(1)


func _test_template_subgraphs() -> void:
	for template_id in MAP_TEMPLATES:
		for chapter_key in CHAPTER_KEYS:
			_prepare_run(template_id, chapter_key)
			var expected_ids: Array[String] = _expected_reachable_ids(chapter_key, template_id)
			var actual_ids: Array[String] = _sorted_strings(main._chapter_map_node_ids(chapter_key))
			_expect(
				actual_ids == expected_ids,
				"%s/%s 模板的章节可达子图与独立 BFS 不一致：实际 %s / 预期 %s。" % [chapter_key, template_id, actual_ids, expected_ids]
			)

			for viewport_size in VIEWPORTS:
				var content_size: Vector2 = _map_content_size(viewport_size)
				var positions: Dictionary = main._map_positions(chapter_key, content_size)
				var position_ids: Array[String] = _sorted_strings(positions.keys())
				_expect(
					position_ids == expected_ids,
					"%s/%s 在 %s 下 positions 必须只包含可达子图。" % [chapter_key, template_id, viewport_size]
				)
				_assert_position_edges_are_closed(chapter_key, template_id, positions)


func _test_render_geometry() -> void:
	for template_id in MAP_TEMPLATES:
		for chapter_key in CHAPTER_KEYS:
			_prepare_run(template_id, chapter_key)
			for viewport_size in VIEWPORTS:
				root.size = viewport_size
				game_manager.map_view_states.clear()
				main.show_map()
				await _settle()
				var map_canvas: Variant = _find_map_canvas(main)
				_expect(map_canvas != null, "%s/%s %s 必须创建 MapCanvas。" % [chapter_key, template_id, viewport_size])
				if map_canvas == null:
					continue
				var content: Control = map_canvas.get_content() as Control
				var positions: Dictionary = main._map_positions(chapter_key, content.size)
				_assert_node_rects_and_layer_gaps(chapter_key, template_id, viewport_size, content, positions)
				_assert_rendered_edges_are_closed(chapter_key, template_id, content, positions)


func _test_optional_route_highlight_semantics() -> void:
	for template_id in MAP_TEMPLATES:
		for chapter_key in CHAPTER_KEYS:
			_prepare_run(template_id, chapter_key)
			var reachable_ids: Array[String] = _sorted_strings(main._chapter_map_node_ids(chapter_key))
			var highlight_case: Dictionary = _find_shared_incoming_case(reachable_ids)
			_expect(
				not highlight_case.is_empty(),
				"%s/%s 必须存在可检验的共享入边目标，以验证 source==current_node 高亮语义。" % [chapter_key, template_id]
			)
			if highlight_case.is_empty():
				continue

			var source_id: String = String(highlight_case["source"])
			var target_id: String = String(highlight_case["target"])
			game_manager.current_node_id = source_id
			game_manager.visited_nodes.clear()
			game_manager.visited_nodes[source_id] = true
			game_manager.current_options.assign([target_id])
			root.size = VIEWPORTS[0]
			game_manager.map_view_states.clear()
			main.show_map()
			await _settle()

			var map_canvas: Variant = _find_map_canvas(main)
			_expect(map_canvas != null, "%s/%s 高亮语义测试必须创建 MapCanvas。" % [chapter_key, template_id])
			if map_canvas == null:
				continue
			var content: Control = map_canvas.get_content() as Control
			var positions: Dictionary = main._map_positions(chapter_key, content.size)
			var blue_line_count: int = 0
			for child in content.get_children():
				if not child is Line2D:
					continue
				var line: Line2D = child as Line2D
				var edge: Dictionary = _edge_for_line(line, positions)
				_expect(not edge.is_empty(), "%s/%s 的线路必须能反查到 positions 中的源/目标节点。" % [chapter_key, template_id])
				if edge.is_empty():
					continue
				var is_blue: bool = _is_optional_line(line)
				var should_be_blue: bool = String(edge["source"]) == source_id and String(edge["target"]) == target_id
				_expect(
					is_blue == should_be_blue,
					"%s/%s 高亮线路错误：%s -> %s 的 source==current_node 语义未满足。" % [chapter_key, template_id, edge["source"], edge["target"]]
				)
				if is_blue:
					blue_line_count += 1
			_expect(blue_line_count == 1, "%s/%s 当前只应有 1 条可选高亮线路，实际 %d。" % [chapter_key, template_id, blue_line_count])


func _prepare_run(template_id: String, chapter_key: String) -> void:
	game_manager.reset_run()
	game_manager.unlocked_memory_ids.assign(["M04", "M05", "M06"])
	_expect(game_manager.configure_starting_archetype("red"), "测试必须能配置红色起始角色。")
	_expect(game_manager.select_map_template_pool(template_id), "%s 模板必须可以被测试选择。" % template_id)
	var entry_id: String = _entry_id(chapter_key, template_id)
	game_manager.current_node_id = entry_id
	game_manager.current_options.assign(_node_edges_as_strings(game_manager.get_node_data(entry_id)))
	game_manager.visited_nodes.clear()
	game_manager.map_template_ids[chapter_key] = template_id


func _entry_id(chapter_key: String, template_id: String) -> String:
	var ids: Array[String] = _expected_reachable_ids(chapter_key, template_id)
	var minimum_layer: int = 2147483647
	var entry_id: String = ""
	for node_id in ids:
		var layer: int = int(game_manager.get_node_data(node_id).get("layer", 0))
		if layer < minimum_layer:
			minimum_layer = layer
			entry_id = node_id
	return entry_id


func _node_edges_as_strings(node_data: Dictionary) -> Array[String]:
	var result: Array[String] = []
	for edge_value in node_data.get("edges", []):
		result.append(String(edge_value))
	return result


func _expected_reachable_ids(chapter_key: String, template_id: String) -> Array[String]:
	var chapter_nodes: Dictionary = {}
	var minimum_layer: int = 2147483647
	var chapter_specs: Dictionary = GameDataScript.MAP_TEMPLATE_SPECS.get(chapter_key, {})
	var template_spec: Dictionary = chapter_specs.get(template_id, {})
	var edge_overrides: Dictionary = template_spec.get("edge_overrides", {})
	for node_id_value in GameDataScript.CHAPTER_NODES.keys():
		var node_id: String = String(node_id_value)
		if not node_id.begins_with(chapter_key + "-"):
			continue
		var node_data: Dictionary = GameDataScript.node(node_id)
		if edge_overrides.has(node_id):
			node_data["edges"] = Array(edge_overrides[node_id]).duplicate()
		chapter_nodes[node_id] = node_data
		minimum_layer = mini(minimum_layer, int(node_data.get("layer", 0)))

	var entry_nodes: Array[String] = []
	for node_id_value in chapter_nodes.keys():
		var node_id: String = String(node_id_value)
		if int(chapter_nodes[node_id].get("layer", 0)) == minimum_layer:
			entry_nodes.append(node_id)
	entry_nodes.sort()
	if entry_nodes.is_empty():
		return []

	var frontier: Array[String] = [entry_nodes[0]]
	var reachable: Dictionary = {}
	var cursor: int = 0
	while cursor < frontier.size():
		var node_id: String = frontier[cursor]
		cursor += 1
		if reachable.has(node_id):
			continue
		reachable[node_id] = true
		for edge_value in chapter_nodes[node_id].get("edges", []):
			var target_id: String = String(edge_value)
			if chapter_nodes.has(target_id) and not reachable.has(target_id):
				frontier.append(target_id)

	return _sorted_strings(reachable.keys())


func _assert_position_edges_are_closed(chapter_key: String, template_id: String, positions: Dictionary) -> void:
	for source_value in positions.keys():
		var source_id: String = String(source_value)
		var node_data: Dictionary = game_manager.get_node_data(source_id)
		for edge_value in node_data.get("edges", []):
			var target_id: String = String(edge_value)
			if not target_id.begins_with(chapter_key + "-"):
				continue
			_expect(
				positions.has(target_id),
				"%s positions 边目标缺失：%s -> %s。" % [template_id, source_id, target_id]
			)


func _assert_node_rects_and_layer_gaps(chapter_key: String, template_id: String, viewport_size: Vector2i, content: Control, positions: Dictionary) -> void:
	var content_rect := Rect2(Vector2.ZERO, content.size)
	var layer_rects: Dictionary = {}
	var button_count: int = 0
	for child in content.get_children():
		if not child is Button:
			continue
		button_count += 1
		var button: Button = child as Button
		var node_id: String = _node_id_for_position(button.position, positions)
		_expect(node_id != "", "%s %s 的地图按钮必须对应 positions 节点。" % [template_id, viewport_size])
		var rect := Rect2(button.position, button.size)
		_expect(
			rect.position.x >= -0.01 and rect.position.y >= -0.01 and rect.end.x <= content_rect.end.x + 0.01 and rect.end.y <= content_rect.end.y + 0.01,
			"%s/%s %s 节点 %s 越出地图内容边界：%s / %s。" % [chapter_key, template_id, viewport_size, node_id, rect, content_rect]
		)
		if node_id == "":
			continue
		var layer: int = int(game_manager.get_node_data(node_id).get("layer", 0))
		if not layer_rects.has(layer):
			layer_rects[layer] = []
		var rects: Array = layer_rects[layer]
		rects.append(rect)

	var positions_ids: Array[String] = _sorted_strings(positions.keys())
	_expect(button_count == positions_ids.size(), "%s %s 节点按钮数量必须等于 positions 数量。" % [template_id, viewport_size])
	for layer_value in layer_rects.keys():
		var rects: Array = layer_rects[layer_value]
		for left_value in rects:
			var left_rect: Rect2 = left_value
			for right_value in rects:
				var right_rect: Rect2 = right_value
				if right_rect.position.x <= left_rect.position.x:
					continue
				var gap: float = right_rect.position.x - left_rect.end.x
				_expect(
					gap + 0.01 >= float(MainScript.MAP_NODE_GUTTER),
					"%s/%s %s 同层节点间距不足：%.2f < %.2f。" % [chapter_key, template_id, viewport_size, gap, MainScript.MAP_NODE_GUTTER]
				)


func _assert_rendered_edges_are_closed(chapter_key: String, template_id: String, content: Control, positions: Dictionary) -> void:
	var expected_edge_count: int = 0
	for source_value in positions.keys():
		var source_id: String = String(source_value)
		for edge_value in game_manager.get_node_data(source_id).get("edges", []):
			var target_id: String = String(edge_value)
			if target_id.begins_with(chapter_key + "-") and positions.has(target_id):
				expected_edge_count += 1

	var actual_edge_count: int = 0
	for child in content.get_children():
		if not child is Line2D:
			continue
		actual_edge_count += 1
		var edge: Dictionary = _edge_for_line(child as Line2D, positions)
		_expect(not edge.is_empty(), "%s 线路端点必须分别落在 positions 的节点上。" % template_id)
	_expect(
		actual_edge_count == expected_edge_count,
		"%s 实际绘制线路数必须等于 positions 内部边数：实际 %d / 预期 %d。" % [template_id, actual_edge_count, expected_edge_count]
	)


func _find_shared_incoming_case(node_ids: Array[String]) -> Dictionary:
	for source_id in node_ids:
		var source_data: Dictionary = game_manager.get_node_data(source_id)
		for edge_value in source_data.get("edges", []):
			var target_id: String = String(edge_value)
			if not node_ids.has(target_id) or not game_manager.is_node_available_for_character(target_id):
				continue
			var other_incoming: bool = false
			for other_id in node_ids:
				if other_id == source_id:
					continue
				var other_edges: Array = game_manager.get_node_data(other_id).get("edges", [])
				if other_edges.has(target_id):
					other_incoming = true
					break
			if other_incoming:
				return {"source": source_id, "target": target_id}
	return {}


func _edge_for_line(line: Line2D, positions: Dictionary) -> Dictionary:
	if line.points.size() < 2:
		return {}
	var start: Vector2 = line.points[0]
	var end: Vector2 = line.points[1]
	for source_value in positions.keys():
		var source_id: String = String(source_value)
		var source_position: Vector2 = positions[source_id]
		var expected_start: Vector2 = source_position + Vector2(MainScript.MAP_NODE_SIZE.x * 0.5, 0.0)
		if start.distance_to(expected_start) > 0.1:
			continue
		for target_value in positions.keys():
			var target_id: String = String(target_value)
			var target_position: Vector2 = positions[target_id]
			var expected_end: Vector2 = target_position + Vector2(MainScript.MAP_NODE_SIZE.x * 0.5, MainScript.MAP_NODE_SIZE.y)
			if end.distance_to(expected_end) <= 0.1:
				return {"source": source_id, "target": target_id}
	return {}


func _is_optional_line(line: Line2D) -> bool:
	var blue: Color = GameThemeScript.BLUE
	blue.a = 0.88
	return line.default_color.is_equal_approx(blue)


func _find_map_canvas(node: Node) -> Variant:
	if node.get_script() == MapCanvasScript:
		return node
	for child in node.get_children():
		var result: Variant = _find_map_canvas(child)
		if result != null:
			return result
	return null


func _node_id_for_position(position: Vector2, positions: Dictionary) -> String:
	for node_id_value in positions.keys():
		var node_id: String = String(node_id_value)
		var expected_position: Vector2 = positions[node_id]
		if position.distance_to(expected_position) <= 0.1:
			return node_id
	return ""


func _map_content_size(viewport_size: Vector2i) -> Vector2:
	return Vector2(
		maxf(float(viewport_size.x) - 72.0, 980.0),
		maxf(float(viewport_size.y) - 190.0, MainScript.MAP_CONTENT_MIN_HEIGHT)
	)


func _sorted_strings(values: Array) -> Array[String]:
	var result: Array[String] = []
	for value in values:
		result.append(String(value))
	result.sort()
	return result


func _settle() -> void:
	await process_frame
	await process_frame
	await process_frame


func _expect(condition: bool, message: String) -> void:
	if not condition and not failures.has(message):
		failures.append(message)
