extends SceneTree

const GameDataScript = preload("res://scripts/GameData.gd")
const SpectrumManagerScript = preload("res://scripts/SpectrumManager.gd")

var failures: Array[String] = []
var game_manager: Node


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	game_manager = root.get_node("GameManager")
	_run_test("archive bypass graph", _test_archive_bypass_graph)
	_run_test("template modifiers", _test_template_modifiers)
	_run_test("deterministic event rng", _test_deterministic_event_rng)
	_run_test("event chain prerequisites", _test_event_chain_prerequisites)
	_run_test("event chain save round trip", _test_event_chain_save_round_trip)
	_run_test("mixed spectra runtime fields", _test_mixed_spectra)
	_run_test("red hilt text contract", _test_red_hilt_text)

	print("V2.1.0 release blocker tests: %d passed, %d failed" % [7 - failures.size(), failures.size()])
	if failures.is_empty():
		quit(0)
		return
	for failure in failures:
		push_error(failure)
	quit(1)


func _run_test(test_name: String, test_callable: Callable) -> void:
	var before: int = failures.size()
	test_callable.call()
	print("[%s] %s" % ["PASS" if failures.size() == before else "FAIL", test_name])


func _test_archive_bypass_graph() -> void:
	_expect(GameDataScript.CHAPTER_NODES.size() == 79, "2.1.0 地图节点总数必须维持 79。")
	var catalog: Dictionary = GameDataScript.map_template_catalog()
	for chapter_id in ["C1", "C2", "C3"]:
		var archive: Dictionary = catalog.get(chapter_id, {}).get("archive", {})
		var nodes: Dictionary = archive.get("nodes", {})
		var bypass_ids: Array[String] = []
		for node_id_value in nodes.keys():
			var node_id: String = String(node_id_value)
			var node: Dictionary = nodes[node_id]
			if node.get("archive_bypass", false) == true:
				bypass_ids.append(node_id)
		bypass_ids.sort()
		_expect(bypass_ids.size() == 2, "%s archive 模板必须恰有两个旁路节点。" % chapter_id)
		var bypass_layers: Array[int] = []
		for bypass_id in bypass_ids:
			var bypass: Dictionary = nodes[bypass_id]
			bypass_layers.append(int(bypass.get("layer", -1)))
			_expect(String(bypass.get("type", "")) == "event", "%s 必须是可结算事件旁路。" % bypass_id)
			_expect(_is_reachable(nodes, chapter_id + "-00", bypass_id), "%s 必须可从章节入口到达。" % bypass_id)
			_expect(_is_reachable(nodes, bypass_id, chapter_id + "-08"), "%s 必须能重新汇合并抵达 Boss。" % bypass_id)
		bypass_layers.sort()
		_expect(bypass_layers == [2, 4], "%s 的旁路必须分别位于第 2、4 层。" % chapter_id)


func _test_template_modifiers() -> void:
	for chapter_id in ["C1", "C2", "C3"]:
		var specs: Dictionary = GameDataScript.MAP_TEMPLATE_SPECS.get(chapter_id, {})
		_expect(float(specs.get("risk", {}).get("enemy_hp_multiplier", 0.0)) == 1.05, "%s risk 必须配置 1.05 敌人 HP 修正。" % chapter_id)
		_expect(int(specs.get("economy", {}).get("shop_refresh_bonus", 0)) == 5, "%s economy 必须配置 5 金币刷新优惠。" % chapter_id)
		_expect(int(specs.get("archive", {}).get("gray_pressure_bonus", 0)) == 1, "%s archive 必须配置 1 点灰蚀压力。" % chapter_id)

	game_manager.set_ascension_level(0)
	game_manager.reset_run()
	game_manager.map_template_ids = {"C1": "risk", "C2": "risk", "C3": "risk"}
	game_manager.current_node_id = "C1-01"
	var base_encounter: Dictionary = GameDataScript.encounter("C1-01")
	var risk_encounter: Dictionary = game_manager.get_current_encounter()
	_expect(int(risk_encounter.get("max_hp", 0)) == int(round(float(base_encounter.get("max_hp", 0)) * 1.05)), "risk 的 1.05 HP 修正必须进入遭遇运行时。")

	game_manager.map_template_ids = {"C1": "economy", "C2": "economy", "C3": "economy"}
	game_manager.current_node_id = "C1-04C"
	game_manager.selected_character_id = ""
	game_manager.free_shop_refreshes = 0
	game_manager.shop_refresh_count = 0
	_expect(game_manager.get_shop_refresh_price() == 13, "economy 首次商店刷新必须由 18 降至 13 金币。")

	game_manager.reset_run()
	game_manager.set_ascension_level(0)
	game_manager.equipped_memory_ids.clear()
	game_manager.gray_pressure = 0
	game_manager.map_template_ids = {"C1": "archive", "C2": "archive", "C3": "archive"}
	game_manager.current_node_id = "C1-00"
	game_manager.current_options.assign(["C1-01"])
	_expect(game_manager.choose_node("C1-01") and game_manager.gray_pressure == 0, "进入 archive 战斗节点本身不得固定增加灰压。")
	game_manager.map_template_ids = {"C1": "standard", "C2": "standard", "C3": "standard"}
	game_manager.add_gray_pressure(2)
	var standard_pressure: int = game_manager.gray_pressure
	game_manager.gray_pressure = 0
	game_manager.map_template_ids = {"C1": "archive", "C2": "archive", "C3": "archive"}
	game_manager.add_gray_pressure(2)
	_expect(game_manager.gray_pressure == standard_pressure + 1, "archive 下 add_gray_pressure(2) 必须比 standard 多获得 1 点灰压。")

	game_manager.gray_pressure = 4
	game_manager.add_gray_pressure(0)
	game_manager.add_gray_pressure(-3)
	_expect(game_manager.gray_pressure == 4, "archive 修正不得让非正数灰压请求凭空加压。")

	game_manager.equipped_memory_ids.assign(["M05"])
	game_manager.gray_pressure = 0
	game_manager.add_gray_pressure(2)
	_expect(game_manager.gray_pressure == 2, "archive 原始获取 3 点时，M05 的 1 点 gray_resist 仍须生效。")
	game_manager.equipped_memory_ids.clear()
	game_manager.gray_pressure = 19
	game_manager.add_gray_pressure(8)
	_expect(game_manager.gray_pressure == 20, "archive 灰压加成不得突破 20 点硬上限。")


func _test_deterministic_event_rng() -> void:
	game_manager.reset_run()
	game_manager.map_template_ids = {"C1": "archive", "C2": "archive", "C3": "archive"}
	game_manager.current_node_id = "C1-03R"
	game_manager.event_chain_progress.clear()
	game_manager.run_seed = 90210
	game_manager.event_assignments.clear()
	seed(1)
	var first_event_id: String = game_manager.get_current_event_id()
	game_manager.event_assignments.clear()
	seed(999999)
	for draw_index in range(20):
		randi()
	var repeated_event_id: String = game_manager.get_current_event_id()
	_expect(first_event_id == repeated_event_id and not first_event_id.is_empty(), "事件抽取不得受全局 RNG 状态影响。")

	var changed_seed_changes_result: bool = false
	for seed_offset in range(1, 128):
		game_manager.run_seed = 90210 + seed_offset
		game_manager.event_assignments.clear()
		if game_manager.get_current_event_id() != first_event_id:
			changed_seed_changes_result = true
			break
	_expect(changed_seed_changes_result, "不同 run_seed 应能改变同一章节节点的确定性事件结果。")


func _test_event_chain_prerequisites() -> void:
	game_manager.reset_run()
	game_manager.map_template_ids = {"C1": "archive", "C2": "archive", "C3": "archive"}
	game_manager.current_node_id = "C2-03R"
	game_manager.event_chain_progress.clear()
	game_manager.event_assignments.clear()
	var locked_fallback_id: String = game_manager.get_current_event_id()
	_expect(String(GameDataScript.event(locked_fallback_id).get("chain_id", "")).is_empty(), "未完成阶段 1 时不得抽到阶段 2 碎片事件。")
	_expect(not game_manager._is_event_chain_stage_unlocked("ash_filter_testimony"), "阶段 2 必须要求同链阶段 1。")

	game_manager.event_chain_progress["CHAIN-ASH-ORIGIN"] = 1
	game_manager.event_assignments.clear()
	_expect(game_manager.get_current_event_id() == "ash_filter_testimony", "满足前序后应优先抽取已解锁的碎片事件。")
	var blocked_result: String = game_manager.apply_event_choice("ash_dragon_margin", "sell")
	_expect(blocked_result.contains("前序尚未解锁"), "直接结算阶段 3 也必须被前序门槛阻止。")
	_expect(int(game_manager.event_chain_progress.get("CHAIN-ASH-ORIGIN", 0)) == 1, "失败的越级结算不得推进事件链。")

	var resolved_result: String = game_manager.apply_event_choice("ash_filter_testimony", "drill")
	_expect(not resolved_result.contains("无效") and not resolved_result.contains("不足"), "合法的阶段 2 事件应能完成结算。")
	_expect(int(game_manager.event_chain_progress.get("CHAIN-ASH-ORIGIN", 0)) == 2, "事件结算后必须推进对应 chain_stage。")
	_expect(game_manager._is_event_chain_stage_unlocked("ash_dragon_margin"), "阶段 2 完成后必须解锁阶段 3。")


func _test_event_chain_save_round_trip() -> void:
	game_manager.reset_run()
	game_manager.event_chain_progress = {"CHAIN-ASH-ORIGIN": 2, "CHAIN-DEBT": 1}
	var snapshot: Dictionary = game_manager.create_save_snapshot()
	game_manager.event_chain_progress.clear()
	_expect(game_manager.restore_save_snapshot(snapshot), "含事件链进度的运行存档必须可恢复。")
	_expect(game_manager.event_chain_progress == {"CHAIN-ASH-ORIGIN": 2, "CHAIN-DEBT": 1}, "合法事件链进度必须完整往返存档。")

	var malformed: Dictionary = snapshot.duplicate(true)
	malformed["event_chain_progress"] = {
		"CHAIN-ASH-ORIGIN": 99,
		"CHAIN-DEBT": -4,
		"CHAIN-CALIBRATION": [1, 2],
		"CHAIN-ORCHESTRA": "2",
		"UNKNOWN": 2,
	}
	malformed["event_assignments"] = {"C3-03R": "ash_dragon_margin"}
	_expect(game_manager.restore_save_snapshot(malformed), "结构有效但链进度畸形的存档应可安全恢复。")
	_expect(game_manager.event_chain_progress == {"CHAIN-ASH-ORIGIN": 3}, "事件链恢复必须钳制最大阶段，并移除负值、非数值及未知链。")
	_expect(not game_manager.event_assignments.has("C3-03R"), "恢复时必须移除不再处于可解锁阶段的事件指派。")


func _test_mixed_spectra() -> void:
	var mixed_count: int = 0
	for card_value in GameDataScript.SPECTRA.values():
		if String(card_value.get("color", "")) == "mixed":
			mixed_count += 1
	_expect(mixed_count >= 8, "mixed 学派必须至少拥有 8 张色谱。")
	for card_id in ["chromatic_relay", "triune_refrain"]:
		var card: Dictionary = GameDataScript.spectrum(card_id)
		_expect(not String(card.get("condition_type", "")).is_empty(), "%s 必须使用已实现的通用条件。" % card_id)
		_expect(card.get("effects", []) is Array and not card.get("effects", []).is_empty(), "%s 必须定义可执行效果。" % card_id)

	var manager: SpectrumManager = SpectrumManagerScript.new()
	manager.begin_turn([{"instance_id": "relay", "card_id": "chromatic_relay", "level": 0}])
	manager.register_clear_event({"type": "red", "count": 3, "cascade": 1, "active": true}, 3, {})
	var fired: Array[Dictionary] = manager.register_clear_event({"type": "blue", "count": 3, "cascade": 1, "active": true}, 3, {})
	_expect(_fired_card(fired, "chromatic_relay"), "双色接力的红 -> 蓝条件必须可实际触发。")

	manager.begin_turn([{"instance_id": "refrain", "card_id": "triune_refrain", "level": 0}])
	manager.register_clear_event({"type": "red", "count": 3, "cascade": 1, "active": true}, 3, {})
	manager.register_clear_event({"type": "blue", "count": 3, "cascade": 1, "active": true}, 3, {})
	fired = manager.register_clear_event({"type": "gold", "count": 3, "cascade": 1, "active": true}, 3, {})
	_expect(_fired_card(fired, "triune_refrain"), "三声复句的三色条件必须可实际触发。")


func _test_red_hilt_text() -> void:
	var description: String = String(GameDataScript.relic("red_hilt").get("description", ""))
	_expect(description.contains("1 红色素"), "红釉剑柄文案必须描述当前 +1 红色素收益。")
	_expect(not description.contains("造成") and not description.contains("伤害"), "红釉剑柄不得再宣称普通消除直接造成伤害。")


func _is_reachable(nodes: Dictionary, start_id: String, target_id: String) -> bool:
	var pending: Array[String] = [start_id]
	var visited: Dictionary = {}
	while not pending.is_empty():
		var node_id: String = pending.pop_front()
		if visited.has(node_id):
			continue
		visited[node_id] = true
		if node_id == target_id:
			return true
		for edge_value in nodes.get(node_id, {}).get("edges", []):
			var edge_id: String = String(edge_value)
			if nodes.has(edge_id) and not visited.has(edge_id):
				pending.append(edge_id)
	return false


func _fired_card(results: Array[Dictionary], card_id: String) -> bool:
	for result in results:
		if String(result.get("card_id", "")) == card_id:
			return true
	return false


func _expect(condition: bool, message: String) -> void:
	if not condition and not failures.has(message):
		failures.append(message)
