extends SceneTree

var failures: Array[String] = []
var passed: int = 0

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	_run_test("cross-chapter policy persists until replaced", _test_cross_chapter_policy_restore)
	_run_test("post-boss pending policy selection restores", _test_pending_policy_restore)
	_run_test("policy restore keeps active id and chapter table aligned", _test_policy_consistency_restore)
	_run_test("missing policy restore returns to policy selection", _test_missing_policy_restore)
	_run_test("camp upgrade rejects wrong or visited nodes", _test_camp_upgrade_node_guards)
	print("V2.3 strategy recovery: %d passed, %d failed" % [passed, failures.size()])
	for failure in failures:
		push_error(failure)
	quit(1 if not failures.is_empty() else 0)

func _run_test(name: String, test_callable: Callable) -> void:
	var before: int = failures.size()
	var completed: Variant = test_callable.call()
	_expect(completed is bool and completed, name + ": test did not complete")
	if failures.size() == before:
		passed += 1
		print("[PASS] " + name)
	else:
		print("[FAIL] " + name)

func _base_snapshot(node_id: String) -> Dictionary:
	var manager: GameManager = root.get_node("GameManager") as GameManager
	manager.reset_run()
	manager.starting_archetype_id = "red"
	manager.selected_character_id = "red"
	manager.selected_vow_id = "vow_order"
	var snapshot: Dictionary = manager.create_save_snapshot()
	snapshot["current_node_id"] = node_id
	snapshot["starting_archetype_id"] = "red"
	snapshot["selected_character_id"] = "red"
	snapshot["selected_vow_id"] = "vow_order"
	return snapshot

func _test_cross_chapter_policy_restore() -> bool:
	var manager: GameManager = root.get_node("GameManager") as GameManager
	var snapshot: Dictionary = _base_snapshot("C2-01")
	snapshot["run_phase"] = "route_selection"
	snapshot["selected_policy_id"] = "red_accord"
	snapshot["chapter_policies"] = {"C1": "red_accord"}
	_expect(manager.restore_save_snapshot(snapshot), "cross-chapter policy snapshot must restore")
	_expect(manager.selected_policy_id == "red_accord", "previous chapter policy remains active until replaced")
	_expect(not manager.chapter_policies.has("C2"), "cross-chapter restore must not invent a current chapter policy")
	_expect(manager.run_phase == "battle", "cross-chapter restore must use the current node phase")
	return true

func _test_pending_policy_restore() -> bool:
	var manager: GameManager = root.get_node("GameManager") as GameManager
	manager.reset_run()
	manager.apply_start_choice("red")
	manager.apply_vow("vow_witness")
	manager.apply_policy("blue_charter")
	manager.current_node_id = "C1-08"
	manager.complete_current_node()
	var snapshot: Dictionary = manager.create_save_snapshot()
	_expect(manager.restore_save_snapshot(snapshot), "post-boss snapshot restores")
	_expect(manager.run_phase == "policy_selection", "post-boss pending policy selection remains reachable")
	_expect(manager.selected_policy_id == "blue_charter", "pending next chapter preserves old policy")
	_expect(manager.can_choose_policy(), "restored pending policy may be selected")
	_expect(manager.apply_policy("golden_exchange"), "restored chapter accepts replacement policy")
	_expect(manager.get_strategy_chapter_id() == "C2", "replacement belongs to next chapter")
	var refreshes: int = manager.free_shop_refreshes
	snapshot = manager.create_save_snapshot()
	_expect(manager.restore_save_snapshot(snapshot), "chosen next chapter snapshot restores")
	_expect(manager.selected_policy_id == "golden_exchange", "chosen next chapter policy remains active at boss checkpoint")
	_expect(manager.free_shop_refreshes == refreshes, "restore cannot grant policy refresh twice")
	return true

func _test_policy_consistency_restore() -> bool:
	var manager: GameManager = root.get_node("GameManager") as GameManager
	var snapshot: Dictionary = _base_snapshot("C2-01")
	snapshot["run_phase"] = "map"
	snapshot["selected_policy_id"] = "blue_oath"
	snapshot["chapter_policies"] = {"C2": "red_accord"}
	_expect(manager.restore_save_snapshot(snapshot), "inconsistent policy snapshot must restore")
	_expect(manager.selected_policy_id == "red_accord", "active policy must follow current chapter policy")
	_expect(manager.chapter_policies.get("C2", "") == "red_accord", "chapter policy must remain canonical")
	return true

func _test_missing_policy_restore() -> bool:
	var manager: GameManager = root.get_node("GameManager") as GameManager
	var snapshot: Dictionary = _base_snapshot("C1-00")
	snapshot.erase("selected_policy_id")
	snapshot["run_phase"] = "route_selection"
	snapshot["chapter_policies"] = {}
	_expect(manager.restore_save_snapshot(snapshot), "missing policy snapshot must restore")
	_expect(manager.selected_policy_id == "", "missing policy must remain empty")
	_expect(manager.run_phase == "policy_selection", "missing policy must require policy selection")
	return true

func _test_camp_upgrade_node_guards() -> bool:
	var manager: GameManager = root.get_node("GameManager") as GameManager
	manager.reset_run()
	manager.current_node_id = "C1-01"
	manager.visited_nodes.clear()
	manager.deck = [{"instance_id": "test_card", "card_id": "ember_slash", "level": 0}]
	var wrong_result: String = manager.apply_camp_upgrade("test_card")
	_expect(wrong_result.contains("营地"), "upgrade on a non-camp node must be rejected as an invalid camp")
	_expect(manager.get_card_level("test_card") == 0, "wrong-node upgrade must not mutate the card")
	manager.current_node_id = "C1-07"
	manager.visited_nodes["C1-07"] = true
	var visited_result: String = manager.apply_camp_upgrade("test_card")
	_expect(visited_result.contains("已经结算"), "upgrade on a visited camp must be rejected as settled")
	_expect(manager.get_card_level("test_card") == 0, "visited-camp upgrade must not mutate the card")
	return true

func _expect(condition: bool, message: String) -> void:
	if not condition and not failures.has(message):
		failures.append(message)
