extends SceneTree

const AscensionRulesScript = preload("res://scripts/AscensionRules.gd")
const BattleManagerScript = preload("res://scripts/BattleManager.gd")
const ChapterPegboardRulesScript = preload("res://scripts/ChapterPegboardRules.gd")
const PegboardResolverScript = preload("res://scripts/PegboardResolver.gd")
const PegboardViewScript = preload("res://scripts/PegboardView.gd")
const RunStatsScript = preload("res://scripts/RunStats.gd")
const SettingsManagerScript = preload("res://scripts/SettingsManager.gd")
const SpectrumResolutionScript = preload("res://scripts/SpectrumResolution.gd")

const MIN_TEST_SEED: int = -9_223_372_036_854_775_807
const MAX_TEST_SEED: int = 9_223_372_036_854_775_807

var failures: Array[String] = []
var passed_tests: int = 0
var game_manager: Node


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	game_manager = root.get_node("GameManager")
	_run_test("A0-A10 release boundaries", _test_ascension_a0_to_a10)
	_run_test("RunStats release summary", _test_run_stats_summary)
	_run_test("stacked spectrum tuning boundaries", _test_spectrum_tuning_boundaries)
	_run_test("multiball and huge damage boundaries", _test_resolver_numeric_boundaries)
	_run_test("extreme seed determinism", _test_extreme_seeds)
	_run_test("Boss phases and intent lifecycle", _test_boss_phases_and_intents)
	_run_test("settings code defaults", _test_settings_defaults)

	print("V1.5 release boundary tests: %d passed, %d failed" % [passed_tests, failures.size()])
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


func _test_ascension_a0_to_a10() -> void:
	_expect(AscensionRulesScript.MIN_LEVEL == 0, "Ascension must begin at A0.")
	_expect(AscensionRulesScript.MAX_LEVEL == 10, "Ascension must end at A10.")
	_expect(AscensionRulesScript.LEVEL_RULES.size() == 11, "A0-A10 must expose exactly eleven definitions.")
	var previous_rules: Dictionary = {}
	for level in range(AscensionRulesScript.MIN_LEVEL, AscensionRulesScript.MAX_LEVEL + 1):
		var definition: Dictionary = AscensionRulesScript.get_level_rule(level)
		var cumulative: Dictionary = AscensionRulesScript.get_cumulative_rules(level)
		_expect(int(definition.get("level", -1)) == level, "A%d must retain its explicit level." % level)
		_expect(not String(definition.get("name", "")).is_empty(), "A%d must have a release name." % level)
		_expect(not String(definition.get("description", "")).is_empty(), "A%d must have a release description." % level)
		_expect(int(cumulative.get("level", -1)) == level, "A%d cumulative rules must retain the level." % level)
		for key_value in AscensionRulesScript.BASE_RULES:
			_expect(cumulative.has(key_value), "A%d must retain rule key %s." % [level, String(key_value)])
		if not previous_rules.is_empty():
			_expect(
				float(cumulative["enemy_health_multiplier"]) + 0.000_001 >= float(previous_rules["enemy_health_multiplier"]),
				"Enemy health pressure must not decrease at A%d." % level
			)
		previous_rules = cumulative

	_expect(AscensionRulesScript.clamp_level(-1_000_000) == 0, "Extreme low ascension must clamp to A0.")
	_expect(AscensionRulesScript.clamp_level(1_000_000) == 10, "Extreme high ascension must clamp to A10.")
	var a10_boss: Dictionary = AscensionRulesScript.apply_to_battle_params({
		"encounter_type": "boss",
		"enemy_max_health": 9_000_000_000,
		"enemy_health": 9_000_000_000,
		"enemy_damage": 9_000_000_000,
		"gray_spawn_chance": 1.0,
		"hazard_peg_chance": 1.0,
		"max_hazard_pegs": 999,
	}, 10)
	_expect(int(a10_boss["enemy_max_health"]) == AscensionRulesScript.MAX_EFFECTIVE_ENEMY_HEALTH, "A10 Boss health must respect the absolute cap.")
	_expect(int(a10_boss["enemy_damage"]) == AscensionRulesScript.MAX_EFFECTIVE_ENEMY_DAMAGE, "A10 Boss damage must respect the absolute cap.")
	_expect(float(a10_boss["gray_spawn_chance"]) <= AscensionRulesScript.MAX_EFFECTIVE_GRAY_SPAWN_CHANCE, "A10 gray chance must remain capped.")
	_expect(float(a10_boss["hazard_peg_chance"]) <= AscensionRulesScript.MAX_EFFECTIVE_HAZARD_PEG_CHANCE, "A10 hazard chance must remain capped.")
	_expect(int(a10_boss["max_hazard_pegs"]) <= AscensionRulesScript.MAX_EFFECTIVE_HAZARD_PEG_COUNT, "A10 hazard count must remain capped.")

	game_manager.set_ascension_level(0)
	game_manager.reset_run()
	_expect(game_manager.configure_starting_archetype("red"), "A0 must configure a real character run.")
	_expect(game_manager.coins == 50, "A0 must begin with the formal 50-gold budget.")
	_expect(_deck_card_count("obsidian_contract") == 0, "A0 must not add an ascension burden.")
	game_manager.set_ascension_level(9)
	game_manager.reset_run()
	_expect(game_manager.configure_starting_archetype("red"), "A9 must configure a real character run.")
	_expect(game_manager.coins == 25, "A9 must apply the 25-gold starting penalty.")
	_expect(_deck_card_count("obsidian_contract") == 1, "A9 must add one ascension burden.")
	game_manager.set_ascension_level(10)
	game_manager.reset_run()
	_expect(game_manager.configure_starting_archetype("red"), "A10 must configure a real character run.")
	_expect(game_manager.coins == 0, "A10 must apply the full 50-gold starting penalty.")
	_expect(_deck_card_count("obsidian_contract") == 2, "A10 must add two ascension burdens.")
	game_manager.set_ascension_level(0)


func _test_run_stats_summary() -> void:
	var stats: Variant = RunStatsScript.new()
	_expect(stats.start("release-boundary", {"ascension": 10}), "RunStats must start for release summary testing.")
	for event in [
		["turns", 6],
		["swaps", 12],
		["matches", 9],
		["cascades", 3],
		["spectra_completed", 4],
		["shots_fired", 2],
		["balls_fired", 4],
		["hits", 12],
		["critical_hits", 3],
		["hazard_pegs", 2],
		["shield_gained", 18],
		["shield_absorbed", 11],
		["coins_gained", 30],
		["coins_spent", 8],
	]:
		_expect(stats.record(event[0], event[1]), "RunStats must record %s." % String(event[0]))
	_expect(stats.record("damage", 60, {"source": "spectrum"}), "RunStats must record spectrum damage.")
	_expect(stats.record("damage", 20, {"source": "relic"}), "RunStats must record relic damage.")
	_expect(stats.record("battle_result", "win"), "RunStats must record a battle win.")

	var result: Dictionary = stats.summary()
	_expect(int(result["damage_total"]) == 80, "RunStats summary must total all damage sources.")
	_expect(String(result["top_damage_source"]) == "spectrum", "RunStats summary must identify the top damage source.")
	_expect(int(result["top_damage_amount"]) == 60, "RunStats summary must include top source damage.")
	_expect(is_equal_approx(float(result["hit_rate"]), 1.0), "RunStats hit rate must remain bounded at one.")
	_expect(is_equal_approx(float(result["crit_rate"]), 0.25), "RunStats crit rate must use crits per hit.")
	_expect(is_equal_approx(float(result["average_damage_per_shot"]), 40.0), "RunStats average shot damage must use total damage per shot.")
	_expect(is_equal_approx(float(result["average_hits_per_ball"]), 3.0), "RunStats must expose average hits per ball.")
	_expect(int(result["coins_net"]) == 22, "RunStats summary must expose net coins.")
	_expect(int(result["battles_total"]) == 1, "RunStats summary must expose battle result totals.")

	_expect(stats.record("damage", RunStatsScript.MAX_STAT_VALUE + 1, {"source": "overflow"}), "Huge RunStats damage must be accepted defensively.")
	var capped: Dictionary = stats.summary()
	_expect(int(capped["damage_by_source"]["overflow"]) == RunStatsScript.MAX_STAT_VALUE, "Huge RunStats damage must saturate at its cap.")
	_expect(capped["average_damage_per_shot"] is float, "Release summary averages must stay numeric after saturation.")


func _test_spectrum_tuning_boundaries() -> void:
	var battle: Variant = BattleManagerScript.new()
	var merged: Dictionary = battle._merge_spectrum_modifier(
		{"flat_damage": 4, "repeat_count": 2, "repeat_ratio": 0.5},
		{"flat_damage": 3, "repeat_count": 3, "repeat_ratio": 0.75}
	)
	_expect(int(merged.get("flat_damage", 0)) == 7, "Stacked flat spectrum damage must aggregate.")
	_expect(int(merged.get("repeat_count", 0)) == 3, "Stacked repeat count must keep the strongest tuning.")
	_expect(is_equal_approx(float(merged.get("repeat_ratio", 0.0)), 0.75), "The latest explicit repeat ratio must apply.")
	var extreme: Dictionary = SpectrumResolutionScript.resolve(
		{"rarity": "epic"},
		{},
		{"repeat_count": 999_999, "repeat_ratio": 99.0, "damage_ratio_bonus": 99.0}
	)
	_expect(int(extreme.get("repeat_count", 0)) == 4, "Repeat count must clamp to four resolutions.")
	_expect(is_equal_approx(float(extreme.get("repeat_ratio", 0.0)), 1.0), "Repeat ratio must clamp to full damage.")
	_expect(int(extreme.get("damage", 0)) == 108, "Amplification and repeat clamps must bound extreme spectrum damage.")
	battle.free()


func _test_resolver_numeric_boundaries() -> void:
	var resolver: Variant = PegboardResolverScript.new()
	var low_values: Array[Variant] = [-999_999, 0, false]
	for multiball_value in low_values:
		var low: Dictionary = resolver.resolve({
			"multiball": multiball_value,
			"crit_chance": 0.0,
		}, 0.0, 81, 1)
		_expect(low["balls"].size() == 1, "Low multiball value %s must clamp to one ball." % str(multiball_value))

	var boolean_multiball: Dictionary = resolver.resolve({"multiball": true}, 0.0, 82, 1)
	_expect(boolean_multiball["balls"].size() == 2, "Boolean true multiball must preserve the supported two-ball compatibility path.")
	for invalid_multiball in [{"count": 999}, [999], "999"]:
		var invalid: Dictionary = resolver.resolve({
			"base_damage": {"invalid": true},
			"damage_per_hit": [99],
			"crit_chance": "always",
			"crit_multiplier": {},
			"pierce": invalid_multiball,
			"multiball": invalid_multiball,
		}, 0.0, 82, 1)
		_expect(invalid["balls"].size() == 1, "Invalid multiball type %s must use the one-ball fallback." % str(invalid_multiball))
		_expect(int(invalid["damage"]) >= 0, "Invalid numeric shot fields must resolve without negative damage.")

	var huge_shot: Dictionary = {
		"base_damage": 9_000_000_000,
		"damage_per_hit": 9_000_000_000,
		"crit_chance": 99.0,
		"crit_multiplier": 99.0,
		"pierce": 999,
		"multiball": 999_999,
		"character_id": "blue",
	}
	var huge: Dictionary = resolver.resolve(huge_shot, 999.0, 83, 999)
	_expect(huge["balls"].size() == PegboardResolverScript.MAX_BALLS, "Huge multiball must clamp to MAX_BALLS.")
	_expect(int(huge["chapter"]) == 99, "Huge chapter values must clamp to the resolver chapter cap.")
	_expect(is_equal_approx(float(huge["aim"]), 1.0), "Huge aim values must clamp to the right edge.")
	_expect(int(huge["damage"]) > 0, "Huge damage input must resolve to positive bounded data.")
	var maximum_expected_damage: int = (
		PegboardResolverScript.MAX_DAMAGE_VALUE
		* (1 + PegboardResolverScript.MAX_HITS_PER_BALL * 10)
		* PegboardResolverScript.MAX_BALLS
	)
	_expect(int(huge["damage"]) <= maximum_expected_damage, "Huge damage must remain within resolver component caps.")
	for ball_value in huge["balls"]:
		var ball: Dictionary = ball_value
		_expect(int(ball["hits"]) >= PegboardResolverScript.MIN_HITS_PER_BALL, "Every huge-input ball must retain minimum hits.")
		_expect(int(ball["hits"]) <= PegboardResolverScript.MAX_HITS_PER_BALL, "Every huge-input ball must retain maximum hits.")

	var normal_profile: Dictionary = {
		"id": "hazard_budget_test",
		"pegs": [{"id": "normal", "type": "normal"}],
		"rules": {},
	}
	for hazard_seed in range(100):
		var budgeted: Dictionary = resolver.resolve({
			"pegboard_profile": normal_profile,
			"hazard_chance_add": 1.0,
			"max_bonus_hazard_hits": 1,
		}, 0.0, hazard_seed, 3)
		_expect(budgeted["peg_types"].count("hazard") <= 1, "Ascension hazards must respect the per-ball bonus budget.")
	var preview: PegboardView = PegboardViewScript.new()
	preview.current_shot = huge_shot.duplicate(true)
	preview.current_profile = normal_profile.duplicate(true)
	var preview_range: Vector2i = preview._sample_damage_range()
	_expect(preview_range.x > 0, "Shot prediction must produce a positive sampled lower bound.")
	_expect(preview_range.y >= preview_range.x, "Shot prediction upper bound must not fall below its lower bound.")
	preview.free()


func _test_extreme_seeds() -> void:
	var resolver: Variant = PegboardResolverScript.new()
	var shot: Dictionary = {
		"base_damage": 14,
		"damage_per_hit": 3,
		"crit_chance": 0.25,
		"multiball": 3,
		"character_id": "mixed",
	}
	for extreme_seed in [MIN_TEST_SEED, -1, 0, 1, MAX_TEST_SEED]:
		var first: Dictionary = resolver.resolve(shot, -0.37, extreme_seed, 3)
		var second: Dictionary = resolver.resolve(shot, -0.37, extreme_seed, 3)
		_expect(first == second, "Seed %s must resolve deterministically." % str(extreme_seed))
		_expect(first["balls"].size() == 3, "Seed %s must preserve multiball count." % str(extreme_seed))
		_expect(int(first["hits"]) >= 3 * PegboardResolverScript.MIN_HITS_PER_BALL, "Seed %s must preserve aggregate minimum hits." % str(extreme_seed))
		_expect(int(first["damage"]) >= 0, "Seed %s must never produce negative damage." % str(extreme_seed))


func _test_boss_phases_and_intents() -> void:
	var intent_effect_keys: Dictionary = {
		"seal": "sealed_peg_ids",
		"aim_drift": "aim_drift",
		"crit_suppress": "crit_chance_multiplier",
		"add_hazard": "added_hazard_peg_ids",
	}
	for chapter in range(1, 4):
		var phase_one: Dictionary = ChapterPegboardRulesScript.compose_profile(chapter, "boss", -999)
		var phase_two: Dictionary = ChapterPegboardRulesScript.compose_profile(chapter, "boss", 999)
		_expect(int(phase_one["boss_phase"]) == 1, "Chapter %d low Boss phase must clamp to phase one." % chapter)
		_expect(int(phase_two["boss_phase"]) == 2, "Chapter %d high Boss phase must clamp to phase two." % chapter)
		_expect(phase_one["id"] != phase_two["id"], "Chapter %d Boss phases must select different profiles." % chapter)
		_expect(phase_one["boss_rewrite"].get("rule") != phase_two["boss_rewrite"].get("rule"), "Chapter %d Boss phase two must rewrite the shot rule." % chapter)

		for intent_id in intent_effect_keys:
			var telegraph: Dictionary = ChapterPegboardRulesScript.create_intent(intent_id, MAX_TEST_SEED, 999)
			_expect(String(telegraph.get("phase", "")) == ChapterPegboardRulesScript.INTENT_PHASE_TELEGRAPH, "%s must begin telegraphed." % intent_id)
			_expect(int(telegraph.get("strength", 0)) == 3, "%s strength must clamp to three." % intent_id)
			var active: Dictionary = ChapterPegboardRulesScript.advance_intent(telegraph, "enemy_turn_end")
			_expect(ChapterPegboardRulesScript.is_intent_active(active), "%s must activate after its telegraph." % intent_id)
			var profile: Dictionary = ChapterPegboardRulesScript.compose_profile(chapter, "boss", 2, active)
			var effects: Dictionary = profile.get("intent_effects", {})
			_expect(effects.has(intent_effect_keys[intent_id]), "Chapter %d %s must patch the active Boss profile." % [chapter, intent_id])
			_expect(ChapterPegboardRulesScript.is_aim_range_usable(profile), "Chapter %d %s must retain usable aim." % [chapter, intent_id])
			var cleared: Dictionary = ChapterPegboardRulesScript.advance_intent(active, "shot_resolved")
			_expect(String(cleared.get("phase", "")) == ChapterPegboardRulesScript.INTENT_PHASE_CLEARED, "%s must clear after its shot." % intent_id)

	_expect(ChapterPegboardRulesScript.create_intent("").is_empty(), "Empty Boss intents must be rejected.")
	_expect(ChapterPegboardRulesScript.create_intent("unknown_intent").is_empty(), "Unknown Boss intents must be rejected.")
	var invalid_intent_profile: Dictionary = ChapterPegboardRulesScript.compose_profile(3, "boss", 2, {"id": "unknown_intent"})
	_expect(not invalid_intent_profile.has("intent_effects"), "Invalid Boss intents must not patch the profile.")


func _test_settings_defaults() -> void:
	var settings: Variant = SettingsManagerScript.new()
	_expect(is_equal_approx(float(settings.master_volume), 1.0), "Default master volume must be 1.0.")
	_expect(is_equal_approx(float(settings.music_volume), 0.75), "Default music volume must be 0.75.")
	_expect(is_equal_approx(float(settings.sfx_volume), 0.85), "Default SFX volume must be 0.85.")
	_expect(not bool(settings.fullscreen), "Fullscreen must default off.")
	_expect(not bool(settings.reduced_motion), "Reduced motion must default off.")
	_expect(bool(settings.aim_assist), "Aim prediction must default on.")
	_expect(not bool(settings.quick_resolve), "Quick resolve must default off.")
	_expect(not bool(settings.high_contrast_pegs), "High contrast pegs must default off.")
	_expect(is_equal_approx(float(settings.combat_speed), 1.0), "Combat speed must default to 1.0.")
	_expect(String(settings.last_error).is_empty(), "Settings must begin without an error.")
	var test_settings_path: String = "user://test_v1_5_settings.cfg"
	if FileAccess.file_exists(test_settings_path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(test_settings_path))
	settings.settings_path = test_settings_path
	settings.aim_assist = false
	settings.quick_resolve = true
	settings.high_contrast_pegs = true
	settings.combat_speed = 1.75
	_expect(settings.save_settings(), "Release settings must save to disk.")
	var restored: Variant = SettingsManagerScript.new()
	restored.settings_path = test_settings_path
	restored.load_settings()
	_expect(not bool(restored.aim_assist), "Aim assist must persist to disk.")
	_expect(bool(restored.quick_resolve), "Quick resolve must persist to disk.")
	_expect(bool(restored.high_contrast_pegs), "High contrast pegs must persist to disk.")
	_expect(is_equal_approx(float(restored.combat_speed), 1.75), "Combat speed must persist to disk.")
	var invalid_config: ConfigFile = ConfigFile.new()
	invalid_config.set_value("gameplay", "combat_speed", 99.0)
	invalid_config.save(test_settings_path)
	restored.load_settings()
	_expect(is_equal_approx(float(restored.combat_speed), 2.0), "Loaded combat speed must clamp to 2.0x.")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(test_settings_path))
	restored.free()
	settings.free()


func _deck_card_count(card_id: String) -> int:
	var count: int = 0
	for card_value in game_manager.deck:
		if card_value is Dictionary and String(card_value.get("card_id", "")) == card_id:
			count += 1
	return count


func _expect(condition: bool, message: String) -> void:
	if not condition and not failures.has(message):
		failures.append(message)
