extends SceneTree

const TEST_SAVE_PATH := "user://test_reward_transaction_save.json"

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

	_run_test("奖励生成幂等", _test_reward_generation_is_idempotent)
	_run_test("奖励只能领取一次", _test_reward_can_only_be_claimed_once)
	_run_test("跳过奖励原子结算", _test_skip_reward_transaction)
	_run_test("Boss 奖励无需选牌", _test_boss_reward_claim)

	save_manager.clear_run()
	save_manager.run_save_path = original_save_path
	print("Reward transaction tests: %d passed, %d failed" % [passed_tests, failures.size()])
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

func _test_reward_generation_is_idempotent() -> void:
	game_manager.reset_run()
	_enter_test_node("C1-01")
	var first: Dictionary = game_manager.build_battle_reward(game_manager.get_current_encounter())
	var second: Dictionary = game_manager.build_battle_reward(game_manager.get_current_encounter())
	_expect(first == second, "同一节点重复生成奖励时应返回同一事务。")
	_expect(String(first.get("transaction_id", "")) != "", "奖励事务必须具有 transaction_id。")
	_expect(game_manager.has_pending_reward(), "生成奖励后应保留待领取事务。")

func _test_reward_can_only_be_claimed_once() -> void:
	game_manager.reset_run()
	_enter_test_node("C1-01")
	var reward: Dictionary = game_manager.build_battle_reward(game_manager.get_current_encounter())
	var starting_coins: int = game_manager.coins
	var card_id: String = String(reward.get("cards", [""])[0])
	var deck_size: int = game_manager.deck.size()
	_expect(game_manager.claim_battle_reward(card_id), "有效卡牌奖励应领取成功。")
	_expect(game_manager.coins == starting_coins + int(reward.get("gold", 0)), "领取后金币应精确入账一次。")
	_expect(game_manager.pigment == 1 + int(reward.get("pigment", 0)), "领取后颜料应精确入账一次。")
	_expect(game_manager.deck.size() == deck_size + 1, "领取卡牌后牌组应增加一张。")
	_expect(game_manager.visited_nodes.has("C1-01"), "领取奖励后当前节点应完成。")
	_expect(not game_manager.has_pending_reward(), "领取后待领取事务应清空。")
	var coins_after_claim: int = game_manager.coins
	_expect(not game_manager.claim_battle_reward(card_id), "同一奖励不能领取第二次。")
	_expect(game_manager.coins == coins_after_claim, "重复领取失败时不能再次增加金币。")

func _test_skip_reward_transaction() -> void:
	game_manager.reset_run()
	_enter_test_node("C1-01")
	var reward: Dictionary = game_manager.build_battle_reward(game_manager.get_current_encounter())
	var starting_coins: int = game_manager.coins
	var deck_size: int = game_manager.deck.size()
	_expect(game_manager.claim_battle_reward("", true), "跳过卡牌应成功结算奖励。")
	_expect(game_manager.coins == starting_coins + int(reward.get("gold", 0)) + 10, "跳过卡牌应额外获得 10 金币。")
	_expect(game_manager.deck.size() == deck_size, "跳过卡牌不应改变牌组。")

func _test_boss_reward_claim() -> void:
	game_manager.reset_run()
	_enter_test_node("C1-08")
	var reward: Dictionary = game_manager.build_battle_reward(game_manager.get_current_encounter())
	var starting_coins: int = game_manager.coins
	_expect(game_manager.claim_battle_reward(), "Boss 奖励应允许不选卡直接领取。")
	_expect(game_manager.coins == starting_coins + int(reward.get("gold", 0)), "Boss 奖励不应获得跳过加成。")
	_expect(game_manager.relics.has("colorless_crown"), "Boss 奖励应发放无色王冠。")

func _expect(condition: bool, message: String) -> void:
	if not condition and not failures.has(message):
		failures.append(message)

func _enter_test_node(node_id: String) -> void:
	game_manager.current_node_id = "C1-07" if node_id == "C1-08" else "C1-00"
	game_manager.current_options.assign([node_id])
	_expect(game_manager.choose_node(node_id), "测试节点 %s 应作为显式合法出口进入。" % node_id)
