extends SceneTree

const GameDataScript = preload("res://scripts/GameData.gd")

var failures: Array[String] = []
var game_manager: Node

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	game_manager = root.get_node("GameManager")
	_test_catalog_targets()
	_test_chapter_structure()
	_test_four_color_board_contract()
	_test_ascension_scaling()
	_test_data_driven_event()
	if failures.is_empty():
		print("V1 content tests passed: 5")
		quit(0)
		return
	for failure in failures:
		push_error(failure)
	quit(1)

func _test_catalog_targets() -> void:
	var collectible_count: int = 0
	for card in GameDataScript.SPECTRA.values():
		if not card.get("pools", []).has("curse"):
			collectible_count += 1
	_expect(collectible_count >= 36, "内容目录不得低于 1.0 的 36 张非诅咒可收集色谱。")
	_expect(GameDataScript.RELICS.size() >= 24, "遗物目录不得低于 1.0 的 24 件。")
	_expect(GameDataScript.EVENTS.size() >= 12, "事件目录不得低于 1.0 的 12 个。")
	var encounter_counts: Dictionary = {"combat": 0, "elite": 0, "boss": 0}
	for encounter in GameDataScript.ENCOUNTERS.values():
		var node_type: String = String(encounter.get("node_type", ""))
		if encounter_counts.has(node_type):
			encounter_counts[node_type] = int(encounter_counts[node_type]) + 1
	_expect(int(encounter_counts["combat"]) >= 18, "敌人目录不得低于 18 个普通遭遇的 1.0 基线。")
	_expect(int(encounter_counts["elite"]) >= 6, "敌人目录不得低于 6 个精英遭遇的 1.0 基线。")
	_expect(int(encounter_counts["boss"]) >= 3, "敌人目录不得低于 3 个 Boss 遭遇的 1.0 基线。")

func _test_chapter_structure() -> void:
	for chapter_id in ["C1", "C2", "C3"]:
		var type_counts: Dictionary = {"combat": 0, "elite": 0, "boss": 0, "event": 0}
		var layers: Dictionary = {}
		for node_id in GameDataScript.CHAPTER_NODES.keys():
			if not String(node_id).begins_with(chapter_id + "-"):
				continue
			var node: Dictionary = GameDataScript.node(String(node_id))
			var node_type: String = String(node.get("type", ""))
			if type_counts.has(node_type):
				type_counts[node_type] = int(type_counts[node_type]) + 1
			var layer: int = int(node.get("layer", -1))
			if layer >= 1:
				layers[layer] = true
		_expect(type_counts["combat"] >= 6, "%s 不得少于 6 个普通战节点。" % chapter_id)
		_expect(type_counts["elite"] >= 2, "%s 不得少于 2 个精英节点。" % chapter_id)
		_expect(type_counts["boss"] == 1, "%s 必须有 1 个 Boss 节点。" % chapter_id)
		_expect(type_counts["event"] >= 4, "%s 不得少于 4 个事件节点。" % chapter_id)
		_expect(layers.size() == 8, "%s 必须覆盖 8 层实际节点。" % chapter_id)

func _test_four_color_board_contract() -> void:
	var board_colors: Array[String] = []
	for color_key in GameDataScript.BASE_WEIGHTS.keys():
		board_colors.append(String(color_key))
	board_colors.sort()
	_expect(board_colors == ["blue", "gold", "gray", "red"], "棋盘基础色必须且只能是红、蓝、金、灰。")

func _test_ascension_scaling() -> void:
	game_manager.reset_run()
	game_manager.current_node_id = "C3-08"
	game_manager.set_ascension_level(0)
	var normal: Dictionary = game_manager.get_current_encounter()
	game_manager.set_ascension_level(5)
	var ascended: Dictionary = game_manager.get_current_encounter()
	_expect(int(ascended.get("max_hp", 0)) > int(normal.get("max_hp", 0)), "进阶 5 必须提高最终 Boss HP。")
	_expect(int(ascended.get("attack", 0)) > int(normal.get("attack", 0)), "进阶 5 必须提高最终 Boss 攻击。")

func _test_data_driven_event() -> void:
	game_manager.reset_run()
	game_manager.current_node_id = "C1-05D"
	var pigment_before: int = game_manager.pigment
	var hp_before: int = game_manager.player_hp
	game_manager.apply_event_choice("pigment_well", "draw")
	_expect(game_manager.pigment == pigment_before + 2, "数据事件应正确发放颜料。")
	_expect(game_manager.player_hp == hp_before - 6, "数据事件应正确结算生命代价。")
	_expect(game_manager.visited_nodes.has("C1-05D"), "数据事件结算后应完成当前节点。")

func _expect(condition: bool, message: String) -> void:
	if not condition and not failures.has(message):
		failures.append(message)
