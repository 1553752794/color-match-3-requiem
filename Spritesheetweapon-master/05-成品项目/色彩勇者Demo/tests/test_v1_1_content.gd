extends SceneTree

const BattleManagerScript = preload("res://scripts/BattleManager.gd")
const GameDataScript = preload("res://scripts/GameData.gd")
const SpectrumManagerScript = preload("res://scripts/SpectrumManager.gd")

var failures: Array[String] = []
var game_manager: Node

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	game_manager = root.get_node("GameManager")
	_test_catalog_targets()
	_test_school_distribution()
	_test_generic_condition()
	_test_generic_effects()
	_test_relic_acquisition_hooks()
	_test_battle_relic_hooks()
	_test_chained_event()
	_test_character_routes()
	_test_event_assignment_persistence()
	_test_challenge_reward()
	if failures.is_empty():
		print("V1.1 content tests passed: 10")
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
	_expect(collectible_count >= 72, "1.1 必须至少提供 72 张可收集色谱。")
	_expect(GameDataScript.SPECTRA.size() >= collectible_count + 1, "色谱注册表必须保留至少 1 张事件诅咒，并允许后续版本扩充。")
	_expect(GameDataScript.RELICS.size() >= 48, "遗物目录不得低于 1.1 的 48 件基线。")
	_expect(GameDataScript.EVENTS.size() >= 24, "事件目录不得低于 1.1 的 24 个基线。")

func _test_school_distribution() -> void:
	for school in ["green", "purple", "white", "black"]:
		var count: int = 0
		for card in GameDataScript.SPECTRA.values():
			if String(card.get("color", "")) == school and String(card.get("condition_type", "")) != "":
				count += 1
				_expect(card.get("effects", []).size() > 0, "%s 新学派色谱必须有可执行 effects。" % school)
		_expect(count >= 9, "%s 学派必须至少保留 9 张 1.1 色谱。" % school)

func _test_generic_condition() -> void:
	var manager: SpectrumManager = SpectrumManagerScript.new()
	var hand: Array[Dictionary] = [{"instance_id": "green_test", "card_id": "verdant_suture", "level": 0}]
	manager.begin_turn(hand)
	var fired: Array[Dictionary] = manager.register_clear_event(
		{"type": "gray", "count": 4, "cascade": 1, "active": true},
		10,
		{"moves_left": 3, "moves_left_after": 2}
	)
	_expect(fired.size() == 1 and String(fired[0].get("card_id", "")) == "verdant_suture", "通用 color_total 条件应触发翠痕缝合。")

func _test_generic_effects() -> void:
	var battle: BattleManager = _new_battle()
	game_manager.player_hp = 60
	game_manager.shield = 0
	battle._apply_generic_spectrum_effects(GameDataScript.spectrum("moss_guard"))
	_expect(game_manager.player_hp == 62, "通用回复效果应结算。")
	_expect(game_manager.shield == 12, "通用护盾效果应结算。")
	battle.free()

func _test_relic_acquisition_hooks() -> void:
	game_manager.reset_run()
	var max_hp_before: int = game_manager.player_max_hp
	game_manager.add_relic("root_token")
	_expect(game_manager.player_max_hp == max_hp_before + 6, "根须护符获得时应提高最大 HP。")
	game_manager.add_relic("violet_ticket")
	_expect(game_manager.free_shop_refreshes == 2, "紫幕通票获得时应增加免费刷新。")

func _test_battle_relic_hooks() -> void:
	game_manager.reset_run()
	game_manager.add_relic("dawn_candle")
	game_manager.equipped_memory_ids.clear()
	var battle: BattleManager = _new_battle(false)
	_expect(game_manager.shield == 7, "黎明烛应在低灰蚀压力战斗开场提供护盾。")
	battle.free()

func _test_chained_event() -> void:
	game_manager.reset_run()
	game_manager.configure_starting_archetype("red")
	game_manager.current_node_id = "C1-02B"
	var first_result: String = game_manager.apply_event_choice("colorless_orchestra", "listen")
	_expect(not first_result.begins_with("资源不足"), "连续事件第一段应可支付默认 1 颜料。")
	_expect(game_manager.pending_event_chain_id == "orchestra_backstage", "第一段事件应进入后台连续事件。")
	_expect(not game_manager.visited_nodes.has("C1-02B"), "连续事件未结束前不应完成节点。")
	game_manager.apply_event_choice("orchestra_backstage", "tune")
	_expect(game_manager.pending_event_chain_id == "" and game_manager.visited_nodes.has("C1-02B"), "连续事件第二段应完成原节点。")

func _test_character_routes() -> void:
	game_manager.reset_run()
	game_manager.configure_starting_archetype("red")
	game_manager.current_node_id = "C1-02A"
	game_manager.current_options.assign(["C1-03X"])
	_expect(game_manager.choose_node("C1-03X"), "烬歌应能进入燃尽风口专属挑战。")
	game_manager.reset_run()
	game_manager.configure_starting_archetype("gold")
	game_manager.current_node_id = "C1-02A"
	game_manager.current_options.assign(["C1-03X"])
	_expect(not game_manager.choose_node("C1-03X"), "洛恩不能进入燃尽风口专属挑战。")

func _test_event_assignment_persistence() -> void:
	game_manager.reset_run()
	game_manager.current_node_id = "C1-02B"
	var assigned: String = game_manager.get_current_event_id()
	_expect(GameDataScript.CHAPTER_NODES["C1-02B"].get("event_pool", []).has(assigned), "事件节点应从配置池选择事件。")
	var snapshot: Dictionary = game_manager.create_save_snapshot()
	game_manager.reset_run()
	_expect(game_manager.restore_save_snapshot(snapshot), "带事件分配的存档应可恢复。")
	_expect(game_manager.get_current_event_id() == assigned, "读档后事件节点不能重新随机。")

func _test_challenge_reward() -> void:
	game_manager.reset_run()
	game_manager.configure_starting_archetype("red")
	game_manager.current_node_id = "C1-03X"
	var reward: Dictionary = game_manager.build_battle_reward(game_manager.get_current_encounter())
	_expect(String(reward.get("node_type", "")) == "challenge", "挑战战应保留独立节点类型。")
	_expect(int(reward.get("pigment", 0)) == 1 and int(reward.get("skip_bonus", 0)) == 15, "挑战战应提供 1 颜料与 15 金币跳过奖励。")

func _new_battle(reset: bool = true) -> BattleManager:
	if reset:
		game_manager.reset_run()
	var battle: BattleManager = BattleManagerScript.new()
	battle.GameManager = game_manager
	root.add_child(battle)
	battle.start_battle(GameDataScript.encounter("C1-01"))
	return battle

func _expect(condition: bool, message: String) -> void:
	if not condition and not failures.has(message):
		failures.append(message)
