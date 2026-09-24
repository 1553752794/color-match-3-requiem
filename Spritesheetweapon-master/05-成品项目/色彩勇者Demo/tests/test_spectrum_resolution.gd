extends SceneTree

const SpectrumResolutionScript = preload("res://scripts/SpectrumResolution.gd")

var failures: Array[String] = []
var passed_tests: int = 0


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_run_test("rarity pulse damage", _test_rarity_pulse_damage)
	_run_test("curse has zero base damage", _test_curse_zero_base_damage)
	_run_test("character profile differences", _test_character_profile_differences)
	_run_test("repeat count boundaries", _test_repeat_count_boundaries)
	_run_test("legacy multiball compatibility", _test_legacy_multiball_compatibility)
	_run_test("shield coin cleanse and burn rewards", _test_resolution_rewards)
	_run_test("armor break aggregation", _test_armor_break)
	_run_test("negative and extreme input clamps", _test_input_clamps)

	print("SpectrumResolution tests: %d passed, %d failed" % [passed_tests, failures.size()])
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


func _test_rarity_pulse_damage() -> void:
	var expected_damage: Dictionary = {
		"common": 8,
		"rare": 13,
		"epic": 20,
		"unknown": 8,
	}
	for rarity_value in expected_damage.keys():
		var rarity: String = String(rarity_value)
		var result: Dictionary = SpectrumResolutionScript.resolve({"rarity": rarity})
		_expect(
			int(result.get("damage", -1)) == int(expected_damage[rarity]),
			"Rarity %s must resolve to %d base pulse damage." % [rarity, int(expected_damage[rarity])]
		)


func _test_curse_zero_base_damage() -> void:
	var result: Dictionary = SpectrumResolutionScript.resolve({"rarity": "curse", "color": "black"})
	_expect(int(result.get("damage", -1)) == 0, "Curse spectra must have zero base pulse damage.")
	_expect(String(result.get("color", "")) == "black", "Resolution must preserve a curse spectrum's color.")


func _test_character_profile_differences() -> void:
	var card: Dictionary = {"rarity": "common", "color": "neutral"}
	var red: Dictionary = SpectrumResolutionScript.resolve(card, {
		"pulse_damage_bonus": 3,
		"completion_burn": 1,
	})
	var blue: Dictionary = SpectrumResolutionScript.resolve(card, {"completion_shield": 3})
	var gold: Dictionary = SpectrumResolutionScript.resolve(card, {"completion_coins": 2})
	var gray: Dictionary = SpectrumResolutionScript.resolve(card, {
		"armor_break": 1,
		"cleanse_on_completion": 1,
	})

	_expect(int(red.get("damage", 0)) == 11 and int(red.get("burn", 0)) == 1, "The red profile must add pulse damage and burn.")
	_expect(int(blue.get("shield", 0)) == 3, "The blue profile must add completion shield.")
	_expect(int(gold.get("coins", 0)) == 2, "The gold profile must add completion coins.")
	_expect(bool(gray.get("ignore_armor", false)) and int(gray.get("cleanse", 0)) == 1, "The gray profile must break armor and cleanse.")


func _test_repeat_count_boundaries() -> void:
	var excessive: Dictionary = SpectrumResolutionScript.resolve(
		{"rarity": "common"},
		{"repeat_count": 99},
		{"repeat_count": 999, "repeat_ratio": 1.0}
	)
	_expect(int(excessive.get("repeat_count", 0)) == 4, "Repeat count must clamp to four.")
	_expect(int(excessive.get("damage", 0)) == 32, "Four full-strength repeats must deal four times base damage.")

	var negative: Dictionary = SpectrumResolutionScript.resolve(
		{"rarity": "rare"},
		{"repeat_count": -20},
		{"repeat_count": -4}
	)
	_expect(int(negative.get("repeat_count", 0)) == 1, "Negative repeat counts must clamp to one.")
	_expect(int(negative.get("damage", 0)) == 13, "A clamped single resolution must not add repeat damage.")


func _test_legacy_multiball_compatibility() -> void:
	var result: Dictionary = SpectrumResolutionScript.resolve(
		{"rarity": "common"},
		{"multiball": 2, "ball_damage_ratio": 0.75},
		{"multiball": 3, "ball_damage_ratio": 0.5}
	)
	_expect(int(result.get("repeat_count", 0)) == 3, "Legacy multiball must map to repeat_count.")
	_expect(is_equal_approx(float(result.get("repeat_ratio", 0.0)), 0.5), "Legacy ball_damage_ratio must map to repeat_ratio.")
	_expect(int(result.get("damage", 0)) == 16, "Legacy three-ball data must preserve its repeat damage formula.")


func _test_resolution_rewards() -> void:
	var result: Dictionary = SpectrumResolutionScript.resolve(
		{"rarity": "common", "color": "gold"},
		{
			"completion_shield": 3,
			"completion_coins": 2,
			"gold_pegs": 2,
			"coins_per_gold_peg": 3,
			"cleanse_on_completion": 1,
			"cleanse_on_shot": 1,
			"completion_burn": 1,
		},
		{
			"shield": 5,
			"bonus_coins": 4,
			"cleanse": 1,
			"ignore_hazard": true,
			"ignore_void": true,
			"burn": 2,
		},
		{"bounty": 5}
	)
	_expect(int(result.get("shield", 0)) == 8, "Completion and modifier shield must stack.")
	_expect(int(result.get("coins", 0)) == 17, "Completion, legacy gold peg, modifier, and bounty coins must stack.")
	_expect(int(result.get("cleanse", 0)) == 4, "Cleanse rewards must stack and clamp to four.")
	_expect(int(result.get("burn", 0)) == 3, "Completion and modifier burn must stack.")


func _test_armor_break() -> void:
	var result: Dictionary = SpectrumResolutionScript.resolve(
		{"rarity": "common"},
		{"armor_break": 1, "pierce": 2},
		{
			"armor_break": 3,
			"pierce_bonus": 4,
			"lock_pierce": 5,
			"armor_break_hits": 6,
		},
		{"pierce": 7},
		{"armor_break": 8}
	)
	_expect(bool(result.get("ignore_armor", false)), "Positive break must mark the resolution as ignoring armor.")
	_expect(int(result.get("armor_break", 0)) == 36, "Modern and legacy break fields must aggregate without loss.")


func _test_input_clamps() -> void:
	var negative: Dictionary = SpectrumResolutionScript.resolve(
		{"rarity": "curse"},
		{
			"pulse_damage_bonus": -100,
			"per_hit_bonus": -100,
			"completion_shield": -100,
			"completion_coins": -100,
			"armor_break": -100,
		},
		{
			"flat_damage": -100,
			"repeat_count": -100,
			"repeat_ratio": -100.0,
			"shield": -100,
			"bonus_coins": -100,
			"cleanse": -100,
			"burn": -100,
		}
	)
	_expect(int(negative.get("damage", -1)) == 0, "Negative damage inputs must resolve to zero.")
	_expect(int(negative.get("shield", -1)) == 0 and int(negative.get("coins", -1)) == 0, "Negative rewards must resolve to zero.")
	_expect(int(negative.get("armor_break", -1)) == 0 and not bool(negative.get("ignore_armor", true)), "Negative break inputs must not bypass armor.")
	_expect(int(negative.get("repeat_count", 0)) == 1, "Negative repeat count must clamp to one.")
	_expect(is_equal_approx(float(negative.get("repeat_ratio", 0.0)), 0.25), "Negative repeat ratio must clamp to 0.25.")

	var extreme: Dictionary = SpectrumResolutionScript.resolve(
		{"rarity": "epic"},
		{"repeat_count": 1_000_000},
		{
			"repeat_count": 1_000_000,
			"repeat_ratio": 1_000_000.0,
			"cleanse": 1_000_000,
			"damage_ratio_bonus": 1_000_000.0,
		},
		{},
		{"amplification": 1_000_000.0}
	)
	_expect(int(extreme.get("repeat_count", 0)) == 4, "Extreme repeat count must clamp to four.")
	_expect(is_equal_approx(float(extreme.get("repeat_ratio", 0.0)), 1.0), "Extreme repeat ratio must clamp to one.")
	_expect(int(extreme.get("cleanse", 0)) == 4, "Extreme cleanse must clamp to four.")
	_expect(int(extreme.get("damage", 0)) == 108, "Extreme amplification must clamp to 35 percent.")


func _expect(condition: bool, message: String) -> void:
	if not condition and not failures.has(message):
		failures.append(message)
