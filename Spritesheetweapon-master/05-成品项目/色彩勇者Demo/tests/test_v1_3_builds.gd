extends SceneTree

const BattleManagerScript = preload("res://scripts/BattleManager.gd")
const GameDataScript = preload("res://scripts/GameData.gd")
const SpectrumResolutionScript = preload("res://scripts/SpectrumResolution.gd")

var failures: Array[String] = []
var game_manager: Node

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	game_manager = root.get_node("GameManager")
	_test_content_scale()
	_test_peg_upgrade_bounds_and_save()
	_test_peg_upgrade_shop_transaction()
	_test_peg_event_transaction()
	_test_relic_shot_parameters()
	_test_peg_reward_hooks()
	if failures.is_empty():
		print("V1.3 build tests passed: 6")
		quit(0)
		return
	for failure in failures:
		push_error(failure)
	quit(1)

func _test_content_scale() -> void:
	_expect(GameDataScript.RELICS.size() >= 60, "1.3 必须至少提供 60 件遗物。")
	_expect(GameDataScript.EVENTS.size() >= 30, "1.3 必须至少提供 30 个事件。")
	for event_id in ["pegsmith", "echo_well", "bounty_lane", "prism_vendor", "mist_foundry", "silent_board"]:
		_expect(GameDataScript.EVENTS.has(event_id), "缺少 1.3 钉板事件：%s。" % event_id)

func _test_peg_upgrade_bounds_and_save() -> void:
	game_manager.reset_run()
	_expect(game_manager.upgrade_peg("critical"), "暴击钉应可强化。")
	_expect(game_manager.upgrade_peg("critical", 5), "一次强化可封顶但不能超过上限。")
	_expect(int(game_manager.peg_upgrades.get("critical", 0)) == 3, "钉板强化上限必须为 3。")
	_expect(not game_manager.upgrade_peg("critical"), "满级钉板强化必须拒绝重复升级。")
	var snapshot: Dictionary = game_manager.create_save_snapshot()
	game_manager.reset_run()
	_expect(game_manager.restore_save_snapshot(snapshot), "带钉板强化的存档应可恢复。")
	_expect(int(game_manager.peg_upgrades.get("critical", 0)) == 3, "读档后钉板强化等级必须保持。")

func _test_peg_upgrade_shop_transaction() -> void:
	game_manager.reset_run()
	game_manager.coins = 500
	var inventory: Array[Dictionary] = game_manager.make_shop_inventory()
	for item in inventory:
		if String(item.get("type", "")) != "peg_upgrade":
			continue
		var upgrade_key: String = String(item.get("id", ""))
		var coins_before: int = game_manager.coins
		_expect(game_manager.buy_shop_item(item), "商店钉板强化应可购买。")
		_expect(int(game_manager.peg_upgrades.get(upgrade_key, 0)) == 1, "购买后对应钉板强化应提升 1 级。")
		_expect(game_manager.coins < coins_before, "购买钉板强化必须扣除金币。")
		return
	_expect(false, "商店必须展示 1 项未满级钉板强化。")

func _test_peg_event_transaction() -> void:
	game_manager.reset_run()
	game_manager.configure_starting_archetype("red")
	game_manager.current_node_id = "C1-02B"
	game_manager.coins = 100
	var result: String = game_manager.apply_event_choice("pegsmith", "critical")
	_expect(not result.contains("不足"), "钉板铸匠事件应能正常结算。")
	_expect(int(game_manager.peg_upgrades.get("critical", 0)) == 1, "事件应提升暴击钉等级。")
	_expect(game_manager.visited_nodes.has("C1-02B"), "钉板事件完成后必须结算当前节点。")

func _test_relic_shot_parameters() -> void:
	var battle: BattleManager = _new_battle("red")
	var red_card: Dictionary = GameDataScript.spectrum("ember_slash")
	var red_profile: Dictionary = game_manager.get_selected_character().get("spectrum_profile", {})
	var red_modifier: Dictionary = red_card.get("shot_modifier", {})
	var baseline: Dictionary = SpectrumResolutionScript.resolve(red_card, red_profile, red_modifier, game_manager.peg_upgrades)
	game_manager.add_relic("flare_nozzle")
	game_manager.add_relic("critical_ink")
	game_manager.peg_upgrades["critical"] = 2
	var boosted: Dictionary = SpectrumResolutionScript.resolve(red_card, red_profile, red_modifier, game_manager.peg_upgrades)
	battle._apply_resolution_relics(boosted, red_card)
	_expect(
		int(boosted.get("damage", 0)) == int(baseline.get("damage", 0)) + 11,
		"旧版暴击强化、赤焰喷口与临界墨滴必须迁移为色谱结算伤害。"
	)
	battle.free()

	battle = _new_battle("red")
	game_manager.add_relic("prism_splitter")
	var mixed_card: Dictionary = GameDataScript.spectrum("finale_variation")
	var mixed_profile: Dictionary = game_manager.get_selected_character().get("spectrum_profile", {})
	var prism_resolution: Dictionary = SpectrumResolutionScript.resolve(
		mixed_card,
		mixed_profile,
		mixed_card.get("shot_modifier", {}),
		game_manager.peg_upgrades
	)
	var mixed_baseline_damage: int = int(prism_resolution.get("damage", 0))
	battle._apply_resolution_relics(prism_resolution, mixed_card)
	_expect(
		int(prism_resolution.get("damage", 0)) == mixed_baseline_damage + 6,
		"棱镜分光器的旧版多球收益必须迁移为混色色谱的固定伤害。"
	)
	battle.free()

func _test_peg_reward_hooks() -> void:
	var battle: BattleManager = _new_battle("gold")
	game_manager.add_relic("profit_pin")
	game_manager.add_relic("echo_spring")
	game_manager.peg_upgrades["bounty"] = 1
	game_manager.peg_upgrades["echo"] = 1
	var gold_card: Dictionary = {"rarity": "common", "color": "gold"}
	var gold_resolution: Dictionary = SpectrumResolutionScript.resolve(
		gold_card,
		{},
		{},
		game_manager.peg_upgrades
	)
	battle._apply_resolution_relics(gold_resolution, gold_card)
	_expect(
		int(gold_resolution.get("coins", 0)) == 2,
		"旧版悬赏强化与悬赏金钉必须迁移为金色色谱完成金币。"
	)
	var vow_ratio: float = clampf(float(game_manager.get_selected_vow().get("resonance_damage_ratio", 1.0)), 1.0, 1.25)
	var memory_damage: int = max(int(game_manager.get_memory_effect_total("resonance_base_damage")), 0)
	var expected_resonance_damage: int = int(round(float(9 + memory_damage) * vow_ratio))
	var actual_resonance_damage: int = battle._resolve_resonance({"id": "unison", "name": "同频和声"}, "neutral")
	_expect(
		actual_resonance_damage == expected_resonance_damage,
		"旧版回声强化与回声簧片必须迁移为谱序共鸣伤害（实际 %d，预期 %d）。" % [actual_resonance_damage, expected_resonance_damage]
	)
	battle.free()

func _new_battle(character_id: String) -> BattleManager:
	game_manager.reset_run()
	game_manager.configure_starting_archetype(character_id)
	var battle: BattleManager = BattleManagerScript.new()
	battle.GameManager = game_manager
	root.add_child(battle)
	battle.start_battle(GameDataScript.encounter("C1-01"))
	return battle

func _expect(condition: bool, message: String) -> void:
	if not condition and not failures.has(message):
		failures.append(message)
