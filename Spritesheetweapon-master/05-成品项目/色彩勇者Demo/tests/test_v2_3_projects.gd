extends SceneTree

var project_script: Script

var failures: Array[String] = []
var passed: int = 0

func _init() -> void:
	project_script = load("res://scripts/ChapterProjects.gd") as Script
	call_deferred("_run")

func _run() -> void:
	if project_script == null or not project_script.can_instantiate():
		_expect(false, "ChapterProjects must be instantiable")
		_report_and_quit()
		return
	_run_test("project catalog", _test_catalog)
	_run_test("begin and status", _test_begin_and_status)
	_run_test("project node rules and deduplication", _test_node_rules)
	_run_test("chapter isolation", _test_chapter_isolation)
	_run_test("completion result and effect totals", _test_completion)
	_run_test("options and snapshots are deep copies", _test_deep_copies)
	_run_test("restore filters and recomputes trusted progress", _test_restore_safety)
	_run_test("forge keeps cumulative progress above target", _test_forge_cumulative_progress)
	_run_test("restore rejects non-string chapter and project keys safely", _test_restore_variant_types)
	_run_test("descriptions state conditions and permanence", _test_description_contract)
	print("V2.3 projects: %d passed, %d failed" % [passed, failures.size()])
	for failure in failures:
		push_error(failure)
	quit(0 if failures.is_empty() else 1)

func _report_and_quit() -> void:
	for failure in failures:
		push_error(failure)
	quit(1)

func _run_test(name: String, test_callable: Callable) -> void:
	var before: int = failures.size()
	var completed: Variant = test_callable.call()
	_expect(completed is bool and completed, name + ": test did not complete")
	if failures.size() == before:
		passed += 1
		print("[PASS] " + name)
	else:
		print("[FAIL] " + name)

func _new_projects() -> RefCounted:
	if project_script == null or not project_script.has_method("new"):
		_expect(false, "ChapterProjects must be instantiable")
		return RefCounted.new()
	return project_script.new()

func _test_catalog() -> bool:
	var projects: RefCounted = _new_projects()
	var expected: Dictionary = {
		"forge": {"name": "熔彩工坊", "color": "red", "description": "强化色谱伤害", "coin_cost": 30, "pigment_cost": 1, "target": 2, "effects": {"spectrum_base_damage": 3}},
		"sanctuary": {"name": "净色花园", "color": "blue", "description": "首回合获得护盾", "coin_cost": 30, "pigment_cost": 1, "target": 2, "effects": {"first_turn_shield": 4}},
		"exchange": {"name": "商路会馆", "color": "gold", "description": "商店折扣", "coin_cost": 30, "pigment_cost": 1, "target": 3, "effects": {"shop_discount": 0.05}},
	}
	var catalog: Dictionary = project_script.get_script_constant_map().get("PROJECTS", {})
	_expect(catalog.size() == 3, "PROJECTS must contain exactly three definitions")
	for project_id in expected:
		_expect(catalog.get(project_id, {}).get("name") == expected[project_id]["name"], "project name must match")
		_expect(catalog.get(project_id, {}).get("color") == expected[project_id]["color"], "project color must match")
		_expect(catalog.get(project_id, {}).get("target") == expected[project_id]["target"], "project target must match")
		_expect(catalog.get(project_id, {}).get("effects") == expected[project_id]["effects"], "project effect must match")
	var options: Array = projects.options()
	_expect(options.size() == 3, "options must return all project data")
	for option in options:
		var option_id: String = String(option.get("id", ""))
		_expect(expected.has(option_id) and option.get("name") == expected[option_id]["name"], "options must return independent project data")
	return true

func _test_begin_and_status() -> bool:
	var projects: RefCounted = _new_projects()
	_expect(projects.begin("C1", "forge"), "first project must begin")
	_expect(not projects.begin("C1", "sanctuary"), "active chapter project cannot be changed")
	_expect(not projects.begin("C9", "forge"), "unknown chapter must be rejected")
	var status: Dictionary = projects.status("C1")
	_expect(status.get("id", "") == "forge" and status.get("progress", -1) == 0 and not status.get("completed", true), "status must merge project data with initial state")
	_expect(status.get("credited_nodes", []).is_empty(), "new project must have no credited nodes")
	_expect(projects.status("C2").is_empty(), "unstarted chapter must return empty status")
	return true

func _test_node_rules() -> bool:
	var projects: RefCounted = _new_projects()
	projects.begin("C1", "forge")
	_expect(projects.advance("C1-01", "combat").is_empty(), "forge combat 1 must be partial")
	_expect(projects.advance("C1-01", "combat").is_empty(), "same node must count once")
	var completion: Dictionary = projects.advance("C1-04A", "elite")
	_expect(completion.get("completed", false) and completion.get("id", "") == "forge", "forge must complete at combat 1, elite 2, boss 1")
	_expect(projects.advance("C1-08", "boss").is_empty(), "completed project must not advance further")

	var sanctuary: RefCounted = _new_projects()
	sanctuary.begin("C2", "sanctuary")
	_expect(sanctuary.advance("C2-02B", "event").is_empty(), "sanctuary event must count one")
	_expect(sanctuary.advance("C2-03B", "chest").get("completed", false), "sanctuary chest must complete second point")

	var exchange: RefCounted = _new_projects()
	exchange.begin("C3", "exchange")
	for node_id in ["C3-01", "C3-02B", "C3-03B"]:
		_expect(exchange.advance(node_id, "wrong_type").is_empty(), "node_type argument must not bypass canonical node type")
		var canonical_type: String = exchange._node_type(node_id)
		var result: Dictionary = exchange.advance(node_id, canonical_type)
		_expect(result.is_empty() if node_id != "C3-03B" else result.get("completed", false), "exchange must count each legal non-start node once")
	return true

func _test_chapter_isolation() -> bool:
	var projects: RefCounted = _new_projects()
	projects.begin("C1", "forge")
	_expect(projects.advance("C2-01", "combat").is_empty(), "cross-chapter node must not advance active project")
	_expect(projects.status("C1").get("progress", -1) == 0, "cross-chapter node must not change progress")
	_expect(projects.begin("C2", "exchange"), "new chapter may begin independently")
	_expect(projects.status("C1").get("id", "") == "forge", "old chapter record must remain")
	_expect(projects.status("C2").get("id", "") == "exchange", "new chapter record must be active")
	return true

func _test_completion() -> bool:
	var projects: RefCounted = _new_projects()
	projects.begin("C1", "forge")
	var result: Dictionary = projects.advance("C1-04A", "elite")
	_expect(result.get("completed", false), "completion must be marked")
	_expect(result.get("name", "") == "熔彩工坊" and result.get("effects", {}).get("spectrum_base_damage", 0) == 3, "completion must return a project data copy")
	_expect(projects.effect_total("spectrum_base_damage") == 3.0, "completed effect must total")
	_expect(projects.effect_total("first_turn_shield") == 0.0, "uncompleted effects must not total")
	return true

func _test_deep_copies() -> bool:
	var projects: RefCounted = _new_projects()
	projects.begin("C1", "forge")
	var options: Array = projects.options()
	options[0]["effects"]["spectrum_base_damage"] = 99
	_expect(projects.options()[0]["effects"]["spectrum_base_damage"] == 3, "options must be deeply copied")
	var snapshot: Dictionary = projects.snapshot()
	snapshot["C1"]["credited_nodes"].append("C1-99")
	_expect(projects.snapshot()["C1"]["credited_nodes"].is_empty(), "snapshot must be deeply copied")
	return true

func _test_restore_safety() -> bool:
	var projects: RefCounted = _new_projects()
	var forged: Dictionary = {
			"C1": {"id": "forge", "progress": 999, "completed": true, "credited_nodes": ["C1-01", "C1-04A", "C1-08", "C2-01", "bad"]},
			"C2": {"id": "exchange", "progress": INF, "completed": true, "credited_nodes": ["C2-01", "C2-02B", "C2-03B"]},
			"C9": {"id": "forge", "progress": 1, "completed": true, "credited_nodes": ["C9-01"]},
			"not_chapter": {"id": "forge", "progress": 1, "credited_nodes": []},
	}
	projects.restore(forged)
	_expect(projects.status("C1").is_empty(), "progress inconsistent with filtered legal nodes must discard record")
	_expect(projects.status("C2").is_empty(), "nonfinite progress must invalidate the chapter record")
	_expect(projects.status("C9").is_empty(), "unknown chapters must be discarded")
	var safe_snapshot: Dictionary = {"C1": {"id": "forge", "progress": 2, "completed": false, "credited_nodes": ["C1-03X"]}}
	projects.restore(safe_snapshot)
	_expect(projects.status("C1").get("completed", false), "restore must not trust forged completed flag")
	return true

func _test_forge_cumulative_progress() -> bool:
	var projects: RefCounted = _new_projects()
	projects.begin("C1", "forge")
	projects.advance("C1-01", "combat")
	var result: Dictionary = projects.advance("C1-04A", "elite")
	_expect(result.get("completed", false), "forge combat 1 plus elite 2 must complete")
	_expect(projects.status("C1").get("progress") == 3, "completed forge must retain cumulative progress 3")
	var restored: RefCounted = _new_projects()
	restored.restore(projects.snapshot())
	_expect(restored.status("C1").get("progress") == 3 and restored.status("C1").get("completed", false), "cumulative forge snapshot must restore")
	return true

func _test_restore_variant_types() -> bool:
	var projects: RefCounted = _new_projects()
	for value in [[], {}, null, 1, true]:
		projects.restore({value: {"id": "forge", "progress": 0, "credited_nodes": []}})
		_expect(projects.snapshot().is_empty(), "array/dict chapter keys must be discarded without errors")
		projects.restore({"C1": {"id": value, "progress": 0, "credited_nodes": []}})
		_expect(projects.snapshot().is_empty(), "array/dict project ids must be discarded without errors")
	return true

func _test_description_contract() -> bool:
	var descriptions: Dictionary = {}
	for option in (_new_projects() as RefCounted).options():
		descriptions[option["id"]] = String(option["description"])
	_expect(descriptions["forge"].find("普通") >= 0 and descriptions["forge"].find("精英") >= 0 and descriptions["forge"].find("Boss") >= 0, "forge description must state normal/elite/boss values")
	_expect(descriptions["sanctuary"].find("非战斗") >= 0, "sanctuary description must state non-combat condition")
	_expect(descriptions["exchange"].find("非起点") >= 0, "exchange description must state non-start condition")
	for description in descriptions.values():
		_expect(description.find("本章") >= 0 and description.find("永久") >= 0, "every description must state chapter term and permanent reward")
	return true

func _expect(condition: bool, message: String) -> void:
	if not condition and not failures.has(message):
		failures.append(message)
