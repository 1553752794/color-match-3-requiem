extends SceneTree

const BattleManagerScript = preload("res://scripts/BattleManager.gd")
const BoardScript = preload("res://scripts/Board.gd")
const GameDataScript = preload("res://scripts/GameData.gd")

var failures: Array[String] = []
var game_manager: Node


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	game_manager = root.get_node("GameManager")
	await _test_charge_interrupt_cancels_heavy()
	await _test_resistance_lifecycle()
	_test_pollution_marker_drives_spectrum_condition()
	await _test_separated_same_color_matches_keep_three_count()
	_test_external_recolor_keeps_board_playable()

	print("V2 combat release boundary tests: 5 collected, %d assertion failures" % failures.size())
	if failures.is_empty():
		quit(0)
		return
	for failure in failures:
		push_error(failure)
	quit(1)


func _test_charge_interrupt_cancels_heavy() -> void:
	game_manager.reset_run()
	game_manager.configure_starting_archetype("blue")
	game_manager.shield = 0
	var battle: BattleManager = BattleManagerScript.new()
	battle.GameManager = game_manager
	root.add_child(battle)
	battle.start_battle(GameDataScript.encounter("C1-04B"))
	battle.enemy.turn_index = 1

	await battle._enemy_action()
	_expect(battle.enemy.charge_pending, "C1-04B must enter charge_pending during its charge intent.")

	var hand: Array[Dictionary] = [{"instance_id": "interrupt_card", "card_id": "ice_rest", "level": 0}]
	battle.spectrum_manager.begin_turn(hand)
	battle._apply_spectrum_effect("ice_rest", 0, 0)
	var hp_before_heavy: int = game_manager.player_hp
	var shield_before_heavy: int = game_manager.shield
	_expect(battle.enemy.interrupted_this_turn, "ice_rest must record that the current charge was interrupted.")
	_expect(not battle.enemy.charge_pending, "ice_rest must clear the pending charge before the next enemy action.")

	await battle._enemy_action()
	_expect(game_manager.player_hp == hp_before_heavy, "An interrupted charge must not let the queued heavy attack damage the player.")
	_expect(game_manager.shield == shield_before_heavy, "An interrupted charge must not consume the player's shield through a queued heavy attack.")
	battle.free()


func _test_resistance_lifecycle() -> void:
	game_manager.reset_run()
	game_manager.configure_starting_archetype("red")
	var battle: BattleManager = BattleManagerScript.new()
	battle.GameManager = game_manager
	root.add_child(battle)
	battle.start_battle(GameDataScript.encounter("C1-03A"))
	battle.enemy.turn_index = 2

	await battle._enemy_action()
	_expect(battle.enemy.resistance_color == "gold", "C1-03A's gold resistance must remain active after the resistance intent resolves.")
	_expect(battle.enemy.resistance_turns == 1, "A one-turn resistance must retain one complete enemy-turn lifetime after application.")

	var hp_before_resisted_hit: int = battle.enemy.hp
	var actual_damage: int = battle.enemy.take_damage(20, "gold")
	_expect(actual_damage == 13, "A 35 percent gold resistance must reduce a 20-damage gold hit to 13.")
	_expect(battle.enemy.hp == hp_before_resisted_hit - 13, "Resistance damage must be reflected in the enemy's real HP delta.")

	await battle._enemy_action()
	_expect(battle.enemy.resistance_turns == 0, "Resistance must expire after the following enemy action.")
	_expect(battle.enemy.resistance_color.is_empty() and battle.enemy.resistance_rate == 0.0, "Expired resistance must clear both its color and rate, not only its counter.")
	battle.free()


func _test_pollution_marker_drives_spectrum_condition() -> void:
	game_manager.reset_run()
	game_manager.configure_starting_archetype("red")
	var battle: BattleManager = BattleManagerScript.new()
	battle.GameManager = game_manager
	root.add_child(battle)
	battle.start_battle({
		"enemy_name": "Test Pollution Target",
		"enemy_id": "TEST-POLLUTE",
		"max_hp": 1000,
		"attack": 1,
		"reward": 0,
		"node_type": "combat",
		"intents": [
			{"type": "pollute", "value": 2},
			{"type": "attack", "value": 1},
		],
	})

	battle._resolve_intent({"type": "pollute", "value": 2})
	_expect(battle.enemy_polluted_this_battle, "A resolved pollute intent must set the battle-wide pollution marker.")

	var hand: Array[Dictionary] = [
		{"instance_id": "ember_instance", "card_id": "ember_slash", "level": 0},
		{"instance_id": "blank_instance", "card_id": "blank_archive", "level": 0},
	]
	battle.spectrum_manager.begin_turn(hand)
	battle._apply_clear_events([{"type": "red", "count": 5, "cascade": 1, "active": true}])
	_expect(battle.spectrum_manager.is_triggered(0), "The setup red five-match must complete the prerequisite ember spectrum.")
	_expect(battle.spectrum_manager.is_triggered(1), "The polluted_completed spectrum must see the pollution marker and trigger in the same turn.")
	battle.free()


func _test_separated_same_color_matches_keep_three_count() -> void:
	var board: Board = BoardScript.new()
	root.add_child(board)
	board.setup(GameDataScript.BASE_WEIGHTS)
	board.grid = [
		["red", "red", "red", "blue", "gold", "gray"],
		["blue", "gold", "gray", "blue", "gold", "gray"],
		["gold", "gray", "blue", "gold", "gray", "blue"],
		["blue", "gold", "gray", "red", "red", "red"],
		["gold", "gray", "blue", "gold", "gray", "blue"],
		["gray", "blue", "gold", "gray", "blue", "gold"],
	]
	board._refresh_tiles()

	var events: Array = await board._resolve_cascades(1, true)
	var red_counts: Array[int] = []
	var red_total: int = 0
	var red_max: int = 0
	for event_value in events:
		var event: Dictionary = event_value
		if String(event.get("type", "")) != "red" or int(event.get("cascade", 0)) != 1:
			continue
		var count: int = int(event.get("count", 0))
		red_counts.append(count)
		red_total += count
		red_max = max(red_max, count)

	red_counts.sort()
	_expect(red_counts == [3, 3], "Two disconnected red three-matches must resolve as two separate three-cell events.")
	_expect(red_total == 6, "Separate red matches must still account for all six cleared cells.")
	_expect(red_max <= 3, "Disconnected red three-matches must never be promoted to a six-match damage tier.")
	board.free()


func _test_external_recolor_keeps_board_playable() -> void:
	var board: Board = BoardScript.new()
	root.add_child(board)
	var exercised: Dictionary = {"pollute": 0, "cleanse": 0, "dye": 0}

	for seed_value in range(32):
		seed(41000 + seed_value)
		board.setup(GameDataScript.BASE_WEIGHTS)
		var baseline: Array = board.grid.duplicate(true)
		_expect_playable(board, "generated board seed %d" % seed_value)

		_restore_grid(board, baseline)
		seed(51000 + seed_value)
		var polluted: int = board.pollute_random_cells(4)
		exercised["pollute"] = int(exercised["pollute"]) + polluted
		_expect_playable(board, "pollute seed %d" % seed_value)

		_restore_grid(board, baseline)
		seed(61000 + seed_value)
		var cleansed: int = board.cleanse_gray_cells(4)
		exercised["cleanse"] = int(exercised["cleanse"]) + cleansed
		_expect_playable(board, "cleanse seed %d" % seed_value)

		_restore_grid(board, baseline)
		seed(71000 + seed_value)
		var dyed: int = board.dye_gray_cells("red", 4)
		exercised["dye"] = int(exercised["dye"]) + dyed
		_expect_playable(board, "dye seed %d" % seed_value)

	_expect(int(exercised["pollute"]) > 0, "The external pollution test must exercise at least one cell mutation.")
	_expect(int(exercised["cleanse"]) > 0, "The external cleanse test must exercise at least one cell mutation.")
	_expect(int(exercised["dye"]) > 0, "The external dye test must exercise at least one cell mutation.")
	board.free()


func _restore_grid(board: Board, snapshot: Array) -> void:
	board.grid.clear()
	for row_value in snapshot:
		board.grid.append(row_value.duplicate(true))
	board._refresh_tiles()


func _expect_playable(board: Board, label: String) -> void:
	_expect(board._find_matches().is_empty(), "%s must not contain a pre-existing match after an external color mutation." % label)
	_expect(board._has_possible_move(), "%s must retain at least one legal swap after an external color mutation." % label)


func _expect(condition: bool, message: String) -> void:
	if not condition and not failures.has(message):
		failures.append(message)
