extends SceneTree

const BOARD_SCRIPT = preload("res://scripts/Board.gd")
const BATTLE_SCRIPT = preload("res://scripts/BattleManager.gd")
const GAME_DATA_SCRIPT = preload("res://scripts/GameData.gd")
const SPECTRUM_SCRIPT = preload("res://scripts/SpectrumManager.gd")

var failures: Array[String] = []
var passed_tests: int = 0

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	_run_test("map view save round trip", _test_map_view_round_trip)
	_run_test("battle checkpoint round trip", _test_battle_checkpoint_round_trip)
	_run_test("battle restore does not replay opening effects", _test_restore_does_not_replay_opening_effects)
	_run_test("invalid battle node is discarded", _test_invalid_battle_node_is_discarded)
	_run_test("stable checkpoint signal is emitted", _test_stable_checkpoint_signal)
	_run_test("board snapshot rejects unplayable data", _test_board_snapshot_validation)
	_run_test("spectrum snapshot preserves every school count", _test_spectrum_snapshot_preserves_school_counts)
	_run_test("victory reward is committed before presentation delay", _test_reward_commit_precedes_delay)

	print("V2.1 recovery tests: %d passed, %d failed" % [passed_tests, failures.size()])
	if failures.is_empty():
		quit(0)
		return
	for failure in failures:
		push_error(failure)
	quit(1)

func _run_test(test_name: String, test_callable: Callable) -> void:
	var before: int = failures.size()
	test_callable.call()
	if failures.size() == before:
		passed_tests += 1
		print("[PASS] %s" % test_name)
	else:
		print("[FAIL] %s" % test_name)

func _new_battle() -> Dictionary:
	var game_manager: Node = root.get_node("GameManager")
	game_manager.reset_run()
	game_manager.configure_starting_archetype("red")
	game_manager.current_node_id = "C1-01"
	game_manager.current_options.clear()
	game_manager.run_phase = "battle"
	var board: Board = BOARD_SCRIPT.new()
	root.add_child(board)
	board.setup(game_manager.get_board_weights())
	var battle: BattleManager = BATTLE_SCRIPT.new()
	battle.GameManager = game_manager
	root.add_child(battle)
	battle.start_battle(GAME_DATA_SCRIPT.encounter("C1-01"))
	return {"game_manager": game_manager, "board": board, "battle": battle}

func _test_map_view_round_trip() -> void:
	var game_manager: Node = root.get_node("GameManager")
	game_manager.reset_run()
	game_manager.set_map_view_state("C1", 1.35, Vector2(84.0, -42.0), "C1-01")
	var snapshot: Dictionary = game_manager.create_save_snapshot()
	game_manager.reset_run()
	_expect(game_manager.restore_save_snapshot(snapshot), "地图视图夹具必须能够恢复。")
	var restored: Dictionary = game_manager.get_map_view_state("C1")
	_expect(is_equal_approx(float(restored.get("zoom", 0.0)), 1.35), "地图缩放比例必须进入局内存档。")
	var pan: Vector2 = restored.get("pan", Vector2.ZERO)
	_expect(pan.is_equal_approx(Vector2(84.0, -42.0)), "地图平移量必须进入局内存档。")
	_expect(String(restored.get("node_id", "")) == "C1-01", "地图视图必须记录用于自动聚焦的进度节点。")

func _test_battle_checkpoint_round_trip() -> void:
	var fixture: Dictionary = _new_battle()
	var game_manager: Node = fixture["game_manager"]
	var board: Board = fixture["board"]
	var battle: BattleManager = fixture["battle"]
	battle.moves_left = 2
	battle.turn_number = 3
	battle.skill_charge = 11
	battle.enemy.hp = 43
	battle.enemy.armor = 9
	battle.enemy.apply_burn(2, 2)
	battle.enemy.set_resistance("blue", 0.35, 2)
	battle.enemy_polluted_this_battle = true
	battle.pending_enemy_disruption = {"type": "spectrum_suppress", "value": 4}
	var spectrum: SpectrumManager = battle.spectrum_manager as SpectrumManager
	spectrum.color_counts["red"] = 4
	var clear_history: Array[Dictionary] = [{"color": "red", "count": 4, "cascade": 1, "active": true}]
	spectrum.clear_event_history = clear_history
	battle.resonance_sequence.begin_turn()
	battle.resonance_sequence.register_color("red")
	var expected_grid: Array = board.grid.duplicate(true)
	var expected_hand: Array = spectrum.hand.duplicate(true)
	var checkpoint: Dictionary = battle.create_snapshot()
	checkpoint["board"] = board.create_snapshot()
	game_manager.set_battle_snapshot(checkpoint)
	var run_snapshot: Dictionary = game_manager.create_save_snapshot()
	var expected_hp: int = game_manager.player_hp
	var expected_shield: int = game_manager.shield

	game_manager.reset_run()
	_expect(game_manager.restore_save_snapshot(run_snapshot), "战斗检查点外层存档必须能够恢复。")
	var restored_board: Board = BOARD_SCRIPT.new()
	root.add_child(restored_board)
	_expect(restored_board.restore_snapshot(game_manager.get_battle_snapshot().get("board", {})), "战斗检查点棋盘必须能够恢复。")
	var restored_battle: BattleManager = BATTLE_SCRIPT.new()
	restored_battle.GameManager = game_manager
	root.add_child(restored_battle)
	_expect(restored_battle.restore_battle(GAME_DATA_SCRIPT.encounter("C1-01"), game_manager.get_battle_snapshot()), "战斗检查点管理器必须能够恢复。")
	_expect(restored_board.grid == expected_grid, "战斗恢复不得重建或改写棋盘。")
	_expect(restored_battle.spectrum_manager.hand == expected_hand, "战斗恢复必须保留当前色谱实例和条件基线。")
	_expect(restored_battle.moves_left == 2 and restored_battle.turn_number == 3, "战斗恢复必须保留步数和回合数。")
	_expect(restored_battle.enemy.hp == 43 and restored_battle.enemy.armor == 9, "战斗恢复必须保留敌人 HP 和护甲。")
	_expect(restored_battle.enemy_polluted_this_battle, "战斗恢复必须保留污染标记。")
	_expect(game_manager.player_hp == expected_hp and game_manager.shield == expected_shield, "战斗恢复不得改写外层 HP 或护盾。")
	board.free()
	battle.free()
	restored_board.free()
	restored_battle.free()

func _test_restore_does_not_replay_opening_effects() -> void:
	var fixture: Dictionary = _new_battle()
	var game_manager: Node = fixture["game_manager"]
	var board: Board = fixture["board"]
	var battle: BattleManager = fixture["battle"]
	var checkpoint: Dictionary = battle.create_snapshot()
	checkpoint["board"] = board.create_snapshot()
	game_manager.set_battle_snapshot(checkpoint)
	var run_snapshot: Dictionary = game_manager.create_save_snapshot()
	game_manager.reset_run()
	_expect(game_manager.restore_save_snapshot(run_snapshot), "开局副作用夹具必须能够恢复。")
	var hp_before: int = game_manager.player_hp
	var shield_before: int = game_manager.shield
	var turns_before: int = int(game_manager.run_stats.summary().get("turns", 0))
	var restored_battle: BattleManager = BATTLE_SCRIPT.new()
	restored_battle.GameManager = game_manager
	root.add_child(restored_battle)
	_expect(restored_battle.restore_battle(GAME_DATA_SCRIPT.encounter("C1-01"), game_manager.get_battle_snapshot()), "开局副作用夹具必须交给恢复分支。")
	_expect(game_manager.player_hp == hp_before, "恢复战斗不得再次触发开局治疗。")
	_expect(game_manager.shield == shield_before, "恢复战斗不得再次触发开局护盾。")
	_expect(int(game_manager.run_stats.summary().get("turns", 0)) == turns_before, "恢复战斗不得再次增加回合统计。")
	board.free()
	battle.free()
	restored_battle.free()

func _test_invalid_battle_node_is_discarded() -> void:
	var game_manager: Node = root.get_node("GameManager")
	game_manager.reset_run()
	game_manager.current_node_id = "C1-01"
	var snapshot: Dictionary = game_manager.create_save_snapshot()
	snapshot["run_phase"] = "battle"
	snapshot["battle_snapshot"] = {
		"snapshot_version": 1,
		"node_id": "C2-01",
		"enemy": {},
		"spectrum": {},
		"board": {},
	}
	_expect(game_manager.restore_save_snapshot(snapshot), "不匹配节点的战斗快照不应阻止外层存档恢复。")
	_expect(not game_manager.has_battle_snapshot(), "不匹配当前节点的战斗快照必须被丢弃。")

func _test_stable_checkpoint_signal() -> void:
	var fixture: Dictionary = _new_battle()
	var battle: BattleManager = fixture["battle"]
	var checkpoint_count: Array[int] = [0]
	battle.checkpoint_ready.connect(func(snapshot: Dictionary) -> void:
		if not snapshot.is_empty():
			checkpoint_count[0] += 1
	)
	battle._emit_checkpoint()
	_expect(checkpoint_count[0] == 1, "稳定战斗状态必须能主动产生一个检查点。")
	_expect(not battle.create_snapshot().is_empty(), "稳定战斗状态的快照不能为空。")
	(fixture["board"] as Board).free()
	battle.free()

func _test_board_snapshot_validation() -> void:
	var board: Board = BOARD_SCRIPT.new()
	root.add_child(board)
	board.setup({"gray": 0.43, "red": 0.19, "blue": 0.19, "gold": 0.19})
	var snapshot: Dictionary = board.create_snapshot()
	var invalid_grid: Array = snapshot["grid"].duplicate(true)
	for y in range(6):
		for x in range(6):
			invalid_grid[y][x] = "red"
	var invalid: Dictionary = snapshot.duplicate(true)
	invalid["grid"] = invalid_grid
	_expect(not board.restore_snapshot(invalid), "包含预成消除且无合法交换的棋盘快照必须被拒绝。")
	_expect(board.restore_snapshot(snapshot), "合法棋盘快照必须能够恢复。")
	board.free()

func _test_spectrum_snapshot_preserves_school_counts() -> void:
	var manager: SpectrumManager = SPECTRUM_SCRIPT.new()
	manager.begin_turn([{"instance_id": "school-count", "card_id": "ember_slash", "level": 0}])
	manager.completed_color_counts = {"red": 2, "purple": 3, "green": -1, "mixed": 4}
	var snapshot: Dictionary = manager.create_snapshot()
	var restored: SpectrumManager = SPECTRUM_SCRIPT.new()
	_expect(restored.restore_snapshot(snapshot), "A valid spectrum checkpoint must restore.")
	_expect(int(restored.completed_color_counts.get("red", 0)) == 2, "Base school counts must be restored.")
	_expect(int(restored.completed_color_counts.get("purple", 0)) == 3, "Extended school counts must be restored.")
	_expect(int(restored.completed_color_counts.get("mixed", 0)) == 4, "Mixed school counts must be restored.")
	_expect(int(restored.completed_color_counts.get("green", -1)) == 0, "School counts must be clamped to zero.")

func _test_reward_commit_precedes_delay() -> void:
	var source: String = FileAccess.get_file_as_string("res://scripts/Main.gd")
	var function_start: int = source.find("func _on_battle_won")
	var build_index: int = source.find("build_battle_reward", function_start)
	var await_index: int = source.find("await get_tree().create_timer", function_start)
	_expect(function_start >= 0 and build_index > function_start, "胜利处理必须创建奖励事务。")
	_expect(await_index < 0 or build_index < await_index, "奖励事务必须在展示延迟前落盘，避免胜利后丢失。")

func _expect(condition: bool, message: String) -> void:
	if not condition and not failures.has(message):
		failures.append(message)
