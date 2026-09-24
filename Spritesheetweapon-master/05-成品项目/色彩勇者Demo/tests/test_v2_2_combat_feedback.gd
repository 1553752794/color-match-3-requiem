extends SceneTree

const BATTLE_MANAGER_SCRIPT = preload("res://scripts/BattleManager.gd")

var failures: Array[String] = []
var feedback: Array[Dictionary] = []
var game_manager: Node
var passed_tests: int = 0


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	game_manager = root.get_node("GameManager")
	await _run_test("typed signal and initialized turn", _test_turn_start)
	await _run_test("clear feedback preserves pigment-only clears", _test_clear_feedback)
	await _run_test("spectrum feedback follows complete resolution", _test_spectrum_feedback)
	await _run_test("resonance feedback once per turn", _test_resonance_feedback)
	await _run_test("enemy action and turn rollover", _test_enemy_feedback)
	await _run_test("loss feedback precedes terminal callback", _test_loss_feedback)
	await _run_test("win stops queued spectra and later cascades", _test_win_stops_queued_spectrum_resolutions)
	print("V2.2 combat feedback tests: %d passed, %d assertion failures" % [passed_tests, failures.size()])
	if failures.is_empty():
		quit(0)
		return
	for failure in failures:
		push_error(failure)
	quit(1)


func _run_test(test_name: String, test_callable: Callable) -> void:
	var before: int = failures.size()
	await test_callable.call()
	if failures.size() == before:
		passed_tests += 1
		print("[PASS] %s" % test_name)
	else:
		print("[FAIL] %s" % test_name)


func _new_battle() -> BattleManager:
	feedback.clear()
	seed(2209)
	game_manager.reset_run()
	game_manager.equipped_memory_ids.clear()
	game_manager.configure_starting_archetype("red")
	var battle: BattleManager = BATTLE_MANAGER_SCRIPT.new()
	battle.GameManager = game_manager
	root.add_child(battle)
	_expect(battle.has_signal("combat_feedback_emitted"), "BattleManager must expose combat_feedback_emitted.")
	if battle.has_signal("combat_feedback_emitted"):
		battle.connect("combat_feedback_emitted", _on_feedback)
	battle.start_battle({
		"enemy_name": "Feedback Target",
		"enemy_id": "FEEDBACK-TARGET",
		"max_hp": 10000,
		"attack": 7,
		"reward": 0,
		"node_type": "combat",
		"intents": [{"type": "attack", "value": 7}],
	})
	return battle


func _test_turn_start() -> void:
	var battle: BattleManager = _new_battle()
	for signal_info in battle.get_signal_list():
		if String(signal_info.get("name", "")) != "combat_feedback_emitted":
			continue
		var args: Array = signal_info.get("args", [])
		_expect(args.size() == 1, "Combat feedback signal must have exactly one argument.")
		if args.size() == 1:
			_expect(int(args[0].get("type", -1)) == TYPE_DICTIONARY, "Combat feedback signal argument must be typed Dictionary.")
	_expect(_feedback_kinds() == ["turn"], "Battle start must emit one turn, not a resonance.")
	_expect(battle.turn_number == 1 and battle.moves_left == 3, "Turn feedback must not change turn or move counts.")
	_expect(battle.spectrum_manager.hand.size() == 3, "Start-turn feedback must leave the initial hand intact.")
	var first: Dictionary = feedback[0].duplicate(true) if not feedback.is_empty() else {}
	battle._begin_player_turn()
	_expect(_feedback_kinds() == ["turn", "turn"], "Each new player turn must emit exactly one turn.")
	if not feedback.is_empty():
		_expect(feedback[0] == first, "Later feedback must not overwrite earlier payloads.")
	battle.free()


func _test_clear_feedback() -> void:
	var battle: BattleManager = _new_battle()
	var empty_hand: Array[Dictionary] = []
	battle.spectrum_manager.begin_turn(empty_hand)
	feedback.clear()
	var hp_before: int = battle.enemy.hp
	var coins_before: int = game_manager.coins
	await battle.on_player_move([
		{"type": "red", "count": 3, "cascade": 1, "active": true},
		{"type": "gold", "count": 3, "cascade": 2, "active": false},
	], 2)
	_expect(_feedback_kinds() == ["clear", "clear"], "Each positive-count clear must emit one clear.")
	if feedback.size() == 2:
		_expect(feedback[0]["color"] == "red" and feedback[1]["color"] == "gold", "Clear feedback must preserve each clear's color and order.")
	_expect(battle.enemy.hp == hp_before, "Ordinary clears must not directly damage enemy HP.")
	_expect(battle.battle_pigments["red"] == 3 and battle.battle_pigments["gold"] == 4, "Clear feedback must preserve pigment and cascade yields.")
	_expect(battle.skill_charge == 7 and battle.moves_left == 2, "Feedback must preserve charge and one move consumed per swap.")
	_expect(game_manager.coins == coins_before + 6, "Gold clear feedback must preserve coin rewards.")
	feedback.clear()
	battle._apply_clear_events([])
	battle._apply_clear_events([{"type": "red", "count": 0}])
	_expect(feedback.is_empty(), "Empty and zero-count clears must not emit feedback.")
	battle.resolving = true
	await battle.on_player_move([{"type": "red", "count": 3}], 1)
	_expect(feedback.is_empty(), "A rejected move while resolving must not emit feedback.")
	battle.free()


func _test_spectrum_feedback() -> void:
	var battle: BattleManager = _new_battle()
	var hand: Array[Dictionary] = [
		{"instance_id": "ember", "card_id": "ember_slash", "level": 0},
		{"instance_id": "guard", "card_id": "warm_guard", "level": 0},
	]
	battle.spectrum_manager.begin_turn(hand)
	var resolved: Array[Dictionary] = []
	battle.spectrum_resolved.connect(func(result: Dictionary) -> void: resolved.append(result))
	feedback.clear()
	var hp_before: int = battle.enemy.hp
	await battle.on_player_move([{"type": "red", "count": 5, "cascade": 1, "active": true}], 1)
	_expect(_feedback_kinds() == ["clear", "spectrum", "spectrum"], "Clear feedback must precede same-event spectra in hand order.")
	_expect(resolved.size() == 2, "Nonlethal same-event spectra must both retain their existing resolution signals.")
	if resolved.size() == 2:
		_expect(resolved[0]["card_id"] == "ember_slash" and resolved[1]["card_id"] == "warm_guard", "Feedback must preserve spectrum resolution order.")
		_expect(hp_before - battle.enemy.hp == int(resolved[0]["total_damage"]) + int(resolved[1]["total_damage"]), "Resolution totals must account for all actual damage.")
		if feedback.size() == 3:
			_expect(feedback[1]["title"] == resolved[0]["name"] and feedback[2]["title"] == resolved[1]["name"], "Spectrum feedback must identify the resolved cards.")
			_expect(String(feedback[1]["detail"]).contains(str(resolved[0]["total_damage"])), "Spectrum detail must report the complete resolved damage.")
	_expect(game_manager.shield == 8, "Nonlethal warm_guard must still grant its shield.")
	battle.free()


func _test_resonance_feedback() -> void:
	var battle: BattleManager = _new_battle()
	var hand: Array[Dictionary] = [{"instance_id": "gold", "card_id": "caravan_beat", "level": 0}]
	battle.spectrum_manager.begin_turn(hand)
	await battle.on_player_move([{"type": "gold", "count": 4, "cascade": 1, "active": true}], 1)
	_expect(not _feedback_kinds().has("resonance"), "First-turn spectra must not emit a resonance without a lead note.")
	battle._begin_player_turn()
	hand = [
		{"instance_id": "guard", "card_id": "frost_guard", "level": 0},
		{"instance_id": "wall", "card_id": "cold_wall", "level": 0},
	]
	battle.spectrum_manager.begin_turn(hand)
	feedback.clear()
	await battle.on_player_move([{"type": "blue", "count": 6, "cascade": 1}], 1)
	_expect(_feedback_kinds().count("resonance") == 1, "Cross-turn resonance must emit exactly once despite two spectrum completions.")
	_expect(_feedback_kinds().count("spectrum") == 2, "Both nonlethal blue spectra must resolve.")
	_expect(game_manager.shield == 40, "Zero-damage verdant resonance must still grant its six shield alongside the two cards.")
	_expect(battle.resonance_sequence.trigger_count == 1, "Feedback must not consume or trigger resonance a second time.")
	battle.free()


func _test_enemy_feedback() -> void:
	var battle: BattleManager = _new_battle()
	var empty_hand: Array[Dictionary] = []
	battle.spectrum_manager.begin_turn(empty_hand)
	battle.moves_left = 1
	game_manager.shield = 2
	var hp_before: int = game_manager.player_hp
	feedback.clear()
	await battle.on_player_move([{"type": "gray", "count": 3, "cascade": 1}], 1)
	_expect(_feedback_kinds() == ["clear", "enemy", "turn"], "Last move must announce enemy action before the next player turn.")
	_expect(game_manager.player_hp == hp_before - 5, "Enemy feedback must preserve shield absorption and HP damage.")
	_expect(battle.enemy.turn_index == 1 and battle.turn_number == 2 and battle.moves_left == 3, "Enemy feedback must preserve intent and turn progression.")
	battle.enemy.freeze_turns = 1
	feedback.clear()
	hp_before = game_manager.player_hp
	await battle._enemy_action()
	_expect(_feedback_kinds() == ["enemy"], "A frozen enemy turn must still emit feedback.")
	_expect(game_manager.player_hp == hp_before and battle.enemy.freeze_turns == 0, "Frozen-turn feedback must not execute the skipped attack.")
	battle.enemy.intents = [{"type": "defend", "value": 9}]
	feedback.clear()
	await battle._enemy_action()
	_expect(_feedback_kinds() == ["enemy"] and battle.enemy.armor == 9, "Non-damage enemy intents must emit feedback and retain their effect.")
	battle.free()


func _test_loss_feedback() -> void:
	var battle: BattleManager = _new_battle()
	game_manager.player_hp = 1
	game_manager.shield = 0
	var terminal_order: Array[String] = []
	battle.battle_lost.connect(func() -> void:
		terminal_order.assign(_feedback_kinds())
	)
	feedback.clear()
	await battle._enemy_action()
	_expect(_feedback_kinds() == ["enemy", "defeat"], "A lethal enemy attack must emit one loss and no new player turn.")
	_expect(terminal_order == ["enemy", "defeat"], "Loss feedback must arrive before battle_lost can change the scene.")
	battle._check_loss()
	await battle.on_player_move([{"type": "red", "count": 3}], 1)
	_expect(_feedback_kinds().count("defeat") == 1 and not _feedback_kinds().has("clear"), "Terminal loss and rejected post-battle moves must not duplicate feedback.")
	battle.free()


func _test_win_stops_queued_spectrum_resolutions() -> void:
	var battle: BattleManager = _new_battle()
	battle.enemy.hp = 1
	var hand: Array[Dictionary] = [
		{"instance_id": "first", "card_id": "ember_slash", "level": 0},
		{"instance_id": "second", "card_id": "warm_guard", "level": 0},
	]
	battle.spectrum_manager.begin_turn(hand)
	var resolved: Array[String] = []
	var terminal_order: Array[String] = []
	battle.spectrum_resolved.connect(func(result: Dictionary) -> void: resolved.append(String(result["card_id"])))
	battle.battle_won.connect(func() -> void:
		terminal_order.assign(_feedback_kinds())
	)
	var coins_before: int = game_manager.coins
	feedback.clear()
	await battle.on_player_move([
		{"type": "red", "count": 5, "cascade": 1, "active": true},
		{"type": "gold", "count": 3, "cascade": 2, "active": false},
	], 2)
	_expect(battle.battle_finished, "A lethal spectrum must finish the battle.")
	_expect(resolved == ["ember_slash"], "A lethal spectrum must stop queued later spectrum resolutions.")
	_expect(game_manager.run_stats.spectra_completed == 1, "Post-win queued spectra must not inflate completion statistics.")
	_expect(game_manager.shield == 0, "Queued warm_guard must not grant rewards after victory.")
	_expect(game_manager.coins == coins_before and battle.battle_pigments["gold"] == 0, "Later cascades must not grant rewards after victory.")
	_expect(battle.enemy.burn_stacks == 4, "The killing card must still finish its own status rewards.")
	_expect(_feedback_kinds() == ["clear", "spectrum", "victory"], "Victory feedback must be the final event in a lethal clear chain.")
	_expect(terminal_order == ["clear", "spectrum", "victory"], "Win feedback must precede the scene-changing battle_won callback.")
	battle._check_win()
	_expect(_feedback_kinds().count("victory") == 1, "Repeated win checks must not duplicate terminal feedback.")
	battle.free()


func _on_feedback(event: Dictionary) -> void:
	_expect(event.has_all(["kind", "title", "detail", "color", "duration"]), "Every feedback payload must contain the five-field contract.")
	for key in ["kind", "title", "detail", "color"]:
		_expect(event.get(key) is String and not String(event.get(key, "")).is_empty(), "Feedback %s must be a nonempty String." % key)
	_expect(event.get("duration") is float and float(event.get("duration", 0.0)) > 0.0, "Feedback duration must be a positive float.")
	feedback.append(event.duplicate(true))


func _feedback_kinds() -> Array[String]:
	var result: Array[String] = []
	for event in feedback:
		result.append(String(event.get("kind", "")))
	return result


func _expect(condition: bool, message: String) -> void:
	if not condition and not failures.has(message):
		failures.append(message)
