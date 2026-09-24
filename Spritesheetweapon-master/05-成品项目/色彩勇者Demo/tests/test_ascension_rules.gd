extends SceneTree

const AscensionRulesScript = preload("res://scripts/AscensionRules.gd")

var failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_test_all_levels_are_explicit()
	_test_cumulative_rules_are_monotonic()
	_test_a10_caps()
	_test_apply_apis_return_independent_copies()
	_test_invalid_levels_are_clamped()
	_test_encounter_specific_scaling()
	if failures.is_empty():
		print("AscensionRules tests passed: 6")
		quit(0)
		return
	for failure in failures:
		push_error(failure)
	quit(1)


func _test_all_levels_are_explicit() -> void:
	_expect(AscensionRulesScript.LEVEL_RULES.size() == 11, "A0-A10 must contain exactly eleven level definitions.")
	for level in range(0, 11):
		var rule: Dictionary = AscensionRulesScript.get_level_rule(level)
		_expect(int(rule.get("level", -1)) == level, "A%d must expose its own level number." % level)
		_expect(not String(rule.get("name", "")).is_empty(), "A%d must have a name." % level)
		_expect(not AscensionRulesScript.get_level_description(level).is_empty(), "A%d must have a description." % level)
		_expect(rule.get("modifiers") is Dictionary, "A%d modifiers must be data-only Dictionary values." % level)
		var cumulative: Dictionary = AscensionRulesScript.get_cumulative_rules(level)
		_expect(int(cumulative.get("level", -1)) == level, "A%d cumulative rules must retain the clamped level." % level)
		for key_value in AscensionRulesScript.BASE_RULES.keys():
			_expect(cumulative.has(key_value), "A%d cumulative rules must contain %s." % [level, String(key_value)])


func _test_cumulative_rules_are_monotonic() -> void:
	var increasing_keys: Array[String] = [
		"enemy_health_multiplier",
		"enemy_damage_multiplier",
		"shop_price_multiplier",
		"gray_spawn_chance_add",
		"gray_corruption_multiplier",
		"hazard_peg_chance_add",
		"hazard_peg_count_add",
		"elite_health_multiplier",
		"elite_damage_multiplier",
		"boss_health_multiplier",
		"boss_damage_multiplier",
		"starting_burden_count_add",
		"starting_gold_penalty",
	]
	var decreasing_keys: Array[String] = ["healing_multiplier", "gold_reward_multiplier"]
	var previous: Dictionary = AscensionRulesScript.get_cumulative_rules(0)
	for level in range(1, 11):
		var current: Dictionary = AscensionRulesScript.get_cumulative_rules(level)
		for key in increasing_keys:
			_expect(
				float(current[key]) + 0.000_001 >= float(previous[key]),
				"%s must not decrease between A%d and A%d." % [key, level - 1, level]
			)
		for key in decreasing_keys:
			_expect(
				float(current[key]) <= float(previous[key]) + 0.000_001,
				"%s must not increase between A%d and A%d." % [key, level - 1, level]
			)
		previous = current


func _test_a10_caps() -> void:
	var rules: Dictionary = AscensionRulesScript.get_cumulative_rules(10)
	_expect(float(rules["enemy_health_multiplier"]) <= AscensionRulesScript.MAX_ENEMY_HEALTH_MULTIPLIER, "A10 enemy health must respect its cap.")
	_expect(float(rules["enemy_damage_multiplier"]) <= AscensionRulesScript.MAX_ENEMY_DAMAGE_MULTIPLIER, "A10 enemy damage must respect its cap.")
	_expect(float(rules["healing_multiplier"]) >= AscensionRulesScript.MIN_HEALING_MULTIPLIER, "A10 healing reduction must respect its floor.")
	_expect(float(rules["gold_reward_multiplier"]) >= AscensionRulesScript.MIN_GOLD_REWARD_MULTIPLIER, "A10 gold reduction must respect its floor.")
	_expect(float(rules["hazard_peg_chance_add"]) <= AscensionRulesScript.MAX_HAZARD_PEG_CHANCE_ADD, "A10 hazard chance must respect its cap.")
	_expect(int(rules["starting_burden_count_add"]) == AscensionRulesScript.MAX_STARTING_BURDEN_COUNT, "A10 starting burden must reach but not exceed its cap.")
	_expect(int(rules["starting_gold_penalty"]) == AscensionRulesScript.MAX_STARTING_GOLD_PENALTY, "A10 gold penalty must reach but not exceed its cap.")
	_expect(
		is_equal_approx(float(rules["boss_damage_multiplier"]), AscensionRulesScript.MAX_BOSS_DAMAGE_MULTIPLIER),
		"A10 boss damage must be clamped to the explicit cap."
	)

	var battle: Dictionary = AscensionRulesScript.apply_to_battle_params({
		"enemy_max_health": 2_000_000,
		"enemy_health": 2_000_000,
		"enemy_damage": 200_000,
		"gray_spawn_chance": 0.64,
		"hazard_peg_chance": 0.34,
		"max_hazard_pegs": 6,
	}, 10)
	_expect(int(battle["enemy_max_health"]) == AscensionRulesScript.MAX_EFFECTIVE_ENEMY_HEALTH, "Applied enemy health must respect the absolute cap.")
	_expect(int(battle["enemy_damage"]) == AscensionRulesScript.MAX_EFFECTIVE_ENEMY_DAMAGE, "Applied enemy damage must respect the absolute cap.")
	_expect(float(battle["gray_spawn_chance"]) <= AscensionRulesScript.MAX_EFFECTIVE_GRAY_SPAWN_CHANCE, "Applied gray chance must respect the board cap.")
	_expect(float(battle["hazard_peg_chance"]) <= AscensionRulesScript.MAX_EFFECTIVE_HAZARD_PEG_CHANCE, "Applied hazard chance must respect the board cap.")
	_expect(int(battle["max_hazard_pegs"]) <= AscensionRulesScript.MAX_EFFECTIVE_HAZARD_PEG_COUNT, "Applied hazard count must respect the board cap.")


func _test_apply_apis_return_independent_copies() -> void:
	var nested: Dictionary = {"labels": ["keep"]}
	var run_input: Dictionary = {"gold_reward_multiplier": 1.0, "metadata": nested}
	var battle_input: Dictionary = {"enemy_max_health": 100, "enemy_health": 80, "enemy_damage": 10, "metadata": nested}
	var profile_input: Dictionary = {"starting_gold": 100, "starting_burden_count": 0, "metadata": nested}
	var run_snapshot: Dictionary = run_input.duplicate(true)
	var battle_snapshot: Dictionary = battle_input.duplicate(true)
	var profile_snapshot: Dictionary = profile_input.duplicate(true)

	var run_result: Dictionary = AscensionRulesScript.apply_to_run_params(run_input, 10)
	var battle_result: Dictionary = AscensionRulesScript.apply_to_battle_params(battle_input, 10)
	var profile_result: Dictionary = AscensionRulesScript.apply_to_profile_params(profile_input, 10)
	_expect(run_input == run_snapshot, "Run parameters must not be modified in place.")
	_expect(battle_input == battle_snapshot, "Battle parameters must not be modified in place.")
	_expect(profile_input == profile_snapshot, "Profile parameters must not be modified in place.")

	var run_metadata: Dictionary = run_result["metadata"]
	var battle_metadata: Dictionary = battle_result["metadata"]
	var profile_metadata: Dictionary = profile_result["metadata"]
	var run_labels: Array = run_metadata["labels"]
	var battle_labels: Array = battle_metadata["labels"]
	var profile_labels: Array = profile_metadata["labels"]
	run_labels.append("run")
	battle_labels.append("battle")
	profile_labels.append("profile")
	_expect(run_input == run_snapshot, "Mutating a run result's nested data must not affect its input.")
	_expect(battle_input == battle_snapshot, "Mutating a battle result's nested data must not affect its input.")
	_expect(profile_input == profile_snapshot, "Mutating a profile result's nested data must not affect its input.")


func _test_invalid_levels_are_clamped() -> void:
	_expect(AscensionRulesScript.clamp_level(-999) == 0, "Levels below A0 must clamp to A0.")
	_expect(AscensionRulesScript.clamp_level(999) == 10, "Levels above A10 must clamp to A10.")
	_expect(AscensionRulesScript.get_level_rule(-1) == AscensionRulesScript.get_level_rule(0), "Negative level rules must resolve to A0.")
	_expect(AscensionRulesScript.get_cumulative_rules(99) == AscensionRulesScript.get_cumulative_rules(10), "Oversized cumulative levels must resolve to A10.")
	var low: Dictionary = AscensionRulesScript.apply_to_profile_params({"starting_gold": 100}, -8)
	var high: Dictionary = AscensionRulesScript.apply_to_profile_params({"starting_gold": 100}, 80)
	_expect(int(low["ascension_level"]) == 0 and int(low["starting_gold"]) == 100, "Invalid low application levels must use A0.")
	_expect(int(high["ascension_level"]) == 10 and int(high["starting_gold"]) == 50, "Invalid high application levels must use capped A10.")


func _test_encounter_specific_scaling() -> void:
	var base: Dictionary = {"enemy_max_health": 100, "enemy_health": 100, "enemy_damage": 20}
	var normal_input: Dictionary = base.duplicate(true)
	normal_input["encounter_type"] = "normal"
	var elite_input: Dictionary = base.duplicate(true)
	elite_input["encounter_type"] = "elite"
	var boss_input: Dictionary = base.duplicate(true)
	boss_input["encounter_type"] = "boss"
	var normal: Dictionary = AscensionRulesScript.apply_to_battle_params(normal_input, 10)
	var elite: Dictionary = AscensionRulesScript.apply_to_battle_params(elite_input, 10)
	var boss: Dictionary = AscensionRulesScript.apply_to_battle_params(boss_input, 10)
	_expect(int(elite["enemy_max_health"]) > int(normal["enemy_max_health"]), "Elite health scaling must stack on the global modifier.")
	_expect(int(boss["enemy_max_health"]) > int(normal["enemy_max_health"]), "Boss health scaling must stack on the global modifier.")
	_expect(int(elite["enemy_damage"]) > int(normal["enemy_damage"]), "Elite damage scaling must stack on the global modifier.")
	_expect(int(boss["enemy_damage"]) > int(normal["enemy_damage"]), "Boss damage scaling must stack on the global modifier.")
	_expect(int(elite["enemy_max_health"]) <= 135, "A10 elite health must respect the final 1.35x cap.")
	_expect(int(elite["enemy_damage"]) <= 25, "A10 elite damage must respect the final 1.25x cap.")
	_expect(int(boss["enemy_max_health"]) <= 140, "A10 Boss health must respect the final 1.40x cap.")
	_expect(int(boss["enemy_damage"]) <= 26, "A10 Boss damage must respect the final 1.30x cap.")
	var zero: Dictionary = AscensionRulesScript.apply_to_battle_params({
		"enemy_max_health": 0,
		"enemy_health": 0,
		"enemy_damage": 0,
	}, 10)
	_expect(int(zero["enemy_max_health"]) == 0 and int(zero["enemy_health"]) == 0, "Zero health inputs must not be revived by scaling.")
	_expect(int(zero["enemy_damage"]) == 0, "Zero damage inputs must remain zero.")


func _expect(condition: bool, message: String) -> void:
	if not condition and not failures.has(message):
		failures.append(message)
