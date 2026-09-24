extends SceneTree

const BATTLE_MANAGER = preload("res://scripts/BattleManager.gd")
const GAME_DATA = preload("res://scripts/GameData.gd")

var failures: Array[String] = []
var reported_moves_left: int = -1


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var game_manager: Node = root.get_node("GameManager")
	game_manager.reset_run()
	game_manager.configure_starting_archetype("red")
	var battle: BattleManager = BATTLE_MANAGER.new()
	battle.GameManager = game_manager
	root.add_child(battle)
	battle.state_changed.connect(func(state: Dictionary) -> void:
		reported_moves_left = int(state.get("moves_left", -1))
	)
	battle.start_battle(GAME_DATA.encounter("C1-01"))
	battle.moves_left = 1
	battle._emit_state(0)

	_expect(battle.moves_left == 1, "消除事件阶段不得提前改变真实步数。")
	_expect(reported_moves_left == 0, "最后一次交换结算期间 HUD 必须预告剩余 0 步。")
	var source: String = FileAccess.get_file_as_string("res://scripts/BattleManager.gd")
	_expect(source.contains("_emit_state(max(moves_left - 1, 0))"), "消除事件状态必须使用扣步后的显示值。")
	_expect(battle._pigment_yield(3, 1) == 3, "首层三消应获得 3 点基础颜料。")
	_expect(battle._pigment_yield(3, 99) == 8, "连锁颜料加成必须封顶为 +5。")

	game_manager.add_relic("red_hilt")
	var enemy_hp_before: int = battle.enemy.hp
	var red_pigment_before: int = int(battle.battle_pigments.get("red", 0))
	var skill_charge_before: int = battle.skill_charge
	battle._apply_color_baseline("red", 4, 1, 5)
	_expect(battle.enemy.hp == enemy_hp_before, "红釉剑柄不得让普通消除直接造成伤害。")
	_expect(int(battle.battle_pigments.get("red", 0)) == red_pigment_before + 1, "红釉剑柄应额外获得 1 红色素。")
	_expect(battle.skill_charge == mini(skill_charge_before + 1, battle.MAX_SKILL_CHARGE), "红釉剑柄的额外颜料应计入技能充能。")
	battle.free()

	if failures.is_empty():
		print("V2 battle state tests passed: 8")
		quit(0)
		return
	for failure in failures:
		push_error(failure)
	quit(1)


func _expect(condition: bool, message: String) -> void:
	if not condition and not failures.has(message):
		failures.append(message)
