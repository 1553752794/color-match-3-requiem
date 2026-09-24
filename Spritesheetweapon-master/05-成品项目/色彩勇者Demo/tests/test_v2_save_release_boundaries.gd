extends SceneTree

const TEST_SAVE_PATH := "user://test_v2_save_release_boundaries.json"

var failures: Array[String] = []
var passed_tests: int = 0
var game_manager: Node
var save_manager: Node
var original_save_path: String


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	game_manager = root.get_node("GameManager")
	save_manager = root.get_node("SaveManager")
	original_save_path = save_manager.run_save_path
	save_manager.run_save_path = TEST_SAVE_PATH
	save_manager.clear_run()

	_run_test("white feather chapter-used save round trip", _test_white_feather_chapter_used_round_trip)
	_run_test("current options must intersect current edges", _test_current_options_intersect_current_edges)
	_run_test("false visited and reward markers are not truthy", _test_false_markers_are_not_truthy)
	_run_test("selected character without vow resumes in vow phase", _test_character_without_vow_resume_phase)
	_run_test("interrupted nodes remain safely re-enterable", _test_interrupted_node_reentry_contract)

	save_manager.clear_run()
	save_manager.run_save_path = original_save_path
	print("V2 save release boundary tests: %d passed, %d failed" % [passed_tests, failures.size()])
	if failures.is_empty():
		quit(0)
		return
	for failure in failures:
		push_error(failure)
	quit(1)


func _run_test(test_name: String, test_callable: Callable) -> void:
	var failure_count_before: int = failures.size()
	test_callable.call()
	if failures.size() == failure_count_before:
		passed_tests += 1
		print("[PASS] %s" % test_name)
	else:
		print("[FAIL] %s" % test_name)


func _test_white_feather_chapter_used_round_trip() -> void:
	game_manager.reset_run()
	game_manager.map_template_ids = {"C1": "standard", "C2": "standard", "C3": "standard"}
	game_manager.current_node_id = "C1-01"
	game_manager.add_relic("white_feather")
	game_manager.gray_pressure = 5
	_expect(game_manager.add_gray_pressure(1) == 3, "White Feather must trigger on the first threshold crossing in C1.")
	_expect(game_manager.white_feather_used_chapters.get("C1", false) == true, "The C1 White Feather marker must be written before saving.")
	_expect(save_manager.save_run(), "The White Feather boundary fixture must save successfully.")

	game_manager.white_feather_used_chapters.clear()
	game_manager.gray_pressure = 0
	_expect(save_manager.load_run(), "The White Feather boundary fixture must load successfully.")
	_expect(game_manager.white_feather_used_chapters.get("C1", false) == true, "The C1 White Feather marker must survive a save round trip.")

	game_manager.gray_pressure = 5
	_expect(game_manager.add_gray_pressure(1) == 0, "White Feather must not trigger twice in the same chapter after loading.")
	_expect(game_manager.gray_pressure == 6, "A consumed C1 White Feather must leave the second threshold crossing at pressure 6.")


func _test_current_options_intersect_current_edges() -> void:
	game_manager.reset_run()
	game_manager.map_template_ids = {"C1": "standard", "C2": "standard", "C3": "standard"}
	game_manager.current_node_id = "C1-01"
	var snapshot: Dictionary = game_manager.create_save_snapshot()
	snapshot["current_options"] = ["C3-08", "C1-02A", "C1-02A"]

	_expect(game_manager.restore_save_snapshot(snapshot), "A structurally valid route boundary fixture must restore.")
	var actual_edges: Array[String] = _node_edges(game_manager.current_node_id)
	for option_value in game_manager.current_options:
		_expect(actual_edges.has(String(option_value)), "Restored current_options must contain only edges of the current node.")
	_expect(game_manager.current_options == ["C1-02A"], "Restored current_options must intersect edges and deduplicate destinations.")
	_expect(not game_manager.choose_node("C3-08"), "A forged cross-chapter option must not be selectable after restore.")
	_expect(game_manager.current_node_id == "C1-01", "Rejecting a forged route must not move the current node.")


func _test_false_markers_are_not_truthy() -> void:
	game_manager.reset_run()
	var snapshot: Dictionary = game_manager.create_save_snapshot()
	snapshot["current_node_id"] = "C1-01"
	snapshot["visited_nodes"] = {"C1-01": false}
	snapshot["claimed_memory_nodes"] = {"C1-01": false}

	_expect(game_manager.restore_save_snapshot(snapshot), "A false-marker boundary fixture must restore.")
	_expect(not game_manager.visited_nodes.has("C1-01"), "A false visited marker must not make a node appear visited through has().")
	_expect(not game_manager.claimed_memory_nodes.has("C1-01"), "A false reward marker must not suppress rewards through has().")


func _test_character_without_vow_resume_phase() -> void:
	game_manager.reset_run()
	game_manager.apply_start_choice("red")
	_expect(game_manager.starting_archetype_id == "red", "The character fixture must record the selected character before testing vow recovery.")
	var snapshot: Dictionary = game_manager.create_save_snapshot()

	_expect(snapshot.has("run_phase"), "Save v4 must expose run_phase so a character-selected run cannot skip vow selection.")
	_expect(String(snapshot.get("run_phase", "")) == "vow_selection", "A character-selected run without a vow must resume in vow_selection.")
	_expect(game_manager.restore_save_snapshot(snapshot), "The character-selected, vow-unconfirmed fixture must restore.")
	var restored_snapshot: Dictionary = game_manager.create_save_snapshot()
	_expect(restored_snapshot.has("run_phase"), "The restored pre-vow state must retain an explicit run_phase.")
	_expect(String(restored_snapshot.get("run_phase", "")) == "vow_selection", "Restored pre-vow state must remain in vow_selection rather than map flow.")


func _test_interrupted_node_reentry_contract() -> void:
	var fixtures: Array[Dictionary] = [
		{"node_id": "C1-01", "phase": "battle"},
		{"node_id": "C1-02B", "phase": "event"},
		{"node_id": "C1-03B", "phase": "chest"},
		{"node_id": "C1-04C", "phase": "shop"},
		{"node_id": "C1-07", "phase": "camp"},
	]
	for fixture in fixtures:
		game_manager.reset_run()
		game_manager.current_node_id = String(fixture.get("node_id", ""))
		game_manager.current_options.clear()
		var snapshot: Dictionary = game_manager.create_save_snapshot()
		_expect(game_manager.restore_save_snapshot(snapshot), "Interrupted %s node must restore structurally." % fixture.get("node_id", ""))

		var restored_snapshot: Dictionary = game_manager.create_save_snapshot()
		var phase: String = String(restored_snapshot.get("run_phase", ""))
		var phase_is_explicit: bool = restored_snapshot.has("run_phase") and phase == String(fixture.get("phase", ""))
		var route_is_reenterable: bool = not _legal_restored_targets().is_empty()
		_expect(
			phase_is_explicit or route_is_reenterable,
			"Interrupted %s node must restore to an explicit %s phase or a checkpoint with a legal re-entry route; current architecture exposes neither." % [fixture.get("node_id", ""), fixture.get("phase", "")]
		)


func _node_edges(node_id: String) -> Array[String]:
	var result: Array[String] = []
	var node: Dictionary = game_manager.get_node_data(node_id)
	for edge_value in node.get("edges", []):
		var edge_id: String = String(edge_value)
		if not result.has(edge_id):
			result.append(edge_id)
	return result


func _legal_restored_targets() -> Array[String]:
	var result: Array[String] = []
	for edge_id in _node_edges(game_manager.current_node_id):
		if game_manager.current_options.has(edge_id) and not game_manager.visited_nodes.has(edge_id):
			result.append(edge_id)
	return result


func _expect(condition: bool, message: String) -> void:
	if not condition and not failures.has(message):
		failures.append(message)
