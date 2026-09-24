extends SceneTree

const MapTemplateResolverScript = preload("res://scripts/MapTemplateResolver.gd")

var failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_test_three_candidates_per_chapter()
	_test_same_seed_is_reproducible()
	_test_different_seeds_rotate_candidates()
	_test_dangling_edge_is_detected()
	_test_start_boss_and_reachability_are_validated()
	_test_minimum_playable_layers_are_validated()
	if failures.is_empty():
		print("Map template resolver tests: 6 passed, 0 failed")
		quit(0)
		return
	for failure in failures:
		push_error(failure)
	quit(1)


func _test_three_candidates_per_chapter() -> void:
	var catalog: Dictionary = _valid_catalog()
	var errors: Array[String] = MapTemplateResolverScript.validate_catalog(catalog, 3)
	_expect(errors.is_empty(), "Three valid candidates per chapter should pass catalog validation: %s" % str(errors))
	for chapter_id in ["C1", "C2", "C3"]:
		var chapter_templates: Dictionary = catalog.get(chapter_id, {})
		_expect(chapter_templates.size() == 3, "%s should expose exactly three test candidates." % chapter_id)
		_expect(
			not MapTemplateResolverScript.select_template(catalog, chapter_id, 20260727).is_empty(),
			"%s should resolve a valid template." % chapter_id
		)


func _test_same_seed_is_reproducible() -> void:
	var catalog: Dictionary = _valid_catalog()
	for chapter_id in ["C1", "C2", "C3"]:
		var first: Dictionary = MapTemplateResolverScript.select_template(catalog, chapter_id, -987654321)
		var second: Dictionary = MapTemplateResolverScript.select_template(catalog, chapter_id, -987654321)
		_expect(first.get("id") == second.get("id"), "%s should reproduce the same template for the same seed." % chapter_id)


func _test_different_seeds_rotate_candidates() -> void:
	var catalog: Dictionary = _valid_catalog()
	for chapter_id in ["C1", "C2", "C3"]:
		var selected_ids: Dictionary = {}
		for run_seed in range(3):
			var selected: Dictionary = MapTemplateResolverScript.select_template(catalog, chapter_id, run_seed)
			selected_ids[String(selected.get("id", ""))] = true
		_expect(selected_ids.size() == 3, "%s should rotate through all three candidates across three seeds." % chapter_id)


func _test_dangling_edge_is_detected() -> void:
	var template: Dictionary = _make_template("C1", "standard")
	var nodes: Dictionary = template.get("nodes", {})
	var start_node: Dictionary = nodes.get("C1-standard-START", {})
	start_node["edges"] = ["C1-standard-MISSING"]
	var errors: Array[String] = MapTemplateResolverScript.validate_template(template)
	_expect(_has_error(errors, "[DANGLING_EDGE]"), "A dangling edge should be reported.")


func _test_start_boss_and_reachability_are_validated() -> void:
	var missing_start: Dictionary = _make_template("C1", "risk")
	var missing_start_nodes: Dictionary = missing_start.get("nodes", {})
	missing_start_nodes.erase("C1-risk-START")
	var missing_start_errors: Array[String] = MapTemplateResolverScript.validate_template(missing_start)
	_expect(_has_error(missing_start_errors, "[MISSING_START]"), "A missing start node should be reported.")

	var missing_boss: Dictionary = _make_template("C1", "risk")
	var missing_boss_nodes: Dictionary = missing_boss.get("nodes", {})
	missing_boss_nodes.erase("C1-risk-BOSS")
	var layer_seven: Dictionary = missing_boss_nodes.get("C1-risk-L7", {})
	layer_seven["edges"] = []
	var missing_boss_errors: Array[String] = MapTemplateResolverScript.validate_template(missing_boss)
	_expect(_has_error(missing_boss_errors, "[MISSING_BOSS]"), "A missing boss node should be reported.")

	var unreachable: Dictionary = _make_template("C1", "risk")
	var unreachable_nodes: Dictionary = unreachable.get("nodes", {})
	var layer_seven_unreachable: Dictionary = unreachable_nodes.get("C1-risk-L7", {})
	layer_seven_unreachable["edges"] = []
	var unreachable_errors: Array[String] = MapTemplateResolverScript.validate_template(unreachable)
	_expect(_has_error(unreachable_errors, "[UNREACHABLE_BOSS]"), "An unreachable boss should be reported.")


func _test_minimum_playable_layers_are_validated() -> void:
	var template: Dictionary = _make_template("C2", "economy")
	var nodes: Dictionary = template.get("nodes", {})
	var layer_six: Dictionary = nodes.get("C2-economy-L6", {})
	layer_six["edges"] = ["C2-economy-BOSS"]
	nodes.erase("C2-economy-L7")
	var errors: Array[String] = MapTemplateResolverScript.validate_template(template)
	_expect(_has_error(errors, "[TOO_FEW_LAYERS]"), "A template with fewer than eight playable layers should be reported.")


func _valid_catalog() -> Dictionary:
	var catalog: Dictionary = {}
	for chapter_id in ["C1", "C2", "C3"]:
		catalog[chapter_id] = {
			"economy": _make_template(chapter_id, "economy"),
			"risk": _make_template(chapter_id, "risk"),
			"standard": _make_template(chapter_id, "standard"),
		}
	return catalog


func _make_template(chapter_id: String, template_id: String) -> Dictionary:
	var prefix: String = "%s-%s" % [chapter_id, template_id]
	var nodes: Dictionary = {
		prefix + "-START": {
			"id": prefix + "-START",
			"type": "start",
			"layer": 0,
			"edges": [prefix + "-L1"],
		},
	}
	for layer in range(1, 8):
		var node_id: String = "%s-L%d" % [prefix, layer]
		var next_id: String = "%s-L%d" % [prefix, layer + 1] if layer < 7 else prefix + "-BOSS"
		nodes[node_id] = {
			"id": node_id,
			"type": "combat" if layer % 2 == 1 else "event",
			"layer": layer,
			"edges": [next_id],
		}
	nodes[prefix + "-BOSS"] = {
		"id": prefix + "-BOSS",
		"type": "boss",
		"layer": 8,
		"edges": [],
	}
	return {
		"id": template_id,
		"chapter_id": chapter_id,
		"nodes": nodes,
	}


func _has_error(errors: Array[String], code: String) -> bool:
	for error_message in errors:
		if error_message.begins_with(code):
			return true
	return false


func _expect(condition: bool, message: String) -> void:
	if not condition and not failures.has(message):
		failures.append(message)
