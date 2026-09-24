extends SceneTree

var failures: Array[String] = []
var game_manager: Node
var save_manager: Node
var original_unlocked_memory_ids: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	game_manager = root.get_node("GameManager")
	save_manager = root.get_node("SaveManager")
	original_unlocked_memory_ids.assign(game_manager.unlocked_memory_ids)
	game_manager.reset_run()
	_test_locked_archive_falls_back_to_vow_pool()
	_test_completed_memory_set_unlocks_archive()
	_test_seed_selection_respects_archive_gate()
	_test_run_save_v4_template_whitelist()
	game_manager.unlocked_memory_ids.assign(original_unlocked_memory_ids)

	if failures.is_empty():
		print("V2.0 archive map tests: 4 passed, 0 failed")
		quit(0)
		return
	for failure in failures:
		push_error(failure)
	quit(1)


func _test_locked_archive_falls_back_to_vow_pool() -> void:
	game_manager.unlocked_memory_ids.assign(["M01", "M02", "M03"])
	game_manager.selected_vow_id = "vow_fracture"
	game_manager._select_map_templates({"C1": "archive", "C2": "archive", "C3": "unknown"})
	_expect(not game_manager.is_archive_map_pool_unlocked(), "The complete starter memory set must not unlock the archive pool by itself.")
	_expect(
		game_manager.map_template_ids == {"C1": "risk", "C2": "risk", "C3": "risk"},
		"Locked archive and unknown templates must fall back to the selected vow's risk pool."
	)
	_expect(not game_manager.select_map_template_pool("archive"), "The archive pool entry must reject a profile without a complete memory set.")
	_expect(game_manager.map_template_ids == {"C1": "risk", "C2": "risk", "C3": "risk"}, "A rejected archive selection must keep the vow fallback for every chapter.")
	var forged_snapshot: Dictionary = game_manager.create_save_snapshot()
	forged_snapshot["map_template_ids"] = {"C1": "archive", "C2": "archive"}
	forged_snapshot["unlocked_memory_ids"] = ["M04", "M05", "M06"]
	_expect(game_manager.restore_save_snapshot(forged_snapshot), "A structurally valid archive snapshot must restore with safe map fallback.")
	_expect(
		game_manager.map_template_ids == {"C1": "risk", "C2": "risk", "C3": "risk"},
		"Run data must not forge archive access, and a missing chapter template must also use the vow fallback."
	)


func _test_completed_memory_set_unlocks_archive() -> void:
	game_manager.unlocked_memory_ids.assign(["M04", "M05", "M06"])
	game_manager.selected_vow_id = "vow_order"
	_expect(game_manager.is_archive_map_pool_unlocked(), "All three fragments from one memory set must unlock the archive pool.")
	var seeded_archive_seen: bool = false
	for seed_value in range(8):
		game_manager.run_seed = seed_value
		game_manager._select_map_templates()
		seeded_archive_seen = seeded_archive_seen or game_manager.map_template_ids.values().has("archive")
	_expect(seeded_archive_seen, "Once unlocked, archive must participate in the deterministic seed candidate pool.")
	_expect(game_manager.select_map_template_pool("archive"), "An unlocked profile must be able to enter the archive pool.")
	_expect(game_manager.map_template_ids == {"C1": "archive", "C2": "archive", "C3": "archive"}, "Archive selection must apply to all three chapters.")
	var snapshot: Dictionary = game_manager.create_save_snapshot()
	var saved_seed: int = int(snapshot.get("run_seed", 0))
	_expect(int(snapshot.get("run_seed", 0)) == game_manager.run_seed, "Run Save v4 must retain the map selection seed.")
	_expect(snapshot.get("map_template_ids") == game_manager.map_template_ids, "Run Save v4 must retain all selected archive templates.")
	game_manager.run_seed = saved_seed + 1
	game_manager.map_template_ids = {"C1": "standard", "C2": "standard", "C3": "standard"}
	_expect(game_manager.restore_save_snapshot(snapshot), "An unlocked archive snapshot must restore successfully.")
	_expect(game_manager.run_seed == saved_seed, "Archive restoration must recover the original deterministic seed.")
	_expect(game_manager.map_template_ids == {"C1": "archive", "C2": "archive", "C3": "archive"}, "An unlocked archive selection must survive a Run Save v4 round trip.")


func _test_seed_selection_respects_archive_gate() -> void:
	game_manager.unlocked_memory_ids.assign(["M04", "M05"])
	game_manager.selected_vow_id = "vow_witness"
	for seed_value in range(16):
		game_manager.run_seed = seed_value
		game_manager._select_map_templates()
		_expect(not game_manager.map_template_ids.values().has("archive"), "Seed selection must never enter archive while its profile condition is locked.")
		var first_selection: Dictionary = game_manager.map_template_ids.duplicate(true)
		game_manager._select_map_templates()
		_expect(game_manager.map_template_ids == first_selection, "The same run seed must reproduce the same legal map templates.")


func _test_run_save_v4_template_whitelist() -> void:
	var archived: Dictionary = save_manager._migrate_run({
		"selected_vow_id": "vow_order",
		"map_template_ids": {"C1": "archive", "C2": "archive", "C3": "archive"},
	}, 4)
	_expect(
		archived.get("map_template_ids") == {"C1": "archive", "C2": "archive", "C3": "archive"},
		"Run Save v4 sanitization must whitelist the archive template ID."
	)
	var malformed: Dictionary = save_manager._migrate_run({
		"selected_vow_id": "vow_witness",
		"map_template_ids": {"C1": "removed", "C2": 42},
	}, 4)
	_expect(
		malformed.get("map_template_ids") == {"C1": "economy", "C2": "economy", "C3": "economy"},
		"Unknown or missing v4 template IDs must sanitize to the selected vow's default pool."
	)


func _expect(condition: bool, message: String) -> void:
	if not condition and not failures.has(message):
		failures.append(message)
