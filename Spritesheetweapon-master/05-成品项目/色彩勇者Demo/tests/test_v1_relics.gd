extends SceneTree

const BattleManagerScript = preload("res://scripts/BattleManager.gd")
const GameDataScript = preload("res://scripts/GameData.gd")
const SpectrumManagerScript = preload("res://scripts/SpectrumManager.gd")

var failures: Array[String] = []
var passed_tests: int = 0
var game_manager: Node

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	game_manager = root.get_node("GameManager")
	_run_test("四色骰降低条件", _test_four_color_die_reduces_condition)
	_run_test("镀金钥匙宝箱二选一", _test_gilded_key_chest_choice)
	_run_test("残破王旗 Boss 后复制", _test_torn_banner_boss_copy)
	_run_test("商店免费与付费刷新", _test_shop_refresh_costs)
	_run_test("终幕花冠按最低倾向护盾", _test_finale_crown_shield)
	_run_test("终幕工坊可获得花冠", _test_final_workshop_grants_crown)
	_run_test("裂纹算盘缩放金色数值", _test_cracked_abacus_scaling)
	_run_test("1.0 新增状态存档", _test_v1_state_save_restore)
	print("V1 relic tests: %d passed, %d failed" % [passed_tests, failures.size()])
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

func _test_four_color_die_reduces_condition() -> void:
	var manager: SpectrumManager = SpectrumManagerScript.new()
	var card: Dictionary = {"instance_id": "die_card", "card_id": "ember_slash", "level": 0}
	var event: Dictionary = {"type": "red", "count": 4, "cascade": 1, "active": true}
	var context: Dictionary = {"moves_left": 3, "moves_left_after": 2}
	manager.begin_turn([card], false)
	_expect(manager.register_clear_event(event, 10, context).is_empty(), "余烬斩原始条件为累计红色 5，红 4 不应触发。")
	manager.begin_turn([card], true)
	var fired: Array[Dictionary] = manager.register_clear_event(event, 10, context)
	_expect(fired.size() == 1, "四色骰应把余烬斩条件从 5 降为 4。")
	var states: Array[Dictionary] = manager.get_card_states()
	_expect(states.size() == 1 and states[0].get("condition_reduced", false) == true, "四色骰减免应在色谱状态中可见。")

func _test_gilded_key_chest_choice() -> void:
	game_manager.reset_run()
	game_manager.current_node_id = "C1-03B"
	var starting_coins: int = game_manager.coins
	game_manager.add_relic("gilded_key")
	_expect(game_manager.get_chest_choices().size() == 2, "镀金钥匙应显示遗物与资源两个宝箱选项。")
	_expect(game_manager.apply_chest_reward().is_empty(), "持有镀金钥匙时不能绕过选择直接随机结算。")
	_expect(not game_manager.visited_nodes.has("C1-03B"), "未选择宝箱奖励前节点不能完成。")
	var reward: Dictionary = game_manager.apply_chest_reward("gold")
	_expect(int(reward.get("coins", 0)) == 45, "镀金钥匙资源选项应获得 45 金币。")
	_expect(game_manager.coins == starting_coins + 45 and game_manager.pigment == 2, "宝箱资源应正确写入局内资源。")
	_expect(game_manager.visited_nodes.has("C1-03B"), "完成宝箱选择后节点应结算。")

func _test_torn_banner_boss_copy() -> void:
	game_manager.reset_run()
	game_manager.current_node_id = "C2-07"
	game_manager.current_options.assign(["C2-08"])
	_expect(game_manager.choose_node("C2-08"), "测试应能通过显式出口进入第二章 Boss。")
	var reward: Dictionary = game_manager.build_battle_reward(game_manager.get_current_encounter())
	_expect(game_manager.claim_battle_reward(), "第二章 Boss 奖励应可直接领取。")
	_expect(game_manager.relics.has("torn_banner"), "第二章 Boss 应授予残破王旗。")
	_expect(game_manager.pending_torn_banner_reward, "获得残破王旗后应等待复制或升级选择。")
	_expect(not game_manager.choose_node("C3-01"), "王旗奖励未处理时不应进入下一章。")
	var source_id: String = String(game_manager.deck[0].get("instance_id", ""))
	var source_card_id: String = String(game_manager.deck[0].get("card_id", ""))
	var old_count: int = _deck_definition_count(source_card_id)
	_expect(game_manager.apply_torn_banner_choice("copy", source_id), "残破王旗复制选择应成功。")
	_expect(_deck_definition_count(source_card_id) == old_count + 1, "复制后牌组应增加同定义色谱。")
	_expect(not game_manager.pending_torn_banner_reward, "完成王旗选择后应解除路线锁。")
	_expect(game_manager.choose_node("C3-01"), "完成王旗选择后应可进入第三章。")

func _test_shop_refresh_costs() -> void:
	game_manager.reset_run()
	game_manager.coins = 100
	game_manager.free_shop_refreshes = 1
	var free_inventory: Array[Dictionary] = game_manager.refresh_shop_inventory()
	_expect(not free_inventory.is_empty(), "免费刷新应返回新商品。")
	_expect(game_manager.coins == 100 and game_manager.free_shop_refreshes == 0, "免费刷新不应扣金币，并应消耗次数。")
	var paid_price: int = game_manager.get_shop_refresh_price()
	var paid_inventory: Array[Dictionary] = game_manager.refresh_shop_inventory()
	_expect(not paid_inventory.is_empty(), "金币足够时付费刷新应成功。")
	_expect(game_manager.coins == 100 - paid_price, "付费刷新应精确扣除显示价格。")

func _test_finale_crown_shield() -> void:
	game_manager.reset_run()
	game_manager.add_relic("finale_crown")
	game_manager.color_usage = {"gray": 50, "red": 10, "blue": 10, "gold": 10}
	_expect(is_equal_approx(game_manager.get_lowest_player_color_ratio(), 1.0 / 3.0), "花冠倾向比例只应统计三种玩家色。")
	_expect(game_manager.get_finale_crown_shield() == 18, "三色均衡时花冠应达到 18 护盾上限。")
	game_manager.color_usage["gold"] = 0
	_expect(game_manager.get_finale_crown_shield() == 0, "完全未使用一种玩家色时不应获得花冠护盾。")
	game_manager.color_usage = {"gray": 0, "red": 10, "blue": 10, "gold": 10}
	game_manager.shield = 0
	game_manager.equipped_memory_ids.clear()
	var battle_manager: BattleManager = BattleManagerScript.new()
	battle_manager.GameManager = game_manager
	root.add_child(battle_manager)
	battle_manager.start_battle(GameDataScript.encounter("C3-08"))
	_expect(game_manager.shield == 18, "最终 Boss 开战时应实际发放终幕花冠护盾。")
	battle_manager.queue_free()

func _test_final_workshop_grants_crown() -> void:
	game_manager.reset_run()
	game_manager.current_node_id = "C3-05A"
	var result: String = game_manager.apply_event_choice("final_workshop", "temper")
	_expect(game_manager.player_max_hp == 112, "终幕校准应扣除 8 最大 HP。")
	_expect(game_manager.relics.has("finale_crown"), "终幕校准应授予终幕花冠。")
	_expect(result.contains("终幕花冠"), "事件结果应明确显示获得的遗物。")

func _test_cracked_abacus_scaling() -> void:
	game_manager.reset_run()
	game_manager.add_relic("cracked_abacus")
	game_manager.coins = 0
	var battle_manager: BattleManager = BattleManagerScript.new()
	battle_manager.GameManager = game_manager
	_expect(battle_manager._scaled_gold_value(10) == 13, "裂纹算盘应将金色色谱整数数值向上缩放 25%。")
	_expect(is_equal_approx(battle_manager._scaled_gold_float(0.2), 0.25), "裂纹算盘应将金色色谱比例数值缩放 25%。")
	game_manager.coins = 20
	_expect(battle_manager._scaled_gold_value(10) == 10, "金币达到 20 后裂纹算盘不应生效。")
	battle_manager.free()

func _test_v1_state_save_restore() -> void:
	game_manager.reset_run()
	game_manager.current_node_id = "C2-08"
	game_manager.shop_refresh_count = 3
	game_manager.free_shop_refreshes = 2
	game_manager.pending_torn_banner_reward = true
	game_manager.set_ascension_level(4)
	var snapshot: Dictionary = game_manager.create_save_snapshot()
	game_manager.reset_run()
	_expect(game_manager.restore_save_snapshot(snapshot), "包含 1.0 新字段的快照应可恢复。")
	_expect(game_manager.shop_refresh_count == 3, "商店刷新次数应从存档恢复。")
	_expect(game_manager.free_shop_refreshes == 2, "免费刷新次数应从存档恢复。")
	_expect(game_manager.pending_torn_banner_reward, "待处理王旗奖励应从存档恢复。")
	_expect(game_manager.ascension_level == 4, "进阶等级应从存档恢复。")

func _deck_definition_count(card_id: String) -> int:
	var count: int = 0
	for card in game_manager.deck:
		if String(card.get("card_id", "")) == card_id:
			count += 1
	return count

func _expect(condition: bool, message: String) -> void:
	if not condition and not failures.has(message):
		failures.append(message)
