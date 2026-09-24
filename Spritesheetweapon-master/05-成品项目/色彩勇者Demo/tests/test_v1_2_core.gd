extends SceneTree

const BattleManagerScript = preload("res://scripts/BattleManager.gd")
const BoardScript = preload("res://scripts/Board.gd")
const GameDataScript = preload("res://scripts/GameData.gd")
const MapTemplateResolverScript = preload("res://scripts/MapTemplateResolver.gd")

var failures: Array[String] = []
var game_manager: Node

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	game_manager = root.get_node("GameManager")
	_test_board_contract()
	_test_map_template_catalog()
	_test_map_template_save_restore()
	_test_clear_to_spectrum_resolution()
	_test_character_skills()
	if failures.is_empty():
		print("V1.2 core tests passed: 5")
		quit(0)
		return
	for failure in failures:
		push_error(failure)
	quit(1)

func _test_board_contract() -> void:
	_expect(BoardScript.COLS == 6 and BoardScript.ROWS == 6, "1.2 棋盘必须固定为 6x6。")
	_expect(is_equal_approx(float(GameDataScript.BASE_WEIGHTS.get("gray", 0.0)), 0.43), "基础灰色权重必须为 43%。")
	var total: float = 0.0
	for weight in GameDataScript.BASE_WEIGHTS.values():
		total += float(weight)
	_expect(is_equal_approx(total, 1.0), "基础棋盘权重之和必须为 1。")

func _test_map_template_catalog() -> void:
	var catalog: Dictionary = GameDataScript.map_template_catalog()
	var errors: Array[String] = MapTemplateResolverScript.validate_catalog(catalog, 3)
	_expect(errors.is_empty(), "正式地图模板目录必须通过图校验：%s" % str(errors))
	for chapter_id in ["C1", "C2", "C3"]:
		_expect(GameDataScript.MAP_TEMPLATE_SPECS.get(chapter_id, {}).size() == 4, "%s 必须有 4 张轮换地图。" % chapter_id)

func _test_map_template_save_restore() -> void:
	game_manager.reset_run()
	game_manager.run_seed = 20260727
	game_manager._select_map_templates()
	var selected: Dictionary = game_manager.map_template_ids.duplicate(true)
	var snapshot: Dictionary = game_manager.create_save_snapshot()
	game_manager.reset_run()
	_expect(game_manager.restore_save_snapshot(snapshot), "1.2 存档应可恢复。")
	_expect(game_manager.run_seed == 20260727, "运行 Seed 必须随存档恢复。")
	_expect(game_manager.map_template_ids == selected, "三章地图模板选择必须随存档恢复。")

func _test_clear_to_spectrum_resolution() -> void:
	var battle: BattleManager = _new_battle("red")
	var hand: Array[Dictionary] = [{"instance_id": "v12_ember", "card_id": "ember_slash", "level": 0}]
	battle.spectrum_manager.begin_turn(hand)
	var hp_before: int = battle.enemy.hp
	battle._apply_clear_events([{"type": "red", "count": 5, "cascade": 1, "active": true}])
	_expect(battle.enemy.hp < hp_before, "普通消除不直接攻击，但达成棋谱后必须立即结算伤害。")
	_expect(int(battle.battle_pigments.get("red", 0)) == 8, "5 连必须产出 8 点对应色素。")
	_expect(String(battle.last_spectrum_resolution.get("card_id", "")) == "ember_slash", "即时结算必须保留来源棋谱。")
	_expect(int(battle.last_spectrum_resolution.get("total_damage", 0)) > 0, "即时结算必须记录本次棋谱总伤害。")
	battle.free()

func _test_character_skills() -> void:
	for character_id in ["red", "blue", "gold", "gray", "mixed"]:
		var battle: BattleManager = _new_battle(character_id)
		var skill: Dictionary = game_manager.get_selected_character().get("active_skill", {})
		_expect(not skill.is_empty(), "%s 必须配置主动技。" % character_id)
		battle.skill_charge = int(skill.get("cost", 12))
		_expect(battle.use_character_skill(), "%s 主动技在满充能时必须可执行。" % character_id)
		_expect(battle.skill_charge == 0, "%s 主动技必须消耗对应充能。" % character_id)
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
