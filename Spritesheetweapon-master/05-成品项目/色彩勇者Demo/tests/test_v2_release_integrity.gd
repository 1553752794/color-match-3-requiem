extends SceneTree

const GameDataScript = preload("res://scripts/GameData.gd")
const SpectrumManagerScript = preload("res://scripts/SpectrumManager.gd")

const CHAPTER_IDS: Array[String] = ["C1", "C2", "C3"]
const TEMPLATE_IDS: Array[String] = ["standard", "risk", "economy", "archive"]
const EXPECTED_TEMPLATE_COUNT: int = 12
const EXPECTED_EXPORT_PATH: String = "build/windows/ColorHero-Match3Requiem-2.3.0.exe"
const PROJECT_TEXT_FILES: Array[String] = ["gd", "tscn", "tres", "godot", "cfg"]
const RUNTIME_HOOK_KEYS: Array[String] = ["runtime_hook", "runtime_handler"]

var failures: Array[String] = []
var passed_tests: int = 0


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_run_test("exact content counts", _test_exact_content_counts)
	_run_test("all resource paths exist", _test_all_resource_paths_exist)
	_run_test("all map templates reach bosses", _test_all_templates_reach_bosses)
	_run_test("character routes remain legal", _test_character_routes)
	_run_test("droppable relics have runtime handling", _test_droppable_relic_hooks)
	_run_test("trajectory lens runtime preview", _test_trajectory_lens_preview)
	_run_test("project and export versions", _test_project_and_export_versions)

	print(
		"V2 release integrity tests: %d passed, %d failed"
		% [passed_tests, failures.size()]
	)
	if failures.is_empty():
		quit(0)
		return
	for failure in failures:
		push_error(failure)
	quit(1)


func _run_test(test_name: String, test_callable: Callable) -> void:
	var before: int = failures.size()
	test_callable.call()
	if failures.size() == before:
		passed_tests += 1
		print("[PASS] %s" % test_name)
	else:
		print("[FAIL] %s" % test_name)


func _test_exact_content_counts() -> void:
	_expect(
		GameDataScript.STARTING_ARCHETYPES.size() == 5,
		"STARTING_ARCHETYPES must contain exactly 5 characters."
	)
	_expect(GameDataScript.SPECTRA.size() == 119, "SPECTRA must contain exactly 119 entries.")
	_expect(GameDataScript.RELICS.size() == 72, "RELICS must contain exactly 72 entries.")
	_expect(GameDataScript.EVENTS.size() == 54, "EVENTS must contain exactly 54 entries.")
	_expect(GameDataScript.ENCOUNTERS.size() == 39, "ENCOUNTERS must contain exactly 39 entries.")
	_expect(
		GameDataScript.CHAPTER_NODES.size() == 79,
		"CHAPTER_NODES must contain exactly 79 registered nodes."
	)
	_expect(
		GameDataScript.MAP_TEMPLATE_SPECS.size() == CHAPTER_IDS.size(),
		"MAP_TEMPLATE_SPECS must contain exactly three chapters."
	)
	var template_count: int = 0
	for chapter_id in CHAPTER_IDS:
		var chapter_templates_value: Variant = GameDataScript.MAP_TEMPLATE_SPECS.get(chapter_id, {})
		if not chapter_templates_value is Dictionary:
			_expect(false, "%s map template entry must be a Dictionary." % chapter_id)
			continue
		var chapter_templates: Dictionary = chapter_templates_value
		_expect(
			chapter_templates.size() == TEMPLATE_IDS.size(),
			"%s must expose exactly four map templates." % chapter_id
		)
		for template_id in TEMPLATE_IDS:
			_expect(
				chapter_templates.has(template_id),
				"%s must expose the %s map template." % [chapter_id, template_id]
			)
		template_count += chapter_templates.size()
	_expect(
		template_count == EXPECTED_TEMPLATE_COUNT,
		"The project must expose exactly 12 map templates."
	)


func _test_all_resource_paths_exist() -> void:
	var files: Array[String] = []
	_collect_project_files("res://", files)
	var runtime_source: String = ""
	var checked_paths: Dictionary = {}
	for file_path in files:
		var source: String = FileAccess.get_file_as_string(file_path)
		if file_path.begins_with("res://scripts/") and not file_path.ends_with("/GameData.gd"):
			runtime_source += source + "\n"
		for resource_path in _extract_resource_paths(source):
			checked_paths[resource_path] = true

	for resource_path_value in checked_paths.keys():
		var resource_path: String = String(resource_path_value)
		_expect(
			FileAccess.file_exists(resource_path) or DirAccess.open(resource_path) != null,
			"Referenced resource does not exist: %s" % resource_path
		)

	_expect(
		FileAccess.file_exists("res://scenes/Main.tscn"),
		"The configured main scene must exist."
	)
	_expect(
		not runtime_source.is_empty(),
		"Runtime source scan must include at least one script."
	)


func _test_all_templates_reach_bosses() -> void:
	var catalog: Dictionary = GameDataScript.map_template_catalog()
	_expect(catalog.size() == CHAPTER_IDS.size(), "Resolved map catalog must contain all chapters.")
	for chapter_id in CHAPTER_IDS:
		var templates: Dictionary = catalog.get(chapter_id, {})
		_expect(
			templates.size() == TEMPLATE_IDS.size(),
			"Resolved %s map catalog must contain four templates." % chapter_id
		)
		for template_id in TEMPLATE_IDS:
			_expect(
				templates.has(template_id),
				"Resolved %s map catalog must contain the %s template." % [chapter_id, template_id]
			)
		for template_id_value in templates.keys():
			var template_id: String = String(template_id_value)
			var template_value: Variant = templates[template_id_value]
			if not template_value is Dictionary:
				_expect(false, "Resolved template %s/%s must be a Dictionary." % [chapter_id, template_id])
				continue
			var template: Dictionary = template_value
			var nodes_value: Variant = template.get("nodes", {})
			if not nodes_value is Dictionary:
				_expect(false, "Resolved template %s/%s must contain nodes." % [chapter_id, template_id])
				continue
			var nodes: Dictionary = nodes_value
			_expect(
				not nodes.is_empty(),
				"Resolved template %s/%s must contain nodes." % [chapter_id, template_id]
			)
			_validate_template_edges(nodes, chapter_id, template_id)
			var starts: Array[String] = _node_ids_of_type(nodes, "start")
			var bosses: Array[String] = _node_ids_of_type(nodes, "boss")
			_expect(
				starts.size() == 1,
				"Template %s/%s must contain exactly one entry node." % [chapter_id, template_id]
			)
			_expect(
				bosses.size() == 1,
				"Template %s/%s must contain exactly one Boss node." % [chapter_id, template_id]
			)
			if starts.size() != 1 or bosses.size() != 1:
				continue
			_expect(
				_is_reachable(nodes, starts[0], bosses[0]),
				"Template %s/%s entry must reach its Boss." % [chapter_id, template_id]
			)


func _test_character_routes() -> void:
	var catalog: Dictionary = GameDataScript.map_template_catalog()
	for character_id_value in GameDataScript.STARTING_ARCHETYPES.keys():
		var character_id: String = String(character_id_value)
		for chapter_id in CHAPTER_IDS:
			var templates: Dictionary = catalog.get(chapter_id, {})
			for template_id_value in templates.keys():
				var template_id: String = String(template_id_value)
				var template_value: Variant = templates[template_id_value]
				if not template_value is Dictionary:
					_expect(false, "Resolved template %s/%s must be a Dictionary." % [chapter_id, template_id])
					continue
				var template: Dictionary = template_value
				var nodes_value: Variant = template.get("nodes", {})
				if not nodes_value is Dictionary:
					continue
				var nodes: Dictionary = nodes_value
				var starts: Array[String] = _node_ids_of_type(nodes, "start")
				var bosses: Array[String] = _node_ids_of_type(nodes, "boss")
				if starts.size() != 1 or bosses.size() != 1:
					continue
				_expect(
					_is_character_route_reachable(nodes, starts[0], bosses[0], character_id),
					"Character %s must retain a legal route in %s/%s."
					% [character_id, chapter_id, template_id]
				)


func _test_droppable_relic_hooks() -> void:
	var runtime_source: String = ""
	var script_files: Array[String] = []
	_collect_project_files("res://scripts", script_files)
	for script_path in script_files:
		if script_path.ends_with("/GameData.gd"):
			continue
		runtime_source += FileAccess.get_file_as_string(script_path) + "\n"

	var droppable: Dictionary = _droppable_relic_ids()
	_expect(not droppable.is_empty(), "The droppable relic pool must not be empty.")
	for relic_id_value in droppable.keys():
		var relic_id: String = String(relic_id_value)
		var relic_data: Dictionary = GameDataScript.RELICS.get(relic_id, {})
		var has_literal_hook: bool = (
			runtime_source.contains('"%s"' % relic_id)
			or runtime_source.contains("'%s'" % relic_id)
		)
		var has_declared_hook: bool = false
		for hook_key in RUNTIME_HOOK_KEYS:
			var hook_id: String = String(relic_data.get(hook_key, "")).strip_edges()
			if not hook_id.is_empty() and runtime_source.contains(hook_id):
				has_declared_hook = true
		_expect(
			has_literal_hook or has_declared_hook,
			"Droppable relic %s must have a runtime hook or explicit data-driven handler."
			% relic_id
		)


func _test_trajectory_lens_preview() -> void:
	var manager: SpectrumManager = SpectrumManagerScript.new()
	var hand: Array[Dictionary] = [
		{"instance_id": "trajectory_red", "card_id": "ember_slash", "level": 0},
		{"instance_id": "trajectory_blue", "card_id": "frost_guard", "level": 0},
	]
	manager.begin_turn(hand, false, true)
	_expect(
		_count_trajectory_markers(manager.get_card_states()) == 0,
		"Trajectory lens must wait for observable progress before selecting a preview target."
	)
	manager.register_clear_event(
		{"type": "red", "count": 4, "cascade": 1, "active": true},
		0,
		{"moves_left": 3}
	)
	var states: Array[Dictionary] = manager.get_card_states()
	_expect(
		_count_trajectory_markers(states) == 1,
		"Trajectory lens must mark exactly one closest incomplete spectrum."
	)
	_expect(
		states[0].get("trajectory_preview", false) == true
			and float(states[0].get("trajectory_progress", 0.0)) >= 0.79,
		"Trajectory lens must mark the spectrum with the highest live completion progress."
	)
	manager.begin_turn(hand, false, false)
	_expect(
		_count_trajectory_markers(manager.get_card_states()) == 0,
		"Trajectory preview must be disabled when the relic is not equipped."
	)


func _count_trajectory_markers(states: Array[Dictionary]) -> int:
	var count: int = 0
	for state in states:
		if state.get("trajectory_preview", false) == true:
			count += 1
	return count


func _test_project_and_export_versions() -> void:
	var project_path: String = "res://project.godot"
	var export_path: String = "res://export_presets.cfg"
	_expect(FileAccess.file_exists(project_path), "project.godot must exist.")
	_expect(FileAccess.file_exists(export_path), "export_presets.cfg must exist.")
	if not FileAccess.file_exists(project_path) or not FileAccess.file_exists(export_path):
		return

	var project_source: String = FileAccess.get_file_as_string(project_path)
	var export_source: String = FileAccess.get_file_as_string(export_path)
	_expect(
		project_source.contains('config/version="2.3.0"'),
		"project.godot version must be 2.3.0."
	)
	_expect(
		export_source.contains('name="Windows 2.3.0 Release"'),
		"The Windows export preset must be named Windows 2.3.0 Release."
	)
	_expect(
		export_source.contains('application/file_version="2.3.0.0"'),
		"The Windows export file version must be 2.3.0.0."
	)
	_expect(
		export_source.contains('application/product_version="2.3.0"'),
		"The Windows export product version must be 2.3.0."
	)
	_expect(
		export_source.contains('export_path="%s"' % EXPECTED_EXPORT_PATH),
		"The Windows export target must be %s." % EXPECTED_EXPORT_PATH
	)
	_expect(
		EXPECTED_EXPORT_PATH.get_file() == "ColorHero-Match3Requiem-2.3.0.exe",
		"The export target filename must be the 2.3.0 release filename."
	)
	var config: ConfigFile = ConfigFile.new()
	_expect(config.load(export_path) == OK, "Export config must parse.")
	var excluded: PackedStringArray = String(config.get_value("preset.0", "exclude_filter", "")).split(",")
	for pattern in ["build/*", "artifacts/*", "assets/external/*", "Godot/*"]:
		_expect(excluded.has(pattern), "Release must exclude development artifacts: " + pattern)


func _droppable_relic_ids() -> Dictionary:
	var droppable: Dictionary = {}
	for relic_id_value in GameDataScript.RELICS.keys():
		var relic_id: String = String(relic_id_value)
		var relic_value: Variant = GameDataScript.RELICS[relic_id_value]
		if not relic_value is Dictionary:
			_expect(false, "RELICS.%s must be a Dictionary." % relic_id)
			continue
		var rarity: String = String(relic_value.get("rarity", ""))
		if rarity in ["common", "rare"]:
			droppable[relic_id] = true

	for encounter_value in GameDataScript.ENCOUNTERS.values():
		if not encounter_value is Dictionary:
			continue
		var boss_relic_id: String = String(encounter_value.get("boss_relic", "")).strip_edges()
		if not boss_relic_id.is_empty():
			droppable[boss_relic_id] = true

	for event_value in GameDataScript.EVENTS.values():
		if not event_value is Dictionary:
			continue
		for choice_value in event_value.get("choices", []):
			if not choice_value is Dictionary:
				continue
			var choice: Dictionary = choice_value
			var exact_relic_id: String = String(choice.get("relic_id", "")).strip_edges()
			if not exact_relic_id.is_empty():
				droppable[exact_relic_id] = true
			var relic_pool: Variant = choice.get("relic_pool", [])
			if not relic_pool is Array:
				continue
			for pool_value in relic_pool:
				var pool_id: String = String(pool_value)
				if GameDataScript.RELICS.has(pool_id):
					droppable[pool_id] = true
				else:
					for relic_id_value in GameDataScript.RELICS.keys():
						var relic: Dictionary = GameDataScript.RELICS[relic_id_value]
						if String(relic.get("rarity", "")) == pool_id:
							droppable[String(relic_id_value)] = true
	return droppable


func _node_ids_of_type(nodes: Dictionary, node_type: String) -> Array[String]:
	var result: Array[String] = []
	for node_id_value in nodes.keys():
		var node_value: Variant = nodes[node_id_value]
		if node_value is Dictionary and String(node_value.get("type", "")) == node_type:
			result.append(String(node_id_value))
	return result


func _validate_template_edges(nodes: Dictionary, chapter_id: String, template_id: String) -> void:
	for node_id_value in nodes.keys():
		var node_id: String = String(node_id_value)
		var node_value: Variant = nodes[node_id_value]
		if not node_value is Dictionary:
			_expect(false, "Template %s/%s node %s must be a Dictionary." % [chapter_id, template_id, node_id])
			continue
		var node: Dictionary = node_value
		var edges_value: Variant = node.get("edges", [])
		if not edges_value is Array:
			_expect(false, "Template %s/%s node %s edges must be an Array." % [chapter_id, template_id, node_id])
			continue
		for edge_value in edges_value:
			var edge_id: String = String(edge_value).strip_edges()
			_expect(
				nodes.has(edge_id),
				"Template %s/%s node %s points to missing node %s." % [chapter_id, template_id, node_id, edge_id]
			)


func _is_reachable(nodes: Dictionary, start_id: String, target_id: String) -> bool:
	var queue: Array[String] = [start_id]
	var visited: Dictionary = {}
	while not queue.is_empty():
		var node_id: String = String(queue.pop_front())
		if visited.has(node_id):
			continue
		visited[node_id] = true
		if node_id == target_id:
			return true
		var node_value: Variant = nodes.get(node_id, {})
		if not node_value is Dictionary:
			continue
		for edge_value in node_value.get("edges", []):
			var edge_id: String = String(edge_value)
			if nodes.has(edge_id) and not visited.has(edge_id):
				queue.append(edge_id)
	return false


func _is_character_route_reachable(
	nodes: Dictionary,
	start_id: String,
	target_id: String,
	character_id: String
) -> bool:
	var queue: Array[String] = [start_id]
	var visited: Dictionary = {}
	while not queue.is_empty():
		var node_id: String = String(queue.pop_front())
		if visited.has(node_id):
			continue
		var node_value: Variant = nodes.get(node_id, {})
		if not node_value is Dictionary or not _character_can_enter(node_value, character_id):
			continue
		visited[node_id] = true
		if node_id == target_id:
			return true
		for edge_value in node_value.get("edges", []):
			var edge_id: String = String(edge_value)
			if nodes.has(edge_id) and not visited.has(edge_id):
				queue.append(edge_id)
	return false


func _character_can_enter(node: Dictionary, character_id: String) -> bool:
	var character_ids: Variant = node.get("character_ids", [])
	if not node.has("character_ids"):
		return true
	if not character_ids is Array:
		return false
	if character_ids.is_empty():
		return true
	return character_ids.has(character_id)


func _collect_project_files(dir_path: String, result: Array[String]) -> void:
	var directory: DirAccess = DirAccess.open(dir_path)
	if directory == null:
		return
	directory.list_dir_begin()
	var entry_name: String = directory.get_next()
	while not entry_name.is_empty():
		var child_path: String = dir_path.path_join(entry_name)
		if directory.current_is_dir():
			if not entry_name.begins_with(".") and not ["artifacts", "build"].has(entry_name):
				_collect_project_files(child_path, result)
		else:
			if entry_name.get_extension() in PROJECT_TEXT_FILES:
				result.append(child_path)
		entry_name = directory.get_next()
	directory.list_dir_end()


func _extract_resource_paths(source: String) -> Array[String]:
	var result: Array[String] = []
	var cursor: int = 0
	while cursor < source.length():
		var start: int = source.find("res://", cursor)
		if start < 0:
			break
		var end: int = source.find("\"", start)
		var single_quote_end: int = source.find("'", start)
		if end < 0 or (single_quote_end >= 0 and single_quote_end < end):
			end = single_quote_end
		if end < 0:
			end = source.length()
		var resource_path: String = source.substr(start, end - start).strip_edges()
		if resource_path.length() > "res://".length() and not result.has(resource_path):
			result.append(resource_path)
		cursor = maxi(end + 1, start + "res://".length())
	return result


func _expect(condition: bool, message: String) -> void:
	if not condition and not failures.has(message):
		failures.append(message)
