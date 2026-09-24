extends SceneTree

const RULES = preload("res://scripts/StrategyRules.gd")
const MANAGER = preload("res://scripts/GameManager.gd")
var failures: Array[String] = []
var checks: int = 0

func _init() -> void:
	call_deferred("_run")

func _expect(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures.append(message)

func _run() -> void:
	var gm: Node = MANAGER.new()
	gm.reset_run()
	_expect(RULES.ids().size() == 4, "four policies")
	_expect(not gm.apply_policy("blue_charter"), "cannot legislate before character and vow")
	gm.reset_run()
	gm.apply_start_choice("red")
	gm.apply_vow("vow_witness")
	_expect(gm.apply_policy("blue_charter"), "policy chosen after vow")
	_expect(not gm.apply_policy("red_accord"), "one policy per chapter")
	_expect(gm.get_policy_battle_shield() == 6, "blue shield")
	gm.current_node_id = "C1-08"
	gm.run_phase = "battle"
	_expect(not gm.apply_policy("golden_exchange"), "boss must finish before next chapter policy")
	gm.current_node_id = "C1-00"
	gm.run_phase = "map"
	gm.current_node_id = "C1-01"
	gm.run_phase = "battle"
	var save: Dictionary = gm.create_save_snapshot()
	_expect(gm.restore_save_snapshot(JSON.parse_string(JSON.stringify(save))), "json roundtrip")
	_expect(gm.selected_policy_id == "blue_charter" and gm.run_phase == "battle", "battle restore stays in battle")
	gm.current_node_id = "C1-08"
	gm.complete_current_node()
	_expect(gm.apply_policy("golden_exchange"), "next chapter policy after boss")
	_expect(gm.get_policy_battle_shield() == 0, "new policy replaces old")
	var refreshes: int = gm.free_shop_refreshes
	_expect(not gm.apply_policy("golden_exchange") and gm.free_shop_refreshes == refreshes, "no repeated refresh grant")
	_expect(gm._character_shop_price(100) == 110, "gold policy shop tradeoff")
	var next_save: Dictionary = gm.create_save_snapshot()
	_expect(gm.restore_save_snapshot(next_save) and gm.run_phase == "map", "post-boss council persists as map")
	_expect(gm.selected_policy_id == "golden_exchange", "future chapter policy survives boss checkpoint")
	gm.current_node_id = "C2-01"
	gm.run_phase = "battle"
	_expect(not gm.apply_policy("red_accord"), "no policy inside battle")
	var coins: int = gm.coins
	var pigment: int = gm.pigment
	_expect(not gm.spend_coins(-5) and gm.coins == coins, "negative gold payment cannot mint money")
	_expect(not gm.spend_pigment(-1) and gm.pigment == pigment, "negative pigment payment cannot mint pigment")
	save.erase("selected_policy_id")
	save.erase("chapter_policies")
	_expect(gm.restore_save_snapshot(save) and gm.selected_policy_id == "" and gm.run_phase == "battle", "old saves remain in battle")
	gm.reset_run()
	_expect(gm.selected_policy_id == "", "reset clears policy")
	gm.apply_start_choice("red")
	gm.apply_vow("vow_witness")
	gm.apply_policy("red_accord")
	var enemy: Dictionary = gm._scaled_encounter({"max_hp": 100, "attack": 8, "intents": [{"type": "attack", "value": 8}, {"type": "charge", "value": 20}, {"type": "heavy", "value": 20}]})
	_expect(enemy.attack == 10 and enemy.intents[0].value == 10 and enemy.intents[1].value == 22 and enemy.intents[2].value == 22, "red enemy tradeoff and accurate charge preview")
	gm.run_phase = "battle"
	gm.current_node_id = "C1-01"
	gm.chapter_policies.clear()
	gm.selected_policy_id = ""
	_expect(not gm.apply_policy("red_accord"), "empty policy cannot be adopted midbattle")
	gm.free()
	print("V2.3 strategy: %d checks, %d failures" % [checks, failures.size()])
	for message in failures:
		push_error(message)
	quit(0 if failures.is_empty() else 1)
