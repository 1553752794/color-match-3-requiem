extends SceneTree

const ChapterPegboardRulesScript = preload("res://scripts/ChapterPegboardRules.gd")

var failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_test_catalog_has_four_profiles_per_chapter()
	_test_composition_is_deterministic()
	_test_chapters_have_distinct_mechanics()
	_test_intents_preview_apply_expire_and_clear()
	_test_boss_phases_rewrite_rules()
	_test_profile_boundaries_remain_playable()
	if failures.is_empty():
		print("ChapterPegboardRules tests: 6 passed, 0 failed")
		quit(0)
		return
	for failure in failures:
		push_error(failure)
	quit(1)


func _test_catalog_has_four_profiles_per_chapter() -> void:
	var catalog: Dictionary = ChapterPegboardRulesScript.get_catalog()
	for chapter in range(1, 4):
		var chapter_profiles: Dictionary = catalog.get(chapter, {})
		_expect(chapter_profiles.size() >= 4, "Chapter %d must expose at least four profiles." % chapter)
		for profile_key in ["normal", "elite", "boss_phase1", "boss_phase2"]:
			_expect(chapter_profiles.has(profile_key), "Chapter %d must include %s." % [chapter, profile_key])
	_expect(ChapterPegboardRulesScript.get_intent_definitions().size() == 4, "Exactly four next-shot intent definitions are required.")


func _test_composition_is_deterministic() -> void:
	var intent: Dictionary = ChapterPegboardRulesScript.create_intent("add_hazard", 9, 2)
	intent = ChapterPegboardRulesScript.advance_intent(intent, "enemy_turn_end")
	var first: Dictionary = ChapterPegboardRulesScript.compose_profile(2, "elite", 1, intent)
	var second: Dictionary = ChapterPegboardRulesScript.compose_profile(2, "elite", 1, intent)
	_expect(first == second, "Identical chapter, encounter, phase, and intent inputs must compose exactly the same profile.")
	_expect(first["pegs"].size() == ChapterPegboardRulesScript.BOARD_PEG_COUNT, "A composed profile must contain the full deterministic board.")


func _test_chapters_have_distinct_mechanics() -> void:
	var chapter_one: Dictionary = ChapterPegboardRulesScript.compose_profile(1, "normal")
	var chapter_two: Dictionary = ChapterPegboardRulesScript.compose_profile(2, "normal")
	var chapter_three: Dictionary = ChapterPegboardRulesScript.compose_profile(3, "normal")
	_expect(chapter_one["theme"] != chapter_two["theme"] and chapter_two["theme"] != chapter_three["theme"], "All chapters must expose distinct board themes.")
	_assert_peg_types(chapter_one, ["flame", "mist"])
	_assert_peg_types(chapter_two, ["mirror", "bumper", "resistance"])
	_assert_peg_types(chapter_three, ["lock", "void", "hazard"])


func _test_intents_preview_apply_expire_and_clear() -> void:
	var intent_expectations: Dictionary = {
		"seal": "sealed_peg_ids",
		"aim_drift": "aim_drift",
		"crit_suppress": "crit_chance_multiplier",
		"add_hazard": "added_hazard_peg_ids",
	}
	for intent_id in intent_expectations:
		var telegraph: Dictionary = ChapterPegboardRulesScript.create_intent(intent_id, 4, 1)
		var preview: Dictionary = ChapterPegboardRulesScript.get_intent_preview(telegraph)
		_expect(preview.get("phase") == "telegraph", "%s must begin in telegraph phase." % intent_id)
		_expect(bool(preview.get("will_apply_next_shot", false)), "%s preview must announce the next shot." % intent_id)
		var telegraphed_profile: Dictionary = ChapterPegboardRulesScript.compose_profile(1, "normal", 1, telegraph)
		_expect(not telegraphed_profile.has("intent_effects"), "%s must not apply during telegraph." % intent_id)

		var active: Dictionary = ChapterPegboardRulesScript.advance_intent(telegraph, "enemy_turn_end")
		_expect(ChapterPegboardRulesScript.is_intent_active(active), "%s must activate after its telegraph." % intent_id)
		var active_profile: Dictionary = ChapterPegboardRulesScript.compose_profile(1, "normal", 1, active)
		var effects: Dictionary = active_profile.get("intent_effects", {})
		_expect(effects.has(intent_expectations[intent_id]), "%s must apply its deterministic profile patch." % intent_id)
		if intent_id == "seal":
			_expect(effects["sealed_peg_ids"].size() == 3, "Seal strength one must rewrite three unique pegs.")
		elif intent_id == "add_hazard":
			_expect(effects["added_hazard_peg_ids"].size() == 3, "Add-hazard strength one must rewrite three unique pegs.")
		_expect(ChapterPegboardRulesScript.is_aim_range_usable(active_profile), "%s must preserve usable aiming." % intent_id)

		var expired: Dictionary = ChapterPegboardRulesScript.advance_intent(active, "shot_resolved")
		_expect(expired.get("phase") == "cleared", "%s must clear after one resolved shot." % intent_id)
		_expect(ChapterPegboardRulesScript.get_intent_preview(expired).is_empty(), "%s preview must disappear after expiry." % intent_id)
		var expired_profile: Dictionary = ChapterPegboardRulesScript.compose_profile(1, "normal", 1, expired)
		_expect(not expired_profile.has("intent_effects"), "%s must not remain applied after expiry." % intent_id)

	var manually_cleared: Dictionary = ChapterPegboardRulesScript.clear_intent(
		ChapterPegboardRulesScript.create_intent("seal"),
		"dispel"
	)
	_expect(manually_cleared.get("phase") == "cleared", "Explicit intent clearing must set the cleared phase.")
	_expect(manually_cleared.get("clear_reason") == "dispel", "Explicit intent clearing must retain its reason.")


func _test_boss_phases_rewrite_rules() -> void:
	for chapter in range(1, 4):
		var phase_one: Dictionary = ChapterPegboardRulesScript.compose_profile(chapter, "boss", 1)
		var phase_two: Dictionary = ChapterPegboardRulesScript.compose_profile(chapter, "boss", 2)
		_expect(phase_one["id"] != phase_two["id"], "Chapter %d boss phases must use different profiles." % chapter)
		_expect(int(phase_one.get("boss_rewrite", {}).get("phase", 0)) == 1, "Chapter %d Boss P1 must expose a phase-one rewrite." % chapter)
		_expect(int(phase_two.get("boss_rewrite", {}).get("phase", 0)) == 2, "Chapter %d Boss P2 must expose a phase-two rewrite." % chapter)
		_expect(phase_one["boss_rewrite"].get("rule") != phase_two["boss_rewrite"].get("rule"), "Chapter %d Boss P2 must materially rewrite its shot rule." % chapter)
	var clamped_phase: Dictionary = ChapterPegboardRulesScript.compose_profile(3, "boss", 99)
	_expect(int(clamped_phase["boss_phase"]) == 2, "Boss phases above two must resolve to the phase-two profile.")


func _test_profile_boundaries_remain_playable() -> void:
	var catalog_errors: Array[String] = ChapterPegboardRulesScript.validate_catalog()
	_expect(catalog_errors.is_empty(), "The built-in profile catalog must validate: %s" % str(catalog_errors))
	for chapter in range(1, 4):
		for encounter_type in ["normal", "elite"]:
			_assert_profile_boundaries(ChapterPegboardRulesScript.compose_profile(chapter, encounter_type))
		for boss_phase in [1, 2]:
			_assert_profile_boundaries(ChapterPegboardRulesScript.compose_profile(chapter, "boss", boss_phase))
		var drift_profile: Dictionary = ChapterPegboardRulesScript.compose_profile(chapter, "boss", 2, {
			"id": "aim_drift",
			"phase": "active",
			"remaining_shots": 1,
			"strength": 3,
			"direction": -1,
		})
		_assert_profile_boundaries(drift_profile)
		_expect(absf(float(drift_profile["aim"]["drift"])) <= 0.36, "Aim drift must remain capped at a readable offset.")

	var normalized: Dictionary = ChapterPegboardRulesScript.compose_profile(-20, "unknown", -5)
	_expect(int(normalized["chapter"]) == 1, "Invalid chapter values must clamp to chapter one.")
	_expect(normalized["encounter_type"] == "normal", "Unknown encounter types must fall back to normal.")
	_assert_profile_boundaries(normalized)


func _assert_peg_types(profile: Dictionary, required_types: Array[String]) -> void:
	var counts: Dictionary = profile.get("peg_counts", {})
	for peg_type in required_types:
		_expect(int(counts.get(peg_type, 0)) > 0, "%s must include %s pegs." % [profile.get("id", "profile"), peg_type])


func _assert_profile_boundaries(profile: Dictionary) -> void:
	var ratio: float = ChapterPegboardRulesScript.get_edge_peg_ratio(profile)
	_expect(ratio <= ChapterPegboardRulesScript.MAX_EDGE_PEG_RATIO + 0.00001, "%s edge peg ratio must stay at or below 25%%." % profile.get("id", "profile"))
	_expect(ChapterPegboardRulesScript.is_aim_range_usable(profile), "%s must retain a usable aim range." % profile.get("id", "profile"))
	_expect(ChapterPegboardRulesScript.validate_profile(profile).is_empty(), "%s must satisfy profile validation." % profile.get("id", "profile"))


func _expect(condition: bool, message: String) -> void:
	if not condition and not failures.has(message):
		failures.append(message)
