extends SceneTree

const PegboardResolverScript = preload("res://scripts/PegboardResolver.gd")

var failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_test_same_seed_reproduces_result()
	_test_aim_is_clamped_to_boundaries()
	_test_tier_defaults_and_damage_formula()
	_test_multiball_aggregates_each_ball()
	_test_negative_inputs_stay_non_negative()
	_test_five_characters_have_distinct_modifiers()
	if failures.is_empty():
		print("PegboardResolver tests passed: 6")
		quit(0)
		return
	for failure in failures:
		push_error(failure)
	quit(1)


func _test_same_seed_reproduces_result() -> void:
	var resolver: Variant = PegboardResolverScript.new()
	var shot: Dictionary = {
		"base_damage": 12,
		"damage_per_hit": 3,
		"crit_multiplier": 1.75,
		"pierce": 1,
		"multiball": 2,
		"character_id": "blue",
		"orb_type": "rare",
	}
	var first: Dictionary = resolver.resolve(shot, 0.37, 981_337, 2)
	var second: Dictionary = resolver.resolve(shot, 0.37, 981_337, 2)
	_expect(first == second, "The same shot, aim, seed, and chapter must reproduce exactly.")


func _test_aim_is_clamped_to_boundaries() -> void:
	var resolver: Variant = PegboardResolverScript.new()
	var left_outside: Dictionary = resolver.resolve({}, -50.0, 77, 1)
	var left_edge: Dictionary = resolver.resolve({}, -1.0, 77, 1)
	var right_outside: Dictionary = resolver.resolve({}, 50.0, 91, 1)
	var right_edge: Dictionary = resolver.resolve({}, 1.0, 91, 1)
	_expect(left_outside == left_edge, "Aim values below -1 must resolve as -1.")
	_expect(right_outside == right_edge, "Aim values above 1 must resolve as 1.")
	_assert_ball_ranges(left_edge)
	_assert_ball_ranges(right_edge)


func _test_tier_defaults_and_damage_formula() -> void:
	var resolver: Variant = PegboardResolverScript.new()
	var cases: Array[Dictionary] = [
		{"orb_type": "common", "base": 8, "per_hit": 2},
		{"orb_type": "rare", "base": 12, "per_hit": 3},
		{"orb_type": "epic", "base": 18, "per_hit": 3},
	]
	for case in cases:
		var shot: Dictionary = {
			"orb_type": case["orb_type"],
			"crit_chance": 0.0,
			"crit_multiplier": 1.0,
		}
		var result: Dictionary = resolver.resolve(shot, 0.0, 402, 1)
		var expected_damage: int = int(case["base"]) + int(result["hits"]) * int(case["per_hit"])
		_expect(
			int(result["damage"]) == expected_damage,
			"%s damage must use base + hits * damage_per_hit." % case["orb_type"]
		)

	var critical: Dictionary = resolver.resolve({
		"base_damage": 10,
		"damage_per_hit": 4,
		"crit_chance": 1.0,
		"crit_multiplier": 2.0,
	}, 0.0, 511, 1)
	var critical_expected: int = 10 + int(critical["hits"]) * 4 * 2
	_expect(int(critical["damage"]) == critical_expected, "Critical hit damage must apply crit_multiplier per hit.")


func _test_multiball_aggregates_each_ball() -> void:
	var resolver: Variant = PegboardResolverScript.new()
	var result: Dictionary = resolver.resolve({
		"base_damage": 8,
		"damage_per_hit": 2,
		"crit_multiplier": 1.0,
		"crit_chance": 0.0,
		"multiball": 3,
		"character_id": "mixed",
	}, 0.2, 8_410, 3)
	var hit_sum: int = 0
	var crit_sum: int = 0
	var damage_sum: int = 0
	var peg_sum: int = 0
	_expect(result["balls"].size() == 3, "multiball = 3 must resolve three balls.")
	for ball_value in result["balls"]:
		var ball: Dictionary = ball_value
		hit_sum += int(ball["hits"])
		crit_sum += int(ball["crit_hits"])
		damage_sum += int(ball["damage"])
		peg_sum += ball["peg_types"].size()
		_assert_ball_ranges(ball)
	_expect(int(result["hits"]) == hit_sum, "Top-level hits must aggregate all balls.")
	_expect(int(result["crit_hits"]) == crit_sum, "Top-level crit_hits must aggregate all balls.")
	_expect(int(result["damage"]) == damage_sum, "Top-level damage must aggregate all balls.")
	_expect(result["peg_types"].size() == peg_sum, "Top-level peg_types must aggregate all balls.")


func _test_negative_inputs_stay_non_negative() -> void:
	var resolver: Variant = PegboardResolverScript.new()
	var result: Dictionary = resolver.resolve({
		"base_damage": -100,
		"damage_per_hit": -9,
		"crit_multiplier": -4.0,
		"pierce": -7,
		"multiball": -3,
	}, 0.0, -22, -5)
	_expect(int(result["hits"]) >= 0, "Hits must never be negative.")
	_expect(int(result["crit_hits"]) >= 0, "Critical hits must never be negative.")
	_expect(int(result["damage"]) >= 0, "Damage must never be negative.")
	_expect(result["balls"].size() == 1, "Invalid multiball values must fall back to one ball.")
	_expect(int(result["chapter"]) == 1, "Invalid chapter values must clamp to chapter one.")


func _test_five_characters_have_distinct_modifiers() -> void:
	var resolver: Variant = PegboardResolverScript.new()
	var expected_effects: Dictionary = {
		"red": "center_momentum",
		"blue": "precision_crit",
		"gold": "bounty_pegs",
		"gray": "mist_pierce",
		"mixed": "prismatic_control",
	}
	var first_peg_types: Array[String] = []
	for character_id in expected_effects:
		var result: Dictionary = resolver.resolve({
			"character_id": character_id,
			"crit_chance": 0.0,
		}, 0.0, 1_205, 2)
		_expect(
			String(result["character_effect"]) == String(expected_effects[character_id]),
			"Character %s must expose its resolver modifier." % character_id
		)
		first_peg_types.append(String(result["peg_types"][0]))
		_assert_ball_ranges(result["balls"][0])
	var unique_first_pegs: Dictionary = {}
	for peg_type in first_peg_types:
		unique_first_pegs[peg_type] = true
	_expect(unique_first_pegs.size() == 5, "The five characters must produce distinct signature peg behavior.")


func _assert_ball_ranges(ball: Dictionary) -> void:
	var hits: int = int(ball["hits"])
	_expect(hits >= 7 and hits <= 13, "Each ball must hit a reasonable 7-13 pegs.")
	_expect(int(ball["crit_hits"]) >= 0, "Each ball must have non-negative crit_hits.")
	_expect(int(ball["damage"]) >= 0, "Each ball must have non-negative damage.")
	_expect(ball["peg_types"].size() == hits, "Each hit must have one peg type.")
	_expect(ball["path"].size() == hits + 2, "Each path must include launch, hits, and exit.")
	for point_value in ball["path"]:
		var point: Vector2 = point_value
		_expect(point.x >= -1.0 and point.x <= 1.0, "Path x coordinates must remain normalized.")
		_expect(point.y >= 0.0 and point.y <= 1.0, "Path y coordinates must remain normalized.")


func _expect(condition: bool, message: String) -> void:
	if not condition and not failures.has(message):
		failures.append(message)
